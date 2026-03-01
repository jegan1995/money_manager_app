// lib/screens/subscription_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/subscription_model.dart';
import '../services/subscription_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});
  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen>
    with SingleTickerProviderStateMixin {
  final _svc = SubscriptionService();
  late TabController _tabs;
  String _filter = 'all'; // all, active, paused

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) {
        setState(() => _filter = ['all','active','paused'][_tabs.index]);
      }
    });
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  String _fmt(double v) {
    if (v >= 100000) return '₹${(v/100000).toStringAsFixed(1)}L';
    if (v >= 1000)   return '₹${(v/1000).toStringAsFixed(1)}K';
    return '₹${v.toStringAsFixed(0)}';
  }

  // Popular services presets
  static const _presets = [
    {'name':'Netflix',    'icon':'🎬','color':'0xFFE50914','cat':'streaming'},
    {'name':'Spotify',    'icon':'🎵','color':'0xFF1DB954','cat':'music'},
    {'name':'YouTube Premium','icon':'▶️','color':'0xFFFF0000','cat':'streaming'},
    {'name':'Amazon Prime','icon':'📦','color':'0xFF00A8E1','cat':'streaming'},
    {'name':'Disney+Hotstar','icon':'⭐','color':'0xFF1B6FE3','cat':'streaming'},
    {'name':'Zomato Pro', 'icon':'🍔','color':'0xFFE23744','cat':'food'},
    {'name':'Swiggy One',  'icon':'🛵','color':'0xFFFC8019','cat':'food'},
    {'name':'GPT Plus',    'icon':'🤖','color':'0xFF10A37F','cat':'productivity'},
    {'name':'Adobe CC',    'icon':'🎨','color':'0xFFFF0000','cat':'productivity'},
    {'name':'Gym',         'icon':'💪','color':'0xFF6C3FC6','cat':'fitness'},
    {'name':'Custom',      'icon':'➕','color':'0xFF667eea','cat':'other'},
  ];

  static const _catColors = {
    'streaming':    Color(0xFFE50914),
    'music':        Color(0xFF1DB954),
    'fitness':      Color(0xFF6C3FC6),
    'productivity': Color(0xFF10A37F),
    'food':         Color(0xFFFC8019),
    'other':        Color(0xFF667eea),
  };

  Color _catColor(String cat) => _catColors[cat] ?? const Color(0xFF667eea);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg     = isDark ? const Color(0xFF0D1117) : const Color(0xFFF0F4FF);
    final card   = isDark ? const Color(0xFF1E2530) : Colors.white;

    return Scaffold(
      backgroundColor: bg,
      body: StreamBuilder<List<SubscriptionModel>>(
        stream: _svc.getSubscriptions(),
        builder: (ctx, snap) {
          final all  = snap.data ?? [];
          final active  = all.where((s) => s.status == 'active').toList();
          final paused  = all.where((s) => s.status == 'paused').toList();
          final display = _filter == 'active' ? active
              : _filter == 'paused' ? paused : all;

          final monthlyTotal = active.fold(0.0,
              (s, sub) => s + sub.monthlyEquivalent);
          final yearlyTotal  = active.fold(0.0,
              (s, sub) => s + sub.yearlyEquivalent);
          final dueSoon = active.where((s) => s.isDueSoon).length;

          return CustomScrollView(
            slivers: [
              // ── App bar ─────────────────────────────────────────────────
              SliverAppBar(
                pinned: true,
                expandedHeight: 180,
                backgroundColor: const Color(0xFF667eea),
                foregroundColor: Colors.white,
                title: const Text('Subscriptions',
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
                        colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 56, 20, 16),
                        child: Row(children: [
                          Expanded(child: _headerStat(
                              'Monthly Cost', _fmt(monthlyTotal), '📅')),
                          Container(width: 1, height: 40,
                              color: Colors.white.withOpacity(0.2)),
                          Expanded(child: _headerStat(
                              'Yearly Total', _fmt(yearlyTotal), '📆')),
                          Container(width: 1, height: 40,
                              color: Colors.white.withOpacity(0.2)),
                          Expanded(child: _headerStat(
                              'Due Soon', '$dueSoon',
                              dueSoon > 0 ? '⚠️' : '✅')),
                        ]),
                      ),
                    ),
                  ),
                ),
                bottom: TabBar(
                  controller: _tabs,
                  indicatorColor: Colors.white,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white60,
                  tabs: [
                    Tab(text: 'All (${all.length})'),
                    Tab(text: 'Active (${active.length})'),
                    Tab(text: 'Paused (${paused.length})'),
                  ],
                ),
              ),

              // ── Due soon banner ──────────────────────────────────────────
              if (dueSoon > 0)
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: Row(children: [
                      const Text('⚠️', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 10),
                      Expanded(child: Text(
                        '$dueSoon subscription${dueSoon > 1 ? 's' : ''} '
                        'billing within ${active.first.remindDaysBefore} days',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600),
                      )),
                    ]),
                  ),
                ),

              // ── List ────────────────────────────────────────────────────
              display.isEmpty
                  ? SliverFillRemaining(child: _empty(isDark))
                  : SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (ctx, i) => _subscriptionCard(
                              display[i], card, isDark, ctx),
                          childCount: display.length,
                        ),
                      ),
                    ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSheet(context,
            isDark ? const Color(0xFF1E2530) : Colors.white, isDark),
        icon: const Icon(Icons.add),
        label: const Text('Add Subscription'),
        backgroundColor: const Color(0xFF667eea),
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _headerStat(String label, String value, String emoji) =>
      Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label,
            style: TextStyle(
                color: Colors.white.withOpacity(0.7), fontSize: 10)),
      ]);

  Widget _subscriptionCard(SubscriptionModel s, Color card,
      bool isDark, BuildContext ctx) {
    final daysLeft = s.nextBilling.difference(DateTime.now()).inDays;
    final overdue  = daysLeft < 0;
    final dueSoon  = daysLeft <= 3 && !overdue;
    final color    = _catColor(s.category);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: overdue ? Colors.red.withOpacity(0.3)
              : dueSoon ? Colors.orange.withOpacity(0.3)
              : Colors.transparent,
        ),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.05), blurRadius: 8)],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showDetailSheet(ctx, s, card, isDark),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            // Icon
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(child: Text(s.icon ?? '💳',
                  style: const TextStyle(fontSize: 22))),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(child: Text(s.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                      overflow: TextOverflow.ellipsis)),
                  if (s.status == 'paused')
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('Paused',
                          style: TextStyle(fontSize: 9,
                              color: Colors.grey,
                              fontWeight: FontWeight.bold)),
                    ),
                ]),
                const SizedBox(height: 4),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(s.cycle,
                        style: TextStyle(
                            fontSize: 9, color: color,
                            fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    overdue
                        ? 'Overdue by ${-daysLeft}d'
                        : daysLeft == 0
                            ? 'Due today!'
                            : 'Due in ${daysLeft}d',
                    style: TextStyle(
                        fontSize: 11,
                        color: overdue ? Colors.red
                            : dueSoon ? Colors.orange
                            : Colors.grey[400]),
                  ),
                ]),
              ],
            )),
            // Amount
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(
                '₹${s.amount.toStringAsFixed(0)}',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16, color: color),
              ),
              Text(
                '~${_fmt(s.monthlyEquivalent)}/mo',
                style: TextStyle(fontSize: 10, color: Colors.grey[400]),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _empty(bool isDark) => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Container(
        width: 72, height: 72,
        decoration: BoxDecoration(
          color: const Color(0xFF667eea).withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: const Text('💳',
            style: TextStyle(fontSize: 32),
            textAlign: TextAlign.center),
      ),
      const SizedBox(height: 16),
      const Text('No subscriptions yet',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      const SizedBox(height: 6),
      Text('Track Netflix, Spotify and more',
          style: TextStyle(color: Colors.grey[400], fontSize: 13)),
    ],
  ));

  // ── Add/Edit bottom sheet ─────────────────────────────────────────────────
  void _showAddSheet(BuildContext ctx, Color card, bool isDark,
      [SubscriptionModel? existing]) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddSubscriptionSheet(
        service: _svc,
        existing: existing,
        card: card,
        isDark: isDark,
      ),
    );
  }

  void _showDetailSheet(BuildContext ctx, SubscriptionModel s,
      Color card, bool isDark) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DetailSheet(
        sub: s, svc: _svc, card: card, isDark: isDark,
        onEdit: () {
          Navigator.pop(ctx);
          _showAddSheet(ctx, card, isDark, s);
        },
      ),
    );
  }
}

