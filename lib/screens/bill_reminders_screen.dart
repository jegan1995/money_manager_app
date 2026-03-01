// lib/screens/bill_reminders_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/bill_model.dart';
import '../services/bill_service.dart';

class BillRemindersScreen extends StatefulWidget {
  const BillRemindersScreen({super.key});
  @override
  State<BillRemindersScreen> createState() => _BillRemindersScreenState();
}

class _BillRemindersScreenState extends State<BillRemindersScreen> {
  final _svc = BillService();

  static const _catIcons = {
    'electricity': '⚡', 'water': '💧', 'rent': '🏠',
    'phone':  '📱', 'internet': '📶', 'insurance': '🛡️',
    'gas':    '🔥', 'emi': '🏦', 'credit_card': '💳', 'other': '📋',
  };

  static const _catColors = {
    'electricity': Color(0xFFF59E0B),
    'water':       Color(0xFF3B82F6),
    'rent':        Color(0xFF8B5CF6),
    'phone':       Color(0xFF10B981),
    'internet':    Color(0xFF06B6D4),
    'insurance':   Color(0xFFEF4444),
    'gas':         Color(0xFFF97316),
    'emi':         Color(0xFF6366F1),
    'credit_card': Color(0xFFEC4899),
    'other':       Color(0xFF667eea),
  };

  Color _color(String cat) => _catColors[cat] ?? const Color(0xFF667eea);
  String _icon(String cat)  => _catIcons[cat]  ?? '📋';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg     = isDark ? const Color(0xFF0D1117) : const Color(0xFFF0F4FF);
    final card   = isDark ? const Color(0xFF1E2530) : Colors.white;

