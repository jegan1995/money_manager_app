// lib/screens/goals_screen.dart
// Feature 19 — Enhanced Savings Goals
// Beautiful goal cards, progress bars, auto-deduct from account,
// monthly contribution planner, milestone celebrations
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/goal_model.dart';
import '../models/account_model.dart';
import '../services/goal_service.dart';
import '../services/account_service.dart';
import '../services/transaction_service.dart';
import '../models/transaction_model.dart';

// ── Goal category data ────────────────────────────────────────────────────────
class _GoalCategory {
  final String label;
  final String emoji;
  final Color  color;
  const _GoalCategory(this.label, this.emoji, this.color);
}

const _kCategories = [
  _GoalCategory('Emergency Fund', '🛡️', Color(0xFF667eea)),
  _GoalCategory('Home',           '🏠', Color(0xFF43b89c)),
  _GoalCategory('Car',            '🚗', Color(0xFFfa709a)),
  _GoalCategory('Vacation',       '✈️', Color(0xFFf6d365)),
  _GoalCategory('Education',      '📚', Color(0xFF764ba2)),
  _GoalCategory('Wedding',        '💍', Color(0xFFfe6b8b)),
  _GoalCategory('Gadget',         '📱', Color(0xFF30cfd0)),
  _GoalCategory('Business',       '💼', Color(0xFFa18cd1)),
  _GoalCategory('Investment',     '📈', Color(0xFF43e97b)),
  _GoalCategory('Other',          '🎯', Color(0xFFf77062)),
];

_GoalCategory _catFor(String? icon) =>
    _kCategories.firstWhere((c) => c.emoji == icon,
        orElse: () => _kCategories.last);

