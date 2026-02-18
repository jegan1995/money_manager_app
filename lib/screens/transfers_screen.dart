import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction_model.dart';
import '../models/account_model.dart';
import '../services/transaction_service.dart';
import '../services/account_service.dart';
import 'transaction_detail_screen.dart';

class TransfersScreen extends StatefulWidget {
  const TransfersScreen({super.key});

  @override
  State<TransfersScreen> createState() => _TransfersScreenState();
}

class _TransfersScreenState extends State<TransfersScreen> {
  final TransactionService transactionService = TransactionService();
  final AccountService accountService = AccountService();

  // ✅ Cache account names: {accountId: accountName}
  Map<String, String> _accountNames = {};

  @override
  void initState() {
    super.initState();
    _loadAccountNames();
  }

  void _loadAccountNames() {
    accountService.getAccountsList().listen((accounts) {
      setState(() {
        _accountNames = {
          for (var account in accounts) account.id ?? '': account.name
        };
      });
    });
  }

  // ✅ Convert ID to name
  String _getAccountName(String? accountId) {
    if (accountId == null) return 'Unknown';
    return _accountNames[accountId] ?? 'Unknown Account';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transfers'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<TransactionModel>>(
        stream: transactionService.getTransactions(),
        builder: (context, AsyncSnapshot<List<TransactionModel>> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyState();
          }

          final allTransactions = snapshot.data!;
          final transfers =
              allTransactions.where((txn) => txn.type == 'transfer').toList();

          if (transfers.isEmpty) {
            return _buildEmptyState();
          }

          // Group by date
          final grouped = <String, List<TransactionModel>>{};
          for (var txn in transfers) {
            final dateKey = DateFormat('yyyy-MM-dd').format(txn.date);
            grouped.putIfAbsent(dateKey, () => []).add(txn);
          }

          final sortedDates = grouped.keys.toList()
            ..sort((a, b) => b.compareTo(a));

          return ListView.builder(
            itemCount: sortedDates.length,
            itemBuilder: (context, index) {
              final dateKey = sortedDates[index];
              final dayTransfers = grouped[dateKey]!;
              final date = DateTime.parse(dateKey);
              final dayTotal =
                  dayTransfers.fold<double>(0, (sum, txn) => sum + txn.amount);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date Header
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    color: Colors.grey[100],
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDate(date),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          '₹${dayTotal.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Transfer List
                  ...dayTransfers.map((transfer) {
                    // ✅ Look up account names from IDs
                    final fromName = _getAccountName(transfer.fromAccount);
                    final toName = _getAccountName(transfer.toAccount);

                    return ListTile(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                TransactionDetailScreen(transaction: transfer),
                          ),
                        );
                      },
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue[50],
                        child: const Icon(Icons.swap_horiz, color: Colors.blue),
                      ),
                      title: Text(
                        // ✅ Show account names as title
                        '$fromName → $toName',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      subtitle:
                          transfer.note != null && transfer.note!.isNotEmpty
                              ? Text(
                                  transfer.note!,
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey[600]),
                                )
                              : Text(
                                  DateFormat('hh:mm a').format(transfer.date),
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey[600]),
                                ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '₹${transfer.amount.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const Divider(height: 1),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.swap_horiz, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
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
            'Transfer money between accounts',
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));

    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return 'Today';
    } else if (date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day) {
      return 'Yesterday';
    } else {
      return DateFormat('EEEE, MMM d').format(date);
    }
  }
}
