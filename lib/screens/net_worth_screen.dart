// lib/screens/net_worth_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/net_worth_model.dart';
import '../services/net_worth_service.dart';

// ── Constants ─────────────────────────────────────────────────────────────────
final _inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
String _f(double v) => _inr.format(v.abs());
String _fs(double v) => '${v < 0 ? '-' : ''}${_f(v)}';

const _assetCategories = [
  ('Cash & Bank',     Icons.account_balance_rounded,   Color(0xFF4facfe)),
  ('Investments',     Icons.trending_up_rounded,        Color(0xFF43e97b)),
  ('Real Estate',     Icons.home_rounded,               Color(0xFF667eea)),
  ('Gold & Jewellery',Icons.diamond_rounded,            Color(0xFFf9ca24)),
  ('Vehicles',        Icons.directions_car_rounded,     Color(0xFFf093fb)),
  ('Retirement',      Icons.savings_rounded,            Color(0xFF56ab2f)),
];

const _liabilityCategories = [
  ('Home Loan',       Icons.home_work_rounded,          Color(0xFFfa709a)),
  ('Car Loan',        Icons.car_rental_rounded,         Color(0xFFfda085)),
  ('Personal Loan',   Icons.person_rounded,             Color(0xFFf5576c)),
  ('Credit Card',     Icons.credit_card_rounded,        Color(0xFFee0979)),
  ('Education Loan',  Icons.school_rounded,             Color(0xFFff6b6b)),
  ('Other Loans',     Icons.receipt_long_rounded,       Color(0xFFfd746c)),
];

// ── Screen ────────────────────────────────────────────────────────────────────
class NetWorthScreen extends StatefulWidget {
  const NetWorthScreen({super.key});
  @override
  State<NetWorthScreen> createState() => _NetWorthScreenState();
}

