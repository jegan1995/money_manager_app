import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/account_model.dart';
import '../models/transaction_model.dart';
import '../services/transaction_service.dart';
import '../services/account_service.dart';
import 'transaction_detail_screen.dart';
import 'add_account_screen.dart';

class AccountDetailScreen extends StatefulWidget {
  final AccountModel account;

  const AccountDetailScreen({super.key, required this.account});

  @override
  State<AccountDetailScreen> createState() => _AccountDetailScreenState();
}

class _AccountDetailScreenState extends State<AccountDetailScreen> {
  final TransactionService _transactionService = TransactionService();
  final AccountService _accountService = AccountService();

  String _selectedPeriod = 'Daily'; // Daily, Monthly, Annually
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        backgroundColor: Colors.green,
        title: Text(widget.account.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            onPressed: () {
              // TODO: Navigate to account analytics
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      AddAccountScreen(account: widget.account),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Account Balance Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.green,
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.account_balance_wallet,
                  size: 48,
                  color: Colors.white,
                ),
                const SizedBox(height: 8),
                Text(
                  widget.account.typeDisplayName,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                StreamBuilder<QuerySnapshot>(
                  stream: _accountService.getAccounts(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Text(
                        '₹0.00',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    }

                    final account = snapshot.data!.docs
                        .map((doc) => AccountModel.fromMap(
                            doc.data() as Map<String, dynamic>, doc.id))
                        .firstWhere((a) => a.id == widget.account.id);

                    return Text(
                      '₹${account.balance.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // Period Tabs
          Container(
            color: Colors.grey[850],
            child: Row(
              children: [
                _buildPeriodTab('Daily'),
                _buildPeriodTab('Monthly'),
                _buildPeriodTab('Annually'),
              ],
            ),
          ),

          // Date Navigation
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.grey[850],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, color: Colors.white),
                  onPressed: _previousPeriod,
                ),
                Text(
                  _getDateLabel(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right, color: Colors.white),
                  onPressed: _nextPeriod,
                ),
              ],
            ),
          ),

          // Summary Row
          _buildSummaryRow(),

