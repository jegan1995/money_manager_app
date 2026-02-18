import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/budget_model.dart';
import '../services/budget_service.dart';
import '../services/transaction_service.dart';
// import '../utils/subcategories.dart';
import '../utils/categories.dart';

class BudgetManagementScreen extends StatefulWidget {
  const BudgetManagementScreen({super.key});

  @override
  State<BudgetManagementScreen> createState() => _BudgetManagementScreenState();
}

class _BudgetManagementScreenState extends State<BudgetManagementScreen> {
  final BudgetService _budgetService = BudgetService();
  final TransactionService _transactionService = TransactionService();

  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Budget Management'),
        actions: [
          // Month/Year Selector
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'change_month') {
                _showMonthYearPicker();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'change_month',
                child: Text(DateFormat('MMMM yyyy')
                    .format(DateTime(_selectedYear, _selectedMonth))),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(
                    DateFormat('MMM yyyy')
                        .format(DateTime(_selectedYear, _selectedMonth)),
                    style: const TextStyle(fontSize: 14),
                  ),
                  const Icon(Icons.arrow_drop_down, size: 20),
                ],
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            _budgetService.getBudgetsForMonth(_selectedMonth, _selectedYear),
        builder: (context, budgetSnapshot) {
          if (budgetSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final budgets = budgetSnapshot.data?.docs
                  .map((doc) => BudgetModel.fromFirestore(doc))
                  .toList() ??
              [];

          return FutureBuilder<Map<String, double>>(
            future: _transactionService.getSpendingByCategory(
              _selectedMonth, // ✅ Just pass the int directly
              _selectedYear,
            ),
            builder: (context, spendingSnapshot) {
              if (!spendingSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final spending = spendingSnapshot.data!;

              if (budgets.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.pie_chart_outline,
                          size: 80, color: Colors.grey[300]),
                      const SizedBox(height: 24),
                      Text('No budgets set',
                          style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 18,
                              fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      Text('Tap + to add your first budget',
                          style:
                              TextStyle(color: Colors.grey[500], fontSize: 14)),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () => _showAddBudgetDialog(),
                        icon: const Icon(Icons.add),
                        label: const Text('Add Budget'),
                      ),
                    ],
                  ),
                );
              }

              // Calculate totals
              double totalBudget = 0;
              double totalSpent = 0;

              for (var budget in budgets) {
                totalBudget += budget.amount;
                totalSpent += spending[budget.category] ?? 0;
              }

              return Column(
                children: [
                  // Summary Card
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.purple[700]!, Colors.purple[500]!],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.purple.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Total Budget',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '₹${totalBudget.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildSummaryItem(
                                'Spent', totalSpent, Colors.red[300]!),
                            _buildSummaryItem('Remaining',
                                totalBudget - totalSpent, Colors.green[300]!),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Budget List
                  Expanded(
                    child: ListView.builder(
                      itemCount: budgets.length,
                      itemBuilder: (context, index) {
                        final budget = budgets[index];
                        final spent = spending[budget.category] ?? 0;
                        final remaining = budget.amount - spent;
                        final percentage =
                            (spent / budget.amount * 100).clamp(0, 100);

                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          child: InkWell(
                            onTap: () => _showEditBudgetDialog(budget),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            _getCategoryIcon(budget.category),
                                            color: Colors.blue,
                                            size: 24,
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            budget.category,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete,
                                            size: 20, color: Colors.red),
                                        onPressed: () =>
                                            _deleteBudget(budget.id!),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '₹${spent.toStringAsFixed(0)} / ₹${budget.amount.toStringAsFixed(0)}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      Text(
                                        '${percentage.toStringAsFixed(0)}%',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: percentage > 100
                                              ? Colors.red
                                              : (percentage > 80
                                                  ? Colors.orange
                                                  : Colors.green),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: LinearProgressIndicator(
                                      value: (percentage / 100).clamp(0, 1),
                                      minHeight: 8,
                                      backgroundColor: Colors.grey[200],
                                      valueColor: AlwaysStoppedAnimation(
                                        percentage > 100
                                            ? Colors.red
                                            : (percentage > 80
                                                ? Colors.orange
                                                : Colors.green),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    remaining >= 0
                                        ? 'Remaining: ₹${remaining.toStringAsFixed(0)}'
                                        : 'Overspent: ₹${(-remaining).toStringAsFixed(0)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: remaining >= 0
                                          ? Colors.green
                                          : Colors.red,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddBudgetDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSummaryItem(String label, double amount, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '₹${amount.toStringAsFixed(0)}',
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  void _showMonthYearPicker() {
    showDialog(
      context: context,
      builder: (context) {
        int tempMonth = _selectedMonth;
        int tempYear = _selectedYear;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Select Month & Year'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButton<int>(
                    value: tempMonth,
                    isExpanded: true,
                    items: List.generate(12, (index) {
                      final month = index + 1;
                      return DropdownMenuItem(
                        value: month,
                        child:
                            Text(DateFormat('MMMM').format(DateTime(0, month))),
                      );
                    }),
                    onChanged: (value) {
                      setDialogState(() {
                        tempMonth = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButton<int>(
                    value: tempYear,
                    isExpanded: true,
                    items: List.generate(10, (index) {
                      final year = DateTime.now().year - 5 + index;
                      return DropdownMenuItem(
                        value: year,
                        child: Text(year.toString()),
                      );
                    }),
                    onChanged: (value) {
                      setDialogState(() {
                        tempYear = value!;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedMonth = tempMonth;
                      _selectedYear = tempYear;
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddBudgetDialog() {
    String? selectedCategory;
    final amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Budget'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                    ),
                    items: Categories.getMainCategories('expense')
                        .map((cat) =>
                            DropdownMenuItem(value: cat, child: Text(cat)))
                        .toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedCategory = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Budget Amount',
                      prefixText: '₹ ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () async {
                    if (selectedCategory == null ||
                        amountController.text.isEmpty) {
                      return;
                    }

                    // ✅ Get current user ID
                    final currentUserId =
                        FirebaseAuth.instance.currentUser?.uid;
                    if (currentUserId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('User not logged in'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    final budget = BudgetModel(
                      id: '',
                      userId: currentUserId, // ✅ NEW: Add userId
                      category: selectedCategory!,
                      amount: double.parse(amountController.text),
                      month: _selectedMonth,
                      year: _selectedYear,
                    );

                    try {
                      await _budgetService.addBudget(budget);
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Budget added'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditBudgetDialog(BudgetModel budget) {
    final amountController =
        TextEditingController(text: budget.amount.toString());

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Edit ${budget.category} Budget'),
          content: TextField(
            controller: amountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Budget Amount',
              prefixText: '₹ ',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                if (amountController.text.isEmpty) return;

                final updatedBudget = BudgetModel(
                  id: budget.id,
                  userId: budget.userId, // ✅ NEW: Keep existing userId
                  category: budget.category,
                  amount: double.parse(amountController.text),
                  month: budget.month,
                  year: budget.year,
                );

                try {
                  await _budgetService.updateBudget(budget.id!, updatedBudget);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Budget updated'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Update'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteBudget(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Budget'),
        content: const Text('Are you sure you want to delete this budget?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _budgetService.deleteBudget(id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Budget deleted'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
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
      default:
        return Icons.category;
    }
  }
}
