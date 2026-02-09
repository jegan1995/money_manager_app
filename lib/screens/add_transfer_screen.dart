import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction_model.dart';
import '../models/account_model.dart';
import '../services/transaction_service.dart';
import '../services/account_service.dart';

class AddTransferScreen extends StatefulWidget {
  const AddTransferScreen({super.key});

  @override
  State<AddTransferScreen> createState() => _AddTransferScreenState();
}

class _AddTransferScreenState extends State<AddTransferScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  final TransactionService _transactionService = TransactionService();
  final AccountService _accountService = AccountService();

  String? _fromAccountId;
  String? _toAccountId;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  List<AccountModel> _accounts = [];

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  void _loadAccounts() {
    _accountService.getAccountsList().listen((accounts) {
      if (mounted) {
        setState(() => _accounts = accounts);
      }
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _saveTransfer() async {
    if (!_formKey.currentState!.validate()) return;

    if (_fromAccountId == null || _toAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select both accounts')),
      );
      return;
    }

    if (_fromAccountId == _toAccountId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot transfer to same account')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final amount = double.parse(_amountController.text);

      // Create transfer transaction
      final transaction = TransactionModel(
        id: '',
        type: 'transfer',
        amount: amount,
        category: 'Transfer',
        date: _selectedDate,
        note: _notesController.text.isEmpty ? null : _notesController.text,
        fromAccount: _fromAccountId,
        toAccount: _toAccountId,
      );

      await _transactionService.addTransaction(transaction);

      // Update balances
      await _accountService.updateAccountBalance(_fromAccountId!, -amount);
      await _accountService.updateAccountBalance(_toAccountId!, amount);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transfer completed!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transfer Money'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _accounts.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      color: Colors.blue.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, color: Colors.blue),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Transfer money between your accounts',
                                style: TextStyle(color: Colors.blue.shade900),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Amount
                    TextFormField(
                      controller: _amountController,
                      decoration: const InputDecoration(
                        labelText: 'Amount',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.currency_rupee),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Enter amount';
                        if (double.tryParse(value) == null) return 'Enter valid number';
                        if (double.parse(value) <= 0) return 'Amount must be > 0';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // From Account
                    DropdownButtonFormField<String>(
                      value: _fromAccountId,
                      decoration: const InputDecoration(
                        labelText: 'From Account',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.account_balance),
                      ),
                      items: _accounts.map((account) => DropdownMenuItem(
                        value: account.id,
                        child: Row(
                          children: [
                            Icon(_getIcon(account.type), size: 20, color: _getColor(account.type)),
                            const SizedBox(width: 8),
                            Expanded(child: Text('${account.name} (₹${account.balance.toStringAsFixed(0)})')),
                          ],
                        ),
                      )).toList(),
                      onChanged: (value) => setState(() => _fromAccountId = value),
                      validator: (value) => value == null ? 'Select source account' : null,
                    ),
                    const SizedBox(height: 16),

                    // Transfer Icon
                    const Center(child: Icon(Icons.arrow_downward, size: 32, color: Colors.blue)),
                    const SizedBox(height: 16),

                    // To Account
                    DropdownButtonFormField<String>(
                      value: _toAccountId,
                      decoration: const InputDecoration(
                        labelText: 'To Account',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.account_balance_wallet),
                      ),
                      items: _accounts.map((account) => DropdownMenuItem(
                        value: account.id,
                        child: Row(
                          children: [
                            Icon(_getIcon(account.type), size: 20, color: _getColor(account.type)),
                            const SizedBox(width: 8),
                            Expanded(child: Text('${account.name} (₹${account.balance.toStringAsFixed(0)})')),
                          ],
                        ),
                      )).toList(),
                      onChanged: (value) => setState(() => _toAccountId = value),
                      validator: (value) => value == null ? 'Select destination account' : null,
                    ),
                    const SizedBox(height: 16),

                    // Date
                    ListTile(
                      title: Text('Date: ${DateFormat('dd/MM/yyyy').format(_selectedDate)}'),
                      leading: const Icon(Icons.calendar_today),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                        side: BorderSide(color: Colors.grey.shade400),
                      ),
                      onTap: _selectDate,
                    ),
                    const SizedBox(height: 16),

                    // Notes
                    TextFormField(
                      controller: _notesController,
                      decoration: const InputDecoration(
                        labelText: 'Notes (Optional)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.note),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 24),

                    // Transfer Button
                    ElevatedButton(
                      onPressed: _isLoading ? null : _saveTransfer,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                      child: _isLoading
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Transfer Money', style: TextStyle(fontSize: 16)),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'cash': return Icons.money;
      case 'bank': return Icons.account_balance;
      case 'credit_card': return Icons.credit_card;
      case 'loan': return Icons.receipt_long;
      default: return Icons.wallet;
    }
  }

  Color _getColor(String type) {
    switch (type) {
      case 'cash': return Colors.green;
      case 'bank': return Colors.blue;
      case 'credit_card': return Colors.orange;
      case 'loan': return Colors.red;
      default: return Colors.grey;
    }
  }
}