import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart' as app_transaction;
import '../services/firestore_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  String _selectedPeriod = 'This Month';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: StreamBuilder<List<app_transaction.Transaction>>(
        stream: _firestoreService.getTransactions(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.insert_chart, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No data to display',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Add transactions to see reports',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          final transactions = _getFilteredTransactions(snapshot.data!);

          if (transactions.isEmpty) {
            return const Center(
              child: Text('No transactions for selected period'),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Period selector
                _buildPeriodSelector(),
                const SizedBox(height: 20),

                // Summary cards
                _buildSummaryCards(transactions),
                const SizedBox(height: 20),

                // Expense pie chart
                _buildExpensePieChart(transactions),
                const SizedBox(height: 20),

                // Income vs Expense bar chart
                _buildIncomeExpenseChart(transactions),
                const SizedBox(height: 20),

                // Category breakdown
                _buildCategoryBreakdown(transactions),
              ],
            ),
          );
        },
      ),
    );
  }

  List<app_transaction.Transaction> _getFilteredTransactions(
      List<app_transaction.Transaction> transactions) {
    DateTime now = DateTime.now();
    DateTime startDate;

    switch (_selectedPeriod) {
      case 'This Month':
        startDate = DateTime(now.year, now.month, 1);
        break;
      case 'Last Month':
        startDate = DateTime(now.year, now.month - 1, 1);
        DateTime endDate = DateTime(now.year, now.month, 1);
        return transactions
            .where((t) => t.date.isAfter(startDate) && t.date.isBefore(endDate))
            .toList();
      case 'Last 3 Months':
        startDate = DateTime(now.year, now.month - 3, 1);
        break;
      case 'This Year':
        startDate = DateTime(now.year, 1, 1);
        break;
      default:
        startDate = DateTime(2020, 1, 1);
    }

    return transactions.where((t) => t.date.isAfter(startDate)).toList();
  }

  Widget _buildPeriodSelector() {
    final periods = ['This Month', 'Last Month', 'Last 3 Months', 'This Year'];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: periods.map((period) {
          final isSelected = _selectedPeriod == period;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedPeriod = period;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.blue : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  period,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSummaryCards(List<app_transaction.Transaction> transactions) {
    double totalIncome = 0;
    double totalExpense = 0;

    for (var t in transactions) {
      if (t.type == 'income') {
        totalIncome += t.amount;
      } else {
        totalExpense += t.amount;
      }
    }

    double balance = totalIncome - totalExpense;

    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            'Income',
            totalIncome,
            Colors.green,
            Icons.arrow_upward,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            'Expense',
            totalExpense,
            Colors.red,
            Icons.arrow_downward,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            'Balance',
            balance,
            balance >= 0 ? Colors.blue : Colors.orange,
            Icons.account_balance_wallet,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
      String label, double amount, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '₹${amount.toStringAsFixed(0)}',
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpensePieChart(List<app_transaction.Transaction> transactions) {
    final expenses =
        transactions.where((t) => t.type == 'expense').toList();

    if (expenses.isEmpty) {
      return const SizedBox.shrink();
    }

    Map<String, double> categoryTotals = {};
    for (var t in expenses) {
      categoryTotals[t.category] =
          (categoryTotals[t.category] ?? 0) + t.amount;
    }

    List<MapEntry<String, double>> sortedEntries = categoryTotals.entries
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final colors = [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.amber,
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Expense Breakdown',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sections: sortedEntries.asMap().entries.map((entry) {
                  final index = entry.key;
                  final category = entry.value.key;
                  final amount = entry.value.value;
                  final total = expenses.fold(0.0, (sum, t) => sum + t.amount);
                  final percentage = (amount / total) * 100;

                  return PieChartSectionData(
                    value: amount,
                    title: '${percentage.toStringAsFixed(1)}%',
                    color: colors[index % colors.length],
                    radius: 60,
                    titleStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  );
                }).toList(),
                sectionsSpace: 2,
                centerSpaceRadius: 40,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: sortedEntries.asMap().entries.map((entry) {
              final index = entry.key;
              final category = entry.value.key;
              final amount = entry.value.value;

              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: colors[index % colors.length],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$category: ₹${amount.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildIncomeExpenseChart(
      List<app_transaction.Transaction> transactions) {
    double totalIncome = 0;
    double totalExpense = 0;

    for (var t in transactions) {
      if (t.type == 'income') {
        totalIncome += t.amount;
      } else {
        totalExpense += t.amount;
      }
    }

    if (totalIncome == 0 && totalExpense == 0) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Income vs Expense',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: (totalIncome > totalExpense ? totalIncome : totalExpense) *
                    1.2,
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        switch (value.toInt()) {
                          case 0:
                            return const Text('Income',
                                style: TextStyle(fontSize: 12));
                          case 1:
                            return const Text('Expense',
                                style: TextStyle(fontSize: 12));
                          default:
                            return const Text('');
                        }
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '₹${(value / 1000).toStringAsFixed(0)}k',
                          style: const TextStyle(fontSize: 10),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                ),
                borderData: FlBorderData(show: false),
                barGroups: [
                  BarChartGroupData(
                    x: 0,
                    barRods: [
                      BarChartRodData(
                        toY: totalIncome,
                        color: Colors.green,
                        width: 40,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(6),
                        ),
                      ),
                    ],
                  ),
                  BarChartGroupData(
                    x: 1,
                    barRods: [
                      BarChartRodData(
                        toY: totalExpense,
                        color: Colors.red,
                        width: 40,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(6),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBreakdown(
      List<app_transaction.Transaction> transactions) {
    Map<String, double> categoryTotals = {};
    for (var t in transactions.where((t) => t.type == 'expense')) {
      categoryTotals[t.category] =
          (categoryTotals[t.category] ?? 0) + t.amount;
    }

    if (categoryTotals.isEmpty) {
      return const SizedBox.shrink();
    }

    List<MapEntry<String, double>> sortedEntries = categoryTotals.entries
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    double total = categoryTotals.values.fold(0, (sum, amount) => sum + amount);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Top Spending Categories',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...sortedEntries.take(5).map((entry) {
            final category = entry.key;
            final amount = entry.value;
            final percentage = (amount / total) * 100;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        category,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      Text(
                        '₹${amount.toStringAsFixed(0)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: LinearProgressIndicator(
                          value: percentage / 100,
                          backgroundColor: Colors.grey.shade200,
                          color: Colors.blue,
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${percentage.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}
