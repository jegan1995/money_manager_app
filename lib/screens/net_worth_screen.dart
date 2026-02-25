import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/net_worth_model.dart';
import '../models/account_model.dart';
import '../services/net_worth_service.dart';
import '../services/account_service.dart';

class NetWorthScreen extends StatefulWidget {
  const NetWorthScreen({super.key});

  @override
  State<NetWorthScreen> createState() => _NetWorthScreenState();
}

class _NetWorthScreenState extends State<NetWorthScreen>
    with SingleTickerProviderStateMixin {
  final _svc     = NetWorthService();
  final _accSvc  = AccountService();
  late TabController _tab;
  bool _balanceHidden = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────
  String _fmt(double v) {
    final abs = v.abs();
    String str;
    if (abs >= 10000000)      str = '₹${(abs / 10000000).toStringAsFixed(2)} Cr';
    else if (abs >= 100000)   str = '₹${(abs / 100000).toStringAsFixed(2)} L';
    else if (abs >= 1000)     str = '₹${(abs / 1000).toStringAsFixed(1)}k';
    else                      str = '₹${abs.toStringAsFixed(0)}';
    return v < 0 ? '-$str' : str;
  }

  String _fmtFull(double v) =>
      '₹${NumberFormat('#,##,##0').format(v.abs())}';

  // ── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0D1117) : const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('Net Worth'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_balanceHidden
                ? Icons.visibility_off
                : Icons.visibility,
                color: Colors.white70),
            onPressed: () => setState(() => _balanceHidden = !_balanceHidden),
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Overview'),
            Tab(icon: Icon(Icons.account_balance), text: 'Assets'),
            Tab(icon: Icon(Icons.credit_card), text: 'Liabilities'),
          ],
        ),
      ),
      body: StreamBuilder<List<NetWorthItem>>(
        stream: _svc.getItems(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final items       = snap.data ?? [];
          final assets      = items.where((i) => i.isAsset).toList();
          final liabilities = items.where((i) => i.isLiability).toList();

          // Also pull in account balances as assets
          return StreamBuilder<List<AccountModel>>(
            stream: _accSvc.getAccounts(),
            builder: (context, accSnap) {
              final accounts = accSnap.data ?? [];

              // Accounts that are positive = assets, negative/debt = liabilities
              double accAssets = 0, accLiabilities = 0;
              for (final a in accounts) {
                if (a.isDebt) {
                  accLiabilities += a.balance.abs();
                } else {
                  if (a.balance > 0) accAssets += a.balance;
                }
              }

              final manualAssets      = assets.fold(0.0, (s, i) => s + i.value);
              final manualLiabilities = liabilities.fold(0.0, (s, i) => s + i.value);

              final totalAssets      = manualAssets + accAssets;
              final totalLiabilities = manualLiabilities + accLiabilities;
              final netWorth         = totalAssets - totalLiabilities;

              return TabBarView(
                controller: _tab,
                children: [
                  _buildOverview(isDark, items, accounts,
                      totalAssets, totalLiabilities, netWorth, accAssets, accLiabilities),
                  _buildItemList(isDark, assets, 'asset', accounts),
                  _buildItemList(isDark, liabilities, 'liability', accounts),
                ],
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSheet(context),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Item'),
      ),
    );
  }

  // ── Tab 1: Overview ──────────────────────────────────────────────────────────
  Widget _buildOverview(
    bool isDark,
    List<NetWorthItem> items,
    List<AccountModel> accounts,
    double totalAssets,
    double totalLiabilities,
    double netWorth,
    double accAssets,
    double accLiabilities,
  ) {
    final isPositive = netWorth >= 0;
    final debtRatio  = totalAssets > 0
        ? (totalLiabilities / totalAssets * 100).clamp(0.0, 100.0)
        : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // ── Net Worth Hero card ─────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isPositive
                    ? [const Color(0xFF1A237E), const Color(0xFF3949AB)]
                    : [const Color(0xFF7B1FA2), const Color(0xFFC62828)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                    color: (isPositive
                            ? const Color(0xFF1A237E)
                            : const Color(0xFF7B1FA2))
                        .withOpacity(0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 8)),
              ],
            ),
            child: Column(
              children: [
                const Text('Net Worth',
                    style: TextStyle(color: Colors.white60, fontSize: 14)),
                const SizedBox(height: 8),
                Text(
                  _balanceHidden ? '₹ ••••••' : _fmt(netWorth),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -1),
                ),
                const SizedBox(height: 4),
                Text(
                  isPositive ? '💚 Positive net worth!' : '⚠️ Liabilities exceed assets',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 20),
                const Divider(color: Colors.white24),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _heroStat('Total Assets',      _fmt(totalAssets),      Colors.greenAccent),
                    Container(width: 1, height: 40, color: Colors.white24),
                    _heroStat('Total Liabilities', _fmt(totalLiabilities), Colors.redAccent),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Debt ratio card ─────────────────────────────────────────────────
          _card(isDark,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Debt-to-Asset Ratio',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: (debtRatio < 30
                                ? Colors.green
                                : debtRatio < 60
                                    ? Colors.orange
                                    : Colors.red)
                            .withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${debtRatio.toStringAsFixed(1)}%',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: debtRatio < 30
                                ? Colors.green
                                : debtRatio < 60
                                    ? Colors.orange
                                    : Colors.red),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: debtRatio / 100,
                    backgroundColor: Colors.green.withOpacity(0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(
                        debtRatio < 30
                            ? Colors.green
                            : debtRatio < 60
                                ? Colors.orange
                                : Colors.red),
                    minHeight: 12,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  debtRatio < 30
                      ? '✅ Excellent! Low debt relative to assets.'
                      : debtRatio < 60
                          ? '⚠️ Moderate debt. Aim to reduce liabilities.'
                          : '🚨 High debt! Focus on paying off loans.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Asset vs Liability breakdown ─────────────────────────────────────
          _card(isDark,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Breakdown',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 14),

                // Assets row
                _breakdownSection('Assets', [
                  if (accAssets > 0)
                    _breakdownRow('💳 Bank & Cash (accounts)',
                        accAssets, Colors.blue, totalAssets),
                  ..._groupByCategory(
                      items.where((i) => i.isAsset).toList(),
                      totalAssets,
                      isDark),
                ]),

                const SizedBox(height: 14),

                // Liabilities row
                _breakdownSection('Liabilities', [
                  if (accLiabilities > 0)
                    _breakdownRow('💳 Account Debts',
                        accLiabilities, Colors.red, totalLiabilities),
                  ..._groupByCategory(
                      items.where((i) => i.isLiability).toList(),
                      totalLiabilities,
                      isDark),
                ]),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Quick stats ──────────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _miniStatCard(isDark, '🏦',
                    'Accounts synced', '${accounts.length}', Colors.blue),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _miniStatCard(isDark, '📋',
                    'Manual items', '${items.length}', Colors.purple),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _miniStatCard(isDark, '📈',
                    'Assets', '${items.where((i) => i.isAsset).length}', Colors.green),
              ),
            ],
          ),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  List<Widget> _groupByCategory(
      List<NetWorthItem> items, double total, bool isDark) {
    final map = <String, double>{};
    for (final i in items) {
      map[i.category] = (map[i.category] ?? 0) + i.value;
    }
    final colors = [
      Colors.green, Colors.teal, Colors.blue,
      Colors.indigo, Colors.purple, Colors.orange,
      Colors.red, Colors.pink, Colors.brown,
    ];
    return map.entries.toList().asMap().entries.map((e) {
      final c = colors[e.key % colors.length];
      return _breakdownRow(e.value.key, e.value.value, c, total);
    }).toList();
  }

  Widget _breakdownSection(String label, List<Widget> rows) {
    if (rows.isEmpty) return const SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey)),
        const SizedBox(height: 8),
        ...rows,
      ],
    );
  }

  Widget _breakdownRow(
      String label, double value, Color color, double total) {
    final pct = total > 0 ? value / total : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(label,
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis),
              ),
              Text(
                _balanceHidden ? '••••' : _fmt(value),
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: color.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroStat(String label, String value, Color color) => Column(
        children: [
          Text(label,
              style:
                  const TextStyle(color: Colors.white60, fontSize: 11)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
        ],
      );

  Widget _miniStatCard(
      bool isDark, String emoji, String label, String value, Color color) {
    return _card(isDark,
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: color)),
            Text(label,
                style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                textAlign: TextAlign.center),
          ],
        ));
  }

  // ── Tab 2 & 3: Items list ────────────────────────────────────────────────────
  Widget _buildItemList(bool isDark, List<NetWorthItem> items,
      String type, List<AccountModel> accounts) {
    final isAsset = type == 'asset';
    final color   = isAsset ? Colors.green : Colors.red;
    final total   = items.fold(0.0, (s, i) => s + i.value);

    // For assets tab: show account balances at top
    final accItems = isAsset
        ? accounts.where((a) => !a.isDebt && a.balance > 0).toList()
        : accounts.where((a) => a.isDebt).toList();

    return CustomScrollView(
      slivers: [
        // Total bar
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isAsset ? '💰 Total Assets' : '💳 Total Liabilities',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15),
                ),
                Text(
                  _balanceHidden ? '₹ ••••••' : _fmtFull(total),
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                      color: color),
                ),
              ],
            ),
          ),
        ),

        // Accounts section (auto-synced)
        if (accItems.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  const Icon(Icons.sync, size: 14, color: Colors.blue),
                  const SizedBox(width: 4),
                  Text('Auto-synced from Accounts',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue[700],
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) {
                final acc = accItems[i];
                return _accountTile(isDark, acc, isAsset);
              },
              childCount: accItems.length,
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  const Icon(Icons.edit_note, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text('Manual Items',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ],

        // Manual items
        if (items.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(48),
              child: Column(
                children: [
                  Text(isAsset ? '🏠' : '💳',
                      style: const TextStyle(fontSize: 52)),
                  const SizedBox(height: 16),
                  Text(
                    isAsset
                        ? 'No assets added yet'
                        : 'No liabilities added yet',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isAsset
                        ? 'Add real estate, gold, investments etc.'
                        : 'Add loans, credit card debts etc.',
                    style: TextStyle(
                        color: Colors.grey[500], fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () => _showAddSheet(context, type: type),
                    icon: const Icon(Icons.add),
                    label: Text(
                        isAsset ? 'Add Asset' : 'Add Liability'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) => _itemTile(isDark, items[i], color),
              childCount: items.length,
            ),
          ),

        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }

  Widget _accountTile(bool isDark, AccountModel acc, bool isAsset) {
    final value = acc.balance.abs();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2530) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                shape: BoxShape.circle),
            child: const Icon(Icons.account_balance,
                color: Colors.blue, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(acc.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                Text(acc.typeDisplayName,
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey[500])),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _balanceHidden ? '₹ ••••' : _fmtFull(value),
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isAsset ? Colors.green : Colors.red),
              ),
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('Auto-synced',
                    style: TextStyle(fontSize: 9, color: Colors.blue)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _itemTile(bool isDark, NetWorthItem item, Color color) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2530) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
              color: color.withOpacity(0.1), shape: BoxShape.circle),
          child: Center(
            child: Text(
              _categoryEmoji(item.category),
              style: const TextStyle(fontSize: 18),
            ),
          ),
        ),
        title: Text(item.name,
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 13)),
        subtitle: Text(item.category,
            style: TextStyle(fontSize: 11, color: Colors.grey[500])),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _balanceHidden ? '₹ ••••' : _fmtFull(item.value),
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: color),
            ),
          ],
        ),
        onTap: () => _showEditSheet(context, item),
        onLongPress: () => _confirmDelete(context, item),
      ),
    );
  }

  // ── Add / Edit bottom sheet ────────────────────────────────────────────────
  void _showAddSheet(BuildContext context, {String? type}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ItemSheet(
        svc: _svc,
        initialType: type ?? 'asset',
      ),
    );
  }

  void _showEditSheet(BuildContext context, NetWorthItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ItemSheet(
        svc: _svc,
        item: item,
        initialType: item.type,
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, NetWorthItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${item.name}"?'),
        content: const Text('This item will be removed from your net worth.'),
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
    if (ok == true) await _svc.deleteItem(item.id!);
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────
  Widget _card(bool isDark,
      {required Widget child, EdgeInsets? padding}) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2530) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: child,
    );
  }

  String _categoryEmoji(String cat) {
    switch (cat) {
      case 'Real Estate':      return '🏠';
      case 'Vehicle':          return '🚗';
      case 'Fixed Deposit':    return '🏦';
      case 'Stocks & MF':      return '📈';
      case 'Gold & Jewellery': return '🥇';
      case 'Cash & Bank':      return '💵';
      case 'PPF / EPF':        return '📑';
      case 'Business':         return '💼';
      case 'Home Loan':        return '🏠';
      case 'Car Loan':         return '🚗';
      case 'Personal Loan':    return '👤';
      case 'Education Loan':   return '🎓';
      case 'Credit Card Debt': return '💳';
      case 'Business Loan':    return '💼';
      default:                 return '📦';
    }
  }
}

