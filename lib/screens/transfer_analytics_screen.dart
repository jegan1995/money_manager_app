import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/transaction_model.dart';
import '../models/account_model.dart';
import '../services/transaction_service.dart';
import '../services/account_service.dart';

class TransferAnalyticsScreen extends StatefulWidget {
  const TransferAnalyticsScreen({super.key});

  @override
  State<TransferAnalyticsScreen> createState() => _TransferAnalyticsScreenState();
}

class _TransferAnalyticsScreenState extends State<TransferAnalyticsScreen> {
  final TransactionService _transactionService = TransactionService();
  final AccountService _accountService = AccountService();
  
  String _selectedPeriod = 'Last 6 Months';
  final List<String> _periods = ['Last 3 Months', 'Last 6 Months', 'This Year', 'All Time'];

  Future<Map<String, dynamic>> _loadData() async {
    final transactions = await _transactionService.getTransactionsList();
    final accounts = await _accountService.getAccountsList();
    return {'transactions': transactions, 'accounts': accounts};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transfer Analytics'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          PopupMenuButton<String>(
            initialValue: _selectedPeriod,
            onSelected: (value) => setState(() => _selectedPeriod = value),
            itemBuilder: (context) => _periods.map((period) {
              return PopupMenuItem(value: period, child: Text(period));
            }).toList(),
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _loadData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData) {
            return const Center(child: Text('No data available'));
          }

          final allTransactions = snapshot.data!['transactions'] as List<TransactionModel>;
          final accounts = snapshot.data!['accounts'] as List<AccountModel>;
          final transfers = _getFilteredTransfers(allTransactions);

