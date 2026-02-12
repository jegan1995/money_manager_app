import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction_model.dart';
import '../models/account_model.dart';
import '../services/transaction_service.dart';
import '../services/account_service.dart';
import 'add_transaction_screen.dart';
import 'transaction_detail_screen.dart';
import 'search_filter_screen.dart';
import 'transfers_screen.dart';
import 'add_transfer_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final TransactionService _transactionService = TransactionService();
  final AccountService _accountService = AccountService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Money Manager'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SearchFilterScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {});
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Total Balance Card
            _buildTotalBalanceCard(),
            const SizedBox(height: 16),

            // Income/Expense Summary (This Month)
            _buildMonthSummaryCards(),
            const SizedBox(height: 16),

            // Transfer Quick Access Card
            _buildTransferQuickCard(),
            const SizedBox(height: 16),

            // Quick Stats
            _buildQuickStatsCard(),
            const SizedBox(height: 24),

            // Recent Transactions Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Transactions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    // Navigate to all transactions (home screen with filter)
                    DefaultTabController.of(context)?.animateTo(1);
                  },
                  child: const Text('See All'),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Recent Transactions List
            _buildRecentTransactions(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddTransactionScreen(),
            ),
          ).then((_) => setState(() {}));
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Transaction'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  Widget _buildTotalBalanceCard() {
    return StreamBuilder<List<AccountModel>>(
      stream: _accountService.getAccountsList(),
      builder: (context, snapshot) {
        double totalBalance = 0;
        
        if (snapshot.hasData) {
          totalBalance = snapshot.data!.fold(0.0, (sum, account) => sum + account.balance);
        }

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade600, Colors.blue.shade400],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Total Balance',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '₹${totalBalance.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Across ${snapshot.data?.length ?? 0} accounts',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMonthSummaryCards() {
    return FutureBuilder<List<TransactionModel>>(
      future: _transactionService.getTransactionsList(),
      builder: (context, snapshot) {
        double monthIncome = 0;
        double monthExpense = 0;

        if (snapshot.hasData) {
          final now = DateTime.now();
          final startOfMonth = DateTime(now.year, now.month, 1);
          
          final monthTransactions = snapshot.data!.where((t) => 
            t.date.isAfter(startOfMonth) && t.date.isBefore(now.add(const Duration(days: 1)))
          ).toList();

          for (var t in monthTransactions) {
            if (t.type == 'income') {
              monthIncome += t.amount;
            } else if (t.type == 'expense') {
              monthExpense += t.amount;
            }
          }
        }

        return Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                'Income',
                monthIncome,
                Colors.green,
                Icons.arrow_upward,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                'Expense',
                monthExpense,
                Colors.red,
                Icons.arrow_downward,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSummaryCard(String label, double amount, MaterialColor color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
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
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color.shade700,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '₹${amount.toStringAsFixed(0)}',
            style: TextStyle(
              color: color.shade900,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'This month',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransferQuickCard() {
    return FutureBuilder<List<TransactionModel>>(
      future: _transactionService.getTransactionsList(),
      builder: (context, snapshot) {
        int transferCount = 0;
        double transferAmount = 0;

        if (snapshot.hasData) {
          final now = DateTime.now();
          final startOfMonth = DateTime(now.year, now.month, 1);
          
          final transfers = snapshot.data!.where((t) => 
            t.type == 'transfer' &&
            t.date.isAfter(startOfMonth) && 
            t.date.isBefore(now.add(const Duration(days: 1)))
          ).toList();

          transferCount = transfers.length;
          transferAmount = transfers.fold(0.0, (sum, t) => sum + t.amount);
        }

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.indigo.shade400, Colors.indigo.shade600],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TransfersScreen()),
              ),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.swap_horiz, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Transfers',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$transferCount this month • ₹${transferAmount.toStringAsFixed(0)}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const AddTransferScreen()),
                      ),
                      icon: const Icon(Icons.add_circle, color: Colors.white, size: 32),
                      tooltip: 'New Transfer',
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickStatsCard() {
    return FutureBuilder<List<TransactionModel>>(
      future: _transactionService.getTransactionsList(),
      builder: (context, snapshot) {
        double todayExpense = 0;
        double weekExpense = 0;
        int transactionCount = 0;

        if (snapshot.hasData) {
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final weekAgo = today.subtract(const Duration(days: 7));

          for (var t in snapshot.data!) {
            if (t.type == 'expense') {
              if (t.date.isAfter(today.subtract(const Duration(days: 1)))) {
                todayExpense += t.amount;
              }
              if (t.date.isAfter(weekAgo)) {
                weekExpense += t.amount;
              }
            }
          }
          transactionCount = snapshot.data!.length;
        }

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.purple.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.purple.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Quick Stats',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem('Today', '₹${todayExpense.toStringAsFixed(0)}'),
                  Container(width: 1, height: 40, color: Colors.grey.shade300),
                  _buildStatItem('This Week', '₹${weekExpense.toStringAsFixed(0)}'),
                  Container(width: 1, height: 40, color: Colors.grey.shade300),
                  _buildStatItem('Total Txns', '$transactionCount'),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildRecentTransactions() {
    return FutureBuilder<List<TransactionModel>>(
      future: _transactionService.getTransactionsList(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                children: [
                  Icon(Icons.receipt_long, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'No transactions yet',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap the button below to add your first transaction',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        // Show only last 10 transactions
        final recentTransactions = snapshot.data!.take(10).toList();

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: recentTransactions.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final transaction = recentTransactions[index];
            final isIncome = transaction.type == 'income';
            final isTransfer = transaction.type == 'transfer';
            final color = isTransfer ? Colors.blue : (isIncome ? Colors.green : Colors.red);

            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              leading: CircleAvatar(
                backgroundColor: color.withOpacity(0.1),
                child: Icon(
                  _getCategoryIcon(transaction.category),
                  color: color,
                  size: 20,
                ),
              ),
              title: Text(
                transaction.category,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (transaction.subcategory != null)
                    Text(
                      transaction.subcategory!,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  Text(
                    DateFormat('MMM d, yyyy').format(transaction.date),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
              trailing: Text(
                isTransfer 
                    ? '₹${transaction.amount.toStringAsFixed(0)}'
                    : '${isIncome ? '+' : '-'}₹${transaction.amount.toStringAsFixed(0)}',
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TransactionDetailScreen(transaction: transaction),
                  ),
                ).then((_) => setState(() {}));
              },
            );
          },
        );
      },
    );
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
      case 'Transfer':
        return Icons.swap_horiz;
      default:
        return Icons.category;
    }
  }
}