import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/account_model.dart';
import '../services/account_service.dart';
import 'add_account_screen.dart';
import 'account_detail_screen.dart';

class AccountsScreen extends StatelessWidget {
  const AccountsScreen({super.key});

  String _fmt(double v) {
    final abs = v.abs();
    if (abs >= 10000000) return '₹${(abs/10000000).toStringAsFixed(2)}Cr';
    if (abs >= 100000)   return '₹${(abs/100000).toStringAsFixed(2)}L';
    return '₹${NumberFormat('#,##,##0').format(abs)}';
  }

  IconData _icon(String type) {
    switch (type) {
      case 'bank':        return Icons.account_balance;
      case 'cash':        return Icons.money;
      case 'card':
      case 'credit_card': return Icons.credit_card;
      case 'wallet':      return Icons.account_balance_wallet;
      case 'loan':        return Icons.receipt_long;
      default:            return Icons.account_balance_wallet;
    }
  }

  String _typeName(String type) {
    switch (type) {
      case 'bank':        return 'Bank Account';
      case 'cash':        return 'Cash';
      case 'card':        return 'Debit Card';
      case 'credit_card': return 'Credit Card';
      case 'wallet':      return 'Digital Wallet';
      case 'loan':        return 'Loan';
      default:            return type;
    }
  }

  List<Color> _gradient(String name) {
    final sets = [
      [const Color(0xFF667eea), const Color(0xFF764ba2)],
      [const Color(0xFF11998e), const Color(0xFF38ef7d)],
      [const Color(0xFF4facfe), const Color(0xFF00f2fe)],
      [const Color(0xFFf093fb), const Color(0xFFf5576c)],
      [const Color(0xFFf77062), const Color(0xFFfe5196)],
      [const Color(0xFF43e97b), const Color(0xFF38f9d7)],
    ];
    return sets[name.hashCode.abs() % sets.length];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final svc = AccountService();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D1117) : const Color(0xFFF0F4FF),
      body: StreamBuilder<List<AccountModel>>(
        stream: svc.getAccounts(),
        builder: (ctx, snap) {
          final accounts = snap.data ?? [];
          final loading = snap.connectionState == ConnectionState.waiting && accounts.isEmpty;

          double assets = 0, debt = 0;
          for (final a in accounts) {
            if (a.type == 'credit_card' || a.type == 'loan') {
              debt += a.balance.abs();
            } else {
              if (a.balance >= 0) assets += a.balance;
              else debt += a.balance.abs();
            }
          }
          final net = assets - debt;

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── Header ─────────────────────────────────────────────
              SliverAppBar(
                expandedHeight: 180,
                pinned: true,
                backgroundColor: const Color(0xFF667eea),
                foregroundColor: Colors.white,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 56, 20, 16),
                        child: Row(children: [
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text('My Accounts',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text('${accounts.length} account${accounts.length != 1 ? 's' : ''}',
                                  style: TextStyle(
                                      color: Colors.white.withOpacity(0.75),
                                      fontSize: 13)),
                            ],
                          )),
                          // Net worth chip
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('Net Worth',
                                    style: TextStyle(
                                        color: Colors.white.withOpacity(0.8),
                                        fontSize: 10)),
                                const SizedBox(height: 2),
                                Text(_fmt(net),
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ]),
                      ),
                    ),
                  ),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () => Navigator.push(ctx,
                        MaterialPageRoute(
                            builder: (_) => const AddAccountScreen())),
                  ),
                ],
              ),

              if (loading)
                const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator())),

              // ── Summary strip ───────────────────────────────────────
              if (!loading && accounts.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Row(children: [
                      Expanded(child: _summaryCard(
                          'Total Assets', assets,
                          const Color(0xFF2E7D32), Icons.trending_up, isDark)),
                      const SizedBox(width: 12),
                      Expanded(child: _summaryCard(
                          'Total Debt', debt,
                          const Color(0xFFC62828), Icons.trending_down, isDark)),
                    ]),
                  ),
                ),

              // ── Accounts list ───────────────────────────────────────
              if (!loading && accounts.isEmpty)
                SliverFillRemaining(child: _empty(isDark)),

              if (!loading && accounts.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => _accountCard(accounts[i], isDark, ctx),
                      childCount: accounts.length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AddAccountScreen())),
        icon: const Icon(Icons.add),
        label: const Text('Add Account'),
        backgroundColor: const Color(0xFF667eea),
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _summaryCard(String label, double amount,
      Color color, IconData icon, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2530) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: color, width: 4)),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.05), blurRadius: 8)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(fontSize: 11, color: Colors.grey[500])),
        ]),
        const SizedBox(height: 6),
        Text(_fmt(amount),
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: color)),
      ]),
    );
  }

  Widget _accountCard(AccountModel acc, bool isDark, BuildContext ctx) {
    final grad = _gradient(acc.name);
    final isDebt = acc.type == 'credit_card' || acc.type == 'loan';
    final amtColor = acc.balance < 0 || isDebt
        ? const Color(0xFFC62828)
        : const Color(0xFF2E7D32);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(ctx,
            MaterialPageRoute(
                builder: (_) => AccountDetailScreen(account: acc)));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2530) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.06), blurRadius: 10,
              offset: const Offset(0, 4))],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            // Gradient icon
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: grad,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(_icon(acc.type), color: Colors.white, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(acc.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 2),
                Text(_typeName(acc.type),
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey[400])),
              ],
            )),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(
                '${acc.balance < 0 ? '-' : ''}${_fmt(acc.balance)}',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: amtColor),
              ),
              const SizedBox(height: 4),
              if (acc.balance < 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('Overdrawn',
                      style: TextStyle(
                          fontSize: 9,
                          color: Colors.red,
                          fontWeight: FontWeight.bold)),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E7D32).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(_typeName(acc.type),
                      style: TextStyle(
                          fontSize: 9,
                          color: Colors.grey[500])),
                ),
              const SizedBox(height: 2),
              Icon(Icons.chevron_right,
                  size: 16, color: Colors.grey[300]),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _empty(bool isDark) => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFF667eea).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.account_balance_wallet_outlined,
                color: Color(0xFF667eea), size: 36),
          ),
          const SizedBox(height: 16),
          const Text('No accounts yet',
              style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text('Add your bank, cash or card accounts',
              style: TextStyle(fontSize: 13, color: Colors.grey[400])),
        ]),
      );
}