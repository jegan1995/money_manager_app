import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/transaction_model.dart';
import '../models/budget_model.dart';
import '../services/transaction_service.dart';
import '../services/budget_service.dart';

class EnhancedReportsScreen extends StatefulWidget {
  const EnhancedReportsScreen({super.key});
  @override
  State<EnhancedReportsScreen> createState() => _EnhancedReportsScreenState();
}

class _EnhancedReportsScreenState extends State<EnhancedReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _txnSvc    = TransactionService();
  final _budgetSvc = BudgetService();

  String _period = 'This Month';
  final _periods = ['This Week', 'This Month', 'Last Month', 'This Year'];
  bool _loading = true;
  List<TransactionModel> _txns = [];
  List<TransactionModel> _filtered = [];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await _txnSvc.getTransactionsList();
    setState(() {
      _txns = list;
      _filter();
      _loading = false;
    });
  }

  void _filter() {
    final now = DateTime.now();
    DateTime start;
    DateTime? end;
    switch (_period) {
      case 'This Week':
        start = now.subtract(Duration(days: now.weekday - 1));
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
    _filtered = _txns.where((t) {
      final after  = t.date.isAfter(start.subtract(const Duration(seconds: 1)));
      final before = end == null || t.date.isBefore(end);
      return after && before;
    }).toList();
  }

  String _fmt(double v) {
    final a = v.abs();
    if (a >= 10000000) return '₹${(a/10000000).toStringAsFixed(2)}Cr';
    if (a >= 100000)   return '₹${(a/100000).toStringAsFixed(1)}L';
    if (a >= 1000)     return '₹${(a/1000).toStringAsFixed(1)}K';
    return '₹${a.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg   = isDark ? const Color(0xFF0D1117) : const Color(0xFFF0F4FF);
    final card = isDark ? const Color(0xFF1E2530) : Colors.white;

    return Scaffold(
      backgroundColor: bg,
      body: NestedScrollView(
        headerSliverBuilder: (ctx, _) => [
          SliverAppBar(
            pinned: true,
            backgroundColor: const Color(0xFF667eea),
            foregroundColor: Colors.white,
            title: const Text('Reports & Budget',
                style: TextStyle(fontWeight: FontWeight.bold)),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _load,
              ),
            ],
            bottom: TabBar(
              controller: _tabs,
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              tabs: const [
                Tab(icon: Icon(Icons.bar_chart, size: 18), text: 'Analytics'),
                Tab(icon: Icon(Icons.pie_chart,  size: 18), text: 'Budget'),
              ],
            ),
          ),
        ],
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                controller: _tabs,
                children: [
                  _AnalyticsTab(
                    txns:     _filtered,
                    period:   _period,
                    periods:  _periods,
                    card:     card,
                    isDark:   isDark,
                    fmt:      _fmt,
                    onPeriodChanged: (p) => setState(() {
                      _period = p;
                      _filter();
                    }),
                  ),
                  _BudgetTab(
                    budgetSvc: _budgetSvc,
                    txns:      _txns,
                    card:      card,
                    isDark:    isDark,
                    fmt:       _fmt,
                  ),
                ],
              ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Analytics Tab
// ════════════════════════════════════════════════════════════════════════════
class _AnalyticsTab extends StatelessWidget {
  final List<TransactionModel> txns;
  final String period;
  final List<String> periods;
  final Color card;
  final bool isDark;
  final String Function(double) fmt;
  final ValueChanged<String> onPeriodChanged;

  const _AnalyticsTab({
    required this.txns,
    required this.period,
    required this.periods,
    required this.card,
    required this.isDark,
    required this.fmt,
    required this.onPeriodChanged,
  });

  @override
  Widget build(BuildContext context) {
    final income  = txns.where((t) => t.type == 'income')
        .fold(0.0, (s, t) => s + t.amount);
    final expense = txns.where((t) => t.type == 'expense')
        .fold(0.0, (s, t) => s + t.amount);
    final net     = income - expense;

    // Category breakdown
    final catMap = <String, double>{};
    for (final t in txns.where((t) => t.type == 'expense')) {
      catMap[t.category] = (catMap[t.category] ?? 0) + t.amount;
    }
    final catList = catMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final catColors = [
      const Color(0xFF667eea), const Color(0xFFf093fb),
      const Color(0xFF4facfe), const Color(0xFFFF7043),
      const Color(0xFF43e97b), const Color(0xFFf77062),
      const Color(0xFF11998e), const Color(0xFFAB47BC),
    ];

    return RefreshIndicator(
      color: const Color(0xFF667eea),
      onRefresh: () async {},
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        children: [
          // Period selector
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2530) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(
                  color: Colors.black.withOpacity(0.05), blurRadius: 8)],
            ),
            child: Row(
              children: periods.map((p) {
                final sel = p == period;
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onPeriodChanged(p);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: sel
                            ? const Color(0xFF667eea)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(p.replaceAll('This ', '').replaceAll('Last ', 'Last\n'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: sel ? Colors.white : Colors.grey[400])),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          // Summary cards
          Row(children: [
            Expanded(child: _statCard('Income',  income,  const Color(0xFF2E7D32), Icons.trending_up, card)),
            const SizedBox(width: 10),
            Expanded(child: _statCard('Expense', expense, const Color(0xFFC62828), Icons.trending_down, card)),
            const SizedBox(width: 10),
            Expanded(child: _statCard('Net',     net,
                net >= 0 ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
                net >= 0 ? Icons.savings : Icons.warning_amber, card)),
          ]),
          const SizedBox(height: 20),

          // Pie chart
          if (expense > 0 && catList.isNotEmpty) ...[
            _sectionTitle('Expense Breakdown', isDark),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(
                    color: Colors.black.withOpacity(0.05), blurRadius: 8)],
              ),
              child: Column(children: [
                SizedBox(
                  height: 200,
                  child: PieChart(PieChartData(
                    sections: catList.take(8).toList().asMap().entries.map((e) {
                      final pct = (e.value.value / expense) * 100;
                      return PieChartSectionData(
                        value: e.value.value,
                        color: catColors[e.key % catColors.length],
                        title: '${pct.toStringAsFixed(0)}%',
                        radius: 70,
                        titleStyle: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold),
                      );
                    }).toList(),
                    sectionsSpace: 2,
                    centerSpaceRadius: 40,
                  )),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12, runSpacing: 6,
                  children: catList.take(8).toList().asMap().entries.map((e) =>
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        width: 10, height: 10,
                        decoration: BoxDecoration(
                          color: catColors[e.key % catColors.length],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(e.value.key,
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey[500])),
                    ])
                  ).toList(),
                ),
              ]),
            ),
            const SizedBox(height: 20),
          ],

          // Top categories
          if (catList.isNotEmpty) ...[
            _sectionTitle('Top Spending', isDark),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(
                    color: Colors.black.withOpacity(0.05), blurRadius: 8)],
              ),
              child: Column(
                children: catList.take(6).toList().asMap().entries.map((e) {
                  final pct = expense > 0 ? e.value.value / expense : 0.0;
                  final isLast = e.key == (catList.length > 6 ? 5 : catList.length - 1);
                  return Column(children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(children: [
                        Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(
                            color: catColors[e.key % catColors.length],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(e.value.key,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13)),
                                Text(fmt(e.value.value),
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: catColors[e.key % catColors.length])),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: pct.clamp(0.0, 1.0).toDouble(),
                                backgroundColor:
                                    catColors[e.key % catColors.length]
                                        .withOpacity(0.1),
                                valueColor: AlwaysStoppedAnimation(
                                    catColors[e.key % catColors.length]),
                                minHeight: 6,
                              ),
                            ),
                          ],
                        )),
                      ]),
                    ),
                    if (!isLast)
                      Divider(height: 1, indent: 34,
                          color: isDark
                              ? Colors.white.withOpacity(0.05)
                              : Colors.grey.shade100),
                  ]);
                }).toList(),
              ),
            ),
          ],

          if (txns.isEmpty) ...[
            const SizedBox(height: 60),
            Center(child: Column(children: [
              Icon(Icons.bar_chart, size: 64,
                  color: Colors.grey[300]),
              const SizedBox(height: 12),
              Text('No data for $period',
                  style: TextStyle(color: Colors.grey[400])),
            ])),
          ],
        ],
      ),
    );
  }

  Widget _statCard(String label, double value, Color color,
      IconData icon, Color card) =>
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(14),
          border: Border(left: BorderSide(color: color, width: 3)),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.05), blurRadius: 6)],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 6),
          Text(label,
              style: TextStyle(fontSize: 10, color: Colors.grey[500])),
          const SizedBox(height: 2),
          Text(
            '${value < 0 ? '-' : ''}${label == 'Net' && value < 0 ? '₹${(-value / 1000).toStringAsFixed(1)}K' : _fmtStatic(value)}',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color),
          ),
        ]),
      );

  static String _fmtStatic(double v) {
    final a = v.abs();
    if (a >= 100000) return '₹${(a/100000).toStringAsFixed(1)}L';
    if (a >= 1000)   return '₹${(a/1000).toStringAsFixed(1)}K';
    return '₹${a.toStringAsFixed(0)}';
  }

  Widget _sectionTitle(String t, bool isDark) => Text(
        t.toUpperCase(),
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.bold,
            color: Colors.grey[500], letterSpacing: 1.1),
      );
}

