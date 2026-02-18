import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/recurring_transaction_model.dart';
import '../services/recurring_transaction_service.dart';
import 'add_recurring_transaction_screen.dart';

class RecurringTransactionsScreen extends StatefulWidget {
  const RecurringTransactionsScreen({super.key});

  @override
  State<RecurringTransactionsScreen> createState() =>
      _RecurringTransactionsScreenState();
}

class _RecurringTransactionsScreenState
    extends State<RecurringTransactionsScreen> {
  final RecurringTransactionService _service = RecurringTransactionService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recurring Transactions'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<RecurringTransactionModel>>(
        stream: _service.getRecurringTransactions(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final recurring = snapshot.data ?? [];

          if (recurring.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: recurring.length,
            itemBuilder: (context, index) {
              final item = recurring[index];
              return _buildRecurringCard(item);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddRecurringTransactionScreen(),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Recurring'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  Widget _buildRecurringCard(RecurringTransactionModel item) {
    final isIncome = item.type == 'income';
    final color = isIncome ? Colors.green : Colors.red;
    final icon = isIncome ? Icons.arrow_downward : Icons.arrow_upward;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(
          item.category,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              _getFrequencyText(item.frequency),
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              'Next: ${DateFormat('MMM d, yyyy').format(item.nextDate)}',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            if (item.note != null && item.note!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  item.note!,
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '₹${item.amount.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Switch(
              value: item.isActive,
              onChanged: (value) async {
                await _service.toggleRecurringTransaction(item.id, value);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(value ? 'Activated' : 'Paused'),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                }
              },
              activeColor: Colors.green,
            ),
          ],
        ),
        onTap: () {
          _showOptions(item);
        },
      ),
    );
  }

  String _getFrequencyText(String frequency) {
    switch (frequency) {
      case 'daily':
        return 'Every day';
      case 'weekly':
        return 'Every week';
      case 'monthly':
        return 'Every month';
      case 'yearly':
        return 'Every year';
      default:
        return frequency;
    }
  }

  void _showOptions(RecurringTransactionModel item) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.blue),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        AddRecurringTransactionScreen(recurring: item),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.play_arrow, color: Colors.green),
              title: const Text('Execute Now'),
              onTap: () async {
                Navigator.pop(context);
                await _service.executeRecurring(item.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Transaction created successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete'),
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(item);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(RecurringTransactionModel item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Recurring Transaction?'),
        content: Text('Delete "${item.category}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _service.deleteRecurringTransaction(item.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Deleted successfully'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.repeat, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No recurring transactions',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Set up automatic transactions for\nsalary, rent, bills, etc.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
          ),
        ],
      ),
    );
  }
}