// ════════════════════════════════════════════════════════════════════════════
class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});
  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen>
    with SingleTickerProviderStateMixin {
  final _goalSvc = GoalService();
  final _accSvc  = AccountService();
  final _txnSvc  = TransactionService();

  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  // ── Add / Edit goal sheet ─────────────────────────────────────────────────
  void _openGoalSheet({GoalModel? goal}) {
    final nameCtrl   = TextEditingController(text: goal?.name);
    final targetCtrl = TextEditingController(
        text: goal != null ? goal.targetAmount.toStringAsFixed(0) : '');
    final descCtrl   = TextEditingController(text: goal?.description);
    DateTime targetDate =
        goal?.targetDate ?? DateTime.now().add(const Duration(days: 365));
    String selEmoji = goal?.icon ?? _kCategories.first.emoji;
    final isEdit = goal != null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          final isDark =
              Theme.of(context).brightness == Brightness.dark;
          return Padding(
            padding: EdgeInsets.fromLTRB(
                20, 16, 20,
                MediaQuery.of(ctx).viewInsets.bottom + 24),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2)),
                  )),
                  const SizedBox(height: 16),
                  Text(isEdit ? 'Edit Goal' : 'New Savings Goal',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),

                  // Category picker
                  const Text('Category',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey)),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 76,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _kCategories.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(width: 10),
                      itemBuilder: (_, i) {
                        final cat = _kCategories[i];
                        final sel = selEmoji == cat.emoji;
                        return GestureDetector(
                          onTap: () =>
                              setSt(() => selEmoji = cat.emoji),
                          child: AnimatedContainer(
                            duration:
                                const Duration(milliseconds: 150),
                            width: 64,
                            decoration: BoxDecoration(
                              color: sel
                                  ? cat.color.withOpacity(0.15)
                                  : (isDark
                                      ? Colors.white
                                          .withOpacity(0.05)
                                      : Colors.grey.shade50),
                              borderRadius:
                                  BorderRadius.circular(14),
                              border: Border.all(
                                color: sel
                                    ? cat.color
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                              Text(cat.emoji,
                                  style: const TextStyle(
                                      fontSize: 22)),
                              const SizedBox(height: 4),
                              Text(cat.label.split(' ').first,
                                  style: const TextStyle(
                                      fontSize: 8,
                                      fontWeight:
                                          FontWeight.w600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ]),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Goal name
                  _field(nameCtrl, 'Goal Name *', isDark,
                      cap: TextCapitalization.words),
                  const SizedBox(height: 12),

                  // Target amount
                  _field(targetCtrl, '₹ Target Amount *', isDark,
                      num: true, prefix: '₹'),
                  const SizedBox(height: 12),

                  // Description
                  _field(descCtrl, 'Description (optional)', isDark,
                      cap: TextCapitalization.sentences),
                  const SizedBox(height: 12),

                  // Target date
                  GestureDetector(
                    onTap: () async {
                      final d = await showDatePicker(
                        context: ctx,
                        initialDate: targetDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2040),
                      );
                      if (d != null) setSt(() => targetDate = d);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withOpacity(0.05)
                            : Colors.grey.shade50,
                        border: Border.all(
                            color: isDark
                                ? Colors.white24
                                : Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(children: [
                        Icon(Icons.calendar_today_rounded,
                            size: 16, color: Colors.grey[500]),
                        const SizedBox(width: 10),
                        Text(
                          'Target Date: ${DateFormat('d MMM yyyy').format(targetDate)}',
                          style: const TextStyle(fontSize: 13),
                        ),
                        const Spacer(),
                        Icon(Icons.edit_rounded,
                            size: 14, color: Colors.grey[400]),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (nameCtrl.text.trim().isEmpty ||
                            targetCtrl.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(const SnackBar(
                            content:
                                Text('Name and target amount required'),
                            backgroundColor: Colors.red,
                          ));
                          return;
                        }
                        Navigator.pop(ctx);
                        if (isEdit) {
                          await _goalSvc.updateGoal(
                              goal.id!,
                              goal.copyWith(
                                name: nameCtrl.text.trim(),
                                targetAmount: double.tryParse(
                                        targetCtrl.text) ??
                                    goal.targetAmount,
                                description:
                                    descCtrl.text.trim().isEmpty
                                        ? null
                                        : descCtrl.text.trim(),
                                targetDate: targetDate,
                                icon: selEmoji,
                              ));
                        } else {
                          await _goalSvc.addGoal(GoalModel(
                            id:           null,
                            userId:       '',
                            name:         nameCtrl.text.trim(),
                            targetAmount: double.tryParse(
                                    targetCtrl.text) ??
                                0,
                            currentAmount: 0,
                            targetDate:   targetDate,
                            description:
                                descCtrl.text.trim().isEmpty
                                    ? null
                                    : descCtrl.text.trim(),
                            icon:         selEmoji,
                          ));
                        }
                        HapticFeedback.lightImpact();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF667eea),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(
                        isEdit ? 'Save Changes' : 'Create Goal',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Add money sheet (with optional auto-deduct from account) ─────────────
  void _openAddMoneySheet(GoalModel goal) {
    final amountCtrl = TextEditingController();
    String? selAccountId;
    bool autoDeduct = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          final isDark =
              Theme.of(context).brightness == Brightness.dark;
          final cat = _catFor(goal.icon);
          final remaining =
              goal.targetAmount - goal.currentAmount;

          return Padding(
            padding: EdgeInsets.fromLTRB(
                20, 16, 20,
                MediaQuery.of(ctx).viewInsets.bottom + 24),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2)),
                  )),
                  const SizedBox(height: 16),

                  // Goal summary header
                  Row(children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: cat.color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(child: Text(cat.emoji,
                          style: const TextStyle(fontSize: 22))),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(goal.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15)),
                        Text(
                          '₹${goal.currentAmount.toStringAsFixed(0)} / ₹${goal.targetAmount.toStringAsFixed(0)} saved',
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    )),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: cat.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${goal.progressPct.toStringAsFixed(0)}%',
                        style: TextStyle(
                            color: cat.color,
                            fontWeight: FontWeight.bold,
                            fontSize: 13),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 16),

                  // Quick amount chips
                  const Text('Quick Add',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, children: [
                    for (final v in [500, 1000, 2000, 5000,
                        remaining.toInt()])
                      if (v > 0)
                        GestureDetector(
                          onTap: () => setSt(() =>
                              amountCtrl.text = v.toString()),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color:
                                  cat.color.withOpacity(0.08),
                              borderRadius:
                                  BorderRadius.circular(20),
                              border: Border.all(
                                  color: cat.color
                                      .withOpacity(0.3)),
                            ),
                            child: Text(
                              v == remaining.toInt()
                                  ? '₹$v (Finish!)'
                                  : '₹$v',
                              style: TextStyle(
                                  color: cat.color,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                  ]),
                  const SizedBox(height: 14),

                  // Amount input
                  _field(amountCtrl, '₹ Amount to Add *', isDark,
                      num: true, prefix: '₹'),
                  const SizedBox(height: 14),

                  // Auto-deduct toggle
                  FutureBuilder<List<AccountModel>>(
                    future: _accSvc.getAccountsList().first,
                    builder: (_, snap) {
                      final accounts = snap.data ?? [];
                      if (accounts.isEmpty) return const SizedBox();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text(
                              'Deduct from Account',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600),
                            ),
                            subtitle: const Text(
                              'Records as expense & deducts from balance',
                              style: TextStyle(fontSize: 11),
                            ),
                            value: autoDeduct,
                            activeColor: cat.color,
                            onChanged: (v) =>
                                setSt(() => autoDeduct = v),
                          ),
                          if (autoDeduct) ...[
                            const SizedBox(height: 4),
                            DropdownButtonFormField<String>(
                              value: selAccountId,
                              decoration: InputDecoration(
                                labelText: 'Select Account',
                                border: OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.circular(12)),
                                filled: true,
                                fillColor: isDark
                                    ? Colors.white.withOpacity(0.05)
                                    : Colors.grey.shade50,
                                contentPadding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 12),
                              ),
                              items: accounts
                                  .map((a) => DropdownMenuItem(
                                        value: a.id,
                                        child: Text(
                                          '${a.name}  (₹${a.balance.toStringAsFixed(0)})',
                                          style: const TextStyle(
                                              fontSize: 13),
                                        ),
                                      ))
                                  .toList(),
                              onChanged: (v) =>
                                  setSt(() => selAccountId = v),
                            ),
                          ],
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final amt =
                            double.tryParse(amountCtrl.text);
                        if (amt == null || amt <= 0) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(const SnackBar(
                            content: Text('Enter a valid amount'),
                            backgroundColor: Colors.red,
                          ));
                          return;
                        }
                        if (autoDeduct &&
                            selAccountId == null) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(const SnackBar(
                            content: Text('Select an account'),
                            backgroundColor: Colors.red,
                          ));
                          return;
                        }
                        Navigator.pop(ctx);
                        await _addMoney(
                          goal: goal,
                          amount: amt,
                          accountId: autoDeduct ? selAccountId : null,
                        );
                      },
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add to Goal',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: cat.color,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Add money logic ────────────────────────────────────────────────────────
  Future<void> _addMoney({
    required GoalModel goal,
    required double amount,
    String? accountId,
  }) async {
    try {
      await _goalSvc.addAmountToGoal(goal.id!, amount);

      // If auto-deduct: record expense transaction
      if (accountId != null) {
        await _txnSvc.addTransaction(TransactionModel(
          id:            '',
          userId:        '',
          type:          'expense',
          amount:        amount,
          category:      'Savings',
          paymentMethod: 'Other',
          date:          DateTime.now(),
          note:          'Savings: ${goal.name}',
          fromAccount:   accountId,
          isRecurring:   false,
          createdAt:     DateTime.now(),
        ));
      }

      HapticFeedback.mediumImpact();
      final newAmt = goal.currentAmount + amount;
      final done  = newAmt >= goal.targetAmount;

      if (done) {
        _showCelebration(goal);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            '✅ ₹${amount.toStringAsFixed(0)} added to "${goal.name}"'
            '${accountId != null ? ' & deducted from account' : ''}',
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed: $e'),
        backgroundColor: Colors.red,
      ));
    }
  }

  // ── Celebration dialog ─────────────────────────────────────────────────────
  void _showCelebration(GoalModel goal) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('🎉', style: TextStyle(fontSize: 60)),
            const SizedBox(height: 16),
            const Text('Goal Completed!',
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              '"${goal.name}" is fully funded!',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF667eea),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Awesome! 🚀',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ]),
        ),
      ),
    );
  }

  // ── Delete goal ────────────────────────────────────────────────────────────
  Future<void> _deleteGoal(GoalModel goal) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Goal'),
        content: Text('Delete "${goal.name}"? This cannot be undone.'),
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
      await _goalSvc.deleteGoal(goal.id!);
      HapticFeedback.mediumImpact();
    }
  }

  // ── Monthly plan calculator ───────────────────────────────────────────────
  double _monthlyNeeded(GoalModel g) {
    final months = g.targetDate.difference(DateTime.now()).inDays / 30;
    if (months <= 0) return g.targetAmount - g.currentAmount;
    return ((g.targetAmount - g.currentAmount) / months)
        .clamp(0, double.infinity);
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark =
        Theme.of(context).brightness == Brightness.dark;
    final bg   = isDark ? const Color(0xFF0D1117) : const Color(0xFFF0F2F8);
    final card = isDark ? const Color(0xFF1E2530) : Colors.white;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Savings Goals',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: isDark ? const Color(0xFF1E2530) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        elevation: 0,
        bottom: TabBar(
          controller: _tabs,
          labelColor: const Color(0xFF667eea),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF667eea),
          tabs: const [
            Tab(text: 'Active'),
            Tab(text: 'Completed'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openGoalSheet(),
        backgroundColor: const Color(0xFF667eea),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Goal',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _goalSvc.getGoals(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(
                    color: Color(0xFF667eea)));
          }

          final all = (snap.data?.docs ?? [])
              .map((d) => GoalModel.fromMap(
                    d.data() as Map<String, dynamic>, d.id))
              .toList();

          final active    = all.where((g) => !g.isCompleted).toList()
            ..sort((a, b) => a.targetDate.compareTo(b.targetDate));
          final completed = all.where((g) => g.isCompleted).toList();

          return TabBarView(
            controller: _tabs,
            children: [
              // ── Active goals ──────────────────────────────────────
              active.isEmpty
                  ? _emptyState(isDark)
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                      children: [
                        // Summary strip
                        if (active.isNotEmpty)
                          _summaryStrip(active, card, isDark),
                        const SizedBox(height: 16),
                        ...active.map((g) =>
                            _goalCard(g, card, isDark)),
                      ],
                    ),

              // ── Completed goals ───────────────────────────────────
              completed.isEmpty
                  ? _emptyCompleted(isDark)
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                      children: completed
                          .map((g) => _goalCard(g, card, isDark))
                          .toList(),
                    ),
            ],
          );
        },
      ),
    );
  }

  // ── Summary strip ──────────────────────────────────────────────────────────
  Widget _summaryStrip(
      List<GoalModel> goals, Color card, bool isDark) {
    final totalTarget =
        goals.fold(0.0, (s, g) => s + g.targetAmount);
    final totalSaved =
        goals.fold(0.0, (s, g) => s + g.currentAmount);
    final totalMonthly =
        goals.fold(0.0, (s, g) => s + _monthlyNeeded(g));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(children: [
        _stripStat('Total Goals', '${goals.length}'),
        _divider(),
        _stripStat('Total Saved',
            '₹${_fmt(totalSaved)}'),
        _divider(),
        _stripStat('Monthly Need',
            '₹${_fmt(totalMonthly)}'),
      ]),
    );
  }

  Widget _stripStat(String label, String value) => Expanded(
        child: Column(children: [
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  color: Colors.white70, fontSize: 9)),
        ]),
      );

  Widget _divider() => Container(
        width: 1, height: 30,
        color: Colors.white.withOpacity(0.2),
        margin: const EdgeInsets.symmetric(horizontal: 4));

  // ── Goal card ──────────────────────────────────────────────────────────────
  Widget _goalCard(GoalModel goal, Color card, bool isDark) {
    final cat      = _catFor(goal.icon);
    final pct      = goal.progressPct.clamp(0.0, 100.0);
    final monthly  = _monthlyNeeded(goal);
    final daysLeft = goal.targetDate.difference(DateTime.now()).inDays;
    final overdue  = daysLeft < 0 && !goal.isCompleted;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(children: [
        // Top section
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                // Icon
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: cat.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(child: Text(cat.emoji,
                      style: const TextStyle(fontSize: 22))),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(goal.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
                    if (goal.description != null)
                      Text(goal.description!,
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                  ],
                )),
                // Status badge
                if (goal.isCompleted)
                  _badge('✅ Done', Colors.green)
                else if (overdue)
                  _badge('⚠️ Overdue', Colors.red)
                else
                  _badge(
                    '$daysLeft days',
                    daysLeft < 30 ? Colors.orange : Colors.grey,
                  ),
              ]),

              const SizedBox(height: 14),

              // Progress bar
              Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                  children: [
                Text(
                  '₹${_fmt(goal.currentAmount)} saved',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
                Text(
                  '${pct.toStringAsFixed(0)}% of ₹${_fmt(goal.targetAmount)}',
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey[500]),
                ),
              ]),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: pct / 100,
                  minHeight: 10,
                  backgroundColor: cat.color.withOpacity(0.1),
                  valueColor:
                      AlwaysStoppedAnimation(cat.color),
                ),
              ),

              // Milestone markers
              if (!goal.isCompleted) ...[
                const SizedBox(height: 8),
                _milestones(pct, cat.color),
              ],

              const SizedBox(height: 10),

              // Stats row
              Row(children: [
                _infoChip(Icons.calendar_today_rounded,
                    DateFormat('d MMM yy')
                        .format(goal.targetDate)),
                const SizedBox(width: 8),
                if (!goal.isCompleted)
                  _infoChip(Icons.savings_rounded,
                      '₹${_fmt(monthly)}/mo needed'),
                const Spacer(),
                if (!goal.isCompleted)
                  _infoChip(Icons.account_balance_wallet_rounded,
                      '₹${_fmt(goal.targetAmount - goal.currentAmount)} left',
                      color: cat.color),
              ]),
            ],
          ),
        ),

        // Action buttons
        if (!goal.isCompleted)
          Container(
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.04)
                  : Colors.grey.shade50,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(18),
              ),
            ),
            child: Row(children: [
              // Add money
              Expanded(child: TextButton.icon(
                onPressed: () => _openAddMoneySheet(goal),
                icon: Icon(Icons.add_circle_outline_rounded,
                    color: cat.color, size: 16),
                label: Text('Add Money',
                    style: TextStyle(
                        color: cat.color,
                        fontWeight: FontWeight.bold,
                        fontSize: 12)),
              )),
              Container(width: 1, height: 32,
                  color: isDark
                      ? Colors.white12 : Colors.grey.shade200),
              // Edit
              Expanded(child: TextButton.icon(
                onPressed: () => _openGoalSheet(goal: goal),
                icon: Icon(Icons.edit_rounded,
                    color: Colors.grey[500], size: 16),
                label: Text('Edit',
                    style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12)),
              )),
              Container(width: 1, height: 32,
                  color: isDark
                      ? Colors.white12 : Colors.grey.shade200),
              // Delete
              Expanded(child: TextButton.icon(
                onPressed: () => _deleteGoal(goal),
                icon: const Icon(Icons.delete_outline_rounded,
                    color: Colors.red, size: 16),
                label: const Text('Delete',
                    style: TextStyle(
                        color: Colors.red, fontSize: 12)),
              )),
            ]),
          ),
      ]),
    );
  }

  // ── Milestone row ──────────────────────────────────────────────────────────
  Widget _milestones(double pct, Color color) {
    return Row(children: [
      for (final m in [25, 50, 75, 100])
        Expanded(child: Row(children: [
          if (m > 25) Expanded(child: Container(
            height: 1.5,
            color: pct >= m
                ? color.withOpacity(0.4) : Colors.grey.shade200,
          )),
          Container(
            width: 18, height: 18,
            decoration: BoxDecoration(
              color: pct >= m
                  ? color : Colors.grey.shade200,
              shape: BoxShape.circle,
            ),
            child: Center(child: Text(
              pct >= m ? '✓' : '$m',
              style: TextStyle(
                  color: pct >= m ? Colors.white : Colors.grey,
                  fontSize: 7,
                  fontWeight: FontWeight.bold),
            )),
          ),
        ])),
    ]);
  }

  Widget _badge(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.bold)),
      );

  Widget _infoChip(IconData icon, String label,
          {Color? color}) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11,
            color: color ?? Colors.grey[400]),
        const SizedBox(width: 3),
        Text(label,
            style: TextStyle(
                fontSize: 10,
                color: color ?? Colors.grey[500])),
      ]);

  Widget _emptyState(bool isDark) => Center(
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
          const Text('🎯', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          const Text('No Savings Goals Yet',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Tap "+ New Goal" to start saving',
              style: TextStyle(color: Colors.grey[500])),
        ]),
      );

  Widget _emptyCompleted(bool isDark) => Center(
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
          const Text('🏆', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          const Text('No Completed Goals Yet',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Keep saving — you\'ll get there!',
              style: TextStyle(color: Colors.grey[500])),
        ]),
      );

  // ── Helpers ────────────────────────────────────────────────────────────────
  String _fmt(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000)   return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    bool isDark, {
    bool num = false,
    String? prefix,
    TextCapitalization cap = TextCapitalization.none,
  }) =>
      TextField(
        controller: ctrl,
        keyboardType: num
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        inputFormatters: num
            ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]
            : null,
        textCapitalization: cap,
        decoration: InputDecoration(
          labelText: label,
          prefixText: prefix,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: isDark
              ? Colors.white.withOpacity(0.05)
              : Colors.grey.shade50,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 14),
          labelStyle: const TextStyle(fontSize: 12),
        ),
        style: const TextStyle(fontSize: 13),
      );
}

// ── Extension on GoalModel ────────────────────────────────────────────────────
extension GoalExt on GoalModel {
  double get progressPct =>
      targetAmount > 0 ? (currentAmount / targetAmount) * 100 : 0;
}