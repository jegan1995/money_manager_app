import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/family_service.dart';
import '../models/family_model.dart';
import '../models/transaction_model.dart';

class FamilyDashboardScreen extends StatefulWidget {
  final FamilyModel family;
  const FamilyDashboardScreen({super.key, required this.family});

  @override
  State<FamilyDashboardScreen> createState() =>
      _FamilyDashboardScreenState();
}

class _FamilyDashboardScreenState extends State<FamilyDashboardScreen>
    with SingleTickerProviderStateMixin {
  final _svc = FamilyService();
  late TabController _tab;

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

  List<String> get _memberUids =>
      widget.family.members.map((m) => m.uid).toList();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0D1117) : const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: Text('${widget.family.name} Dashboard'),
        backgroundColor: const Color(0xFF667eea),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tab,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard_outlined, size: 18),
                text: 'Overview'),
            Tab(icon: Icon(Icons.people_outlined, size: 18),
                text: 'Per Member'),
            Tab(icon: Icon(Icons.receipt_long_outlined, size: 18),
                text: 'Transactions'),
          ],
        ),
      ),
      body: StreamBuilder<List<TransactionModel>>(
        stream: _svc.watchFamilyTransactions(_memberUids),
        builder: (context, snap) {
          final all = snap.data ?? [];
          final now = DateTime.now();
          final monthTxns = all.where((t) =>
              t.date.year == now.year &&
              t.date.month == now.month).toList();

          return TabBarView(
            controller: _tab,
            children: [
              _overviewTab(monthTxns, all, isDark),
              _perMemberTab(all, isDark),
              _transactionsTab(all, isDark),
            ],
          );
        },
      ),
    );
  }

  // ── Tab 1: Overview ────────────────────────────────────────────────────────
  Widget _overviewTab(List<TransactionModel> month,
      List<TransactionModel> all, bool isDark) {
    final totalInc = month
        .where((t) => t.type == 'income')
        .fold(0.0, (s, t) => s + t.amount);
    final totalExp = month
        .where((t) => t.type == 'expense')
        .fold(0.0, (s, t) => s + t.amount);
    final savings = totalInc - totalExp;

    // Category breakdown
    final catMap = <String, double>{};
    for (final t in month.where((t) => t.type == 'expense')) {
      catMap[t.category] = (catMap[t.category] ?? 0) + t.amount;
    }
    final sortedCats = catMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return RefreshIndicator(
      onRefresh: () async => setState(() {}),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        children: [
          // Month banner
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF667eea).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              const Icon(Icons.calendar_today,
                  color: Color(0xFF667eea), size: 14),
              const SizedBox(width: 8),
              Text(
                '${DateFormat('MMMM yyyy').format(DateTime.now())} • Family Summary',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF667eea)),
              ),
            ]),
          ),
          const SizedBox(height: 14),

          // 3 summary cards
          Row(children: [
            _sumCard('Income',  totalInc,
                const Color(0xFF2E7D32), Icons.arrow_upward, isDark),
            const SizedBox(width: 10),
            _sumCard('Expense', totalExp,
                const Color(0xFFC62828), Icons.arrow_downward, isDark),
            const SizedBox(width: 10),
            _sumCard('Savings', savings,
                savings >= 0
                    ? const Color(0xFF1565C0)
                    : const Color(0xFFE65100),
                savings >= 0
                    ? Icons.savings_outlined
                    : Icons.trending_down,
                isDark),
          ]),
          const SizedBox(height: 14),

          // Members count
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2530) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(
                  color: Colors.black.withOpacity(0.04), blurRadius: 6)],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _miniStat('Members',
                    '${widget.family.members.length}', Icons.people),
                _miniStat('Transactions',
                    '${month.length}', Icons.receipt_long),
                _miniStat('Avg/day',
                    _fmt(totalExp / DateTime.now().day),
                    Icons.today),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Top categories
          if (sortedCats.isNotEmpty) ...[
            _label('Top Family Expenses', isDark),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E2530) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(
                    color: Colors.black.withOpacity(0.04), blurRadius: 6)],
              ),
              child: Column(
                children: sortedCats.take(6).toList().asMap().entries.map((e) {
                  final pct = totalExp > 0
                      ? e.value.value / totalExp
                      : 0.0;
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                    child: Column(children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(e.value.key,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500)),
                          Text(
                            '${_fmt(e.value.value)}  ${(pct * 100).toStringAsFixed(1)}%',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFC62828)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct.clamp(0.0, 1.0),
                          minHeight: 5,
                          backgroundColor: Colors.grey.shade100,
                          color: const Color(0xFF667eea),
                        ),
                      ),
                    ]),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Tab 2: Per Member ──────────────────────────────────────────────────────
  Widget _perMemberTab(List<TransactionModel> all, bool isDark) {
    final now = DateTime.now();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      children: widget.family.members.map((member) {
        final memberTxns = all.where((t) =>
            t.userId == member.uid &&
            t.date.year == now.year &&
            t.date.month == now.month).toList();

        final inc = memberTxns
            .where((t) => t.type == 'income')
            .fold(0.0, (s, t) => s + t.amount);
        final exp = memberTxns
            .where((t) => t.type == 'expense')
            .fold(0.0, (s, t) => s + t.amount);
        final color = _hexColor(member.avatarColor ?? '#667eea');

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2530) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(
                color: Colors.black.withOpacity(0.05), blurRadius: 8)],
            border: Border(left: BorderSide(color: color, width: 4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: color.withOpacity(0.15),
                  child: Text(
                    member.name.isNotEmpty
                        ? member.name[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 16),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(member.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                    Text(member.role.label,
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[400])),
                  ],
                )),
                Text('${memberTxns.length} txns',
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey[400])),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _memberStat(
                    'Income', inc, const Color(0xFF2E7D32))),
                Expanded(child: _memberStat(
                    'Expense', exp, const Color(0xFFC62828))),
                Expanded(child: _memberStat(
                    'Savings', inc - exp,
                    inc - exp >= 0
                        ? const Color(0xFF1565C0)
                        : const Color(0xFFE65100))),
              ]),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ── Tab 3: All Transactions ────────────────────────────────────────────────
  Widget _transactionsTab(List<TransactionModel> all, bool isDark) {
    if (all.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined,
                size: 64, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text('No family transactions yet',
                style: TextStyle(
                    color: Colors.grey[400], fontSize: 14)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      itemCount: all.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        final t = all[i];
        final member = widget.family.members
            .firstWhere((m) => m.uid == t.userId,
                orElse: () => FamilyMember(
                    uid: t.userId,
                    name: 'Unknown',
                    email: '',
                    role: FamilyRole.member,
                    joinedAt: DateTime.now()));
        final memberColor =
            _hexColor(member.avatarColor ?? '#667eea');
        final isExp = t.type == 'expense';
        final amtColor = isExp
            ? const Color(0xFFC62828)
            : const Color(0xFF2E7D32);

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2530) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(
                color: Colors.black.withOpacity(0.04), blurRadius: 5)],
          ),
          child: Row(children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: amtColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                  isExp ? Icons.arrow_downward : Icons.arrow_upward,
                  color: amtColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.note ?? t.category,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Row(children: [
                  CircleAvatar(
                    radius: 7,
                    backgroundColor: memberColor.withOpacity(0.15),
                    child: Text(
                      member.name.isNotEmpty
                          ? member.name[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                          color: memberColor,
                          fontSize: 7,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${member.name}  •  ${t.category}  •  ${DateFormat('dd MMM').format(t.date)}',
                    style: TextStyle(
                        fontSize: 10, color: Colors.grey[400]),
                  ),
                ]),
              ],
            )),
            Text(
              '${isExp ? '-' : '+'}${_fmt(t.amount)}',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: amtColor),
            ),
          ]),
        );
      },
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Widget _sumCard(String label, double amt,
      Color color, IconData icon, bool isDark) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2530) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border(left: BorderSide(color: color, width: 3)),
            boxShadow: [BoxShadow(
                color: Colors.black.withOpacity(0.04), blurRadius: 6)],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Row(children: [
              Icon(icon, color: color, size: 12),
              const SizedBox(width: 3),
              Text(label,
                  style: TextStyle(
                      fontSize: 9, color: Colors.grey[500])),
            ]),
            const SizedBox(height: 4),
            Text(_fmt(amt.abs()),
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: color)),
          ]),
        ),
      );

  Widget _miniStat(String label, String value, IconData icon) =>
      Column(children: [
        Icon(icon, color: const Color(0xFF667eea), size: 20),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label,
            style: TextStyle(fontSize: 10, color: Colors.grey[400])),
      ]);

  Widget _memberStat(String label, double value, Color color) =>
      Column(children: [
        Text(label,
            style: TextStyle(fontSize: 10, color: Colors.grey[400])),
        const SizedBox(height: 2),
        Text(_fmt(value.abs()),
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13, color: color)),
      ]);

  Widget _label(String text, bool isDark) => Text(text,
      style: const TextStyle(
          fontWeight: FontWeight.bold, fontSize: 14));

  String _fmt(double v) {
    final abs = v.abs();
    if (abs >= 10000000)
      return '₹${(abs / 10000000).toStringAsFixed(1)}Cr';
    if (abs >= 100000)
      return '₹${(abs / 100000).toStringAsFixed(1)}L';
    return '₹${NumberFormat('#,##,##0').format(abs)}';
  }

  Color _hexColor(String hex) {
    try {
      return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      return const Color(0xFF667eea);
    }
  }
}