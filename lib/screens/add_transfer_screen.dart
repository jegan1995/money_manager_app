import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/transfer_model.dart';
import '../models/account_model.dart';
import '../services/transfer_service.dart';
import '../services/account_service.dart';

class AddTransferScreen extends StatefulWidget {
  const AddTransferScreen({super.key});

  @override
  State<AddTransferScreen> createState() => _AddTransferScreenState();
}

class _AddTransferScreenState extends State<AddTransferScreen> {
  final _formKey = GlobalKey<FormState>();
  final TransferService _transferService = TransferService();
  final AccountService _accountService = AccountService();

  final TextEditingController _amountController = TextEditingController();
  String? _fromAccount;
  String? _toAccount;
  DateTime _selectedDate = DateTime.now();
  final TextEditingController _noteController = TextEditingController();
  bool _isLoading = false;

  List<AccountModel> _accounts = [];

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  void _loadAccounts() {
    _accountService.getAccounts().listen((snapshot) {
      setState(() {
        _accounts = snapshot.docs
            .map((doc) => AccountModel.fromMap(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                ))
            .toList();
      });
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transfer Money'),
      ),
      body: _accounts.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.account_balance_wallet_outlined,
                      size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No accounts available'),
                  SizedBox(height: 8),
                  Text(
                    'Please create accounts first',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // From Account
                  DropdownButtonFormField<String>(
                    value: _fromAccount,
                    decoration: const InputDecoration(
                      labelText: 'From Account *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.account_balance_wallet),
                    ),
                    items: _accounts
                        .map((account) => DropdownMenuItem(
                              value: account.id,
                              child: Text(
                                  '${account.name} (₹${account.balance.toStringAsFixed(0)})'),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _fromAccount = value;
                      });
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please select source account';
                      }
                      if (value == _toAccount) {
                        return 'Cannot transfer to same account';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Swap Button
                  Center(
                    child: IconButton(
                      onPressed: () {
                        setState(() {
                          final temp = _fromAccount;
                          _fromAccount = _toAccount;
                          _toAccount = temp;
                        });
                      },
                      icon: const Icon(Icons.swap_vert),
                      iconSize: 32,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // To Account
                  DropdownButtonFormField<String>(
                    value: _toAccount,
                    decoration: const InputDecoration(
                      labelText: 'To Account *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.account_balance),
                    ),
                    items: _accounts
                        .map((account) => DropdownMenuItem(
                              value: account.id,
                              child: Text(
                                  '${account.name} (₹${account.balance.toStringAsFixed(0)})'),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _toAccount = value;
                      });
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please select destination account';
                      }
                      if (value == _fromAccount) {
                        return 'Cannot transfer to same account';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Amount
                  TextFormField(
                    controller: _amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Amount *',
                      prefixText: '₹ ',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.currency_rupee),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter amount';
                      }
                      if (double.tryParse(value) == null) {
                        return 'Please enter valid amount';
                      }
                      if (double.parse(value) <= 0) {
                        return 'Amount must be greater than 0';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Date Picker
                  InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (date != null) {
                        setState(() {
                          _selectedDate = date;
                        });
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Date *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                      child: Text(
                        DateFormat('EEEE, MMM d, yyyy').format(_selectedDate),
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Note
                  TextFormField(
                    controller: _noteController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Note (Optional)',
                      border: OutlineInputBorder(),
                      hintText: 'Add transfer details...',
                      prefixIcon: Icon(Icons.note),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Transfer Button
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _saveTransfer,
                    icon: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.swap_horiz),
                    label: const Text(
                      'TRANSFER',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Future<void> _saveTransfer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final transfer = TransferModel(
        fromAccount: _fromAccount!,
        toAccount: _toAccount!,
        amount: double.parse(_amountController.text),
        date: _selectedDate,
        note: _noteController.text.isEmpty ? null : _noteController.text,
      );

      await _transferService.addTransfer(transfer);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transfer completed successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}