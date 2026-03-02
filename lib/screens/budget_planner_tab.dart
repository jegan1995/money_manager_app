// lib/screens/budget_planner_tab.dart
// Budget Planner — monthly + custom date range, rollover, alerts
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/budget_planner_model.dart';
import '../services/budget_planner_service.dart';

final _inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
String _f(double v) => _inr.format(v.abs());

// ── Category definitions ──────────────────────────────────────────────────────
const _categoryList = [
  ('Food & Dining',    '🍽️',  Color(0xFFf093fb)),
  ('Transport',        '🚗',  Color(0xFF4facfe)),
  ('Shopping',         '🛍️',  Color(0xFFfa709a)),
  ('Entertainment',    '🎬',  Color(0xFFffd89b)),
  ('Health',           '💊',  Color(0xFF43e97b)),
  ('Education',        '📚',  Color(0xFF667eea)),
  ('Bills & Utilities','💡',  Color(0xFFf9ca24)),
  ('Rent',             '🏠',  Color(0xFF56ab2f)),
  ('Groceries',        '🛒',  Color(0xFF96fbc4)),
  ('Travel',           '✈️',  Color(0xFF89f7fe)),
  ('Subscriptions',    '📱',  Color(0xFFa18cd1)),
  ('Personal Care',    '💅',  Color(0xFFfbc2eb)),
  ('Savings',          '💰',  Color(0xFF38f9d7)),
  ('Other',            '📦',  Color(0xFFb0bec5)),
];

String _emojiFor(String cat) {
  for (final c in _categoryList) {
    if (c.$1.toLowerCase() == cat.toLowerCase()) return c.$2;
  }
  return '📦';
}

Color _colorFor(String cat) {
  for (final c in _categoryList) {
    if (c.$1.toLowerCase() == cat.toLowerCase()) return c.$3;
  }
  return const Color(0xFFb0bec5);
}

// ════════════════════════════════════════════════════════════════════════════
class BudgetPlannerTab extends StatefulWidget {
  const BudgetPlannerTab({super.key});
  @override
  State<BudgetPlannerTab> createState() => _BudgetPlannerTabState();
}

class _BudgetPlannerTabState extends State<BudgetPlannerTab> {
  final _svc = BudgetPlannerService();

  // Viewing period
  int  _month = DateTime.now().month;
  int  _year  = DateTime.now().year;

  // Statuses loaded once per refresh
  bool               _loading  = false;
  List<BudgetStatus> _statuses = [];

  @override
  void initState() { super.initState(); }

