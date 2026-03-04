// lib/screens/transactions_screen.dart
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
  final _txnSvc    = TransactionService();
  String _filter   = 'all';

  // ── Copy transaction ────────────────────────────────────────────────────────
  Future<void> _copyTransaction(TransactionModel txn) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.copy_all_rounded, color: Color(0xFF667eea), size: 20),
          SizedBox(width: 8),
          Text('Copy Transaction'),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Create a copy of this transaction?',
                style: TextStyle(fontSize: 13)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF667eea).withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(txn.category,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13)),
                  Text('₹${txn.amount.toStringAsFixed(0)} · ${txn.type}',
                      style: const TextStyle(
                          fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'It will open in edit mode so you can adjust date/amount.',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF667eea),
                foregroundColor: Colors.white,
              ),
              child: const Text('Copy')),
        ],
      ),
    );
    if (confirmed != true) return;

    // Build a copy with empty id + today's date
    final copy = TransactionModel(
      id:                 '',
      userId:             '',
      type:               txn.type,
      amount:             txn.amount,
      category:           txn.category,
      subcategory:        txn.subcategory,
      paymentMethod:      txn.paymentMethod,
      date:               DateTime.now(),
      note:               txn.note != null ? '${txn.note} (copy)' : null,
      description:        txn.description,
      fromAccount:        txn.fromAccount,
      toAccount:          txn.toAccount,
      isRecurring:        false,
      recurringFrequency: null,
      createdAt:          DateTime.now(),
    );

    // Open AddTransactionScreen in "copy mode" — no existing id
    // so saving creates a new transaction
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => AddTransactionScreen(transaction: copy, isCopy: true),
    ));
  }

  // ── Delete transaction ──────────────────────────────────────────────────────
  Future<void> _deleteTransaction(TransactionModel txn) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Transaction'),
        content: Text(
          'Delete ₹${txn.amount.toStringAsFixed(0)} ${txn.type} '
          '(${txn.category})?\nThis cannot be undone.',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true) {
      await _txnSvc.deleteTransaction(txn.id);
      HapticFeedback.mediumImpact();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Transaction deleted'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

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
            icon: Icon(Icons.filter_list, color: Colors.grey[600]),
            onSelected: (v) => setState(() => _filter = v),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'all',      child: Text('All')),
              PopupMenuItem(value: 'income',   child: Text('Income')),
              PopupMenuItem(value: 'expense',  child: Text('Expense')),
              PopupMenuItem(value: 'transfer', child: Text('Transfer')),
            ],
          ),
        ],
      ),
      body: StreamBuilder<List<TransactionModel>>(
        stream: _txnSvc.getTransactions(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFF667eea)));
          }
          if (!snap.hasData || snap.data!.isEmpty) return _emptyState();

          var txns = snap.data!;
          if (_filter != 'all') {
            txns = txns.where((t) => t.type == _filter).toList();
          }
          if (txns.isEmpty) return _emptyState();

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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => const AddTransactionScreen())),
        backgroundColor: const Color(0xFF667eea),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  // ── Date group ──────────────────────────────────────────────────────────────
  Widget _dateGroup(
      DateTime date, List<TransactionModel> txns, bool isDark) {
    final inc = txns.where((t) => t.type == 'income')
        .fold(0.0, (s, t) => s + t.amount);
    final exp = txns.where((t) => t.type == 'expense')
        .fold(0.0, (s, t) => s + t.amount);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(children: [
          Text(_dateLabel(date),
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white70 : Colors.grey[800])),
          const Spacer(),
          if (inc > 0)
            _pill('+₹${inc.toStringAsFixed(0)}', Colors.green),
          if (inc > 0 && exp > 0) const SizedBox(width: 6),
          if (exp > 0)
            _pill('-₹${exp.toStringAsFixed(0)}', Colors.red),
        ]),
      ),
      Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2530) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: txns.length,
          separatorBuilder: (_, __) => Divider(
              height: 1, indent: 72,
              color: isDark ? Colors.white12 : Colors.grey[200]),
          itemBuilder: (_, i) => _txnTile(txns[i], isDark),
        ),
      ),
      const SizedBox(height: 16),
    ]);
  }

  // ── Transaction tile with popup menu ───────────────────────────────────────
  Widget _txnTile(TransactionModel txn, bool isDark) {
    final isInc = txn.type == 'income';
    final isTrf = txn.type == 'transfer';
    final color = isInc ? Colors.green : isTrf ? Colors.blue : Colors.red;
    final icon  = isInc ? Icons.arrow_downward_rounded
                : isTrf ? Icons.swap_horiz_rounded
                        : Icons.arrow_upward_rounded;

    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(txn.category,
          style: const TextStyle(
              fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (txn.note != null)
            Text(txn.note!,
                style: TextStyle(
                    color: Colors.grey[500], fontSize: 11),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(DateFormat('h:mm a').format(txn.date),
              style: TextStyle(
                  color: Colors.grey[400], fontSize: 11)),
        ],
      ),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(
          '${isInc ? '+' : isTrf ? '⇄' : '-'}₹${txn.amount.toStringAsFixed(0)}',
          style: TextStyle(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 4),
        // ── 3-dot menu ─────────────────────────────────────────────
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert_rounded,
              size: 18, color: Colors.grey[400]),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          onSelected: (v) {
            if (v == 'edit') {
              Navigator.push(context, MaterialPageRoute(
                  builder: (_) =>
                      AddTransactionScreen(transaction: txn)));
            } else if (v == 'copy') {
              _copyTransaction(txn);
            } else if (v == 'delete') {
              _deleteTransaction(txn);
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(children: [
                Icon(Icons.edit_rounded, size: 16, color: Color(0xFF667eea)),
                SizedBox(width: 10),
                Text('Edit'),
              ]),
            ),
            const PopupMenuItem(
              value: 'copy',
              child: Row(children: [
                Icon(Icons.copy_all_rounded, size: 16, color: Colors.orange),
                SizedBox(width: 10),
                Text('Copy'),
              ]),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(children: [
                Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red),
                SizedBox(width: 10),
                Text('Delete', style: TextStyle(color: Colors.red)),
              ]),
            ),
          ],
        ),
      ]),
      onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => AddTransactionScreen(transaction: txn))),
    );
  }

  Widget _pill(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label,
            style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
      );

  Widget _emptyState() => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('📋', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          const Text('No transactions yet',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text('Tap + to add your first transaction',
              style: TextStyle(color: Colors.grey)),
        ]),
      );

  String _dateLabel(DateTime d) {
    final now = DateTime.now();
    if (d.year == now.year && d.month == now.month && d.day == now.day)
      return 'Today';
    final yesterday = now.subtract(const Duration(days: 1));
    if (d.year == yesterday.year &&
        d.month == yesterday.month &&
        d.day == yesterday.day) return 'Yesterday';
    return DateFormat('EEE, d MMM yyyy').format(d);
  }

  Map<DateTime, List<TransactionModel>> _groupByDate(
      List<TransactionModel> txns) {
    final map = <DateTime, List<TransactionModel>>{};
    for (final t in txns) {
      final key = DateTime(t.date.year, t.date.month, t.date.day);
      map.putIfAbsent(key, () => []).add(t);
    }
    return map;
  }
}