    return Scaffold(
      backgroundColor: bg,
      body: StreamBuilder<List<BillModel>>(
        stream: _svc.getBills(),
        builder: (ctx, snap) {
          final bills    = snap.data ?? [];
          final overdue  = bills.where((b) => b.isOverdue && !b.isPaid).toList();
          final dueSoon  = bills.where((b) => b.isDueSoon && !b.isOverdue).toList();
          final upcoming = bills.where((b) => !b.isDueSoon && !b.isOverdue && !b.isPaid).toList();
          final paid     = bills.where((b) => b.isPaid).toList();

          // Stats
          final totalPending = bills.where((b) => !b.isPaid)
              .fold(0.0, (s, b) => s + b.amount);
          final totalPaid = paid.fold(0.0, (s, b) => s + b.amount);
          final overdueCount = overdue.length;

          return CustomScrollView(
            slivers: [
              // ── App bar ──────────────────────────────────────────────
              SliverAppBar(
                pinned: true,
                expandedHeight: 160,
                backgroundColor: const Color(0xFF1A237E),
                foregroundColor: Colors.white,
                title: const Text('Bill Reminders',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () => _showAddSheet(context, card, isDark),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF1A237E), Color(0xFF3949AB)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 56, 20, 16),
                        child: Row(children: [
                          _headerStat('Pending',
                              '₹${totalPending.toStringAsFixed(0)}',
                              Icons.pending_actions, Colors.orange),
                          _vDivider(),
                          _headerStat('Paid This Month',
                              '₹${totalPaid.toStringAsFixed(0)}',
                              Icons.check_circle_outline, Colors.green),
                          _vDivider(),
                          _headerStat('Overdue',
                              '$overdueCount',
                              Icons.warning_amber_outlined,
                              overdueCount > 0 ? Colors.red : Colors.green),
                        ]),
                      ),
                    ),
                  ),
                ),
              ),

              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                sliver: SliverList(delegate: SliverChildListDelegate([
                  // OVERDUE
                  if (overdue.isNotEmpty) ...[
                    _sectionHeader('🔴  Overdue', Colors.red),
                    const SizedBox(height: 8),
                    ...overdue.map((b) => _billCard(b, card, isDark, ctx)),
                    const SizedBox(height: 16),
                  ],

                  // DUE SOON
                  if (dueSoon.isNotEmpty) ...[
                    _sectionHeader('⚠️  Due Soon', Colors.orange),
                    const SizedBox(height: 8),
                    ...dueSoon.map((b) => _billCard(b, card, isDark, ctx)),
                    const SizedBox(height: 16),
                  ],

                  // UPCOMING
                  if (upcoming.isNotEmpty) ...[
                    _sectionHeader('📅  Upcoming', const Color(0xFF1A237E)),
                    const SizedBox(height: 8),
                    ...upcoming.map((b) => _billCard(b, card, isDark, ctx)),
                    const SizedBox(height: 16),
                  ],

                  // PAID
                  if (paid.isNotEmpty) ...[
                    _sectionHeader('✅  Paid', Colors.green),
                    const SizedBox(height: 8),
                    ...paid.map((b) => _billCard(b, card, isDark, ctx)),
                    const SizedBox(height: 16),
                  ],

                  // EMPTY
                  if (bills.isEmpty)
                    SizedBox(
                      height: 300,
                      child: Center(child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('📋', style: TextStyle(fontSize: 48)),
                          const SizedBox(height: 12),
                          const Text('No bills added yet',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 6),
                          Text('Add electricity, rent, phone bills',
                              style: TextStyle(
                                  color: Colors.grey[400], fontSize: 13)),
                        ],
                      )),
                    ),
                ])),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSheet(context,
            isDark ? const Color(0xFF1E2530) : Colors.white, isDark),
        icon: const Icon(Icons.add),
        label: const Text('Add Bill'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _headerStat(String label, String value,
      IconData icon, Color color) =>
      Expanded(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold, fontSize: 14)),
          Text(label, style: TextStyle(
              color: Colors.white.withOpacity(0.7), fontSize: 10),
              textAlign: TextAlign.center),
        ],
      ));

  Widget _vDivider() => Container(
      width: 1, height: 40,
      color: Colors.white.withOpacity(0.2));

  Widget _sectionHeader(String title, Color color) => Text(
    title.toUpperCase(),
    style: TextStyle(
        fontSize: 11, fontWeight: FontWeight.bold,
        color: color, letterSpacing: 1.0),
  );

  Widget _billCard(BillModel b, Color card, bool isDark,
      BuildContext ctx) {
    final color    = _color(b.category);
    final daysLeft = b.daysUntilDue;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: b.isOverdue && !b.isPaid
              ? Colors.red.withOpacity(0.3)
              : b.isDueSoon
                  ? Colors.orange.withOpacity(0.3)
                  : Colors.transparent,
        ),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.05), blurRadius: 8)],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showDetailSheet(ctx, b, card, isDark),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            // Category icon
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                color: b.isPaid
                    ? Colors.green.withOpacity(0.1)
                    : color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Center(child: Text(
                b.isPaid ? '✅' : _icon(b.category),
                style: const TextStyle(fontSize: 20))),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(b.name, style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 3),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(b.frequency,
                        style: TextStyle(
                            fontSize: 9, color: color,
                            fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  if (!b.isPaid) Text(
                    b.isOverdue
                        ? 'Overdue by ${-daysLeft}d'
                        : daysLeft == 0 ? 'Due today!'
                        : 'Due ${DateFormat('d MMM').format(b.nextDueDate)}',
                    style: TextStyle(
                        fontSize: 11,
                        color: b.isOverdue ? Colors.red
                            : b.isDueSoon ? Colors.orange
                            : Colors.grey[400]),
                  ),
                  if (b.isPaid) Text(
                    'Paid ${b.paidDate != null ? DateFormat('d MMM').format(b.paidDate!) : ''}',
                    style: const TextStyle(
                        fontSize: 11, color: Colors.green),
                  ),
                ]),
              ],
            )),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('₹${b.amount.toStringAsFixed(0)}',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: b.isPaid ? Colors.green : color)),
              const SizedBox(height: 4),
              if (!b.isPaid)
                GestureDetector(
                  onTap: () async {
                    HapticFeedback.mediumImpact();
                    await _svc.markPaid(b.id!);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('Mark Paid',
                        style: TextStyle(
                            fontSize: 10, color: Colors.green,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
              if (b.isPaid)
                GestureDetector(
                  onTap: () async => await _svc.markUnpaid(b.id!),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('Undo',
                        style: TextStyle(
                            fontSize: 10, color: Colors.grey,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
            ]),
          ]),
        ),
      ),
    );
  }

  void _showDetailSheet(BuildContext ctx, BillModel b,
      Color card, bool isDark) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Text(_icon(b.category), style: const TextStyle(fontSize: 40)),
          const SizedBox(height: 8),
          Text(b.name, style: const TextStyle(
              fontWeight: FontWeight.bold, fontSize: 20)),
          Text('₹${b.amount.toStringAsFixed(0)} · ${b.frequency}',
              style: TextStyle(color: Colors.grey[400])),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _statChip('Due Day', '${b.dueDayOfMonth}th'),
            _statChip('Next Due', DateFormat('d MMM').format(b.nextDueDate)),
            _statChip('Status', b.isPaid ? 'Paid' : b.isOverdue
                ? 'Overdue' : 'Pending'),
          ]),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _showAddSheet(ctx, card, isDark, b);
              },
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('Edit'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1A237E),
                side: const BorderSide(color: Color(0xFF1A237E)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            )),
            const SizedBox(width: 10),
            Expanded(child: ElevatedButton.icon(
              onPressed: () async {
                if (b.isPaid) {
                  await _svc.markUnpaid(b.id!);
                } else {
                  await _svc.markPaid(b.id!);
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              icon: Icon(b.isPaid
                  ? Icons.undo : Icons.check_circle_outline, size: 16),
              label: Text(b.isPaid ? 'Mark Unpaid' : 'Mark Paid'),
              style: ElevatedButton.styleFrom(
                backgroundColor: b.isPaid ? Colors.grey : Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            )),
            const SizedBox(width: 10),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () async {
                Navigator.pop(ctx);
                await _svc.delete(b.id!);
              },
            ),
          ]),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }

  Widget _statChip(String label, String value) => Column(children: [
    Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[400])),
    const SizedBox(height: 4),
    Text(value, style: const TextStyle(
        fontWeight: FontWeight.bold, fontSize: 14)),
  ]);

  void _showAddSheet(BuildContext ctx, Color card, bool isDark,
      [BillModel? existing]) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddBillSheet(
        svc: _svc, existing: existing, card: card, isDark: isDark,
      ),
    );
  }
}