          if (transfers.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.swap_horiz, size: 80, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('No transfer data yet', style: TextStyle(fontSize: 18, color: Colors.grey)),
                  const SizedBox(height: 8),
                  const Text('Create transfers to see analytics', style: TextStyle(fontSize: 14, color: Colors.grey)),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Summary Cards
                _buildSummaryCards(transfers),
                const SizedBox(height: 24),

                // Monthly Trend Chart
                _buildMonthlyTrendChart(transfers),
                const SizedBox(height: 24),

                // Top Transfer Routes
                _buildTopTransferRoutes(transfers, accounts),
                const SizedBox(height: 24),

                // Transfer vs Income/Expense
                _buildTransferComparison(allTransactions),
                const SizedBox(height: 24),

                // Account Flow
                _buildAccountFlow(transfers, accounts),
              ],
            ),
          );
        },
      ),
    );
  }

  List<TransactionModel> _getFilteredTransfers(List<TransactionModel> transactions) {
    final transfers = transactions.where((t) => t.type == 'transfer').toList();
    final now = DateTime.now();
    DateTime cutoffDate;

    switch (_selectedPeriod) {
      case 'Last 3 Months':
        cutoffDate = DateTime(now.year, now.month - 3, now.day);
        break;
      case 'Last 6 Months':
        cutoffDate = DateTime(now.year, now.month - 6, now.day);
        break;
      case 'This Year':
        cutoffDate = DateTime(now.year, 1, 1);
        break;
      default: // All Time
        return transfers;
    }

    return transfers.where((t) => t.date.isAfter(cutoffDate)).toList();
  }

  Widget _buildSummaryCards(List<TransactionModel> transfers) {
    final totalAmount = transfers.fold(0.0, (sum, t) => sum + t.amount);
    final avgTransfer = transfers.isNotEmpty ? totalAmount / transfers.length : 0.0;

    return Row(
      children: [
        Expanded(child: _buildSummaryCard('Total Transfers', '₹${totalAmount.toStringAsFixed(0)}', Icons.swap_horiz, Colors.blue)),
        const SizedBox(width: 12),
        Expanded(child: _buildSummaryCard('Count', '${transfers.length}', Icons.numbers, Colors.green)),
        const SizedBox(width: 12),
        Expanded(child: _buildSummaryCard('Average', '₹${avgTransfer.toStringAsFixed(0)}', Icons.trending_up, Colors.orange)),
      ],
    );
  }

  Widget _buildSummaryCard(String label, String value, IconData icon, Color color) {
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
          Text(label, style: TextStyle(fontSize: 12, color: color), textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildMonthlyTrendChart(List<TransactionModel> transfers) {
    Map<String, double> monthlyData = {};
    for (var transfer in transfers) {
      final monthKey = DateFormat('MMM yyyy').format(transfer.date);
      monthlyData[monthKey] = (monthlyData[monthKey] ?? 0) + transfer.amount;
    }

    final sortedEntries = monthlyData.entries.toList()
      ..sort((a, b) {
        final dateA = DateFormat('MMM yyyy').parse(a.key);
        final dateB = DateFormat('MMM yyyy').parse(b.key);
        return dateA.compareTo(dateB);
      });

    final displayData = sortedEntries.length > 6 
        ? sortedEntries.sublist(sortedEntries.length - 6) 
        : sortedEntries;

    if (displayData.isEmpty) {
      return const SizedBox.shrink();
    }

    final spots = displayData.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.value);
    }).toList();

    final maxY = displayData.fold(0.0, (max, e) => e.value > max ? e.value : max) * 1.2;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Monthly Transfer Trends', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: true, drawVerticalLine: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text('₹${(value / 1000).toStringAsFixed(0)}k', style: const TextStyle(fontSize: 10));
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= 0 && value.toInt() < displayData.length) {
                          final month = displayData[value.toInt()].key.split(' ')[0];
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(month, style: const TextStyle(fontSize: 10)),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                minY: 0,
                maxY: maxY,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: Colors.blue,
                    barWidth: 3,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(show: true, color: Colors.blue.withOpacity(0.1)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopTransferRoutes(List<TransactionModel> transfers, List<AccountModel> accounts) {
    final accountMap = <String, String>{};
    for (var account in accounts) {
      if (account.id != null) {
        accountMap[account.id!] = account.name;
      }
    }

    Map<String, List<TransactionModel>> routes = {};
    for (var transfer in transfers) {
      if (transfer.fromAccount != null && transfer.toAccount != null) {
        final fromName = accountMap[transfer.fromAccount] ?? transfer.fromAccount!;
        final toName = accountMap[transfer.toAccount] ?? transfer.toAccount!;
        final routeKey = '$fromName → $toName';
        routes[routeKey] = [...(routes[routeKey] ?? []), transfer];
      }
    }

    final sortedRoutes = routes.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));

    final topRoutes = sortedRoutes.take(5).toList();

    if (topRoutes.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Top Transfer Routes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ...topRoutes.map((entry) {
            final totalAmount = entry.value.fold(0.0, (sum, t) => sum + t.amount);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${topRoutes.indexOf(entry) + 1}',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w500)),
                        Text('${entry.value.length} transfers', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      ],
                    ),
                  ),
                  Text('₹${totalAmount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildTransferComparison(List<TransactionModel> transactions) {
    final filtered = _getFilteredTransfers(transactions);
    
    double income = 0, expense = 0, transfers = 0;
    for (var txn in filtered) {
      if (txn.type == 'income') income += txn.amount;
      if (txn.type == 'expense') expense += txn.amount;
      if (txn.type == 'transfer') transfers += txn.amount;
    }

    final maxValue = [income, expense, transfers].reduce((a, b) => a > b ? a : b);
    if (maxValue == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Transfer vs Income/Expense', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxValue * 1.2,
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text('₹${(value / 1000).toStringAsFixed(0)}k', style: const TextStyle(fontSize: 10));
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        switch (value.toInt()) {
                          case 0: return const Text('Income', style: TextStyle(fontSize: 12));
                          case 1: return const Text('Expense', style: TextStyle(fontSize: 12));
                          case 2: return const Text('Transfers', style: TextStyle(fontSize: 12));
                          default: return const Text('');
                        }
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(show: true, drawVerticalLine: false),
                borderData: FlBorderData(show: false),
                barGroups: [
                  BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: income, color: Colors.green, width: 40)]),
                  BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: expense, color: Colors.red, width: 40)]),
                  BarChartGroupData(x: 2, barRods: [BarChartRodData(toY: transfers, color: Colors.blue, width: 40)]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountFlow(List<TransactionModel> transfers, List<AccountModel> accounts) {
    final accountMap = <String, String>{};
    for (var account in accounts) {
      if (account.id != null) {
        accountMap[account.id!] = account.name;
      }
    }

    Map<String, double> accountInflow = {};
    Map<String, double> accountOutflow = {};

    for (var transfer in transfers) {
      if (transfer.fromAccount != null) {
        final fromName = accountMap[transfer.fromAccount] ?? transfer.fromAccount!;
        accountOutflow[fromName] = (accountOutflow[fromName] ?? 0) + transfer.amount;
      }
      if (transfer.toAccount != null) {
        final toName = accountMap[transfer.toAccount] ?? transfer.toAccount!;
        accountInflow[toName] = (accountInflow[toName] ?? 0) + transfer.amount;
      }
    }

    final allAccounts = {...accountInflow.keys, ...accountOutflow.keys}.toList();
    if (allAccounts.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Account Money Flow', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ...allAccounts.map((accountName) {
            final inflow = accountInflow[accountName] ?? 0;
            final outflow = accountOutflow[accountName] ?? 0;
            final netFlow = inflow - outflow;

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(accountName, style: const TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.arrow_downward, size: 16, color: Colors.green),
                                const SizedBox(width: 4),
                                Text('In: ₹${inflow.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, color: Colors.green)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.arrow_upward, size: 16, color: Colors.red),
                                const SizedBox(width: 4),
                                Text('Out: ₹${outflow.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, color: Colors.red)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: netFlow >= 0 ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Net: ${netFlow >= 0 ? '+' : ''}₹${netFlow.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: netFlow >= 0 ? Colors.green : Colors.red,
                          ),
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