// lib/screens/add_transaction_screen.dart
import '../utils/categories.dart';
import '../models/custom_category_model.dart';
import '../services/custom_category_service.dart';
import 'custom_categories_screen.dart';
import 'receipt_scanner_screen.dart';
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
  String? _selectedSubSub;
  String? _paymentMethod;
  String? _fromAccount;
  String? _toAccount;

  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  bool _isRecurring = false;
  String _recurringFrequency = 'monthly';

  List<AccountModel> _accounts = [];
  bool _isBookmarked = false;

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
      // subSub stored in note prefix if needed; start empty
      _selectedSubSub = null;
      _paymentMethod = widget.transaction!.paymentMethod;
      _fromAccount = widget.transaction!.fromAccount;
      _toAccount = widget.transaction!.toAccount;
      _selectedDate = widget.transaction!.date;
      _noteController.text = widget.transaction!.note ?? '';
      _descriptionController.text = widget.transaction!.description ?? '';
      _receiptUrl = widget.transaction!.imageUrl;
      _loadBookmark();
    }
  }

  Future<void> _loadBookmark() async {
    if (widget.transaction == null || widget.transaction!.id.isEmpty) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('transactions')
          .doc(widget.transaction!.id)
          .get();
      if (doc.exists && mounted) {
        setState(() {
          _isBookmarked = doc.data()?['isBookmarked'] ?? false;
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleBookmark() async {
    if (widget.transaction == null) return;
    final newVal = !_isBookmarked;
    setState(() => _isBookmarked = newVal);
    try {
      await FirebaseFirestore.instance
          .collection('transactions')
          .doc(widget.transaction!.id)
          .update({'isBookmarked': newVal});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(newVal ? '🔖 Bookmarked!' : 'Bookmark removed'),
          backgroundColor: newVal ? const Color(0xFF667eea) : Colors.grey,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 1),
        ));
      }
    } catch (_) {}
  }

  Future<void> _deleteTransaction() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Transaction'),
        content: const Text('This cannot be undone. Delete this transaction?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await _transactionService.deleteTransaction(widget.transaction!.id);
      if (mounted) Navigator.pop(context);
    }
  }

  void _openAsCopy() {
    Navigator.pushReplacement(context, MaterialPageRoute(
      builder: (_) => AddTransactionScreen(
        transaction: widget.transaction, isCopy: true),
    ));
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

  // ── Open Receipt Scanner and pre-fill form with result ────────────────────
  Future<void> _openReceiptScanner() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const ReceiptScannerScreen()),
    );
    if (result != null && mounted) {
      setState(() {
        if (result['amount'] != null) {
          _amountController.text =
              (result['amount'] as double).toStringAsFixed(0);
        }
        if (result['category'] != null) {
          _selectedCategory = result['category'] as String;
          _selectedSubcategory = null;
        }
        if (result['note'] != null) {
          _noteController.text = result['note'] as String;
        }
        if (result['description'] != null) {
          _descriptionController.text = result['description'] as String;
        }
        if (result['date'] != null) {
          _selectedDate = result['date'] as DateTime;
        }
        // Receipts are almost always expenses
        _type = 'expense';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Receipt scanned! Review the details below.'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.transaction != null && !widget.isCopy;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final typeColor = _type == 'income'
        ? const Color(0xFF43b89c)
        : _type == 'expense'
            ? const Color(0xFFe53935)
            : const Color(0xFF667eea);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D1117) : const Color(0xFFF0F2F8),
      appBar: AppBar(
        title: Text(
          widget.isCopy ? '📋 Copy Transaction'
              : isEdit   ? 'Edit Transaction'
                         : 'Add Transaction',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        backgroundColor: isDark ? const Color(0xFF1E2530) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        elevation: 0,
        actions: [
          if (!isEdit)
            TextButton.icon(
              onPressed: _openReceiptScanner,
              icon: const Text('🤖', style: TextStyle(fontSize: 14)),
              label: const Text('Scan',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              style: TextButton.styleFrom(foregroundColor: const Color(0xFF667eea)),
            ),
        ],
      ),

      // ── 3 action buttons bottom bar (edit mode only) ─────────────────────
      bottomNavigationBar: isEdit
          ? Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E2530) : Colors.white,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 10,
                      offset: const Offset(0, -4)),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              child: Row(children: [
                // Delete
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _deleteTransaction,
                    icon: const Icon(Icons.delete_outline_rounded,
                        size: 16, color: Colors.red),
                    label: const Text('Delete',
                        style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w600,
                            fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      side: BorderSide(color: Colors.red.withOpacity(0.4)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Copy
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _openAsCopy,
                    icon: const Icon(Icons.copy_all_rounded,
                        size: 16, color: Colors.orange),
                    label: const Text('Copy',
                        style: TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.w600,
                            fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      side: BorderSide(color: Colors.orange.withOpacity(0.4)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Bookmark
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _toggleBookmark,
                    icon: Icon(
                      _isBookmarked
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                      size: 16,
                      color: const Color(0xFF667eea),
                    ),
                    label: Text(
                      _isBookmarked ? 'Saved' : 'Bookmark',
                      style: const TextStyle(
                          color: Color(0xFF667eea),
                          fontWeight: FontWeight.w600,
                          fontSize: 13),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      side: const BorderSide(
                          color: Color(0x66667eea)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      backgroundColor: _isBookmarked
                          ? const Color(0xFF667eea).withOpacity(0.08)
                          : null,
                    ),
                  ),
                ),
              ]),
            )
          : null,

      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
          children: [

            // ── Type selector (compact pill style) ────────────────────────
            Container(
              height: 38,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.06)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                for (final t in [
                  ('income',   'Income',   const Color(0xFF43b89c)),
                  ('expense',  'Expense',  const Color(0xFFe53935)),
                  ('transfer', 'Transfer', const Color(0xFF667eea)),
                ])
                  Expanded(child: GestureDetector(
                    onTap: () => setState(() {
                      _type = t.$1;
                      _selectedCategory = null;
                      _selectedSubcategory = null;
                      _selectedSubSub = null;
                      _fromAccount = null;
                      _toAccount = null;
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: _type == t.$1 ? t.$3 : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(t.$2,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _type == t.$1
                                ? Colors.white
                                : Colors.grey[500],
                          ),
                        ),
                      ),
                    ),
                  )),
              ]),
            ),
            const SizedBox(height: 12),

            // ── Amount (large, prominent) ─────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E2530) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: typeColor.withOpacity(0.25)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(children: [
                Text('₹', style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold,
                    color: typeColor)),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: typeColor),
                    decoration: const InputDecoration(
                      hintText: '0',
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Enter amount';
                      if (double.tryParse(v) == null) return 'Invalid amount';
                      return null;
                    },
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 10),

            // ── Date + Repeat row ─────────────────────────────────────────
            Row(children: [
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (d != null) setState(() => _selectedDate = d);
                  },
                  child: _compactField(
                    icon: Icons.calendar_today_rounded,
                    text: DateFormat('d MMM yyyy').format(_selectedDate),
                    isDark: isDark,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => setState(() => _isRecurring = !_isRecurring),
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: _isRecurring
                        ? const Color(0xFF667eea).withOpacity(0.1)
                        : (isDark
                            ? Colors.white.withOpacity(0.05)
                            : Colors.grey.shade50),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: _isRecurring
                            ? const Color(0xFF667eea).withOpacity(0.4)
                            : (isDark ? Colors.white24 : Colors.grey.shade300)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.repeat_rounded,
                        size: 15,
                        color: _isRecurring
                            ? const Color(0xFF667eea)
                            : Colors.grey[500]),
                    const SizedBox(width: 5),
                    Text('Repeat',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: _isRecurring
                                ? const Color(0xFF667eea)
                                : Colors.grey[500])),
                  ]),
                ),
              ),
            ]),

            // Recurring frequency
            if (_isRecurring) ...[
              const SizedBox(height: 8),
              _compactDropdown<String>(
                value: _recurringFrequency,
                icon: Icons.loop_rounded,
                hint: 'Repeat frequency',
                isDark: isDark,
                items: const ['daily', 'weekly', 'monthly', 'yearly'],
                labels: const ['Daily', 'Weekly', 'Monthly', 'Yearly'],
                onChanged: (v) => setState(() => _recurringFrequency = v!),
              ),
            ],
            const SizedBox(height: 10),

            // ── Type-specific fields ──────────────────────────────────────
            if (_type == 'transfer')
              _buildTransferFields()
            else ...[
              _buildCategoryFields(),
              const SizedBox(height: 8),
              _buildAccountField(),
            ],
            const SizedBox(height: 10),

            // ── Note ─────────────────────────────────────────────────────
            _compactTextField(
              controller: _noteController,
              icon: Icons.notes_rounded,
              hint: 'Add a note (optional)',
              isDark: isDark,
              maxLines: 2,
            ),
            const SizedBox(height: 8),

            // ── Description ───────────────────────────────────────────────
            _compactTextField(
              controller: _descriptionController,
              icon: Icons.description_rounded,
              hint: 'Description (optional)',
              isDark: isDark,
              maxLines: 2,
            ),
            const SizedBox(height: 18),

            // ── Save button ───────────────────────────────────────────────
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveTransaction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: typeColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 18, width: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(
                        isEdit ? 'Update Transaction' : 'Save Transaction',
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ── Compact helper widgets ──────────────────────────────────────────────────
  Widget _compactField({
    required IconData icon,
    required String text,
    required bool isDark,
  }) =>
      Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: isDark ? Colors.white24 : Colors.grey.shade300),
        ),
        child: Row(children: [
          Icon(icon, size: 14, color: Colors.grey[500]),
          const SizedBox(width: 8),
          Text(text,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        ]),
      );

  Widget _compactTextField({
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    required bool isDark,
    int maxLines = 1,
  }) =>
      TextField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
          prefixIcon: Icon(icon, size: 16, color: Colors.grey[400]),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                  color: isDark ? Colors.white24 : Colors.grey.shade300)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                  color: isDark ? Colors.white12 : Colors.grey.shade200)),
          filled: true,
          fillColor:
              isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade50,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          isDense: true,
        ),
      );

  Widget _compactDropdown<T>({
    required T? value,
    required IconData icon,
    required String hint,
    required bool isDark,
    required List<T> items,
    required List<String> labels,
    required ValueChanged<T?> onChanged,
  }) =>
      DropdownButtonFormField<T>(
        value: value,
        isDense: true,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, size: 16, color: Colors.grey[400]),
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                  color: isDark ? Colors.white12 : Colors.grey.shade200)),
          filled: true,
          fillColor:
              isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade50,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        items: List.generate(
          items.length,
          (i) => DropdownMenuItem(
              value: items[i],
              child: Text(labels[i],
                  style: const TextStyle(fontSize: 13))),
        ),
        onChanged: onChanged,
      );

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
      isDense: true,
      decoration: InputDecoration(
        labelText: 'Account *',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade200)),
        prefixIcon: const Icon(Icons.account_balance_wallet_rounded, size: 16),
        hintText: 'Select account',
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        filled: true,
        fillColor: Colors.grey.shade50,
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
      case 'bank':         return Icons.account_balance;
      case 'cash':         return Icons.money;
      case 'credit card':
      case 'card':         return Icons.credit_card;
      case 'wallet':       return Icons.account_balance_wallet;
      case 'loan':         return Icons.trending_down;
      default:             return Icons.account_circle;
    }
  }

  Widget _buildCategoryFields() {
    return Column(
      children: [
        GestureDetector(
          onTap: () => _showCategoryPicker(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(children: [
              Icon(Icons.category_rounded, size: 16, color: Colors.grey[400]),
              const SizedBox(width: 10),
              Expanded(child: Text(
                _selectedCategory != null
                    ? (_selectedSubcategory != null
                        ? (_selectedSubSub != null
                            ? '$_selectedCategory · $_selectedSubcategory · $_selectedSubSub'
                            : '$_selectedCategory · $_selectedSubcategory')
                        : _selectedCategory!)
                    : 'Select category *',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: _selectedCategory != null ? null : Colors.grey,
                ),
              )),
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 12, color: Colors.grey[400]),
            ]),
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
        selectedSubSub: _selectedSubSub,
        customCatSvc: _customCatSvc,
        onSelected: (cat, sub, subSub) {
          setState(() {
            _selectedCategory = cat;
            _selectedSubcategory = sub;
            _selectedSubSub = subSub;
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

      final transaction = TransactionModel(
        userId: '',
        id: '',
        type: _type,
        amount: double.parse(_amountController.text),
        category: _selectedCategory ?? '',
        subcategory: _selectedSubSub != null
            ? '$_selectedSubcategory · $_selectedSubSub'
            : _selectedSubcategory,
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
      case 'Food & Dining':     return Icons.restaurant;
      case 'Transportation':    return Icons.directions_car;
      case 'Shopping':          return Icons.shopping_bag;
      case 'Entertainment':     return Icons.movie;
      case 'Bills & Utilities': return Icons.receipt;
      case 'Healthcare':        return Icons.local_hospital;
      case 'Education':         return Icons.school;
      case 'Personal Care':     return Icons.spa;
      case 'Travel':            return Icons.flight;
      case 'Salary':            return Icons.account_balance_wallet;
      case 'Business':          return Icons.business;
      case 'Investments':       return Icons.trending_up;
      case 'Gifts':             return Icons.card_giftcard;
      default:                  return Icons.category;
    }
  }
}

// ── Category Picker Bottom Sheet (Accordion, 3-level) ─────────────────────────
class _CategoryPickerSheet extends StatefulWidget {
  final String type;
  final String? selectedCategory;
  final String? selectedSubcategory;
  final String? selectedSubSub;
  final CustomCategoryService customCatSvc;
  final void Function(String cat, String? sub, String? subSub) onSelected;

  const _CategoryPickerSheet({
    required this.type,
    required this.selectedCategory,
    required this.selectedSubcategory,
    this.selectedSubSub,
    required this.customCatSvc,
    required this.onSelected,
  });

  @override
  State<_CategoryPickerSheet> createState() => _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends State<_CategoryPickerSheet> {
  List<CustomCategory> _cats = [];
  bool _loading = true;
  String? _expandedCat;   // which main cat is open
  String? _expandedSub;   // which sub is showing sub-subs

  @override
  void initState() {
    super.initState();
    _expandedCat = widget.selectedCategory;
    _load();
  }

  Future<void> _load() async {
    final cats = await widget.customCatSvc.getCategoriesOnce(type: widget.type);
    if (mounted) setState(() { _cats = cats; _loading = false; });
  }

  Color get _accent =>
      widget.type == 'expense' ? const Color(0xFFe53935) : const Color(0xFF43b89c);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2530) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(children: [
          // Handle
          Center(child: Container(
            margin: const EdgeInsets.only(top: 10),
            width: 40, height: 4,
            decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2)))),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(children: [
              Text('Select Category',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              const Spacer(),
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(
                      builder: (_) => const CustomCategoriesScreen()));
                },
                icon: const Icon(Icons.tune_rounded, size: 14),
                label: const Text('Manage', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(foregroundColor: _accent),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ]),
          ),
          const Divider(height: 1),

          // List
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(
                    color: Color(0xFF667eea)))
                : _cats.isEmpty
                    ? Center(child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('📂', style: TextStyle(fontSize: 48)),
                          const SizedBox(height: 12),
                          const Text('No categories found'),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: _load,
                            child: const Text('Retry'),
                          ),
                        ]))
                    : ListView.builder(
                        controller: scrollCtrl,
                        padding: const EdgeInsets.only(bottom: 20),
                        itemCount: _cats.length,
                        itemBuilder: (_, i) =>
                            _AccordionCatRow(
                              cat:           _cats[i],
                              expandedCat:   _expandedCat,
                              expandedSub:   _expandedSub,
                              selectedCat:   widget.selectedCategory,
                              selectedSub:   widget.selectedSubcategory,
                              selectedSubSub:widget.selectedSubSub,
                              accent:        _accent,
                              isDark:        isDark,
                              onExpandCat:   (name) =>
                                  setState(() => _expandedCat =
                                      _expandedCat == name ? null : name),
                              onExpandSub:   (name) =>
                                  setState(() => _expandedSub =
                                      _expandedSub == name ? null : name),
                              onSelect:      (cat, sub, subSub) {
                                widget.onSelected(cat, sub, subSub);
                                Navigator.pop(context);
                              },
                            ),
                      ),
          ),
        ]),
      ),
    );
  }
}

