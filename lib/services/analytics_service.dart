// lib/services/analytics_service.dart
// Powers all 4 analytics features:
//   1. AI Spending Insights (rule-based + Claude API)
//   2. Financial Health Score
//   3. Cashflow Forecast
//   4. Spending Trends
//
// No new packages needed — uses dart:io HttpClient (already available).
// Claude API is optional — user enters their own API key in the app.

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/transaction_model.dart';

// ── Data models ───────────────────────────────────────────────────────────────

class SpendingInsight {
  final String type;      // 'warning' | 'tip' | 'positive' | 'ai'
  final String title;
  final String message;
  final String icon;

  const SpendingInsight({
    required this.type,
    required this.title,
    required this.message,
    required this.icon,
  });
}

class HealthBreakdown {
  final String label;
  final double score;     // 0–100
  final double maxScore;
  final String description;
  final String icon;

  const HealthBreakdown({
    required this.label,
    required this.score,
    required this.maxScore,
    required this.description,
    required this.icon,
  });
}

class FinancialHealthScore {
  final double total;          // 0–100
  final String grade;          // A+, A, B, C, D, F
  final String headline;
  final List<HealthBreakdown> breakdown;

  const FinancialHealthScore({
    required this.total,
    required this.grade,
    required this.headline,
    required this.breakdown,
  });
}

class MonthlyPoint {
  final DateTime month;
  final double income;
  final double expense;
  final double balance;

  const MonthlyPoint({
    required this.month,
    required this.income,
    required this.expense,
    required this.balance,
  });
}

class CategoryTrend {
  final String category;
  final List<double> monthlyAmounts; // index 0 = oldest
  final double total;
  final double avgMonthly;

  const CategoryTrend({
    required this.category,
    required this.monthlyAmounts,
    required this.total,
    required this.avgMonthly,
  });
}

// ── AnalyticsService ──────────────────────────────────────────────────────────

class AnalyticsService {

