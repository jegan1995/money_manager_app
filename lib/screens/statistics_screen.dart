import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/transaction_service.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  final TransactionService _transactionService = TransactionService();
  String _selectedPeriod = 'This Month';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistics'),
        actions: [
          PopupMenuButton<String>(
            initialValue: _selectedPeriod,
            onSelected: (value) => setState(() => _selectedPeriod = value),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'This Month', child: Text('This Month')),
              const PopupMenuItem(value: 'Last 3 Months', child: Text('Last 3 Months')),
              const PopupMenuItem(value: 'Last 6 Months', child: Text('Last 6 Months')),
              const PopupMenuItem(value: 'This Year', child: Text('This Year')),
            ],
          ),
        ],
      ),
      body: FutureBuilder<Map<String, double>>(
        future: _transactionService.getSpendingByCategory(
          DateTime.now().month,
          DateTime.now().year,
        ),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final spending = snapshot.data!;
          
          if (spending.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bar_chart, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  const Text('No data available'),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Pie Chart
              const Text(
                'Spending by Category',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 300,
                child: PieChart(
                  PieChartData(
                    sections: spending.entries.map((e) {
                      return PieChartSectionData(
                        value: e.value,
                        title: '${e.key}\n₹${e.value.toStringAsFixed(0)}',
                        radius: 100,
                        titleStyle: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    }).toList(),
                    sectionsSpace: 2,
                    centerSpaceRadius: 40,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Category List
              const Text(
                'Breakdown',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ...spending.entries.map((e) => Card(
                    child: ListTile(
                      title: Text(e.key),
                      trailing: Text(
                        '₹${e.value.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  )),
            ],
          );
        },
      ),
    );
  }
}