  Future<void> _refresh(List<BudgetPlan> plans) async {
    if (_loading) return;
    setState(() => _loading = true);
    final statuses = await _svc.getAllStatuses(plans);
    // Sort: over > near > ok, then alphabetical
    statuses.sort((a, b) {
      if (a.isOver  && !b.isOver)  return -1;
      if (!a.isOver && b.isOver)   return  1;
      if (a.isNear  && !b.isNear)  return -1;
      if (!a.isNear && b.isNear)   return  1;
      return a.plan.category.compareTo(b.plan.category);
    });
    if (mounted) setState(() { _statuses = statuses; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final cardBg  = isDark ? const Color(0xFF1E2530) : Colors.white;
    final bg      = isDark ? const Color(0xFF0D1117) : const Color(0xFFF5F6FA);

    return StreamBuilder<List<BudgetPlan>>(
      stream: _svc.getPlansForMonth(_month, _year),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && _statuses.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        final plans = snap.data ?? [];

        // Trigger refresh whenever plans change
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _refresh(plans);
        });

        final totalBudget  = _statuses.fold(0.0, (s, st) => s + st.plan.effectiveAmount);
        final totalSpent   = _statuses.fold(0.0, (s, st) => s + st.spent);
        final totalRemain  = totalBudget - totalSpent;
        final overCount    = _statuses.where((s) => s.isOver).length;
        final nearCount    = _statuses.where((s) => s.isNear).length;

        return Container(
          color: bg,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [

              // ── Month navigator ──────────────────────────────────────────
              _MonthSelector(
                month: _month, year: _year,
                onPrev: () => setState(() {
                  if (_month == 1) { _month = 12; _year--; }
                  else { _month--; }
                  _statuses = [];
                }),
                onNext: () => setState(() {
                  if (_month == 12) { _month = 1; _year++; }
                  else { _month++; }
                  _statuses = [];
                }),
                isDark: isDark,
              ),
              const SizedBox(height: 16),

              // ── Overall summary card ─────────────────────────────────────
              if (_statuses.isNotEmpty)
                _SummaryCard(
                  totalBudget: totalBudget,
                  totalSpent:  totalSpent,
                  totalRemain: totalRemain,
                  overCount:   overCount,
                  nearCount:   nearCount,
                  isDark:      isDark,
                ),

              if (_statuses.isNotEmpty) const SizedBox(height: 20),

              // ── Alerts ───────────────────────────────────────────────────
              if (overCount > 0 || nearCount > 0) ...[
                _AlertsBanner(
                  statuses: _statuses,
                  isDark:   isDark,
                ),
                const SizedBox(height: 16),
              ],

              // ── Budget cards ─────────────────────────────────────────────
              if (_statuses.isEmpty && !_loading)
                _EmptyState(
                  onAdd: () => _showAddSheet(context, isDark),
                )
              else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Category Budgets',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87)),
                    TextButton.icon(
                      onPressed: () => _showAddSheet(context, isDark),
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text('Add'),
                      style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF667eea)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ..._statuses.map((st) => _BudgetCard(
                  status:   st,
                  isDark:   isDark,
                  cardBg:   cardBg,
                  onEdit:   () => _showEditSheet(context, st.plan, isDark),
                  onDelete: () => _confirmDelete(context, st.plan),
                  onRollover: st.plan.rollover && !st.isOver && st.remaining > 0
                      ? () => _doRollover(context, st)
                      : null,
                )),
              ],

              const SizedBox(height: 80),
            ],
          ),
        );
      },
    );
  }

  // ── Add / Edit sheet ──────────────────────────────────────────────────────
  void _showAddSheet(BuildContext ctx, bool isDark) =>
      _showSheet(ctx, null, isDark);

  void _showEditSheet(BuildContext ctx, BudgetPlan plan, bool isDark) =>
      _showSheet(ctx, plan, isDark);

  void _showSheet(BuildContext ctx, BudgetPlan? existing, bool isDark) {
    String   category  = existing?.category   ?? _categoryList[0].$1;
    String   emoji     = existing?.emoji      ?? _emojiFor(category);
    String   period    = existing?.period     ?? 'monthly';
    bool     rollover  = existing?.rollover   ?? false;
    DateTime startDate = existing?.startDate  ?? DateTime(_year, _month, 1);
    DateTime endDate   = existing?.endDate    ?? DateTime(_year, _month + 1, 0);

    final amtCtrl = TextEditingController(
        text: existing != null ? existing.amount.toStringAsFixed(0) : '');

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(builder: (ctx, setSheet) {
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
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // Handle
                Container(width: 40, height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2))),

                Text(existing == null ? 'New Budget' : 'Edit Budget',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),

                // Category picker
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: _categoryList.map((cat) {
                      final sel = category == cat.$1;
                      return GestureDetector(
                        onTap: () => setSheet(() {
                          category = cat.$1;
                          emoji    = cat.$2;
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: sel
                                ? cat.$3.withOpacity(0.18)
                                : Colors.grey.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: sel ? cat.$3 : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Text('${cat.$2} ${cat.$1}',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: sel ? cat.$3 : Colors.grey,
                                  fontWeight: sel
                                      ? FontWeight.bold
                                      : FontWeight.normal)),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),

                // Amount
                TextField(
                  controller: amtCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                  ],
                  decoration: InputDecoration(
                    labelText: 'Budget Amount',
                    prefixText: '₹ ',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: isDark
                        ? Colors.white.withOpacity(0.05)
                        : Colors.grey.shade50,
                  ),
                ),
                const SizedBox(height: 14),

                // Period type
                Row(children: [
                  Expanded(child: _chip('📅 Monthly', period == 'monthly',
                      const Color(0xFF667eea),
                      () => setSheet(() => period = 'monthly'))),
                  const SizedBox(width: 10),
                  Expanded(child: _chip('📆 Custom Range', period == 'custom',
                      Colors.teal,
                      () => setSheet(() => period = 'custom'))),
                ]),
                const SizedBox(height: 14),

                // Custom date range
                if (period == 'custom') ...[
                  Row(children: [
                    Expanded(child: _DatePickerTile(
                      label: 'From',
                      date:  startDate,
                      isDark: isDark,
                      onPick: (d) => setSheet(() => startDate = d),
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: _DatePickerTile(
                      label: 'To',
                      date:  endDate,
                      isDark: isDark,
                      onPick: (d) => setSheet(() => endDate = d),
                    )),
                  ]),
                  const SizedBox(height: 14),
                ],

                // Rollover toggle
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: rollover
                        ? Colors.green.withOpacity(0.08)
                        : Colors.grey.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: rollover
                          ? Colors.green.withOpacity(0.4)
                          : Colors.transparent,
                    ),
                  ),
                  child: Row(children: [
                    const Text('🔄', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 10),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Rollover unused budget',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13)),
                        Text(
                          rollover
                              ? 'Unspent amount carries to next month'
                              : 'Unused amount expires each month',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey[500])),
                      ],
                    )),
                    Switch(
                      value: rollover,
                      activeColor: Colors.green,
                      onChanged: (v) => setSheet(() => rollover = v),
                    ),
                  ]),
                ),
                const SizedBox(height: 20),

                // Save
                SizedBox(
                  width: double.infinity, height: 50,
                  child: ElevatedButton(
                    onPressed: () async {
                      final amt = double.tryParse(amtCtrl.text);
                      if (amt == null || amt <= 0) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                              content: Text('Enter a valid budget amount')));
                        return;
                      }
                      final plan = BudgetPlan(
                        id:        existing?.id,
                        userId:    '',
                        category:  category,
                        amount:    amt,
                        period:    period,
                        month:     _month,
                        year:      _year,
                        startDate: period == 'custom' ? startDate : null,
                        endDate:   period == 'custom' ? endDate   : null,
                        rollover:  rollover,
                        rolloverAmount: existing?.rolloverAmount ?? 0,
                        emoji:     emoji,
                      );
                      if (existing == null) {
                        await _svc.addPlan(plan);
                      } else {
                        await _svc.updatePlan(plan.copyWith(
                            id: existing.id));
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF667eea),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      existing == null ? 'Create Budget' : 'Save Changes',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        );
      }),
    );
  }

  Widget _chip(String label, bool sel, Color color, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: sel ? color.withOpacity(0.12) : Colors.grey.withOpacity(0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: sel ? color : Colors.transparent, width: 2),
          ),
          child: Center(child: Text(label,
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 12,
                  color: sel ? color : Colors.grey))),
        ),
      );

  Future<void> _confirmDelete(BuildContext ctx, BudgetPlan plan) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Budget'),
        content: Text(
            'Delete "${plan.category}" budget of ${_f(plan.amount)}?'),
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
    if (ok == true && plan.id != null) await _svc.deletePlan(plan.id!);
  }

  Future<void> _doRollover(BuildContext ctx, BudgetStatus st) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Rollover Budget'),
        content: Text(
          'Carry ${_f(st.remaining)} unused from '
          '"${st.plan.category}" to next month?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Rollover')),
        ],
      ),
    );
    if (ok == true) {
      await _svc.rolloverToNextMonth(st);
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
          content: Text(
              '${_f(st.remaining)} rolled over to next month ✅'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }
}

