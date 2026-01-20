import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction_model.dart';
import '../services/transaction_service.dart';
import 'add_transaction_screen.dart';

class TransactionDetailScreen extends StatelessWidget {
  final TransactionModel transaction;

  const TransactionDetailScreen({
    super.key,
    required this.transaction,
  });

  @override
  Widget build(BuildContext context) {
    final isExpense = transaction.type == 'expense';
    final isIncome = transaction.type == 'income';
    final isTransfer = transaction.type == 'transfer';
    final TransactionService transactionService = TransactionService();

    Color typeColor = Colors.blue;
    if (isExpense) typeColor = Colors.red;
    if (isIncome) typeColor = Colors.green;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction Details'),
        actions: [
          // Edit Button
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => AddTransactionScreen(
                    transaction: transaction,
                  ),
                ),
              );
            },
          ),
          // Copy Button
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Copy Transaction',
            onPressed: () {
              final copiedTransaction = transaction.copyWith(
                id: null,
                date: DateTime.now(),
                createdAt: DateTime.now(),
              );
              
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddTransactionScreen(
                    transaction: copiedTransaction,
                    isCopy: true,
                  ),
                ),
              );
            },
          ),
          // Delete Button
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete Transaction'),
                  content: const Text(
                      'Are you sure you want to delete this transaction?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text(
                        'Delete',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );

              if (confirmed == true && context.mounted) {
                try {
                  await transactionService.deleteTransaction(transaction.id!);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Transaction deleted'),
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
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Amount Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: typeColor.withOpacity(0.1),
              ),
              child: Column(
                children: [
                  Icon(
                    isTransfer
                        ? Icons.swap_horiz
                        : (isExpense ? Icons.arrow_upward : Icons.arrow_downward),
                    color: typeColor,
                    size: 48,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isTransfer
                        ? 'Transfer'
                        : (isExpense ? 'Expense' : 'Income'),
                    style: TextStyle(
                      fontSize: 16,
                      color: typeColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '₹${transaction.amount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: typeColor,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Details List
            _buildDetailItem(
              icon: Icons.category,
              label: 'Category',
              value: transaction.category,
            ),
            
            if (transaction.subcategory != null)
              _buildDetailItem(
                icon: Icons.subdirectory_arrow_right,
                label: 'Subcategory',
                value: transaction.subcategory!,
              ),

            if (transaction.paymentMethod != null)
              _buildDetailItem(
                icon: Icons.payment,
                label: 'Payment Method',
                value: transaction.paymentMethod ?? '',
              ),

            if (transaction.fromAccount != null)
              _buildDetailItem(
                icon: Icons.account_balance_wallet,
                label: 'From Account',
                value: transaction.fromAccount!,
              ),

            if (transaction.toAccount != null)
              _buildDetailItem(
                icon: Icons.account_balance,
                label: 'To Account',
                value: transaction.toAccount!,
              ),

            _buildDetailItem(
              icon: Icons.calendar_today,
              label: 'Date',
              value: DateFormat('EEEE, MMM d, yyyy').format(transaction.date),
            ),

            _buildDetailItem(
              icon: Icons.access_time,
              label: 'Time',
              value: DateFormat('h:mm a').format(transaction.date),
            ),

            if (transaction.note != null && transaction.note!.isNotEmpty)
              _buildDetailItem(
                icon: Icons.note,
                label: 'Note',
                value: transaction.note!,
              ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[600], size: 22),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