// ── Add/Edit Bill Sheet ───────────────────────────────────────────────────────
class _AddBillSheet extends StatefulWidget {
  final BillService svc;
  final BillModel? existing;
  final Color card;
  final bool isDark;
  const _AddBillSheet(
      {required this.svc, this.existing,
       required this.card, required this.isDark});
  @override
  State<_AddBillSheet> createState() => _AddBillSheetState();
}

class _AddBillSheetState extends State<_AddBillSheet> {
  final _nameCtrl   = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _noteCtrl   = TextEditingController();

  String _category = 'electricity';
  String _frequency = 'monthly';
  int    _dueDayOfMonth = 1;
  bool   _remindMe = true;
  int    _remindDays = 3;
  bool   _loading  = false;

  static const _categories = [
    {'key':'electricity','label':'Electricity','emoji':'⚡'},
    {'key':'water',      'label':'Water',      'emoji':'💧'},
    {'key':'rent',       'label':'Rent',       'emoji':'🏠'},
    {'key':'phone',      'label':'Phone',      'emoji':'📱'},
    {'key':'internet',   'label':'Internet',   'emoji':'📶'},
    {'key':'insurance',  'label':'Insurance',  'emoji':'🛡️'},
    {'key':'gas',        'label':'Gas',        'emoji':'🔥'},
    {'key':'emi',        'label':'EMI',        'emoji':'🏦'},
    {'key':'credit_card','label':'Credit Card','emoji':'💳'},
    {'key':'other',      'label':'Other',      'emoji':'📋'},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      final e = widget.existing!;
      _nameCtrl.text   = e.name;
      _amountCtrl.text = e.amount.toStringAsFixed(0);
      _noteCtrl.text   = e.note ?? '';
      _category        = e.category;
      _frequency       = e.frequency;
      _dueDayOfMonth   = e.dueDayOfMonth;
      _remindMe        = e.remindMe;
      _remindDays      = e.remindDaysBefore;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _amountCtrl.dispose(); _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty || _amountCtrl.text.trim().isEmpty) return;
    final amount = double.tryParse(_amountCtrl.text);
    if (amount == null) return;

