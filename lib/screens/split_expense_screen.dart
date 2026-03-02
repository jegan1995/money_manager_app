// lib/screens/split_expense_screen.dart
// Split Expense Manager — full rebuild with settlement dashboard,
// equal/custom/% split modes, "who owes me" summary, group tracking
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/split_expense_model.dart';
import '../services/split_expense_service.dart';

final _inr = NumberFormat.currency(
    locale: 'en_IN', symbol: '₹', decimalDigits: 0);
String _f(double v) => _inr.format(v.abs());

// ── Split categories ──────────────────────────────────────────────────────────
const _categories = [
  ('🍽️', 'Food'),      ('🏠', 'Rent'),
  ('✈️', 'Travel'),    ('🎉', 'Party'),
  ('🛒', 'Groceries'), ('⚡', 'Utilities'),
  ('🎬', 'Movies'),    ('📦', 'Other'),
];

// ════════════════════════════════════════════════════════════════════════════
class SplitExpenseScreen extends StatelessWidget {
  const SplitExpenseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final svc    = SplitExpenseService();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg     = isDark ? const Color(0xFF0D1117) : const Color(0xFFF0F2F8);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Split Expenses',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: isDark ? const Color(0xFF1E2530) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        elevation: 0,
      ),
      body: StreamBuilder<List<SplitExpenseModel>>(
        stream: svc.getSplitExpenses(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final all      = snap.data ?? [];
          if (all.isEmpty) return _EmptyState(
              onAdd: () => _showAddSheet(context, svc, isDark, null));

          final active   = all.where((e) => !e.isSettled).toList();
          final settled  = all.where((e) =>  e.isSettled).toList();

          // Settlement summary totals
          double totalOwedToMe = 0;
          double totalIOwe     = 0;
          for (final e in active) {
            for (int i = 0; i < e.splits.length; i++) {
              final s = e.splits[i];
              if (!s.isPaid) {
                // Index 0 = "You" (the creator)
                if (i == 0) totalIOwe    += s.amount;
                else        totalOwedToMe += s.amount;
              }
            }
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Settlement dashboard ────────────────────────────────────
              _SettlementDashboard(
                owedToMe: totalOwedToMe,
                iOwe:     totalIOwe,
                isDark:   isDark,
              ),
              const SizedBox(height: 20),

              // ── Active splits ───────────────────────────────────────────
              if (active.isNotEmpty) ...[
                _sectionHead('Active Splits (${active.length})', isDark),
                const SizedBox(height: 10),
                ...active.map((e) => _SplitCard(
                  expense: e, svc: svc, isDark: isDark,
                  onEdit: () => _showAddSheet(
                      context, svc, isDark, e),
                  onDelete: () => _confirmDelete(context, e, svc),
                )),
              ],

              // ── Settled splits ──────────────────────────────────────────
              if (settled.isNotEmpty) ...[
                const SizedBox(height: 20),
                _sectionHead('Settled (${settled.length})', isDark),
                const SizedBox(height: 10),
                ...settled.map((e) => _SplitCard(
                  expense: e, svc: svc, isDark: isDark,
                  settled: true,
                  onEdit: () => _showAddSheet(
                      context, svc, isDark, e),
                  onDelete: () => _confirmDelete(context, e, svc),
                )),
              ],
              const SizedBox(height: 80),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSheet(context, svc, isDark, null),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.group_add_rounded),
        label: const Text('Split Bill',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  // ── Add / Edit bottom sheet ───────────────────────────────────────────────
  static void _showAddSheet(BuildContext ctx, SplitExpenseService svc,
      bool isDark, SplitExpenseModel? existing) {
    // Controllers
    final descCtrl   = TextEditingController(
        text: existing?.description ?? '');
    final totalCtrl  = TextEditingController(
        text: existing != null
            ? existing.totalAmount.toStringAsFixed(0) : '');
    String category  = existing?.category ?? 'Other';
    DateTime date    = existing?.date ?? DateTime.now();

    // People list (name, amount, isPaid)
    final people = existing != null
        ? existing.splits
            .map((s) => _PersonEntry(
                name: s.name, amount: s.amount, isPaid: s.isPaid))
            .toList()
        : <_PersonEntry>[
            _PersonEntry(name: 'You'),
            _PersonEntry(name: ''),
          ];

    // Split mode: equal / custom
    String splitMode = 'equal';

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(builder: (ctx, setSheet) {
        // Auto-calculate equal split
        void recalcEqual() {
          if (splitMode != 'equal') return;
          final total = double.tryParse(totalCtrl.text) ?? 0;
          final n     = people.length;
          if (n == 0 || total == 0) return;
          final each  = total / n;
          for (final p in people) p.amount = each;
          setSheet(() {});
        }

        final total   = double.tryParse(totalCtrl.text) ?? 0;
        final sumSplit = people.fold(0.0, (s, p) => s + p.amount);
        final diff     = total - sumSplit;
        final balanced = diff.abs() < 0.5;

        return Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2530) : Colors.white,
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2)),
                )),
                Text(existing == null ? 'Split a Bill' : 'Edit Split',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),

                // Description + amount row
                Row(children: [
                  Expanded(child: _tf(descCtrl, 'Description *',
                      isDark, cap: TextCapitalization.sentences)),
                  const SizedBox(width: 10),
                  SizedBox(width: 120, child: _tf(totalCtrl,
                      'Total ₹ *', isDark, num: true,
                      onChanged: (_) => recalcEqual())),
                ]),
                const SizedBox(height: 12),

                // Category chips
                SizedBox(
                  height: 38,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: _categories.map((c) {
                      final sel = category == c.$2;
                      return GestureDetector(
                        onTap: () => setSheet(() => category = c.$2),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: sel
                                ? Colors.orange.withOpacity(0.15)
                                : Colors.grey.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: sel ? Colors.orange
                                  : Colors.transparent,
                              width: 1.5),
                          ),
                          child: Text('${c.$1} ${c.$2}',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: sel
                                      ? Colors.orange : Colors.grey,
                                  fontWeight: sel
                                      ? FontWeight.bold
                                      : FontWeight.normal)),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 12),

                // Date picker
                GestureDetector(
                  onTap: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (d != null) setSheet(() => date = d);
                  },
                  child: Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.grey.shade50,
                      border: Border.all(
                          color: isDark
                              ? Colors.white24
                              : Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(children: [
                      Icon(Icons.calendar_today_rounded,
                          size: 14,
                          color: isDark
                              ? Colors.white54 : Colors.grey[500]),
                      const SizedBox(width: 8),
                      Text(DateFormat('d MMM y').format(date),
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13)),
                    ]),
                  ),
                ),
                const SizedBox(height: 16),

                // Split mode toggle
                Row(children: [
                  const Text('Split mode:',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                  const SizedBox(width: 12),
                  _modeChip('Equal', splitMode == 'equal',
                      () => setSheet(() {
                        splitMode = 'equal';
                        recalcEqual();
                      })),
                  const SizedBox(width: 8),
                  _modeChip('Custom', splitMode == 'custom',
                      () => setSheet(() => splitMode = 'custom')),
                ]),
                const SizedBox(height: 14),

                // People list
                const Text('People',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                ...people.asMap().entries.map((entry) {
                  final i = entry.key;
                  final p = entry.value;
                  return _PersonRow(
                    person:     p,
                    index:      i,
                    isDark:     isDark,
                    splitMode:  splitMode,
                    isYou:      i == 0,
                    onNameChange: (v) => setSheet(() => p.name = v),
                    onAmountChange: (v) {
                      setSheet(() {
                        p.amount = double.tryParse(v) ?? 0;
                      });
                    },
                    onRemove: i > 1
                        ? () => setSheet(() {
                            people.removeAt(i);
                            recalcEqual();
                          })
                        : null,
                  );
                }),

                // Add person button
                TextButton.icon(
                  onPressed: () => setSheet(() {
                    people.add(_PersonEntry(name: ''));
                    recalcEqual();
                  }),
                  icon: const Icon(Icons.person_add_rounded,
                      size: 16),
                  label: const Text('Add Person'),
                  style: TextButton.styleFrom(
                      foregroundColor: Colors.orange),
                ),
                const SizedBox(height: 4),

                // Balance check
                if (splitMode == 'custom' && total > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: balanced
                          ? Colors.green.withOpacity(0.08)
                          : Colors.orange.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(children: [
                      Icon(
                        balanced
                            ? Icons.check_circle_rounded
                            : Icons.warning_amber_rounded,
                        color: balanced
                            ? Colors.green : Colors.orange,
                        size: 16),
                      const SizedBox(width: 8),
                      Text(
                        balanced
                            ? 'Balanced ✅'
                            : '${diff > 0 ? "₹${diff.toStringAsFixed(0)} unassigned" : "₹${(-diff).toStringAsFixed(0)} over-assigned"}',
                        style: TextStyle(
                            fontSize: 12,
                            color: balanced
                                ? Colors.green : Colors.orange,
                            fontWeight: FontWeight.w600)),
                    ]),
                  ),
                const SizedBox(height: 20),

                // Save button
                SizedBox(
                  width: double.infinity, height: 50,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (descCtrl.text.trim().isEmpty ||
                          totalCtrl.text.isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text(
                                'Fill description and total')));
                        return;
                      }
                      final validPeople = people
                          .where((p) => p.name.trim().isNotEmpty)
                          .toList();
                      if (validPeople.length < 2) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text(
                                'Add at least 2 people')));
                        return;
                      }
                      final model = SplitExpenseModel(
                        id: existing?.id ?? '',
                        userId: '',
                        description: descCtrl.text.trim(),
                        totalAmount:
                            double.tryParse(totalCtrl.text) ?? 0,
                        splits: validPeople.map((p) =>
                            SplitPerson(
                              name:   p.name.trim(),
                              amount: p.amount,
                              isPaid: p.isPaid,
                            )).toList(),
                        date:     date,
                        category: category,
                        isSettled: existing?.isSettled ?? false,
                        createdAt: existing?.createdAt
                            ?? DateTime.now(),
                      );
                      if (existing == null) {
                        await svc.addSplitExpense(model);
                      } else {
                        await svc.updateSplitExpense(
                            existing.id, model);
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      existing == null ? 'Create Split' : 'Save Changes',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15)),
                  ),
                ),
              ],
            )),
          ),
        );
      }),
    );
  }

  static Widget _modeChip(
      String label, bool sel, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: sel
                ? Colors.orange : Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(label,
              style: TextStyle(
                  color: sel ? Colors.white : Colors.grey,
                  fontSize: 12,
                  fontWeight: sel
                      ? FontWeight.bold : FontWeight.normal)),
        ),
      );

  static Widget _tf(
    TextEditingController ctrl, String label, bool isDark, {
    bool num = false,
    TextCapitalization cap = TextCapitalization.none,
    ValueChanged<String>? onChanged,
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
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: isDark
              ? Colors.white.withOpacity(0.05)
              : Colors.grey.shade50,
          labelStyle: const TextStyle(fontSize: 12),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 14),
        ),
        style: const TextStyle(fontSize: 13),
      );

  static Future<void> _confirmDelete(BuildContext ctx,
      SplitExpenseModel e, SplitExpenseService svc) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Split'),
        content: Text('Delete "${e.description}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) await svc.deleteSplitExpense(e.id);
  }
}