  // ── Rule-based insights ───────────────────────────────────────────────────
  static List<SpendingInsight> generateInsights(
      List<TransactionModel> all) {
    final insights = <SpendingInsight>[];

    if (all.isEmpty) return [
      const SpendingInsight(
        type: 'tip',
        title: 'No data yet',
        icon: '💡',
        message: 'Add some transactions to see personalised spending insights.',
      ),
    ];

    final now      = DateTime.now();
    final thisMonth = all.where((t) =>
        t.date.year == now.year && t.date.month == now.month).toList();
    final lastMonth = all.where((t) {
      final lm = DateTime(now.year, now.month - 1);
      return t.date.year == lm.year && t.date.month == lm.month;
    }).toList();

    final thisIncome  = _sum(thisMonth, 'income');
    final thisExpense = _sum(thisMonth, 'expense');
    final lastExpense = _sum(lastMonth, 'expense');
    final savings     = thisIncome - thisExpense;
    final savingsRate = thisIncome > 0 ? (savings / thisIncome) * 100 : 0;

    // 1. Savings rate
    if (thisIncome > 0) {
      if (savingsRate >= 30) {
        insights.add(SpendingInsight(
          type: 'positive',
          icon: '🎉',
          title: 'Great savings rate!',
          message: 'You\'re saving ${savingsRate.toStringAsFixed(0)}% of income. '
              'That\'s above the recommended 20% — keep it up!',
        ));
      } else if (savingsRate < 0) {
        insights.add(SpendingInsight(
          type: 'warning',
          icon: '🚨',
          title: 'Spending exceeds income',
          message: 'You spent ₹${(thisExpense - thisIncome).toStringAsFixed(0)} more '
              'than you earned this month. Review your expenses.',
        ));
      } else if (savingsRate < 10) {
        insights.add(SpendingInsight(
          type: 'warning',
          icon: '⚠️',
          title: 'Low savings rate',
          message: 'You\'re saving only ${savingsRate.toStringAsFixed(0)}% this month. '
              'Try to aim for at least 20% of your income.',
        ));
      }
    }

    // 2. Month-over-month expense change
    if (lastExpense > 0 && thisExpense > 0) {
      final change = ((thisExpense - lastExpense) / lastExpense) * 100;
      if (change > 20) {
        insights.add(SpendingInsight(
          type: 'warning',
          icon: '📈',
          title: 'Spending up ${change.toStringAsFixed(0)}%',
          message: 'Your spending is ₹${(thisExpense - lastExpense).toStringAsFixed(0)} '
              'higher than last month. Check what changed.',
        ));
      } else if (change < -15) {
        insights.add(SpendingInsight(
          type: 'positive',
          icon: '📉',
          title: 'Spending down ${change.abs().toStringAsFixed(0)}%',
          message: 'Great discipline! You spent ₹${(lastExpense - thisExpense).toStringAsFixed(0)} '
              'less than last month.',
        ));
      }
    }

    // 3. Top category dominance
    final catTotals = <String, double>{};
    for (final t in thisMonth.where((t) => t.type == 'expense')) {
      catTotals[t.category] = (catTotals[t.category] ?? 0) + t.amount;
    }
    if (catTotals.isNotEmpty && thisExpense > 0) {
      final topCat  = catTotals.entries.reduce((a, b) => a.value > b.value ? a : b);
      final pct     = (topCat.value / thisExpense) * 100;
      if (pct > 45) {
        insights.add(SpendingInsight(
          type: 'warning',
          icon: '🔍',
          title: '${topCat.key} is ${pct.toStringAsFixed(0)}% of spending',
          message: '₹${topCat.value.toStringAsFixed(0)} spent on ${topCat.key} this month. '
              'High concentration in one category can indicate overspending.',
        ));
      }
    }

    // 4. No income recorded
    if (thisIncome == 0 && thisExpense > 0) {
      insights.add(const SpendingInsight(
        type: 'tip',
        icon: '💰',
        title: 'No income recorded this month',
        message: 'You have expenses but no income logged. '
            'Add your salary or other income to get accurate insights.',
      ));
    }

    // 5. Frequent small transactions (possible spending leak)
    final smallTxns = thisMonth.where(
        (t) => t.type == 'expense' && t.amount < 200).toList();
    if (smallTxns.length > 15) {
      final smallTotal = smallTxns.fold(0.0, (s, t) => s + t.amount);
      insights.add(SpendingInsight(
        type: 'tip',
        icon: '🪣',
        title: '${smallTxns.length} small purchases = ₹${smallTotal.toStringAsFixed(0)}',
        message: 'Frequent small spends under ₹200 add up quickly. '
            'Consider tracking these "latte factor" expenses.',
      ));
    }

    // 6. Weekend vs weekday (fun fact)
    final weekendSpend = thisMonth
        .where((t) =>
            t.type == 'expense' &&
            (t.date.weekday == DateTime.saturday ||
                t.date.weekday == DateTime.sunday))
        .fold(0.0, (s, t) => s + t.amount);
    final weekdaySpend = thisExpense - weekendSpend;
    if (weekdaySpend > 0 && weekendSpend > weekdaySpend * 0.8) {
      insights.add(SpendingInsight(
        type: 'tip',
        icon: '📅',
        title: 'Heavy weekend spending',
        message: '₹${weekendSpend.toStringAsFixed(0)} spent on weekends vs '
            '₹${weekdaySpend.toStringAsFixed(0)} on weekdays. '
            'Weekends might be a spending trigger for you.',
      ));
    }

    // 7. Positive: diversified spending
    if (catTotals.length >= 5 && thisExpense > 0) {
      final maxPct = catTotals.values.map((v) => v / thisExpense * 100).reduce(
          (a, b) => a > b ? a : b);
      if (maxPct < 35) {
        insights.add(const SpendingInsight(
          type: 'positive',
          icon: '✅',
          title: 'Well-balanced spending',
          message: 'Your spending is spread across multiple categories '
              'with no single category dominating. Good financial hygiene!',
        ));
      }
    }

    return insights.isEmpty
        ? [
            const SpendingInsight(
              type: 'positive',
              icon: '👍',
              title: 'Looking good!',
              message: 'No major spending issues detected this month. '
                  'Keep up the good habits!',
            )
          ]
        : insights;
  }