    setState(() => _loading = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final bill = BillModel(
        id:               widget.existing?.id,
        userId:           uid,
        name:             _nameCtrl.text.trim(),
        category:         _category,
        amount:           amount,
        dueDayOfMonth:    _dueDayOfMonth,
        frequency:        _frequency,
        remindMe:         _remindMe,
        remindDaysBefore: _remindDays,
        note:             _noteCtrl.text.trim().isEmpty
            ? null : _noteCtrl.text.trim(),
      );

      if (widget.existing != null) {
        await widget.svc.update(widget.existing!.id!, bill);
      } else {
        await widget.svc.add(bill);
      }
      if (mounted) Navigator.pop(context);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Container(
      margin: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 20),
      decoration: BoxDecoration(
        color: widget.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(children: [
        Container(width: 40, height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            decoration: BoxDecoration(color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(isEdit ? 'Edit Bill' : 'Add Bill Reminder',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 18)),
              TextButton(
                onPressed: _loading ? null : _save,
                child: _loading
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Save', style: TextStyle(
                        color: Color(0xFF1A237E),
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Category picker
            Text('Bill Type', style: TextStyle(
                fontSize: 11, color: Colors.grey[500],
                fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8,
              children: _categories.map((c) {
                final sel = _category == c['key'];
                return GestureDetector(
                  onTap: () => setState(() {
                    _category = c['key']!;
                    if (_nameCtrl.text.isEmpty) {
                      _nameCtrl.text = c['label']!;
                    }
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: sel
                          ? const Color(0xFF1A237E).withOpacity(0.1)
                          : Colors.grey.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: sel
                            ? const Color(0xFF1A237E)
                            : Colors.transparent,
                      ),
                    ),
                    child: Text('${c['emoji']} ${c['label']}',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600,
                            color: sel
                                ? const Color(0xFF1A237E)
                                : Colors.grey[500])),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            Row(children: [
              Expanded(child: _inputField(_nameCtrl, 'Bill Name', 'Electricity')),
              const SizedBox(width: 12),
              Expanded(child: _inputField(_amountCtrl, 'Amount (₹)', '500',
                  type: const TextInputType.numberWithOptions(decimal: true))),
            ]),
            const SizedBox(height: 14),

            // Frequency
            Text('Frequency', style: TextStyle(
                fontSize: 11, color: Colors.grey[500],
                fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(children: ['monthly','quarterly','yearly','once'].map((f) {
              final sel = _frequency == f;
              return Expanded(child: GestureDetector(
                onTap: () => setState(() => _frequency = f),
                child: Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: sel
                        ? const Color(0xFF1A237E)
                        : Colors.grey.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(f[0].toUpperCase() + f.substring(1),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.bold,
                          color: sel ? Colors.white : Colors.grey[500])),
                ),
              ));
            }).toList()),
            const SizedBox(height: 14),

            // Due day
            Text('Due Day of Month', style: TextStyle(
                fontSize: 11, color: Colors.grey[500],
                fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: Slider(
                value: _dueDayOfMonth.toDouble(),
                min: 1, max: 28, divisions: 27,
                activeColor: const Color(0xFF1A237E),
                label: 'Day $_dueDayOfMonth',
                onChanged: (v) => setState(
                    () => _dueDayOfMonth = v.toInt()),
              )),
              Container(
                width: 48, height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A237E).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(child: Text('$_dueDayOfMonth',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A237E)))),
              ),
            ]),
            const SizedBox(height: 14),

            // Remind me
            Row(children: [
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Remind Me',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                Text('Notify before due date',
                    style: TextStyle(fontSize: 11, color: Colors.grey[400])),
              ])),
              Switch(
                value: _remindMe,
                activeColor: const Color(0xFF1A237E),
                onChanged: (v) => setState(() => _remindMe = v),
              ),
            ]),
            if (_remindMe) Row(children: [
              Text('Days before: ', style: TextStyle(
                  fontSize: 12, color: Colors.grey[400])),
              ...[1, 3, 5, 7].map((d) => GestureDetector(
                onTap: () => setState(() => _remindDays = d),
                child: Container(
                  width: 36, height: 32,
                  margin: const EdgeInsets.only(left: 6),
                  decoration: BoxDecoration(
                    color: _remindDays == d
                        ? const Color(0xFF1A237E)
                        : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(child: Text('$d',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12,
                          color: _remindDays == d
                              ? Colors.white : Colors.grey))),
                ),
              )),
            ]),
            const SizedBox(height: 14),
            _inputField(_noteCtrl, 'Note (optional)',
                'e.g. BESCOM account', maxLines: 2),
            const SizedBox(height: 24),
          ],
        )),
      ]),
    );
  }

  Widget _inputField(TextEditingController ctrl, String label, String hint,
      {TextInputType? type, int maxLines = 1}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(
            fontSize: 11, color: Colors.grey[500],
            fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl, keyboardType: type, maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
            filled: true,
            fillColor: Colors.grey.withOpacity(0.08),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
          ),
        ),
      ]);
}