          // Transactions List
          Expanded(
            child: _buildTransactionsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodTab(String period) {
    final isSelected = _selectedPeriod == period;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedPeriod = period;
            _selectedDate = DateTime.now();
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? Colors.green : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Text(
            period,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.green : Colors.grey,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow() {
    return StreamBuilder<List<TransactionModel>>(
      stream: _transactionService.getTransactions(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[850],
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                SizedBox(height: 50),
              ],
            ),
          );
        }

        final transactions = snapshot.data!;

        final filtered = _filterTransactionsByPeriod(
            transactions); // ✅ Change allTransactions to transactions

        double deposit = 0;
        double withdrawal = 0;

        for (var txn in filtered) {
          if (txn.type == 'income' && txn.toAccount == widget.account.id) {
            deposit += txn.amount;
          } else if (txn.type == 'expense' &&
              txn.fromAccount == widget.account.id) {
            withdrawal += txn.amount;
          } else if (txn.type == 'transfer') {
            if (txn.toAccount == widget.account.id) {
              deposit += txn.amount;
            } else if (txn.fromAccount == widget.account.id) {
              withdrawal += txn.amount;
            }
          }
        }

        final total = deposit - withdrawal;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Colors.grey[850],
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryItem('Deposit', deposit, Colors.blue),
              _buildSummaryItem('Withdrawal', withdrawal, Colors.red),
              _buildSummaryItem('Total', total, Colors.white),
              StreamBuilder<QuerySnapshot>(
                stream: _accountService.getAccounts(),
                builder: (context, accSnapshot) {
                  if (!accSnapshot.hasData) {
                    return _buildSummaryItem('Balance', 0, Colors.grey);
                  }

                  final account = accSnapshot.data!.docs
                      .map((doc) => AccountModel.fromMap(
                          doc.data() as Map<String, dynamic>, doc.id))
                      .firstWhere((a) => a.id == widget.account.id);

                  return _buildSummaryItem(
                    'Balance',
                    account.balance,
                    account.balance >= 0 ? Colors.green : Colors.red,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryItem(String label, double amount, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          amount >= 0
              ? '₹${amount.toStringAsFixed(2)}'
              : '-₹${(-amount).toStringAsFixed(2)}',
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionsList() {
    return StreamBuilder<List<TransactionModel>>(
      stream: _transactionService.getTransactions(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.green),
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: Text(
              'No transactions',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        final transactions = snapshot.data!;

        final filtered = _filterTransactionsByPeriod(
            transactions); // ✅ Change allTransactions to transactions

        if (filtered.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long, size: 64, color: Colors.grey[700]),
                const SizedBox(height: 16),
                Text(
                  'No transactions for ${_getDateLabel()}',
                  style: const TextStyle(color: Colors.grey, fontSize: 16),
                ),
              ],
            ),
          );
        }

        // Group by date
        final grouped = <String, List<TransactionModel>>{};
        for (var txn in filtered) {
          final key = DateFormat('yyyy-MM-dd').format(txn.date);
          grouped.putIfAbsent(key, () => []).add(txn);
        }

        final sortedDates = grouped.keys.toList()
          ..sort((a, b) => b.compareTo(a));

        return ListView.builder(
          itemCount: sortedDates.length,
          itemBuilder: (context, index) {
            final dateKey = sortedDates[index];
            final dayTxns = grouped[dateKey]!;
            final date = DateTime.parse(dateKey);

            double dayDeposit = 0;
            double dayWithdrawal = 0;

            for (var txn in dayTxns) {
              if (txn.type == 'income' && txn.toAccount == widget.account.id) {
                dayDeposit += txn.amount;
              } else if (txn.type == 'expense' &&
                  txn.fromAccount == widget.account.id) {
                dayWithdrawal += txn.amount;
              } else if (txn.type == 'transfer') {
                if (txn.toAccount == widget.account.id) {
                  dayDeposit += txn.amount;
                } else if (txn.fromAccount == widget.account.id) {
                  dayWithdrawal += txn.amount;
                }
              }
            }

            return Column(
              children: [
                // Date Header
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: Colors.grey[850],
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${date.day} ${_getDayName(date.weekday)} ${DateFormat('MM/yyyy').format(date)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Row(
                        children: [
                          if (dayDeposit > 0)
                            Text(
                              '₹${dayDeposit.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: Colors.blue,
                                fontSize: 13,
                              ),
                            ),
                          if (dayDeposit > 0 && dayWithdrawal > 0)
                            const SizedBox(width: 8),
                          if (dayWithdrawal > 0)
                            Text(
                              '₹${dayWithdrawal.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 13,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Transactions
                ...dayTxns.map((txn) => _buildTransactionTile(txn)),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildTransactionTile(TransactionModel transaction) {
    bool isDeposit = false;
    bool isWithdrawal = false;

    if (transaction.type == 'income' &&
        transaction.toAccount == widget.account.id) {
      isDeposit = true;
    } else if (transaction.type == 'expense' &&
        transaction.fromAccount == widget.account.id) {
      isWithdrawal = true;
    } else if (transaction.type == 'transfer') {
      if (transaction.toAccount == widget.account.id) {
        isDeposit = true;
      } else if (transaction.fromAccount == widget.account.id) {
        isWithdrawal = true;
      }
    }

    if (!isDeposit && !isWithdrawal) {
      return const SizedBox.shrink();
    }

    return ListTile(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              TransactionDetailScreen(transaction: transaction),
        ),
      ),
      leading: CircleAvatar(
        backgroundColor: transaction.type == 'transfer'
            ? Colors.blue.withOpacity(0.2)
            : (isDeposit
                ? Colors.blue.withOpacity(0.2)
                : Colors.red.withOpacity(0.2)),
        child: Icon(
          transaction.type == 'transfer'
              ? Icons.swap_horiz
              : _getCategoryIcon(transaction.category),
          color: transaction.type == 'transfer'
              ? Colors.blue
              : (isDeposit ? Colors.blue : Colors.red),
          size: 20,
        ),
      ),
      title: Text(
        transaction.category,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        transaction.subcategory ?? transaction.note ?? widget.account.name,
        style: TextStyle(color: Colors.grey[400], fontSize: 12),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        isDeposit
            ? '₹${transaction.amount.toStringAsFixed(2)}'
            : '₹${transaction.amount.toStringAsFixed(2)}',
        style: TextStyle(
          color: isDeposit ? Colors.blue : Colors.red,
          fontSize: 15,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  List<TransactionModel> _filterTransactionsByPeriod(
      List<TransactionModel> transactions) {
    return transactions.where((txn) {
      // Filter by account
      if (txn.type == 'income' && txn.toAccount != widget.account.id) {
        return false;
      } else if (txn.type == 'expense' &&
          txn.fromAccount != widget.account.id) {
        return false;
      } else if (txn.type == 'transfer') {
        if (txn.fromAccount != widget.account.id &&
            txn.toAccount != widget.account.id) {
          return false;
        }
      }

      // Filter by period
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
          _selectedDate = DateTime(_selectedDate.year, _selectedDate.month - 1);
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
          _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + 1);
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

  String _getDayName(int weekday) {
    switch (weekday) {
      case 1:
        return 'Mon';
      case 2:
        return 'Tue';
      case 3:
        return 'Wed';
      case 4:
        return 'Thu';
      case 5:
        return 'Fri';
      case 6:
        return 'Sat';
      case 7:
        return 'Sun';
      default:
        return '';
    }
  }

  IconData _getCategoryIcon(String category) {
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
}
