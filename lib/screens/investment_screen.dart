// lib/screens/investment_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/investment_model.dart';
import '../services/investment_service.dart';

class InvestmentScreen extends StatefulWidget {
  const InvestmentScreen({super.key});
  @override
  State<InvestmentScreen> createState() => _InvestmentScreenState();
}

class _InvestmentScreenState extends State<InvestmentScreen>
    with SingleTickerProviderStateMixin {
  final _svc = InvestmentService();
  late TabController _tabs;
  String _selectedType = 'all';

  static const _types = [
    {'key':'all',          'label':'All',          'emoji':'📊'},
    {'key':'stocks',       'label':'Stocks',       'emoji':'📈'},
    {'key':'mutual_fund',  'label':'MF',           'emoji':'🏦'},
    {'key':'gold',         'label':'Gold',         'emoji':'🥇'},
    {'key':'fd',           'label':'FD',           'emoji':'🏛️'},
    {'key':'crypto',       'label':'Crypto',       'emoji':'🪙'},
    {'key':'ppf',          'label':'PPF',          'emoji':'🛡️'},
    {'key':'real_estate',  'label':'Property',     'emoji':'🏠'},
    {'key':'other',        'label':'Other',        'emoji':'📦'},
  ];

  static const _typeColors = {
    'stocks':      Color(0xFF2196F3),
    'mutual_fund': Color(0xFF9C27B0),
    'gold':        Color(0xFFFFC107),
    'fd':          Color(0xFF4CAF50),
    'crypto':      Color(0xFFFF9800),
    'ppf':         Color(0xFF009688),
    'real_estate': Color(0xFF795548),
    'other':       Color(0xFF607D8B),
  };

  Color _color(String type) => _typeColors[type] ?? const Color(0xFF667eea);
  String _emoji(String type) =>
      _types.firstWhere((t) => t['key'] == type,
          orElse: () => {'emoji': '📊'})['emoji']!;

  String _fmt(double v) {
    final a = v.abs();
    if (a >= 10000000) return '₹${(a/10000000).toStringAsFixed(2)}Cr';
    if (a >= 100000)   return '₹${(a/100000).toStringAsFixed(2)}L';
    if (a >= 1000)     return '₹${(a/1000).toStringAsFixed(1)}K';
    return '₹${a.toStringAsFixed(0)}';
  }

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _types.length, vsync: this);
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) {
        setState(() => _selectedType = _types[_tabs.index]['key']!);
      }
    });
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg     = isDark ? const Color(0xFF0D1117) : const Color(0xFFF0F4FF);
    final card   = isDark ? const Color(0xFF1E2530) : Colors.white;

    return Scaffold(
      backgroundColor: bg,
      body: StreamBuilder<List<InvestmentModel>>(
        stream: _svc.getInvestments(),
        builder: (ctx, snap) {
          final all = snap.data ?? [];
          final filtered = _selectedType == 'all'
              ? all
              : all.where((i) => i.type == _selectedType).toList();

          final totalInvested = all.fold(0.0, (s, i) => s + i.invested);
          final totalCurrent  = all.fold(0.0, (s, i) => s + i.currentValue);
          final totalReturns  = totalCurrent - totalInvested;
          final returnsPct    = totalInvested > 0
              ? (totalReturns / totalInvested) * 100 : 0.0;

          return CustomScrollView(
            slivers: [
              // ── App bar ──────────────────────────────────────────────
              SliverAppBar(
                pinned: true,
                expandedHeight: 220,
                backgroundColor: const Color(0xFF1B5E20),
                foregroundColor: Colors.white,
                title: const Text('Investment Portfolio',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () => _showAddSheet(ctx, card, isDark),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF1B5E20), Color(0xFF388E3C)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 56, 20, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Portfolio Value',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 12)),
                            const SizedBox(height: 4),
                            Text(_fmt(totalCurrent),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: -1)),
                            const SizedBox(height: 12),
                            Row(children: [
                              _headerStat('Invested',   _fmt(totalInvested)),
                              _vDiv(),
                              _headerStat('Returns',
                                  '${totalReturns >= 0 ? '+' : ''}${_fmt(totalReturns)}',
                                  color: totalReturns >= 0
                                      ? Colors.greenAccent
                                      : Colors.redAccent),
                              _vDiv(),
                              _headerStat('Return %',
                                  '${returnsPct >= 0 ? '+' : ''}${returnsPct.toStringAsFixed(1)}%',
                                  color: returnsPct >= 0
                                      ? Colors.greenAccent
                                      : Colors.redAccent),
                              _vDiv(),
                              _headerStat('Holdings', '${all.length}'),
                            ]),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                bottom: TabBar(
                  controller: _tabs,
                  isScrollable: true,
                  indicatorColor: Colors.white,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white60,
                  tabAlignment: TabAlignment.start,
                  tabs: _types.map((t) =>
                      Tab(text: '${t['emoji']} ${t['label']}')).toList(),
                ),
              ),

              // ── Type allocation strip ────────────────────────────────
              if (all.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: _allocationBar(all, totalCurrent, card),
                  ),
                ),

              // ── List ─────────────────────────────────────────────────
              filtered.isEmpty
                  ? SliverFillRemaining(child: _empty(isDark))
                  : SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (_, i) => _investmentCard(
                              filtered[i], card, isDark, ctx,
                              filtered[i].currentValue / totalCurrent),
                          childCount: filtered.length,
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
        label: const Text('Add Investment'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _headerStat(String label, String value, {Color? color}) =>
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(
              color: Colors.white.withOpacity(0.7), fontSize: 10)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(
              color: color ?? Colors.white,
              fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ));

  Widget _vDiv() => Container(
      width: 1, height: 32, color: Colors.white.withOpacity(0.2),
      margin: const EdgeInsets.symmetric(horizontal: 8));

  Widget _allocationBar(List<InvestmentModel> all,
      double total, Color card) {
    // Group by type
    final groups = <String, double>{};
    for (final inv in all) {
      groups[inv.type] = (groups[inv.type] ?? 0) + inv.currentValue;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.05), blurRadius: 8)],
      ),
      child: Column(children: [
        const Align(alignment: Alignment.centerLeft,
            child: Text('Allocation',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 13))),
        const SizedBox(height: 10),
        // Segmented bar
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 12,
            child: Row(
              children: groups.entries.map((e) {
                final pct = total > 0 ? e.value / total : 0.0;
                return Expanded(
                  flex: (pct * 1000).toInt(),
                  child: Container(color: _color(e.key)),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 12, runSpacing: 6,
          children: groups.entries.map((e) {
            final pct = total > 0 ? (e.value / total) * 100 : 0.0;
            return Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 10, height: 10,
                  decoration: BoxDecoration(
                      color: _color(e.key), shape: BoxShape.circle)),
              const SizedBox(width: 4),
              Text('${_emoji(e.key)} ${pct.toStringAsFixed(0)}%',
                  style: const TextStyle(fontSize: 11)),
            ]);
          }).toList(),
        ),
      ]),
    );
  }

  Widget _investmentCard(InvestmentModel inv, Color card,
      bool isDark, BuildContext ctx, double portfolioPct) {
    final color = _color(inv.type);
    final isProfit = inv.isProfit;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.05), blurRadius: 8)],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showDetailSheet(ctx, inv, card, isDark),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Row(children: [
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Center(child: Text(_emoji(inv.type),
                    style: const TextStyle(fontSize: 22))),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(inv.name, style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(inv.type.replaceAll('_', ' '),
                          style: TextStyle(
                              fontSize: 9, color: color,
                              fontWeight: FontWeight.bold)),
                    ),
                    if (inv.symbol != null) ...[
                      const SizedBox(width: 6),
                      Text(inv.symbol!,
                          style: TextStyle(
                              fontSize: 10, color: Colors.grey[400])),
                    ],
                    if (inv.broker != null) ...[
                      const SizedBox(width: 6),
                      Text('• ${inv.broker}',
                          style: TextStyle(
                              fontSize: 10, color: Colors.grey[400])),
                    ],
                  ]),
                ],
              )),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(_fmt(inv.currentValue),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isProfit
                        ? Colors.green.withOpacity(0.1)
                        : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    '${isProfit ? '▲' : '▼'} '
                    '${inv.returnsPct.abs().toStringAsFixed(1)}%',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isProfit ? Colors.green : Colors.red),
                  ),
                ),
              ]),
            ]),
            const SizedBox(height: 10),
            // Mini stats row
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
              _miniStat('Invested', _fmt(inv.invested), Colors.grey),
              _miniStat('Returns',
                  '${isProfit ? '+' : ''}${_fmt(inv.returns)}',
                  isProfit ? Colors.green : Colors.red),
              _miniStat('Portfolio',
                  '${(portfolioPct * 100).toStringAsFixed(1)}%',
                  color),
              if (inv.quantity > 0 && inv.quantity != 1)
                _miniStat('Units',
                    inv.quantity.toStringAsFixed(2), Colors.grey),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _miniStat(String label, String value, Color color) =>
      Column(children: [
        Text(label, style: TextStyle(fontSize: 9, color: Colors.grey[400])),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.bold, color: color)),
      ]);

  Widget _empty(bool isDark) => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center, children: [
    Container(
      width: 72, height: 72,
      decoration: BoxDecoration(
        color: const Color(0xFF1B5E20).withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: const Text('📊',
          style: TextStyle(fontSize: 32), textAlign: TextAlign.center),
    ),
    const SizedBox(height: 16),
    const Text('No investments tracked',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
    const SizedBox(height: 6),
    Text('Add stocks, mutual funds, gold, FD',
        style: TextStyle(color: Colors.grey[400], fontSize: 13)),
  ]));

  void _showAddSheet(BuildContext ctx, Color card, bool isDark,
      [InvestmentModel? existing]) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddInvestmentSheet(
        svc: _svc, existing: existing, card: card, isDark: isDark,
      ),
    );
  }

  void _showDetailSheet(BuildContext ctx, InvestmentModel inv,
      Color card, bool isDark) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DetailSheet(
        inv: inv, svc: _svc, card: card, isDark: isDark,
        onEdit: () {
          Navigator.pop(ctx);
          _showAddSheet(ctx, card, isDark, inv);
        },
      ),
    );
  }
}