class _NetWorthScreenState extends State<NetWorthScreen>
    with SingleTickerProviderStateMixin {
  final _svc = NetWorthService();
  late TabController _tab;
  int _touchedAsset = -1;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg     = isDark ? const Color(0xFF0D1117) : const Color(0xFFF5F6FA);
    final cardBg = isDark ? const Color(0xFF1E2530) : Colors.white;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Net Worth',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: isDark ? const Color(0xFF1E2530) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _showAddSheet(context, isDark),
            tooltip: 'Add item',
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          indicatorColor: const Color(0xFF667eea),
          labelColor: const Color(0xFF667eea),
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Details'),
          ],
        ),
      ),
      body: StreamBuilder<List<NetWorthItem>>(
        stream: _svc.getItems(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final items      = snap.data ?? [];
          final assets     = items.where((i) => i.type == 'asset').toList();
          final liabilities = items.where((i) => i.type == 'liability').toList();
          final totalAssets = assets.fold(0.0, (s, i) => s + i.value);
          final totalLiab   = liabilities.fold(0.0, (s, i) => s + i.value);
          final netWorth    = totalAssets - totalLiab;

          return TabBarView(
            controller: _tab,
            children: [
              _OverviewTab(
                items: items,
                assets: assets,
                liabilities: liabilities,
                totalAssets: totalAssets,
                totalLiab: totalLiab,
                netWorth: netWorth,
                isDark: isDark,
                cardBg: cardBg,
                touchedAsset: _touchedAsset,
                onTouchAsset: (i) => setState(() => _touchedAsset = i),
                onAdd: () => _showAddSheet(context, isDark),
              ),
              _DetailsTab(
                items: items,
                isDark: isDark,
                cardBg: cardBg,
                onEdit:   (item) => _showEditSheet(context, item, isDark),
                onDelete: (item) => _confirmDelete(context, item),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSheet(context, isDark),
        backgroundColor: const Color(0xFF667eea),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Item',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  // ── Add / Edit sheet ──────────────────────────────────────────────────────
  void _showAddSheet(BuildContext ctx, bool isDark) =>
      _showItemSheet(ctx, null, isDark);

  void _showEditSheet(BuildContext ctx, NetWorthItem item, bool isDark) =>
      _showItemSheet(ctx, item, isDark);

  void _showItemSheet(BuildContext ctx, NetWorthItem? existing, bool isDark) {
    String type     = existing?.type     ?? 'asset';
    String category = existing?.category ?? _assetCategories[0].$1;
    final nameCtrl  = TextEditingController(text: existing?.name  ?? '');
    final valueCtrl = TextEditingController(
        text: existing != null ? existing.value.toStringAsFixed(0) : '');
    final noteCtrl  = TextEditingController(text: existing?.note  ?? '');

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) {
        final cats = type == 'asset' ? _assetCategories : _liabilityCategories;
        // Reset category if switching type
        if (!cats.any((c) => c.$1 == category)) {
          category = cats[0].$1;
        }

        return Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2530) : Colors.white,
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24)),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Handle
              Container(width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2))),

              Text(existing == null ? 'Add Item' : 'Edit Item',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),

              // Type toggle
              Row(children: [
                Expanded(child: _typeBtn('Asset', type == 'asset',
                    Colors.green, () => setSheet(() {
                      type = 'asset';
                      category = _assetCategories[0].$1;
                    }))),
                const SizedBox(width: 10),
                Expanded(child: _typeBtn('Liability', type == 'liability',
                    Colors.red, () => setSheet(() {
                      type = 'liability';
                      category = _liabilityCategories[0].$1;
                    }))),
              ]),
              const SizedBox(height: 16),

              // Category chips
              SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: cats.map((cat) {
                    final sel = category == cat.$1;
                    return GestureDetector(
                      onTap: () => setSheet(() => category = cat.$1),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: sel
                              ? cat.$3.withOpacity(0.15)
                              : Colors.grey.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: sel ? cat.$3 : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(cat.$2, size: 14,
                              color: sel ? cat.$3 : Colors.grey),
                          const SizedBox(width: 5),
                          Text(cat.$1,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: sel ? cat.$3 : Colors.grey,
                                  fontWeight: sel
                                      ? FontWeight.bold
                                      : FontWeight.normal)),
                        ]),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),

              // Name field
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Name *  (e.g. SBI Savings, DLF Flat)',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.grey.shade50,
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),

              // Value field
              TextField(
                controller: valueCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                ],
                decoration: InputDecoration(
                  labelText: 'Current Value *',
                  prefixText: '₹ ',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.grey.shade50,
                ),
              ),
              const SizedBox(height: 12),

              // Note field
              TextField(
                controller: noteCtrl,
                decoration: InputDecoration(
                  labelText: 'Note (optional)',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.grey.shade50,
                ),
              ),
              const SizedBox(height: 20),

              // Save button
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty ||
                        valueCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                          content: Text('Name and value are required')));
                      return;
                    }
                    final uid =
                        FirebaseAuth.instance.currentUser?.uid ?? '';
                    final item = NetWorthItem(
                      id:       existing?.id,
                      userId:   uid,
                      type:     type,
                      category: category,
                      name:     nameCtrl.text.trim(),
                      value:    double.tryParse(valueCtrl.text) ?? 0,
                      note:     noteCtrl.text.trim().isEmpty
                                    ? null
                                    : noteCtrl.text.trim(),
                    );
                    if (existing == null) {
                      await _svc.addItem(item);
                    } else {
                      await _svc.updateItem(item);
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
                    existing == null ? 'Add Item' : 'Save Changes',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
            ]),
          ),
        );
      }),
    );
  }

  Widget _typeBtn(String label, bool sel, Color color, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: sel ? color.withOpacity(0.12) : Colors.grey.withOpacity(0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: sel ? color : Colors.transparent, width: 2),
          ),
          child: Center(child: Text(label,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: sel ? color : Colors.grey))),
        ),
      );

  Future<void> _confirmDelete(BuildContext ctx, NetWorthItem item) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Item'),
        content: Text('Delete "${item.name}" (${_f(item.value)})?'),
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
    if (ok == true) {
      await _svc.deleteItem(item.id!);
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
          content: Text('Deleted: ${item.name}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }
}

// ════════════════════════════════════════════════════════════════════════════
// TAB 1 — OVERVIEW
// ════════════════════════════════════════════════════════════════════════════
class _OverviewTab extends StatelessWidget {
  final List<NetWorthItem> items, assets, liabilities;
  final double totalAssets, totalLiab, netWorth;
  final bool isDark;
  final Color cardBg;
  final int touchedAsset;
  final ValueChanged<int> onTouchAsset;
  final VoidCallback onAdd;

  const _OverviewTab({
    required this.items,       required this.assets,
    required this.liabilities, required this.totalAssets,
    required this.totalLiab,   required this.netWorth,
    required this.isDark,      required this.cardBg,
    required this.touchedAsset, required this.onTouchAsset,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return _empty(context);

    final netColor = netWorth >= 0 ? Colors.green : Colors.red;
    final ratio    = totalAssets > 0
        ? (totalLiab / totalAssets).clamp(0.0, 1.0)
        : 0.0;

    // Group assets by category for pie chart
    final catMap = <String, double>{};
    for (final a in assets) {
      catMap[a.category] = (catMap[a.category] ?? 0) + a.value;
    }
    final catList = catMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    const pieColors = [
      Color(0xFF667eea), Color(0xFF43e97b), Color(0xFF4facfe),
      Color(0xFFf9ca24), Color(0xFFf093fb), Color(0xFF56ab2f),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [

        // ── Net Worth hero card ────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: netWorth >= 0
                  ? [const Color(0xFF667eea), const Color(0xFF764ba2)]
                  : [Colors.red.shade700, Colors.red.shade400],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(
              color: (netWorth >= 0
                  ? const Color(0xFF667eea)
                  : Colors.red).withOpacity(0.35),
              blurRadius: 20, offset: const Offset(0, 8),
            )],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Row(children: [
              const Text('💰', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Text('Net Worth',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 14)),
            ]),
            const SizedBox(height: 8),
            Text(_fs(netWorth),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            // Assets vs Liabilities bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 6,
                backgroundColor: Colors.white.withOpacity(0.3),
                valueColor: AlwaysStoppedAnimation(
                    Colors.red.withOpacity(0.85)),
              ),
            ),
            const SizedBox(height: 10),
            Row(children: [
              _heroStat('Assets', totalAssets, Colors.white),
              const Spacer(),
              _heroStat('Liabilities', totalLiab,
                  Colors.red.shade200, align: TextAlign.right),
            ]),
          ]),
        ),
        const SizedBox(height: 20),

        // ── Asset pie chart ────────────────────────────────────────────────
        if (assets.isNotEmpty) ...[
          _sectionTitle('Asset Breakdown', isDark),
          const SizedBox(height: 12),
          Container(
            height: 220,
            padding: const EdgeInsets.all(16),
            decoration: _cardDeco(cardBg),
            child: Row(children: [
              Expanded(flex: 5, child: PieChart(PieChartData(
                pieTouchData: PieTouchData(
                  touchCallback: (evt, resp) {
                    if (resp?.touchedSection != null) {
                      onTouchAsset(
                          resp!.touchedSection!.touchedSectionIndex);
                    } else {
                      onTouchAsset(-1);
                    }
                  },
                ),
                sections: catList.asMap().entries.map((e) {
                  final pct = totalAssets > 0
                      ? e.value.value / totalAssets * 100
                      : 0.0;
                  final touched = e.key == touchedAsset;
                  return PieChartSectionData(
                    value:  e.value.value,
                    color:  pieColors[e.key % pieColors.length],
                    radius: touched ? 68 : 56,
                    title:  touched
                        ? '${pct.toStringAsFixed(0)}%'
                        : '',
                    titleStyle: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12),
                  );
                }).toList(),
                sectionsSpace: 2,
                centerSpaceRadius: 36,
              ))),
              const SizedBox(width: 12),
              Expanded(flex: 4, child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: catList.asMap().entries.map((e) {
                  final pct = totalAssets > 0
                      ? e.value.value / totalAssets * 100 : 0.0;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(children: [
                      Container(
                        width: 10, height: 10,
                        decoration: BoxDecoration(
                          color: pieColors[e.key % pieColors.length],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(child: Text(e.value.key,
                          style: TextStyle(fontSize: 10,
                              color: isDark
                                  ? Colors.white70
                                  : Colors.black87),
                          overflow: TextOverflow.ellipsis)),
                      Text('${pct.toStringAsFixed(0)}%',
                          style: TextStyle(
                              fontSize: 9, color: Colors.grey[500])),
                    ]),
                  );
                }).toList(),
              )),
            ]),
          ),
          const SizedBox(height: 20),
        ],

        // ── Summary cards ──────────────────────────────────────────────────
        Row(children: [
          Expanded(child: _summaryCard(
              '💚 Assets', totalAssets,
              assets.length, Colors.green, cardBg, isDark)),
          const SizedBox(width: 12),
          Expanded(child: _summaryCard(
              '❤️ Liabilities', totalLiab,
              liabilities.length, Colors.red, cardBg, isDark)),
        ]),
        const SizedBox(height: 20),

        // ── Category summary ───────────────────────────────────────────────
        _sectionTitle('By Category', isDark),
        const SizedBox(height: 12),
        ..._buildCategorySummary(assets, totalAssets,
            _assetCategories, cardBg, isDark, 'Assets'),
        const SizedBox(height: 12),
        ..._buildCategorySummary(liabilities, totalLiab,
            _liabilityCategories, cardBg, isDark, 'Liabilities'),

        const SizedBox(height: 80),
      ],
    );
  }

  List<Widget> _buildCategorySummary(
    List<NetWorthItem> list,
    double total,
    List<(String, IconData, Color)> cats,
    Color cardBg,
    bool isDark,
    String label,
  ) {
    if (list.isEmpty) return [];
    final catMap = <String, double>{};
    for (final i in list) catMap[i.category] = (catMap[i.category] ?? 0) + i.value;
    final entries = catMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: _cardDeco(cardBg),
        child: Column(children: entries.map((e) {
          final cat  = cats.firstWhere(
              (c) => c.$1 == e.key,
              orElse: () => (e.key, Icons.circle, Colors.grey));
          final pct  = total > 0 ? e.value / total : 0.0;
          final isLiab = label == 'Liabilities';
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(children: [
              Row(children: [
                Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                    color: cat.$3.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(cat.$2, color: cat.$3, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.key, style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                    Text('${(pct * 100).toStringAsFixed(0)}% of $label',
                        style: TextStyle(
                            fontSize: 10, color: Colors.grey[500])),
                  ],
                )),
                Text(
                  isLiab ? '−${_f(e.value)}' : _f(e.value),
                  style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 13,
                    color: isLiab ? Colors.red : Colors.green,
                  ),
                ),
              ]),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct, minHeight: 4,
                  backgroundColor: Colors.grey.withOpacity(0.12),
                  valueColor: AlwaysStoppedAnimation(cat.$3),
                ),
              ),
            ]),
          );
        }).toList()),
      ),
    ];
  }

  Widget _empty(BuildContext context) => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const Text('💰', style: TextStyle(fontSize: 64)),
      const SizedBox(height: 16),
      const Text('Track Your Net Worth',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Text('Add assets and liabilities\nto see your financial picture',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[500])),
      const SizedBox(height: 24),
      ElevatedButton.icon(
        onPressed: onAdd,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add First Item'),
        style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF667eea),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(
                horizontal: 24, vertical: 12)),
      ),
    ],
  ));

  Widget _heroStat(String label, double val, Color color,
      {TextAlign align = TextAlign.left}) =>
      Column(crossAxisAlignment: align == TextAlign.right
          ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
        Text(_f(val), style: TextStyle(
            color: color, fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: TextStyle(
            color: Colors.white.withOpacity(0.65), fontSize: 11)),
      ]);

  Widget _summaryCard(String label, double val, int count,
      Color color, Color bg, bool isDark) =>
      Container(
        padding: const EdgeInsets.all(16),
        decoration: _cardDeco(bg),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Text(label, style: const TextStyle(
              fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          Text(_f(val), style: TextStyle(
              fontWeight: FontWeight.bold, fontSize: 18, color: color)),
          const SizedBox(height: 4),
          Text('$count item${count == 1 ? '' : 's'}',
              style: TextStyle(fontSize: 11, color: Colors.grey[500])),
        ]),
      );
}