  // ── Claude AI insights ────────────────────────────────────────────────────
  // Returns null if on web (dart:io not available) or API call fails.
  static Future<String?> fetchClaudeInsights({
    required List<TransactionModel> transactions,
    required String apiKey,
  }) async {
    if (kIsWeb) return null; // dart:io not available on web
    if (apiKey.trim().isEmpty) return null;

    final now       = DateTime.now();
    final thisMonth = transactions.where((t) =>
        t.date.year == now.year && t.date.month == now.month).toList();

    final income  = _sum(thisMonth, 'income');
    final expense = _sum(thisMonth, 'expense');

    // Build category summary
    final catMap = <String, double>{};
    for (final t in thisMonth.where((t) => t.type == 'expense')) {
      catMap[t.category] = (catMap[t.category] ?? 0) + t.amount;
    }
    final catSummary = catMap.entries
        .map((e) => '${e.key}: ₹${e.value.toStringAsFixed(0)}')
        .join(', ');

    final prompt = '''You are a personal finance advisor analyzing a user's monthly spending in India.
Here is their ${now.year}-${now.month.toString().padLeft(2, '0')} financial summary:
- Total Income: ₹${income.toStringAsFixed(0)}
- Total Expenses: ₹${expense.toStringAsFixed(0)}
- Savings: ₹${(income - expense).toStringAsFixed(0)} (${income > 0 ? ((income - expense) / income * 100).toStringAsFixed(1) : 0}%)
- Expense breakdown: $catSummary
- Total transactions: ${thisMonth.length}

Give exactly 3 specific, actionable insights in this exact JSON format (no other text):
{"insights":[{"title":"...","message":"...","type":"warning|tip|positive"}]}

Keep each message under 120 characters. Be specific with numbers. Be friendly but direct.''';

    try {
      final body = jsonEncode({
        'model': 'claude-haiku-4-5-20251001',
        'max_tokens': 400,
        'messages': [{'role': 'user', 'content': prompt}],
      });

      final client  = HttpClient();
      client.connectionTimeout = const Duration(seconds: 15);
      final request = await client.postUrl(
          Uri.parse('https://api.anthropic.com/v1/messages'));
      request.headers.set('content-type',   'application/json');
      request.headers.set('x-api-key',       apiKey.trim());
      request.headers.set('anthropic-version', '2023-06-01');
      request.write(body);

      final response = await request.close();
      final respBody = await response.transform(utf8.decoder).join();
      client.close();

      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(respBody);
      final text    = decoded['content']?[0]?['text'] as String?;
      if (text == null) return null;

      // Parse inner JSON
      final start = text.indexOf('{');
      final end   = text.lastIndexOf('}');
      if (start < 0 || end < 0) return null;

      return text.substring(start, end + 1);
    } catch (_) {
      return null;
    }
  }

