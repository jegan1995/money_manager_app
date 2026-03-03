// lib/screens/data_management_screen.dart
// Feature 18 — Data Management & Power Utilities
// Clear transactions, delete account, carry forward budget,
// bulk copy transactions, transaction stats dashboard
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/transaction_model.dart';
import '../models/budget_model.dart';
import '../services/transaction_service.dart';
import '../services/account_service.dart';
import '../services/budget_service.dart';
import '../services/auth_service.dart';

class DataManagementScreen extends StatefulWidget {
  const DataManagementScreen({super.key});
  @override
  State<DataManagementScreen> createState() => _DataManagementScreenState();
}

class _DataManagementScreenState extends State<DataManagementScreen> {
  final _txnSvc  = TransactionService();
  final _accSvc  = AccountService();
  final _budgSvc = BudgetService();
  final _authSvc = AuthService();

  bool _loading = false;
  Map<String, dynamic> _stats = {};

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  // ── Load data summary ──────────────────────────────────────────────────────
  Future<void> _loadStats() async {
    setState(() => _loading = true);
    try {
      final txns  = await _txnSvc.getTransactionsList();
      final accs  = await _accSvc.getAccountsList().first;
      final now   = DateTime.now();
      final thisMonthTxns = txns.where((t) =>
          t.date.month == now.month && t.date.year == now.year).toList();
      final income  = thisMonthTxns.where((t) => t.type == 'income')
          .fold(0.0, (s, t) => s + t.amount);
      final expense = thisMonthTxns.where((t) => t.type == 'expense')
          .fold(0.0, (s, t) => s + t.amount);

      setState(() {
        _stats = {
          'totalTxns':   txns.length,
          'totalAccs':   accs.length,
          'thisMonth':   thisMonthTxns.length,
          'income':      income,
          'expense':     expense,
          'oldestDate':  txns.isNotEmpty
              ? txns.last.date : null,
        };
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  // ── Clear transactions ─────────────────────────────────────────────────────
  Future<void> _clearTransactions({
    required String type,    // 'all' | 'expense' | 'income' | 'transfer'
    required String period,  // 'all' | 'this_month' | 'last_month' | 'this_year'
  }) async {
    final confirmed = await _showConfirmDialog(
      title: 'Clear Transactions',
      message:
          'Delete ${type == 'all' ? 'ALL' : type} transactions '
          '(${_periodLabel(period)})?\n\n'
          '⚠️ This cannot be undone. Account balances will be reversed.',
      confirmText: 'DELETE',
      confirmColor: Colors.red,
      requireTyping: true,
      typingConfirmWord: 'DELETE',
    );
    if (!confirmed) return;

    setState(() => _loading = true);
    try {
      final all  = await _txnSvc.getTransactionsList();
      final now  = DateTime.now();

      final filtered = all.where((t) {
        // Type filter
        if (type != 'all' && t.type != type) return false;
        // Period filter
        if (period == 'this_month') {
          return t.date.month == now.month && t.date.year == now.year;
        }
        if (period == 'last_month') {
          final lm = DateTime(now.year, now.month - 1);
          return t.date.month == lm.month && t.date.year == lm.year;
        }
        if (period == 'this_year') {
          return t.date.year == now.year;
        }
        return true; // 'all'
      }).toList();

      int deleted = 0;
      for (final t in filtered) {
        await _txnSvc.deleteTransaction(t.id);
        deleted++;
      }

      await _loadStats();
      HapticFeedback.mediumImpact();
      _snack('✅ Deleted $deleted transaction(s)', green: true);
    } catch (e) {
      setState(() => _loading = false);
      _snack('Failed: $e', green: false);
    }
  }

  // ── Carry forward budget ───────────────────────────────────────────────────
  Future<void> _carryForwardBudget() async {
    final now  = DateTime.now();
    final next = DateTime(now.year, now.month + 1);

    final confirmed = await _showConfirmDialog(
      title: 'Carry Forward Budget',
      message:
          'Copy this month\'s budget plan to '
          '${DateFormat('MMMM yyyy').format(next)}?\n\n'
          'Existing budgets for next month will NOT be overwritten.',
      confirmText: 'Copy Budget',
      confirmColor: const Color(0xFF667eea),
    );
    if (!confirmed) return;

    setState(() => _loading = true);
    try {
      // Get this month's budgets
      final snap = await _budgSvc
          .getBudgetsForMonth(now.month, now.year)
          .first;
      final budgets = snap.docs
          .map((d) => BudgetModel.fromFirestore(d))
          .toList();

      // Get next month existing
      final nextSnap = await _budgSvc
          .getBudgetsForMonth(next.month, next.year)
          .first;
      final existingCats = nextSnap.docs
          .map((d) => BudgetModel.fromFirestore(d).category)
          .toSet();

      int copied = 0;
      for (final b in budgets) {
        if (!existingCats.contains(b.category)) {
          await _budgSvc.addBudget(BudgetModel(
            id:        '',
            userId:    '',
            category:  b.category,
            amount:    b.amount,
            month:     next.month,
            year:      next.year,
            createdAt: DateTime.now(),
          ));
          copied++;
        }
      }

      setState(() => _loading = false);
      HapticFeedback.lightImpact();
      _snack(
        copied > 0
            ? '✅ Copied $copied budget(s) to ${DateFormat('MMM yyyy').format(next)}'
            : 'All categories already exist for next month',
        green: copied > 0,
      );
    } catch (e) {
      setState(() => _loading = false);
      _snack('Failed: $e', green: false);
    }
  }

  // ── Bulk copy transactions month → month ───────────────────────────────────
  Future<void> _bulkCopyTransactions() async {
    final now  = DateTime.now();
    // Default: copy last month's recurring to this month
    final from = DateTime(now.year, now.month - 1);

    final confirmed = await _showConfirmDialog(
      title: 'Copy Last Month\'s Transactions',
      message:
          'Copy all RECURRING transactions from '
          '${DateFormat('MMMM yyyy').format(from)} to '
          '${DateFormat('MMMM yyyy').format(now)}?\n\n'
          'Only transactions marked as recurring will be copied.',
      confirmText: 'Copy',
      confirmColor: Colors.orange,
    );
    if (!confirmed) return;

    setState(() => _loading = true);
    try {
      final all = await _txnSvc.getTransactionsList();
      final lastMonthRecurring = all.where((t) =>
          t.date.month == from.month &&
          t.date.year  == from.year  &&
          t.isRecurring).toList();

      int copied = 0;
      for (final t in lastMonthRecurring) {
        final newDate = DateTime(now.year, now.month, t.date.day);
        final copy = TransactionModel(
          id:                '',
          userId:            '',
          type:              t.type,
          amount:            t.amount,
          category:          t.category,
          subcategory:       t.subcategory,
          paymentMethod:     t.paymentMethod,
          date:              newDate,
          note:              t.note != null ? '${t.note} (copied)' : 'Copied',
          description:       t.description,
          fromAccount:       t.fromAccount,
          toAccount:         t.toAccount,
          isRecurring:       true,
          recurringFrequency: t.recurringFrequency,
          createdAt:         DateTime.now(),
        );
        await _txnSvc.addTransaction(copy);
        copied++;
      }

      await _loadStats();
      HapticFeedback.lightImpact();
      _snack(
        copied > 0
            ? '✅ Copied $copied recurring transaction(s)'
            : 'No recurring transactions found in last month',
        green: copied > 0,
      );
    } catch (e) {
      setState(() => _loading = false);
      _snack('Failed: $e', green: false);
    }
  }

  // ── Reset account balances ─────────────────────────────────────────────────
  Future<void> _recalculateBalances() async {
    final confirmed = await _showConfirmDialog(
      title: 'Recalculate Balances',
      message:
          'Recalculate all account balances from transaction history?\n\n'
          'Use this if balances seem incorrect.',
      confirmText: 'Recalculate',
      confirmColor: Colors.blue,
    );
    if (!confirmed) return;

    setState(() => _loading = true);
    try {
      final accs = await _accSvc.getAccountsList().first;
      final txns = await _txnSvc.getTransactionsList();

      for (final acc in accs) {
        double balance = 0;
        for (final t in txns) {
          if (t.type == 'income'   && t.toAccount   == acc.id) balance += t.amount;
          if (t.type == 'expense'  && t.fromAccount == acc.id) balance -= t.amount;
          if (t.type == 'transfer' && t.toAccount   == acc.id) balance += t.amount;
          if (t.type == 'transfer' && t.fromAccount == acc.id) balance -= t.amount;
        }
        await FirebaseFirestore.instance
            .collection('accounts')
            .doc(acc.id)
            .update({'balance': balance});
      }

      setState(() => _loading = false);
      HapticFeedback.lightImpact();
      _snack('✅ Balances recalculated for ${accs.length} account(s)',
          green: true);
    } catch (e) {
      setState(() => _loading = false);
      _snack('Failed: $e', green: false);
    }
  }

  // ── Delete account ─────────────────────────────────────────────────────────
  Future<void> _deleteAccount() async {
    final confirmed = await _showConfirmDialog(
      title: '⚠️ Delete Account',
      message:
          'This will PERMANENTLY delete:\n\n'
          '• All your transactions\n'
          '• All accounts\n'
          '• All budgets & goals\n'
          '• Your login credentials\n\n'
          'This action CANNOT be undone.',
      confirmText: 'DELETE ACCOUNT',
      confirmColor: Colors.red,
      requireTyping: true,
      typingConfirmWord: 'DELETE',
    );
    if (!confirmed) return;

    setState(() => _loading = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('Not logged in');

      final db = FirebaseFirestore.instance;

      // Delete all user collections in parallel
      await Future.wait([
        _deleteCollection(db, 'transactions', uid),
        _deleteCollection(db, 'accounts', uid),
        _deleteCollection(db, 'budgets', uid),
        _deleteCollection(db, 'goals', uid),
        _deleteCollection(db, 'loans', uid),
        _deleteCollection(db, 'investments', uid),
        _deleteCollection(db, 'net_worth_items', uid),
        _deleteCollection(db, 'budget_plans', uid),
        _deleteCollection(db, 'split_expenses', uid),
        _deleteCollection(db, 'subscriptions', uid),
        _deleteCollection(db, 'bill_reminders', uid),
      ]);

      // Delete user doc
      await db.collection('users').doc(uid).delete();

      // Delete Firebase Auth account
      await _authSvc.deleteAccount();
    } catch (e) {
      setState(() => _loading = false);
      _snack('Failed to delete account: $e', green: false);
    }
  }

  Future<void> _deleteCollection(
      FirebaseFirestore db, String col, String uid) async {
    try {
      final snap = await db.collection(col)
          .where('userId', isEqualTo: uid).get();
      final batch = db.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (_) {}
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  String _periodLabel(String p) {
    switch (p) {
      case 'this_month':  return 'This Month';
      case 'last_month':  return 'Last Month';
      case 'this_year':   return 'This Year';
      default:            return 'All Time';
    }
  }

  void _snack(String msg, {required bool green}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: green ? Colors.green : Colors.red,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ── Confirm dialog with optional type-to-confirm ───────────────────────────
  Future<bool> _showConfirmDialog({
    required String title,
    required String message,
    required String confirmText,
    required Color  confirmColor,
    bool   requireTyping      = false,
    String typingConfirmWord  = 'DELETE',
  }) async {
    final ctrl = TextEditingController();
    bool typed = !requireTyping;

    return await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: Text(title,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message, style: const TextStyle(fontSize: 13)),
              if (requireTyping) ...[
                const SizedBox(height: 16),
                Text(
                  'Type "$typingConfirmWord" to confirm:',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: ctrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: typingConfirmWord,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                  onChanged: (v) =>
                      setSt(() => typed = v.trim().toUpperCase() ==
                          typingConfirmWord.toUpperCase()),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: typed
                  ? () => Navigator.pop(ctx, true)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: confirmColor,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey[300],
              ),
              child: Text(confirmText,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    ) ?? false;
  }

  // ── Clear sheet ─────────────────────────────────────────────────────────
  void _showClearSheet() {
    String selType   = 'all';
    String selPeriod = 'this_month';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2)),
              )),
              const SizedBox(height: 16),
              const Text('Clear Transactions',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),

              // Transaction type
              const Text('Transaction Type',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600,
                      color: Colors.grey)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: [
                for (final t in [
                  ('all', 'All'),
                  ('expense', '↑ Expense'),
                  ('income',  '↓ Income'),
                  ('transfer','⇄ Transfer'),
                ])
                  ChoiceChip(
                    label: Text(t.$2,
                        style: TextStyle(
                            fontSize: 12,
                            color: selType == t.$1
                                ? Colors.white : null)),
                    selected: selType == t.$1,
                    selectedColor: Colors.red,
                    onSelected: (_) => setSt(() => selType = t.$1),
                  ),
              ]),
              const SizedBox(height: 16),

              // Period
              const Text('Period',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600,
                      color: Colors.grey)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: [
                for (final p in [
                  ('this_month', 'This Month'),
                  ('last_month', 'Last Month'),
                  ('this_year',  'This Year'),
                  ('all',        'All Time'),
                ])
                  ChoiceChip(
                    label: Text(p.$2,
                        style: TextStyle(
                            fontSize: 12,
                            color: selPeriod == p.$1
                                ? Colors.white : null)),
                    selected: selPeriod == p.$1,
                    selectedColor: Colors.red,
                    onSelected: (_) => setSt(() => selPeriod = p.$1),
                  ),
              ]),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _clearTransactions(
                        type: selType, period: selPeriod);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Clear Transactions',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0D1117) : const Color(0xFFF0F2F8),
      appBar: AppBar(
        title: const Text('Data Management',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: isDark ? const Color(0xFF1E2530) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadStats,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF667eea)),
                  SizedBox(height: 16),
                  Text('Processing...', style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [

                // ── Stats summary card ──────────────────────────────────
                _sectionCard(
                  isDark: isDark,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle('📊 Data Summary', isDark),
                      const SizedBox(height: 12),
                      Row(children: [
                        _statBox('Total\nTransactions',
                            '${_stats['totalTxns'] ?? 0}',
                            const Color(0xFF667eea), isDark),
                        const SizedBox(width: 10),
                        _statBox('Accounts',
                            '${_stats['totalAccs'] ?? 0}',
                            Colors.orange, isDark),
                        const SizedBox(width: 10),
                        _statBox('This Month',
                            '${_stats['thisMonth'] ?? 0}',
                            Colors.green, isDark),
                      ]),
                      if (_stats['oldestDate'] != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          'Data since: ${DateFormat('d MMM y').format(_stats['oldestDate'])}',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey[500]),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── Transaction tools ───────────────────────────────────
                _sectionCard(
                  isDark: isDark,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle('🔧 Transaction Tools', isDark),
                      const SizedBox(height: 4),

                      _utilTile(
                        icon: Icons.delete_sweep_rounded,
                        color: Colors.red,
                        title: 'Clear Transactions',
                        subtitle: 'Delete by type and date range',
                        onTap: _showClearSheet,
                        isDark: isDark,
                      ),

                      _utilTile(
                        icon: Icons.copy_all_rounded,
                        color: Colors.orange,
                        title: 'Copy Last Month\'s Recurring',
                        subtitle: 'Duplicate recurring transactions to this month',
                        onTap: _bulkCopyTransactions,
                        isDark: isDark,
                      ),

                      _utilTile(
                        icon: Icons.calculate_rounded,
                        color: Colors.blue,
                        title: 'Recalculate Balances',
                        subtitle: 'Fix account balances from transaction history',
                        onTap: _recalculateBalances,
                        isDark: isDark,
                        isLast: true,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── Budget tools ────────────────────────────────────────
                _sectionCard(
                  isDark: isDark,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle('📅 Budget Tools', isDark),
                      const SizedBox(height: 4),

                      _utilTile(
                        icon: Icons.forward_rounded,
                        color: const Color(0xFF667eea),
                        title: 'Carry Forward Budget',
                        subtitle: 'Copy this month\'s plan to next month',
                        onTap: _carryForwardBudget,
                        isDark: isDark,
                        isLast: true,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── Danger zone ─────────────────────────────────────────
                Container(
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: Colors.red.withOpacity(0.2), width: 1.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                        child: Row(children: [
                          const Icon(Icons.warning_amber_rounded,
                              color: Colors.red, size: 16),
                          const SizedBox(width: 6),
                          const Text('Danger Zone',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red)),
                        ]),
                      ),

                      _utilTile(
                        icon: Icons.person_remove_rounded,
                        color: Colors.red,
                        title: 'Delete My Account',
                        subtitle: 'Permanently delete account & all data',
                        onTap: _deleteAccount,
                        isDark: isDark,
                        isLast: true,
                        titleColor: Colors.red,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
    );
  }

  // ── Reusable widgets ───────────────────────────────────────────────────────
  Widget _sectionCard({required Widget child, required bool isDark}) =>
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2530) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4)),
          ],
        ),
        child: child,
      );

  Widget _sectionTitle(String title, bool isDark) => Text(
        title,
        style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white70 : Colors.black87),
      );

  Widget _statBox(String label, String value, Color color, bool isDark) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: [
            Text(value,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color)),
            const SizedBox(height: 3),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 9, color: Colors.grey)),
          ]),
        ),
      );

  Widget _utilTile({
    required IconData icon,
    required Color    color,
    required String   title,
    required String   subtitle,
    required VoidCallback onTap,
    required bool     isDark,
    bool  isLast      = false,
    Color? titleColor,
  }) =>
      Column(children: [
        ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          leading: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 20),
          ),
          title: Text(title,
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: titleColor)),
          subtitle: Text(subtitle,
              style: const TextStyle(fontSize: 11, color: Colors.grey)),
          trailing: Icon(Icons.arrow_forward_ios_rounded,
              size: 14, color: Colors.grey[400]),
          onTap: onTap,
        ),
        if (!isLast)
          Divider(height: 1,
              color: isDark
                  ? Colors.white.withOpacity(0.06)
                  : Colors.grey.shade100),
      ]);
}