// ── Mutable person entry used in sheet ───────────────────────────────────────
class _PersonEntry {
  String name;
  double amount;
  bool   isPaid;
  _PersonEntry(
      {required this.name, this.amount = 0, this.isPaid = false});
}

// ── Person row in add/edit sheet ──────────────────────────────────────────────
class _PersonRow extends StatelessWidget {
  final _PersonEntry         person;
  final int                  index;
  final bool                 isDark, isYou;
  final String               splitMode;
  final ValueChanged<String> onNameChange;
  final ValueChanged<String> onAmountChange;
  final VoidCallback?        onRemove;

  const _PersonRow({
    required this.person,       required this.index,
    required this.isDark,       required this.isYou,
    required this.splitMode,    required this.onNameChange,
    required this.onAmountChange, this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final nameCtrl = TextEditingController(text: person.name);
    final amtCtrl  = TextEditingController(
        text: person.amount > 0
            ? person.amount.toStringAsFixed(0) : '');
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        // Avatar / number
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: isYou
                ? Colors.orange.withOpacity(0.15)
                : Colors.grey.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Center(child: Text(
            isYou ? '👤' : '${index + 1}',
            style: TextStyle(
                fontSize: isYou ? 14 : 12,
                fontWeight: FontWeight.bold,
                color: isYou ? Colors.orange : Colors.grey),
          )),
        ),
        const SizedBox(width: 8),
        // Name field
        Expanded(child: TextField(
          controller: nameCtrl,
          textCapitalization: TextCapitalization.words,
          readOnly: isYou,
          onChanged: onNameChange,
          decoration: InputDecoration(
            hintText: isYou ? 'You' : 'Person ${index + 1} name',
            hintStyle: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white38 : Colors.black26),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10)),
            filled: true,
            fillColor: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.grey.shade50,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 10),
            isDense: true,
          ),
          style: const TextStyle(fontSize: 12),
        )),
        const SizedBox(width: 8),
        // Amount field (only editable in custom mode)
        SizedBox(width: 80, child: TextField(
          controller: amtCtrl,
          readOnly: splitMode == 'equal',
          keyboardType: const TextInputType.numberWithOptions(
              decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
          ],
          onChanged: onAmountChange,
          decoration: InputDecoration(
            prefixText: '₹',
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10)),
            filled: true,
            fillColor: splitMode == 'equal'
                ? (isDark
                    ? Colors.white.withOpacity(0.03)
                    : Colors.grey.shade100)
                : (isDark
                    ? Colors.white.withOpacity(0.07)
                    : Colors.white),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 10),
            isDense: true,
          ),
          style: const TextStyle(fontSize: 12),
        )),
        const SizedBox(width: 4),
        // Remove button
        if (onRemove != null)
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.remove_circle_rounded,
                color: Colors.red, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          )
        else
          const SizedBox(width: 22),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Settlement dashboard
