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

  String _type = 'expense';
  final TextEditingController _amountController = TextEditingController();
  String _category = 'Food & Dining';
  String? _subcategory;
  String _paymentMethod = 'Cash';
  DateTime _selectedDate = DateTime.now();
  final TextEditingController _noteController = TextEditingController();
  bool _isLoading = false;

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
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                  _subcategory = null;
                });
              },
            ),
            const SizedBox(height: 16),

            // Subcategory
            DropdownButtonFormField<String>(
              value: _subcategory,
              decoration: const InputDecoration(
                labelText: 'Subcategory (Optional)',
                border: OutlineInputBorder(),
                hintText: 'Select subcategory',
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
                  suffixIcon: Icon(Icons.calendar_today),
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
                hintText: 'Add a note...',
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
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      isEdit ? 'UPDATE' : 'SAVE',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
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
                : (widget.transaction != null ? 'Updated' : 'Added')),
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