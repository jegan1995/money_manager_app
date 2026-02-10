import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/transaction_model.dart';
import '../services/transaction_service.dart';

class TransfersScreenDebug extends StatelessWidget {
  const TransfersScreenDebug({super.key});

  @override
  Widget build(BuildContext context) {
    final TransactionService transactionService = TransactionService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transfers Debug'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: transactionService.getTransactions(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final allTransactions = snapshot.data!.docs
              .map((doc) => TransactionModel.fromFirestore(doc))
              .toList();

          // Show ALL transactions to debug
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: allTransactions.length,
            itemBuilder: (context, index) {
              final txn = allTransactions[index];
              return Card(
                child: ListTile(
                  title: Text('${txn.category} - ${txn.type}'),
                  subtitle: Text(
                    'From: ${txn.fromAccount ?? "null"}\n'
                    'To: ${txn.toAccount ?? "null"}\n'
                    'Amount: ₹${txn.amount}'
                  ),
                  trailing: Text(
                    txn.type,
                    style: TextStyle(
                      color: txn.type == 'transfer' ? Colors.blue : Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
