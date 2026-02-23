import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/transaction_model.dart';
import '../models/goal_model.dart';
import '../services/transaction_service.dart';
import '../services/goal_service.dart';
import '../services/savings_prediction_service.dart';

class PredictSavingsScreen extends StatefulWidget {
  const PredictSavingsScreen({super.key});

  @override
  State<PredictSavingsScreen> createState() => _PredictSavingsScreenState();
}

class _PredictSavingsScreenState extends State<PredictSavingsScreen>
    with SingleTickerProviderStateMixin {
  final _txnService = TransactionService();
  final _goalService = GoalService();
  late TabController _tabController;

  bool _loading = true;
  bool _aiLoading = false;

  List<TransactionModel> _transactions = [];
  List<GoalModel> _goals = [];
  List<MonthlySnapshot> _history = [];
  List<PredictionScenario> _scenarios = [];
  String _aiNarrative = '';
  String? _apiKey;

  // Goal simulator state
  int _selectedScenario = 1; // realistic by default
  double _goalAllocation = 50; // % of savings to goals

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _apiKey = await SavingsPredictionService.getSavedApiKey();

    final txns = await _txnService.getTransactionsList();

    // Load goals once
    List<GoalModel> goals = [];
    _goalService.getGoals().listen((snap) {
      goals = snap.docs
          .map((d) => GoalModel.fromFirestore(d))
          .where((g) => !g.isCompleted)
          .toList();
    });

    setState(() {
      _transactions = txns;
      _history = SavingsPredictionService.buildMonthlyHistory(txns);
      _scenarios = SavingsPredictionService.generateScenarios(_history);
      _goals = goals;
      _loading = false;
    });

    // Fire AI in background
    if (_apiKey != null && _apiKey!.isNotEmpty && _scenarios.isNotEmpty) {
      _fetchAI();
    }
  }

  Future<void> _fetchAI() async {
    if (_apiKey == null || _history.isEmpty) return;
    setState(() => _aiLoading = true);
    final result = await SavingsPredictionService.getAiNarrative(
      history: _history,
      scenarios: _scenarios,
      apiKey: _apiKey!,
    );
    setState(() {
      _aiNarrative = result;
      _aiLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Predict Future Savings'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Forecast'),
            Tab(text: 'Scenarios'),
            Tab(text: 'Goals'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildForecastTab(theme),
                  _buildScenariosTab(theme),
                  _buildGoalsTab(theme),
                ],
              ),
            ),
    );
  }

  // ── Tab 1: Forecast ──────────────────────────────────────────────────────────
  Widget _buildForecastTab(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final hasData = _history.any((h) => h.income > 0 || h.expense > 0);

    if (!hasData) {
      return _emptyState(
        '🔮',
        'No transaction data yet',
        'Add income & expense transactions\nto see your savings forecast.',
      );
    }

    final realistic =
        _scenarios.length > 1 ? _scenarios[1] : _scenarios.first;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // History chart
        _sectionTitle('📅 Last 6 Months — Actual'),
        const SizedBox(height: 10),
        _buildHistoryChart(isDark),
        const SizedBox(height: 8),
        _buildHistoryTable(isDark),
        const SizedBox(height: 24),

        // 12-month forecast banner
        _sectionTitle('🔮 12-Month Savings Forecast'),
        const SizedBox(height: 10),
        _buildForecastBanner(realistic, isDark),
        const SizedBox(height: 12),
        _buildForecastLineChart(isDark),
        const SizedBox(height: 24),

        // AI narrative
        if (_aiLoading) _buildAiLoading(isDark),
        if (_aiNarrative.isNotEmpty) _buildAiCard(_aiNarrative, isDark),
        if (_aiNarrative.isNotEmpty) const SizedBox(height: 24),

        // Scenario quick compare
        _sectionTitle('⚡ Scenario Comparison'),
        const SizedBox(height: 10),
        _buildScenarioCompareRow(isDark),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildHistoryChart(bool isDark) {
    final maxVal = _history
        .map((h) => h.income > h.expense ? h.income : h.expense)
        .fold(0.0, (a, b) => a > b ? a : b);

    return Container(
      height: 180,
      padding: const EdgeInsets.fromLTRB(4, 12, 16, 8),
      decoration: _cardDecor(isDark),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxVal > 0 ? maxVal * 1.2 : 10000,
          barTouchData: BarTouchData(enabled: false),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: Colors.grey.withOpacity(0.15), strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= _history.length) return const SizedBox();
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      _history[i].label.split(' ').first,
                      style: const TextStyle(fontSize: 9),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (v, _) => Text(
                  '₹${(v / 1000).toStringAsFixed(0)}k',
                  style: const TextStyle(fontSize: 8),
                ),
              ),
            ),
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
          ),
          barGroups: _history.asMap().entries.map((e) {
            return BarChartGroupData(
              x: e.key,
              barRods: [
                BarChartRodData(
                  toY: e.value.income,
                  color: Colors.green.withOpacity(0.8),
                  width: 10,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(3)),
                ),
                BarChartRodData(
                  toY: e.value.expense,
                  color: Colors.red.withOpacity(0.8),
                  width: 10,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(3)),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildHistoryTable(bool isDark) {
    return Container(
      decoration: _cardDecor(isDark),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                Expanded(
                    flex: 2,
                    child: Text('Month',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[600]))),
                Expanded(
                    child: Text('Income',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.green,
                            fontWeight: FontWeight.w600))),
                Expanded(
                    child: Text('Expense',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.red,
                            fontWeight: FontWeight.w600))),
                Expanded(
                    child: Text('Saved',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.teal,
                            fontWeight: FontWeight.w600))),
              ],
            ),
          ),
          const Divider(height: 1),
          ..._history.reversed.map((h) {
            final pos = h.savings >= 0;
            return Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                      flex: 2,
                      child: Text(h.label,
                          style: const TextStyle(fontSize: 11))),
                  Expanded(
                      child: Text(
                          SavingsPredictionService.formatAmount(h.income),
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                              fontSize: 11, color: Colors.green))),
                  Expanded(
                      child: Text(
                          SavingsPredictionService.formatAmount(h.expense),
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                              fontSize: 11, color: Colors.red))),
                  Expanded(
                      child: Text(
                          '${pos ? '+' : ''}${SavingsPredictionService.formatAmount(h.savings)}',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: pos ? Colors.teal : Colors.red))),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildForecastBanner(PredictionScenario s, bool isDark) {
    final isPositive = s.total12Months >= 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isPositive
              ? [const Color(0xFF1B5E20), const Color(0xFF2E7D32)]
              : [const Color(0xFFB71C1C), const Color(0xFFC62828)],
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
              Text(isPositive ? '📈' : '📉',
                  style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              const Text('Realistic 12-Month Prediction',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            SavingsPredictionService.formatAmount(s.total12Months),
            style: const TextStyle(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.bold),
          ),
          Text(
            'projected savings over next 12 months',
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _bannerPill(
                  '₹${SavingsPredictionService.formatAmount(s.monthlyIncome)}/mo income',
                  Colors.white24),
              const SizedBox(width: 8),
              _bannerPill(
                  '₹${SavingsPredictionService.formatAmount(s.monthlyExpense)}/mo expense',
                  Colors.white24),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bannerPill(String text, Color bg) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text,
            style: const TextStyle(color: Colors.white, fontSize: 11)),
      );

  Widget _buildForecastLineChart(bool isDark) {
    if (_scenarios.isEmpty) return const SizedBox();

    final months = List.generate(12, (i) => i);
    final maxY = _scenarios
        .map((s) => s.cumulativeSavings.reduce((a, b) => a > b ? a : b))
        .reduce((a, b) => a > b ? a : b);
    final minY = _scenarios
        .map((s) => s.cumulativeSavings.reduce((a, b) => a < b ? a : b))
        .reduce((a, b) => a < b ? a : b);

    final colors = [Colors.red, Colors.blue, Colors.green];

    return Container(
      height: 220,
      padding: const EdgeInsets.fromLTRB(4, 16, 16, 8),
      decoration: _cardDecor(isDark),
      child: LineChart(
        LineChartData(
          minY: (minY * 1.1) < 0 ? minY * 1.1 : 0,
          maxY: maxY * 1.15,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
                color: Colors.grey.withOpacity(0.15), strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 2,
                getTitlesWidget: (v, _) {
                  final m = v.toInt();
                  if (m < 0 || m > 11) return const SizedBox();
                  final now = DateTime.now();
                  final future = DateTime(now.year, now.month + m + 1);
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      DateFormat('MMM').format(future),
                      style: const TextStyle(fontSize: 9),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                getTitlesWidget: (v, _) => Text(
                  SavingsPredictionService.formatAmount(v),
                  style: const TextStyle(fontSize: 8),
                ),
              ),
            ),
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
          ),
          lineBarsData: _scenarios.asMap().entries.map((e) {
            return LineChartBarData(
              spots: months
                  .map((m) => FlSpot(
                      m.toDouble(), e.value.cumulativeSavings[m]))
                  .toList(),
              isCurved: true,
              color: colors[e.key % colors.length],
              barWidth: e.key == 1 ? 3 : 2,
              dotData: const FlDotData(show: false),
              dashArray: e.key == 0 ? [6, 3] : null,
              belowBarData: e.key == 1
                  ? BarAreaData(
                      show: true,
                      color: Colors.blue.withOpacity(0.06),
                    )
                  : BarAreaData(show: false),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildScenarioCompareRow(bool isDark) {
    final colors = [Colors.red, Colors.blue, Colors.green];
    return Row(
      children: _scenarios.asMap().entries.map((e) {
        final s = e.value;
        final color = colors[e.key];
        final isPositive = s.total12Months >= 0;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: e.key < 2 ? 8 : 0),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                Text(s.emoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(height: 4),
                Text(s.name,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: color)),
                const SizedBox(height: 4),
                Text(
                  SavingsPredictionService.formatAmount(s.total12Months),
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isPositive ? color : Colors.red),
                ),
                Text('12 months',
                    style: TextStyle(
                        fontSize: 10, color: Colors.grey[500])),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Tab 2: Scenarios ─────────────────────────────────────────────────────────
  Widget _buildScenariosTab(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final colors = [Colors.red, Colors.blue, Colors.green];

    if (_scenarios.isEmpty) {
      return _emptyState('📊', 'No data yet',
          'Add transactions to see scenario predictions.');
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'What could happen in the next 12 months?',
          style: TextStyle(color: Colors.grey[600], fontSize: 13),
        ),
        const SizedBox(height: 16),

        ..._scenarios.asMap().entries.map((e) {
          final s = e.value;
          final color = colors[e.key];
          final isPos = s.total12Months >= 0;

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withOpacity(0.25)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2))
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.08),
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16)),
                  ),
                  child: Row(
                    children: [
                      Text(s.emoji,
                          style: const TextStyle(fontSize: 24)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.name,
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: color)),
                            Text(s.description,
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600])),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            SavingsPredictionService.formatAmount(
                                s.total12Months),
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isPos ? color : Colors.red),
                          ),
                          Text('saved in 12mo',
                              style: TextStyle(
                                  fontSize: 10, color: Colors.grey[500])),
                        ],
                      ),
                    ],
                  ),
                ),

                // Stats row
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _statChip('Income growth',
                              '${s.incomeGrowthRate >= 0 ? '+' : ''}${s.incomeGrowthRate.toStringAsFixed(0)}%/yr',
                              Colors.green),
                          const SizedBox(width: 8),
                          _statChip('Expense growth',
                              '${s.expenseGrowthRate >= 0 ? '+' : ''}${s.expenseGrowthRate.toStringAsFixed(0)}%/yr',
                              Colors.orange),
                          const SizedBox(width: 8),
                          _statChip(
                              'Monthly save',
                              SavingsPredictionService.formatAmount(
                                  s.monthlySavings),
                              Colors.teal),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Mini bar chart (monthly savings)
                      SizedBox(
                        height: 60,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: s.monthlySavingsList.map((v) {
                            final maxBar = s.monthlySavingsList
                                .map((x) => x.abs())
                                .reduce((a, b) => a > b ? a : b);
                            final frac = maxBar > 0 ? (v / maxBar).abs() : 0.0;
                            return Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 1.5),
                                child: Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.end,
                                  children: [
                                    Container(
                                      height: (frac * 48).clamp(2, 48),
                                      decoration: BoxDecoration(
                                        color: v >= 0
                                            ? color.withOpacity(0.7)
                                            : Colors.red.withOpacity(0.7),
                                        borderRadius:
                                            BorderRadius.circular(3),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('Monthly savings forecast (12 months)',
                          style: TextStyle(
                              fontSize: 10, color: Colors.grey[500])),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.lightbulb_outline,
                                size: 14, color: color),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                s.insight,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black87,
                                    height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ── Tab 3: Goal Simulator ────────────────────────────────────────────────────
  Widget _buildGoalsTab(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;

    if (_scenarios.isEmpty) {
      return _emptyState('🎯', 'No data yet',
          'Add transactions to simulate goal timelines.');
    }

    final scenario = _scenarios[_selectedScenario.clamp(0, _scenarios.length - 1)];
    final monthlySavings = scenario.monthlySavings;
    final colors = [Colors.red, Colors.blue, Colors.green];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Scenario selector
        _sectionTitle('Choose Scenario'),
        const SizedBox(height: 10),
        Row(
          children: _scenarios.asMap().entries.map((e) {
            final selected = _selectedScenario == e.key;
            final c = colors[e.key];
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedScenario = e.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: EdgeInsets.only(right: e.key < 2 ? 8 : 0),
                  padding: const EdgeInsets.symmetric(
                      vertical: 10, horizontal: 6),
                  decoration: BoxDecoration(
                    color: selected ? c : c.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: selected ? c : c.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      Text(e.value.emoji,
                          style: const TextStyle(fontSize: 18)),
                      const SizedBox(height: 2),
                      Text(e.value.name,
                          style: TextStyle(
                              fontSize: 10,
                              color: selected
                                  ? Colors.white
                                  : c,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),

        // Monthly savings from scenario
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colors[_selectedScenario].withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: colors[_selectedScenario].withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Monthly Savings Available',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600)),
                    Text(
                      SavingsPredictionService.formatAmount(monthlySavings),
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: monthlySavings >= 0
                              ? colors[_selectedScenario]
                              : Colors.red),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Allocate to goals',
                      style: TextStyle(fontSize: 11)),
                  Text('${_goalAllocation.toStringAsFixed(0)}%',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: colors[_selectedScenario])),
                ],
              ),
            ],
          ),
        ),

        // Allocation slider
        Slider(
          value: _goalAllocation,
          min: 10,
          max: 100,
          divisions: 9,
          label: '${_goalAllocation.toStringAsFixed(0)}%',
          onChanged: (v) => setState(() => _goalAllocation = v),
          activeColor: colors[_selectedScenario],
        ),
        const SizedBox(height: 8),

        // Goals list
        if (_goals.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: _cardDecor(isDark),
            child: Column(
              children: [
                const Text('🎯', style: TextStyle(fontSize: 36)),
                const SizedBox(height: 8),
                const Text('No active goals',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Go to Financial Goals to add goals',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey[500])),
              ],
            ),
          )
        else ...[
          _sectionTitle('⏱️ Goal Timeline Forecast'),
          const SizedBox(height: 10),
          ..._goals.map((goal) {
            final forecast = SavingsPredictionService.forecastGoal(
              goalName: goal.name,
              targetAmount: goal.targetAmount,
              currentAmount: goal.currentAmount,
              monthlySavings: monthlySavings,
              allocationPercent:
                  _goalAllocation / _goals.length,
            );
            return _buildGoalForecastCard(
                goal, forecast, isDark, colors[_selectedScenario]);
          }),
        ],
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildGoalForecastCard(GoalModel goal, GoalForecast forecast,
      bool isDark, Color color) {
    final progress = goal.progress / 100;
    final months = forecast.monthsToReach;

    String timeLabel;
    Color timeColor;
    if (!forecast.isReachable) {
      timeLabel = 'Not reachable with current savings';
      timeColor = Colors.red;
    } else if (months == 0) {
      timeLabel = 'Already reached! 🎉';
      timeColor = Colors.green;
    } else if (months <= 3) {
      timeLabel = 'In $months months 🔥';
      timeColor = Colors.green;
    } else if (months <= 12) {
      timeLabel = 'In $months months';
      timeColor = Colors.orange;
    } else {
      final years = (months / 12).floor();
      final rem = months % 12;
      timeLabel = rem > 0
          ? 'In ${years}y ${rem}mo'
          : 'In ${years} years';
      timeColor = Colors.grey[600]!;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(goal.icon ?? '🎯',
                  style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(goal.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                    Text(
                      'Target: ${SavingsPredictionService.formatAmount(goal.targetAmount)} • '
                      'Saved: ${SavingsPredictionService.formatAmount(goal.currentAmount)}',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(timeLabel,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: timeColor)),
                  if (forecast.estimatedDate != null && months > 0)
                    Text(
                      DateFormat('MMM yyyy')
                          .format(forecast.estimatedDate!),
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey[500]),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: Colors.grey.withOpacity(0.15),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(progress * 100).toStringAsFixed(0)}% complete',
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
              Text(
                '₹${SavingsPredictionService.formatAmount(forecast.monthlyContribution)}/mo allocated',
                style: TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────
  Widget _buildAiLoading(bool isDark) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: const Color(0xFF4285F4).withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Color(0xFF4285F4))),
            const SizedBox(width: 12),
            const Text('✨ Gemini AI analyzing your savings trend...',
                style: TextStyle(
                    color: Color(0xFF4285F4),
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ],
        ),
      );

  Widget _buildAiCard(String text, bool isDark) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF1A237E).withOpacity(0.3)
              : const Color(0xFFE8EAF6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: const Color(0xFF3F51B5).withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('✨',
                    style: TextStyle(fontSize: 15)),
                const SizedBox(width: 6),
                const Text('Gemini AI Analysis',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFF3F51B5))),
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
            const Divider(height: 14),
            Text(text,
                style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white70 : Colors.black87,
                    height: 1.6)),
          ],
        ),
      );

  Widget _statChip(String label, String value, Color color) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: color)),
            Text(label,
                style:
                    TextStyle(fontSize: 9, color: Colors.grey[600])),
          ],
        ),
      );

  Widget _sectionTitle(String t) => Text(t,
      style: const TextStyle(
          fontSize: 15, fontWeight: FontWeight.bold));

  BoxDecoration _cardDecor(bool isDark) => BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      );

  Widget _emptyState(String emoji, String title, String subtitle) =>
      Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 52)),
            const SizedBox(height: 16),
            Text(title,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13, color: Colors.grey[500])),
          ],
        ),
      );
}