// ── Add/Edit Sheet ────────────────────────────────────────────────────────────
class _AddSubscriptionSheet extends StatefulWidget {
  final SubscriptionService service;
  final SubscriptionModel? existing;
  final Color card;
  final bool isDark;
  const _AddSubscriptionSheet(
      {required this.service, this.existing,
       required this.card, required this.isDark});
  @override
  State<_AddSubscriptionSheet> createState() => _AddSubscriptionSheetState();
}

class _AddSubscriptionSheetState extends State<_AddSubscriptionSheet> {
  final _nameCtrl   = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _noteCtrl   = TextEditingController();

  String _category = 'streaming';
  String _cycle    = 'monthly';
  String _status   = 'active';
  String _icon     = '💳';
  DateTime _nextBilling = DateTime.now().add(const Duration(days: 30));
  bool _remindMe   = true;
  int  _remindDays = 3;
  bool _loading    = false;

  static const _categories = [
    {'key':'streaming',    'label':'Streaming',    'emoji':'🎬'},
    {'key':'music',        'label':'Music',        'emoji':'🎵'},
    {'key':'fitness',      'label':'Fitness',      'emoji':'💪'},
    {'key':'productivity', 'label':'Productivity', 'emoji':'⚡'},
    {'key':'food',         'label':'Food',         'emoji':'🍔'},
    {'key':'other',        'label':'Other',        'emoji':'📦'},
  ];

