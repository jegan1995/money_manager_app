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
          if (!accountSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          // Build account map
          final accountMap = <String?, String>{};
          for (var account in accountSnapshot.data!) {
            accountMap[account.id] = account.name;
          }

          return StreamBuilder<QuerySnapshot>(
            stream: transactionService.getTransactionsByType('transfer'),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return _buildEmptyState(context);
              }

              final transfers = snapshot.data!.docs
                  .map((doc) => TransactionModel.fromFirestore(doc))
                  .toList();

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: transfers.length,
                itemBuilder: (context, index) {
                  final transfer = transfers[index];
                  final fromName = accountMap[transfer.fromAccount] ?? 'Unknown';
                  final toName = accountMap[transfer.toAccount] ?? 'Unknown';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue.withOpacity(0.2),
                        child: const Icon(Icons.swap_horiz, color: Colors.blue),
                      ),
                      title: Text(
                        transfer.category,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$fromName → $toName', style: const TextStyle(fontSize: 12)),
                          Text(
                            DateFormat('dd MMM yyyy').format(transfer.date),
                            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                      trailing: Text(
                        '₹${transfer.amount.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue),
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
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AddTransferScreen())),
        icon: const Icon(Icons.add),
        label: const Text('New Transfer'),
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
          Text('No transfers yet', style: TextStyle(color: Colors.grey[600], fontSize: 18, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Text('Transfer money between accounts', style: TextStyle(color: Colors.grey[500], fontSize: 14)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AddTransferScreen())),
            icon: const Icon(Icons.add),
            label: const Text('Add Transfer'),
          ),
        ],
      ),
    );
  }

  void _showDetails(BuildContext context, TransactionModel transfer, String from, String to, TransactionService service) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Transfer Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Amount: ₹${transfer.amount}'),
            const SizedBox(height: 8),
            Text('From: $from'),
            const SizedBox(height: 8),
            Text('To: $to'),
            const SizedBox(height: 8),
            Text('Date: ${DateFormat('dd MMM yyyy').format(transfer.date)}'),
            if (transfer.note != null) ...[
              const SizedBox(height: 8),
              Text('Notes: ${transfer.note}'),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('Delete Transfer'),
                  content: const Text('Delete this transfer?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                    TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                  ],
                ),
              );
              if (confirmed == true) {
                await service.deleteTransaction(transfer.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transfer deleted')));
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}