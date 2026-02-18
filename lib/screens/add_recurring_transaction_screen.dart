import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/recurring_transaction_model.dart';
import '../models/account_model.dart';
import '../services/recurring_transaction_service.dart';
import '../services/account_service.dart';
import '../utils/categories.dart';

class AddRecurringTransactionScreen extends StatefulWidget {
  final RecurringTransactionModel? recurring;

  const AddRecurringTransactionScreen({super.key, this.recurring});

  @override
  State<AddRecurringTransactionScreen> createState() =>
      _AddRecurringTransactionScreenState();
}

class _AddRecurringTransactionScreenState
    extends State<AddRecurringTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final RecurringTransactionService _service = RecurringTransactionService();
  final AccountService _accountService = AccountService();

  String _type = 'expense';
  String? _category;
  String? _subcategory;
  String? _selectedAccount;
  String _frequency = 'monthly';
  
  DateTime _startDate = DateTime.now();
  bool _isLoading = false;
  List<AccountModel> _accounts = [];

  @override
  void initState() {
    super.initState();
    _loadAccounts();

    if (widget.recurring != null) {
      final r = widget.recurring!;
      _type = r.type;
      _category = r.category;
      _subcategory = r.subcategory;
      _selectedAccount = r.type == 'income' ? r.toAccount : r.fromAccount;
      _frequency = r.frequency;
      _startDate = r.nextDate;
      _amountController.text = r.amount.toString();
      _noteController.text = r.note ?? '';
    }
  }

  void _loadAccounts() {
    _accountService.getAccountsList().listen((accounts) {
      setState(() => _accounts = accounts);
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_category == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final recurring = RecurringTransactionModel(
        id: widget.recurring?.id ?? '',
        userId: '', // Will be set in service
        type: _type,
        amount: double.parse(_amountController.text),
        category: _category!,
        subcategory: _subcategory,
        fromAccount: _type == 'expense' ? _selectedAccount : null,
        toAccount: _type == 'income' ? _selectedAccount : null,
        frequency: _frequency,
        nextDate: _startDate,
        lastExecuted: widget.recurring?.lastExecuted,
        isActive: true,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        createdAt: widget.recurring?.createdAt ?? DateTime.now(),
      );

      if (widget.recurring == null) {
        await _service.addRecurringTransaction(recurring);
      } else {
        await _service.updateRecurringTransaction(
            widget.recurring!.id, recurring);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.recurring == null ? 'Added!' : 'Updated!'),
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
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            Text(widget.recurring == null ? 'Add Recurring' : 'Edit Recurring'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Type Selector
            _buildTypeSelector(),
            const SizedBox(height: 20),

            // Amount
            TextFormField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Amount *',
                prefixText: '₹ ',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return 'Required';
                if (double.tryParse(value) == null) return 'Invalid amount';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Category
            _buildCategoryDropdown(),
            const SizedBox(height: 16),

            // Subcategory
            if (_category != null && _subcategory != null)
              _buildSubcategoryDropdown(),
            if (_category != null && _subcategory != null)
              const SizedBox(height: 16),

            // Account
            _buildAccountDropdown(),
            const SizedBox(height: 16),

            // Frequency
            _buildFrequencyDropdown(),
            const SizedBox(height: 16),

            // Start Date
            _buildDatePicker(),
            const SizedBox(height: 16),

            // Note
            TextFormField(
              controller: _noteController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Note (Optional)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Save Button
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        widget.recurring == null ? 'Add Recurring' : 'Update',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTypeButton('Income', 'income', Colors.green),
          ),
          Expanded(
            child: _buildTypeButton('Expense', 'expense', Colors.red),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeButton(String label, String value, Color color) {
    final isSelected = _type == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _type = value;
          _category = null;
          _subcategory = null;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isSelected)
              const Icon(Icons.check, color: Colors.white, size: 18),
            if (isSelected) const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[700],
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    final categoryList = _type == 'income'
        ? Categories.incomeCategories
        : Categories.expenseCategories;

    return DropdownButtonFormField<String>(
      value: _category,
      decoration: InputDecoration(
        labelText: 'Category *',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: categoryList.map((cat) {
        return DropdownMenuItem(value: cat, child: Text(cat));
      }).toList(),
      onChanged: (value) {
        setState(() {
          _category = value;
          // Set first subcategory if available
          final subcats = Categories.getSubcategories(_type, value!);
          _subcategory = subcats.isNotEmpty ? subcats.first : null;
        });
      },
      validator: (value) => value == null ? 'Required' : null,
    );
  }

  Widget _buildSubcategoryDropdown() {
    // Use Categories.getSubcategories() method
    final subcategories = _category != null
        ? Categories.getSubcategories(_type, _category!)
        : <String>[];

    if (subcategories.isEmpty) {
      return const SizedBox.shrink();
    }

    return DropdownButtonFormField<String>(
      value: _subcategory,
      decoration: InputDecoration(
        labelText: 'Subcategory',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: subcategories.map((sub) {
        return DropdownMenuItem(value: sub, child: Text(sub));
      }).toList(),
      onChanged: (value) => setState(() => _subcategory = value),
    );
  }

  Widget _buildAccountDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedAccount,
      decoration: InputDecoration(
        labelText: 'Account *',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: _accounts.map((acc) {
        return DropdownMenuItem(
          value: acc.id,
          child: Text('${acc.name} (₹${acc.balance.toStringAsFixed(0)})'),
        );
      }).toList(),
      onChanged: (value) => setState(() => _selectedAccount = value),
      validator: (value) => value == null ? 'Required' : null,
    );
  }

  Widget _buildFrequencyDropdown() {
    return DropdownButtonFormField<String>(
      value: _frequency,
      decoration: InputDecoration(
        labelText: 'Frequency *',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: const [
        DropdownMenuItem(value: 'daily', child: Text('Daily')),
        DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
        DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
        DropdownMenuItem(value: 'yearly', child: Text('Yearly')),
      ],
      onChanged: (value) => setState(() => _frequency = value!),
    );
  }

  Widget _buildDatePicker() {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('Start Date'),
      subtitle: Text(DateFormat('MMMM d, yyyy').format(_startDate)),
      trailing: const Icon(Icons.calendar_today),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[300]!),
      ),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _startDate,
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 3650)),
        );
        if (picked != null) {
          setState(() => _startDate = picked);
        }
      },
    );
  }
}