// ════════════════════════════════════════════════════════════════════════════
// WIDGETS
// ════════════════════════════════════════════════════════════════════════════

class _MonthSelector extends StatelessWidget {
  final int month, year;
  final VoidCallback onPrev, onNext;
  final bool isDark;

  const _MonthSelector({
    required this.month, required this.year,
    required this.onPrev, required this.onNext,
    required this.isDark,
  });

  static const _months = [
    'January','February','March','April','May','June',
    'July','August','September','October','November','December'
  ];

  @override
  Widget build(BuildContext context) {
    final now       = DateTime.now();
    final isCurrent = month == now.month && year == now.year;

    return Row(children: [
      IconButton(
        onPressed: onPrev,
        icon: const Icon(Icons.chevron_left_rounded),
        style: IconButton.styleFrom(
            backgroundColor: isDark
                ? Colors.white.withOpacity(0.06)
                : Colors.grey.shade100),
      ),
      Expanded(child: Column(children: [
        Text('${_months[month - 1]} $year',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 16)),
        if (isCurrent)
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF667eea).withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text('Current Month',
                style: TextStyle(
                    fontSize: 10, color: Color(0xFF667eea),
                    fontWeight: FontWeight.bold)),
          ),
      ])),
      IconButton(
        onPressed: onNext,
        icon: const Icon(Icons.chevron_right_rounded),
        style: IconButton.styleFrom(
            backgroundColor: isDark
                ? Colors.white.withOpacity(0.06)
                : Colors.grey.shade100),
      ),
    ]);
  }
}

// ── Summary card ──────────────────────────────────────────────────────────────
class _SummaryCard extends StatelessWidget {
  final double totalBudget, totalSpent, totalRemain;
  final int overCount, nearCount;
  final bool isDark;