  // ── Financial Health Score ────────────────────────────────────────────────
  static FinancialHealthScore computeHealthScore(
      List<TransactionModel> all) {
    if (all.isEmpty) {
      return const FinancialHealthScore(
        total: 0, grade: 'N/A',
        headline: 'Add transactions to get your score',
        breakdown: [],
      );
    }

    final now       = DateTime.now();
    final months    = List.generate(3, (i) => DateTime(now.year, now.month - i));
    final breakdown = <HealthBreakdown>[];

    // 1. Savings Rate — 30 pts
    double totalIncome  = 0, totalExpense = 0;
    for (final t in all.where((t) =>
        months.any((m) => t.date.year == m.year && t.date.month == m.month))) {
      if (t.type == 'income')  totalIncome  += t.amount;
      if (t.type == 'expense') totalExpense += t.amount;
    }
    final savingsRate = totalIncome > 0
        ? ((totalIncome - totalExpense) / totalIncome * 100).clamp(0, 100)
        : 0.0;
    final savingsScore = (savingsRate / 100 * 30).clamp(0.0, 30.0);
    breakdown.add(HealthBreakdown(
      label: 'Savings Rate',
      score: savingsScore,
      maxScore: 30,
      icon: '💰',
      description: savingsRate >= 20
          ? 'Saving ${savingsRate.toStringAsFixed(0)}% — excellent!'
          : savingsRate >= 10
              ? 'Saving ${savingsRate.toStringAsFixed(0)}% — try for 20%'
              : 'Saving ${savingsRate.toStringAsFixed(0)}% — needs improvement',
    ));

    // 2. Expense Control — 25 pts (expense growth month-over-month)
    double expenseScore = 25;
    if (months.length >= 2) {
      final m1exp = _sumMonth(all, months[0], 'expense');
      final m2exp = _sumMonth(all, months[1], 'expense');
      if (m2exp > 0) {
        final growth = (m1exp - m2exp) / m2exp * 100;
        if (growth > 30)       expenseScore = 5;
        else if (growth > 15)  expenseScore = 12;
        else if (growth > 5)   expenseScore = 18;
        else if (growth < -5)  expenseScore = 25; // decreased — great
        else                   expenseScore = 22;
      }
    }
    breakdown.add(HealthBreakdown(
      label: 'Expense Control',
      score: expenseScore,
      maxScore: 25,
      icon: '📊',
      description: expenseScore >= 20
          ? 'Expenses stable or decreasing'
          : expenseScore >= 12
              ? 'Moderate expense growth'
              : 'Expenses growing significantly',
    ));

    // 3. Income Consistency — 20 pts
    final monthlyIncomes = months.map(
        (m) => _sumMonth(all, m, 'income')).toList();
    final nonZeroIncomes = monthlyIncomes.where((v) => v > 0).toList();
    double incomeScore = 0;
    if (nonZeroIncomes.length == 3) {
      final avg = nonZeroIncomes.reduce((a, b) => a + b) / 3;
      final variance = nonZeroIncomes
          .map((v) => (v - avg).abs() / avg * 100)
          .reduce((a, b) => a + b) / 3;
      incomeScore = variance < 10
          ? 20
          : variance < 25
              ? 14
              : variance < 40
                  ? 8
                  : 3;
    } else if (nonZeroIncomes.length == 2) {
      incomeScore = 12;
    } else if (nonZeroIncomes.length == 1) {
      incomeScore = 6;
    }
    breakdown.add(HealthBreakdown(
      label: 'Income Consistency',
      score: incomeScore,
      maxScore: 20,
      icon: '💼',
      description: incomeScore >= 16
          ? 'Very consistent income'
          : incomeScore >= 10
              ? 'Somewhat variable income'
              : 'Income is irregular',
    ));

    // 4. Spending Diversity — 15 pts
    final thisExp = all.where((t) =>
        t.type == 'expense' &&
        t.date.year == months[0].year &&
        t.date.month == months[0].month).toList();
    final catCount = <String>{};
    for (final t in thisExp) catCount.add(t.category);
    double totalMonth = thisExp.fold(0.0, (s, t) => s + t.amount);
    final catAmts = <String, double>{};
    for (final t in thisExp) catAmts[t.category] = (catAmts[t.category] ?? 0) + t.amount;
    double maxCatPct = catAmts.isEmpty ? 0
        : catAmts.values.reduce((a, b) => a > b ? a : b) / (totalMonth == 0 ? 1 : totalMonth) * 100;
    final diversityScore = catCount.length >= 5 && maxCatPct < 35
        ? 15.0
        : catCount.length >= 3 && maxCatPct < 50
            ? 10.0
            : catCount.length >= 2
                ? 6.0
                : 2.0;
    breakdown.add(HealthBreakdown(
      label: 'Spending Diversity',
      score: diversityScore,
      maxScore: 15,
      icon: '🎯',
      description: diversityScore >= 12
          ? 'Well-diversified spending'
          : diversityScore >= 8
              ? 'Moderate diversity'
              : 'Concentrated in few categories',
    ));

    // 5. Transaction Regularity — 10 pts
    final txnCount = all.where((t) =>
        months.any((m) => t.date.year == m.year && t.date.month == m.month))
        .length;
    final regularityScore = txnCount >= 30
        ? 10.0
        : txnCount >= 15
            ? 7.0
            : txnCount >= 5
                ? 4.0
                : 1.0;
    breakdown.add(HealthBreakdown(
      label: 'Tracking Regularity',
      score: regularityScore,
      maxScore: 10,
      icon: '📝',
      description: txnCount >= 20
          ? 'Tracking expenses regularly'
          : txnCount >= 10
              ? 'Moderate tracking'
              : 'Log more transactions for better insights',
    ));

    final total = (savingsScore + expenseScore + incomeScore +
            diversityScore + regularityScore)
        .clamp(0.0, 100.0);

    return FinancialHealthScore(
      total: total,
      grade: total >= 85
          ? 'A+'
          : total >= 75
              ? 'A'
              : total >= 65
                  ? 'B'
                  : total >= 50
                      ? 'C'
                      : total >= 35
                          ? 'D'
                          : 'F',
      headline: total >= 75
          ? 'Your finances are in great shape!'
          : total >= 55
              ? 'Doing okay — a few areas to improve'
              : total >= 35
                  ? 'Some financial habits need attention'
                  : 'Your finances need a health check',
      breakdown: breakdown,
    );
  }