// ── Single accordion row ──────────────────────────────────────────────────────
class _AccordionCatRow extends StatelessWidget {
  final CustomCategory cat;
  final String? expandedCat;
  final String? expandedSub;
  final String? selectedCat;
  final String? selectedSub;
  final String? selectedSubSub;
  final Color accent;
  final bool isDark;
  final void Function(String) onExpandCat;
  final void Function(String) onExpandSub;
  final void Function(String cat, String? sub, String? subSub) onSelect;

  const _AccordionCatRow({
    required this.cat,
    required this.expandedCat,
    required this.expandedSub,
    required this.selectedCat,
    required this.selectedSub,
    required this.selectedSubSub,
    required this.accent,
    required this.isDark,
    required this.onExpandCat,
    required this.onExpandSub,
    required this.onSelect,
  });

  bool get isOpen => expandedCat == cat.name;
  bool get isSelected => selectedCat == cat.name;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // ── Main category row ───────────────────────────────────────────────
      InkWell(
        onTap: () {
          if (cat.subcategories.isEmpty) {
            onSelect(cat.name, null, null);
          } else {
            onExpandCat(cat.name);
          }
        },
        child: Container(
          color: isSelected && isOpen
              ? cat.color.withOpacity(0.06)
              : isOpen
                  ? (isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade50)
                  : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            // Icon
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: cat.color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(child: Text(cat.emoji,
                  style: const TextStyle(fontSize: 20))),
            ),
            const SizedBox(width: 12),
            // Name
            Expanded(child: Text(cat.name,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? cat.color : null,
                ))),
            // Selected indicator
            if (isSelected && selectedSub == null)
              Icon(Icons.check_circle_rounded,
                  color: cat.color, size: 18),
            const SizedBox(width: 4),
            // Expand arrow
            if (cat.subcategories.isNotEmpty)
              Icon(isOpen
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
                  color: Colors.grey[400], size: 20),
          ]),
        ),
      ),

      // ── Subcategories (accordion) ───────────────────────────────────────
      if (isOpen && cat.subcategories.isNotEmpty) ...[
        Divider(height: 1,
            color: isDark ? Colors.white12 : Colors.grey.shade100),
        ...cat.subcategories.map((sub) => _SubRow(
              sub:          sub,
              cat:          cat,
              expandedSub:  expandedSub,
              selectedCat:  selectedCat,
              selectedSub:  selectedSub,
              selectedSubSub: selectedSubSub,
              isDark:       isDark,
              onExpandSub:  onExpandSub,
              onSelect:     onSelect,
            )),
        Divider(height: 1,
            color: isDark ? Colors.white12 : Colors.grey.shade100),
      ],

      Divider(height: 1,
          color: isDark ? Colors.white12 : Colors.grey.shade100),
    ]);
  }
}