  const _SummaryCard({
    required this.totalBudget,  required this.totalSpent,
    required this.totalRemain,  required this.overCount,
    required this.nearCount,    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final pct      = totalBudget > 0
        ? (totalSpent / totalBudget).clamp(0.0, 1.0) : 0.0;
    final isOver   = totalSpent > totalBudget;
    final barColor = isOver
        ? Colors.red : (pct > 0.8 ? Colors.orange : Colors.green);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isOver
              ? [Colors.red.shade700, Colors.red.shade500]
              : [const Color(0xFF667eea), const Color(0xFF764ba2)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(
          color: (isOver
              ? Colors.red : const Color(0xFF667eea)).withOpacity(0.35),
          blurRadius: 18, offset: const Offset(0, 8),
        )],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        Row(children: [
          const Text('📊', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          const Text('Overall Budget',
              style: TextStyle(color: Colors.white70, fontSize: 13)),
          const Spacer(),
          if (overCount > 0)
            _badge('$overCount over', Colors.red.shade300),
          if (nearCount > 0) ...[
            const SizedBox(width: 6),
            _badge('$nearCount near limit', Colors.orange.shade300),
          ],
        ]),
        const SizedBox(height: 12),

        // Spent / Budget
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(_f(totalSpent),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(width: 6),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('/ ${_f(totalBudget)}',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.65),
                      fontSize: 14)),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text('${(pct * 100).toStringAsFixed(0)}% used',
            style: TextStyle(
                color: Colors.white.withOpacity(0.7), fontSize: 12)),

        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: pct, minHeight: 8,
            backgroundColor: Colors.white.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation(
                isOver ? Colors.red.shade300 : Colors.white),
          ),
        ),
        const SizedBox(height: 12),
        Row(children: [
          _statChip('Spent',     _f(totalSpent),  Colors.white70),
          const Spacer(),
          _statChip('Remaining', _f(totalRemain),
              totalRemain >= 0 ? Colors.greenAccent : Colors.redAccent),
        ]),
      ]),
    );
  }

  Widget _badge(String t, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: c.withOpacity(0.25),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(t, style: TextStyle(
        color: c, fontSize: 10, fontWeight: FontWeight.bold)),
  );

  Widget _statChip(String label, String val, Color col) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(val, style: TextStyle(
            color: col, fontWeight: FontWeight.bold, fontSize: 14)),
        Text(label, style: TextStyle(
            color: Colors.white.withOpacity(0.6), fontSize: 10)),
      ]);
}

// ── Alerts banner ─────────────────────────────────────────────────────────────
class _AlertsBanner extends StatelessWidget {
  final List<BudgetStatus> statuses;
  final bool isDark;

  const _AlertsBanner({required this.statuses, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final over = statuses.where((s) => s.isOver).toList();
    final near = statuses.where((s) => s.isNear).toList();

    return Column(children: [
      ...over.map((s) => _alertTile(
        icon: '🚨',
        color: Colors.red,
        title: '${s.plan.category} — Over Budget!',
        sub: 'Spent ${_f(s.spent)} of ${_f(s.plan.effectiveAmount)} '
            '(${(s.pct * 100).toStringAsFixed(0)}%)',
        isDark: isDark,
      )),
      ...near.map((s) => _alertTile(
        icon: '⚠️',
        color: Colors.orange,
        title: '${s.plan.category} — Near Limit',
        sub: '${_f(s.remaining)} remaining '
            '(${(s.pct * 100).toStringAsFixed(0)}% used)',
        isDark: isDark,
      )),
    ]);
  }

  Widget _alertTile({
    required String icon,  required Color color,
    required String title, required String sub,
    required bool isDark,
  }) =>
      Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(children: [
          Text(icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 13, color: color)),
              Text(sub, style: TextStyle(
                  fontSize: 11, color: Colors.grey[500])),
            ],
          )),
        ]),
      );
}

// ── Individual budget card ────────────────────────────────────────────────────
class _BudgetCard extends StatelessWidget {
  final BudgetStatus  status;
  final bool          isDark;
  final Color         cardBg;
  final VoidCallback  onEdit;
  final VoidCallback  onDelete;
  final VoidCallback? onRollover;

  const _BudgetCard({
    required this.status,    required this.isDark,
    required this.cardBg,   required this.onEdit,
    required this.onDelete,  this.onRollover,
  });

