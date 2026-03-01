// lib/screens/enhanced_reports_screen.dart
// Rebuilt as a 5-tab screen:
//   Overview  │  AI Insights  │  Health Score  │  Cashflow  │  Trends

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction_model.dart';
import '../services/transaction_service.dart';
import '../services/analytics_service.dart';
import 'tax_calculator_tab.dart';

// Currency formatter
final _fmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
String _f(double v) => _fmt.format(v);

// Month label
String _monthLabel(DateTime m, {bool short = true}) =>
    short ? DateFormat('MMM').format(m) : DateFormat('MMM yy').format(m);

class EnhancedReportsScreen extends StatefulWidget {
  const EnhancedReportsScreen({super.key});
  @override
  State<EnhancedReportsScreen> createState() => _EnhancedReportsScreenState();
}

class _EnhancedReportsScreenState extends State<EnhancedReportsScreen>
    with SingleTickerProviderStateMixin {
  final _svc = TransactionService();
  late TabController _tab;

  // ── Data ──────────────────────────────────────────────────────────────────
  bool   _loading          = true;
  List<TransactionModel> _all  = [];
  List<TransactionModel> _filtered = [];
  String _period           = 'This Month';
  final  _periods          = ['This Week', 'This Month', 'Last Month', 'This Year'];

  // ── AI / Claude ───────────────────────────────────────────────────────────
  bool   _aiLoading        = false;
  String? _aiResult;
  String? _aiError;
  String  _apiKey          = '';
  bool    _showApiKeyField = false;
  List<SpendingInsight> _ruleInsights = [];

  // ── Health & forecast ─────────────────────────────────────────────────────
  FinancialHealthScore? _health;
  List<MonthlyPoint>    _forecast = [];
  List<MonthlyPoint>    _trend    = [];
  List<CategoryTrend>   _catTrend = [];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 6, vsync: this, initialIndex: 0);
    _loadApiKey();
    _loadData();
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  Future<void> _loadApiKey() async {
    final p = await SharedPreferences.getInstance();
    setState(() => _apiKey = p.getString('claude_api_key') ?? '');
  }

  Future<void> _saveApiKey(String key) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('claude_api_key', key);
    setState(() { _apiKey = key; _showApiKeyField = false; });
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final txns = await _svc.getTransactionsList();
    setState(() {
      _all       = txns;
      _health    = AnalyticsService.computeHealthScore(txns);
      _forecast  = AnalyticsService.buildCashflowForecast(txns);
      _trend     = AnalyticsService.buildMonthlyTrend(txns);
      _catTrend  = AnalyticsService.buildCategoryTrends(txns);
      _ruleInsights = AnalyticsService.generateInsights(txns);
      _filterByPeriod();
      _loading   = false;
    });
  }

  void _filterByPeriod() {
    final now = DateTime.now();
    DateTime start;
    DateTime? end;
    switch (_period) {
      case 'This Week':
        start = now.subtract(Duration(days: now.weekday - 1));
      case 'Last Month':
        start = DateTime(now.year, now.month - 1, 1);
        end   = DateTime(now.year, now.month, 1);
      case 'This Year':
        start = DateTime(now.year, 1, 1);
      default: // This Month
        start = DateTime(now.year, now.month, 1);
    }
    setState(() {
      _filtered = _all.where((t) =>
          t.date.isAfter(start) &&
          (end == null || t.date.isBefore(end!))).toList();
    });
  }

  Future<void> _runClaudeAI() async {
    if (_apiKey.isEmpty && !kIsWeb) {
      setState(() => _showApiKeyField = true);
      return;
    }
    setState(() { _aiLoading = true; _aiError = null; _aiResult = null; });
    try {
      final result = await AnalyticsService.fetchClaudeInsights(
        transactions: _all,
        apiKey: _apiKey,
      );
      setState(() { _aiLoading = false; _aiResult = result; });
    } catch (e) {
      setState(() { _aiLoading = false; _aiError = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E2530) : Colors.white;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D1117) : const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('Reports & Analytics',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: isDark ? const Color(0xFF1E2530) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        elevation: 0,
        bottom: TabBar(
          controller: _tab,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: const Color(0xFF667eea),
          labelColor: const Color(0xFF667eea),
          unselectedLabelColor: Colors.grey,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          tabs: const [
            Tab(text: '📊 Overview'),
            Tab(text: '🤖 AI Insights'),
            Tab(text: '💯 Health'),
            Tab(text: '📈 Cashflow'),
            Tab(text: '📉 Trends'),
            Tab(text: '🧾 Tax'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tab,
              children: [
                _OverviewTab(
                  filtered: _filtered,
                  periods: _periods,
                  period: _period,
                  onPeriodChange: (p) {
                    setState(() => _period = p);
                    _filterByPeriod();
                  },
                  cardBg: cardBg,
                  isDark: isDark,
                ),
                _InsightsTab(
                  ruleInsights: _ruleInsights,
                  aiLoading: _aiLoading,
                  aiResult: _aiResult,
                  aiError: _aiError,
                  apiKey: _apiKey,
                  showApiKeyField: _showApiKeyField,
                  onRunAI: _runClaudeAI,
                  onSaveKey: _saveApiKey,
                  onShowKeyField: () => setState(() => _showApiKeyField = true),
                  cardBg: cardBg,
                  isDark: isDark,
                ),
                _HealthTab(
                  health: _health,
                  cardBg: cardBg,
                  isDark: isDark,
                ),
                _CashflowTab(
                  forecast: _forecast,
                  cardBg: cardBg,
                  isDark: isDark,
                ),
                _TrendsTab(
                  trend: _trend,
                  catTrend: _catTrend,
                  cardBg: cardBg,
                  isDark: isDark,
                ),
                const TaxCalculatorTab(),
              ],
            ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// TAB 1 — OVERVIEW
// ════════════════════════════════════════════════════════════════════════
class _OverviewTab extends StatelessWidget {
  final List<TransactionModel> filtered;
  final List<String> periods;
  final String period;
  final void Function(String) onPeriodChange;
  final Color cardBg;
  final bool isDark;

  const _OverviewTab({
    required this.filtered, required this.periods, required this.period,
    required this.onPeriodChange, required this.cardBg, required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final income  = filtered.where((t) => t.type == 'income').fold(0.0, (s, t) => s + t.amount);
    final expense = filtered.where((t) => t.type == 'expense').fold(0.0, (s, t) => s + t.amount);
    final balance = income - expense;

    final catMap = <String, double>{};
    for (final t in filtered.where((t) => t.type == 'expense')) {
      catMap[t.category] = (catMap[t.category] ?? 0) + t.amount;
    }
    final sortedCats = catMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    const colors = [
      Color(0xFF667eea), Color(0xFFf093fb), Color(0xFF4facfe),
      Color(0xFF43e97b), Color(0xFFfa709a), Color(0xFFffecd2),
      Color(0xFFa18cd1), Color(0xFFfda085),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Period selector
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.07) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: periods.map((p) {
            final sel = p == period;
            return Expanded(child: GestureDetector(
              onTap: () => onPeriodChange(p),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: sel ? const Color(0xFF667eea) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  p.replaceAll('This ', '').replaceAll('Last ', 'L.'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: sel ? Colors.white : Colors.grey,
                    fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                    fontSize: 11,
                  ),
                ),
              ),
            ));
          }).toList()),
        ),
        const SizedBox(height: 16),

        // 3 summary cards
        Row(children: [
          _statCard('Income', income, Colors.green, Icons.arrow_upward, cardBg),
          const SizedBox(width: 10),
          _statCard('Expense', expense, Colors.red, Icons.arrow_downward, cardBg),
          const SizedBox(width: 10),
          _statCard('Balance', balance,
              balance >= 0 ? Colors.blue : Colors.orange,
              Icons.account_balance_wallet, cardBg),
        ]),
        const SizedBox(height: 20),

        // Expense pie chart
        if (expense > 0 && sortedCats.isNotEmpty) ...[
          _sectionTitle('Expense Breakdown', isDark),
          const SizedBox(height: 12),
          Container(
            height: 240,
            padding: const EdgeInsets.all(16),
            decoration: _card(cardBg),
            child: Row(children: [
              Expanded(flex: 3, child: PieChart(PieChartData(
                sections: sortedCats.take(6).toList().asMap().entries.map((e) {
                  final pct = e.value.value / expense * 100;
                  return PieChartSectionData(
                    value:  e.value.value,
                    color:  colors[e.key % colors.length],
                    radius: 56,
                    title:  '${pct.toStringAsFixed(0)}%',
                    titleStyle: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                  );
                }).toList(),
                sectionsSpace: 2,
                centerSpaceRadius: 38,
              ))),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: sortedCats.take(6).toList().asMap().entries.map((e) =>
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(children: [
                      Container(width: 10, height: 10,
                          decoration: BoxDecoration(
                              color: colors[e.key % colors.length],
                              shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Expanded(child: Text(e.value.key,
                          style: const TextStyle(fontSize: 10),
                          overflow: TextOverflow.ellipsis)),
                    ]),
                  )
                ).toList(),
              )),
            ]),
          ),
          const SizedBox(height: 20),
        ],

        // Income vs Expense bar
        _sectionTitle('Income vs Expense', isDark),
        const SizedBox(height: 12),
        Container(
          height: 180,
          padding: const EdgeInsets.all(16),
          decoration: _card(cardBg),
          child: BarChart(BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: (income > expense ? income : expense) * 1.2 + 1,
            barTouchData: BarTouchData(enabled: false),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, _) => Text(
                  v.toInt() == 0 ? 'Income' : 'Expense',
                  style: const TextStyle(fontSize: 11)),
              )),
              leftTitles: AxisTitles(sideTitles: SideTitles(
                showTitles: true, reservedSize: 44,
                getTitlesWidget: (v, _) => Text(
                  '₹${(v / 1000).toStringAsFixed(0)}k',
                  style: const TextStyle(fontSize: 9)),
              )),
              topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            gridData:   FlGridData(show: true, drawVerticalLine: false),
            borderData: FlBorderData(show: false),
            barGroups: [
              BarChartGroupData(x: 0, barRods: [BarChartRodData(
                toY: income, color: Colors.green, width: 36,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
              )]),
              BarChartGroupData(x: 1, barRods: [BarChartRodData(
                toY: expense, color: Colors.red, width: 36,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
              )]),
            ],
          )),
        ),
        const SizedBox(height: 20),

        // Top categories list
        if (sortedCats.isNotEmpty) ...[
          _sectionTitle('Top Spending Categories', isDark),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: _card(cardBg),
            child: Column(children: sortedCats.take(8).toList().asMap().entries.map((e) {
              final pct = expense > 0 ? e.value.value / expense : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(e.value.key,
                        style: TextStyle(fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87))),
                    Text(_f(e.value.value),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Text('${(pct * 100).toStringAsFixed(0)}%',
                        style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                  ]),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 5,
                      backgroundColor: Colors.grey.withOpacity(0.15),
                      valueColor: AlwaysStoppedAnimation(
                          colors[e.key % colors.length]),
                    ),
                  ),
                ]),
              );
            }).toList()),
          ),
        ],
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _statCard(String label, double amount, Color color, IconData icon, Color bg) =>
      Expanded(child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 10)),
          const SizedBox(height: 2),
          FittedBox(child: Text(_f(amount),
              style: TextStyle(
                  color: color, fontSize: 14, fontWeight: FontWeight.bold))),
        ]),
      ));
}