  static const _cycles = ['weekly','monthly','quarterly','yearly'];

  static const _popularIcons = [
    '🎬','🎵','📺','💻','🎮','📚','🏋️','🍔','🛵','☁️','📱','🤖','🎨','✈️','💳',
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
      _cycle           = e.cycle;
      _status          = e.status;
      _icon            = e.icon ?? '💳';
      _nextBilling     = e.nextBilling;
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
    if (_nameCtrl.text.trim().isEmpty || _amountCtrl.text.trim().isEmpty) {
      return;
    }
    final amount = double.tryParse(_amountCtrl.text);
    if (amount == null) return;

    setState(() => _loading = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final sub = SubscriptionModel(
        id:               widget.existing?.id,
        userId:           uid,
        name:             _nameCtrl.text.trim(),
        category:         _category,
        amount:           amount,
        cycle:            _cycle,
        startDate:        widget.existing?.startDate ?? DateTime.now(),
        nextBilling:      _nextBilling,
        status:           _status,
        note:             _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        icon:             _icon,
        remindMe:         _remindMe,
        remindDaysBefore: _remindDays,
      );

      if (widget.existing != null) {
        await widget.service.update(widget.existing!.id!, sub);
      } else {
        await widget.service.add(sub);
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
        // Handle
        Container(
          width: 40, height: 4,
          margin: const EdgeInsets.only(top: 12, bottom: 8),
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        // Title bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(isEdit ? 'Edit Subscription' : 'Add Subscription',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 18)),
              TextButton(
                onPressed: _loading ? null : _save,
                child: _loading
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(isEdit ? 'Update' : 'Save',
                        style: const TextStyle(
                            color: Color(0xFF667eea),
                            fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Icon picker
            Text('Icon', style: TextStyle(
                fontSize: 11, color: Colors.grey[500],
                fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SizedBox(
              height: 48,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _popularIcons.length,
                itemBuilder: (_, i) {
                  final ico = _popularIcons[i];
                  final sel = _icon == ico;
                  return GestureDetector(
                    onTap: () => setState(() => _icon = ico),
                    child: Container(
                      width: 44, height: 44,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: sel
                            ? const Color(0xFF667eea).withOpacity(0.15)
                            : Colors.grey.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: sel
                              ? const Color(0xFF667eea)
                              : Colors.transparent,
                        ),
                      ),
                      child: Center(child: Text(ico,
                          style: const TextStyle(fontSize: 20))),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // Name & Amount row
            Row(children: [
              Expanded(child: _field(_nameCtrl, 'Service Name', 'Netflix')),
              const SizedBox(width: 12),
              Expanded(child: _field(_amountCtrl, 'Amount (₹)', '199',
                  type: const TextInputType.numberWithOptions(decimal: true))),
            ]),
            const SizedBox(height: 14),

            // Category
            Text('Category', style: TextStyle(
                fontSize: 11, color: Colors.grey[500],
                fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: _categories.map((c) {
              final sel = _category == c['key'];
              return GestureDetector(
                onTap: () => setState(() => _category = c['key']!),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: sel
                        ? const Color(0xFF667eea).withOpacity(0.15)
                        : Colors.grey.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: sel
                          ? const Color(0xFF667eea)
                          : Colors.transparent,
                    ),
                  ),
                  child: Text('${c['emoji']} ${c['label']}',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: sel
                              ? const Color(0xFF667eea)
                              : Colors.grey[500])),
                ),
              );
            }).toList()),
            const SizedBox(height: 14),

            // Billing cycle
            Text('Billing Cycle', style: TextStyle(
                fontSize: 11, color: Colors.grey[500],
                fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(children: _cycles.map((c) {
              final sel = _cycle == c;
              return Expanded(child: GestureDetector(
                onTap: () => setState(() => _cycle = c),
                child: Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: sel
                        ? const Color(0xFF667eea)
                        : Colors.grey.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    c[0].toUpperCase() + c.substring(1),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: sel ? Colors.white : Colors.grey[500]),
                  ),
                ),
              ));
            }).toList()),
            const SizedBox(height: 14),

            // Next billing date
            Text('Next Billing Date', style: TextStyle(
                fontSize: 11, color: Colors.grey[500],
                fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _nextBilling,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
                );
                if (d != null) setState(() => _nextBilling = d);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(children: [
                  const Icon(Icons.calendar_today_outlined,
                      size: 16, color: Color(0xFF667eea)),
                  const SizedBox(width: 8),
                  Text(DateFormat('dd MMM yyyy').format(_nextBilling),
                      style: const TextStyle(
                          fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Icon(Icons.chevron_right,
                      size: 16, color: Colors.grey[400]),
                ]),
              ),
            ),
            const SizedBox(height: 14),

            // Remind me
            Row(children: [
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Remind Me Before Due',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13)),
                  Text('Get notified before billing',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey[400])),
                ],
              )),
              Switch(
                value: _remindMe,
                activeColor: const Color(0xFF667eea),
                onChanged: (v) => setState(() => _remindMe = v),
              ),
            ]),
            if (_remindMe) ...[
              Row(children: [
                Text('Days before: ', style: TextStyle(
                    fontSize: 12, color: Colors.grey[400])),
                ...[1, 3, 5, 7].map((d) => GestureDetector(
                  onTap: () => setState(() => _remindDays = d),
                  child: Container(
                    width: 36, height: 32,
                    margin: const EdgeInsets.only(left: 6),
                    decoration: BoxDecoration(
                      color: _remindDays == d
                          ? const Color(0xFF667eea)
                          : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(child: Text('$d',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: _remindDays == d
                                ? Colors.white : Colors.grey))),
                  ),
                )),
              ]),
            ],
            const SizedBox(height: 14),
            _field(_noteCtrl, 'Note (optional)', 'e.g. Family plan',
                maxLines: 2),
            const SizedBox(height: 24),
          ],
        )),
      ]),
    );
  }

  Widget _field(TextEditingController ctrl, String label, String hint,
      {TextInputType? type, int maxLines = 1}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(
            fontSize: 11, color: Colors.grey[500],
            fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          keyboardType: type,
          maxLines: maxLines,
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

// ── Detail Sheet ──────────────────────────────────────────────────────────────
class _DetailSheet extends StatelessWidget {
  final SubscriptionModel sub;
  final SubscriptionService svc;
  final Color card;
  final bool isDark;
  final VoidCallback onEdit;

  const _DetailSheet({
    required this.sub, required this.svc,
    required this.card, required this.isDark,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final daysLeft = sub.nextBilling.difference(DateTime.now()).inDays;
    return Container(
      margin: const EdgeInsets.only(top: 60),
      decoration: BoxDecoration(
        color: card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(children: [
        Container(
          width: 40, height: 4,
          margin: const EdgeInsets.only(top: 12, bottom: 20),
          decoration: BoxDecoration(
            color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
        ),
        Text(sub.icon ?? '💳', style: const TextStyle(fontSize: 40)),
        const SizedBox(height: 8),
        Text(sub.name, style: const TextStyle(
            fontWeight: FontWeight.bold, fontSize: 20)),
        const SizedBox(height: 4),
        Text('₹${sub.amount.toStringAsFixed(0)} / ${sub.cycle}',
            style: TextStyle(color: Colors.grey[400], fontSize: 14)),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _stat('Monthly', '₹${sub.monthlyEquivalent.toStringAsFixed(0)}'),
              _stat('Yearly',  '₹${sub.yearlyEquivalent.toStringAsFixed(0)}'),
              _stat('Next Due',
                  daysLeft == 0 ? 'Today'
                  : daysLeft < 0 ? 'Overdue'
                  : '${daysLeft}d'),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: [
            Expanded(child: OutlinedButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('Edit'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF667eea),
                side: const BorderSide(color: Color(0xFF667eea)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            )),
            const SizedBox(width: 10),
            Expanded(child: ElevatedButton.icon(
              onPressed: () async {
                final newStatus = sub.status == 'active' ? 'paused' : 'active';
                await svc.updateStatus(sub.id!, newStatus);
                if (context.mounted) Navigator.pop(context);
              },
              icon: Icon(sub.status == 'active'
                  ? Icons.pause_circle_outline
                  : Icons.play_circle_outline, size: 16),
              label: Text(sub.status == 'active' ? 'Pause' : 'Resume'),
              style: ElevatedButton.styleFrom(
                backgroundColor: sub.status == 'active'
                    ? Colors.orange : const Color(0xFF667eea),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            )),
            const SizedBox(width: 10),
            IconButton(
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Delete Subscription'),
                    content: Text('Delete "${sub.name}"?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel')),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white),
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
                if (ok == true) {
                  await svc.delete(sub.id!);
                  if (context.mounted) Navigator.pop(context);
                }
              },
              icon: const Icon(Icons.delete_outline, color: Colors.red),
            ),
          ]),
        ),
        const SizedBox(height: 30),
      ]),
    );
  }

  Widget _stat(String label, String value) => Column(children: [
    Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[400])),
    const SizedBox(height: 4),
    Text(value, style: const TextStyle(
        fontWeight: FontWeight.bold, fontSize: 15)),
  ]);
}