// ── Add/Edit Item Bottom Sheet ───────────────────────────────────────────────
class _ItemSheet extends StatefulWidget {
  final NetWorthService svc;
  final NetWorthItem? item;
  final String initialType;

  const _ItemSheet({
    required this.svc,
    this.item,
    required this.initialType,
  });

  @override
  State<_ItemSheet> createState() => _ItemSheetState();
}

class _ItemSheetState extends State<_ItemSheet> {
  final _formKey    = GlobalKey<FormState>();
  final _nameCtrl   = TextEditingController();
  final _valueCtrl  = TextEditingController();
  final _noteCtrl   = TextEditingController();

  late String _type;
  String? _category;
  bool _saving = false;

  bool get _isEdit => widget.item != null;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    if (_isEdit) {
      _nameCtrl.text  = widget.item!.name;
      _valueCtrl.text = widget.item!.value.toStringAsFixed(0);
      _noteCtrl.text  = widget.item!.note ?? '';
      _category       = widget.item!.category;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _valueCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  List<String> get _categories =>
      _type == 'asset' ? kAssetCategories : kLiabilityCategories;

  Color get _color =>
      _type == 'asset' ? Colors.green : Colors.red;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_category == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please select a category'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    setState(() => _saving = true);
    try {
      final uid  = widget.svc.hashCode.toString(); // placeholder — service gets real uid
      final now  = DateTime.now();
      final item = NetWorthItem(
        id:        _isEdit ? widget.item!.id : null,
        userId:    _isEdit ? widget.item!.userId : '',
        name:      _nameCtrl.text.trim(),
        category:  _category!,
        type:      _type,
        value:     double.parse(_valueCtrl.text),
        note:      _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        createdAt: _isEdit ? widget.item!.createdAt : now,
        updatedAt: now,
      );

      if (_isEdit) {
        await widget.svc.updateItem(item);
      } else {
        await widget.svc.addItem(item);
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2530) : Colors.white,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),

              Text(
                _isEdit ? 'Edit Item' : 'Add Item',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // Type toggle
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _type = 'asset';
                        _category = null;
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _type == 'asset'
                              ? Colors.green
                              : Colors.green.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: Colors.green.withOpacity(0.4)),
                        ),
                        child: Center(
                          child: Text('💰 Asset',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _type == 'asset'
                                      ? Colors.white
                                      : Colors.green)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _type = 'liability';
                        _category = null;
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _type == 'liability'
                              ? Colors.red
                              : Colors.red.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: Colors.red.withOpacity(0.4)),
                        ),
                        child: Center(
                          child: Text('💳 Liability',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _type == 'liability'
                                      ? Colors.white
                                      : Colors.red)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Name
              TextFormField(
                controller: _nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Name *',
                  hintText: _type == 'asset'
                      ? 'e.g. My Flat, SBI FD, Gold'
                      : 'e.g. Home Loan, HDFC Card',
                  prefixIcon: const Icon(Icons.label_outline),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Name required' : null,
              ),
              const SizedBox(height: 12),

              // Value
              TextFormField(
                controller: _valueCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                ],
                decoration: InputDecoration(
                  labelText: 'Current Value *',
                  prefixText: '₹ ',
                  prefixIcon: const Icon(Icons.currency_rupee),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Value required';
                  if (double.tryParse(v) == null) return 'Enter valid number';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Category
              Text('Category *',
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey[500])),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _categories.map((cat) {
                  final sel = cat == _category;
                  return GestureDetector(
                    onTap: () => setState(() => _category = cat),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: sel
                            ? _color
                            : _color.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: _color.withOpacity(0.3)),
                      ),
                      child: Text(cat,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: sel ? Colors.white : _color)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),

              // Note
              TextFormField(
                controller: _noteCtrl,
                decoration: InputDecoration(
                  labelText: 'Note (optional)',
                  hintText: 'e.g. 10 grams, 2BHK Chennai',
                  prefixIcon:
                      const Icon(Icons.note_alt_outlined),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 20),

              // Save button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : Text(_isEdit ? 'Update Item' : 'Add Item',
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}