import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/transaction_model.dart';
import '../models/account_model.dart';
import '../services/transaction_service.dart';
import '../services/account_service.dart';
import 'add_transfer_screen.dart';

class TransfersScreen extends StatelessWidget {
  const TransfersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final TransactionService transactionService = TransactionService();
    final AccountService accountService = AccountService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transfers'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: StreamBuilder<List<AccountModel>>(
        stream: accountService.getAccountsList(),
        builder: (context, accountSnapshot) {
          final accountMap = <String?, String>{};
          if (accountSnapshot.hasData) {
            for (var account in accountSnapshot.data!) {
              accountMap[account.id] = account.name;
            }
          }

          return StreamBuilder<QuerySnapshot>(
            stream: transactionService.getTransactions(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return _buildEmptyState(context);
              }

              final allTransactions = snapshot.data!.docs
                  .map((doc) => TransactionModel.fromFirestore(doc))
                  .toList();

              // Filter transfers
              final transfers = allTransactions.where((txn) {
                if (txn.type.toLowerCase() == 'transfer') return true;
                if (txn.category.toLowerCase().contains('transfer')) return true;
                if (txn.fromAccount != null && txn.toAccount != null) return true;
                return false;
              }).toList();

              if (transfers.isEmpty) {
                return _buildEmptyState(context);
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: transfers.length,
                itemBuilder: (context, index) {
                  final transfer = transfers[index];
                  final fromName = accountMap[transfer.fromAccount] ?? 
                                   (transfer.fromAccount ?? 'Unknown');
                  final toName = accountMap[transfer.toAccount] ?? 
                                 (transfer.toAccount ?? 'Unknown');

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 2,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue.withOpacity(0.2),
                        child: const Icon(Icons.swap_horiz, color: Colors.blue),
                      ),
                      title: Text(
                        transfer.category,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            '$fromName → $toName',
                            style: const TextStyle(fontSize: 13, color: Colors.black87),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            DateFormat('dd MMM yyyy').format(transfer.date),
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                          if (transfer.note != null && transfer.note!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              transfer.note!,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[500],
                                fontStyle: FontStyle.italic,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                      trailing: Text(
                        '₹${transfer.amount.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      onTap: () => _showDetails(context, transfer, fromName, toName, transactionService),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AddTransferScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('New Transfer'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.swap_horiz, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 24),
          Text(
            'No transfers yet',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Transfer money between your accounts',
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AddTransferScreen()),
            ),
            icon: const Icon(Icons.add),
            label: const Text('Add Transfer'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  void _showDetails(
    BuildContext context,
    TransactionModel transfer,
    String from,
    String to,
    TransactionService service,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.swap_horiz, color: Colors.blue),
            const SizedBox(width: 8),
            const Text('Transfer Details'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Amount', '₹${transfer.amount.toStringAsFixed(2)}', isBold: true),
            const Divider(height: 24),
            _buildDetailRow('From Account', from),
            const SizedBox(height: 12),
            const Center(child: Icon(Icons.arrow_downward, color: Colors.blue, size: 20)),
            const SizedBox(height: 12),
            _buildDetailRow('To Account', to),
            const Divider(height: 24),
            _buildDetailRow('Date', DateFormat('dd MMM yyyy').format(transfer.date)),
            if (transfer.note != null && transfer.note!.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildDetailRow('Notes', transfer.note!),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('Delete Transfer'),
                  content: const Text(
                    'Are you sure you want to delete this transfer?\n\n'
                    'Note: This will only delete the transaction record. '
                    'Account balances will NOT be automatically adjusted.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text(
                        'Delete',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );

              if (confirmed == true) {
                await service.deleteTransaction(transfer.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Transfer deleted'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              fontSize: isBold ? 16 : 14,
            ),
          ),
        ),
      ],
    );
  }
}