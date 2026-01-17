import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/transaction_model.dart';
import '../models/account_model.dart';
import '../services/transaction_service.dart';
import '../services/account_service.dart';
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
  final AccountService _accountService = AccountService();

  String _type = 'expense';
  final TextEditingController _amountController = TextEditingController();
  String? _selectedCategory;
  String? _selectedSubcategory;
  String _paymentMethod = 'Cash';
  String? _fromAccount;
  String? _toAccount;
  DateTime _selectedDate = DateTime.now();
  final TextEditingController _noteController = TextEditingController();
  bool _isLoading = false;

  List<AccountModel> _accounts = [];

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
    _loadAccounts();
    if (widget.transaction != null) {
      _type = widget.transaction!.type;
      _amountController.text = widget.transaction!.amount.toString();
      _selectedCategory = widget.transaction!.category;
      _selectedSubcategory = widget.transaction!.subcategory;
      _paymentMethod = widget.transaction!.paymentMethod ?? 'Cash';
      _fromAccount = widget.transaction!.fromAccount;
      _toAccount = widget.transaction!.toAccount;
      _selectedDate = widget.transaction!.date;
      _noteController.text = widget.transaction!.note ?? '';
    }
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
            // Type Selector (Income/Expense/Transfer)
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'expense',
                  label: Text('Expense'),
                  icon: Icon(Icons.remove_circle_outline),
                ),
                ButtonSegment(
                  value: 'income',
                  label: Text('Income'),
                  icon: Icon(Icons.add_circle_outline),
                ),
                ButtonSegment(
                  value: 'transfer',
                  label: Text('Transfer'),
                  icon: Icon(Icons.swap_horiz),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (Set<String> newSelection) {
                setState(() {
                  _type = newSelection.first;
                  _selectedCategory = null;
                  _selectedSubcategory = null;
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

            // Show different fields based on type
            if (_type == 'transfer') ...[
              _buildTransferFields(),
            ] else ...[
              _buildCategoryFields(),
              const SizedBox(height: 16),
              _buildPaymentMethodField(),
            ],

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
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryFields() {
    final categories = Categories.getMainCategories(_type);

    return Column(
      children: [
        // Category Selector (Opens bottom sheet)
        InkWell(
          onTap: () => _showCategoryPicker(categories),
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Category *',
              border: OutlineInputBorder(),
              suffixIcon: Icon(Icons.arrow_drop_down),
            ),
            child: Text(
              _selectedCategory != null
                  ? _selectedSubcategory != null
                      ? '$_selectedCategory - $_selectedSubcategory'
                      : _selectedCategory!
                  : 'Select category',
              style: TextStyle(
                fontSize: 16,
                color: _selectedCategory != null ? Colors.black : Colors.grey,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showCategoryPicker(List<String> categories) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Select Category',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    final subcategories =
                        Categories.getSubcategories(_type, category);

                    return ExpansionTile(
                      leading: Icon(
                        _getCategoryIcon(category),
                        color: _type == 'expense' ? Colors.red : Colors.green,
                      ),
                      title: Text(
                        category,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      children: subcategories.map((sub) {
                        return ListTile(
                          contentPadding:
                              const EdgeInsets.only(left: 72, right: 16),
                          title: Text(sub),
                          onTap: () {
                            setState(() {
                              _selectedCategory = category;
                              _selectedSubcategory = sub;
                            });
                            Navigator.pop(context);
                          },
                          trailing: _selectedCategory == category &&
                                  _selectedSubcategory == sub
                              ? const Icon(Icons.check, color: Colors.blue)
                              : null,
                        );
                      }).toList(),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPaymentMethodField() {
    return DropdownButtonFormField<String>(
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
    );
  }

  Widget _buildTransferFields() {
    return Column(
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
      ],
    );
  }

  Future<void> _saveTransaction() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate category for income/expense
    if (_type != 'transfer' && _selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a category'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final transaction = TransactionModel(
        id: widget.transaction?.id,
        type: _type,
        amount: double.parse(_amountController.text),
        category: _type == 'transfer' ? 'Transfer' : _selectedCategory!,
        subcategory: _selectedSubcategory,
        paymentMethod: _type == 'transfer' ? null : _paymentMethod,
        fromAccount: _type == 'transfer' ? _fromAccount : null,
        toAccount: _type == 'transfer' ? _toAccount : null,
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

        // Update account balances for transfers
        if (_type == 'transfer') {
          await _accountService.updateAccountBalance(
            _fromAccount!,
            -transaction.amount,
          );
          await _accountService.updateAccountBalance(
            _toAccount!,
            transaction.amount,
          );
        }
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

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Food & Dining':
        return Icons.restaurant;
      case 'Transportation':
        return Icons.directions_car;
      case 'Shopping':
        return Icons.shopping_bag;
      case 'Entertainment':
        return Icons.movie;
      case 'Bills & Utilities':
        return Icons.receipt;
      case 'Healthcare':
        return Icons.local_hospital;
      case 'Education':
        return Icons.school;
      case 'Personal Care':
        return Icons.spa;
      case 'Travel':
        return Icons.flight;
      case 'Salary':
        return Icons.account_balance_wallet;
      case 'Business':
        return Icons.business;
      case 'Investments':
        return Icons.trending_up;
      case 'Gifts':
        return Icons.card_giftcard;
      default:
        return Icons.category;
    }
  }
}
