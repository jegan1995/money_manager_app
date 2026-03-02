// lib/screens/smart_dashboard.dart
// Smart Dashboard — financial command center
// Pulls from: accounts, transactions, budgets, loans, net worth, goals
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/transaction_model.dart';
import '../models/account_model.dart';
import '../models/goal_model.dart';
import '../models/budget_planner_model.dart';
import '../models/net_worth_model.dart';
import '../models/loan_model.dart';
import '../services/transaction_service.dart';
import '../services/account_service.dart';
import '../services/goal_service.dart';
import '../services/budget_planner_service.dart';
import '../services/net_worth_service.dart';
import '../services/loan_service.dart';
import 'add_transaction_screen.dart';
import 'transactions_screen.dart';
import 'search_transactions_screen.dart';
import 'enhanced_reports_screen.dart';
import 'loan_screen.dart';
import 'net_worth_screen.dart';
import '../widgets/animated_fab.dart';
import '../widgets/slide_page_route.dart';

final _inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
String _f(double v)  => _inr.format(v.abs());
String _fs(double v) => '${v < 0 ? '-' : ''}${_f(v)}';

// ════════════════════════════════════════════════════════════════════════════
class SmartDashboard extends StatefulWidget {
  const SmartDashboard({super.key});
  @override
  State<SmartDashboard> createState() => _SmartDashboardState();
}

class _SmartDashboardState extends State<SmartDashboard>
    with SingleTickerProviderStateMixin {

  // Services
  final _txnSvc  = TransactionService();
  final _accSvc  = AccountService();
  final _goalSvc = GoalService();
  final _budgetSvc = BudgetPlannerService();
  final _nwSvc   = NetWorthService();
  final _loanSvc = LoanService();

  // Animation
  late AnimationController _anim;
  late Animation<double>    _fade;

  // State
  bool   _balanceVisible = true;
  String _greeting       = '';

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 700));
    _fade = Tween(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _anim, curve: Curves.easeOut));
    _anim.forward();
    _greeting = _getGreeting();
  }

  @override
  void dispose() { _anim.dispose(); super.dispose(); }

  String _getGreeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  String get _userName =>
      FirebaseAuth.instance.currentUser?.displayName?.split(' ').first
      ?? 'there';

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final bg      = isDark ? const Color(0xFF0D1117) : const Color(0xFFF0F2F8);

    return Scaffold(
      backgroundColor: bg,
      body: FadeTransition(
        opacity: _fade,
        child: RefreshIndicator(
          onRefresh: () async {
            HapticFeedback.lightImpact();
            setState(() { _greeting = _getGreeting(); });
          },
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── Header ───────────────────────────────────────────────────
              SliverToBoxAdapter(child: _Header(
                greeting: _greeting,
                userName: _userName,
                isDark:   isDark,
                onSearch: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) =>
                        const SearchTransactionsScreen())),
              )),

              // ── Total Balance ─────────────────────────────────────────────
              SliverToBoxAdapter(child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: _BalanceCard(
                  accSvc:   _accSvc,
                  txnSvc:   _txnSvc,
                  isDark:   isDark,
                  visible:  _balanceVisible,
                  onToggle: () => setState(
                      () => _balanceVisible = !_balanceVisible),
                ),
              )),

              // ── Quick actions ─────────────────────────────────────────────
              SliverToBoxAdapter(child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                child: _QuickActions(isDark: isDark, context: context),
              )),

              // ── Budget snapshot ───────────────────────────────────────────
              SliverToBoxAdapter(child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: _BudgetSnapshot(
                  svc: _budgetSvc, isDark: isDark,
                  onTap: () => _goToReports(context, 6),
                ),
              )),

              // ── Net Worth + Loans row ─────────────────────────────────────
              SliverToBoxAdapter(child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _NetWorthMini(
                      svc: _nwSvc, isDark: isDark,
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) =>
                              const NetWorthScreen())),
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: _LoanMini(
                      svc: _loanSvc, isDark: isDark,
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) =>
                              const LoanScreen())),
                    )),
                  ],
                ),
              )),

              // ── Goals ─────────────────────────────────────────────────────
              SliverToBoxAdapter(child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: _GoalsWidget(
                    svc: _goalSvc, isDark: isDark),
              )),

              // ── Recent transactions ───────────────────────────────────────
              SliverToBoxAdapter(child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Recent Transactions',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87)),
                    TextButton(
                      onPressed: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) =>
                              const TransactionsScreen())),
                      child: const Text('See All',
                          style: TextStyle(color: Color(0xFF667eea))),
                    ),
                  ],
                ),
              )),

              SliverToBoxAdapter(child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                child: _RecentTxns(
                    svc: _txnSvc, isDark: isDark),
              )),
            ],
          ),
        ),
      ),
      floatingActionButton: AnimatedFab(
        onPressed: () => Navigator.push(context,
            SlidePageRoute(page: const AddTransactionScreen())),
      ),
    );
  }

  void _goToReports(BuildContext ctx, int tabIndex) {
    Navigator.push(ctx, MaterialPageRoute(
        builder: (_) => const EnhancedReportsScreen()));
  }
}