class _SubRow extends StatelessWidget {
  final CustomSubcategory sub;
  final CustomCategory cat;
  final String? expandedSub;
  final String? selectedCat;
  final String? selectedSub;
  final String? selectedSubSub;
  final bool isDark;
  final void Function(String) onExpandSub;
  final void Function(String cat, String? sub, String? subSub) onSelect;

  const _SubRow({
    required this.sub,
    required this.cat,
    required this.expandedSub,
    required this.selectedCat,
    required this.selectedSub,
    required this.selectedSubSub,
    required this.isDark,
    required this.onExpandSub,
    required this.onSelect,
  });

  bool get isSubOpen => expandedSub == sub.name;
  bool get isSubSel  => selectedCat == cat.name && selectedSub == sub.name;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Sub row
      InkWell(
        onTap: () {
          if (sub.subSubs.isEmpty) {
            onSelect(cat.name, sub.name, null);
          } else {
            onExpandSub(sub.name);
          }
        },
        child: Container(
          color: isSubSel
              ? cat.color.withOpacity(0.06)
              : Colors.transparent,
          padding: const EdgeInsets.fromLTRB(52, 10, 16, 10),
          child: Row(children: [
            Container(
              width: 6, height: 6, margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                  color: isSubSel ? cat.color : Colors.grey[400],
                  shape: BoxShape.circle),
            ),
            Expanded(child: Text(sub.name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSubSel ? FontWeight.w600 : FontWeight.normal,
                  color: isSubSel ? cat.color : null,
                ))),
            if (isSubSel && selectedSubSub == null)
              Icon(Icons.check_rounded, color: cat.color, size: 16),
            if (sub.subSubs.isNotEmpty) ...[
              const SizedBox(width: 4),
              Icon(isSubOpen
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
                  color: Colors.grey[400], size: 16),
            ],
          ]),
        ),
      ),
      // Sub-subcategories
      if (isSubOpen && sub.subSubs.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(64, 4, 16, 8),
          child: Wrap(spacing: 6, runSpacing: 6,
            children: sub.subSubs.map((ss) {
              final isSel = selectedCat == cat.name &&
                  selectedSub == sub.name &&
                  selectedSubSub == ss;
              return GestureDetector(
                onTap: () => onSelect(cat.name, sub.name, ss),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSel ? cat.color : cat.color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: cat.color.withOpacity(0.3)),
                  ),
                  child: Text(ss, style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isSel ? Colors.white : cat.color)),
                ),
              );
            }).toList()),
        ),
    ]);
  }
}