import 'package:flutter/material.dart';
import '../models/bill_reminder_model.dart';
import '../models/account_model.dart';
import '../services/bill_reminder_service.dart';
import '../services/account_service.dart';

class AddBillReminderScreen extends StatefulWidget {
  final BillReminderModel? bill; // null = add, non-null = edit

  const AddBillReminderScreen({super.key, this.bill});

  @override
  State<AddBillReminderScreen> createState() => _AddBillReminderScreenState();
}

class _AddBillReminderScreenState extends State<AddBillReminderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = BillReminderService();
  final _accountService = AccountService();

  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  int _dueDayOfMonth = 1;
  String _category = 'Bills & Utilities';
  String _repeatType = 'monthly';
  String? _selectedAccountId;
  bool _isAutoPay = false;
  bool _saving = false;

  List<AccountModel> _accounts = [];

  static const _categories = [
    'Bills & Utilities',
    'Rent',
    'Insurance',
    'Loan / EMI',
    'Subscription',
    'Education',
    'Healthcare',
    'Tax',
    'Other',
  ];

  static const _categoryIcons = {
    'Bills & Utilities': Icons.receipt_long,
    'Rent': Icons.home,
    'Insurance': Icons.shield,
    'Loan / EMI': Icons.account_balance,
    'Subscription': Icons.subscriptions,
    'Education': Icons.school,
    'Healthcare': Icons.local_hospital,
    'Tax': Icons.percent,
    'Other': Icons.category,
  };

  static const _categoryColors = {
    'Bills & Utilities': Color(0xFF1565C0),
    'Rent': Color(0xFF6A1B9A),
    'Insurance': Color(0xFF2E7D32),
    'Loan / EMI': Color(0xFFC62828),
    'Subscription': Color(0xFFE65100),
    'Education': Color(0xFF00838F),
    'Healthcare': Color(0xFFAD1457),
    'Tax': Color(0xFF4E342E),
    'Other': Color(0xFF37474F),
  };

  @override
  void initState() {
    super.initState();
    _accountService.getAccounts().listen((list) {
      if (mounted) setState(() => _accounts = list);
    });

    // Pre-fill if editing
    final b = widget.bill;
    if (b != null) {
      _nameController.text = b.name;
      _amountController.text = b.amount.toStringAsFixed(0);
      _noteController.text = b.note ?? '';
      _dueDayOfMonth = b.dueDayOfMonth;
      _category = b.category;
      _repeatType = b.repeatType;
      _selectedAccountId = b.accountId;
      _isAutoPay = b.isAutoPay;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final bill = BillReminderModel(
        id: widget.bill?.id ?? '',
        userId: '',
        name: _nameController.text.trim(),
        amount: double.parse(_amountController.text),
        dueDayOfMonth: _dueDayOfMonth,
        category: _category,
        accountId: _selectedAccountId,
        isAutoPay: _isAutoPay,
        repeatType: _repeatType,
        note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
        createdAt: widget.bill?.createdAt ?? DateTime.now(),
      );

      if (widget.bill != null) {
        await _service.updateBillReminder(widget.bill!.id, bill);
      } else {
        await _service.addBillReminder(bill);
      }

      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.pop(context);
        messenger.showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(widget.bill != null ? 'Bill updated!' : 'Bill reminder added!',
                style: const TextStyle(color: Colors.white)),
          ]),
          backgroundColor: const Color(0xFF2E7D32),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEdit = widget.bill != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Bill Reminder' : 'Add Bill Reminder'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Category chips
            Text('Category',
                style: theme.textTheme.labelLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categories.map((cat) {
                final selected = _category == cat;
                final color = _categoryColors[cat] ?? Colors.grey;
                return GestureDetector(
                  onTap: () => setState(() => _category = cat),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected ? color : color.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: selected ? color : color.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_categoryIcons[cat] ?? Icons.category,
                            size: 14,
                            color: selected ? Colors.white : color),
                        const SizedBox(width: 4),
                        Text(cat,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: selected ? Colors.white : color,
                            )),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Bill name
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Bill Name *',
                hintText: 'e.g. Electricity, Netflix, SBI Home Loan',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                prefixIcon: Icon(
                    _categoryIcons[_category] ?? Icons.receipt_long,
                    color: _categoryColors[_category]),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Enter bill name' : null,
            ),
            const SizedBox(height: 14),

            // Amount
            TextFormField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Amount *',
                prefixText: '₹ ',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.currency_rupee),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Enter amount';
                if (double.tryParse(v) == null) return 'Invalid amount';
                return null;
              },
            ),
            const SizedBox(height: 14),

            // Due day
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[400]!),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 18,
                          color: Colors.grey),
                      const SizedBox(width: 8),
                      Text('Due Day of Month: ',
                          style: TextStyle(color: Colors.grey[700])),
                      Text(
                        _dueDayOfMonth.toString(),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _dueDayOfMonth.toDouble(),
                    min: 1,
                    max: 31,
                    divisions: 30,
                    label: _dueDayOfMonth.toString(),
                    onChanged: (v) =>
                        setState(() => _dueDayOfMonth = v.round()),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('1st', style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                      Text('15th', style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                      Text('31st', style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Repeat type
            DropdownButtonFormField<String>(
              value: _repeatType,
              decoration: InputDecoration(
                labelText: 'Repeat',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.repeat),
              ),
              items: const [
                DropdownMenuItem(value: 'monthly', child: Text('Every Month')),
                DropdownMenuItem(value: 'yearly', child: Text('Every Year')),
                DropdownMenuItem(
                    value: 'one_time', child: Text('One Time Only')),
              ],
              onChanged: (v) => setState(() => _repeatType = v!),
            ),
            const SizedBox(height: 14),

            // Account
            DropdownButtonFormField<String>(
              value: _selectedAccountId,
              decoration: InputDecoration(
                labelText: 'Pay from Account (Optional)',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.account_balance_wallet),
              ),
              items: [
                const DropdownMenuItem(
                    value: null, child: Text('No account selected')),
                ..._accounts.map((a) => DropdownMenuItem(
                    value: a.id,
                    child: Text('${a.name} (₹${a.balance.toStringAsFixed(0)})'))),
              ],
              onChanged: (v) => setState(() => _selectedAccountId = v),
            ),
            const SizedBox(height: 14),

            // Auto pay toggle
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.auto_mode,
                      color: _isAutoPay ? Colors.green : Colors.grey),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Auto Pay',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        Text('Mark as auto-deducted',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey[600])),
                      ],
                    ),
                  ),
                  Switch(
                    value: _isAutoPay,
                    onChanged: (v) => setState(() => _isAutoPay = v),
                    activeColor: Colors.green,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Note
            TextFormField(
              controller: _noteController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Note (Optional)',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.notes),
              ),
            ),
            const SizedBox(height: 24),

            // Save button
            ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(isEdit ? 'UPDATE BILL' : 'ADD BILL REMINDER',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}