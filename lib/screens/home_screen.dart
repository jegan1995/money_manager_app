import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/transaction_model.dart';
import '../models/account_model.dart';
import '../services/transaction_service.dart';
import '../services/account_service.dart';
import 'add_transaction_screen.dart';
import 'transactions_screen.dart';
import 'accounts_screen.dart';
import 'category_analytics_screen.dart';
import 'search_transactions_screen.dart';
import 'statistics_screen.dart';
import 'budget_screen.dart';
import '../widgets/animated_fab.dart';
import '../widgets/slide_page_route.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final _txnSvc  = TransactionService();
  final _accSvc  = AccountService();
  final _user    = FirebaseAuth.instance.currentUser;
  late AnimationController _ctrl;
  late Animation<double>   _fade;
  bool _balanceVisible = true;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        duration: const Duration(milliseconds: 600), vsync: this);
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  String get _firstName {
    final name = _user?.displayName ?? _user?.email ?? 'there';
    return name.split(' ').first.split('@').first;
  }

  String _fmt(double v) {
    if (!_balanceVisible) return '₹ ••••••';
    final abs = v.abs();
    if (abs >= 10000000) return '₹${(abs / 10000000).toStringAsFixed(2)}Cr';
    if (abs >= 100000)   return '₹${(abs / 100000).toStringAsFixed(2)}L';
    return '₹${NumberFormat('#,##,##0.00').format(abs)}';
  }

  String _fmtShort(double v) {
    final abs = v.abs();
    if (abs >= 10000000) return '₹${(abs / 10000000).toStringAsFixed(1)}Cr';
    if (abs >= 100000)   return '₹${(abs / 100000).toStringAsFixed(1)}L';
    if (abs >= 1000)     return '₹${(abs / 1000).toStringAsFixed(1)}K';
    return '₹${abs.toStringAsFixed(0)}';
  }

  // ── Category icon ──────────────────────────────────────────────────────────
  IconData _catIcon(String category) {
    switch (category.toLowerCase()) {
      case 'food':
      case 'dining':
      case 'restaurant': return Icons.restaurant;
      case 'shopping':   return Icons.shopping_bag;
      case 'transport':
      case 'travel':     return Icons.directions_car;
      case 'health':
      case 'medical':    return Icons.medical_services;
      case 'entertainment': return Icons.movie;
      case 'bills':
      case 'utilities':  return Icons.receipt;
      case 'education':  return Icons.school;
      case 'salary':
      case 'income':     return Icons.work;
      case 'transfer':   return Icons.swap_horiz;
      case 'investment': return Icons.trending_up;
      case 'groceries':  return Icons.local_grocery_store;
      default:           return Icons.attach_money;
    }
  }

  Color _catColor(String category) {
    switch (category.toLowerCase()) {
      case 'food':
      case 'dining':
      case 'restaurant': return const Color(0xFFFF7043);
      case 'shopping':   return const Color(0xFFAB47BC);
      case 'transport':
      case 'travel':     return const Color(0xFF42A5F5);
      case 'health':
      case 'medical':    return const Color(0xFF26A69A);
      case 'entertainment': return const Color(0xFFFF7043);
      case 'bills':
      case 'utilities':  return const Color(0xFF78909C);
      case 'education':  return const Color(0xFF5C6BC0);
      case 'salary':
      case 'income':     return const Color(0xFF66BB6A);
      case 'groceries':  return const Color(0xFF8D6E63);
      default:           return const Color(0xFF667eea);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0D1117) : const Color(0xFFF0F4FF);

    return Scaffold(
      backgroundColor: bg,
      body: FadeTransition(
        opacity: _fade,
        child: RefreshIndicator(
          color: const Color(0xFF667eea),
          onRefresh: () async => setState(() {}),
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _header(isDark),
              _balanceCard(isDark),
              _accountsRow(isDark),
              _quickActions(isDark),
              _spendingOverview(isDark),
              _recentTransactions(isDark),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
      floatingActionButton: AnimatedFab(
        onPressed: () => Navigator.push(
            context, SlidePageRoute(page: const AddTransactionScreen())),
      ),
    );
  }

  // ── 1. Header ──────────────────────────────────────────────────────────────
  Widget _header(bool isDark) {
    return SliverToBoxAdapter(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF667eea), Color(0xFF764ba2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 12,
          left: 20, right: 16, bottom: 24,
        ),
        child: Row(children: [
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_greeting,
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14)),
              const SizedBox(height: 2),
              Text(
                _firstName,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat('EEEE, d MMMM yyyy').format(DateTime.now()),
                style: TextStyle(
                    color: Colors.white.withOpacity(0.7), fontSize: 12),
              ),
            ],
          )),
          // Search
          IconButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => const SearchTransactionsScreen())),
            icon: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.search, color: Colors.white, size: 20),
            ),
          ),
          // Avatar
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
            ),
            child: Center(
              child: Text(
                _firstName.isNotEmpty ? _firstName[0].toUpperCase() : 'U',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  // ── 2. Balance Card ────────────────────────────────────────────────────────
  Widget _balanceCard(bool isDark) {
    return SliverToBoxAdapter(
      child: StreamBuilder<List<AccountModel>>(
        stream: _accSvc.getAccounts(),
        builder: (ctx, accSnap) {
          return StreamBuilder<List<TransactionModel>>(
            stream: _txnSvc.getTransactions(),
            builder: (ctx, txnSnap) {
              final accounts = accSnap.data ?? [];
              final transactions = txnSnap.data ?? [];
              final totalBalance = accounts.fold(0.0, (s, a) => s + a.balance);

              final now = DateTime.now();
              final monthTxns = transactions.where((t) =>
                  t.date.year == now.year && t.date.month == now.month);
              final income  = monthTxns.where((t) => t.type == 'income')
                  .fold(0.0, (s, t) => s + t.amount);
              final expense = monthTxns.where((t) => t.type == 'expense')
                  .fold(0.0, (s, t) => s + t.amount);
              final savings = income - expense;
              final savingsRate = income > 0 ? (savings / income).clamp(0.0, 1.0) : 0.0;

              return Transform.translate(
                offset: const Offset(0, -1),
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                          color: const Color(0xFF667eea).withOpacity(0.45),
                          blurRadius: 24,
                          offset: const Offset(0, 12)),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Total balance row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Total Balance',
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500)),
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                setState(() =>
                                    _balanceVisible = !_balanceVisible);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(children: [
                                  Icon(
                                    _balanceVisible
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    color: Colors.white, size: 14),
                                  const SizedBox(width: 4),
                                  Text(
                                    DateFormat('MMM yyyy').format(now),
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold)),
                                ]),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Big balance number
                        Text(
                          _fmt(totalBalance),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 34,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 4),

                        // Savings rate bar
                        if (income > 0) ...[
                          Row(children: [
                            Text('Savings rate ',
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 11)),
                            Text(
                              '${(savingsRate * 100).toStringAsFixed(0)}%',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold)),
                          ]),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: savingsRate,
                              minHeight: 4,
                              backgroundColor: Colors.white.withOpacity(0.2),
                              valueColor: const AlwaysStoppedAnimation(
                                  Colors.greenAccent),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ] else
                          const SizedBox(height: 20),

                        // Income / Expense / Savings
                        Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(children: [
                            Expanded(child: _balanceStat(
                                'Income', income,
                                Icons.arrow_downward_rounded,
                                Colors.greenAccent)),
                            Container(width: 1, height: 36,
                                color: Colors.white.withOpacity(0.2)),
                            Expanded(child: _balanceStat(
                                'Expense', expense,
                                Icons.arrow_upward_rounded,
                                Colors.redAccent)),
                            Container(width: 1, height: 36,
                                color: Colors.white.withOpacity(0.2)),
                            Expanded(child: _balanceStat(
                                'Savings', savings,
                                Icons.savings_outlined,
                                savings >= 0
                                    ? Colors.cyanAccent
                                    : Colors.orangeAccent)),
                          ]),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _balanceStat(String label, double amount,
      IconData icon, Color color) {
    return Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: color, size: 13),
        const SizedBox(width: 3),
        Text(label,
            style: TextStyle(
                color: Colors.white.withOpacity(0.75), fontSize: 11)),
      ]),
      const SizedBox(height: 4),
      Text(
        _balanceVisible ? _fmtShort(amount) : '••••',
        style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold),
      ),
    ]);
  }

  // ── 3. Accounts horizontal scroll ─────────────────────────────────────────
  Widget _accountsRow(bool isDark) {
    return SliverToBoxAdapter(
      child: StreamBuilder<List<AccountModel>>(
        stream: _accSvc.getAccounts(),
        builder: (ctx, snap) {
          final accounts = snap.data ?? [];
          if (accounts.isEmpty) return const SizedBox(height: 16);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('My Accounts',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.grey[800])),
                    GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => const AccountsScreen())),
                      child: const Text('See All',
                          style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF667eea),
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 90,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: accounts.length,
                  itemBuilder: (ctx, i) {
                    final acc = accounts[i];
                    return _accountChip(acc, isDark);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _accountChip(AccountModel acc, bool isDark) {
    final colors = [
      [const Color(0xFF667eea), const Color(0xFF764ba2)],
      [const Color(0xFF11998e), const Color(0xFF38ef7d)],
      [const Color(0xFFf093fb), const Color(0xFFf5576c)],
      [const Color(0xFF4facfe), const Color(0xFF00f2fe)],
      [const Color(0xFFf77062), const Color(0xFFfe5196)],
    ];
    final idx = acc.name.hashCode.abs() % colors.length;
    final grad = colors[idx];

    final icon = acc.type == 'bank'
        ? Icons.account_balance
        : acc.type == 'cash'
            ? Icons.money
            : acc.type == 'card'
                ? Icons.credit_card
                : Icons.account_balance_wallet;

    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const AccountsScreen())),
      child: Container(
        width: 150,
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: grad,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: grad[0].withOpacity(0.35),
                blurRadius: 10,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: Colors.white70, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(acc.name,
                    style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
            ]),
            const Spacer(),
            Text(
              _balanceVisible
                  ? _fmtShort(acc.balance)
                  : '••••',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  // ── 4. Quick Actions ───────────────────────────────────────────────────────
  Widget _quickActions(bool isDark) {
    final actions = [
      _QA('Add', Icons.add_circle_outline, const Color(0xFF667eea),
          () => Navigator.push(context,
              SlidePageRoute(page: const AddTransactionScreen()))),
      _QA('Accounts', Icons.account_balance_wallet_outlined,
          const Color(0xFF11998e),
          () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const AccountsScreen()))),
      _QA('Analytics', Icons.pie_chart_outline, const Color(0xFFf093fb),
          () => Navigator.push(context,
              MaterialPageRoute(
                  builder: (_) => const CategoryAnalyticsScreen()))),
      _QA('Reports', Icons.bar_chart, const Color(0xFF4facfe),
          () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const StatisticsScreen()))),
      _QA('Budget', Icons.savings_outlined, const Color(0xFFf77062),
          () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const BudgetScreen()))),
      _QA('History', Icons.history, const Color(0xFF764ba2),
          () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => TransactionsScreen()))),
    ];

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Quick Actions',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.grey[800])),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: actions.map((a) => _qaButton(a, isDark)).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _qaButton(_QA a, bool isDark) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        a.onTap();
      },
      child: Column(children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color: a.color.withOpacity(isDark ? 0.15 : 0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: a.color.withOpacity(0.25), width: 1),
          ),
          child: Icon(a.icon, color: a.color, size: 22),
        ),
        const SizedBox(height: 6),
        Text(a.label,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey[300] : Colors.grey[700])),
      ]),
    );
  }

  // ── 5. Spending Overview ───────────────────────────────────────────────────
  Widget _spendingOverview(bool isDark) {
    return SliverToBoxAdapter(
      child: StreamBuilder<List<TransactionModel>>(
        stream: _txnSvc.getTransactions(),
        builder: (ctx, snap) {
          final transactions = snap.data ?? [];
          final now = DateTime.now();
          final monthTxns = transactions.where((t) =>
              t.date.year == now.year && t.date.month == now.month).toList();

          // Category breakdown
          final catMap = <String, double>{};
          for (final t in monthTxns.where((t) => t.type == 'expense')) {
            catMap[t.category] = (catMap[t.category] ?? 0) + t.amount;
          }
          final sorted = catMap.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          final top4 = sorted.take(4).toList();
          final totalExp = catMap.values.fold(0.0, (s, v) => s + v);

          if (top4.isEmpty) return const SizedBox.shrink();

          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('This Month',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.grey[800])),
                    GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => const CategoryAnalyticsScreen())),
                      child: const Text('Details',
                          style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF667eea),
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E2530) : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4))],
                  ),
                  child: Column(
                    children: top4.map((e) {
                      final pct = totalExp > 0
                          ? (e.value / totalExp).clamp(0.0, 1.0)
                          : 0.0;
                      final color = _catColor(e.key);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(children: [
                          Row(children: [
                            Container(
                              width: 32, height: 32,
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(_catIcon(e.key),
                                  color: color, size: 16),
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: Text(e.key,
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500))),
                            Text(
                              _fmtShort(e.value),
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? Colors.white
                                      : Colors.grey[800]),
                            ),
                            const SizedBox(width: 6),
                            SizedBox(
                              width: 36,
                              child: Text(
                                '${(pct * 100).toStringAsFixed(0)}%',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[400]),
                              ),
                            ),
                          ]),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: pct,
                              minHeight: 5,
                              backgroundColor: isDark
                                  ? Colors.white10
                                  : Colors.grey.shade100,
                              valueColor:
                                  AlwaysStoppedAnimation(color),
                            ),
                          ),
                        ]),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── 6. Recent Transactions ────────────────────────────────────────────────
  Widget _recentTransactions(bool isDark) {
    return SliverToBoxAdapter(
      child: StreamBuilder<List<TransactionModel>>(
        stream: _txnSvc.getTransactions(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
            return const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final all = snap.data ?? [];
          final recent = all.take(8).toList();

          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Recent Transactions',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.grey[800])),
                    GestureDetector(
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(
                              builder: (_) => TransactionsScreen())),
                      child: const Text('View All',
                          style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF667eea),
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (recent.isEmpty)
                  _emptyState(isDark)
                else
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E2530) : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4))],
                    ),
                    child: Column(
                      children: recent.asMap().entries.map((e) {
                        final txn = e.value;
                        final isLast = e.key == recent.length - 1;
                        return _txnTile(txn, isDark, isLast);
                      }).toList(),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _txnTile(TransactionModel txn, bool isDark, bool isLast) {
    final isIncome  = txn.type == 'income';
    final isTransfer = txn.type == 'transfer';
    final color = isIncome
        ? const Color(0xFF2E7D32)
        : isTransfer
            ? const Color(0xFF1565C0)
            : const Color(0xFFC62828);
    final catColor = _catColor(txn.category);

    return Column(children: [
      InkWell(
        borderRadius: isLast
            ? const BorderRadius.only(
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(18))
            : BorderRadius.zero,
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: catColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_catIcon(txn.category),
                  color: catColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  txn.note?.isNotEmpty == true ? txn.note! : txn.category,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: catColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(txn.category,
                        style: TextStyle(
                            fontSize: 10,
                            color: catColor,
                            fontWeight: FontWeight.w500)),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    DateFormat('dd MMM, h:mm a').format(txn.date),
                    style: TextStyle(
                        fontSize: 10, color: Colors.grey[400]),
                  ),
                ]),
              ],
            )),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(
                '${isIncome ? '+' : isTransfer ? '↔' : '-'}${_fmtShort(txn.amount)}',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: color),
              ),
              if (txn.paymentMethod != null && txn.paymentMethod!.isNotEmpty)
                Text(txn.paymentMethod!,
                    style: TextStyle(
                        fontSize: 9, color: Colors.grey[400])),
            ]),
          ]),
        ),
      ),
      if (!isLast)
        Divider(height: 1, indent: 72,
            color: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.grey.shade100),
    ]);
  }

  Widget _emptyState(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2530) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4))],
      ),
      child: Column(children: [
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
            color: const Color(0xFF667eea).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.receipt_long_outlined,
              color: Color(0xFF667eea), size: 30),
        ),
        const SizedBox(height: 14),
        Text('No transactions yet',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.grey[700])),
        const SizedBox(height: 6),
        Text('Tap + to add your first transaction',
            style: TextStyle(fontSize: 12, color: Colors.grey[400])),
      ]),
    );
  }
}

class _QA {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _QA(this.label, this.icon, this.color, this.onTap);
}