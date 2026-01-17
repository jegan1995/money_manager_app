import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/transaction_model.dart';
import '../services/transaction_service.dart';
import 'add_transaction_screen.dart';
import 'transaction_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TransactionService _transactionService = TransactionService();
  String _selectedPeriod = 'This Month';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Money Manager'),
        actions: [
          PopupMenuButton<String>(
            initialValue: _selectedPeriod,
            onSelected: (value) => setState(() => _selectedPeriod = value),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'Today', child: Text('Today')),
              const PopupMenuItem(value: 'This Week', child: Text('This Week')),
              const PopupMenuItem(value: 'This Month', child: Text('This Month')),
              const PopupMenuItem(value: 'This Year', child: Text('This Year')),
              const PopupMenuItem(value: 'All Time', child: Text('All Time')),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(_selectedPeriod, style: const TextStyle(fontSize: 14)),
                  const Icon(Icons.arrow_drop_down, size: 20),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildBalanceCards(),
          Expanded(child: _buildTransactionsList()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AddTransactionScreen()),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBalanceCards() {
    return StreamBuilder<QuerySnapshot>(
      stream: _transactionService.getTransactions(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData) return const SizedBox.shrink();

        final transactions = snapshot.data!.docs
            .map((doc) => TransactionModel.fromMap(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                ))
            .toList();

        final filtered = _filterByPeriod(transactions);

        double income = 0, expense = 0;
        for (var txn in filtered) {
          if (txn.type == 'income') {
            income += txn.amount;
          } else {
            expense += txn.amount;
          }
        }

        return Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                child: _buildStatCard('Balance', income - expense,
                    Icons.account_balance_wallet_outlined, Colors.blue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                    'Income', income, Icons.arrow_downward, Colors.green),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                    'Expense', expense, Icons.arrow_upward, Colors.red),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String label, double amount, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '₹${amount.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _transactionService.getTransactions(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text('No transactions yet',
                    style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                const SizedBox(height: 8),
                Text('Tap + to add your first transaction',
                    style: TextStyle(color: Colors.grey[500], fontSize: 14)),
              ],
            ),
          );
        }

        final transactions = snapshot.data!.docs
            .map((doc) => TransactionModel.fromMap(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                ))
            .toList();

        final filtered = _filterByPeriod(transactions);

        if (filtered.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text('No transactions in $_selectedPeriod',
                    style: TextStyle(color: Colors.grey[600], fontSize: 16)),
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

        final sortedDates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

        return Container(
          color: Colors.white,
          child: ListView.builder(
            itemCount: sortedDates.length,
            itemBuilder: (context, index) {
              final dateKey = sortedDates[index];
              final dayTxns = grouped[dateKey]!;
              final date = DateTime.parse(dateKey);

              double dayIncome = 0, dayExpense = 0;
              for (var txn in dayTxns) {
                if (txn.type == 'income') {
                  dayIncome += txn.amount;
                } else {
                  dayExpense += txn.amount;
                }
              }

              return Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    color: Colors.grey[100],
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_formatDateHeader(date),
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14)),
                        Text('₹${(dayIncome - dayExpense).toStringAsFixed(0)}',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: (dayIncome - dayExpense) >= 0
                                  ? Colors.green
                                  : Colors.red,
                            )),
                      ],
                    ),
                  ),
                  ...dayTxns.map((txn) => _buildTransactionTile(txn)),
                  const Divider(height: 1),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildTransactionTile(TransactionModel transaction) {
    final isExpense = transaction.type == 'expense';

    return ListTile(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TransactionDetailScreen(transaction: transaction),
        ),
      ),
      leading: CircleAvatar(
        backgroundColor: isExpense ? Colors.red[50] : Colors.green[50],
        radius: 20,
        child: Icon(
          _getCategoryIcon(transaction.category),
          color: isExpense ? Colors.red : Colors.green,
          size: 20,
        ),
      ),
      title: Text(transaction.category,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
      subtitle: Text(transaction.subcategory ?? transaction.paymentMethod,
          style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      trailing: Text(
        '${isExpense ? '-' : '+'}₹${transaction.amount.toStringAsFixed(0)}',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: isExpense ? Colors.red : Colors.green,
        ),
      ),
    );
  }

  List<TransactionModel> _filterByPeriod(List<TransactionModel> transactions) {
    final now = DateTime.now();

    return transactions.where((txn) {
      switch (_selectedPeriod) {
        case 'Today':
          return txn.date.year == now.year &&
              txn.date.month == now.month &&
              txn.date.day == now.day;
        case 'This Week':
          final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
          return txn.date.isAfter(startOfWeek.subtract(const Duration(days: 1)));
        case 'This Month':
          return txn.date.year == now.year && txn.date.month == now.month;
        case 'This Year':
          return txn.date.year == now.year;
        default:
          return true;
      }
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));

    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return 'Today';
    } else if (date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day) {
      return 'Yesterday';
    } else {
      return DateFormat('EEEE, MMM d').format(date);
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