// ════════════════════════════════════════════════════════════════════════════
class _SettlementDashboard extends StatelessWidget {
  final double owedToMe, iOwe;
  final bool   isDark;
  const _SettlementDashboard(
      {required this.owedToMe,
       required this.iOwe,
       required this.isDark});

  @override
  Widget build(BuildContext context) {
    final net = owedToMe - iOwe;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: net >= 0
              ? [const Color(0xFF43e97b), const Color(0xFF38f9d7)]
              : [const Color(0xFFfa709a), const Color(0xFFfee140)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(
          color: (net >= 0
              ? const Color(0xFF43e97b)
              : const Color(0xFFfa709a)).withOpacity(0.35),
          blurRadius: 18, offset: const Offset(0, 8),
        )],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        Row(children: [
          const Text('👥', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text(net >= 0 ? 'Others owe you' : 'You owe others',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12)),
            Text(_f(net.abs()),
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 26)),
          ]),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: _dashStat(
              '💚 Owed to Me', owedToMe, Colors.white)),
          Container(width: 1, height: 36,
              color: Colors.white.withOpacity(0.3)),
          Expanded(child: _dashStat(
              '🔴 I Owe', iOwe, Colors.white, right: true)),
        ]),
      ]),
    );
  }

  Widget _dashStat(String label, double val, Color col,
      {bool right = false}) =>
      Padding(
        padding: EdgeInsets.only(
            left: right ? 16 : 0, right: right ? 0 : 16),
        child: Column(
            crossAxisAlignment: right
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
          Text(label,
              style: TextStyle(
                  color: col.withOpacity(0.75),
                  fontSize: 10)),
          const SizedBox(height: 2),
          Text(_f(val),
              style: TextStyle(
                  color: col,
                  fontWeight: FontWeight.bold,
                  fontSize: 15)),
        ]),
      );
}

