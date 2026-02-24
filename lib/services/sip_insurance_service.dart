import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction_model.dart';

// ── Data classes ──────────────────────────────────────────────────────────────

class FinancialProfile {
  final double avgMonthlyIncome;
  final double avgMonthlyExpense;
  final double avgMonthlySavings;
  final double savingsRate; // %
  final double emergencyFundMonths; // how many months of expenses in savings
  final int age;
  final Map<String, double> topCategories;

  const FinancialProfile({
    required this.avgMonthlyIncome,
    required this.avgMonthlyExpense,
    required this.avgMonthlySavings,
    required this.savingsRate,
    required this.emergencyFundMonths,
    required this.age,
    required this.topCategories,
  });
}

class SuggestionCard {
  final String emoji;
  final String type; // sip | insurance | emergency | tax | general
  final String title;
  final String subtitle;
  final String body;
  final String? actionLabel;
  final String? actionValue; // e.g. calculated amount
  final SipColor color;
  final int priority; // 1=urgent, 2=recommended, 3=optional

  const SuggestionCard({
    required this.emoji,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.body,
    this.actionLabel,
    this.actionValue,
    required this.color,
    required this.priority,
  });
}

// Color values as simple ints, resolved in UI layer
class SipColor {
  final int value;
  const SipColor(this.value);
  static const red = SipColor(0xFFC62828);
  static const orange = SipColor(0xFFE65100);
  static const green = SipColor(0xFF2E7D32);
  static const blue = SipColor(0xFF1565C0);
  static const purple = SipColor(0xFF6A1B9A);
  static const teal = SipColor(0xFF00695C);
  static const amber = SipColor(0xFFF57F17);
}

// ── Main service ──────────────────────────────────────────────────────────────

class SipInsuranceService {
  static const _geminiUrl =
      'https://generativelanguage.googleapis.com/v1/models/gemini-1.5-flash-latest:generateContent';

  /// Build financial profile from last 3 months of transactions
  static FinancialProfile buildProfile(
      List<TransactionModel> transactions, int age) {
    final now = DateTime.now();
    final threeMonthsAgo =
        DateTime(now.year, now.month - 3, now.day);

    final recent = transactions
        .where((t) => t.date.isAfter(threeMonthsAgo))
        .toList();

    final months = 3.0;

    final totalIncome = recent
        .where((t) => t.type == 'income')
        .fold(0.0, (s, t) => s + t.amount);
    final totalExpense = recent
        .where((t) => t.type == 'expense')
        .fold(0.0, (s, t) => s + t.amount);

    final avgIncome = totalIncome / months;
    final avgExpense = totalExpense / months;
    final avgSavings = avgIncome - avgExpense;
    final savingsRate =
        avgIncome > 0 ? (avgSavings / avgIncome) * 100 : 0.0;

    // Category breakdown
    final catMap = <String, double>{};
    for (final t in recent.where((t) => t.type == 'expense')) {
      catMap[t.category] = (catMap[t.category] ?? 0) + t.amount;
    }
    // Normalize to monthly
    final topCats = catMap
        .map((k, v) => MapEntry(k, v / months));

    // Rough emergency fund estimate (3 months savings as proxy)
    final currentSavingsProxy = avgSavings * 3;
    final emergencyMonths =
        avgExpense > 0 ? currentSavingsProxy / avgExpense : 0.0;

    return FinancialProfile(
      avgMonthlyIncome: avgIncome,
      avgMonthlyExpense: avgExpense,
      avgMonthlySavings: avgSavings.clamp(0, double.infinity),
      savingsRate: savingsRate,
      emergencyFundMonths: emergencyMonths,
      age: age,
      topCategories: topCats,
    );
  }

