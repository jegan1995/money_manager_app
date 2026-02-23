import 'package:flutter/material.dart';
import '../models/transaction_model.dart';
import '../services/transaction_service.dart';
import '../services/sip_insurance_service.dart';

class SipInsuranceScreen extends StatefulWidget {
  const SipInsuranceScreen({super.key});

  @override
  State<SipInsuranceScreen> createState() => _SipInsuranceScreenState();
}

class _SipInsuranceScreenState extends State<SipInsuranceScreen> {
  final _txnService = TransactionService();

  bool _loading = true;
  bool _aiLoading = false;
  bool _showAgeInput = false;

  List<TransactionModel> _transactions = [];
  FinancialProfile? _profile;
  List<SuggestionCard> _cards = [];
  String _aiResponse = '';
  String? _apiKey;
  int _age = 28;

  final _ageController = TextEditingController(text: '28');

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    setState(() => _loading = true);
    _apiKey = await SipInsuranceService.getSavedApiKey();
    final txns = await _txnService.getTransactionsList();
    setState(() {
      _transactions = txns;
      _loading = false;
      _showAgeInput = true; // Ask age first
    });
  }

  void _generate() {
    final age = int.tryParse(_ageController.text) ?? 28;
    setState(() {
      _age = age;
      _showAgeInput = false;
      _profile = SipInsuranceService.buildProfile(_transactions, age);
      _cards = SipInsuranceService.generateRuleBased(_profile!);
    });

    // If API key available, also fetch AI suggestions
    if (_apiKey != null && _apiKey!.isNotEmpty) {
      _fetchAI();
    }
  }

  Future<void> _fetchAI() async {
    if (_profile == null || _apiKey == null) return;
    setState(() => _aiLoading = true);
    final result = await SipInsuranceService.generateGeminiSuggestions(
        _profile!, _apiKey!);
    setState(() {
      _aiResponse = result;
      _aiLoading = false;
    });
  }

  Color _cardFlutterColor(SuggestionCard card) {
    switch (card.color.value) {
      case 0xFFC62828: return const Color(0xFFC62828);
      case 0xFFE65100: return const Color(0xFFE65100);
      case 0xFF2E7D32: return const Color(0xFF2E7D32);
      case 0xFF1565C0: return const Color(0xFF1565C0);
      case 0xFF6A1B9A: return const Color(0xFF6A1B9A);
      case 0xFF00695C: return const Color(0xFF00695C);
      case 0xFFF57F17: return const Color(0xFFF57F17);
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('SIP & Insurance Advisor'),
        actions: [
          if (_profile != null)
            IconButton(
              icon: const Icon(Icons.tune),
              tooltip: 'Change age',
              onPressed: () => setState(() => _showAgeInput = true),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _showAgeInput
              ? _buildAgeInput(theme, isDark)
              : _buildSuggestions(theme, isDark),
    );
  }

  // ── Age Input ────────────────────────────────────────────────────────────────
  Widget _buildAgeInput(ThemeData theme, bool isDark) {
    final hasData = _transactions.isNotEmpty;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Header
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6A1B9A), Color(0xFF1565C0)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Center(
                child: Text('💡', style: TextStyle(fontSize: 38)),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'AI Financial Advisor',
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Get personalized SIP, insurance & tax-saving\nsuggestions based on your actual spending.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], height: 1.5),
            ),
            const SizedBox(height: 32),

            if (!hasData)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: Colors.orange.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Add some transactions first for better suggestions. '
                        'We\'ll still show general advice.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            if (!hasData) const SizedBox(height: 20),

            // Age input
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'What is your age?',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Used to calculate insurance needs and SIP horizon',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _ageController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 36, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      hintText: '28',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      suffix: const Text('years'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Generate button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _generate,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Get My Suggestions'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  backgroundColor: const Color(0xFF6A1B9A),
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),

            if (_apiKey != null) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.auto_awesome,
                      size: 14, color: Color(0xFF4285F4)),
                  const SizedBox(width: 4),
                  Text(
                    'Gemini AI will add personalized tips',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Suggestions ───────────────────────────────────────────────────────────────
  Widget _buildSuggestions(ThemeData theme, bool isDark) {
    final p = _profile!;

    return RefreshIndicator(
      onRefresh: () async {
        _generate();
        if (_apiKey != null) await _fetchAI();
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile summary banner
          _buildProfileBanner(p, isDark),
          const SizedBox(height: 20),

          // AI response (if available)
          if (_aiLoading) ...[
            _buildAiLoadingCard(isDark),
            const SizedBox(height: 16),
          ],
          if (_aiResponse.isNotEmpty) ...[
            _buildAiCard(_aiResponse, isDark),
            const SizedBox(height: 16),
          ],

          // Priority section header
          _sectionLabel('📌 Recommendations for You', theme),
          const SizedBox(height: 10),

          // Suggestion cards
          ..._cards.map((card) => _buildCard(card, theme, isDark)),

          // Disclaimer
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '⚠️ Disclaimer: These are AI-generated suggestions for educational purposes only. '
              'Please consult a SEBI-registered financial advisor before making investment decisions.',
              style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                  height: 1.4),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildProfileBanner(FinancialProfile p, bool isDark) {
    final savingsColor = p.savingsRate >= 20
        ? Colors.green
        : p.savingsRate >= 10
            ? Colors.orange
            : Colors.red;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6A1B9A), Color(0xFF1565C0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('💡', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(
                'Based on last 3 months • Age $_age',
                style: const TextStyle(
                    color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _bannerStat(
                  'Income/mo',
                  '₹${_fmt(p.avgMonthlyIncome)}',
                  Colors.white),
              _bannerDiv(),
              _bannerStat(
                  'Expense/mo',
                  '₹${_fmt(p.avgMonthlyExpense)}',
                  Colors.white),
              _bannerDiv(),
              _bannerStat(
                  'Savings',
                  '${p.savingsRate.toStringAsFixed(0)}%',
                  savingsColor == Colors.green
                      ? Colors.greenAccent
                      : savingsColor == Colors.orange
                          ? Colors.orangeAccent
                          : Colors.redAccent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bannerStat(String label, String value, Color valueColor) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  color: valueColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  color: Colors.white60, fontSize: 11),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _bannerDiv() => Container(
      width: 1, height: 36, color: Colors.white24);

  Widget _buildAiLoadingCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: const Color(0xFF4285F4).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFF4285F4),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('✨ Gemini AI analyzing your profile...',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF4285F4))),
              Text('Generating personalized tips',
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey[500])),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAiCard(String text, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A237E).withOpacity(0.3) : const Color(0xFFE8EAF6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: const Color(0xFF3F51B5).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('✨', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              const Text(
                'Gemini AI Personalized Advice',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Color(0xFF3F51B5),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF4285F4).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('AI',
                    style: TextStyle(
                        fontSize: 10,
                        color: Color(0xFF4285F4),
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const Divider(height: 16),
          Text(
            text,
            style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white70 : Colors.black87,
                height: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(
      SuggestionCard card, ThemeData theme, bool isDark) {
    final color = _cardFlutterColor(card);
    final priorityLabel = card.priority == 1
        ? 'URGENT'
        : card.priority == 2
            ? 'RECOMMENDED'
            : 'OPTIONAL';
    final priorityColor = card.priority == 1
        ? Colors.red
        : card.priority == 2
            ? Colors.orange
            : Colors.grey;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.07),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Text(card.emoji,
                    style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(card.title,
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: color)),
                      Text(card.subtitle,
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600])),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: priorityColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: priorityColor.withOpacity(0.3)),
                  ),
                  child: Text(priorityLabel,
                      style: TextStyle(
                          fontSize: 9,
                          color: priorityColor,
                          fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ),

          // Body
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(card.body,
                    style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? Colors.white70
                            : Colors.black87,
                        height: 1.5)),
                if (card.actionLabel != null &&
                    card.actionValue != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: color.withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${card.actionLabel}: ',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600]),
                        ),
                        Text(
                          card.actionValue!,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: color),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text, ThemeData theme) => Text(
        text,
        style: theme.textTheme.titleMedium
            ?.copyWith(fontWeight: FontWeight.bold),
      );

  String _fmt(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toStringAsFixed(0);
  }
}