// ── Add/Edit Sheet ────────────────────────────────────────────────────────────
class _AddInvestmentSheet extends StatefulWidget {
  final InvestmentService svc;
  final InvestmentModel? existing;
  final Color card;
  final bool isDark;
  const _AddInvestmentSheet({
    required this.svc, this.existing,
    required this.card, required this.isDark,
  });
  @override
  State<_AddInvestmentSheet> createState() => _AddInvestmentSheetState();
}

class _AddInvestmentSheetState extends State<_AddInvestmentSheet> {
  final _nameCtrl     = TextEditingController();
  final _investedCtrl = TextEditingController();
  final _currentCtrl  = TextEditingController();
  final _qtyCtrl      = TextEditingController();
  final _symbolCtrl   = TextEditingController();
  final _brokerCtrl   = TextEditingController();
  final _noteCtrl     = TextEditingController();

  String   _type         = 'stocks';
  DateTime _purchaseDate = DateTime.now();
  bool     _loading      = false;

  static const _types = [
    {'key':'stocks',      'label':'Stocks',       'emoji':'📈'},
    {'key':'mutual_fund', 'label':'Mutual Fund',  'emoji':'🏦'},
    {'key':'gold',        'label':'Gold',         'emoji':'🥇'},
    {'key':'fd',          'label':'Fixed Deposit','emoji':'🏛️'},
    {'key':'crypto',      'label':'Crypto',       'emoji':'🪙'},
    {'key':'ppf',         'label':'PPF/EPF',      'emoji':'🛡️'},
    {'key':'real_estate', 'label':'Property',     'emoji':'🏠'},
    {'key':'other',       'label':'Other',        'emoji':'📦'},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      final e = widget.existing!;
      _nameCtrl.text     = e.name;
      _investedCtrl.text = e.invested.toStringAsFixed(0);
      _currentCtrl.text  = e.currentValue.toStringAsFixed(0);
      _qtyCtrl.text      = e.quantity == 1 ? '' : e.quantity.toString();
      _symbolCtrl.text   = e.symbol ?? '';
      _brokerCtrl.text   = e.broker ?? '';
      _noteCtrl.text     = e.note ?? '';
      _type              = e.type;
      _purchaseDate      = e.purchaseDate;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _investedCtrl.dispose(); _currentCtrl.dispose();
    _qtyCtrl.dispose(); _symbolCtrl.dispose();
    _brokerCtrl.dispose(); _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty ||
        _investedCtrl.text.trim().isEmpty ||
        _currentCtrl.text.trim().isEmpty) return;