  // ── Cashflow Forecast — next 3 months ────────────────────────────────────
  static List<MonthlyPoint> buildCashflowForecast(
      List<TransactionModel> all) {
    final now    = DateTime.now();
    // Historical: last 6 months
    final historical = <MonthlyPoint>[];
    for (int i = 5; i >= 0; i--) {
      final m = DateTime(now.year, now.month - i);
      historical.add(MonthlyPoint(
        month:   m,
        income:  _sumMonth(all, m, 'income'),
        expense: _sumMonth(all, m, 'expense'),
        balance: _sumMonth(all, m, 'income') - _sumMonth(all, m, 'expense'),
      ));
    }

    // Average from last 3 months for forecast
    final recent = historical.skip(3).toList();
    final avgInc = recent.isEmpty ? 0.0
        : recent.map((m) => m.income).reduce((a, b) => a + b) / recent.length;
    final avgExp = recent.isEmpty ? 0.0
        : recent.map((m) => m.expense).reduce((a, b) => a + b) / recent.length;

    // Trend: is expense growing?
    double expTrend = 0;
    if (recent.length >= 2) {
      final first = recent.first.expense;
      final last  = recent.last.expense;
      if (first > 0) expTrend = (last - first) / first / recent.length;
    }

    // Forecast: next 3 months
    final forecast = <MonthlyPoint>[];
    for (int i = 1; i <= 3; i++) {
      final m          = DateTime(now.year, now.month + i);
      final projExpense = avgExp * (1 + expTrend * i);
      forecast.add(MonthlyPoint(
        month:   m,
        income:  avgInc,
        expense: projExpense.clamp(0, double.infinity),
        balance: avgInc - projExpense,
      ));
    }

    return [...historical, ...forecast];
  }

  // ── Spending Trends — last 6 months by category ───────────────────────────
  static List<MonthlyPoint> buildMonthlyTrend(List<TransactionModel> all) {
    final now = DateTime.now();
    return List.generate(6, (i) {
      final m = DateTime(now.year, now.month - (5 - i));
      return MonthlyPoint(
        month:   m,
        income:  _sumMonth(all, m, 'income'),
        expense: _sumMonth(all, m, 'expense'),
        balance: _sumMonth(all, m, 'income') - _sumMonth(all, m, 'expense'),
      );
    });
  }

  static List<CategoryTrend> buildCategoryTrends(
      List<TransactionModel> all) {
    final now    = DateTime.now();
    final months = List.generate(6, (i) => DateTime(now.year, now.month - (5 - i)));

    // Collect all categories from expense transactions
    final categories = <String>{};
    for (final t in all.where((t) => t.type == 'expense')) {
      categories.add(t.category);
    }

    return categories.map((cat) {
      final monthly = months.map((m) {
        return all
            .where((t) =>
                t.type == 'expense' &&
                t.category == cat &&
                t.date.year == m.year &&
                t.date.month == m.month)
            .fold(0.0, (s, t) => s + t.amount);
      }).toList();
      final total    = monthly.reduce((a, b) => a + b);
      final nonZero  = monthly.where((v) => v > 0).length;
      return CategoryTrend(
        category:      cat,
        monthlyAmounts: monthly,
        total:         total,
        avgMonthly:    nonZero > 0 ? total / nonZero : 0,
      );
    }).toList()
      ..sort((a, b) => b.total.compareTo(a.total));
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  static double _sum(List<TransactionModel> list, String type) =>
      list.where((t) => t.type == type).fold(0.0, (s, t) => s + t.amount);

  static double _sumMonth(
      List<TransactionModel> all, DateTime m, String type) =>
      all
          .where((t) =>
              t.type == type &&
              t.date.year == m.year &&
              t.date.month == m.month)
          .fold(0.0, (s, t) => s + t.amount);
}