// ════════════════════════════════════════════════════════════════════════════
// Split card
// ════════════════════════════════════════════════════════════════════════════
class _SplitCard extends StatelessWidget {
  final SplitExpenseModel expense;
  final SplitExpenseService svc;
  final bool isDark, settled;
  final VoidCallback onEdit, onDelete;

  const _SplitCard({
    required this.expense, required this.svc,
    required this.isDark,  this.settled = false,
    required this.onEdit,  required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg   = isDark ? const Color(0xFF1E2530) : Colors.white;
    final paidCt   = expense.splits.where((s) => s.isPaid).length;
    final total    = expense.splits.length;
    final pct      = total > 0 ? paidCt / total : 0.0;
    final catEmoji = (_categories.firstWhere(
            (c) => c.$2 == expense.category,
            orElse: () => ('📦', 'Other')))
        .$1;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: settled ? cardBg.withOpacity(0.7) : cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: settled
                    ? Colors.green.withOpacity(0.1)
                    : Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(child: Text(
                settled ? '✅' : catEmoji,
                style: const TextStyle(fontSize: 20))),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(expense.description,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
                Row(children: [
                  Text(
                    DateFormat('d MMM y').format(expense.date),
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500])),
                  if (expense.category != null) ...[
                    Text('  ·  ', style: TextStyle(
                        color: Colors.grey[400])),
                    Text(expense.category!,
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500])),
                  ],
                ]),
              ],
            )),
            Column(crossAxisAlignment: CrossAxisAlignment.end,
                children: [
              Text(_f(expense.totalAmount),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.orange)),
              if (settled)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('SETTLED',
                      style: TextStyle(
                          fontSize: 9, color: Colors.green,
                          fontWeight: FontWeight.bold)),
                ),
            ]),
            const SizedBox(width: 4),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert,
                  size: 18,
                  color: isDark
                      ? Colors.white38 : Colors.grey[400]),
              onSelected: (v) {
                if (v == 'edit')   onEdit();
                if (v == 'delete') onDelete();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit',
                    child: Text('Edit')),
                const PopupMenuItem(value: 'delete',
                    child: Text('Delete',
                        style: TextStyle(color: Colors.red))),
              ],
            ),
          ]),
        ),

        // Progress bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct, minHeight: 5,
              backgroundColor: Colors.grey.withOpacity(0.12),
              valueColor: AlwaysStoppedAnimation(
                  pct >= 1.0 ? Colors.green : Colors.orange),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 6),
          child: Row(children: [
            Text('$paidCt of $total paid',
                style: TextStyle(
                    fontSize: 11,
                    color: pct >= 1.0
                        ? Colors.green : Colors.orange,
                    fontWeight: FontWeight.w600)),
            const Spacer(),
            Text(
              'Per person: ${_f(expense.totalAmount / total)}',
              style: TextStyle(
                  fontSize: 11, color: Colors.grey[500])),
          ]),
        ),

        // People list
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            children: expense.splits.asMap().entries.map((entry) {
              final i = entry.key;
              final s = entry.value;
              return _PersonTile(
                person:  s,
                index:   i,
                isDark:  isDark,
                settled: settled,
                onMarkPaid: (!settled && !s.isPaid)
                    ? () async {
                        HapticFeedback.lightImpact();
                        await svc.markPersonPaid(expense.id, i);
                      }
                    : null,
              );
            }).toList(),
          ),
        ),
      ]),
    );
  }
}

