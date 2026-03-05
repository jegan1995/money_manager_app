import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/account_model.dart';
import '../models/transaction_model.dart';
import '../services/transaction_service.dart';
import '../services/account_service.dart';
import 'add_account_screen.dart';
import 'add_transaction_screen.dart';

class AccountDetailScreen extends StatefulWidget {
  final AccountModel account;
  const AccountDetailScreen({super.key, required this.account});
  @override
  State<AccountDetailScreen> createState() => _AccountDetailScreenState();
}

class _AccountDetailScreenState extends State<AccountDetailScreen>
    with SingleTickerProviderStateMixin {
  final _txnSvc = TransactionService();
  final _accSvc = AccountService();
  late TabController _tabs;

  String _period = 'Monthly';
  DateTime _date = DateTime.now();

  bool get _isCreditCard => widget.account.type == 'credit_card';
  int get _billDay => widget.account.billDate ?? 1;

  (DateTime, DateTime) get _billingCycle {
    final now = _date;
    final bd = _billDay;
    final prevMonth = now.month == 1 ? 12 : now.month - 1;
    final prevYear  = now.month == 1 ? now.year - 1 : now.year;
    if (now.day >= bd) {
      final cycleStart = DateTime(prevYear, prevMonth, bd);
      final cycleEnd   = DateTime(now.year, now.month, bd).subtract(const Duration(days: 1));
      return (cycleStart, cycleEnd);
    } else {
      final ppMonth  = prevMonth == 1 ? 12 : prevMonth - 1;
      final ppYear   = prevMonth == 1 ? prevYear - 1 : prevYear;
      final cycleStart = DateTime(ppYear, ppMonth, bd);
      final cycleEnd   = DateTime(prevYear, prevMonth, bd).subtract(const Duration(days: 1));
      return (cycleStart, cycleEnd);
    }
  }

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this, initialIndex: 1);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  String _fmt(double v) {
    final a = v.abs();
    if (a >= 100000) return '₹${(a / 100000).toStringAsFixed(1)}L';
    if (a >= 1000)   return '₹${(a / 1000).toStringAsFixed(1)}K';
    return '₹${a.toStringAsFixed(0)}';
  }

  IconData _icon(String type) {
    switch (type) {
      case 'bank':        return Icons.account_balance;
      case 'cash':        return Icons.money;
      case 'card':
      case 'credit_card': return Icons.credit_card;
      case 'wallet':      return Icons.account_balance_wallet;
      case 'loan':        return Icons.receipt_long;
      default:            return Icons.account_balance_wallet;
    }
  }

  List<Color> _gradient(String name) {
    final sets = [
      [const Color(0xFF667eea), const Color(0xFF764ba2)],
      [const Color(0xFF11998e), const Color(0xFF38ef7d)],
      [const Color(0xFF4facfe), const Color(0xFF00f2fe)],
      [const Color(0xFFf093fb), const Color(0xFFf5576c)],
      [const Color(0xFFf77062), const Color(0xFFfe5196)],
      [const Color(0xFF43e97b), const Color(0xFF38f9d7)],
    ];
    return sets[name.hashCode.abs() % sets.length];
  }

  bool _inPeriod(DateTime d) {
    if (_isCreditCard && widget.account.billDate != null) {
      final cycle = _billingCycle;
      return !d.isBefore(cycle.$1) &&
             !d.isAfter(cycle.$2.copyWith(hour: 23, minute: 59, second: 59));
    }
    final now = _date;
    switch (_period) {
      case 'Daily':
        return d.year == now.year && d.month == now.month && d.day == now.day;
      case 'Monthly':
        return d.year == now.year && d.month == now.month;
      case 'Annually':
        return d.year == now.year;
    }
    return true;
  }

  bool _belongsToAccount(TransactionModel t) {
    return t.fromAccount == widget.account.id ||
        t.toAccount == widget.account.id;
  }

  String _dateLabel() {
    if (_isCreditCard && widget.account.billDate != null) {
      final cycle = _billingCycle;
      final fmt = DateFormat('d MMM');
      return '\${fmt.format(cycle.\$1)} – \${fmt.format(cycle.\$2)}';
    }
    switch (_period) {
      case 'Daily':   return DateFormat('dd MMM yyyy').format(_date);
      case 'Monthly': return DateFormat('MMMM yyyy').format(_date);
      case 'Annually': return _date.year.toString();
    }
    return '';
  }

  void _prev() => setState(() {
    if (_isCreditCard && widget.account.billDate != null) {
      _date = DateTime(_date.year, _date.month - 1, _date.day);
      return;
    }
    switch (_period) {
      case 'Daily':    _date = _date.subtract(const Duration(days: 1)); break;
      case 'Monthly':  _date = DateTime(_date.year, _date.month - 1); break;
      case 'Annually': _date = DateTime(_date.year - 1); break;
    }
  });

  void _next() => setState(() {
    if (_isCreditCard && widget.account.billDate != null) {
      _date = DateTime(_date.year, _date.month + 1, _date.day);
      return;
    }
    switch (_period) {
      case 'Daily':    _date = _date.add(const Duration(days: 1)); break;
      case 'Monthly':  _date = DateTime(_date.year, _date.month + 1); break;
      case 'Annually': _date = DateTime(_date.year + 1); break;
    }
  });

  IconData _catIcon(String c) {
    switch (c.toLowerCase()) {
      case 'food': case 'dining': return Icons.restaurant;
      case 'shopping':  return Icons.shopping_bag;
      case 'transport': case 'travel': return Icons.directions_car;
      case 'health':    return Icons.medical_services;
      case 'entertainment': return Icons.movie;
      case 'bills':     return Icons.receipt;
      case 'education': return Icons.school;
      case 'salary':    return Icons.work;
      case 'transfer':  return Icons.swap_horiz;
      case 'groceries': return Icons.local_grocery_store;
      default:          return Icons.attach_money;
    }
  }

  Color _catColor(String c) {
    switch (c.toLowerCase()) {
      case 'food': case 'dining': return const Color(0xFFFF7043);
      case 'shopping':  return const Color(0xFFAB47BC);
      case 'transport': return const Color(0xFF42A5F5);
      case 'health':    return const Color(0xFF26A69A);
      case 'entertainment': return const Color(0xFFEF5350);
      case 'bills':     return const Color(0xFF78909C);
      case 'education': return const Color(0xFF5C6BC0);
      case 'salary':    return const Color(0xFF66BB6A);
      case 'transfer':  return const Color(0xFF42A5F5);
      default:          return const Color(0xFF667eea);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final grad   = _gradient(widget.account.name);
    final bg     = isDark ? const Color(0xFF0D1117) : const Color(0xFFF0F4FF);
    final card   = isDark ? const Color(0xFF1E2530) : Colors.white;

    return Scaffold(
      backgroundColor: bg,
      body: StreamBuilder<List<AccountModel>>(
        stream: _accSvc.getAccountsList(),
        builder: (ctx, accSnap) {
          final liveAcc = accSnap.data
              ?.firstWhere((a) => a.id == widget.account.id,
                  orElse: () => widget.account) ??
              widget.account;

          return NestedScrollView(
            headerSliverBuilder: (ctx, _) => [
              SliverAppBar(
                expandedHeight: 220,
                pinned: true,
                backgroundColor: grad[0],
                foregroundColor: Colors.white,
                // ── Edit button in app bar ──────────────────────────────
                actions: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Edit Account',
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              AddAccountScreen(account: widget.account),
                        ),
                      );
                    },
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: grad,
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
                            Row(children: [
                              Container(
                                width: 48, height: 48,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(_icon(liveAcc.type),
                                    color: Colors.white, size: 24),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(liveAcc.name,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18)),
                                  Text(liveAcc.typeDisplayName,
                                      style: TextStyle(
                                          color: Colors.white.withOpacity(0.8),
                                          fontSize: 12)),
                                ],
                              ),
                            ]),
                            const SizedBox(height: 16),
                            Text(
                              '${liveAcc.balance < 0 ? '-' : ''}${_fmt(liveAcc.balance)}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -1),
                            ),
                            Text('Current Balance',
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // ── Period tabs ──────────────────────────────────────────
                bottom: TabBar(
                  controller: _tabs,
                  indicatorColor: Colors.white,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white60,
                  tabs: const [
                    Tab(text: 'Daily'),
                    Tab(text: 'Monthly'),
                    Tab(text: 'Annually'),
                  ],
                  onTap: (i) => setState(() {
                    _period = ['Daily', 'Monthly', 'Annually'][i];
                    _date = DateTime.now();
                  }),
                ),
              ),
            ],
            body: StreamBuilder<List<TransactionModel>>(
              stream: _txnSvc.getTransactions(),
              builder: (ctx, txnSnap) {
                final all = txnSnap.data ?? [];
                final filtered = all
                    .where((t) => _belongsToAccount(t) && _inPeriod(t.date))
                    .toList()
                  ..sort((a, b) => b.date.compareTo(a.date));

                double deposit = 0, withdrawal = 0;
                for (final t in filtered) {
                  if (t.type == 'income' && t.toAccount == widget.account.id) {
                    deposit += t.amount;
                  } else if (t.type == 'expense' &&
                      t.fromAccount == widget.account.id) {
                    withdrawal += t.amount;
                  } else if (t.type == 'transfer') {
                    if (t.toAccount == widget.account.id) deposit += t.amount;
                    if (t.fromAccount == widget.account.id)
                      withdrawal += t.amount;
                  }
                }

                return Column(children: [
                  // ── Date nav + summary ─────────────────────────────────
                  Container(
                    color: isDark ? const Color(0xFF1A1F2B) : Colors.white,
                    child: Column(children: [
                      // CC billing info
                      if (_isCreditCard && widget.account.billDate != null) ...[
                        Container(
                          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.purple.withOpacity(0.07),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: Colors.purple.withOpacity(0.2)),
                          ),
                          child: Row(children: [
                            const Icon(Icons.credit_card_rounded,
                                color: Colors.purple, size: 14),
                            const SizedBox(width: 8),
                            Text(
                              'Statement: ${widget.account.billDate}th'
                              '${widget.account.dueDate != null ? '   Due: ${widget.account.dueDate}th' : ''}',
                              style: TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.purple[200] : Colors.purple[700]),
                            ),
                          ]),
                        ),
                        const SizedBox(height: 4),
                      ],
                      // Date navigation
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chevron_left),
                              onPressed: _prev,
                            ),
                            Text(_dateLabel(),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14)),
                            IconButton(
                              icon: const Icon(Icons.chevron_right),
                              onPressed: _next,
                            ),
                          ],
                        ),
                      ),
                      // Summary strip
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _summaryChip('In', deposit,
                                const Color(0xFF2E7D32)),
                            Container(
                                width: 1, height: 30,
                                color: Colors.grey.withOpacity(0.2)),
                            _summaryChip('Out', withdrawal,
                                const Color(0xFFC62828)),
                            Container(
                                width: 1, height: 30,
                                color: Colors.grey.withOpacity(0.2)),
                            _summaryChip('Net', deposit - withdrawal,
                                deposit >= withdrawal
                                    ? const Color(0xFF2E7D32)
                                    : const Color(0xFFC62828)),
                            Container(
                                width: 1, height: 30,
                                color: Colors.grey.withOpacity(0.2)),
                            _summaryChip('Balance', liveAcc.balance,
                                liveAcc.balance >= 0
                                    ? const Color(0xFF2E7D32)
                                    : const Color(0xFFC62828)),
                          ],
                        ),
                      ),
                    ]),
                  ),

                  // ── Transactions list ────────────────────────────────
                  Expanded(
                    child: filtered.isEmpty
                        ? _empty(isDark)
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                            itemCount: _groupByDate(filtered).length,
                            itemBuilder: (ctx, i) {
                              final groups = _groupByDate(filtered);
                              final date = groups.keys.elementAt(i);
                              return _dateGroup(
                                  date, groups[date]!, card, isDark);
                            },
                          ),
                  ),
                ]);
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddTransactionScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Add Transaction'),
        backgroundColor: grad[0],
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _summaryChip(String label, double amount, Color color) =>
      Column(children: [
        Text(label,
            style: TextStyle(fontSize: 10, color: Colors.grey[500])),
        const SizedBox(height: 2),
        Text(_fmt(amount),
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: color)),
      ]);

  Map<DateTime, List<TransactionModel>> _groupByDate(
      List<TransactionModel> txns) {
    final map = <DateTime, List<TransactionModel>>{};
    for (final t in txns) {
      final key = DateTime(t.date.year, t.date.month, t.date.day);
      map.putIfAbsent(key, () => []).add(t);
    }
    return Map.fromEntries(
        map.entries.toList()..sort((a, b) => b.key.compareTo(a.key)));
  }

  Widget _dateGroup(DateTime date, List<TransactionModel> txns,
      Color card, bool isDark) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    String label;
    if (date == today)     label = 'Today';
    else if (date == yesterday) label = 'Yesterday';
    else label = DateFormat('EEE, d MMM').format(date);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey[500])),
      ),
      Container(
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Column(
          children: txns.asMap().entries.map((e) {
            return _txnTile(e.value, isDark, e.key == txns.length - 1);
          }).toList(),
        ),
      ),
      const SizedBox(height: 10),
    ]);
  }

  Widget _txnTile(TransactionModel txn, bool isDark, bool isLast) {
    final isIn = txn.type == 'income' ||
        (txn.type == 'transfer' && txn.toAccount == widget.account.id);
    final isTransfer = txn.type == 'transfer';
    final amtColor = isIn
        ? const Color(0xFF2E7D32)
        : isTransfer
            ? const Color(0xFF1565C0)
            : const Color(0xFFC62828);
    final cc = _catColor(txn.category);

    return Column(children: [
      InkWell(
        borderRadius: isLast
            ? const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16))
            : BorderRadius.zero,
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddTransactionScreen(transaction: txn),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: cc.withOpacity(0.1),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(_catIcon(txn.category), color: cc, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  txn.note?.isNotEmpty == true ? txn.note! : txn.category,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: cc.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(txn.category,
                        style: TextStyle(fontSize: 9, color: cc,
                            fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 6),
                  Text(DateFormat('h:mm a').format(txn.date),
                      style: TextStyle(
                          fontSize: 10, color: Colors.grey[400])),
                ]),
              ],
            )),
            Text(
              '${isIn ? '+' : isTransfer ? '↔' : '-'}${_fmt(txn.amount)}',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14, color: amtColor),
            ),
          ]),
        ),
      ),
      if (!isLast)
        Divider(height: 1, indent: 66,
            color: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.grey.shade100),
    ]);
  }

  Widget _empty(bool isDark) => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center,
            children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFF667eea).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.receipt_long_outlined,
                color: Color(0xFF667eea), size: 30),
          ),
          const SizedBox(height: 12),
          const Text('No transactions',
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 4),
          Text('for $_period — ${_dateLabel()}',
              style: TextStyle(fontSize: 12, color: Colors.grey[400])),
        ]),
      );
}