import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction_model.dart';
import '../models/account_model.dart';
import '../services/transaction_service.dart';
import '../services/account_service.dart';
import 'add_transaction_screen.dart';
import 'transactions_screen.dart';
import 'search_transactions_screen.dart';
import 'transaction_detail_screen.dart';
import '../widgets/slide_page_route.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TransactionService _transactionService = TransactionService();
  final AccountService _accountService = AccountService();

  String _period = 'Monthly';
  DateTime _date = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF121212) : const Color(0xFFF0F2F5),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(isDark),
            _buildBalanceCard(isDark),
            _buildPeriodTabs(isDark),
            _buildDateNavRow(isDark),
            _buildSummaryRow(isDark),
            Expanded(child: _buildTransactionList(isDark)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          SlidePageRoute(page: const AddTransactionScreen()),
        ).then((_) => setState(() {})),
        backgroundColor: Theme.of(context).colorScheme.primary,
        elevation: 4,
        child: const Icon(Icons.add, color: Colors.white, size: 24),
      ),
    );
  }

  Widget _buildTopBar(bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Good ${_greeting()}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.grey[900],
                ),
              ),
              Text(
                DateFormat('EEE, d MMM yyyy').format(DateTime.now()),
                style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.grey[500] : Colors.grey[500]),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            icon: Icon(Icons.search,
                size: 22,
                color: isDark ? Colors.grey[400] : Colors.grey[700]),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const SearchTransactionsScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard(bool isDark) {
    return StreamBuilder<List<AccountModel>>(
      stream: _accountService.getAccounts(),
      builder: (context, snap) {
        final total =
            (snap.data ?? []).fold<double>(0, (s, a) => s + a.balance);
        return Container(
          width: double.infinity,
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Balance',
                    style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.grey[500] : Colors.grey[500]),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '₹${_fmt(total)}',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.grey[900],
                    ),
                  ),
                ],
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => TransactionsScreen()),
                ),
                icon: const Icon(Icons.list, size: 14),
                label: const Text('All', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: Size.zero,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPeriodTabs(bool isDark) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      child: Row(
        children: ['Daily', 'Monthly', 'Annually'].map((p) {
          final selected = _period == p;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() {
                _period = p;
                _date = DateTime.now();
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: selected ? primary : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                ),
                child: Text(
                  p,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        selected ? FontWeight.bold : FontWeight.normal,
                    color: selected
                        ? primary
                        : (isDark ? Colors.grey[500] : Colors.grey[500]),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDateNavRow(bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF252530) : const Color(0xFFEEF0F5),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: Icon(Icons.chevron_left,
                size: 22,
                color: isDark ? Colors.grey[400] : Colors.grey[700]),
            onPressed: _prev,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
          ),
          const SizedBox(width: 8),
          Text(
            _dateLabel(),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.grey[800],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.chevron_right,
                size: 22,
                color: isDark ? Colors.grey[400] : Colors.grey[700]),
            onPressed: _next,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(bool isDark) {
    return StreamBuilder<List<TransactionModel>>(
      stream: _transactionService.getTransactions(),
      builder: (context, snap) {
        double income = 0, expense = 0;
        if (snap.hasData) {
          for (final t in _filtered(snap.data!)) {
            if (t.type == 'income') income += t.amount;
            if (t.type == 'expense') expense += t.amount;
          }
        }
        final total = income - expense;

        return Container(
          color: isDark ? const Color(0xFF252530) : const Color(0xFFEEF0F5),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              _summaryItem('Income', income, const Color(0xFF42A5F5), isDark),
              _vDiv(isDark),
              _summaryItem('Expense', expense, const Color(0xFFEF5350), isDark),
              _vDiv(isDark),
              _summaryItem(
                'Total',
                total,
                total >= 0 ? const Color(0xFF66BB6A) : const Color(0xFFEF5350),
                isDark,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _summaryItem(String label, double amount, Color color, bool isDark) {
    return Expanded(
      child: Column(
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  color: isDark ? Colors.grey[500] : Colors.grey[500])),
          const SizedBox(height: 3),
          Text(
            '₹${_fmt(amount.abs())}',
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _vDiv(bool isDark) => Container(
        width: 1,
        height: 28,
        color: isDark ? Colors.white12 : Colors.grey[300],
      );

  Widget _buildTransactionList(bool isDark) {
    return StreamBuilder<List<TransactionModel>>(
      stream: _transactionService.getTransactions(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snap.hasData) return _emptyState(isDark);

        final list = _filtered(snap.data!);
        if (list.isEmpty) return _emptyState(isDark);

        // Group by date
        final grouped = <String, List<TransactionModel>>{};
        for (final t in list) {
          final key = DateFormat('yyyy-MM-dd').format(t.date);
          grouped.putIfAbsent(key, () => []).add(t);
        }
        final sortedDates = grouped.keys.toList()
          ..sort((a, b) => b.compareTo(a));

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 80),
          itemCount: sortedDates.length,
          itemBuilder: (context, i) {
            final key = sortedDates[i];
            final txns = grouped[key]!;
            final date = DateTime.parse(key);

            double dayIncome = 0, dayExpense = 0;
            for (final t in txns) {
              if (t.type == 'income') dayIncome += t.amount;
              if (t.type == 'expense') dayExpense += t.amount;
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date header row
                Container(
                  color: isDark
                      ? const Color(0xFF1A1A2A)
                      : const Color(0xFFE8EAF0),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Column(
                          children: [
                            Text(
                              DateFormat('d').format(date),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            Text(
                              DateFormat('EEE').format(date).toUpperCase(),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 9,
                                color: isDark
                                    ? Colors.grey[500]
                                    : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          DateFormat('MMM yyyy').format(date),
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ),
                      if (dayIncome > 0) ...[
                        Text(
                          '+₹${_fmt(dayIncome)}',
                          style: const TextStyle(
                              color: Color(0xFF42A5F5),
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 6),
                      ],
                      if (dayExpense > 0)
                        Text(
                          '-₹${_fmt(dayExpense)}',
                          style: const TextStyle(
                              color: Color(0xFFEF5350),
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                    ],
                  ),
                ),
                // Transactions
                Container(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  child:
                      Column(children: txns.map((t) => _buildTile(t, isDark)).toList()),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildTile(TransactionModel txn, bool isDark) {
    final isIncome = txn.type == 'income';
    final isTransfer = txn.type == 'transfer';

    Color amountColor;
    Color iconBg;
    IconData iconData;

    if (isTransfer) {
      amountColor = const Color(0xFF42A5F5);
      iconBg = Colors.blue.withOpacity(0.12);
      iconData = Icons.swap_horiz;
    } else if (isIncome) {
      amountColor = const Color(0xFF42A5F5);
      iconBg = Colors.blue.withOpacity(0.12);
      iconData = _categoryIcon(txn.category);
    } else {
      amountColor = const Color(0xFFEF5350);
      iconBg = Colors.red.withOpacity(0.12);
      iconData = _categoryIcon(txn.category);
    }

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => TransactionDetailScreen(transaction: txn)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(iconData, color: amountColor, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    txn.category,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                      color: isDark ? Colors.white : Colors.grey[900],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if ((txn.note?.isNotEmpty ?? false) ||
                      (txn.subcategory?.isNotEmpty ?? false))
                    Text(
                      txn.subcategory?.isNotEmpty == true
                          ? txn.subcategory!
                          : txn.note!,
                      style: TextStyle(
                          fontSize: 11,
                          color:
                              isDark ? Colors.grey[600] : Colors.grey[500]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isIncome ? '+' : isTransfer ? '' : '-'}₹${_fmt(txn.amount)}',
                  style: TextStyle(
                    color: amountColor,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  DateFormat('h:mm a').format(txn.date),
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.grey[600] : Colors.grey[400],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long,
              size: 56, color: isDark ? Colors.grey[700] : Colors.grey[300]),
          const SizedBox(height: 12),
          Text(
            'No transactions for',
            style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey[600] : Colors.grey[500]),
          ),
          Text(
            _dateLabel(),
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey[500] : Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to add a transaction',
            style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey[700] : Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  List<TransactionModel> _filtered(List<TransactionModel> all) {
    return all.where((t) {
      switch (_period) {
        case 'Daily':
          return t.date.year == _date.year &&
              t.date.month == _date.month &&
              t.date.day == _date.day;
        case 'Monthly':
          return t.date.year == _date.year && t.date.month == _date.month;
        case 'Annually':
          return t.date.year == _date.year;
        default:
          return true;
      }
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  void _prev() => setState(() {
        switch (_period) {
          case 'Daily':
            _date = _date.subtract(const Duration(days: 1));
            break;
          case 'Monthly':
            _date = DateTime(_date.year, _date.month - 1);
            break;
          case 'Annually':
            _date = DateTime(_date.year - 1);
            break;
        }
      });

  void _next() => setState(() {
        switch (_period) {
          case 'Daily':
            _date = _date.add(const Duration(days: 1));
            break;
          case 'Monthly':
            _date = DateTime(_date.year, _date.month + 1);
            break;
          case 'Annually':
            _date = DateTime(_date.year + 1);
            break;
        }
      });

  String _dateLabel() {
    switch (_period) {
      case 'Daily':
        return DateFormat('MMM d, yyyy').format(_date);
      case 'Monthly':
        return DateFormat('MMMM yyyy').format(_date);
      case 'Annually':
        return DateFormat('yyyy').format(_date);
      default:
        return '';
    }
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Morning';
    if (h < 17) return 'Afternoon';
    return 'Evening';
  }

  String _fmt(double amount) {
    if (amount >= 10000000) {
      return '${(amount / 10000000).toStringAsFixed(1)}Cr';
    }
    if (amount >= 100000) return '${(amount / 100000).toStringAsFixed(1)}L';
    if (amount >= 1000) {
      final r = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
      return amount.toInt().toString().replaceAllMapped(r, (m) => '${m[1]},');
    }
    return amount.toStringAsFixed(0);
  }

  IconData _categoryIcon(String cat) {
    switch (cat) {
      case 'Food & Dining':
        return Icons.restaurant;
      case 'Transportation':
        return Icons.directions_car;
      case 'Shopping':
        return Icons.shopping_bag;
      case 'Entertainment':
        return Icons.movie;
      case 'Bills & Utilities':
        return Icons.receipt;
      case 'Healthcare':
        return Icons.local_hospital;
      case 'Education':
        return Icons.school;
      case 'Personal Care':
        return Icons.spa;
      case 'Travel':
        return Icons.flight;
      case 'Salary':
        return Icons.account_balance_wallet;
      case 'Business':
        return Icons.business;
      case 'Investments':
        return Icons.trending_up;
      case 'Gifts':
        return Icons.card_giftcard;
      default:
        return Icons.category;
    }
  }
}