  /// Generate suggestions using rule-based engine (works offline)
  static List<SuggestionCard> generateRuleBased(FinancialProfile p) {
    final cards = <SuggestionCard>[];
    final income = p.avgMonthlyIncome;
    final savings = p.avgMonthlySavings;
    final age = p.age;

    // ── 1. Emergency Fund ────────────────────────────────────────────────────
    if (p.emergencyFundMonths < 3) {
      final target = p.avgMonthlyExpense * 6;
      cards.add(SuggestionCard(
        emoji: '🛡️',
        type: 'emergency',
        priority: 1,
        color: SipColor.red,
        title: 'Build Emergency Fund First',
        subtitle: 'URGENT — Do this before investing',
        body:
            'You should have 6 months of expenses (₹${target.toStringAsFixed(0)}) saved as emergency fund before starting SIPs. '
            'Start with a liquid mutual fund or high-interest savings account.',
        actionLabel: 'Target Amount',
        actionValue: '₹${target.toStringAsFixed(0)}',
      ));
    }

    // ── 2. Term Insurance ────────────────────────────────────────────────────
    if (income > 0 && age < 55) {
      final coverNeeded = income * 12 * 10; // 10x annual income
      final avgPremium = age < 30
          ? 8000.0
          : age < 40
              ? 12000.0
              : 20000.0;
      cards.add(SuggestionCard(
        emoji: '🔒',
        type: 'insurance',
        priority: 1,
        color: SipColor.blue,
        title: 'Term Life Insurance',
        subtitle: 'Protect your family — ₹${(avgPremium / 12).toStringAsFixed(0)}/month',
        body:
            'Based on your income of ₹${income.toStringAsFixed(0)}/month, you need at least '
            '₹${(coverNeeded / 100000).toStringAsFixed(0)} Lakh term cover. '
            'At age $age, a 1 Crore policy costs approx ₹${avgPremium.toStringAsFixed(0)}/year. '
            'Recommended: LIC Tech Term, HDFC Life Click 2 Protect, ICICI iProtect Smart.',
        actionLabel: 'Suggested Cover',
        actionValue: '₹${(coverNeeded / 100000).toStringAsFixed(0)} Lakh',
      ));
    }

    // ── 3. Health Insurance ──────────────────────────────────────────────────
    cards.add(SuggestionCard(
      emoji: '🏥',
      type: 'insurance',
      priority: 1,
      color: SipColor.green,
      title: 'Health Insurance',
      subtitle: 'Medical cover for you & family',
      body: age < 35
          ? 'At your age, a ₹10 Lakh family floater costs just ₹600–900/month. '
              'Don\'t rely only on employer insurance. '
              'Recommended: Niva Bupa (formerly Max Bupa), Star Health, HDFC Ergo Optima.'
          : 'Consider ₹20–25 Lakh cover as medical costs rise with age. '
              'Add a super top-up for extra coverage at low cost. '
              'Recommended: Niva Bupa ReAssure, Care Supreme, Aditya Birla Activ.',
      actionLabel: 'Min. Cover',
      actionValue: age < 35 ? '₹10 Lakh' : '₹20 Lakh',
    ));

    // ── 4. SIP Suggestions ───────────────────────────────────────────────────
    if (savings > 0) {
      final sipAmount = (savings * 0.6).clamp(500, 50000).toDouble(); // 60% of savings
      final sipReturn = 12.0; // assumed CAGR %
      final years = (60 - age).clamp(5, 35).toDouble();
      final months = years * 12;
      final futureValue =
          sipAmount * ((pow(1 + sipReturn / 1200, months) - 1) /
                  (sipReturn / 1200)) *
              (1 + sipReturn / 1200);

      cards.add(SuggestionCard(
        emoji: '📈',
        type: 'sip',
        priority: 2,
        color: SipColor.purple,
        title: 'Start a Monthly SIP',
        subtitle:
            '₹${sipAmount.toStringAsFixed(0)}/month can grow to ₹${_formatCrore(futureValue)} in $years years',
        body: _sipBodyByAge(age, sipAmount, income),
        actionLabel: 'Suggested SIP',
        actionValue: '₹${sipAmount.toStringAsFixed(0)}/month',
      ));
    }

    // ── 5. PPF / NPS ─────────────────────────────────────────────────────────
    if (income > 20000 && age < 50) {
      final ppfAmount =
          (income * 0.1).clamp(500, 12500).toDouble(); // Max 1.5L/year
      cards.add(SuggestionCard(
        emoji: '💼',
        type: 'tax',
        priority: 2,
        color: SipColor.teal,
        title: 'PPF / NPS for Tax Saving',
        subtitle: 'Save tax + build retirement corpus',
        body:
            'PPF gives 7.1% tax-free returns. NPS gives extra ₹50,000 deduction under 80CCD(1B). '
            'Invest ₹${ppfAmount.toStringAsFixed(0)}/month in PPF to save ₹${(ppfAmount * 12 * 0.30).toStringAsFixed(0)}/year in taxes (30% bracket). '
            'Start with SBI PPF account (free) or NPS via eNPS portal.',
        actionLabel: 'Monthly PPF',
        actionValue: '₹${ppfAmount.toStringAsFixed(0)}/month',
      ));
    }

    // ── 6. 50-30-20 Rule check ───────────────────────────────────────────────
    if (income > 0) {
      final expensePct = (p.avgMonthlyExpense / income) * 100;
      if (expensePct > 70) {
        cards.add(SuggestionCard(
          emoji: '⚖️',
          type: 'general',
          priority: 2,
          color: SipColor.orange,
          title: '50-30-20 Budget Rule',
          subtitle: 'Your expenses are ${expensePct.toStringAsFixed(0)}% of income',
          body:
              'You\'re spending ${expensePct.toStringAsFixed(0)}% of income on expenses. '
              'The ideal split is: 50% needs, 30% wants, 20% savings & investments. '
              'Try reducing discretionary spend by ₹${((expensePct - 50) / 100 * income).toStringAsFixed(0)}/month.',
          actionLabel: 'Target Savings',
          actionValue: '₹${(income * 0.20).toStringAsFixed(0)}/month',
        ));
      }
    }

    // ── 7. Top category-specific advice ─────────────────────────────────────
    if (p.topCategories.containsKey('Entertainment') &&
        (p.topCategories['Entertainment'] ?? 0) > income * 0.1) {
      final amt = p.topCategories['Entertainment']!;
      cards.add(SuggestionCard(
        emoji: '🎬',
        type: 'general',
        priority: 3,
        color: SipColor.amber,
        title: 'High Entertainment Spend',
        subtitle:
            '₹${amt.toStringAsFixed(0)}/month on entertainment',
        body:
            'You spend ${((amt / income) * 100).toStringAsFixed(0)}% of income on entertainment. '
            'Consider bundling OTT subscriptions (YouTube Premium includes YouTube Music) and reviewing unused subscriptions.',
        actionLabel: 'Potential Save',
        actionValue:
            '₹${(amt * 0.3).toStringAsFixed(0)}/month',
      ));
    }

    // Sort by priority
    cards.sort((a, b) => a.priority.compareTo(b.priority));
    return cards;
  }