// ════════════════════════════════════════════════════════════════════════════
// HEADER
// ════════════════════════════════════════════════════════════════════════════
class _Header extends StatelessWidget {
  final String greeting, userName;
  final bool isDark;
  final VoidCallback onSearch;

  const _Header({
    required this.greeting, required this.userName,
    required this.isDark,   required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, MediaQuery.of(context).padding.top + 16, 16, 16),
      child: Row(children: [
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$greeting, $userName! 👋',
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 2),
            Text(DateFormat('EEEE, d MMMM y').format(now),
                style: TextStyle(
                    fontSize: 12, color: Colors.grey[500])),
          ],
        )),
        IconButton(
          onPressed: onSearch,
          icon: Icon(Icons.search_rounded,
              color: isDark ? Colors.white70 : Colors.black54),
          style: IconButton.styleFrom(
            backgroundColor: isDark
                ? Colors.white.withOpacity(0.08)
                : Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// BALANCE CARD
// ════════════════════════════════════════════════════════════════════════════
class _BalanceCard extends StatelessWidget {
  final AccountService  accSvc;
  final TransactionService txnSvc;
  final bool isDark, visible;
  final VoidCallback onToggle;

  const _BalanceCard({
    required this.accSvc,   required this.txnSvc,
    required this.isDark,   required this.visible,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final now       = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);

    return StreamBuilder<List<AccountModel>>(
      stream: accSvc.getAccountsList(),
      builder: (ctx, accSnap) {
        return StreamBuilder<List<TransactionModel>>(
          stream: txnSvc.getTransactions(),
          builder: (ctx, txnSnap) {
            final accounts = accSnap.data ?? [];
            final allTxns  = txnSnap.data ?? [];
            final txns     = allTxns.where((t) =>
                t.date.isAfter(monthStart)).toList();
            final balance  = accounts.fold(
                0.0, (s, a) => s + a.balance);
            final income   = txns
                .where((t) => t.type == 'income')
                .fold(0.0, (s, t) => s + t.amount);
            final expense  = txns
                .where((t) => t.type == 'expense')
                .fold(0.0, (s, t) => s + t.amount);

            return Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [BoxShadow(
                  color: const Color(0xFF667eea).withOpacity(0.4),
                  blurRadius: 20, offset: const Offset(0, 10),
                )],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text('Total Balance',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 13)),
                    const Spacer(),
                    GestureDetector(
                      onTap: onToggle,
                      child: Icon(
                        visible
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: Colors.white70, size: 18,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 6),
                  Text(
                    visible ? _fs(balance) : '₹ ••••••',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${accounts.length} account${accounts.length == 1 ? '' : 's'}',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 11)),
                  const SizedBox(height: 20),
                  // Income / Expense this month
                  Row(children: [
                    Expanded(child: _monthStat(
                        '↑ Income', income, Colors.greenAccent)),
                    Container(width: 1, height: 36,
                        color: Colors.white.withOpacity(0.2)),
                    Expanded(child: _monthStat(
                        '↓ Expense', expense, Colors.redAccent,
                        right: true)),
                  ]),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _monthStat(String label, double val, Color col,
      {bool right = false}) =>
      Padding(
        padding: EdgeInsets.only(
            left: right ? 16 : 0, right: right ? 0 : 16),
        child: Column(
            crossAxisAlignment: right
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
          Text(label, style: TextStyle(
              color: Colors.white.withOpacity(0.65),
              fontSize: 11)),
          const SizedBox(height: 2),
          Text(visible ? _f(val) : '••••',
              style: TextStyle(
                  color: col,
                  fontWeight: FontWeight.bold,
                  fontSize: 15)),
        ]),
      );
}

// ════════════════════════════════════════════════════════════════════════════
// QUICK ACTIONS
// ════════════════════════════════════════════════════════════════════════════
class _QuickActions extends StatelessWidget {
  final bool isDark;
  final BuildContext context;
  const _QuickActions({required this.isDark, required this.context});

  @override
  Widget build(BuildContext ctx) {
    final cardBg = isDark ? const Color(0xFF1E2530) : Colors.white;
    final actions = [
      (Icons.add_circle_rounded,    'Add\nExpense',   const Color(0xFFfa709a),
          () => Navigator.push(ctx, SlidePageRoute(
              page: const AddTransactionScreen()))),
      (Icons.savings_rounded,       'Add\nIncome',    const Color(0xFF43e97b),
          () => Navigator.push(ctx, SlidePageRoute(
              page: const AddTransactionScreen()))),
      (Icons.list_alt_rounded,      'All\nTransact.', const Color(0xFF667eea),
          () => Navigator.push(ctx, MaterialPageRoute(
              builder: (_) => const TransactionsScreen()))),
      (Icons.insert_chart_rounded,  'Reports',        const Color(0xFF764ba2),
          () => Navigator.push(ctx, MaterialPageRoute(
              builder: (_) => const EnhancedReportsScreen()))),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: actions.map((a) => GestureDetector(
          onTap: a.$4,
          child: Column(children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: a.$3.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(a.$1, color: a.$3, size: 22),
            ),
            const SizedBox(height: 6),
            Text(a.$2,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.white70 : Colors.black54,
                    fontWeight: FontWeight.w600)),
          ]),
        )).toList(),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// BUDGET SNAPSHOT
// ════════════════════════════════════════════════════════════════════════════
class _BudgetSnapshot extends StatefulWidget {
  final BudgetPlannerService svc;
  final bool isDark;
  final VoidCallback onTap;
  const _BudgetSnapshot({required this.svc,
      required this.isDark, required this.onTap});
  @override
  State<_BudgetSnapshot> createState() => _BudgetSnapshotState();
}

class _BudgetSnapshotState extends State<_BudgetSnapshot> {
  List<BudgetStatus> _statuses = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final now    = DateTime.now();
    widget.svc.getPlansForMonth(now.month, now.year).first.then((plans) async {
      if (plans.isEmpty) { setState(() => _loaded = true); return; }
      final statuses = await widget.svc.getAllStatuses(plans);
      if (mounted) setState(() { _statuses = statuses; _loaded = true; });
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark  = widget.isDark;
    final cardBg  = isDark ? const Color(0xFF1E2530) : Colors.white;

    if (!_loaded) return const SizedBox.shrink();
    if (_statuses.isEmpty) return _EmptyWidget(
      emoji: '📊', title: 'No Budgets Set',
      sub: 'Tap Reports → Budget to create budgets',
      color: const Color(0xFF667eea), isDark: isDark,
      onTap: widget.onTap,
    );

    final totalBudget = _statuses.fold(0.0, (s, st) => s + st.plan.effectiveAmount);
    final totalSpent  = _statuses.fold(0.0, (s, st) => s + st.spent);
    final pct         = totalBudget > 0
        ? (totalSpent / totalBudget).clamp(0.0, 1.0) : 0.0;
    final overList    = _statuses.where((s) => s.isOver).toList();
    final nearList    = _statuses.where((s) => s.isNear).toList();

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Row(children: [
            const Text('📊', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Text('This Month\'s Budget',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 14,
                    color: isDark ? Colors.white : Colors.black87)),
            const Spacer(),
            if (overList.isNotEmpty)
              _tag('${overList.length} over', Colors.red),
            if (nearList.isNotEmpty) ...[
              const SizedBox(width: 6),
              _tag('${nearList.length} near', Colors.orange),
            ],
            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded,
                size: 18, color: Colors.grey[400]),
          ]),
          const SizedBox(height: 14),

          // Big numbers
          Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(_f(totalSpent), style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 22)),
              Text('spent of ${_f(totalBudget)}',
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey[500])),
            ]),
            const Spacer(),
            Column(crossAxisAlignment: CrossAxisAlignment.end,
                children: [
              Text('${(pct * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 22,
                      color: pct >= 1.0
                          ? Colors.red
                          : pct >= 0.8
                              ? Colors.orange
                              : Colors.green)),
              const Text('used', style: TextStyle(
                  fontSize: 11, color: Colors.grey)),
            ]),
          ]),
          const SizedBox(height: 10),

          // Overall progress
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct, minHeight: 7,
              backgroundColor: Colors.grey.withOpacity(0.12),
              valueColor: AlwaysStoppedAnimation(
                  pct >= 1.0 ? Colors.red
                  : pct >= 0.8 ? Colors.orange
                  : Colors.green),
            ),
          ),
          const SizedBox(height: 12),

          // Per-category mini bars (top 4)
          ...(_statuses.take(4).map((st) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              SizedBox(width: 90, child: Text(
                st.plan.category,
                style: const TextStyle(fontSize: 10),
                overflow: TextOverflow.ellipsis,
              )),
              Expanded(child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: st.pct.clamp(0.0, 1.0), minHeight: 5,
                  backgroundColor: Colors.grey.withOpacity(0.1),
                  valueColor: AlwaysStoppedAnimation(
                      st.statusColor),
                ),
              )),
              const SizedBox(width: 8),
              Text('${(st.pct * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                      fontSize: 9, color: st.statusColor,
                      fontWeight: FontWeight.bold)),
            ]),
          ))),
        ]),
      ),
    );
  }

  Widget _tag(String t, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
        color: c.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6)),
    child: Text(t, style: TextStyle(
        fontSize: 9, color: c, fontWeight: FontWeight.bold)),
  );
}

