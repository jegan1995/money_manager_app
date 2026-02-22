import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/account_model.dart';
import '../models/transaction_model.dart';
import '../services/transaction_service.dart';
import '../services/account_service.dart';
import 'transaction_detail_screen.dart';
import 'add_account_screen.dart';
import 'add_transaction_screen.dart';

class AccountDetailScreen extends StatefulWidget {
  final AccountModel account;

  const AccountDetailScreen({super.key, required this.account});

  @override
  State<AccountDetailScreen> createState() => _AccountDetailScreenState();
}

class _AccountDetailScreenState extends State<AccountDetailScreen> {
  final TransactionService _transactionService = TransactionService();
  final AccountService _accountService = AccountService();

  // Default to Monthly (so user sees all this month's transactions, not just today)
  String _selectedPeriod = 'Monthly';
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final color = _accountColor(widget.account.type);

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.account.name,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AddAccountScreen(account: widget.account),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Balance Header ──────────────────────────────────────────────
          Container(
            width: double.infinity,
            color: color,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                Icon(_accountIcon(widget.account.type),
                    size: 36, color: Colors.white.withOpacity(0.9)),
                const SizedBox(height: 6),
                Text(
                  widget.account.typeDisplayName,
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.75), fontSize: 12),
                ),
                const SizedBox(height: 6),
                // Live balance from Firestore
                StreamBuilder<List<AccountModel>>(
                  stream: _accountService.getAccounts(),
                  builder: (context, snapshot) {
                    double balance = widget.account.balance;
                    if (snapshot.hasData) {
                      try {
                        final acc = snapshot.data!
                            .firstWhere((a) => a.id == widget.account.id);
                        balance = acc.balance;
                      } catch (_) {}
                    }
                    return Text(
                      '₹${_fmt(balance)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // ── Period Tabs ─────────────────────────────────────────────────
          Container(
            color: Color.lerp(color, Colors.black, 0.25),
            child: Row(
              children: ['Daily', 'Monthly', 'Annually']
                  .map((p) => _buildPeriodTab(p, color))
                  .toList(),
            ),
          ),

          // ── Date Navigation ─────────────────────────────────────────────
          Container(
            color: Color.lerp(color, Colors.black, 0.35),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, color: Colors.white, size: 22),
                  onPressed: _previousPeriod,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  padding: EdgeInsets.zero,
                ),
                Text(
                  _getDateLabel(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right, color: Colors.white, size: 22),
                  onPressed: _nextPeriod,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),

          // ── Income / Expense summary bar ────────────────────────────────
          _buildSummaryBar(color),

          // ── Transactions List ───────────────────────────────────────────
          Expanded(child: _buildTransactionsList()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AddTransactionScreen()),
        ).then((_) => setState(() {})),
        backgroundColor: color,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  // ── Period Tab ────────────────────────────────────────────────────────────

  Widget _buildPeriodTab(String period, Color color) {
    final isSelected = _selectedPeriod == period;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _selectedPeriod = period;
          _selectedDate = DateTime.now();
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? Colors.white : Colors.transparent,
                width: 2.5,
              ),
            ),
          ),
          child: Text(
            period,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white.withOpacity(0.5),
              fontWeight:
                  isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  // ── Summary Bar ───────────────────────────────────────────────────────────

  Widget _buildSummaryBar(Color color) {
    return StreamBuilder<List<TransactionModel>>(
      stream: _transactionService.getTransactions(),
      builder: (context, snapshot) {
        double deposit = 0, withdrawal = 0;

        if (snapshot.hasData) {
          for (final txn in _filterByPeriodAndAccount(snapshot.data!)) {
            if (_isDepositFor(txn)) {
              deposit += txn.amount;
            } else {
              withdrawal += txn.amount;
            }
          }
        }

        return Container(
          color: Color.lerp(color, Colors.black, 0.45),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: _summaryItem(
                    'Deposit', deposit, const Color(0xFF64B5F6)),
              ),
              Container(width: 1, height: 28, color: Colors.white24),
              Expanded(
                child: _summaryItem(
                    'Withdrawal', withdrawal, const Color(0xFFEF9A9A)),
              ),
              Container(width: 1, height: 28, color: Colors.white24),
              Expanded(
                child: _summaryItem(
                  'Total',
                  deposit - withdrawal,
                  (deposit - withdrawal) >= 0
                      ? const Color(0xFF81C784)
                      : const Color(0xFFEF9A9A),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _summaryItem(String label, double amount, Color color) {
    final isNeg = amount < 0;
    return Column(
      children: [
        Text(label,
            style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 10,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        Text(
          '${isNeg ? '-' : ''}₹${_fmt(amount.abs())}',
          style: TextStyle(
              color: color, fontSize: 13, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  // ── Transactions List ─────────────────────────────────────────────────────

  Widget _buildTransactionsList() {
    return StreamBuilder<List<TransactionModel>>(
      stream: _transactionService.getTransactions(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }

        if (!snapshot.hasData) {
          return _emptyState();
        }

        final filtered = _filterByPeriodAndAccount(snapshot.data!);

        if (filtered.isEmpty) {
          return _emptyState();
        }

        // Group by date
        final grouped = <String, List<TransactionModel>>{};
        for (final txn in filtered) {
          final key = DateFormat('yyyy-MM-dd').format(txn.date);
          grouped.putIfAbsent(key, () => []).add(txn);
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

            double dayDeposit = 0, dayWithdraw = 0;
            for (final t in txns) {
              if (_isDepositFor(t)) {
                dayDeposit += t.amount;
              } else {
                dayWithdraw += t.amount;
              }
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date header row
                Container(
                  color: const Color(0xFF12122A),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 6),
                  child: Row(
                    children: [
                      // Date box
                      Container(
                        width: 36,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Column(
                          children: [
                            Text(
                              DateFormat('d').format(date),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold),
                            ),
                            Text(
                              DateFormat('EEE').format(date).toUpperCase(),
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.5),
                                  fontSize: 9),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        DateFormat('MMM yyyy').format(date),
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 12),
                      ),
                      const Spacer(),
                      if (dayDeposit > 0)
                        Text(
                          '+₹${_fmt(dayDeposit)}',
                          style: const TextStyle(
                              color: Color(0xFF64B5F6),
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                      if (dayDeposit > 0 && dayWithdraw > 0)
                        const SizedBox(width: 6),
                      if (dayWithdraw > 0)
                        Text(
                          '-₹${_fmt(dayWithdraw)}',
                          style: const TextStyle(
                              color: Color(0xFFEF9A9A),
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                    ],
                  ),
                ),
                // Transaction tiles
                ...txns.map((txn) => _buildTile(txn)),
                Divider(
                    height: 1, color: Colors.white.withOpacity(0.05)),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildTile(TransactionModel txn) {
    final isDeposit = _isDepositFor(txn);
    final amountColor =
        isDeposit ? const Color(0xFF64B5F6) : const Color(0xFFEF9A9A);
    final iconColor = isDeposit ? Colors.blue[300]! : Colors.red[300]!;
    final iconBg = isDeposit
        ? Colors.blue.withOpacity(0.15)
        : Colors.red.withOpacity(0.15);

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TransactionDetailScreen(transaction: txn),
        ),
      ),
      child: Container(
        color: const Color(0xFF1A1A2E),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(
          children: [
            // Icon
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(
                txn.type == 'transfer'
                    ? Icons.swap_horiz
                    : _categoryIcon(txn.category),
                color: iconColor,
                size: 16,
              ),
            ),
            const SizedBox(width: 10),
            // Category + note/subcategory
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    txn.category,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if ((txn.subcategory?.isNotEmpty ?? false) ||
                      (txn.note?.isNotEmpty ?? false))
                    Text(
                      txn.subcategory?.isNotEmpty == true
                          ? txn.subcategory!
                          : txn.note!,
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            // Amount
            Text(
              '${isDeposit ? '+' : '-'}₹${_fmt(txn.amount)}',
              style: TextStyle(
                color: amountColor,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long,
              size: 56, color: Colors.grey[700]),
          const SizedBox(height: 12),
          Text(
            'No transactions for ${_getDateLabel()}',
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
          ),
          const SizedBox(height: 6),
          Text(
            'Tap + to add a transaction',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  bool _isDepositFor(TransactionModel txn) {
    if (txn.type == 'income' && txn.toAccount == widget.account.id) return true;
    if (txn.type == 'transfer' && txn.toAccount == widget.account.id) return true;
    return false;
  }

  List<TransactionModel> _filterByPeriodAndAccount(
      List<TransactionModel> all) {
    return all.where((txn) {
      // Must involve this account
      final involvesAccount = (txn.type == 'income' &&
              txn.toAccount == widget.account.id) ||
          (txn.type == 'expense' &&
              txn.fromAccount == widget.account.id) ||
          (txn.type == 'transfer' &&
              (txn.fromAccount == widget.account.id ||
                  txn.toAccount == widget.account.id));

      if (!involvesAccount) return false;

      // Period filter
      switch (_selectedPeriod) {
        case 'Daily':
          return txn.date.year == _selectedDate.year &&
              txn.date.month == _selectedDate.month &&
              txn.date.day == _selectedDate.day;
        case 'Monthly':
          return txn.date.year == _selectedDate.year &&
              txn.date.month == _selectedDate.month;
        case 'Annually':
          return txn.date.year == _selectedDate.year;
        default:
          return true;
      }
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  void _previousPeriod() {
    setState(() {
      switch (_selectedPeriod) {
        case 'Daily':
          _selectedDate = _selectedDate.subtract(const Duration(days: 1));
          break;
        case 'Monthly':
          _selectedDate =
              DateTime(_selectedDate.year, _selectedDate.month - 1);
          break;
        case 'Annually':
          _selectedDate = DateTime(_selectedDate.year - 1);
          break;
      }
    });
  }

  void _nextPeriod() {
    setState(() {
      switch (_selectedPeriod) {
        case 'Daily':
          _selectedDate = _selectedDate.add(const Duration(days: 1));
          break;
        case 'Monthly':
          _selectedDate =
              DateTime(_selectedDate.year, _selectedDate.month + 1);
          break;
        case 'Annually':
          _selectedDate = DateTime(_selectedDate.year + 1);
          break;
      }
    });
  }

  String _getDateLabel() {
    switch (_selectedPeriod) {
      case 'Daily':
        return DateFormat('MMM d, yyyy').format(_selectedDate);
      case 'Monthly':
        return DateFormat('MMM yyyy').format(_selectedDate);
      case 'Annually':
        return DateFormat('yyyy').format(_selectedDate);
      default:
        return '';
    }
  }

  Color _accountColor(String type) {
    switch (type) {
      case 'cash':
        return Colors.green[700]!;
      case 'bank':
        return Colors.blue[700]!;
      case 'credit_card':
        return Colors.orange[700]!;
      case 'loan':
        return Colors.red[700]!;
      default:
        return Colors.blueGrey[700]!;
    }
  }

  IconData _accountIcon(String type) {
    switch (type) {
      case 'cash':
        return Icons.payments;
      case 'bank':
        return Icons.account_balance;
      case 'credit_card':
        return Icons.credit_card;
      case 'loan':
        return Icons.money_off;
      default:
        return Icons.account_balance_wallet;
    }
  }

  IconData _categoryIcon(String category) {
    switch (category) {
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

  String _fmt(double amount) {
    if (amount >= 10000000) {
      return '${(amount / 10000000).toStringAsFixed(1)}Cr';
    }
    if (amount >= 100000) return '${(amount / 100000).toStringAsFixed(1)}L';
    if (amount >= 1000) {
      final formatter = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
      return amount
          .toInt()
          .toString()
          .replaceAllMapped(formatter, (m) => '${m[1]},');
    }
    return amount.toStringAsFixed(0);
  }
}