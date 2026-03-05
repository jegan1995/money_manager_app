import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/account_model.dart';
import '../services/account_service.dart';

class AddAccountScreen extends StatefulWidget {
  final AccountModel? account;
  const AddAccountScreen({super.key, this.account});
  @override
  State<AddAccountScreen> createState() => _AddAccountScreenState();
}

class _AddAccountScreenState extends State<AddAccountScreen> {
  final _formKey        = GlobalKey<FormState>();
  final _namCtrl        = TextEditingController();
  final _balCtrl        = TextEditingController();
  final _noteCtrl       = TextEditingController();
  final _accountService = AccountService();
  String _type    = 'cash';
  bool _loading   = false;

  // Account type definitions
  static const _types = [
    {'value': 'cash',        'label': 'Cash',         'icon': Icons.money,                   'color': 0xFF2E7D32},
    {'value': 'bank',        'label': 'Bank Account',  'icon': Icons.account_balance,          'color': 0xFF1565C0},
    {'value': 'card',        'label': 'Debit Card',    'icon': Icons.credit_card,              'color': 0xFF00838F},
    {'value': 'credit_card', 'label': 'Credit Card',   'icon': Icons.credit_card,              'color': 0xFF6A1B9A},
    {'value': 'wallet',      'label': 'Digital Wallet','icon': Icons.account_balance_wallet,   'color': 0xFFF57F17},
    {'value': 'loan',        'label': 'Loan',          'icon': Icons.receipt_long,             'color': 0xFFC62828},
    {'value': 'other',       'label': 'Other',         'icon': Icons.savings,                  'color': 0xFF546E7A},
  ];

  Map<String, dynamic> get _selectedType =>
      _types.firstWhere((t) => t['value'] == _type,
          orElse: () => _types[0]);

  @override
  void initState() {
    super.initState();
    if (widget.account != null) {
      _namCtrl.text = widget.account!.name;
      _type         = widget.account!.type;
      // Format balance cleanly — avoid floating point like 201.5799999
      final rawBal = widget.account!.balance.abs();
      if (rawBal == rawBal.truncateToDouble()) {
        _balCtrl.text = rawBal.toStringAsFixed(0);         // e.g. "500"
      } else {
        _balCtrl.text = double.parse(
            rawBal.toStringAsFixed(2)).toString();          // e.g. "201.58"
      }
      _noteCtrl.text = widget.account!.note ?? '';
    }
  }