    final invested = double.tryParse(_investedCtrl.text);
    final current  = double.tryParse(_currentCtrl.text);
    if (invested == null || current == null) return;

    setState(() => _loading = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final qty = double.tryParse(_qtyCtrl.text) ?? 1;
      final inv = InvestmentModel(
        id:           widget.existing?.id,
        userId:       uid,
        name:         _nameCtrl.text.trim(),
        type:         _type,
        invested:     invested,
        currentValue: current,
        quantity:     qty,
        buyPrice:     qty > 0 ? invested / qty : invested,
        symbol:       _symbolCtrl.text.trim().isEmpty
            ? null : _symbolCtrl.text.trim().toUpperCase(),
        broker:       _brokerCtrl.text.trim().isEmpty
            ? null : _brokerCtrl.text.trim(),
        purchaseDate: _purchaseDate,
        note:         _noteCtrl.text.trim().isEmpty
            ? null : _noteCtrl.text.trim(),
      );

      if (widget.existing != null) {
        await widget.svc.update(widget.existing!.id!, inv);
      } else {
        await widget.svc.add(inv);
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
              Text(isEdit ? 'Edit Investment' : 'Add Investment',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 18)),
              TextButton(
                onPressed: _loading ? null : _save,
                child: _loading
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(isEdit ? 'Update' : 'Save',
                        style: const TextStyle(
                            color: Color(0xFF1B5E20),
                            fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Type
            Text('Investment Type', style: TextStyle(
                fontSize: 11, color: Colors.grey[500],
                fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8,
              children: _types.map((t) {
                final sel = _type == t['key'];
                return GestureDetector(
                  onTap: () => setState(() => _type = t['key']!),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: sel
                          ? const Color(0xFF1B5E20).withOpacity(0.1)
                          : Colors.grey.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: sel
                            ? const Color(0xFF1B5E20)
                            : Colors.transparent,
                      ),
                    ),
                    child: Text('${t['emoji']} ${t['label']}',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600,
                            color: sel
                                ? const Color(0xFF1B5E20)
                                : Colors.grey[500])),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            _field(_nameCtrl, 'Investment Name', 'e.g. Reliance Industries'),
            const SizedBox(height: 12),

            Row(children: [
              Expanded(child: _field(_investedCtrl, 'Amount Invested (₹)', '10000',
                  type: const TextInputType.numberWithOptions(decimal: true))),
              const SizedBox(width: 12),
              Expanded(child: _field(_currentCtrl, 'Current Value (₹)', '12000',
                  type: const TextInputType.numberWithOptions(decimal: true))),
            ]),
            const SizedBox(height: 12),

            Row(children: [
              Expanded(child: _field(_qtyCtrl, 'Units / Grams / Qty', '10',
                  type: const TextInputType.numberWithOptions(decimal: true))),
              const SizedBox(width: 12),
              Expanded(child: _field(_symbolCtrl, 'Symbol / Ticker',
                  'RELIANCE / INF123')),
            ]),
            const SizedBox(height: 12),
            _field(_brokerCtrl, 'Broker / Platform',
                'e.g. Zerodha, Groww, Coin'),
            const SizedBox(height: 12),

            // Purchase date
            Text('Purchase Date', style: TextStyle(
                fontSize: 11, color: Colors.grey[500],
                fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _purchaseDate,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                );
                if (d != null) setState(() => _purchaseDate = d);
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
                      size: 16, color: Color(0xFF1B5E20)),
                  const SizedBox(width: 8),
                  Text(DateFormat('dd MMM yyyy').format(_purchaseDate),
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Icon(Icons.chevron_right,
                      size: 16, color: Colors.grey[400]),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            _field(_noteCtrl, 'Note (optional)', 'e.g. Long term holding',
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

// ── Detail / Update value sheet ───────────────────────────────────────────────
class _DetailSheet extends StatefulWidget {
  final InvestmentModel inv;
  final InvestmentService svc;
  final Color card;
  final bool isDark;
  final VoidCallback onEdit;
  const _DetailSheet({
    required this.inv, required this.svc,
    required this.card, required this.isDark,
    required this.onEdit,
  });
  @override
  State<_DetailSheet> createState() => _DetailSheetState();
}

class _DetailSheetState extends State<_DetailSheet> {
  late TextEditingController _valCtrl;

  @override
  void initState() {
    super.initState();
    _valCtrl = TextEditingController(
        text: widget.inv.currentValue.toStringAsFixed(0));
  }

  @override
  void dispose() { _valCtrl.dispose(); super.dispose(); }

  String _fmt(double v) {
    if (v >= 100000) return '₹${(v/100000).toStringAsFixed(2)}L';
    if (v >= 1000)   return '₹${(v/1000).toStringAsFixed(1)}K';
    return '₹${v.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    final inv     = widget.inv;
    final isProfit = inv.isProfit;

    return Container(
      margin: const EdgeInsets.only(top: 80),
      decoration: BoxDecoration(
        color: widget.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2))),
          Row(children: [
            const SizedBox(width: 8),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(inv.name, style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 20)),
              if (inv.symbol != null)
                Text(inv.symbol!,
                    style: TextStyle(color: Colors.grey[400])),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isProfit
                    ? Colors.green.withOpacity(0.1)
                    : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${isProfit ? '▲' : '▼'} '
                '${inv.returnsPct.abs().toStringAsFixed(1)}%',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isProfit ? Colors.green : Colors.red),
              ),
            ),
          ]),
          const SizedBox(height: 20),

          // Stats grid
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.05),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(children: [
              Row(children: [
                _statTile('Invested', _fmt(inv.invested)),
                _statTile('Current',  _fmt(inv.currentValue)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                _statTile('Returns',
                    '${isProfit ? '+' : ''}${_fmt(inv.returns)}',
                    color: isProfit ? Colors.green : Colors.red),
                _statTile('Purchase',
                    DateFormat('d MMM yy').format(inv.purchaseDate)),
              ]),
              if (inv.broker != null) ...[
                const SizedBox(height: 12),
                Row(children: [
                  _statTile('Broker', inv.broker!),
                  _statTile('Units',  inv.quantity.toStringAsFixed(2)),
                ]),
              ],
            ]),
          ),
          const SizedBox(height: 16),

          // Quick update current value
          Text('Update Current Value', style: TextStyle(
              fontSize: 11, color: Colors.grey[400],
              fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: TextField(
              controller: _valCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                prefixText: '₹ ',
                filled: true,
                fillColor: Colors.grey.withOpacity(0.08),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
              ),
            )),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: () async {
                final val = double.tryParse(_valCtrl.text);
                if (val != null) {
                  await widget.svc.updateCurrentValue(inv.id!, val);
                  if (context.mounted) Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B5E20),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 14),
                elevation: 0,
              ),
              child: const Text('Update'),
            ),
          ]),
          const SizedBox(height: 16),

          Row(children: [
            Expanded(child: OutlinedButton.icon(
              onPressed: widget.onEdit,
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('Edit'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1B5E20),
                side: const BorderSide(color: Color(0xFF1B5E20)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            )),
            const SizedBox(width: 10),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () async {
                await widget.svc.delete(inv.id!);
                if (context.mounted) Navigator.pop(context);
              },
            ),
          ]),
          const SizedBox(height: 20),
        ],
      )),
    );
  }

  Widget _statTile(String label, String value, {Color? color}) =>
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(
              fontSize: 10, color: Colors.grey[400])),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: color)),
        ],
      ));
}