  static String _sipBodyByAge(int age, double sip, double income) {
    if (age < 30) {
      return 'You\'re young — time is your biggest asset! Start with:\n'
          '• 50% Nifty 50 Index Fund (low cost, market returns)\n'
          '• 30% Flexi Cap Fund (growth)\n'
          '• 20% Mid Cap Fund (higher growth)\n'
          'Recommended: Mirae Asset Large Cap, Parag Parikh Flexi Cap, Axis Midcap.';
    } else if (age < 40) {
      return 'Balance growth with some stability:\n'
          '• 40% Large Cap / Index Fund\n'
          '• 30% Balanced Advantage Fund\n'
          '• 20% Mid Cap\n'
          '• 10% Debt Fund\n'
          'Recommended: HDFC Balanced Advantage, SBI Nifty Index, Kotak Emerging Equity.';
    } else if (age < 50) {
      return 'Shift towards stability as retirement approaches:\n'
          '• 50% Large Cap / Index Fund\n'
          '• 30% Balanced Advantage / Hybrid Fund\n'
          '• 20% Short Duration Debt Fund\n'
          'Recommended: ICICI Pru Balanced Advantage, UTI Nifty 50 Index.';
    } else {
      return 'Focus on capital preservation:\n'
          '• 30% Large Cap Fund\n'
          '• 40% Hybrid/Balanced Fund\n'
          '• 30% Debt / FD\n'
          'Consider Senior Citizen Savings Scheme (SCSS) for guaranteed returns.';
    }
  }

  static String _formatCrore(double amount) {
    if (amount >= 10000000) {
      return '₹${(amount / 10000000).toStringAsFixed(1)} Cr';
    } else if (amount >= 100000) {
      return '₹${(amount / 100000).toStringAsFixed(1)} L';
    }
    return '₹${amount.toStringAsFixed(0)}';
  }

  static double pow(double base, double exp) {
    double result = 1;
    for (int i = 0; i < exp; i++) {
      result *= base;
    }
    return result;
  }

  /// Generate AI suggestions via Gemini
  static Future<String> generateGeminiSuggestions(
      FinancialProfile p, String apiKey) async {
    final prompt = '''
You are a SEBI-registered Indian financial advisor AI. Analyze this person's financial profile and give 3-5 specific, actionable suggestions for SIP investments and insurance in India.

Financial Profile:
- Monthly Income: ₹${p.avgMonthlyIncome.toStringAsFixed(0)}
- Monthly Expenses: ₹${p.avgMonthlyExpense.toStringAsFixed(0)}
- Monthly Savings: ₹${p.avgMonthlySavings.toStringAsFixed(0)}
- Savings Rate: ${p.savingsRate.toStringAsFixed(1)}%
- Age: ${p.age} years
- Top Spending: ${p.topCategories.entries.take(3).map((e) => '${e.key}: ₹${e.value.toStringAsFixed(0)}').join(', ')}

Give advice specific to:
1. How much to invest in SIP monthly (exact amount)
2. Which mutual fund categories are right for their age
3. Insurance gaps (term + health)
4. Tax saving opportunities (80C, 80D)
5. One specific concern based on their spending pattern

Format: 3-5 short paragraphs. Use ₹ symbol. Mention specific Indian fund names/insurers. Keep it practical and specific to their numbers. Do NOT give generic advice.
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
            'temperature': 0.3,
            'maxOutputTokens': 600,
          }
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['candidates'][0]['content']['parts'][0]['text'] as String;
      }
      return '';
    } catch (e) {
      return '';
    }
  }

  static Future<String?> getSavedApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('gemini_api_key');
  }
}