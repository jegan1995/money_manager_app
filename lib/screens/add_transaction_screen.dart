import '../utils/categories.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/transaction_model.dart';
import '../models/account_model.dart';
import '../services/transaction_service.dart';
import '../services/account_service.dart';
import 'accounts_screen.dart';
import '../widgets/custom_snackbar.dart';
import '../widgets/loading_overlay.dart';
import 'dart:typed_data';
import '../services/storage_service.dart';
import '../widgets/receipt_picker.dart';

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

  // Receipt fields
  final StorageService _storageService = StorageService();
  Uint8List? _receiptImage;
  String? _receiptUrl;

  String _type = 'expense';
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  String? _selectedCategory;
  String? _selectedSubcategory;
  String? _paymentMethod;
  String? _fromAccount;
  String? _toAccount;

  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  bool _isRecurring = false;
  String _recurringFrequency = 'monthly';

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
      _paymentMethod = widget.transaction!.paymentMethod;
      _fromAccount = widget.transaction!.fromAccount;
      _toAccount = widget.transaction!.toAccount;
      _selectedDate = widget.transaction!.date;
      _noteController.text = widget.transaction!.note ?? '';
      _descriptionController.text = widget.transaction!.description ?? '';
      _receiptUrl = widget.transaction!.imageUrl;
    }
  }

  void _loadAccounts() {
    _accountService.getAccounts().listen((accountsList) {
      setState(() {
        _accounts = accountsList;
      });
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _descriptionController.dispose();
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
                  value: 'income',
                  label: Text('Income'),
                  icon: Icon(Icons.add_circle_outline),
                ),
                ButtonSegment(
                  value: 'expense',
                  label: Text('Expense'),
                  icon: Icon(Icons.remove_circle_outline),
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
                  _fromAccount = null;
                  _toAccount = null;
                });
              },
            ),
            const SizedBox(height: 20),

            // Amount
            TextFormField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
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

            // Date Picker
            Row(
              children: [
                Expanded(
                  child: InkWell(
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
                        DateFormat('MMM d, yyyy').format(_selectedDate),
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Repeat toggle
                InkWell(
                  onTap: () {
                    setState(() {
                      _isRecurring = !_isRecurring;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[400]!),
                      borderRadius: BorderRadius.circular(4),
                      color: _isRecurring ? Colors.blue[50] : null,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.repeat,
                          color: _isRecurring ? Colors.blue : Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Repeat',
                          style: TextStyle(
                            color:
                                _isRecurring ? Colors.blue : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Recurring frequency
            if (_isRecurring) ...[
              DropdownButtonFormField<String>(
                value: _recurringFrequency,
                decoration: const InputDecoration(
                  labelText: 'Repeat Frequency',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.loop),
                ),
                items: const [
                  DropdownMenuItem(value: 'daily', child: Text('Daily')),
                  DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                  DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                  DropdownMenuItem(value: 'yearly', child: Text('Yearly')),
                ],
                onChanged: (value) {
                  setState(() {
                    _recurringFrequency = value!;
                  });
                },
              ),
              const SizedBox(height: 16),
            ],

            // Fields based on type
            if (_type == 'transfer') ...[
              _buildTransferFields(),
            ] else ...[
              _buildCategoryFields(),
              const SizedBox(height: 16),
              _buildAccountField(),
            ],

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

            // Description
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'Additional details',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.description),
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

  Widget _buildAccountField() {
    if (_accounts.isEmpty) {
      return Column(
        children: [
          OutlinedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AccountsScreen(),
                ),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('Create Account First'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.all(16),
              minimumSize: const Size.fromHeight(50),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You need at least one account to add transactions',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      );
    }

    return DropdownButtonFormField<String>(
      value: _type == 'income' ? _toAccount : _fromAccount,
      decoration: const InputDecoration(
        labelText: 'Account *',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.account_balance_wallet),
        hintText: 'Select account',
      ),
      items: _accounts.map((account) {
        return DropdownMenuItem<String>(
          value: account.id,
          child: Row(
            children: [
              Icon(_getAccountTypeIcon(account.type), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${account.name} (₹${account.balance.toStringAsFixed(0)})',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          if (_type == 'income') {
            _toAccount = value;
          } else {
            _fromAccount = value;
          }
        });
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please select an account';
        }
        return null;
      },
    );
  }

  IconData _getAccountTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'bank':
        return Icons.account_balance;
      case 'cash':
        return Icons.money;
      case 'credit card':
      case 'card':
        return Icons.credit_card;
      case 'wallet':
        return Icons.account_balance_wallet;
      case 'loan':
        return Icons.trending_down;
      default:
        return Icons.account_circle;
    }
  }

  Widget _buildCategoryFields() {
    return Column(
      children: [
        InkWell(
          onTap: () => _showCategoryPicker(),
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

  void _showCategoryPicker() {
    final categories = Categories.getMainCategories(_type);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              // Header
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

              // Categories Grid
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    final subcategories =
                        Categories.getSubcategories(_type, category);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          color: Colors.grey[200],
                          child: Row(
                            children: [
                              Icon(
                                _getCategoryIcon(category),
                                color: _type == 'expense'
                                    ? Colors.red
                                    : Colors.green,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                category,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              childAspectRatio: 2.5,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                            ),
                            itemCount: subcategories.length,
                            itemBuilder: (context, subIndex) {
                              final sub = subcategories[subIndex];
                              final isSelected =
                                  _selectedCategory == category &&
                                      _selectedSubcategory == sub;

                              return OutlinedButton(
                                onPressed: () {
                                  setState(() {
                                    _selectedCategory = category;
                                    _selectedSubcategory = sub;
                                  });
                                  Navigator.pop(context);
                                },
                                style: OutlinedButton.styleFrom(
                                  backgroundColor:
                                      isSelected ? Colors.blue[50] : null,
                                  side: BorderSide(
                                    color: isSelected
                                        ? Colors.blue
                                        : Colors.grey[300]!,
                                    width: isSelected ? 2 : 1,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                ),
                                child: Text(
                                  sub,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color:
                                        isSelected ? Colors.blue : Colors.black,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Custom categories coming in next update!'),
                                  backgroundColor: Colors.blue,
                                ),
                              );
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Add New Category'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildTransferFields() {
    return Column(
      children: [
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

    if (_type != 'transfer' && _selectedCategory == null) {
      CustomSnackBar.show(
        context,
        message: 'Please select a category',
        type: SnackBarType.error,
      );
      return;
    }

    LoadingOverlay.show(context, message: 'Saving...');

    try {
      final tempId = DateTime.now().millisecondsSinceEpoch.toString();

      String? uploadedImageUrl;
      // if (_receiptImage != null) {
      //   uploadedImageUrl = await _storageService.uploadReceipt(
      //     _receiptImage!,
      //     widget.transaction?.id ?? tempId,
      //   );
      // }

      final transaction = TransactionModel(
        userId: '',
        id: '',
        type: _type,
        amount: double.parse(_amountController.text),
        category: _selectedCategory ?? '',
        subcategory: _selectedSubcategory,
        paymentMethod: _paymentMethod,
        date: _selectedDate,
        note: _noteController.text.isEmpty ? null : _noteController.text,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        fromAccount: _type == 'transfer'
            ? _fromAccount
            : (_type == 'expense' ? _fromAccount : null),
        toAccount: _type == 'transfer'
            ? _toAccount
            : (_type == 'income' ? _toAccount : null),
        isRecurring: _isRecurring,
        recurringFrequency: _isRecurring ? _recurringFrequency : null,
        imageUrl: uploadedImageUrl ?? _receiptUrl,
        createdAt: DateTime.now(),
      );

      if (widget.transaction != null && !widget.isCopy) {
        await _transactionService.updateTransaction(
          widget.transaction!.id,
          transaction,
        );
      } else {
        await _transactionService.addTransaction(transaction);
      }

      if (mounted) {
        LoadingOverlay.hide(context);
        CustomSnackBar.show(
          context,
          message: widget.isCopy
              ? 'Transaction copied successfully!'
              : (widget.transaction != null
                  ? 'Transaction updated!'
                  : 'Transaction saved successfully!'),
          type: SnackBarType.success,
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        LoadingOverlay.hide(context);
        CustomSnackBar.show(
          context,
          message: 'Failed to save: $e',
          type: SnackBarType.error,
        );
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
