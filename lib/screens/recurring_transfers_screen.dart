import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/recurring_transfer_model.dart';
import '../models/account_model.dart';
import '../services/recurring_transfer_service.dart';
import '../services/account_service.dart';

class RecurringTransfersScreen extends StatefulWidget {
  const RecurringTransfersScreen({super.key});

  @override
  State<RecurringTransfersScreen> createState() => _RecurringTransfersScreenState();
}

class _RecurringTransfersScreenState extends State<RecurringTransfersScreen> {
  final RecurringTransferService _recurringService = RecurringTransferService();
  final AccountService _accountService = AccountService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recurring Transfers'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: StreamBuilder<List<RecurringTransferModel>>(
        stream: _recurringService.getRecurringTransfers(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.repeat, size: 80, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('No recurring transfers', style: TextStyle(fontSize: 18, color: Colors.grey)),
                  const SizedBox(height: 8),
                  const Text('Set up automatic transfers', style: TextStyle(fontSize: 14, color: Colors.grey)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _showAddRecurringDialog(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Recurring Transfer'),
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
              return _buildRecurringCard(recurring);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddRecurringDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildRecurringCard(RecurringTransferModel recurring) {
    final nextDate = _calculateNextDate(recurring);
    final daysUntil = nextDate.difference(DateTime.now()).inDays;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue.withOpacity(0.1),
              child: const Icon(Icons.repeat, color: Colors.blue),
            ),
            title: Text(recurring.title, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: StreamBuilder<List<AccountModel>>(
              stream: _accountService.getAccountsList(),
              builder: (context, accountSnapshot) {
                if (!accountSnapshot.hasData) return const Text('Loading...');
                
                final accounts = accountSnapshot.data!;
                final fromAccount = accounts.firstWhere((a) => a.id == recurring.fromAccountId, orElse: () => AccountModel(id: '', name: 'Unknown', type: 'cash', balance: 0, createdAt: DateTime.now()));
                final toAccount = accounts.firstWhere((a) => a.id == recurring.toAccountId, orElse: () => AccountModel(id: '', name: 'Unknown', type: 'cash', balance: 0, createdAt: DateTime.now()));
                
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${fromAccount.name} → ${toAccount.name}'),
                    Text('₹${recurring.amount.toStringAsFixed(0)} • ${recurring.frequency}', style: const TextStyle(fontSize: 12)),
                  ],
                );
              },
            ),
            trailing: Switch(
              value: recurring.isActive,
              onChanged: (value) => _toggleActive(recurring, value),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Next Transfer', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      Text(
                        DateFormat('MMM d, yyyy').format(nextDate),
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      Text(
                        daysUntil > 0 ? 'in $daysUntil days' : 'Today',
                        style: TextStyle(fontSize: 12, color: daysUntil == 0 ? Colors.orange : Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => _showEditDialog(recurring),
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('Edit'),
                    ),
                    TextButton.icon(
                      onPressed: () => _deleteRecurring(recurring),
                      icon: const Icon(Icons.delete, size: 16, color: Colors.red),
                      label: const Text('Delete', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  DateTime _calculateNextDate(RecurringTransferModel recurring) {
    DateTime next = recurring.lastExecuted ?? recurring.startDate;
    
    switch (recurring.frequency) {
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
    
    while (next.isBefore(DateTime.now())) {
      switch (recurring.frequency) {
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
    }
    
    return next;
  }

  void _toggleActive(RecurringTransferModel recurring, bool value) {
    _recurringService.updateRecurringTransfer(
      recurring.id!,
      recurring.copyWith(isActive: value),
    );
  }

  void _deleteRecurring(RecurringTransferModel recurring) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Recurring Transfer?'),
        content: Text('This will stop automatic transfers for "${recurring.title}".'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _recurringService.deleteRecurringTransfer(recurring.id!);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showAddRecurringDialog() async {
    final accounts = await _accountService.getAccountsList().first;
    if (!mounted) return;
    
    _showRecurringDialog(null, accounts);
  }

  void _showEditDialog(RecurringTransferModel recurring) async {
    final accounts = await _accountService.getAccountsList().first;
    if (!mounted) return;
    
    _showRecurringDialog(recurring, accounts);
  }

  void _showRecurringDialog(RecurringTransferModel? existing, List<AccountModel> accounts) {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController(text: existing?.title ?? '');
    final amountController = TextEditingController(text: existing?.amount.toString() ?? '');
    final notesController = TextEditingController(text: existing?.note ?? '');
    
    String? fromAccountId = existing?.fromAccountId ?? (accounts.isNotEmpty ? accounts.first.id : null);
    String? toAccountId = existing?.toAccountId ?? (accounts.length > 1 ? accounts[1].id : null);
    String frequency = existing?.frequency ?? 'monthly';
    DateTime startDate = existing?.startDate ?? DateTime.now();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(existing == null ? 'Add Recurring Transfer' : 'Edit Recurring Transfer'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      hintText: 'e.g., Monthly Savings',
                    ),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: amountController,
                    decoration: const InputDecoration(labelText: 'Amount'),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v!.isEmpty) return 'Required';
                      if (double.tryParse(v) == null) return 'Invalid amount';
                      if (double.parse(v) <= 0) return 'Must be greater than 0';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: fromAccountId,
                    decoration: const InputDecoration(labelText: 'From Account'),
                    items: accounts.map((account) {
                      return DropdownMenuItem(
                        value: account.id,
                        child: Text('${account.name} (₹${account.balance.toStringAsFixed(0)})'),
                      );
                    }).toList(),
                    onChanged: (value) => setState(() => fromAccountId = value),
                    validator: (v) => v == null ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: toAccountId,
                    decoration: const InputDecoration(labelText: 'To Account'),
                    items: accounts.map((account) {
                      return DropdownMenuItem(
                        value: account.id,
                        child: Text('${account.name} (₹${account.balance.toStringAsFixed(0)})'),
                      );
                    }).toList(),
                    onChanged: (value) => setState(() => toAccountId = value),
                    validator: (v) {
                      if (v == null) return 'Required';
                      if (v == fromAccountId) return 'Must be different from source';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: frequency,
                    decoration: const InputDecoration(labelText: 'Frequency'),
                    items: const [
                      DropdownMenuItem(value: 'daily', child: Text('Daily')),
                      DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                      DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                      DropdownMenuItem(value: 'yearly', child: Text('Yearly')),
                    ],
                    onChanged: (value) => setState(() => frequency = value!),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    title: Text('Start Date: ${DateFormat('MMM d, yyyy').format(startDate)}'),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: startDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setState(() => startDate = picked);
                      }
                    },
                  ),
                  TextFormField(
                    controller: notesController,
                    decoration: const InputDecoration(labelText: 'Notes (Optional)'),
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
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  final recurring = RecurringTransferModel(
                    id: existing?.id,
                    title: titleController.text,
                    amount: double.parse(amountController.text),
                    fromAccountId: fromAccountId!,
                    toAccountId: toAccountId!,
                    frequency: frequency,
                    startDate: startDate,
                    note: notesController.text.isEmpty ? null : notesController.text,
                    isActive: existing?.isActive ?? true,
                    lastExecuted: existing?.lastExecuted,
                    createdAt: existing?.createdAt ?? DateTime.now(),
                  );

                  if (existing == null) {
                    _recurringService.addRecurringTransfer(recurring);
                  } else {
                    _recurringService.updateRecurringTransfer(existing.id!, recurring);
                  }
                  
                  Navigator.pop(context);
                }
              },
              child: Text(existing == null ? 'Add' : 'Update'),
            ),
          ],
        ),
      ),
    );
  }
}