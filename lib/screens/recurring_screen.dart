import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/recurring_transaction.dart';
import '../services/recurring_service.dart';

class RecurringScreen extends StatefulWidget {
  const RecurringScreen({super.key});

  @override
  State<RecurringScreen> createState() => _RecurringScreenState();
}

class _RecurringScreenState extends State<RecurringScreen> {
  final RecurringService _recurringService = RecurringService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recurring Transactions'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: StreamBuilder<List<RecurringTransaction>>(
        stream: _recurringService.getRecurringTransactions(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.replay, size: 80, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('No recurring transactions',
                      style: TextStyle(fontSize: 18, color: Colors.grey)),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () => _showAddRecurringDialog(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Recurring'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final recurring = snapshot.data![index];
              final isIncome = recurring.type == 'income';
              final color = isIncome ? Colors.green : Colors.red;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: color.withOpacity(0.1),
                    child: Icon(
                      Icons.replay,
                      color: color,
                    ),
                  ),
                  title: Text(
                    recurring.title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${recurring.category} • ${recurring.frequency}'),
                      Text(
                        'Next: ${_getNextDate(recurring)}',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${isIncome ? '+' : '-'}₹${recurring.amount.toStringAsFixed(0)}',
                        style: TextStyle(
                          color: color,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete,
                            size: 18, color: Colors.red),
                        onPressed: () =>
                            _recurringService.deleteRecurring(recurring.id),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddRecurringDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  String _getNextDate(RecurringTransaction r) {
    DateTime next = r.lastGenerated;
    switch (r.frequency) {
      case 'daily':
        next = next.add(const Duration(days: 1));
        break;
      case 'weekly':
        next = next.add(const Duration(days: 7));
        break;
      case 'monthly':
        next = DateTime(next.year, next.month + 1, next.day);
        break;
      case 'yearly':
        next = DateTime(next.year + 1, next.month, next.day);
        break;
    }
    return DateFormat('dd MMM yyyy').format(next);
  }

  void _showAddRecurringDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    final notesController = TextEditingController();

    String selectedType = 'expense';
    String selectedCategory = 'Bills';
    String selectedFrequency = 'monthly';

    final expenseCategories = [
      'Food',
      'Transport',
      'Shopping',
      'Bills',
      'Entertainment',
      'Health',
      'Education',
      'Other'
    ];
    final incomeCategories = [
      'Salary',
      'Business',
      'Investment',
      'Gift',
      'Other'
    ];
    final frequencies = ['daily', 'weekly', 'monthly', 'yearly'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          List<String> categories =
              selectedType == 'expense' ? expenseCategories : incomeCategories;
          if (!categories.contains(selectedCategory)) {
            selectedCategory = categories[0];
          }

          return AlertDialog(
            title: const Text('Add Recurring Transaction'),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('Expense'),
                            value: 'expense',
                            groupValue: selectedType,
                            onChanged: (value) =>
                                setState(() => selectedType = value!),
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('Income'),
                            value: 'income',
                            groupValue: selectedType,
                            onChanged: (value) =>
                                setState(() => selectedType = value!),
                          ),
                        ),
                      ],
                    ),
                    TextFormField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: 'Title'),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    TextFormField(
                      controller: amountController,
                      decoration: const InputDecoration(labelText: 'Amount'),
                      keyboardType: TextInputType.number,
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    DropdownButtonFormField<String>(
                      value: selectedCategory,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: categories
                          .map((cat) =>
                              DropdownMenuItem(value: cat, child: Text(cat)))
                          .toList(),
                      onChanged: (value) =>
                          setState(() => selectedCategory = value!),
                    ),
                    DropdownButtonFormField<String>(
                      value: selectedFrequency,
                      decoration: const InputDecoration(labelText: 'Frequency'),
                      items: frequencies
                          .map(
                              (f) => DropdownMenuItem(value: f, child: Text(f)))
                          .toList(),
                      onChanged: (value) =>
                          setState(() => selectedFrequency = value!),
                    ),
                    TextFormField(
                      controller: notesController,
                      decoration:
                          const InputDecoration(labelText: 'Notes (Optional)'),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    final recurring = RecurringTransaction(
                      id: '',
                      title: titleController.text,
                      amount: double.parse(amountController.text),
                      category: selectedCategory,
                      type: selectedType,
                      frequency: selectedFrequency,
                      startDate: DateTime.now(),
                      notes: notesController.text.isEmpty
                          ? null
                          : notesController.text,
                      lastGenerated: DateTime.now(),
                    );
                    await _recurringService.addRecurring(recurring);
                    Navigator.pop(context);
                  }
                },
                child: const Text('Add'),
              ),
            ],
          );
        },
      ),
    );
  }
}
