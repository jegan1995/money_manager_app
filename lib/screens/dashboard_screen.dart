import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/transaction_model.dart';
import '../models/account_model.dart';
import '../models/goal_model.dart';
import '../services/transaction_service.dart';
import '../services/account_service.dart';
import '../services/goal_service.dart';
import '../services/bill_reminder_service.dart';
import '../models/bill_reminder_model.dart';
import 'add_transaction_screen.dart';
import 'transaction_detail_screen.dart';
import 'search_filter_screen.dart';
import 'transfers_screen.dart';
import 'add_transfer_screen.dart';
import 'goals_screen.dart';
import 'bill_reminders_screen.dart';
import 'financial_insights_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _txnService = TransactionService();
  final _accountService = AccountService();
  final _goalService = GoalService();
  final _billService = BillReminderService();

  bool _balanceHidden = false;
  bool _loading = true;

  // Data holders
  List<TransactionModel> _transactions = [];
  List<AccountModel> _accounts = [];
  List<GoalModel> _goals = [];
  List<BillReminderModel> _bills = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final txns = await _txnService.getTransactionsList();
    _goalService.getGoals().first.then((snap) {
      if (mounted) {
        setState(() {
          _goals = snap.docs
              .map((d) => GoalModel.fromFirestore(d))
              .where((g) => !g.isCompleted)
              .toList();
        });
      }
    });
    _billService.getBillReminders().first.then((bills) {
      if (mounted) setState(() => _bills = bills);
    });

    final accounts = await _accountService.getAccountsList().first;
    if (mounted) {
      setState(() {
        _transactions = txns;
        _accounts = accounts;
        _loading = false;
      });
    }
  }

  // ── Derived data ────────────────────────────────────────────────────────────
  double get _totalBalance =>
      _accounts.fold(0.0, (s, a) => s + a.balance);

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String get _userName {
    final user = FirebaseAuth.instance.currentUser;
    if (user?.displayName != null && user!.displayName!.isNotEmpty) {
      return user.displayName!.split(' ').first;
    }
    return user?.email?.split('@').first ?? 'there';
  }

  Map<String, double> _thisMonthStats() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    double income = 0, expense = 0;
    for (final t in _transactions) {
      if (t.date.isBefore(start)) continue;
      if (t.type == 'income') income += t.amount;
      if (t.type == 'expense') expense += t.amount;
    }
    return {'income': income, 'expense': expense, 'savings': income - expense};
  }

  Map<String, double> _lastMonthStats() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month - 1, 1);
    final end = DateTime(now.year, now.month, 1);
    double income = 0, expense = 0;
    for (final t in _transactions) {
      if (t.date.isBefore(start) || t.date.isAfter(end)) continue;
      if (t.type == 'income') income += t.amount;
      if (t.type == 'expense') expense += t.amount;
    }
    return {'income': income, 'expense': expense};
  }

  Map<String, double> _topCategories() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final map = <String, double>{};
    for (final t in _transactions) {
      if (t.type != 'expense') continue;
      if (t.date.isBefore(start)) continue;
      map[t.category] = (map[t.category] ?? 0) + t.amount;
    }
    final sorted = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(sorted.take(4));
  }

  double get _todayExpense {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    return _transactions
        .where((t) => t.type == 'expense' && !t.date.isBefore(start))
        .fold(0.0, (s, t) => s + t.amount);
  }

  List<BillReminderModel> get _upcomingBills => _bills
      .where((b) => b.isActive && b.nextDueDate != null && b.daysUntilDue >= 0 && b.daysUntilDue <= 7)
      .toList()
    ..sort((a, b) => a.daysUntilDue.compareTo(b.daysUntilDue));

  // ── Format helpers ──────────────────────────────────────────────────────────
  String _fmt(double v) {
    if (v.abs() >= 100000) return '₹${(v / 100000).toStringAsFixed(1)}L';
    if (v.abs() >= 1000) return '₹${(v / 1000).toStringAsFixed(1)}k';
    return '₹${v.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final stats = _thisMonthStats();
    final lastStats = _lastMonthStats();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D1117) : const Color(0xFFF5F6FA),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: CustomScrollView(
                slivers: [
                  // ── Header ──────────────────────────────────────────────────
                  SliverToBoxAdapter(child: _buildHeader(isDark, stats)),

                  // ── Body ────────────────────────────────────────────────────
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        const SizedBox(height: 16),
                        _buildMonthCards(isDark, stats, lastStats),
                        const SizedBox(height: 16),
                        _buildQuickActions(isDark),
                        const SizedBox(height: 20),
                        if (_upcomingBills.isNotEmpty) ...[
                          _buildUpcomingBills(isDark),
                          const SizedBox(height: 20),
                        ],
                        if (_goals.isNotEmpty) ...[
                          _buildGoals(isDark),
                          const SizedBox(height: 20),
                        ],
                        _buildTopCategories(isDark),
                        const SizedBox(height: 20),
                        _buildRecentTransactions(isDark),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddTransactionScreen()),
        ).then((_) => _load()),
        icon: const Icon(Icons.add),
        label: const Text('Add'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
      ),
    );
  }

  // ── Header with balance ─────────────────────────────────────────────────────
  Widget _buildHeader(bool isDark, Map<String, double> stats) {
    final savingsRate = stats['income']! > 0
        ? (stats['savings']! / stats['income']! * 100)
        : 0.0;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0D47A1), Color(0xFF1976D2), Color(0xFF42A5F5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$_greeting,',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 14)),
                      Text(_userName,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          _balanceHidden
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: Colors.white70,
                          size: 22,
                        ),
                        onPressed: () =>
                            setState(() => _balanceHidden = !_balanceHidden),
                      ),
                      IconButton(
                        icon: const Icon(Icons.search,
                            color: Colors.white70, size: 22),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const SearchFilterScreen()),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Total balance
              const Text('Total Balance',
                  style: TextStyle(color: Colors.white60, fontSize: 13)),
              const SizedBox(height: 4),
              Text(
                _balanceHidden ? '₹ ••••••' : _fmt(_totalBalance),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 38,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -1),
              ),
              const SizedBox(height: 4),
              Text(
                '${_accounts.length} account${_accounts.length != 1 ? 's' : ''} • Today: ${_fmt(_todayExpense)} spent',
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),

              const SizedBox(height: 16),

              // Savings rate pill
              if (stats['income']! > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: savingsRate >= 0
                        ? Colors.white.withOpacity(0.15)
                        : Colors.red.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        savingsRate >= 20
                            ? Icons.trending_up
                            : savingsRate >= 0
                                ? Icons.trending_flat
                                : Icons.trending_down,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Saving ${savingsRate.toStringAsFixed(0)}% this month',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Month income/expense/savings cards ──────────────────────────────────────
  Widget _buildMonthCards(bool isDark, Map<String, double> stats,
      Map<String, double> lastStats) {
    final expenseDiff = lastStats['expense']! > 0
        ? ((stats['expense']! - lastStats['expense']!) /
                lastStats['expense']! *
                100)
        : 0.0;

    return Row(
      children: [
        Expanded(
            child: _miniCard(
          isDark,
          '📈',
          'Income',
          stats['income']!,
          Colors.green,
          'This month',
        )),
        const SizedBox(width: 10),
        Expanded(
            child: _miniCard(
          isDark,
          '📉',
          'Expense',
          stats['expense']!,
          Colors.red,
          lastStats['expense']! > 0
              ? '${expenseDiff >= 0 ? '+' : ''}${expenseDiff.toStringAsFixed(0)}% vs last mo'
              : 'This month',
          valueColor:
              expenseDiff > 10 ? Colors.red : null,
        )),
        const SizedBox(width: 10),
        Expanded(
            child: _miniCard(
          isDark,
          '💰',
          'Savings',
          stats['savings']!,
          stats['savings']! >= 0 ? Colors.teal : Colors.red,
          'This month',
        )),
      ],
    );
  }

  Widget _miniCard(bool isDark, String emoji, String label, double value,
      Color color, String sub,
      {Color? valueColor}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2530) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 6),
          Text(
            _balanceHidden ? '••••' : _fmt(value),
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: valueColor ?? (isDark ? Colors.white : Colors.black87)),
          ),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          Text(sub,
              style: TextStyle(fontSize: 9, color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  // ── Quick actions ───────────────────────────────────────────────────────────
  Widget _buildQuickActions(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Quick Actions', isDark),
        const SizedBox(height: 10),
        Row(
          children: [
            _actionBtn(isDark, '💵', 'Income', Colors.green, () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AddTransactionScreen(),
                ),
              ).then((_) => _load());
            }),
            const SizedBox(width: 10),
            _actionBtn(isDark, '🛒', 'Expense', Colors.red, () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AddTransactionScreen(),
                ),
              ).then((_) => _load());
            }),
            const SizedBox(width: 10),
            _actionBtn(isDark, '🔄', 'Transfer', Colors.blue, () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddTransferScreen()),
              ).then((_) => _load());
            }),
            const SizedBox(width: 10),
            _actionBtn(isDark, '📊', 'Insights', Colors.purple, () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const FinancialInsightsScreen()),
              );
            }),
          ],
        ),
      ],
    );
  }

  Widget _actionBtn(bool isDark, String emoji, String label, Color color,
      VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(height: 4),
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: color)),
            ],
          ),
        ),
      ),
    );
  }

  // ── Upcoming bills ──────────────────────────────────────────────────────────
  Widget _buildUpcomingBills(bool isDark) {
    final bills = _upcomingBills.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _sectionTitle('📅 Upcoming Bills', isDark),
            GestureDetector(
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const BillRemindersScreen())),
              child: Text('See all',
                  style: TextStyle(
                      fontSize: 12, color: Theme.of(context).colorScheme.primary)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2530) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2))
            ],
          ),
          child: Column(
            children: bills.asMap().entries.map((e) {
              final bill = e.value;
              final days = bill.daysUntilDue;
              final isToday = days == 0;
              final isTomorrow = days == 1;
              Color urgency = days <= 1
                  ? Colors.red
                  : days <= 3
                      ? Colors.orange
                      : Colors.blue;
              String dayLabel = isToday
                  ? 'TODAY'
                  : isTomorrow
                      ? 'TOMORROW'
                      : 'In $days days';
              return Column(
                children: [
                  if (e.key > 0) const Divider(height: 1),
                  ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                          color: urgency.withOpacity(0.12),
                          shape: BoxShape.circle),
                      child:
                          Center(child: Text('🧾', style: const TextStyle(fontSize: 18))),
                    ),
                    title: Text(bill.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                    subtitle: Text(
                        '₹${bill.amount.toStringAsFixed(0)} • ${bill.category}',
                        style:
                            TextStyle(fontSize: 11, color: Colors.grey[500])),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          color: urgency.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8)),
                      child: Text(dayLabel,
                          style: TextStyle(
                              fontSize: 10,
                              color: urgency,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ── Goals ───────────────────────────────────────────────────────────────────
  Widget _buildGoals(bool isDark) {
    final goals = _goals.take(2).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _sectionTitle('🎯 Goals', isDark),
            GestureDetector(
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const GoalsScreen())),
              child: Text('See all',
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.primary)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...goals.map((g) => _goalCard(g, isDark)),
      ],
    );
  }

  Widget _goalCard(GoalModel g, bool isDark) {
    final pct = g.progress;
    final color = pct >= 75
        ? Colors.green
        : pct >= 40
            ? Colors.orange
            : Colors.blue;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2530) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(g.icon ?? '🎯', style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(g.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                    Text(
                        '${_fmt(g.currentAmount)} of ${_fmt(g.targetAmount)}',
                        style:
                            TextStyle(fontSize: 11, color: Colors.grey[500])),
                  ],
                ),
              ),
              Text('${pct.toStringAsFixed(0)}%',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: color,
                      fontSize: 15)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct / 100,
              backgroundColor: Colors.grey.withOpacity(0.15),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 7,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${g.daysRemaining} days left',
                  style: TextStyle(fontSize: 10, color: Colors.grey[500])),
              Text(_fmt(g.targetAmount - g.currentAmount) + ' remaining',
                  style: TextStyle(fontSize: 10, color: Colors.grey[500])),
            ],
          ),
        ],
      ),
    );
  }

  // ── Top categories ──────────────────────────────────────────────────────────
  Widget _buildTopCategories(bool isDark) {
    final cats = _topCategories();
    if (cats.isEmpty) return const SizedBox();

    final maxVal = cats.values.reduce((a, b) => a > b ? a : b);
    final colors = [
      Colors.red,
      Colors.orange,
      Colors.purple,
      Colors.blue,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('🗂️ Top Spending This Month', isDark),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2530) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2))
            ],
          ),
          child: Column(
            children: cats.entries.toList().asMap().entries.map((e) {
              final idx = e.key;
              final cat = e.value.key;
              final amt = e.value.value;
              final frac = maxVal > 0 ? amt / maxVal : 0.0;
              final color = colors[idx % colors.length];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(_categoryIcon(cat), size: 14, color: color),
                            const SizedBox(width: 6),
                            Text(cat,
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black87)),
                          ],
                        ),
                        Text(_fmt(amt),
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: color)),
                      ],
                    ),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: frac,
                        backgroundColor: color.withOpacity(0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ── Recent transactions ─────────────────────────────────────────────────────
  Widget _buildRecentTransactions(bool isDark) {
    final recent = _transactions.take(8).toList();
    if (recent.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('🕒 Recent Transactions', isDark),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2530) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2))
            ],
          ),
          child: Column(
            children: recent.asMap().entries.map((e) {
              final t = e.value;
              final isIncome = t.type == 'income';
              final isTransfer = t.type == 'transfer';
              final color = isTransfer
                  ? Colors.blue
                  : isIncome
                      ? Colors.green
                      : Colors.red;
              final prefix = isTransfer ? '' : isIncome ? '+' : '-';

              return Column(
                children: [
                  if (e.key > 0)
                    Divider(
                        height: 1,
                        color: Colors.grey.withOpacity(0.12)),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 2),
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          shape: BoxShape.circle),
                      child: Icon(_categoryIcon(t.category),
                          color: color, size: 18),
                    ),
                    title: Text(t.category,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                    subtitle: Text(
                      DateFormat('MMM d').format(t.date),
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey[500]),
                    ),
                    trailing: Text(
                      '$prefix${_fmt(t.amount)}',
                      style: TextStyle(
                          color: color,
                          fontSize: 14,
                          fontWeight: FontWeight.bold),
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              TransactionDetailScreen(transaction: t)),
                    ).then((_) => _load()),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────
  Widget _sectionTitle(String t, bool isDark) => Text(
        t,
        style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87),
      );

  IconData _categoryIcon(String cat) {
    switch (cat) {
      case 'Food & Dining': return Icons.restaurant;
      case 'Transportation': return Icons.directions_car;
      case 'Shopping': return Icons.shopping_bag;
      case 'Entertainment': return Icons.movie;
      case 'Bills & Utilities': return Icons.receipt;
      case 'Healthcare': return Icons.local_hospital;
      case 'Education': return Icons.school;
      case 'Personal Care': return Icons.spa;
      case 'Travel': return Icons.flight;
      case 'Salary': return Icons.account_balance_wallet;
      case 'Business': return Icons.business;
      case 'Investments': return Icons.trending_up;
      case 'Gifts': return Icons.card_giftcard;
      case 'Transfer': return Icons.swap_horiz;
      case 'Groceries': return Icons.local_grocery_store;
      case 'Rent': return Icons.home;
      case 'Insurance': return Icons.security;
      case 'Subscriptions': return Icons.subscriptions;
      default: return Icons.category;
    }
  }
}