import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/transaction_model.dart';
import '../services/transaction_service.dart';
import 'add_transaction_screen.dart';
import 'search_transactions_screen.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final _svc = TransactionService();
  String _filter = 'all'; // all / income / expense / transfer

  String _fmt(double v) {
    final a = v.abs();
    if (a >= 100000) return '₹${(a/100000).toStringAsFixed(1)}L';
    if (a >= 1000)   return '₹${(a/1000).toStringAsFixed(1)}K';
    return '₹${a.toStringAsFixed(0)}';
  }

  IconData _catIcon(String c) {
    switch (c.toLowerCase()) {
      case 'food': case 'dining': case 'restaurant': return Icons.restaurant;
      case 'shopping':   return Icons.shopping_bag;
      case 'transport': case 'travel': return Icons.directions_car;
      case 'health': case 'medical': return Icons.medical_services;
      case 'entertainment': return Icons.movie;
      case 'bills': case 'utilities': return Icons.receipt;
      case 'education':  return Icons.school;
      case 'salary': case 'income': return Icons.work;
      case 'transfer':   return Icons.swap_horiz;
      case 'groceries':  return Icons.local_grocery_store;
      default:           return Icons.attach_money;
    }
  }

  Color _catColor(String c) {
    switch (c.toLowerCase()) {
      case 'food': case 'dining': return const Color(0xFFFF7043);
      case 'shopping':   return const Color(0xFFAB47BC);
      case 'transport': case 'travel': return const Color(0xFF42A5F5);
      case 'health': case 'medical': return const Color(0xFF26A69A);
      case 'entertainment': return const Color(0xFFEF5350);
      case 'bills': case 'utilities': return const Color(0xFF78909C);
      case 'education':  return const Color(0xFF5C6BC0);
      case 'salary': case 'income': return const Color(0xFF66BB6A);
      case 'groceries':  return const Color(0xFF8D6E63);
      case 'transfer':   return const Color(0xFF42A5F5);
      default:           return const Color(0xFF667eea);
    }
  }

  Map<DateTime, List<TransactionModel>> _groupByDate(
      List<TransactionModel> txns) {
    final map = <DateTime, List<TransactionModel>>{};
    for (final t in txns) {
      final key = DateTime(t.date.year, t.date.month, t.date.day);
      map.putIfAbsent(key, () => []).add(t);
    }
    return Map.fromEntries(
        map.entries.toList()..sort((a, b) => b.key.compareTo(a.key)));
  }

  String _dateHeader(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    if (d == today)     return 'Today';
    if (d == yesterday) return 'Yesterday';
    return DateFormat('EEEE, d MMMM').format(d);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D1117) : const Color(0xFFF0F4FF),
      body: NestedScrollView(
        headerSliverBuilder: (ctx, _) => [
          SliverAppBar(
            pinned: true,
            backgroundColor: const Color(0xFF667eea),
            foregroundColor: Colors.white,
            title: const Text('Transactions',
                style: TextStyle(fontWeight: FontWeight.bold)),
            actions: [
              IconButton(
                icon: const Icon(Icons.search),
                onPressed: () => Navigator.push(ctx,
                    MaterialPageRoute(
                        builder: (_) => const SearchTransactionsScreen())),
              ),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () => Navigator.push(ctx,
                    MaterialPageRoute(
                        builder: (_) => const AddTransactionScreen())),
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(52),
              child: Container(
                color: const Color(0xFF667eea),
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    _chip('all',      'All',      isDark),
                    const SizedBox(width: 8),
                    _chip('income',   'Income',   isDark),
                    const SizedBox(width: 8),
                    _chip('expense',  'Expense',  isDark),
                    const SizedBox(width: 8),
                    _chip('transfer', 'Transfer', isDark),
                  ]),
                ),
              ),
            ),
          ),
        ],
        body: StreamBuilder<List<TransactionModel>>(
          stream: _svc.getTransactions(),
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting &&
                !snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            var txns = snap.data ?? [];
            if (_filter != 'all') {
              txns = txns.where((t) => t.type == _filter).toList();
            }

            if (txns.isEmpty) return _empty(isDark);

            // Monthly summary
            final now = DateTime.now();
            final month = txns.where((t) =>
                t.date.year == now.year && t.date.month == now.month);
            final inc = month.where((t) => t.type == 'income')
                .fold(0.0, (s, t) => s + t.amount);
            final exp = month.where((t) => t.type == 'expense')
                .fold(0.0, (s, t) => s + t.amount);

            final grouped = _groupByDate(txns);

            return RefreshIndicator(
              color: const Color(0xFF667eea),
              onRefresh: () async => setState(() {}),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                children: [
                  // Month summary
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E2530)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 6)],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _monthStat('This Month', '', Icons.calendar_today,
                            Colors.grey, isDark),
                        _monthStat('Income', _fmt(inc),
                            Icons.arrow_downward, const Color(0xFF2E7D32),
                            isDark),
                        _monthStat('Expense', _fmt(exp),
                            Icons.arrow_upward, const Color(0xFFC62828),
                            isDark),
                        _monthStat('Net', _fmt(inc - exp),
                            inc >= exp
                                ? Icons.trending_up
                                : Icons.trending_down,
                            inc >= exp
                                ? const Color(0xFF2E7D32)
                                : const Color(0xFFC62828),
                            isDark),
                      ],
                    ),
                  ),

                  // Date groups
                  ...grouped.entries.map((e) =>
                      _dateGroup(e.key, e.value, isDark)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _chip(String val, String label, bool isDark) {
    final sel = _filter == val;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _filter = val);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: sel ? Colors.white : Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: sel
                    ? const Color(0xFF667eea)
                    : Colors.white)),
      ),
    );
  }

  Widget _monthStat(String label, String value,
      IconData icon, Color color, bool isDark) {
    return Column(children: [
      Icon(icon, color: color, size: 16),
      const SizedBox(height: 3),
      if (value.isNotEmpty)
        Text(value,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13, color: color)),
      Text(label,
          style: TextStyle(fontSize: 10, color: Colors.grey[400])),
    ]);
  }

  Widget _dateGroup(DateTime date,
      List<TransactionModel> txns, bool isDark) {
    final inc = txns.where((t) => t.type == 'income')
        .fold(0.0, (s, t) => s + t.amount);
    final exp = txns.where((t) => t.type == 'expense')
        .fold(0.0, (s, t) => s + t.amount);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Date header
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_dateHeader(date),
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white70 : Colors.grey[700])),
            Row(children: [
              if (inc > 0) _badge('+${_fmt(inc)}', const Color(0xFF2E7D32)),
              if (inc > 0 && exp > 0) const SizedBox(width: 6),
              if (exp > 0) _badge('-${_fmt(exp)}', const Color(0xFFC62828)),
            ]),
          ],
        ),
      ),

      // Cards
      Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2530) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.05), blurRadius: 8,
              offset: const Offset(0, 3))],
        ),
        child: Column(
          children: txns.asMap().entries.map((e) {
            final txn = e.value;
            final isLast = e.key == txns.length - 1;
            return _txnTile(txn, isDark, isLast);
          }).toList(),
        ),
      ),
      const SizedBox(height: 14),
    ]);
  }

  Widget _badge(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(text,
            style: TextStyle(
                fontSize: 11, color: color, fontWeight: FontWeight.bold)),
      );

  Widget _txnTile(TransactionModel txn, bool isDark, bool isLast) {
    final isIncome   = txn.type == 'income';
    final isTransfer = txn.type == 'transfer';
    final amtColor = isIncome
        ? const Color(0xFF2E7D32)
        : isTransfer
            ? const Color(0xFF1565C0)
            : const Color(0xFFC62828);
    final catColor = _catColor(txn.category);

    final br = isLast
        ? const BorderRadius.only(
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16))
        : BorderRadius.zero;

    return Column(children: [
      InkWell(
        borderRadius: br,
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.push(context,
              MaterialPageRoute(
                  builder: (_) => AddTransactionScreen(transaction: txn)));
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: catColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_catIcon(txn.category), color: catColor, size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  txn.note?.isNotEmpty == true ? txn.note! : txn.category,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: catColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(txn.category,
                        style: TextStyle(
                            fontSize: 9,
                            color: catColor,
                            fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 6),
                  Text(DateFormat('h:mm a').format(txn.date),
                      style: TextStyle(
                          fontSize: 10, color: Colors.grey[400])),
                ]),
              ],
            )),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(
                '${isIncome ? '+' : isTransfer ? '↔' : '-'}${_fmt(txn.amount)}',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14, color: amtColor),
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
        Divider(height: 1, indent: 68,
            color: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.grey.shade100),
    ]);
  }

  Widget _empty(bool isDark) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFF667eea).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.receipt_long_outlined,
                  color: Color(0xFF667eea), size: 34),
            ),
            const SizedBox(height: 14),
            const Text('No transactions yet',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('Tap + to add your first transaction',
                style: TextStyle(fontSize: 12, color: Colors.grey[400])),
          ],
        ),
      );
}