// ════════════════════════════════════════════════════════════════════════════
// Budget Tab
// ════════════════════════════════════════════════════════════════════════════
class _BudgetTab extends StatelessWidget {
  final BudgetService budgetSvc;
  final List<TransactionModel> txns;
  final Color card;
  final bool isDark;
  final String Function(double) fmt;

  const _BudgetTab({
    required this.budgetSvc,
    required this.txns,
    required this.card,
    required this.isDark,
    required this.fmt,
  });

  static const _categories = [
    'Food & Dining', 'Shopping', 'Transportation',
    'Entertainment', 'Bills & Utilities', 'Healthcare',
    'Education', 'Personal Care', 'Travel', 'Other',
  ];

  @override
  Widget build(BuildContext context) {
    final now          = DateTime.now();
    final currentMonth = DateTime(now.year, now.month);

    return StreamBuilder<QuerySnapshot>(
      stream: budgetSvc.getBudgets(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final budgets = snap.data?.docs
            .map((d) => BudgetModel.fromFirestore(d))
            .toList() ?? [];

        // Total budget summary
        double totalBudget = 0, totalSpent = 0;
        for (final b in budgets) {
          totalBudget += b.amount;
          totalSpent  += txns
              .where((t) =>
                  t.type == 'expense' &&
                  t.category == b.category &&
                  t.date.isAfter(currentMonth))
              .fold(0.0, (s, t) => s + t.amount);
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          children: [
            // Month header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(DateFormat('MMMM yyyy').format(now),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('${budgets.length} budget${budgets.length != 1 ? 's' : ''} set',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey[400])),
                ]),
                ElevatedButton.icon(
                  onPressed: () => _showAddDialog(context),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Budget'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF667eea),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Overall progress
            if (budgets.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        const Text('Total Spent',
                            style: TextStyle(
                                color: Colors.white70, fontSize: 11)),
                        Text(fmt(totalSpent),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold)),
                      ]),
                      Column(crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                        const Text('Total Budget',
                            style: TextStyle(
                                color: Colors.white70, fontSize: 11)),
                        Text(fmt(totalBudget),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold)),
                      ]),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: totalBudget > 0
                          ? (totalSpent / totalBudget).clamp(0.0, 1.0)
                          : 0,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      valueColor: AlwaysStoppedAnimation(
                        totalSpent > totalBudget
                            ? Colors.red[300]!
                            : Colors.white,
                      ),
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        totalBudget > 0
                            ? '${((totalSpent / totalBudget) * 100).toStringAsFixed(0)}% used'
                            : '0% used',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 11)),
                      Text(
                        totalSpent <= totalBudget
                            ? '${fmt(totalBudget - totalSpent)} remaining'
                            : '${fmt(totalSpent - totalBudget)} over budget',
                        style: TextStyle(
                            color: totalSpent <= totalBudget
                                ? Colors.white
                                : Colors.red[300],
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                    ],
                  ),
                ]),
              ),
              const SizedBox(height: 16),
            ],

            // Empty state
            if (budgets.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 60),
                  child: Column(children: [
                    Container(
                      width: 72, height: 72,
                      decoration: BoxDecoration(
                        color: const Color(0xFF667eea).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.pie_chart_outline,
                          color: Color(0xFF667eea), size: 34),
                    ),
                    const SizedBox(height: 14),
                    const Text('No budgets set',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 6),
                    Text('Tap "Add Budget" to get started',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[400])),
                  ]),
                ),
              ),

            // Budget cards
            ...budgets.map((b) {
              final spent = txns
                  .where((t) =>
                      t.type == 'expense' &&
                      t.category == b.category &&
                      t.date.isAfter(currentMonth))
                  .fold(0.0, (s, t) => s + t.amount);
              final pct = b.amount > 0 ? spent / b.amount : 0.0;
              final over = spent > b.amount;
              final barColor = pct > 0.9
                  ? Colors.red
                  : pct > 0.7 ? Colors.orange : const Color(0xFF667eea);

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(
                      color: Colors.black.withOpacity(0.05), blurRadius: 8)],
                ),
                child: Column(children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(b.category,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      Row(children: [
                        if (over)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('Over Budget',
                                style: TextStyle(
                                    fontSize: 9,
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold)),
                          ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => budgetSvc.deleteBudget(b.id),
                          child: Icon(Icons.delete_outline,
                              color: Colors.red[300], size: 18),
                        ),
                      ]),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Spent: ${fmt(spent)}',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[500])),
                      Text('Budget: ${fmt(b.amount)}',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[500])),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: pct.clamp(0.0, 1.0).toDouble(),
                      backgroundColor: barColor.withOpacity(0.1),
                      valueColor: AlwaysStoppedAnimation(barColor),
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${(pct * 100).toStringAsFixed(0)}% used',
                          style: TextStyle(
                              fontSize: 11,
                              color: pct > 0.9 ? Colors.red : Colors.grey[400])),
                      Text(
                        over
                            ? '${fmt(spent - b.amount)} over'
                            : '${fmt(b.amount - spent)} left',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: over ? Colors.red : const Color(0xFF2E7D32)),
                      ),
                    ],
                  ),
                ]),
              );
            }),
          ],
        );
      },
    );
  }

  void _showAddDialog(BuildContext context) {
    String selectedCat = _categories[0];
    final amtCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: const Text('Add Budget',
              style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              value: selectedCat,
              decoration: InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 12),
              ),
              items: _categories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => ss(() => selectedCat = v!),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amtCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true),
              decoration: InputDecoration(
                labelText: 'Monthly Budget (₹)',
                prefixText: '₹ ',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 12),
              ),
            ),
          ]),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF667eea),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                final amt = double.tryParse(amtCtrl.text);
                if (amt == null || amt <= 0) return;
                final uid = FirebaseAuth.instance.currentUser?.uid;
                if (uid == null) return;
                final now = DateTime.now();
                await budgetSvc.addBudget(BudgetModel(
                  id: '',
                  userId: uid,
                  category: selectedCat,
                  amount: amt,
                  month: now.month,
                  year: now.year,
                  createdAt: now,
                ));
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
}