// ════════════════════════════════════════════════════════════════════════
// TAB 2 — AI INSIGHTS
// ════════════════════════════════════════════════════════════════════════
class _InsightsTab extends StatefulWidget {
  final List<SpendingInsight> ruleInsights;
  final bool    aiLoading;
  final String? aiResult;
  final String? aiError;
  final String  apiKey;
  final bool    showApiKeyField;
  final VoidCallback onRunAI;
  final Future<void> Function(String) onSaveKey;
  final VoidCallback onShowKeyField;
  final Color cardBg;
  final bool  isDark;

  const _InsightsTab({
    required this.ruleInsights,    required this.aiLoading,
    required this.aiResult,        required this.aiError,
    required this.apiKey,          required this.showApiKeyField,
    required this.onRunAI,         required this.onSaveKey,
    required this.onShowKeyField,  required this.cardBg,
    required this.isDark,
  });
  @override
  State<_InsightsTab> createState() => _InsightsTabState();
}

class _InsightsTabState extends State<_InsightsTab> {
  final _keyCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [

        // ── Rule-based insights ─────────────────────────────────────
        _sectionTitle('Smart Insights', widget.isDark),
        const SizedBox(height: 12),
        ...widget.ruleInsights.map((ins) => _insightCard(ins, widget.cardBg, widget.isDark)),
        const SizedBox(height: 24),

        // ── Claude AI section ───────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF667eea), Color(0xFF764ba2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Text('🤖', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Claude AI Analysis',
                    style: TextStyle(color: Colors.white,
                        fontWeight: FontWeight.bold, fontSize: 16)),
                Text(kIsWeb
                    ? 'Available on Android app only'
                    : widget.apiKey.isEmpty
                        ? 'Enter your Anthropic API key'
                        : 'Powered by Claude claude-haiku-4-5-20251001',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.75), fontSize: 11)),
              ])),
            ]),
            const SizedBox(height: 16),

            if (!kIsWeb) ...[
              // API key field
              if (widget.showApiKeyField || widget.apiKey.isEmpty) ...[
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _keyCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    obscureText: true,
                    decoration: const InputDecoration(
                      hintText: 'sk-ant-...',
                      hintStyle: TextStyle(color: Colors.white38),
                      prefixIcon: Icon(Icons.key, color: Colors.white54, size: 18),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(12),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: ElevatedButton(
                    onPressed: () => widget.onSaveKey(_keyCtrl.text.trim()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF667eea),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Save Key',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  )),
                ]),
                const SizedBox(height: 8),
                Text('Get your free API key at console.anthropic.com',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.55), fontSize: 10)),
              ] else ...[
                // Run button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: widget.aiLoading ? null : widget.onRunAI,
                    icon: widget.aiLoading
                        ? const SizedBox(width: 16, height: 16,
                            child: CircularProgressIndicator(
                                color: Color(0xFF667eea), strokeWidth: 2))
                        : const Icon(Icons.auto_awesome, size: 18),
                    label: Text(widget.aiLoading ? 'Analysing...' : 'Get AI Insights'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF667eea),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: widget.onShowKeyField,
                  child: Text('Change API key',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.6), fontSize: 11)),
                ),
              ],
            ],

            // AI error
            if (widget.aiError != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(widget.aiError!,
                      style: const TextStyle(color: Colors.white, fontSize: 12))),
                ]),
              ),
            ],
          ]),
        ),

        // AI results
        if (widget.aiResult != null) ...[
          const SizedBox(height: 16),
          _sectionTitle('Claude AI Insights', widget.isDark),
          const SizedBox(height: 12),
          ..._parseAiInsights(widget.aiResult!).map(
              (ins) => _insightCard(ins, widget.cardBg, widget.isDark)),
        ],

        const SizedBox(height: 20),
      ],
    );
  }

  List<SpendingInsight> _parseAiInsights(String json) {
    try {
      final data = jsonDecode(json);
      final list = (data['insights'] as List?) ?? [];
      return list.map((item) => SpendingInsight(
        type:    item['type'] ?? 'tip',
        title:   item['title'] ?? '',
        message: item['message'] ?? '',
        icon:    item['type'] == 'warning' ? '⚠️' : item['type'] == 'positive' ? '✅' : '💡',
      )).toList();
    } catch (_) {
      return [const SpendingInsight(
        type: 'tip', icon: '💡',
        title: 'AI Response',
        message: 'Received insights from Claude but could not parse them.',
      )];
    }
  }
}