  @override
  Widget build(BuildContext context) {
    final st       = status;
    final cat      = st.plan.category;
    final catColor = _colorFor(cat);
    final emoji    = st.plan.emoji ?? _emojiFor(cat);
    final pct      = st.pct.clamp(0.0, 1.0);
    final hasRoll  = st.plan.rolloverAmount > 0;

    return Dismissible(
      key: Key(st.plan.id ?? cat),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline,
            color: Colors.white, size: 22),
      ),
      confirmDismiss: (_) async {
        HapticFeedback.mediumImpact();
        onDelete();
        return false;
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: st.isOver
              ? Border.all(color: Colors.red.withOpacity(0.4), width: 1.5)
              : st.isNear
                  ? Border.all(
                      color: Colors.orange.withOpacity(0.4), width: 1.5)
                  : null,
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          // Header row
          Row(children: [
            // Category icon
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: catColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(child: Text(emoji,
                  style: const TextStyle(fontSize: 18))),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(cat, style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(width: 6),
                  if (st.isOver)
                    _tag('OVER', Colors.red)
                  else if (st.isNear)
                    _tag('NEAR', Colors.orange),
                ]),
                Text(st.plan.displayPeriod,
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey[500])),
              ],
            )),
            // Edit button
            IconButton(
              onPressed: onEdit,
              icon: Icon(Icons.edit_outlined,
                  size: 18,
                  color: isDark ? Colors.white38 : Colors.grey[400]),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                  minWidth: 32, minHeight: 32),
            ),
          ]),
          const SizedBox(height: 14),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct, minHeight: 8,
              backgroundColor: Colors.grey.withOpacity(0.12),
              valueColor: AlwaysStoppedAnimation(st.statusColor),
            ),
          ),
          const SizedBox(height: 10),

          // Spent / Budget / Remaining
          Row(children: [
            _amtChip('Spent',    st.spent,     st.statusColor),
            const Spacer(),
            _amtChip('Budget',   st.plan.effectiveAmount, Colors.grey),
            const Spacer(),
            _amtChip('Left',     st.remaining,
                st.remaining >= 0 ? Colors.green : Colors.red,
                prefix: st.remaining < 0 ? '-' : ''),
          ]),

          // Rollover info
          if (hasRoll) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                const Text('🔄', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 4),
                Text(
                  'Includes ${_f(st.plan.rolloverAmount)} rolled over',
                  style: const TextStyle(
                      fontSize: 11, color: Colors.green),
                ),
              ]),
            ),
          ],

          // Rollover button
          if (onRollover != null) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: onRollover,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: Colors.teal.withOpacity(0.3)),
                ),
                child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                  const Icon(Icons.arrow_forward_rounded,
                      size: 14, color: Colors.teal),
                  const SizedBox(width: 4),
                  Text(
                    'Carry ${_f(st.remaining)} to next month',
                    style: const TextStyle(
                        fontSize: 11, color: Colors.teal,
                        fontWeight: FontWeight.w600),
                  ),
                ]),
              ),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _tag(String t, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: c.withOpacity(0.15),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(t,
        style: TextStyle(
            fontSize: 9, color: c, fontWeight: FontWeight.bold)),
  );

  Widget _amtChip(String label, double val, Color col,
      {String prefix = ''}) =>
      Column(children: [
        Text('$prefix${_f(val)}',
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 13, color: col)),
        Text(label, style: TextStyle(
            fontSize: 10, color: Colors.grey[500])),
      ]);
}

// ── Date picker tile ──────────────────────────────────────────────────────────
class _DatePickerTile extends StatelessWidget {
  final String label;
  final DateTime date;
  final bool isDark;
  final ValueChanged<DateTime> onPick;

  const _DatePickerTile({
    required this.label, required this.date,
    required this.isDark, required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        if (d != null) onPick(d);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withOpacity(0.05)
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.12)
                  : Colors.grey.shade300),
        ),
        child: Row(children: [
          Icon(Icons.calendar_today_rounded,
              size: 14,
              color: isDark ? Colors.white54 : Colors.grey[500]),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: TextStyle(
                    fontSize: 10, color: Colors.grey[500])),
            Text(DateFormat('d MMM y').format(date),
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 12)),
          ]),
        ]),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(children: [
        const Text('📊', style: TextStyle(fontSize: 56)),
        const SizedBox(height: 16),
        const Text('No Budgets Yet',
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('Set category budgets to\ntrack where your money goes',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500])),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Create First Budget'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF667eea),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(
                horizontal: 24, vertical: 12),
          ),
        ),
      ]),
    );
  }
}