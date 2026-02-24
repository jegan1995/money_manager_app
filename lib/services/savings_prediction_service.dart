import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction_model.dart';

// ── Data classes ──────────────────────────────────────────────────────────────

class MonthlySnapshot {
  final String label; // e.g. "Mar 2025"
  final double income;
  final double expense;
  final double savings;
  const MonthlySnapshot({
    required this.label,
    required this.income,
    required this.expense,
    required this.savings,
  });
}

class PredictionScenario {
  final String name;
  final String emoji;
  final String description;
  final double monthlyIncome;
  final double monthlyExpense;
  final double monthlySavings;
  final double incomeGrowthRate; // % per year
  final double expenseGrowthRate; // % per year
  final List<double> cumulativeSavings; // 12 months forecast
  final List<double> monthlySavingsList; // per month
  final String insight;

  const PredictionScenario({
    required this.name,
    required this.emoji,
    required this.description,
    required this.monthlyIncome,
    required this.monthlyExpense,
    required this.monthlySavings,
    required this.incomeGrowthRate,
    required this.expenseGrowthRate,
    required this.cumulativeSavings,
    required this.monthlySavingsList,
    required this.insight,
  });

  double get total12Months => cumulativeSavings.last;
}

class GoalForecast {
  final String goalName;
  final double targetAmount;
  final double currentAmount;
  final double monthlyContribution;
  final int monthsToReach; // -1 if unreachable
  final DateTime? estimatedDate;
  const GoalForecast({
    required this.goalName,
    required this.targetAmount,
    required this.currentAmount,
    required this.monthlyContribution,
    required this.monthsToReach,
    this.estimatedDate,
  });
  double get remaining => targetAmount - currentAmount;
  bool get isReachable => monthsToReach > 0;
}

// ── Main Service ──────────────────────────────────────────────────────────────

class SavingsPredictionService {
  static const _geminiUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';

  /// Build monthly snapshots from transactions (last 6 months)
  static List<MonthlySnapshot> buildMonthlyHistory(
      List<TransactionModel> transactions) {
    final now = DateTime.now();
    final snapshots = <MonthlySnapshot>[];

    for (int i = 5; i >= 0; i--) {
      final monthDate = DateTime(now.year, now.month - i, 1);
      final monthEnd = DateTime(monthDate.year, monthDate.month + 1, 1);

      final monthTxns = transactions.where((t) =>
          t.date.isAfter(monthDate.subtract(const Duration(days: 1))) &&
          t.date.isBefore(monthEnd));

      final income = monthTxns
          .where((t) => t.type == 'income')
          .fold(0.0, (s, t) => s + t.amount);
      final expense = monthTxns
          .where((t) => t.type == 'expense')
          .fold(0.0, (s, t) => s + t.amount);

      snapshots.add(MonthlySnapshot(
        label: _monthLabel(monthDate),
        income: income,
        expense: expense,
        savings: income - expense,
      ));
    }
    return snapshots;
  }

  /// Calculate trend slope using linear regression
  static double _trendSlope(List<double> values) {
    if (values.length < 2) return 0;
    final n = values.length;
    double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
    for (int i = 0; i < n; i++) {
      sumX += i;
      sumY += values[i];
      sumXY += i * values[i];
      sumX2 += i * i;
    }
    final denom = n * sumX2 - sumX * sumX;
    if (denom == 0) return 0;
    return (n * sumXY - sumX * sumY) / denom;
  }

  /// Generate 3 prediction scenarios
  static List<PredictionScenario> generateScenarios(
      List<MonthlySnapshot> history) {
    if (history.isEmpty) return [];

    // Use last 3 months average as baseline (ignore zero months)
    final nonZero = history.where((h) => h.income > 0 || h.expense > 0).toList();
    final useMonths = nonZero.isEmpty ? history : nonZero;
    final recent = useMonths.length >= 3
        ? useMonths.sublist(useMonths.length - 3)
        : useMonths;

    final avgIncome =
        recent.fold(0.0, (s, h) => s + h.income) / recent.length;
    final avgExpense =
        recent.fold(0.0, (s, h) => s + h.expense) / recent.length;

    // Income trend slope
    final incomeValues = history.map((h) => h.income).toList();
    final expenseValues = history.map((h) => h.expense).toList();
    final incomeSlope = _trendSlope(incomeValues);
    final expenseSlope = _trendSlope(expenseValues);

    // Scenario 1: Pessimistic (expenses grow 5%, income flat)
    final s1 = _buildScenario(
      name: 'Pessimistic',
      emoji: '😟',
      description: 'If expenses grow 5% but income stays flat',
      baseIncome: avgIncome,
      baseExpense: avgExpense,
      incomeGrowthYearly: 0,
      expenseGrowthYearly: 5,
      insight: avgIncome > 0
          ? 'At this rate, your savings will shrink. Consider cutting discretionary spend by '
              '₹${((avgExpense * 0.05)).toStringAsFixed(0)}/month to stay positive.'
          : 'Add income transactions to see predictions.',
    );

    // Scenario 2: Realistic (based on actual trend)
    final incomeGrowth =
        avgIncome > 0 ? ((incomeSlope / avgIncome) * 100 * 12).clamp(-10, 20).toDouble() : 3.0;
    final expenseGrowth =
        avgExpense > 0 ? ((expenseSlope / avgExpense) * 100 * 12).clamp(-5, 15).toDouble() : 3.0;
    final s2 = _buildScenario(
      name: 'Realistic',
      emoji: '📊',
      description: 'Based on your actual spending trend',
      baseIncome: avgIncome,
      baseExpense: avgExpense,
      incomeGrowthYearly: incomeGrowth,
      expenseGrowthYearly: expenseGrowth,
      insight:
          'Based on last 6 months trend: income ${incomeGrowth >= 0 ? '+' : ''}${incomeGrowth.toStringAsFixed(1)}%/yr, '
          'expenses ${expenseGrowth >= 0 ? '+' : ''}${expenseGrowth.toStringAsFixed(1)}%/yr.',
    );

    // Scenario 3: Optimistic (income grows 10%, expenses cut 10%)
    final s3 = _buildScenario(
      name: 'Optimistic',
      emoji: '🚀',
      description: 'If you cut expenses 10% and income grows',
      baseIncome: avgIncome,
      baseExpense: avgExpense * 0.9, // 10% cut
      incomeGrowthYearly: 10,
      expenseGrowthYearly: 2,
      insight:
          'Cutting expenses by just ₹${(avgExpense * 0.10).toStringAsFixed(0)}/month '
          'and a 10% income raise could save you ₹${((avgIncome * 1.10 - avgExpense * 0.90) * 12).toStringAsFixed(0)} extra this year!',
    );

    return [s1, s2, s3];
  }