// ════════════════════════════════════════════════════════════════════════
// TAB 3 — HEALTH SCORE
// ════════════════════════════════════════════════════════════════════════
class _HealthTab extends StatelessWidget {
  final FinancialHealthScore? health;
  final Color cardBg;
  final bool  isDark;
  const _HealthTab({required this.health, required this.cardBg, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final h = health;
    if (h == null) {
      return const Center(child: Text('No data available'));
    }

    final gradeColor = h.total >= 75
        ? Colors.green
        : h.total >= 55
            ? const Color(0xFF667eea)
            : h.total >= 35
                ? Colors.orange
                : Colors.red;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [

        // Big score circle
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [gradeColor.withOpacity(0.8), gradeColor],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(children: [
            Stack(alignment: Alignment.center, children: [
              SizedBox(width: 120, height: 120,
                child: CircularProgressIndicator(
                  value: h.total / 100,
                  strokeWidth: 10,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  valueColor: const AlwaysStoppedAnimation(Colors.white),
                )),
              Column(mainAxisSize: MainAxisSize.min, children: [
                Text(h.total.toStringAsFixed(0),
                    style: const TextStyle(color: Colors.white,
                        fontSize: 36, fontWeight: FontWeight.bold)),
                Text('/ 100', style: TextStyle(
                    color: Colors.white.withOpacity(0.7), fontSize: 12)),
              ]),
            ]),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('Grade: ${h.grade}',
                  style: const TextStyle(color: Colors.white,
                      fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            const SizedBox(height: 10),
            Text(h.headline,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.9), fontSize: 13)),
          ]),
        ),
        const SizedBox(height: 20),

        // Breakdown
        _sectionTitle('Score Breakdown', isDark),
        const SizedBox(height: 12),
        ...h.breakdown.map((item) {
          final pct = item.maxScore > 0 ? item.score / item.maxScore : 0.0;
          final itemColor = pct >= 0.7
              ? Colors.green
              : pct >= 0.4
                  ? Colors.orange
                  : Colors.red;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: _card(cardBg),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(item.icon, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Expanded(child: Text(item.label,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                Text('${item.score.toStringAsFixed(0)}/${item.maxScore.toInt()}',
                    style: TextStyle(fontWeight: FontWeight.bold, color: itemColor)),
              ]),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct, minHeight: 7,
                  backgroundColor: Colors.grey.withOpacity(0.15),
                  valueColor: AlwaysStoppedAnimation(itemColor),
                ),
              ),
              const SizedBox(height: 6),
              Text(item.description,
                  style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            ]),
          );
        }),

        // Tips
        const SizedBox(height: 8),
        _sectionTitle('How to improve', isDark),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: _card(cardBg),
          child: Column(children: [
            _tip('💰', 'Target 20-30% savings rate each month'),
            _tip('📊', 'Keep expense growth below 5% month-on-month'),
            _tip('💼', 'Log all income sources for consistency score'),
            _tip('🎯', 'Spread spending across 5+ categories'),
            _tip('📝', 'Add at least 20 transactions per month'),
          ]),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _tip(String icon, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(children: [
      Text(icon, style: const TextStyle(fontSize: 16)),
      const SizedBox(width: 10),
      Expanded(child: Text(text,
          style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87))),
    ]),
  );
}

