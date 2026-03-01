// lib/screens/transactions_screen.dart
// Added: swipe-to-delete (left swipe), tap = edit, long-press = delete confirm
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/transaction_model.dart';
import '../services/transaction_service.dart';
import 'add_transaction_screen.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});
  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final _svc         = TransactionService();
  String _filterType = 'all';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D1117) : Colors.grey[50],
      appBar: AppBar(
        title: const Text('All Transactions',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: isDark ? const Color(0xFF1E2530) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.filter_list,
                color: isDark ? Colors.white70 : Colors.grey[700]),
            onSelected: (v) => setState(() => _filterType = v),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'all',     child: Text('All')),
              PopupMenuItem(value: 'income',  child: Text('Income')),
              PopupMenuItem(value: 'expense', child: Text('Expense')),
            ],
          ),
        ],
      ),
      body: StreamBuilder<List<TransactionModel>>(
        stream: _svc.getTransactions(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.hasData || snap.data!.isEmpty) return _empty();

          var txns = snap.data!;
          if (_filterType != 'all') {
            txns = txns.where((t) => t.type == _filterType).toList();
          }
          if (txns.isEmpty) return _empty();

          final grouped = _groupByDate(txns);
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: grouped.length,
            itemBuilder: (_, i) {
              final date = grouped.keys.elementAt(i);
              return _dateGroup(date, grouped[date]!, isDark);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AddTransactionScreen())),
        backgroundColor: const Color(0xFF667eea),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _dateGroup(DateTime date, List<TransactionModel> txns, bool isDark) {
    final inc = txns.where((t) => t.type == 'income')
        .fold(0.0, (s, t) => s + t.amount);
    final exp = txns.where((t) => t.type == 'expense')
        .fold(0.0, (s, t) => s + t.amount);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(children: [
          Expanded(child: Text(_dateHeader(date),
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white70 : Colors.grey[700]))),
          if (inc > 0) _badge('+₹${inc.toStringAsFixed(0)}', Colors.green),
          if (inc > 0 && exp > 0) const SizedBox(width: 6),
          if (exp > 0) _badge('-₹${exp.toStringAsFixed(0)}', Colors.red),
        ]),
      ),
      Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2530) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: txns.length,
          separatorBuilder: (_, __) => Divider(
              height: 1, indent: 72,
              color: isDark ? Colors.white.withOpacity(0.06)
                           : Colors.grey.shade100),
          itemBuilder: (_, i) => _txnTile(txns[i], isDark),
        ),
      ),
      const SizedBox(height: 16),
    ]);
  }

  Widget _txnTile(TransactionModel txn, bool isDark) {
    final isIncome = txn.type == 'income';
    final color    = isIncome ? Colors.green : Colors.red;

    // Category icon
    final icon = _categoryIcon(txn.category, isIncome);

    return Dismissible(
      key: Key(txn.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.delete_outline, color: Colors.white, size: 24),
          const SizedBox(height: 4),
          const Text('Delete', style: TextStyle(
              color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
        ]),
      ),
      confirmDismiss: (_) async {
        HapticFeedback.mediumImpact();
        return await _confirmDelete(context, txn);
      },
      onDismissed: (_) => _delete(txn),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(txn.category,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (txn.note != null && txn.note!.isNotEmpty)
            Text(txn.note!,
                style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.grey[600],
                    fontSize: 12),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(DateFormat('h:mm a').format(txn.date),
              style: TextStyle(
                  color: isDark ? Colors.white38 : Colors.grey[400],
                  fontSize: 11)),
        ]),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          Text('${isIncome ? '+' : '-'}₹${txn.amount.toStringAsFixed(0)}',
              style: TextStyle(
                  color: color, fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right,
              color: isDark ? Colors.white24 : Colors.grey[300], size: 16),
        ]),
        onTap: () => Navigator.push(context,
            MaterialPageRoute(
                builder: (_) => AddTransactionScreen(transaction: txn))),
        onLongPress: () async {
          HapticFeedback.heavyImpact();
          final ok = await _confirmDelete(context, txn);
          if (ok == true) _delete(txn);
        },
      ),
    );
  }

  Future<bool?> _confirmDelete(BuildContext ctx, TransactionModel txn) =>
      showDialog<bool>(
        context: ctx,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: const Text('Delete Transaction'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.delete_outline, color: Colors.red[400], size: 48),
            const SizedBox(height: 12),
            Text(
              '${txn.type == 'income' ? '+' : '-'}₹${txn.amount.toStringAsFixed(0)} · ${txn.category}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(DateFormat('MMM d, yyyy').format(txn.date),
                style: TextStyle(color: Colors.grey[500], fontSize: 13)),
            const SizedBox(height: 12),
            Text('This cannot be undone.',
                style: TextStyle(color: Colors.grey[500], fontSize: 12)),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10))),
                child: const Text('Delete')),
          ],
        ),
      );

  void _delete(TransactionModel txn) {
    _svc.deleteTransaction(txn.id);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Deleted: ${txn.category}'),
      backgroundColor: Colors.red,
      behavior: SnackBarBehavior.floating,
      action: SnackBarAction(
        label: 'OK',
        textColor: Colors.white,
        onPressed: () {},
      ),
    ));
  }

  Widget _empty() => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(Icons.receipt_long, size: 80, color: Colors.grey[300]),
      const SizedBox(height: 16),
      Text('No transactions yet',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600,
              color: Colors.grey[600])),
      const SizedBox(height: 8),
      Text('Start tracking your finances',
          style: TextStyle(fontSize: 14, color: Colors.grey[500])),
    ],
  ));

  Widget _badge(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(text, style: TextStyle(
        color: color, fontSize: 11, fontWeight: FontWeight.w600)),
  );

  IconData _categoryIcon(String cat, bool isIncome) {
    if (isIncome) return Icons.arrow_downward_rounded;
    return switch (cat.toLowerCase()) {
      'food' || 'food & dining' || 'dining' => Icons.restaurant_rounded,
      'transport' || 'transportation'        => Icons.directions_car_rounded,
      'shopping'                             => Icons.shopping_bag_rounded,
      'entertainment'                        => Icons.movie_rounded,
      'health' || 'medical'                  => Icons.health_and_safety_rounded,
      'education'                            => Icons.school_rounded,
      'bills' || 'utilities'                 => Icons.receipt_rounded,
      'rent' || 'housing'                    => Icons.home_rounded,
      'groceries'                            => Icons.local_grocery_store_rounded,
      'travel'                               => Icons.flight_rounded,
      _                                      => Icons.arrow_upward_rounded,
    };
  }

  Map<DateTime, List<TransactionModel>> _groupByDate(
      List<TransactionModel> txns) {
    final grouped = <DateTime, List<TransactionModel>>{};
    for (final t in txns) {
      final d = DateTime(t.date.year, t.date.month, t.date.day);
      grouped.putIfAbsent(d, () => []).add(t);
    }
    final sorted = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    return {for (final k in sorted) k: grouped[k]!};
  }

  String _dateHeader(DateTime date) {
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (date == today) return 'Today';
    if (date == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return DateFormat('MMMM d, yyyy').format(date);
  }
}