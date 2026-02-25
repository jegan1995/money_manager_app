import '../utils/categories.dart';
import '../models/custom_category_model.dart';
import '../services/custom_category_service.dart';
import 'custom_categories_screen.dart';
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
  final CustomCategoryService _customCatSvc = CustomCategoryService();

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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CategoryPickerSheet(
        type: _type,
        selectedCategory: _selectedCategory,
        selectedSubcategory: _selectedSubcategory,
        customCatSvc: _customCatSvc,
        onSelected: (cat, sub) {
          setState(() {
            _selectedCategory = cat;
            _selectedSubcategory = sub;
          });
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



// ── Category Picker Bottom Sheet ─────────────────────────────────────────────
class _CategoryPickerSheet extends StatefulWidget {
  final String type;
  final String? selectedCategory;
  final String? selectedSubcategory;
  final CustomCategoryService customCatSvc;
  final void Function(String category, String? subcategory) onSelected;

  const _CategoryPickerSheet({
    required this.type,
    required this.selectedCategory,
    required this.selectedSubcategory,
    required this.customCatSvc,
    required this.onSelected,
  });

  @override
  State<_CategoryPickerSheet> createState() => _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends State<_CategoryPickerSheet> {
  List<CustomCategory> _customCats = [];
  bool _loadingCustom = true;

  @override
  void initState() {
    super.initState();
    _loadCustom();
  }

  Future<void> _loadCustom() async {
    final cats = await widget.customCatSvc.getCategoriesOnce(type: widget.type);
    if (mounted) setState(() { _customCats = cats; _loadingCustom = false; });
  }

  Color get _accentColor =>
      widget.type == 'expense' ? Colors.red : Colors.green;

  @override
  Widget build(BuildContext context) {
    final builtIn  = Categories.getMainCategories(widget.type);
    final isDark   = Theme.of(context).brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollCtrl) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2530) : Colors.white,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10),
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                child: Row(
                  children: [
                    Text('Select Category',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  const CustomCategoriesScreen()),
                        );
                      },
                      icon: const Icon(Icons.edit, size: 14),
                      label: const Text('Manage', style: TextStyle(fontSize: 12)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  children: [

                    // ── Custom categories (if any) ────────────────────────────
                    if (_loadingCustom)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(
                            child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    else if (_customCats.isNotEmpty) ...[
                      _sectionHeader('⭐ My Categories', _accentColor),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _customCats.map((cat) {
                            final isSel = widget.selectedCategory == cat.name;
                            return GestureDetector(
                              onTap: () {
                                widget.onSelected(cat.name, null);
                                Navigator.pop(context);
                                // If has subcategories, show sub-picker
                                if (cat.subcategories.isNotEmpty) {
                                  _showSubPicker(context, cat.name,
                                      cat.subcategories, cat.color);
                                }
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isSel
                                      ? cat.color
                                      : cat.color.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: cat.color.withOpacity(0.4)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(cat.emoji,
                                        style: const TextStyle(fontSize: 18)),
                                    const SizedBox(width: 6),
                                    Text(cat.name,
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: isSel
                                                ? Colors.white
                                                : cat.color)),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const Divider(),
                    ],

                    // ── Built-in categories ───────────────────────────────────
                    _sectionHeader('📋 Default Categories', Colors.grey),
                    ...builtIn.map((cat) {
                      final subs    = Categories.getSubcategories(widget.type, cat);
                      final isSel   = widget.selectedCategory == cat;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Category header row
                          InkWell(
                            onTap: () {
                              widget.onSelected(cat, null);
                              Navigator.pop(context);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              color: isSel
                                  ? _accentColor.withOpacity(0.08)
                                  : isDark
                                      ? const Color(0xFF252D3A)
                                      : Colors.grey[100],
                              child: Row(
                                children: [
                                  Container(
                                    width: 36, height: 36,
                                    decoration: BoxDecoration(
                                      color: _accentColor.withOpacity(0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      _builtInIcon(cat),
                                      color: _accentColor, size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(cat,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15)),
                                  ),
                                  if (isSel)
                                    Icon(Icons.check_circle,
                                        color: _accentColor, size: 20),
                                ],
                              ),
                            ),
                          ),
                          // Subcategory chips
                          if (subs.isNotEmpty)
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(12, 8, 12, 8),
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: subs.map((sub) {
                                  final isSubSel =
                                      widget.selectedCategory == cat &&
                                          widget.selectedSubcategory == sub;
                                  return GestureDetector(
                                    onTap: () {
                                      widget.onSelected(cat, sub);
                                      Navigator.pop(context);
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: isSubSel
                                            ? _accentColor
                                            : _accentColor.withOpacity(0.07),
                                        borderRadius:
                                            BorderRadius.circular(16),
                                        border: Border.all(
                                            color: _accentColor.withOpacity(
                                                0.25)),
                                      ),
                                      child: Text(sub,
                                          style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: isSubSel
                                                  ? Colors.white
                                                  : _accentColor)),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          const Divider(height: 1),
                        ],
                      );
                    }),

                    // ── Add custom category button ─────────────────────────────
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const CustomCategoriesScreen()),
                          );
                        },
                        icon: Icon(Icons.add, color: _accentColor),
                        label: Text('Create Custom Category',
                            style: TextStyle(color: _accentColor)),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          side: BorderSide(
                              color: _accentColor.withOpacity(0.5)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _sectionHeader(String label, Color color) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color)),
      );

  IconData _builtInIcon(String cat) {
    switch (cat) {
      case 'Food & Dining':   return Icons.restaurant;
      case 'Shopping':        return Icons.shopping_bag;
      case 'Transportation':  return Icons.directions_car;
      case 'Entertainment':   return Icons.movie;
      case 'Bills & Utilities': return Icons.receipt_long;
      case 'Healthcare':      return Icons.medical_services;
      case 'Education':       return Icons.school;
      case 'Personal Care':   return Icons.face;
      case 'Travel':          return Icons.flight;
      case 'Salary':          return Icons.work;
      case 'Business':        return Icons.business;
      case 'Investments':     return Icons.trending_up;
      case 'Freelance':       return Icons.computer;
      case 'Rental Income':   return Icons.home;
      case 'Gifts':           return Icons.card_giftcard;
      default:                return Icons.category;
    }
  }

  void _showSubPicker(BuildContext context, String catName,
      List<String> subs, Color color) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$catName — pick subcategory',
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: subs.map((s) => GestureDetector(
                    onTap: () {
                      widget.onSelected(catName, s);
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border:
                            Border.all(color: color.withOpacity(0.3)),
                      ),
                      child: Text(s,
                          style: TextStyle(
                              fontSize: 13, color: color)),
                    ),
                  )).toList(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}