// ════════════════════════════════════════════════════════════════════════
// TAB 4 — CASHFLOW FORECAST
// ════════════════════════════════════════════════════════════════════════
class _CashflowTab extends StatelessWidget {
  final List<MonthlyPoint> forecast;
  final Color cardBg;
  final bool  isDark;
  const _CashflowTab({required this.forecast, required this.cardBg, required this.isDark});

  @override
  Widget build(BuildContext context) {
    if (forecast.isEmpty) {
      return const Center(child: Text('No data to forecast'));
    }

    final maxY = forecast.map((m) => m.income > m.expense ? m.income : m.expense)
        .reduce((a, b) => a > b ? a : b) * 1.25;
    final now = DateTime.now();

    // Build line chart spots
    final incSpots  = <FlSpot>[];
    final expSpots  = <FlSpot>[];
    final balSpots  = <FlSpot>[];
    for (int i = 0; i < forecast.length; i++) {
      incSpots.add(FlSpot(i.toDouble(), forecast[i].income));
      expSpots.add(FlSpot(i.toDouble(), forecast[i].expense));
      balSpots.add(FlSpot(i.toDouble(), forecast[i].balance));
    }

    // Find where forecast starts (month 7 = index 6)
    final forecastStartIdx = forecast.indexWhere((m) =>
        m.month.isAfter(DateTime(now.year, now.month)));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionTitle('Cashflow Forecast', isDark),
        Text('Based on your last 3 months average',
            style: TextStyle(fontSize: 11, color: Colors.grey[500])),
        const SizedBox(height: 16),

        // Line chart
        Container(
          height: 240,
          padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
          decoration: _card(cardBg),
          child: LineChart(LineChartData(
            minX: 0, maxX: (forecast.length - 1).toDouble(),
            minY: 0, maxY: maxY,
            gridData: FlGridData(
              show: true, drawVerticalLine: false,
              getDrawingHorizontalLine: (v) =>
                  FlLine(color: Colors.grey.withOpacity(0.15), strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(sideTitles: SideTitles(
                showTitles: true, reservedSize: 26,
                getTitlesWidget: (v, _) {
                  final idx = v.toInt();
                  if (idx < 0 || idx >= forecast.length) return const Text('');
                  return Text(_monthLabel(forecast[idx].month),
                      style: TextStyle(
                          fontSize: 9,
                          color: forecastStartIdx >= 0 && idx >= forecastStartIdx
                              ? const Color(0xFF667eea)
                              : Colors.grey));
                },
              )),
              leftTitles: AxisTitles(sideTitles: SideTitles(
                showTitles: true, reservedSize: 44,
                getTitlesWidget: (v, _) => Text(
                    '₹${(v / 1000).toStringAsFixed(0)}k',
                    style: const TextStyle(fontSize: 9, color: Colors.grey)),
              )),
              topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            lineBarsData: [
              _line(incSpots, Colors.green, isDashed: false),
              _line(expSpots, Colors.red,   isDashed: false),
              _line(balSpots, const Color(0xFF667eea), isDashed: false),
            ],
          )),
        ),

        // Legend
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _legend('Income',  Colors.green),
          const SizedBox(width: 16),
          _legend('Expense', Colors.red),
          const SizedBox(width: 16),
          _legend('Balance', const Color(0xFF667eea)),
          const SizedBox(width: 16),
          _legend('Forecast ▶', const Color(0xFF667eea).withOpacity(0.4)),
        ]),
        const SizedBox(height: 20),

        // Monthly table
        _sectionTitle('Monthly Breakdown', isDark),
        const SizedBox(height: 12),
        Container(
          decoration: _card(cardBg),
          child: Column(children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF667eea).withOpacity(0.1),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              ),
              child: Row(children: [
                Expanded(child: Text('Month', style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 11,
                    color: Colors.grey[500]))),
                _th('Income'), _th('Expense'), _th('Balance'),
              ]),
            ),
            ...forecast.asMap().entries.map((e) {
              final m        = e.value;
              final isForecast = forecastStartIdx >= 0 && e.key >= forecastStartIdx;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isForecast
                      ? const Color(0xFF667eea).withOpacity(0.04)
                      : Colors.transparent,
                  border: Border(bottom: BorderSide(
                      color: Colors.grey.withOpacity(0.08))),
                ),
                child: Row(children: [
                  Expanded(child: Row(children: [
                    Text(_monthLabel(m.month, short: false),
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: isForecast ? FontWeight.w500 : FontWeight.normal,
                            color: isForecast
                                ? const Color(0xFF667eea)
                                : (isDark ? Colors.white70 : Colors.black87))),
                    if (isForecast) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFF667eea).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('est', style: TextStyle(
                            fontSize: 8, color: Color(0xFF667eea))),
                      ),
                    ],
                  ])),
                  _td(m.income,  Colors.green),
                  _td(m.expense, Colors.red),
                  _td(m.balance, m.balance >= 0 ? Colors.green : Colors.red),
                ]),
              );
            }),
          ]),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  LineChartBarData _line(List<FlSpot> spots, Color color,
      {bool isDashed = false}) =>
      LineChartBarData(
        spots: spots,
        isCurved: true,
        color: color,
        barWidth: 2.5,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(
          show: true,
          color: color.withOpacity(0.06),
        ),
      );

  Widget _legend(String label, Color color) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 12, height: 3,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
      ]);

  Widget _th(String t) => SizedBox(
    width: 76,
    child: Text(t, textAlign: TextAlign.right,
        style: TextStyle(fontWeight: FontWeight.bold,
            fontSize: 11, color: Colors.grey[500])),
  );

  Widget _td(double v, Color c) => SizedBox(
    width: 76,
    child: Text(_f(v), textAlign: TextAlign.right,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c)),
  );
}