// ── Person tile inside card ───────────────────────────────────────────────────
class _PersonTile extends StatelessWidget {
  final SplitPerson  person;
  final int          index;
  final bool         isDark, settled;
  final VoidCallback? onMarkPaid;

  const _PersonTile({
    required this.person,   required this.index,
    required this.isDark,   required this.settled,
    this.onMarkPaid,
  });

  @override
  Widget build(BuildContext context) {
    final isYou  = index == 0;
    final isPaid = person.isPaid;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            color: isPaid
                ? Colors.green.withOpacity(0.1)
                : (isYou
                    ? Colors.orange.withOpacity(0.1)
                    : Colors.grey.withOpacity(0.1)),
            shape: BoxShape.circle,
          ),
          child: Center(child: Text(
            isPaid ? '✅' : (isYou ? '👤' : '👤'),
            style: const TextStyle(fontSize: 12))),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(
          isYou ? 'You (${person.name})' : person.name,
          style: TextStyle(
              fontSize: 12,
              color: isPaid
                  ? Colors.green
                  : (isDark ? Colors.white : Colors.black87),
              decoration: isPaid
                  ? TextDecoration.lineThrough : null),
        )),
        Text(_f(person.amount),
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: isPaid ? Colors.green : Colors.orange)),
        const SizedBox(width: 8),
        if (onMarkPaid != null)
          GestureDetector(
            onTap: onMarkPaid,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: Colors.green.withOpacity(0.4)),
              ),
              child: const Text('Mark Paid',
                  style: TextStyle(
                      fontSize: 10,
                      color: Colors.green,
                      fontWeight: FontWeight.bold)),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isPaid
                  ? Colors.green.withOpacity(0.1)
                  : Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(isPaid ? 'Paid' : 'Pending',
                style: TextStyle(
                    fontSize: 9,
                    color: isPaid ? Colors.green : Colors.grey,
                    fontWeight: FontWeight.bold)),
          ),
      ]),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center,
        children: [
      const Text('👥', style: TextStyle(fontSize: 64)),
      const SizedBox(height: 16),
      const Text('No Splits Yet',
          style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Text('Split bills with friends and track\nwho owes what',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[500])),
      const SizedBox(height: 24),
      ElevatedButton.icon(
        onPressed: onAdd,
        icon: const Icon(Icons.group_add_rounded),
        label: const Text('Split First Bill'),
        style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(
                horizontal: 24, vertical: 12)),
      ),
    ]),
  );
}

Widget _sectionHead(String t, bool isDark) =>
    Text(t, style: TextStyle(
        fontSize: 15, fontWeight: FontWeight.bold,
        color: isDark ? Colors.white : Colors.black87));