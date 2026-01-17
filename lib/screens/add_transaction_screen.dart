import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction_model.dart';
import '../services/transaction_service.dart';
import '../utils/subcategories.dart';

class AddTransactionScreen extends StatefulWidget {
  final TransactionModel? transaction;
  final bool isCopy;

  const AddTransactionScreen({
    super.key,
    this.transaction,
    this.isCopy = false,
  });

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final TransactionService _transactionService = TransactionService();

  // Form fields
  String _type = 'expense';
  final TextEditingController _amountController = TextEditingController();
  String _category = 'Food & Dining';
  String? _subcategory;
  String _account = 'Cash';
  String _paymentMethod = 'Cash';
  DateTime _selectedDate = DateTime.now();
  final TextEditingController _noteController = TextEditingController();
  bool _isLoading = false;

  // Category lists
  final List<String> _expenseCategories = [
    'Food & Dining',
    'Transportation',
    'Shopping',
    'Entertainment',
    'Bills & Utilities',
    'Healthcare',
    'Education',
    'Personal Care',
    'Travel',
    'Others',
  ];

  final List<String> _incomeCategories = [
    'Salary',
    'Business',
    'Investments',
    'Gifts',
    'Others',
  ];

  final List<String> _accounts = [
    'Cash',
    'Bank Account',
    'Credit Card',
    'Debit Card',
    'Wallet',
  ];

  final List<String> _paymentMethods = [
    'Cash',
    'Credit Card',
    'Debit Card',
    'UPI',
    'Net Banking',
    'Wallet',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.transaction != null) {
      _type = widget.transaction!.type;
      _amountController.text = widget.transaction!.amount.toString();
      _category = widget.transaction!.category;
      _subcategory = widget.transaction!.subcategory;
      _account = widget.transaction!.account;
      _paymentMethod = widget.transaction!.paymentMethod;
      _selectedDate = widget.transaction!.date;
      _noteController.text = widget.transaction!.note ?? '';
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.transaction != null && !widget.isCopy;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isCopy
            ? 'Copy Transaction'
            : (isEdit ? 'Edit Transaction' : 'Add Transaction')),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Type Selector
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'expense',
                  label: Text('Expense'),
                  icon: Icon(Icons.arrow_upward),
                ),
                ButtonSegment(
                  value: 'income',
                  label: Text('Income'),
                  icon: Icon(Icons.arrow_downward),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (Set<String> newSelection) {
                setState(() {
                  _type = newSelection.first;
                  _category = _type == 'expense'
                      ? _expenseCategories.first
                      : _incomeCategories.first;
                  _subcategory = null;
                });
              },
            ),
            const SizedBox(height: 20),

            // Amount
            TextFormField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Amount *',
                prefixText: '₹ ',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter amount';
                }
                if (double.tryParse(value) == null) {
                  return 'Please enter valid amount';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Category
            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(
                labelText: 'Category *',
                border: OutlineInputBorder(),
              ),
              items: (_type == 'expense' ? _expenseCategories : _incomeCategories)
                  .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _category = value!;
                  _subcategory = null; // Reset subcategory
                });
              },
            ),
            const SizedBox(height: 16),

            // Subcategory
            DropdownButtonFormField<String>(
              value: _subcategory,
              decoration: const InputDecoration(
                labelText: 'Subcategory',
                border: OutlineInputBorder(),
              ),
              items: Subcategories.getSubcategories(_type, _category)
                  .map((sub) => DropdownMenuItem(value: sub, child: Text(sub)))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _subcategory = value;
                });
              },
            ),
            const SizedBox(height: 16),

            // Account
            DropdownButtonFormField<String>(
              value: _account,
              decoration: const InputDecoration(
                labelText: 'Account *',
                border: OutlineInputBorder(),
              ),
              items: _accounts
                  .map((acc) => DropdownMenuItem(value: acc, child: Text(acc)))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _account = value!;
                });
              },
            ),
            const SizedBox(height: 16),

            // Payment Method (Mandatory)
            DropdownButtonFormField<String>(
              value: _paymentMethod,
              decoration: const InputDecoration(
                labelText: 'Payment Method *',
                border: OutlineInputBorder(),
              ),
              items: _paymentMethods
                  .map((pm) => DropdownMenuItem(value: pm, child: Text(pm)))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _paymentMethod = value!;
                });
              },
            ),
            const SizedBox(height: 16),

            // Date Picker
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Date *'),
              subtitle: Text(DateFormat('EEEE, MMM d, yyyy').format(_selectedDate)),
              trailing: const Icon(Icons.calendar_today),
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
            ),
            const Divider(),

            // Note
            TextFormField(
              controller: _noteController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Note',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),

            // Save Button
            ElevatedButton(
              onPressed: _isLoading ? null : _saveTransaction,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : Text(isEdit ? 'Update' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveTransaction() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final transaction = TransactionModel(
        id: widget.transaction?.id,
        type: _type,
        amount: double.parse(_amountController.text),
        category: _category,
        subcategory: _subcategory,
        account: _account,
        paymentMethod: _paymentMethod,
        date: _selectedDate,
        note: _noteController.text.isEmpty ? null : _noteController.text,
        imageUrl: widget.transaction?.imageUrl,
      );

      if (widget.transaction != null && !widget.isCopy) {
        await _transactionService.updateTransaction(
          widget.transaction!.id!,
          transaction,
        );
      } else {
        await _transactionService.addTransaction(transaction);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.isCopy
                ? 'Transaction copied'
                : (widget.transaction != null
                    ? 'Transaction updated'
                    : 'Transaction added')),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
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