// ════════════════════════════════════════════════════════════════════════
// TAB 5 — TRENDS
// ════════════════════════════════════════════════════════════════════════
class _TrendsTab extends StatefulWidget {
  final List<MonthlyPoint>  trend;
  final List<CategoryTrend> catTrend;
  final Color cardBg;
  final bool  isDark;
  const _TrendsTab({required this.trend, required this.catTrend,
      required this.cardBg, required this.isDark});
  @override
  State<_TrendsTab> createState() => _TrendsTabState();
}

class _TrendsTabState extends State<_TrendsTab> {
  bool _showExpense = true;

  @override
  Widget build(BuildContext context) {
    final points = widget.trend;
    if (points.isEmpty) {
      return const Center(child: Text('No trend data available'));
    }

    const colors = [
      Color(0xFF667eea), Color(0xFFf093fb), Color(0xFF4facfe),
      Color(0xFF43e97b), Color(0xFFfa709a), Color(0xFFfda085),
    ];

    final maxY = points.map((m) => _showExpense ? m.expense : m.income)
        .reduce((a, b) => a > b ? a : b) * 1.25 + 1;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Toggle income/expense
        Row(children: [
          Expanded(child: _sectionTitle('6-Month Trend', widget.isDark)),
          ToggleButtons(
            isSelected: [_showExpense, !_showExpense],
            onPressed: (i) => setState(() => _showExpense = i == 0),
            borderRadius: BorderRadius.circular(10),
            selectedColor: Colors.white,
            fillColor: const Color(0xFF667eea),
            constraints: const BoxConstraints(minWidth: 72, minHeight: 32),
            children: const [
              Text('Expense', style: TextStyle(fontSize: 11)),
              Text('Income',  style: TextStyle(fontSize: 11)),
            ],
          ),
        ]),
        const SizedBox(height: 12),

        // Bar chart — 6 months
        Container(
          height: 200,
          padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
          decoration: _card(widget.cardBg),
          child: BarChart(BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: maxY,
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipItem: (g, gi, rod, ri) => BarTooltipItem(
                  _f(rod.toY),
                  const TextStyle(color: Colors.white, fontSize: 11,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(sideTitles: SideTitles(
                showTitles: true, reservedSize: 22,
                getTitlesWidget: (v, _) {
                  final idx = v.toInt();
                  if (idx < 0 || idx >= points.length) return const Text('');
                  return Text(_monthLabel(points[idx].month),
                      style: const TextStyle(fontSize: 9, color: Colors.grey));
                },
              )),
              leftTitles: AxisTitles(sideTitles: SideTitles(
                showTitles: true, reservedSize: 44,
                getTitlesWidget: (v, _) => Text(
                    '₹${(v / 1000).toStringAsFixed(0)}k',
                    style: const TextStyle(fontSize: 9, color: Colors.grey)),
              )),
              topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            gridData:   FlGridData(show: true, drawVerticalLine: false),
            borderData: FlBorderData(show: false),
            barGroups: points.asMap().entries.map((e) =>
              BarChartGroupData(x: e.key, barRods: [BarChartRodData(
                toY:    _showExpense ? e.value.expense : e.value.income,
                width:  24,
                color:  _showExpense
                    ? Color.lerp(Colors.red, Colors.orange,
                        e.key / points.length)!
                    : Color.lerp(Colors.green, const Color(0xFF43e97b),
                        e.key / points.length)!,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
              )])
            ).toList(),
          )),
        ),
        const SizedBox(height: 20),

        // Balance trend line
        _sectionTitle('Monthly Balance', widget.isDark),
        const SizedBox(height: 12),
        Container(
          height: 140,
          padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
          decoration: _card(widget.cardBg),
          child: LineChart(LineChartData(
            gridData: FlGridData(show: true, drawVerticalLine: false,
                getDrawingHorizontalLine: (v) =>
                    FlLine(color: Colors.grey.withOpacity(0.15), strokeWidth: 1)),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(sideTitles: SideTitles(
                showTitles: true, reservedSize: 20,
                getTitlesWidget: (v, _) {
                  final idx = v.toInt();
                  if (idx < 0 || idx >= points.length) return const Text('');
                  return Text(_monthLabel(points[idx].month),
                      style: const TextStyle(fontSize: 9, color: Colors.grey));
                },
              )),
              leftTitles:  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            lineBarsData: [LineChartBarData(
              spots: points.asMap().entries.map((e) =>
                  FlSpot(e.key.toDouble(), e.value.balance)).toList(),
              isCurved:  true,
              color:     const Color(0xFF667eea),
              barWidth:  2.5,
              dotData:   const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: const Color(0xFF667eea).withOpacity(0.08),
              ),
            )],
          )),
        ),
        const SizedBox(height: 20),

        // Category trends
        if (widget.catTrend.isNotEmpty) ...[
          _sectionTitle('Category Trends (6 months)', widget.isDark),
          const SizedBox(height: 12),
          ...widget.catTrend.take(6).toList().asMap().entries.map((e) {
            final cat   = e.value;
            final maxV  = cat.monthlyAmounts.reduce((a, b) => a > b ? a : b);
            final color = colors[e.key % colors.length];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: _card(widget.cardBg),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(cat.category,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                  Text('avg ${_f(cat.avgMonthly)}/mo',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                ]),
                const SizedBox(height: 10),
                Row(children: cat.monthlyAmounts.asMap().entries.map((me) {
                  final h = maxV > 0 ? me.value / maxV : 0.0;
                  return Expanded(child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(children: [
                      Container(
                        height: 40 * h + 2,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.15 + 0.7 * h),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(_monthLabel(widget.trend[me.key].month),
                          style: const TextStyle(fontSize: 8, color: Colors.grey)),
                    ]),
                  ));
                }).toList()),
              ]),
            );
          }),
        ],
        const SizedBox(height: 20),
      ],
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────
BoxDecoration _card(Color bg) => BoxDecoration(
  color: bg,
  borderRadius: BorderRadius.circular(16),
  boxShadow: [BoxShadow(
    color: Colors.black.withOpacity(0.06),
    blurRadius: 12, offset: const Offset(0, 4),
  )],
);

Widget _sectionTitle(String t, bool isDark) => Text(t,
    style: TextStyle(
        fontSize: 16, fontWeight: FontWeight.bold,
        color: isDark ? Colors.white : Colors.black87));

Widget _insightCard(SpendingInsight ins, Color bg, bool isDark) {
  final colors = {
    'warning':  Colors.orange,
    'positive': Colors.green,
    'tip':      const Color(0xFF667eea),
    'ai':       const Color(0xFF764ba2),
  };
  final c = colors[ins.type] ?? const Color(0xFF667eea);
  return Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: c.withOpacity(0.2)),
    ),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 38, height: 38,
        decoration: BoxDecoration(
          color: c.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(child: Text(ins.icon, style: const TextStyle(fontSize: 18))),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(ins.title,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13,
                color: isDark ? Colors.white : Colors.black87)),
        const SizedBox(height: 4),
        Text(ins.message,
            style: TextStyle(fontSize: 12,
                color: isDark ? Colors.white60 : Colors.black54)),
      ])),
    ]),
  );
}