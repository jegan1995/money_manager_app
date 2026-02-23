import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/transaction_model.dart';
import '../services/transaction_service.dart';

class FinancialInsightsScreen extends StatefulWidget {
  const FinancialInsightsScreen({super.key});

  @override
  State<FinancialInsightsScreen> createState() =>
      _FinancialInsightsScreenState();
}

class _FinancialInsightsScreenState extends State<FinancialInsightsScreen>
    with SingleTickerProviderStateMixin {
  final _service = TransactionService();
  late TabController _tabController;

  bool _loading = true;
  List<TransactionModel> _all = [];

  // Computed data
  List<_MonthData> _last6Months = [];
  List<double> _dayOfWeekSpend = List.filled(7, 0); // Mon–Sun
  List<_CategoryTrend> _categoryTrends = [];
  List<_Insight> _insights = [];
  double _savingsRate = 0;
  double _avgDailySpend = 0;
  int _noSpendDays = 0;
  String? _biggestDayLabel;
  double _biggestDayAmount = 0;

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
    final all = await _service.getTransactionsList();
    setState(() {
      _all = all;
      _compute();
      _loading = false;
    });
  }

  // ── All computation ─────────────────────────────────────────────────────────
  void _compute() {
    _computeMonthlyTrend();
    _computeDayOfWeek();
    _computeCategoryTrends();
    _computeKPIs();
    _generateInsights();
  }

  void _computeMonthlyTrend() {
    final now = DateTime.now();
    _last6Months = [];
    for (int i = 5; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final end = DateTime(month.year, month.month + 1, 1);
      final txns = _all.where((t) =>
          t.date.isAfter(month.subtract(const Duration(days: 1))) &&
          t.date.isBefore(end));
      final income = txns
          .where((t) => t.type == 'income')
          .fold(0.0, (s, t) => s + t.amount);
      final expense = txns
          .where((t) => t.type == 'expense')
          .fold(0.0, (s, t) => s + t.amount);
      _last6Months.add(_MonthData(
        label: DateFormat('MMM').format(month),
        income: income,
        expense: expense,
        savings: income - expense,
      ));
    }
  }

  void _computeDayOfWeek() {
    _dayOfWeekSpend = List.filled(7, 0);
    final expenses = _all.where((t) => t.type == 'expense');
    for (final t in expenses) {
      final dow = t.date.weekday - 1; // 0=Mon 6=Sun
      _dayOfWeekSpend[dow] += t.amount;
    }
  }

  void _computeCategoryTrends() {
    final now = DateTime.now();
    final thisMonthStart = DateTime(now.year, now.month, 1);
    final lastMonthStart = DateTime(now.year, now.month - 1, 1);

    final thisMonth = _all
        .where((t) =>
            t.type == 'expense' && t.date.isAfter(thisMonthStart))
        .toList();
    final lastMonth = _all
        .where((t) =>
            t.type == 'expense' &&
            t.date.isAfter(lastMonthStart) &&
            t.date.isBefore(thisMonthStart))
        .toList();

    final thisMap = <String, double>{};
    final lastMap = <String, double>{};
    for (final t in thisMonth) {
      thisMap[t.category] = (thisMap[t.category] ?? 0) + t.amount;
    }
    for (final t in lastMonth) {
      lastMap[t.category] = (lastMap[t.category] ?? 0) + t.amount;
    }

    final allCats = {...thisMap.keys, ...lastMap.keys};
    _categoryTrends = allCats.map((cat) {
      final cur = thisMap[cat] ?? 0;
      final prev = lastMap[cat] ?? 0;
      double change = 0;
      if (prev > 0) change = ((cur - prev) / prev) * 100;
      return _CategoryTrend(
          category: cat,
          thisMonth: cur,
          lastMonth: prev,
          changePercent: change);
    }).toList();
    _categoryTrends.sort((a, b) => b.thisMonth.compareTo(a.thisMonth));
  }

  void _computeKPIs() {
    final now = DateTime.now();
    final thisMonthStart = DateTime(now.year, now.month, 1);
    final thisMonth =
        _all.where((t) => t.date.isAfter(thisMonthStart)).toList();

    final income = thisMonth
        .where((t) => t.type == 'income')
        .fold(0.0, (s, t) => s + t.amount);
    final expense = thisMonth
        .where((t) => t.type == 'expense')
        .fold(0.0, (s, t) => s + t.amount);

    _savingsRate = income > 0 ? ((income - expense) / income) * 100 : 0;

    // Avg daily spend (last 30 days)
    final last30 = _all.where((t) =>
        t.type == 'expense' &&
        t.date.isAfter(now.subtract(const Duration(days: 30))));
    _avgDailySpend =
        last30.fold(0.0, (s, t) => s + t.amount) / 30;

    // No-spend days this month
    final expenseDays = thisMonth
        .where((t) => t.type == 'expense')
        .map((t) => DateFormat('yyyy-MM-dd').format(t.date))
        .toSet();
    final daysInMonth = now.day;
    _noSpendDays = daysInMonth - expenseDays.length;

    // Biggest spending day
    final dayMap = <String, double>{};
    for (final t in _all.where((t) => t.type == 'expense')) {
      final key = DateFormat('yyyy-MM-dd').format(t.date);
      dayMap[key] = (dayMap[key] ?? 0) + t.amount;
    }
    if (dayMap.isNotEmpty) {
      final sorted = dayMap.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final best = sorted.first;
      _biggestDayAmount = best.value;
      _biggestDayLabel = DateFormat('d MMM yyyy')
          .format(DateTime.parse(best.key));
    }
  }

  void _generateInsights() {
    _insights = [];
    final now = DateTime.now();
    final thisMonthStart = DateTime(now.year, now.month, 1);
    final lastMonthStart = DateTime(now.year, now.month - 1, 1);

    final thisMonthExp = _all
        .where((t) =>
            t.type == 'expense' && t.date.isAfter(thisMonthStart))
        .fold(0.0, (s, t) => s + t.amount);
    final lastMonthExp = _all
        .where((t) =>
            t.type == 'expense' &&
            t.date.isAfter(lastMonthStart) &&
            t.date.isBefore(thisMonthStart))
        .fold(0.0, (s, t) => s + t.amount);

    // 1. Month comparison
    if (lastMonthExp > 0) {
      final diff = thisMonthExp - lastMonthExp;
      final pct = ((diff / lastMonthExp) * 100).abs().toStringAsFixed(0);
      if (diff > 0) {
        _insights.add(_Insight(
          icon: '📈',
          color: Colors.orange,
          title: 'Spending Up This Month',
          body:
              'You\'ve spent ₹${diff.toStringAsFixed(0)} more than last month ($pct% increase).',
          type: 'warning',
        ));
      } else if (diff < 0) {
        _insights.add(_Insight(
          icon: '📉',
          color: Colors.green,
          title: 'Great! Spending Down',
          body:
              'You\'ve spent ₹${diff.abs().toStringAsFixed(0)} less than last month ($pct% decrease).',
          type: 'positive',
        ));
      }
    }

    // 2. Savings rate insight
    if (_savingsRate >= 20) {
      _insights.add(_Insight(
        icon: '💰',
        color: Colors.green,
        title: 'Excellent Savings Rate',
        body:
            'You\'re saving ${_savingsRate.toStringAsFixed(0)}% of your income this month. Keep it up!',
        type: 'positive',
      ));
    } else if (_savingsRate > 0 && _savingsRate < 10) {
      _insights.add(_Insight(
        icon: '⚠️',
        color: Colors.orange,
        title: 'Low Savings Rate',
        body:
            'You\'re saving only ${_savingsRate.toStringAsFixed(0)}% of income. Try to reach 20%.',
        type: 'warning',
      ));
    } else if (_savingsRate < 0) {
      _insights.add(_Insight(
        icon: '🚨',
        color: Colors.red,
        title: 'Spending More Than Earning',
        body:
            'Your expenses exceed income by ₹${(_savingsRate.abs() / 100 * thisMonthExp).toStringAsFixed(0)} this month.',
        type: 'alert',
      ));
    }

    // 3. Category spikes
    for (final trend in _categoryTrends.take(5)) {
      if (trend.changePercent > 50 && trend.lastMonth > 0) {
        _insights.add(_Insight(
          icon: '🔺',
          color: Colors.orange,
          title: '${trend.category} Spending Spike',
          body:
              '${trend.changePercent.toStringAsFixed(0)}% more on ${trend.category} vs last month (₹${trend.thisMonth.toStringAsFixed(0)} vs ₹${trend.lastMonth.toStringAsFixed(0)}).',
          type: 'warning',
        ));
      }
    }

    // 4. Day of week insight
    final maxDow = _dayOfWeekSpend.reduce((a, b) => a > b ? a : b);
    if (maxDow > 0) {
      final maxIdx = _dayOfWeekSpend.indexOf(maxDow);
      const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
      _insights.add(_Insight(
        icon: '📅',
        color: Colors.blue,
        title: '${days[maxIdx]} is Your Big Spend Day',
        body:
            'You spend the most on ${days[maxIdx]}. Try to plan purchases ahead to stay on budget.',
        type: 'info',
      ));
    }

    // 5. No-spend days
    if (_noSpendDays >= 5) {
      _insights.add(_Insight(
        icon: '🎯',
        color: Colors.green,
        title: '$_noSpendDays No-Spend Days This Month',
        body: 'Great discipline! You had $_noSpendDays days with zero spending.',
        type: 'positive',
      ));
    }

    // 6. Daily average
    if (_avgDailySpend > 0) {
      _insights.add(_Insight(
        icon: '📊',
        color: Colors.blue,
        title: 'Daily Spending Average',
        body:
            'You spend ₹${_avgDailySpend.toStringAsFixed(0)} on average per day over the last 30 days.',
        type: 'info',
      ));
    }

    if (_insights.isEmpty) {
      _insights.add(_Insight(
        icon: '📝',
        color: Colors.grey,
        title: 'Not Enough Data Yet',
        body:
            'Add more transactions to start seeing personalized financial insights.',
        type: 'info',
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial Insights'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Insights'),
            Tab(text: 'Trends'),
            Tab(text: 'Patterns'),
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
                  _buildInsightsTab(theme),
                  _buildTrendsTab(theme),
                  _buildPatternsTab(theme),
                ],
              ),
            ),
    );
  }

  // ── Tab 1: Smart Insights ────────────────────────────────────────────────────
  Widget _buildInsightsTab(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // KPI row
        Row(
          children: [
            _kpiCard('Savings Rate',
                '${_savingsRate.toStringAsFixed(1)}%',
                _savingsRate >= 20
                    ? Colors.green
                    : _savingsRate >= 0
                        ? Colors.orange
                        : Colors.red,
                Icons.savings),
            const SizedBox(width: 10),
            _kpiCard('Avg/Day',
                '₹${_avgDailySpend.toStringAsFixed(0)}',
                Colors.blue,
                Icons.today),
            const SizedBox(width: 10),
            _kpiCard('No-Spend\nDays',
                '$_noSpendDays',
                Colors.teal,
                Icons.event_available),
          ],
        ),
        const SizedBox(height: 16),

        // Biggest day card
        if (_biggestDayLabel != null)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2A2A2A) : Colors.amber[50],
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.amber.withOpacity(0.4)),
            ),
            child: Row(
              children: [
                const Text('🔥', style: TextStyle(fontSize: 28)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Biggest Spending Day Ever',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13)),
                      Text(
                        '$_biggestDayLabel — ₹${_biggestDayAmount.toStringAsFixed(0)}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),

        // Insight cards
        Text('Your Financial Health',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        ..._insights.map((i) => _insightCard(i, isDark)),
      ],
    );
  }

  Widget _kpiCard(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _insightCard(_Insight insight, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: insight.color.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: insight.color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(insight.icon,
                  style: const TextStyle(fontSize: 20)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(insight.title,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: insight.color)),
                const SizedBox(height: 4),
                Text(insight.body,
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                        height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab 2: Trends (6-month line chart) ──────────────────────────────────────
  Widget _buildTrendsTab(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;

    if (_last6Months.isEmpty ||
        _last6Months.every((m) => m.income == 0 && m.expense == 0)) {
      return const Center(
        child: Text('No data for the last 6 months',
            style: TextStyle(color: Colors.grey)),
      );
    }

    final maxY = _last6Months
            .map((m) => m.income > m.expense ? m.income : m.expense)
            .reduce((a, b) => a > b ? a : b) *
        1.2;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 6-month line chart
        _sectionTitle('6-Month Income vs Expense'),
        const SizedBox(height: 12),
        Container(
          height: 220,
          padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
          decoration: _cardDecor(isDark),
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: maxY > 0 ? maxY : 10000,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: Colors.grey.withOpacity(0.15),
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (v, _) {
                      final idx = v.toInt();
                      if (idx < 0 || idx >= _last6Months.length) {
                        return const SizedBox();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(_last6Months[idx].label,
                            style: const TextStyle(fontSize: 10)),
                      );
                    },
                    reservedSize: 28,
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 44,
                    getTitlesWidget: (v, _) => Text(
                      '₹${(v / 1000).toStringAsFixed(0)}k',
                      style: const TextStyle(fontSize: 9),
                    ),
                  ),
                ),
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
              ),
              lineBarsData: [
                // Income line
                LineChartBarData(
                  spots: _last6Months.asMap().entries
                      .map((e) => FlSpot(e.key.toDouble(), e.value.income))
                      .toList(),
                  isCurved: true,
                  color: Colors.green,
                  barWidth: 2.5,
                  dotData: FlDotData(
                    getDotPainter: (_, __, ___, ____) =>
                        FlDotCirclePainter(
                            radius: 4,
                            color: Colors.green,
                            strokeWidth: 2,
                            strokeColor: Colors.white),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    color: Colors.green.withOpacity(0.07),
                  ),
                ),
                // Expense line
                LineChartBarData(
                  spots: _last6Months.asMap().entries
                      .map((e) => FlSpot(e.key.toDouble(), e.value.expense))
                      .toList(),
                  isCurved: true,
                  color: Colors.red,
                  barWidth: 2.5,
                  dotData: FlDotData(
                    getDotPainter: (_, __, ___, ____) =>
                        FlDotCirclePainter(
                            radius: 4,
                            color: Colors.red,
                            strokeWidth: 2,
                            strokeColor: Colors.white),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    color: Colors.red.withOpacity(0.07),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _legend(Colors.green, 'Income'),
            const SizedBox(width: 20),
            _legend(Colors.red, 'Expense'),
          ],
        ),
        const SizedBox(height: 24),

        // Savings bar chart
        _sectionTitle('Monthly Savings'),
        const SizedBox(height: 12),
        Container(
          height: 180,
          padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
          decoration: _cardDecor(isDark),
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: _last6Months
                      .map((m) => m.savings.abs())
                      .reduce((a, b) => a > b ? a : b) *
                  1.3,
              barTouchData: BarTouchData(enabled: false),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (v, _) {
                      final idx = v.toInt();
                      if (idx < 0 || idx >= _last6Months.length) {
                        return const SizedBox();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(_last6Months[idx].label,
                            style: const TextStyle(fontSize: 10)),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 44,
                    getTitlesWidget: (v, _) => Text(
                      '₹${(v / 1000).toStringAsFixed(0)}k',
                      style: const TextStyle(fontSize: 9),
                    ),
                  ),
                ),
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: Colors.grey.withOpacity(0.15),
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              barGroups: _last6Months.asMap().entries.map((e) {
                final savings = e.value.savings;
                return BarChartGroupData(
                  x: e.key,
                  barRods: [
                    BarChartRodData(
                      toY: savings < 0 ? 0 : savings,
                      color: savings >= 0 ? Colors.teal : Colors.red,
                      width: 20,
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4)),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Month table
        _sectionTitle('Month Summary'),
        const SizedBox(height: 10),
        Container(
          decoration: _cardDecor(isDark),
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                        flex: 2,
                        child: Text('Month',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w600))),
                    Expanded(
                        child: Text('Income',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.green,
                                fontWeight: FontWeight.w600))),
                    Expanded(
                        child: Text('Expense',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.red,
                                fontWeight: FontWeight.w600))),
                    Expanded(
                        child: Text('Saved',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.teal,
                                fontWeight: FontWeight.w600))),
                  ],
                ),
              ),
              const Divider(height: 1),
              ..._last6Months.reversed.map((m) {
                final isPositive = m.savings >= 0;
                return Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      Expanded(
                          flex: 2,
                          child: Text(m.label,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13))),
                      Expanded(
                          child: Text(
                              '₹${(m.income / 1000).toStringAsFixed(1)}k',
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.green))),
                      Expanded(
                          child: Text(
                              '₹${(m.expense / 1000).toStringAsFixed(1)}k',
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.red))),
                      Expanded(
                          child: Text(
                              '${isPositive ? '+' : ''}₹${(m.savings / 1000).toStringAsFixed(1)}k',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: isPositive
                                      ? Colors.teal
                                      : Colors.red,
                                  fontWeight: FontWeight.w600))),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ── Tab 3: Patterns ──────────────────────────────────────────────────────────
  Widget _buildPatternsTab(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    const dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final maxDow =
        _dayOfWeekSpend.reduce((a, b) => a > b ? a : b);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Day-of-week spending
        _sectionTitle('Spending by Day of Week'),
        const SizedBox(height: 4),
        Text('All-time total spending per weekday',
            style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: _cardDecor(isDark),
          child: Column(
            children: List.generate(7, (i) {
              final val = _dayOfWeekSpend[i];
              final pct = maxDow > 0 ? val / maxDow : 0.0;
              final isMax = val == maxDow && maxDow > 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    SizedBox(
                      width: 32,
                      child: Text(dayLabels[i],
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: isMax
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isMax
                                  ? Colors.orange
                                  : null)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Stack(
                        children: [
                          Container(
                            height: 22,
                            decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: pct.clamp(0.0, 1.0),
                            child: Container(
                              height: 22,
                              decoration: BoxDecoration(
                                color: isMax
                                    ? Colors.orange
                                    : theme.colorScheme.primary
                                        .withOpacity(0.7),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 64,
                      child: Text(
                        val > 0
                            ? '₹${(val / 1000).toStringAsFixed(1)}k'
                            : '—',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            fontSize: 11,
                            color: isMax ? Colors.orange : Colors.grey[600],
                            fontWeight: isMax
                                ? FontWeight.bold
                                : FontWeight.normal),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 24),

        // Category MoM trend
        _sectionTitle('Category Trend (This vs Last Month)'),
        const SizedBox(height: 4),
        Text('How each category changed month-over-month',
            style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        const SizedBox(height: 12),
        if (_categoryTrends.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: _cardDecor(isDark),
            child: const Center(
              child: Text('No category data yet',
                  style: TextStyle(color: Colors.grey)),
            ),
          )
        else
          Container(
            decoration: _cardDecor(isDark),
            child: Column(
              children: _categoryTrends.take(8).map((trend) {
                final up = trend.changePercent > 0;
                final same = trend.lastMonth == 0;
                Color arrowColor;
                IconData arrow;
                String changeLabel;

                if (same) {
                  arrowColor = Colors.blue;
                  arrow = Icons.fiber_new;
                  changeLabel = 'New';
                } else if (up) {
                  arrowColor = trend.changePercent > 30
                      ? Colors.red
                      : Colors.orange;
                  arrow = Icons.arrow_upward;
                  changeLabel =
                      '+${trend.changePercent.toStringAsFixed(0)}%';
                } else {
                  arrowColor = Colors.green;
                  arrow = Icons.arrow_downward;
                  changeLabel =
                      '${trend.changePercent.toStringAsFixed(0)}%';
                }

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          Icon(_categoryIcon(trend.category),
                              size: 18, color: Colors.grey[600]),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(trend.category,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13)),
                                Text(
                                  'Last: ₹${trend.lastMonth.toStringAsFixed(0)}  →  This: ₹${trend.thisMonth.toStringAsFixed(0)}',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[500]),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: arrowColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(arrow,
                                    size: 14, color: arrowColor),
                                const SizedBox(width: 3),
                                Text(changeLabel,
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: arrowColor,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (trend != _categoryTrends.take(8).last)
                      const Divider(height: 1, indent: 14),
                  ],
                );
              }).toList(),
            ),
          ),
        const SizedBox(height: 32),
      ],
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────
  Widget _sectionTitle(String t) => Text(t,
      style:
          const TextStyle(fontSize: 15, fontWeight: FontWeight.bold));

  Widget _legend(Color color, String label) => Row(
        children: [
          Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                  color: color, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      );

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

  IconData _categoryIcon(String cat) {
    switch (cat) {
      case 'Food & Dining':
        return Icons.restaurant;
      case 'Transportation':
        return Icons.directions_car;
      case 'Shopping':
        return Icons.shopping_bag;
      case 'Entertainment':
        return Icons.movie;
      case 'Bills & Utilities':
        return Icons.receipt_long;
      case 'Healthcare':
        return Icons.local_hospital;
      case 'Education':
        return Icons.school;
      case 'Personal Care':
        return Icons.face;
      case 'Travel':
        return Icons.flight;
      default:
        return Icons.category;
    }
  }
}

// ── Data classes ──────────────────────────────────────────────────────────────
class _MonthData {
  final String label;
  final double income;
  final double expense;
  final double savings;
  const _MonthData(
      {required this.label,
      required this.income,
      required this.expense,
      required this.savings});
}

class _CategoryTrend {
  final String category;
  final double thisMonth;
  final double lastMonth;
  final double changePercent;
  const _CategoryTrend(
      {required this.category,
      required this.thisMonth,
      required this.lastMonth,
      required this.changePercent});
}

class _Insight {
  final String icon;
  final Color color;
  final String title;
  final String body;
  final String type;
  const _Insight(
      {required this.icon,
      required this.color,
      required this.title,
      required this.body,
      required this.type});
}