// ════════════════════════════════════════════════════════════════════════════
// TAB 2 — DETAILS (full item list with edit/delete)
// ════════════════════════════════════════════════════════════════════════════
class _DetailsTab extends StatelessWidget {
  final List<NetWorthItem> items;
  final bool isDark;
  final Color cardBg;
  final ValueChanged<NetWorthItem> onEdit;
  final ValueChanged<NetWorthItem> onDelete;

  const _DetailsTab({
    required this.items,   required this.isDark,
    required this.cardBg,  required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(child: Text('No items yet',
          style: TextStyle(color: Colors.grey[500])));
    }

    final assets      = items.where((i) => i.type == 'asset').toList();
    final liabilities = items.where((i) => i.type == 'liability').toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (assets.isNotEmpty) ...[
          _groupHeader('💚 Assets', assets, Colors.green, isDark),
          ..._groupedItems(assets, _assetCategories),
          const SizedBox(height: 20),
        ],
        if (liabilities.isNotEmpty) ...[
          _groupHeader('❤️ Liabilities', liabilities, Colors.red, isDark),
          ..._groupedItems(liabilities, _liabilityCategories),
        ],
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _groupHeader(String title, List<NetWorthItem> list,
      Color color, bool isDark) {
    final total = list.fold(0.0, (s, i) => s + i.value);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Text(title, style: const TextStyle(
            fontWeight: FontWeight.bold, fontSize: 15)),
        const Spacer(),
        Text(_f(total), style: TextStyle(
            fontWeight: FontWeight.bold, fontSize: 15, color: color)),
      ]),
    );
  }

  List<Widget> _groupedItems(
    List<NetWorthItem> items,
    List<(String, IconData, Color)> cats,
  ) {
    // Group by category
    final map = <String, List<NetWorthItem>>{};
    for (final i in items) {
      map.putIfAbsent(i.category, () => []).add(i);
    }
    final result = <Widget>[];
    for (final entry in map.entries) {
      final cat = cats.firstWhere(
          (c) => c.$1 == entry.key,
          orElse: () => (entry.key, Icons.circle, Colors.grey));
      result.add(Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(children: [
          Icon(cat.$2, size: 14, color: cat.$3),
          const SizedBox(width: 6),
          Text(cat.$1, style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.bold,
              color: isDark ? Colors.white54 : Colors.grey[600])),
        ]),
      ));
      for (final item in entry.value) {
        result.add(Dismissible(
          key: Key(item.id ?? item.name),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            decoration: BoxDecoration(
              color: Colors.red.shade400,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.delete_outline,
                color: Colors.white, size: 22),
          ),
          confirmDismiss: (_) async {
            HapticFeedback.mediumImpact();
            onDelete(item);
            return false; // let onDelete handle
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8, offset: const Offset(0, 3))],
            ),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: cat.$3.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(cat.$2, color: cat.$3, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name, style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13)),
                  if (item.note != null && item.note!.isNotEmpty)
                    Text(item.note!, style: TextStyle(
                        fontSize: 11, color: Colors.grey[500]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                ],
              )),
              Text(
                item.type == 'liability'
                    ? '−${_f(item.value)}'
                    : _f(item.value),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: item.type == 'liability'
                      ? Colors.red : Colors.green,
                ),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => onEdit(item),
                child: Icon(Icons.edit_outlined,
                    size: 18,
                    color: isDark
                        ? Colors.white38 : Colors.grey[400]),
              ),
            ]),
          ),
        ));
      }
      result.add(const SizedBox(height: 8));
    }
    return result;
  }
}

// ── Shared helpers ─────────────────────────────────────────────────────────────
BoxDecoration _cardDeco(Color bg) => BoxDecoration(
  color: bg,
  borderRadius: BorderRadius.circular(16),
  boxShadow: [BoxShadow(
      color: Colors.black.withOpacity(0.06),
      blurRadius: 12, offset: const Offset(0, 4))],
);

Widget _sectionTitle(String t, bool isDark) => Text(t,
    style: TextStyle(
        fontSize: 15, fontWeight: FontWeight.bold,
        color: isDark ? Colors.white : Colors.black87));