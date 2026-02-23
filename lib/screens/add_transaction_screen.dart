import '../utils/categories.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/transaction_model.dart';
import '../models/account_model.dart';
import '../services/transaction_service.dart';
import '../services/account_service.dart';
import '../services/voice_input_service.dart';
import '../widgets/voice_input_sheet.dart';
import 'accounts_screen.dart';
import '../widgets/custom_snackbar.dart';
import '../widgets/loading_overlay.dart';
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
  final StorageService _storageService = StorageService();

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

  // Voice input state
  bool _voiceFilled = false;

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
    }
  }

  void _loadAccounts() {
    _accountService.getAccounts().listen((accountsList) {
      if (mounted) setState(() => _accounts = accountsList);
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // ── Voice Input ──────────────────────────────────────────────────────────────

  Future<void> _openVoiceInput() async {
    final result = await showModalBottomSheet<VoiceParseResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => VoiceInputSheet(accounts: _accounts),
    );

    if (result != null && mounted) {
      _applyVoiceResult(result);
    }
  }

  void _applyVoiceResult(VoiceParseResult result) {
    setState(() {
      _voiceFilled = true;

      if (result.type != null) _type = result.type!;
      if (result.amount != null) {
        _amountController.text = result.amount!.toStringAsFixed(0);
      }
      if (result.category != null) _selectedCategory = result.category;
      if (result.subcategory != null) _selectedSubcategory = result.subcategory;

      if (result.fromAccount != null) {
        if (_type == 'income') {
          _toAccount = result.fromAccount;
        } else {
          _fromAccount = result.fromAccount;
        }
      }
      if (result.toAccount != null) _toAccount = result.toAccount;

      if (result.note != null && result.note!.isNotEmpty) {
        _noteController.text = result.note!;
      }
      if (result.date != null) _selectedDate = result.date!;
    });

    // Show info about what was filled
    final filled = <String>[];
    if (result.amount != null) filled.add('Amount');
    if (result.category != null) filled.add('Category');
    if (result.fromAccount != null) filled.add('Account');

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Auto-filled: ${filled.join(', ')}. Review before saving.',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.indigo,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.transaction != null && !widget.isCopy;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isCopy
            ? 'Copy Transaction'
            : (isEdit ? 'Edit Transaction' : 'Add Transaction')),
        actions: [
          // Voice input button
          if (!isEdit)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Tooltip(
                message: 'Voice Input',
                child: InkWell(
                  onTap: _openVoiceInput,
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _voiceFilled
                          ? Colors.indigo.withOpacity(0.15)
                          : theme.colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _voiceFilled
                            ? Colors.indigo
                            : theme.colorScheme.primary.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _voiceFilled ? Icons.auto_awesome : Icons.mic,
                          size: 18,
                          color: _voiceFilled
                              ? Colors.indigo
                              : theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _voiceFilled ? 'Auto-filled' : 'Voice',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _voiceFilled
                                ? Colors.indigo
                                : theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Voice fill banner
            if (_voiceFilled) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.indigo.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: Colors.indigo.withOpacity(0.25)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome,
                        size: 16, color: Colors.indigo),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Fields auto-filled by voice. Please review.',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.indigo,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                    InkWell(
                      onTap: () => setState(() => _voiceFilled = false),
                      child:
                          const Icon(Icons.close, size: 16, color: Colors.indigo),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

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
              decoration: InputDecoration(
                labelText: 'Amount *',
                prefixText: '₹ ',
                border: const OutlineInputBorder(),
                suffixIcon: _voiceFilled && _amountController.text.isNotEmpty
                    ? const Icon(Icons.auto_awesome,
                        size: 16, color: Colors.indigo)
                    : null,
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
                        setState(() => _selectedDate = date);
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
                InkWell(
                  onTap: () {
                    setState(() => _isRecurring = !_isRecurring);
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
                          color:
                              _isRecurring ? Colors.blue : Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Repeat',
                          style: TextStyle(
                            color: _isRecurring
                                ? Colors.blue
                                : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

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
                  DropdownMenuItem(
                      value: 'monthly', child: Text('Monthly')),
                  DropdownMenuItem(value: 'yearly', child: Text('Yearly')),
                ],
                onChanged: (value) {
                  setState(() => _recurringFrequency = value!);
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
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Note (Optional)',
                border: OutlineInputBorder(),
                hintText: 'Add a note...',
              ),
            ),

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
            const SizedBox(height: 32),
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
                    builder: (context) => const AccountsScreen()),
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
                      ? '$_selectedCategory › $_selectedSubcategory'
                      : _selectedCategory!
                  : 'Select category',
              style: TextStyle(
                fontSize: 16,
                color: _selectedCategory != null ? null : Colors.grey,
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
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  border:
                      Border(bottom: BorderSide(color: Colors.grey[300]!)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Select Category',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
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

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Category header - tap to select without subcategory
                        InkWell(
                          onTap: () {
                            setState(() {
                              _selectedCategory = category;
                              _selectedSubcategory = null;
                            });
                            Navigator.pop(context);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            color: Colors.grey[100],
                            child: Row(
                              children: [
                                Icon(_getCategoryIcon(category),
                                    color: _type == 'expense'
                                        ? Colors.red
                                        : Colors.green),
                                const SizedBox(width: 12),
                                Text(category,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16)),
                                const Spacer(),
                                Icon(Icons.chevron_right,
                                    color: Colors.grey[400], size: 18),
                              ],
                            ),
                          ),
                        ),
                        if (subcategories.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: subcategories.map((sub) {
                                final isSelected =
                                    _selectedCategory == category &&
                                        _selectedSubcategory == sub;
                                return InkWell(
                                  onTap: () {
                                    setState(() {
                                      _selectedCategory = category;
                                      _selectedSubcategory = sub;
                                    });
                                    Navigator.pop(context);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? Theme.of(context)
                                              .colorScheme
                                              .primary
                                              .withOpacity(0.1)
                                          : Colors.grey[100],
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: isSelected
                                            ? Theme.of(context)
                                                .colorScheme
                                                .primary
                                            : Colors.grey[300]!,
                                      ),
                                    ),
                                    child: Text(sub,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: isSelected
                                              ? Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                              : null,
                                          fontWeight: isSelected
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                        )),
                                  ),
                                );
                              }).toList(),
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
          onChanged: (value) => setState(() => _fromAccount = value),
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
          onChanged: (value) => setState(() => _toAccount = value),
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
        imageUrl: null,
        createdAt: DateTime.now(),
      );

      if (widget.transaction != null && !widget.isCopy) {
        await _transactionService.updateTransaction(
            widget.transaction!.id, transaction);
      } else {
        await _transactionService.addTransaction(transaction);
      }

      if (mounted) {
        LoadingOverlay.hide(context);
        final messenger = ScaffoldMessenger.of(context);
        Navigator.pop(context);
        messenger.clearSnackBars();
        messenger.showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('Transaction saved!',
                    style: TextStyle(color: Colors.white, fontSize: 13)),
              ],
            ),
            backgroundColor: const Color(0xFF2E7D32),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            duration: const Duration(seconds: 3),
          ),
        );
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
        return Icons.face;
      case 'Travel':
        return Icons.flight;
      case 'Salary':
        return Icons.work;
      case 'Business':
        return Icons.business;
      case 'Investments':
        return Icons.trending_up;
      case 'Freelance':
        return Icons.computer;
      case 'Gifts':
        return Icons.card_giftcard;
      case 'Rental Income':
        return Icons.home;
      default:
        return Icons.category;
    }
  }
}