  static PredictionScenario _buildScenario({
    required String name,
    required String emoji,
    required String description,
    required double baseIncome,
    required double baseExpense,
    required double incomeGrowthYearly,
    required double expenseGrowthYearly,
    required String insight,
  }) {
    final monthlyIncomeGrowth = incomeGrowthYearly / 100 / 12;
    final monthlyExpenseGrowth = expenseGrowthYearly / 100 / 12;

    final cumulativeSavings = <double>[];
    final monthlySavingsList = <double>[];
    double cumulative = 0;

    for (int m = 0; m < 12; m++) {
      final projectedIncome =
          baseIncome * math.pow(1 + monthlyIncomeGrowth, m + 1);
      final projectedExpense =
          baseExpense * math.pow(1 + monthlyExpenseGrowth, m + 1);
      final monthlySaving = projectedIncome - projectedExpense;
      cumulative += monthlySaving;
      monthlySavingsList.add(monthlySaving);
      cumulativeSavings.add(cumulative);
    }

    return PredictionScenario(
      name: name,
      emoji: emoji,
      description: description,
      monthlyIncome: baseIncome,
      monthlyExpense: baseExpense,
      monthlySavings: baseIncome - baseExpense,
      incomeGrowthRate: incomeGrowthYearly,
      expenseGrowthRate: expenseGrowthYearly,
      cumulativeSavings: cumulativeSavings,
      monthlySavingsList: monthlySavingsList,
      insight: insight,
    );
  }

  /// Calculate months to reach a goal given monthly savings
  static GoalForecast forecastGoal({
    required String goalName,
    required double targetAmount,
    required double currentAmount,
    required double monthlySavings,
    required double allocationPercent, // % of savings to this goal
  }) {
    final contribution = monthlySavings * (allocationPercent / 100);
    if (contribution <= 0) {
      return GoalForecast(
        goalName: goalName,
        targetAmount: targetAmount,
        currentAmount: currentAmount,
        monthlyContribution: 0,
        monthsToReach: -1,
      );
    }
    final remaining = targetAmount - currentAmount;
    if (remaining <= 0) {
      return GoalForecast(
        goalName: goalName,
        targetAmount: targetAmount,
        currentAmount: currentAmount,
        monthlyContribution: contribution,
        monthsToReach: 0,
        estimatedDate: DateTime.now(),
      );
    }
    final months = (remaining / contribution).ceil();
    final estimatedDate = DateTime(
      DateTime.now().year,
      DateTime.now().month + months,
    );
    return GoalForecast(
      goalName: goalName,
      targetAmount: targetAmount,
      currentAmount: currentAmount,
      monthlyContribution: contribution,
      monthsToReach: months,
      estimatedDate: estimatedDate,
    );
  }

  /// Gemini AI prediction narrative
  static Future<String> getAiNarrative({
    required List<MonthlySnapshot> history,
    required List<PredictionScenario> scenarios,
    required String apiKey,
  }) async {
    final historyText = history
        .map((h) =>
            '${h.label}: Income ₹${h.income.toStringAsFixed(0)}, Expense ₹${h.expense.toStringAsFixed(0)}, Saved ₹${h.savings.toStringAsFixed(0)}')
        .join('\n');

    final realisticScenario =
        scenarios.length > 1 ? scenarios[1] : null;
    final projected12 =
        realisticScenario?.total12Months.toStringAsFixed(0) ?? 'N/A';

    final prompt = '''
You are an Indian personal finance coach. Analyze this person's 6-month financial history and give a 3-paragraph prediction narrative.

History:
$historyText

Realistic 12-month savings projection: ₹$projected12

Write 3 short paragraphs:
1. What the trend shows (positive/negative, consistent/volatile)
2. One specific action they can take to improve savings next month (with ₹ amount)
3. Where they could be in 12 months if they follow the optimistic scenario

Keep it encouraging, specific, and use ₹ amounts. Do NOT be generic. Max 120 words total.
''';

    try {
      final response = await http.post(
        Uri.parse('$_geminiUrl?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.4,
            'maxOutputTokens': 250,
          }
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['candidates'][0]['content']['parts'][0]['text']
            as String;
      }
      return '';
    } catch (_) {
      return '';
    }
  }

  static Future<String?> getSavedApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('gemini_api_key');
  }

  static String _monthLabel(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[d.month - 1]} ${d.year}';
  }

  static String formatAmount(double v) {
    if (v.abs() >= 10000000) return '₹${(v / 10000000).toStringAsFixed(1)}Cr';
    if (v.abs() >= 100000) return '₹${(v / 100000).toStringAsFixed(1)}L';
    if (v.abs() >= 1000) return '₹${(v / 1000).toStringAsFixed(1)}k';
    return '₹${v.toStringAsFixed(0)}';
  }
}