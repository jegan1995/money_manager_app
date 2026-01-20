import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import "../models/budget_model.dart";';
import '../models/transaction.dart' as app_transaction;
import '../services/budget_service.dart';
import '../services/firestore_service.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  final BudgetService _budgetService = BudgetService();
  final FirestoreService _firestoreService = FirestoreService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Budgets'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        automaticallyImplyLeading: false,
      ),
      body: StreamBuilder<List<BudgetModel>>(
        stream: _budgetService.getBudgets(),
        builder: (context, budgetSnapshot) {
          if (budgetSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!budgetSnapshot.hasData || budgetSnapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.account_balance_wallet, size: 80, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('No budgets set', style: TextStyle(fontSize: 18, color: Colors.grey)),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () => _showAddBudgetDialog(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Budget'),
                  ),
                ],
              ),
            );
          }

          return StreamBuilder<List<app_transaction.Transaction>>(
            stream: _firestoreService.getTransactions(),
            builder: (context, transactionSnapshot) {
              if (!transactionSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final transactions = transactionSnapshot.data!;
              final now = DateTime.now();
              final currentMonth = DateTime(now.year, now.month);

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: budgetSnapshot.data!.length,
                itemBuilder: (context, index) {
                  final budget = budgetSnapshot.data![index];
                  
                  final spent = transactions
                      .where((t) =>
                          t.type == 'expense' &&
                          t.category == budget.category &&
                          t.date.isAfter(currentMonth))
                      .fold(0.0, (sum, t) => sum + t.amount);

                  final percentage = (spent / budget.amount) * 100;
                  final remaining = budget.amount - spent;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                budget.category,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _budgetService.deleteBudgetModel(budget.id),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Spent: ₹${spent.toStringAsFixed(0)}'),
                              Text('Budget: ₹${budget.amount.toStringAsFixed(0)}'),
                            ],
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: percentage / 100,
                            backgroundColor: Colors.grey.shade200,
                            color: percentage > 90
                                ? Colors.red
                                : percentage > 70
                                    ? Colors.orange
                                    : Colors.green,
                            minHeight: 10,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${percentage.toStringAsFixed(1)}% used',
                                style: TextStyle(
                                  color: percentage > 90 ? Colors.red : Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                remaining >= 0
                                    ? '₹${remaining.toStringAsFixed(0)} left'
                                    : '₹${(-remaining).toStringAsFixed(0)} over',
                                style: TextStyle(
                                  color: remaining >= 0 ? Colors.green : Colors.red,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddBudgetDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddBudgetDialog(BuildContext context) {
    final categories = ['Food', 'Transport', 'Shopping', 'Bills', 'Entertainment', 'Health', 'Education', 'Other'];
    String selectedCategory = categories[0];
    final amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Budget'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedCategory,
                decoration: const InputDecoration(labelText: 'Category'),
                items: categories.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
                onChanged: (value) => setState(() => selectedCategory = value!),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                decoration: const InputDecoration(labelText: 'Monthly Budget Amount'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountController.text);
                if (amount != null && amount > 0) {
                  final budget = BudgetModel(
                    id: '',
                    category: selectedCategory,
                    amount: amount,
                    period: 'monthly',
                    createdDate: DateTime.now(),
                  );
                  await _budgetService.addBudgetModel(budget);
                  Navigator.pop(context);
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
}