// ════════════════════════════════════════════════════════════════════════════
// NET WORTH MINI
// ════════════════════════════════════════════════════════════════════════════
class _NetWorthMini extends StatelessWidget {
  final NetWorthService svc;
  final bool isDark;
  final VoidCallback onTap;
  const _NetWorthMini({required this.svc,
      required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? const Color(0xFF1E2530) : Colors.white;

    return StreamBuilder<List<NetWorthItem>>(
      stream: svc.getItems(),
      builder: (_, snap) {
        final items     = snap.data ?? [];
        final assets    = items.where((i) => i.type == 'asset')
            .fold(0.0, (s, i) => s + i.value);
        final liab      = items.where((i) => i.type == 'liability')
            .fold(0.0, (s, i) => s + i.value);
        final netWorth  = assets - liab;
        final isEmpty   = items.isEmpty;

        return GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Row(children: [
                const Text('💰', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Text('Net Worth',
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87)),
                const Spacer(),
                Icon(Icons.chevron_right_rounded,
                    size: 16, color: Colors.grey[400]),
              ]),
              const SizedBox(height: 12),
              if (isEmpty)
                Text('Tap to add\nassets',
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey[500]))
              else ...[
                Text(_fs(netWorth),
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: netWorth >= 0
                            ? Colors.green : Colors.red)),
                const SizedBox(height: 4),
                Text('${_f(assets)} assets',
                    style: TextStyle(
                        fontSize: 10, color: Colors.grey[500])),
              ],
            ]),
          ),
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// LOAN MINI
// ════════════════════════════════════════════════════════════════════════════
class _LoanMini extends StatelessWidget {
  final LoanService svc;
  final bool isDark;
  final VoidCallback onTap;
  const _LoanMini({required this.svc,
      required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? const Color(0xFF1E2530) : Colors.white;

    return StreamBuilder<List<LoanModel>>(
      stream: svc.getActiveLoans(),
      builder: (_, snap) {
        final loans    = snap.data ?? [];
        final totalEmi = loans.fold(0.0, (s, l) => s + l.emi);
        final totalOut = loans.fold(
            0.0, (s, l) => s + l.outstandingBalance);
        final isEmpty  = loans.isEmpty;

        return GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Row(children: [
                const Text('🏦', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Text('Loans',
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87)),
                const Spacer(),
                Icon(Icons.chevron_right_rounded,
                    size: 16, color: Colors.grey[400]),
              ]),
              const SizedBox(height: 12),
              if (isEmpty)
                Text('No active\nloans',
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey[500]))
              else ...[
                Text(_f(totalEmi),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Color(0xFF667eea))),
                const SizedBox(height: 4),
                Text('EMI/month',
                    style: TextStyle(
                        fontSize: 10, color: Colors.grey[500])),
                const SizedBox(height: 4),
                Text('${_f(totalOut)} outstanding',
                    style: TextStyle(
                        fontSize: 10, color: Colors.grey[500])),
              ],
            ]),
          ),
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// GOALS WIDGET
// ════════════════════════════════════════════════════════════════════════════
class _GoalsWidget extends StatelessWidget {
  final GoalService svc;
  final bool isDark;
  const _GoalsWidget({required this.svc, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? const Color(0xFF1E2530) : Colors.white;

    return StreamBuilder<QuerySnapshot>(
      stream: svc.getGoals(),
      builder: (_, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final docs  = snap.data!.docs;
        if (docs.isEmpty) return const SizedBox.shrink();

        final goals = docs.map((d) =>
            GoalModel.fromFirestore(d)).toList()
          ..sort((a, b) => b.progress.compareTo(a.progress));

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Row(children: [
              const Text('🎯', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text('Financial Goals',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14,
                      color: isDark ? Colors.white : Colors.black87)),
              const Spacer(),
              Text('${docs.length} goal${docs.length == 1 ? '' : 's'}',
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey[500])),
            ]),
            const SizedBox(height: 14),
            ...goals.take(3).map((g) => _goalRow(g, isDark)),
          ]),
        );
      },
    );
  }

  Widget _goalRow(GoalModel g, bool isDark) {
    final pct   = g.progress / 100;
    final color = pct >= 1.0 ? Colors.green
        : pct >= 0.5 ? const Color(0xFF667eea)
        : Colors.orange;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(children: [
        Row(children: [
          Text(g.icon ?? '🎯',
              style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(g.name, style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13)),
              Text('${_f(g.currentAmount)} of ${_f(g.targetAmount)}',
                  style: TextStyle(
                      fontSize: 10, color: Colors.grey[500])),
            ],
          )),
          Text('${g.progress.toStringAsFixed(0)}%',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13, color: color)),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct.clamp(0.0, 1.0), minHeight: 5,
            backgroundColor: Colors.grey.withOpacity(0.12),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// RECENT TRANSACTIONS
// ════════════════════════════════════════════════════════════════════════════
class _RecentTxns extends StatelessWidget {
  final TransactionService svc;
  final bool isDark;
  const _RecentTxns({required this.svc, required this.isDark});

  static const _catIcons = <String, IconData>{
    'food':          Icons.restaurant_rounded,
    'food & dining': Icons.restaurant_rounded,
    'transport':     Icons.directions_car_rounded,
    'shopping':      Icons.shopping_bag_rounded,
    'health':        Icons.local_hospital_rounded,
    'entertainment': Icons.movie_rounded,
    'bills':         Icons.receipt_long_rounded,
    'salary':        Icons.account_balance_rounded,
    'income':        Icons.arrow_downward_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? const Color(0xFF1E2530) : Colors.white;

    return FutureBuilder<List<TransactionModel>>(
      future: svc.getTransactionsList(),
      builder: (_, snap) {
        if (!snap.hasData) return const Center(
            child: CircularProgressIndicator());
        final txns = (snap.data ?? [])
          ..sort((a, b) => b.date.compareTo(a.date));
        final recent = txns.take(5).toList();

        if (recent.isEmpty) return Center(child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text('No transactions yet',
              style: TextStyle(color: Colors.grey[500])),
        ));

        return Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: recent.length,
            separatorBuilder: (_, __) => Divider(
                height: 1,
                color: Colors.grey.withOpacity(0.1)),
            itemBuilder: (_, i) {
              final t       = recent[i];
              final isExp   = t.type == 'expense';
              final catKey  = t.category.toLowerCase();
              final icon    = _catIcons[catKey]
                  ?? (isExp
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded);
              final color   = isExp
                  ? const Color(0xFFfa709a)
                  : const Color(0xFF43e97b);

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 4),
                leading: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                title: Text(t.category,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
                subtitle: Text(
                    DateFormat('d MMM').format(t.date),
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500])),
                trailing: Text(
                  '${isExp ? '-' : '+'}${_f(t.amount)}',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14, color: color),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// ── Shared empty widget ───────────────────────────────────────────────────────
class _EmptyWidget extends StatelessWidget {
  final String emoji, title, sub;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;
  const _EmptyWidget({
    required this.emoji,  required this.title,
    required this.sub,    required this.color,
    required this.isDark, required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? const Color(0xFF1E2530) : Colors.white;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 13)),
              Text(sub, style: TextStyle(
                  fontSize: 11, color: Colors.grey[500])),
            ],
          )),
          Icon(Icons.arrow_forward_rounded,
              color: color, size: 18),
        ]),
      ),
    );
  }
}
