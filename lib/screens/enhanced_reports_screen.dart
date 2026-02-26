import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/transaction_model.dart';
import '../models/account_model.dart';
import '../services/transaction_service.dart';
import '../services/account_service.dart';
import 'category_transactions_screen.dart';
import 'account_detail_screen.dart';

class EnhancedReportsScreen extends StatefulWidget {
  const EnhancedReportsScreen({super.key});

  @override
  State<EnhancedReportsScreen> createState() =>
      _EnhancedReportsScreenState();
}

class _EnhancedReportsScreenState extends State<EnhancedReportsScreen>
    with SingleTickerProviderStateMixin {
  final _txnSvc = TransactionService();
  final _accSvc = AccountService();
  late TabController _tabCtrl;

  String _period = 'This Month';
  final _periods = ['This Week', 'This Month', 'Last Month', 'This Year'];

  bool _loading = true;
  List<TransactionModel> _all = [];
  List<TransactionModel> _filtered = [];
  List<AccountModel> _accounts = [];

  static const _catColors = [
    Color(0xFFE53935), Color(0xFFFB8C00), Color(0xFFFDD835),
    Color(0xFF43A047), Color(0xFF1E88E5), Color(0xFF8E24AA),
    Color(0xFF00ACC1), Color(0xFF6D4C41), Color(0xFF546E7A),
    Color(0xFFEC407A), Color(0xFF26A69A), Color(0xFFFF7043),
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final txns = await _txnSvc.getTransactionsList();
    final accs = await _accSvc.getAccounts().first;
    setState(() {
      _all      = txns;
      _accounts = accs;
      _applyFilter();
      _loading  = false;
    });
  }

  void _applyFilter() {
    final now = DateTime.now();
    DateTime start;
    DateTime? end;
    switch (_period) {
      case 'This Week':
        final wd = now.weekday;
        start = DateTime(now.year, now.month, now.day - (wd - 1));
        break;
      case 'Last Month':
        start = DateTime(now.year, now.month - 1, 1);
        end   = DateTime(now.year, now.month, 1);
        break;
      case 'This Year':
        start = DateTime(now.year, 1, 1);
        break;
      default:
        start = DateTime(now.year, now.month, 1);
    }
    _filtered = _all.where((t) {
      final after  = !t.date.isBefore(start);
      final before = end == null || t.date.isBefore(end);
      return after && before;
    }).toList();
  }

  List<TransactionModel> get _expenses =>
      _filtered.where((t) => t.type == 'expense').toList();
  List<TransactionModel> get _income =>
      _filtered.where((t) => t.type == 'income').toList();

  double get _totalExp =>
      _expenses.fold(0.0, (s, t) => s + t.amount);
  double get _totalInc =>
      _income.fold(0.0, (s, t) => s + t.amount);
  double get _netSavings => _totalInc - _totalExp;
  double get _savingsRate =>
      _totalInc > 0 ? (_netSavings / _totalInc * 100) : 0;

  Map<String, double> get _catMap {
    final m = <String, double>{};
    for (final t in _expenses) {
      m[t.category] = (m[t.category] ?? 0) + t.amount;
    }
    return m;
  }

  List<MapEntry<String, double>> get _sortedCats {
    final list = _catMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return list;
  }

  void _openCategory(String cat, Color color) {
    final txns =
        _filtered.where((t) => t.type == 'expense' && t.category == cat).toList();
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => CategoryTransactionsScreen(
          category: cat, transactions: txns, color: color),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_loading) {
      return Scaffold(
        appBar: _appBar(isDark),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0D1117) : const Color(0xFFF0F2F5),
      appBar: _appBar(isDark),
      body: Column(children: [
        // ── Period selector ──────────────────────────────────────────────
        _periodSelector(isDark),
        // ── Tab bar ──────────────────────────────────────────────────────
        _tabBar(isDark),
        // ── Tab views ────────────────────────────────────────────────────
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [
              _overviewTab(isDark),
              _categoriesTab(isDark),
              _accountsTab(isDark),
              _trendsTab(isDark),
            ],
          ),
        ),
      ]),
    );
  }

  PreferredSizeWidget _appBar(bool isDark) => AppBar(
        title: const Text('Reports & Analytics'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh), onPressed: _load)
        ],
      );

  // ── Period selector ─────────────────────────────────────────────────────────
  Widget _periodSelector(bool isDark) => Container(
        color: const Color(0xFF1565C0),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: _periods.map((p) {
              final sel = _period == p;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() {
                    _period = p;
                    _applyFilter();
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    decoration: BoxDecoration(
                      color: sel ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(p,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: sel
                                ? const Color(0xFF1565C0)
                                : Colors.white70)),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      );

  // ── Tab bar ─────────────────────────────────────────────────────────────────
  Widget _tabBar(bool isDark) => Container(
        color: isDark ? const Color(0xFF1A2035) : Colors.white,
        child: TabBar(
          controller: _tabCtrl,
          labelColor: const Color(0xFF1565C0),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF1565C0),
          indicatorWeight: 3,
          labelStyle: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.bold),
          tabs: const [
            Tab(icon: Icon(Icons.dashboard_outlined, size: 18),
                text: 'Overview'),
            Tab(icon: Icon(Icons.pie_chart_outline, size: 18),
                text: 'Categories'),
            Tab(icon: Icon(Icons.account_balance_outlined, size: 18),
                text: 'Accounts'),
            Tab(icon: Icon(Icons.trending_up_outlined, size: 18),
                text: 'Trends'),
          ],
        ),
      );

  // ════════════════════════════════════════════════════════════════════════════
  // TAB 1: OVERVIEW
  // ════════════════════════════════════════════════════════════════════════════
  Widget _overviewTab(bool isDark) => RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          children: [
            // 3 summary cards
            Row(children: [
              _summaryCard('Income',  _totalInc,
                  const Color(0xFF2E7D32), Icons.arrow_upward, isDark),
              const SizedBox(width: 10),
              _summaryCard('Expense', _totalExp,
                  const Color(0xFFC62828), Icons.arrow_downward, isDark),
              const SizedBox(width: 10),
              _summaryCard('Savings', _netSavings,
                  _netSavings >= 0
                      ? const Color(0xFF1565C0)
                      : const Color(0xFFE65100),
                  _netSavings >= 0
                      ? Icons.savings_outlined
                      : Icons.warning_amber_outlined,
                  isDark),
            ]),
            const SizedBox(height: 14),

            // Savings rate progress
            _savingsRateCard(isDark),
            const SizedBox(height: 14),

            // Income vs Expense bar chart
            _sectionTitle('Income vs Expense', isDark),
            const SizedBox(height: 8),
            _barChart(isDark),
            const SizedBox(height: 14),

            // Top 3 expense categories preview
            if (_sortedCats.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _sectionTitle('Top Categories', isDark),
                  TextButton(
                    onPressed: () => _tabCtrl.animateTo(1),
                    child: const Text('See all',
                        style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF1565C0))),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _topCategoriesPreview(isDark),
            ],

            const SizedBox(height: 14),

            // Recent transactions
            _sectionTitle('Recent Transactions', isDark),
            const SizedBox(height: 8),
            _recentList(isDark),
          ],
        ),
      );

  // ════════════════════════════════════════════════════════════════════════════
  // TAB 2: CATEGORIES
  // ════════════════════════════════════════════════════════════════════════════
  Widget _categoriesTab(bool isDark) => _sortedCats.isEmpty
      ? _emptyState('No expense data', isDark)
      : RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding:
                const EdgeInsets.fromLTRB(16, 16, 16, 80),
            children: [
              // Pie chart
              _pieChart(isDark),
              const SizedBox(height: 16),

              // Full category list — all tappable
              _sectionTitle(
                  'All Categories  (tap to drill down)', isDark),
              const SizedBox(height: 8),
              _fullCategoryList(isDark),
            ],
          ),
        );

  // ════════════════════════════════════════════════════════════════════════════
  // TAB 3: ACCOUNTS
  // ════════════════════════════════════════════════════════════════════════════
  Widget _accountsTab(bool isDark) {
    if (_accounts.isEmpty) return _emptyState('No accounts found', isDark);
    final totalBal =
        _accounts.fold(0.0, (s, a) => s + a.balance);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        children: [
          // Total balance hero
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1565C0), Color(0xFF1976D2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: const Color(0xFF1565C0).withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6))
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Net Worth',
                    style: TextStyle(
                        color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 6),
                Text(_fmt(totalBal),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Across ${_accounts.length} accounts',
                    style: const TextStyle(
                        color: Colors.white60, fontSize: 12)),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Account type summary
          _accountTypeSummary(isDark),

          const SizedBox(height: 16),

          // Individual account cards
          _sectionTitle('All Accounts', isDark),
          const SizedBox(height: 8),
          ..._accounts.map((a) => _accountCard(a, isDark)),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // TAB 4: TRENDS
  // ════════════════════════════════════════════════════════════════════════════
  Widget _trendsTab(bool isDark) {
    // Build last 6 months data
    final now = DateTime.now();
    final months = List.generate(6, (i) {
      final m = DateTime(now.year, now.month - (5 - i), 1);
      return m;
    });

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        children: [
          _sectionTitle('6-Month Trend', isDark),
          const SizedBox(height: 8),
          _monthlyTrendChart(months, isDark),
          const SizedBox(height: 16),
          _sectionTitle('Monthly Summary Table', isDark),
          const SizedBox(height: 8),
          _monthlyTable(months, isDark),
        ],
      ),
    );
  }

  // ── Widgets ─────────────────────────────────────────────────────────────────

  Widget _summaryCard(String label, double amount,
      Color color, IconData icon, bool isDark) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2530) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border(left: BorderSide(color: color, width: 3)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 6)
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(icon, color: color, size: 13),
                const SizedBox(width: 4),
                Text(label,
                    style: TextStyle(
                        fontSize: 10, color: Colors.grey[500])),
              ]),
              const SizedBox(height: 6),
              Text(_fmt(amount),
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: color)),
            ],
          ),
        ),
      );

  Widget _savingsRateCard(bool isDark) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2530) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04), blurRadius: 6)
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Savings Rate',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13)),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _savingsRateColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${_savingsRate.toStringAsFixed(1)}%',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: _savingsRateColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (_savingsRate / 100).clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: Colors.grey.shade200,
                color: _savingsRateColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(_savingsRateMessage,
                style:
                    TextStyle(fontSize: 11, color: Colors.grey[500])),
          ],
        ),
      );

  Color get _savingsRateColor => _savingsRate >= 20
      ? const Color(0xFF2E7D32)
      : _savingsRate >= 0
          ? const Color(0xFFFB8C00)
          : const Color(0xFFC62828);

  String get _savingsRateMessage => _savingsRate >= 30
      ? 'Excellent! Saving ${_savingsRate.toStringAsFixed(0)}% of income'
      : _savingsRate >= 20
          ? 'Good saving habit! Keep it up'
          : _savingsRate >= 0
              ? 'Try to save at least 20% of income'
              : 'Spending more than earning this period';

  Widget _barChart(bool isDark) {
    final maxY =
        (_totalInc > _totalExp ? _totalInc : _totalExp) * 1.3;
    return Container(
      height: 160,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2530) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04), blurRadius: 6)
        ],
      ),
      child: BarChart(BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY > 0 ? maxY : 100,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (g, gi, rod, ri) => BarTooltipItem(
                _fmt(rod.toY),
                const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11)),
          ),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) {
                switch (v.toInt()) {
                  case 0: return const Text('Income',   style: TextStyle(fontSize: 10));
                  case 1: return const Text('Expense',  style: TextStyle(fontSize: 10));
                  case 2: return const Text('Savings',  style: TextStyle(fontSize: 10));
                  default: return const Text('');
                }
              },
            ),
          ),
          leftTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData:   const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: [
          BarChartGroupData(x: 0, barRods: [BarChartRodData(
              toY: _totalInc,
              color: const Color(0xFF2E7D32),
              width: 28,
              borderRadius: BorderRadius.circular(5))]),
          BarChartGroupData(x: 1, barRods: [BarChartRodData(
              toY: _totalExp,
              color: const Color(0xFFC62828),
              width: 28,
              borderRadius: BorderRadius.circular(5))]),
          BarChartGroupData(x: 2, barRods: [BarChartRodData(
              toY: _netSavings.abs(),
              color: _netSavings >= 0
                  ? const Color(0xFF1565C0)
                  : const Color(0xFFE65100),
              width: 28,
              borderRadius: BorderRadius.circular(5))]),
        ],
      )),
    );
  }

  Widget _topCategoriesPreview(bool isDark) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2530) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04), blurRadius: 6)
          ],
        ),
        child: Column(
          children: _sortedCats.take(3).toList().asMap().entries.map((e) {
            final color = _catColors[e.key % _catColors.length];
            final pct   = _totalExp > 0 ? e.value.value / _totalExp : 0.0;
            return InkWell(
              onTap: () => _openCategory(e.value.key, color),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                child: Row(children: [
                  Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(
                        color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(e.value.key,
                        style: const TextStyle(fontSize: 13)),
                  ),
                  Text(_fmt(e.value.value),
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: color)),
                  const SizedBox(width: 8),
                  Text('${(pct * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey[400])),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right,
                      size: 14, color: Colors.grey[300]),
                ]),
              ),
            );
          }).toList(),
        ),
      );

  Widget _pieChart(bool isDark) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2530) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05), blurRadius: 8)
          ],
        ),
        child: Column(children: [
          SizedBox(
            height: 220,
            child: Row(children: [
              Expanded(
                flex: 3,
                child: PieChart(PieChartData(
                  pieTouchData: PieTouchData(
                    touchCallback: (event, resp) {
                      if (event is FlTapUpEvent &&
                          resp?.touchedSection != null) {
                        final idx = resp!.touchedSection!
                            .touchedSectionIndex;
                        if (idx >= 0 && idx < _sortedCats.length) {
                          _openCategory(
                              _sortedCats[idx].key,
                              _catColors[idx % _catColors.length]);
                        }
                      }
                    },
                  ),
                  sections: _sortedCats.take(8).toList().asMap().entries.map((e) {
                    final pct = e.value.value / _totalExp * 100;
                    return PieChartSectionData(
                      value: e.value.value,
                      title: pct > 7 ? '${pct.toStringAsFixed(0)}%' : '',
                      color: _catColors[e.key % _catColors.length],
                      radius: 78,
                      titleStyle: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    );
                  }).toList(),
                  sectionsSpace: 2,
                  centerSpaceRadius: 32,
                )),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _sortedCats.take(8).toList().asMap().entries.map((e) {
                    final c = _catColors[e.key % _catColors.length];
                    return GestureDetector(
                      onTap: () => _openCategory(e.value.key, c),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(children: [
                          Container(width: 10, height: 10,
                              decoration: BoxDecoration(
                                  color: c, shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(e.value.key,
                                style: const TextStyle(fontSize: 10),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                        ]),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 6),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.touch_app, size: 11, color: Colors.grey[400]),
            const SizedBox(width: 4),
            Text('Tap slice or name to see transactions',
                style: TextStyle(fontSize: 10, color: Colors.grey[400])),
          ]),
        ]),
      );

  Widget _fullCategoryList(bool isDark) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2530) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05), blurRadius: 8)
          ],
        ),
        child: Column(
          children: _sortedCats.asMap().entries.map((e) {
            final i     = e.key;
            final cat   = e.value.key;
            final amt   = e.value.value;
            final color = _catColors[i % _catColors.length];
            final pct   = _totalExp > 0 ? amt / _totalExp : 0.0;
            final count = _expenses
                .where((t) => t.category == cat)
                .length;

            return Column(children: [
              InkWell(
                onTap: () => _openCategory(cat, color),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  child: Column(children: [
                    Row(children: [
                      Container(
                        width: 38, height: 38,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(_catEmoji(cat),
                              style:
                                  const TextStyle(fontSize: 16)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(cat,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13)),
                          Text('$count transactions',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[400])),
                        ],
                      )),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(_fmt(amt),
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14, color: color)),
                          Text(
                            '${(pct * 100).toStringAsFixed(1)}%',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey[400]),
                          ),
                        ],
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.chevron_right,
                          size: 14, color: Colors.grey[300]),
                    ]),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct.clamp(0.0, 1.0),
                        minHeight: 5,
                        backgroundColor: Colors.grey.shade100,
                        color: color,
                      ),
                    ),
                  ]),
                ),
              ),
              if (i < _sortedCats.length - 1)
                Divider(height: 1,
                    indent: 66,
                    color: Colors.grey.withOpacity(0.1)),
            ]);
          }).toList(),
        ),
      );

  Widget _accountTypeSummary(bool isDark) {
    final typeMap = <String, double>{};
    for (final a in _accounts) {
      typeMap[a.typeDisplayName] =
          (typeMap[a.typeDisplayName] ?? 0) + a.balance;
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2530) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04), blurRadius: 6)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('By Account Type',
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 12),
          ...typeMap.entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: [
                      Container(
                          width: 8, height: 8,
                          decoration: const BoxDecoration(
                              color: Color(0xFF1565C0),
                              shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Text(e.key,
                          style: const TextStyle(fontSize: 13)),
                    ]),
                    Text(_fmt(e.value),
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: e.value >= 0
                                ? const Color(0xFF2E7D32)
                                : const Color(0xFFC62828))),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _accountCard(AccountModel a, bool isDark) {
    final isPositive = a.balance >= 0;
    return GestureDetector(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => AccountDetailScreen(account: a))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2530) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04), blurRadius: 6)
          ],
        ),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF1565C0).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.account_balance,
                color: Color(0xFF1565C0), size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(a.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14)),
              Text(a.typeDisplayName,
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey[400])),
            ],
          )),
          Text(_fmt(a.balance),
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isPositive
                      ? const Color(0xFF2E7D32)
                      : const Color(0xFFC62828))),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right,
              size: 16, color: Colors.grey[300]),
        ]),
      ),
    );
  }

  Widget _monthlyTrendChart(List<DateTime> months, bool isDark) {
    final incomeData = months.map((m) {
      return _all
          .where((t) =>
              t.type == 'income' &&
              t.date.year == m.year &&
              t.date.month == m.month)
          .fold(0.0, (s, t) => s + t.amount);
    }).toList();

    final expenseData = months.map((m) {
      return _all
          .where((t) =>
              t.type == 'expense' &&
              t.date.year == m.year &&
              t.date.month == m.month)
          .fold(0.0, (s, t) => s + t.amount);
    }).toList();

    final maxY = [...incomeData, ...expenseData]
            .fold(0.0, (a, b) => a > b ? a : b) *
        1.3;

    return Container(
      height: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2530) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05), blurRadius: 8)
        ],
      ),
      child: LineChart(LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: Colors.grey.withOpacity(0.1), strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        maxY: maxY > 0 ? maxY : 100,
        minY: 0,
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) {
                final idx = v.toInt();
                if (idx < 0 || idx >= months.length) return const Text('');
                return Text(DateFormat('MMM').format(months[idx]),
                    style: const TextStyle(fontSize: 9));
              },
              interval: 1,
            ),
          ),
          leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: incomeData.asMap().entries
                .map((e) => FlSpot(e.key.toDouble(), e.value))
                .toList(),
            isCurved: true,
            color: const Color(0xFF2E7D32),
            barWidth: 2.5,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: const Color(0xFF2E7D32).withOpacity(0.08),
            ),
          ),
          LineChartBarData(
            spots: expenseData.asMap().entries
                .map((e) => FlSpot(e.key.toDouble(), e.value))
                .toList(),
            isCurved: true,
            color: const Color(0xFFC62828),
            barWidth: 2.5,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: const Color(0xFFC62828).withOpacity(0.08),
            ),
          ),
        ],
      )),
    );
  }

  Widget _monthlyTable(List<DateTime> months, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2530) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04), blurRadius: 6)
        ],
      ),
      child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(
            color: Color(0xFF1565C0),
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(14)),
          ),
          child: Row(children: [
            Expanded(child: Text('Month',
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11, fontWeight: FontWeight.bold))),
            _tHead('Income'),
            _tHead('Expense'),
            _tHead('Savings'),
          ]),
        ),
        // Rows
        ...months.reversed.map((m) {
          final inc = _all
              .where((t) =>
                  t.type == 'income' &&
                  t.date.year == m.year &&
                  t.date.month == m.month)
              .fold(0.0, (s, t) => s + t.amount);
          final exp = _all
              .where((t) =>
                  t.type == 'expense' &&
                  t.date.year == m.year &&
                  t.date.month == m.month)
              .fold(0.0, (s, t) => s + t.amount);
          final sav = inc - exp;
          final isCurrentMonth =
              m.year == DateTime.now().year &&
              m.month == DateTime.now().month;

          return Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isCurrentMonth
                  ? const Color(0xFF1565C0).withOpacity(0.05)
                  : null,
            ),
            child: Row(children: [
              Expanded(
                child: Text(
                  DateFormat('MMM yy').format(m),
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: isCurrentMonth
                          ? FontWeight.bold
                          : FontWeight.normal),
                ),
              ),
              _tCell(_fmtShort(inc), const Color(0xFF2E7D32)),
              _tCell(_fmtShort(exp), const Color(0xFFC62828)),
              _tCell(
                  _fmtShort(sav),
                  sav >= 0
                      ? const Color(0xFF1565C0)
                      : const Color(0xFFE65100)),
            ]),
          );
        }),
      ]),
    );
  }

  Widget _recentList(bool isDark) {
    final recent = [..._filtered]
      ..sort((a, b) => b.date.compareTo(a.date));
    if (recent.isEmpty) return _emptyState('No transactions', isDark);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2530) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04), blurRadius: 6)
        ],
      ),
      child: Column(
        children: recent.take(5).map((t) {
          final isExp = t.type == 'expense';
          final color = isExp
              ? const Color(0xFFC62828)
              : const Color(0xFF2E7D32);
          return ListTile(
            leading: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(_catEmoji(t.category),
                    style: const TextStyle(fontSize: 17)),
              ),
            ),
            title: Text(
              t.note ?? t.category,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600),
              maxLines: 1, overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${t.category}  •  ${DateFormat('dd MMM').format(t.date)}',
              style: TextStyle(fontSize: 11, color: Colors.grey[400]),
            ),
            trailing: Text(
              '${isExp ? '-' : '+'}${_fmt(t.amount)}',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14, color: color),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _emptyState(String msg, bool isDark) => Center(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.bar_chart_outlined,
                  size: 64, color: Colors.grey[300]),
              const SizedBox(height: 12),
              Text(msg,
                  style: TextStyle(
                      color: Colors.grey[400], fontSize: 14)),
            ],
          ),
        ),
      );

  Widget _sectionTitle(String t, bool isDark) => Text(t,
      style: const TextStyle(
          fontWeight: FontWeight.bold, fontSize: 14));

  Widget _tHead(String t) => Expanded(
        child: Text(t,
            textAlign: TextAlign.right,
            style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.bold)),
      );

  Widget _tCell(String t, Color c) => Expanded(
        child: Text(t,
            textAlign: TextAlign.right,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: c)),
      );

  String _fmt(double v) {
    final abs = v.abs();
    if (abs >= 10000000)
      return '₹${(abs / 10000000).toStringAsFixed(2)}Cr';
    if (abs >= 100000)
      return '₹${(abs / 100000).toStringAsFixed(2)}L';
    return '₹${NumberFormat('#,##,##0').format(abs)}';
  }

  String _fmtShort(double v) {
    final abs = v.abs();
    String s;
    if (abs >= 10000000)      s = '${(abs / 10000000).toStringAsFixed(1)}Cr';
    else if (abs >= 100000)   s = '${(abs / 100000).toStringAsFixed(1)}L';
    else if (abs >= 1000)     s = '${(abs / 1000).toStringAsFixed(0)}k';
    else                      s = abs.toStringAsFixed(0);
    return '${v < 0 ? '-' : ''}₹$s';
  }

  String _catEmoji(String cat) {
    switch (cat.toLowerCase()) {
      case 'food & dining':       return '🍔';
      case 'shopping':            return '🛍️';
      case 'transportation':      return '🚗';
      case 'entertainment':       return '🎬';
      case 'bills & utilities':   return '💡';
      case 'healthcare':          return '💊';
      case 'education':           return '📚';
      case 'personal care':       return '💆';
      case 'travel':              return '✈️';
      case 'salary':              return '💼';
      case 'business':            return '🏢';
      case 'investments':         return '📈';
      case 'freelance':           return '💻';
      case 'gifts':               return '🎁';
      case 'cashback':            return '💳';
      case 'rent':                return '🏠';
      case 'groceries':           return '🛒';
      default:                    return '📦';
    }
  }
}