  @override
  void dispose() {
    _namCtrl.dispose(); _balCtrl.dispose(); _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.account != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg     = isDark ? const Color(0xFF0D1117) : const Color(0xFFF0F4FF);
    final card   = isDark ? const Color(0xFF1E2530) : Colors.white;
    final accColor = Color(_selectedType['color'] as int);

    return Scaffold(
      backgroundColor: bg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: const Color(0xFF667eea),
            foregroundColor: Colors.white,
            title: Text(isEdit ? 'Edit Account' : 'Add Account',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            actions: [
              if (isEdit)
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _deleteAccount,
                ),
            ],
          ),
          SliverToBoxAdapter(
            child: Form(
              key: _formKey,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Account type header preview ────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            accColor,
                            accColor.withOpacity(0.7),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(children: [
                        Container(
                          width: 56, height: 56,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            _selectedType['icon'] as IconData,
                            color: Colors.white, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _namCtrl.text.isEmpty
                                  ? 'Account Name' : _namCtrl.text,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _selectedType['label'] as String,
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 13),
                            ),
                          ],
                        ),
                      ]),
                    ),

                    const SizedBox(height: 20),

                    // ── Account type picker ───────────────────────────
                    _sectionLabel('Account Type', isDark),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                          color: card,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8)]),
                      child: Column(
                        children: _types.asMap().entries.map((e) {
                          final t    = e.value;
                          final isLast = e.key == _types.length - 1;
                          final sel  = _type == t['value'];
                          final tc   = Color(t['color'] as int);
                          return Column(children: [
                            InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() => _type = t['value'] as String);
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                child: Row(children: [
                                  Container(
                                    width: 36, height: 36,
                                    decoration: BoxDecoration(
                                      color: tc.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(t['icon'] as IconData,
                                        color: tc, size: 18),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(child: Text(
                                    t['label'] as String,
                                    style: TextStyle(
                                        fontWeight: sel
                                            ? FontWeight.bold : FontWeight.normal,
                                        fontSize: 14),
                                  )),
                                  if (sel)
                                    Icon(Icons.check_circle,
                                        color: const Color(0xFF667eea),
                                        size: 20),
                                ]),
                              ),
                            ),
                            if (!isLast)
                              Divider(height: 1, indent: 64,
                                  color: isDark
                                      ? Colors.white.withOpacity(0.06)
                                      : Colors.grey.shade100),
                          ]);
                        }).toList(),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Account details ───────────────────────────────
                    _sectionLabel('Account Details', isDark),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                          color: card,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8)]),
                      child: Column(children: [
                        _field(
                          controller: _namCtrl,
                          label: 'Account Name',
                          hint: 'e.g. HDFC Savings, My Wallet',
                          icon: Icons.label_outline,
                          onChanged: (_) => setState(() {}),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Enter account name' : null,
                        ),
                        Divider(height: 1, indent: 16,
                            color: isDark
                                ? Colors.white.withOpacity(0.06)
                                : Colors.grey.shade100),
                        _field(
                          controller: _balCtrl,
                          label: (_type == 'credit_card' || _type == 'loan')
                              ? 'Outstanding Balance (₹)'
                              : 'Current Balance (₹)',
                          hint: '0.00',
                          icon: Icons.currency_rupee,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9.]')),
                          ],
                          validator: (v) {
                            if (v == null || v.trim().isEmpty)
                              return 'Enter balance';
                            if (double.tryParse(v) == null)
                              return 'Enter a valid number';
                            return null;
                          },
                        ),
                        Divider(height: 1, indent: 16,
                            color: isDark
                                ? Colors.white.withOpacity(0.06)
                                : Colors.grey.shade100),
                        _field(
                          controller: _noteCtrl,
                          label: 'Note (optional)',
                          hint: 'e.g. Primary account, Emergency fund',
                          icon: Icons.notes_outlined,
                          maxLines: 2,
                        ),
                      ]),
                    ),

                    if (_type == 'credit_card' || _type == 'loan') ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: Colors.orange.withOpacity(0.3)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.info_outline,
                              color: Colors.orange, size: 16),
                          const SizedBox(width: 8),
                          Expanded(child: Text(
                            'Enter the outstanding amount you owe. '
                            'This will be shown as debt in your net worth.',
                            style: TextStyle(
                                fontSize: 12, color: Colors.orange[700]),
                          )),
                        ]),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // ── Save button ───────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF667eea),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: _loading
                            ? const SizedBox(width: 20, height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : Text(isEdit ? 'Update Account' : 'Save Account',
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text, bool isDark) => Text(
        text.toUpperCase(),
        style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.grey[500],
            letterSpacing: 1.1),
      );

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) =>
      TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        inputFormatters: inputFormatters,
        onChanged: onChanged,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, size: 18, color: Colors.grey[400]),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          focusedBorder: InputBorder.none,
          enabledBorder: InputBorder.none,
        ),
      );

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.mediumImpact();
    setState(() => _loading = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('Not logged in');

      double balance = double.parse(_balCtrl.text.trim());
      // Credit/loan stored as negative
      if (_type == 'credit_card' || _type == 'loan') {
        balance = -balance.abs();
      }

      final acc = AccountModel(
        id:      widget.account?.id,
        userId:  uid,
        name:    _namCtrl.text.trim(),
        type:    _type,
        balance: balance,
        note:    _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      );

      if (widget.account != null) {
        await _accountService.updateAccount(widget.account!.id!, acc);
      } else {
        await _accountService.addAccount(acc);
      }

      if (mounted) {
        Navigator.pop(context);
        _snack(widget.account != null
            ? 'Account updated successfully'
            : 'Account added successfully', true);
      }
    } catch (e) {
      if (mounted) _snack('Error: $e', false);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteAccount() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Account'),
        content: Text(
            'Delete "${widget.account!.name}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _accountService.deleteAccount(widget.account!.id!);
      if (mounted) {
        Navigator.pop(context);
        _snack('Account deleted', true);
      }
    } catch (e) {
      if (mounted) _snack('Error: $e', false);
    }
  }

  void _snack(String msg, bool ok) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: ok ? const Color(0xFF2E7D32) : Colors.red,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
    ));
  }
}