import 'package:flutter/material.dart';
import '../models/account_model.dart';
import '../services/account_service.dart';

class AddAccountScreen extends StatefulWidget {
  final AccountModel? account;

  const AddAccountScreen({super.key, this.account});

  @override
  State<AddAccountScreen> createState() => _AddAccountScreenState();
}

class _AddAccountScreenState extends State<AddAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final AccountService _accountService = AccountService();

  final TextEditingController _nameController = TextEditingController();
  String _type = 'cash';
  final TextEditingController _balanceController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  bool _isLoading = false;

  final List<Map<String, dynamic>> _accountTypes = [
    {'value': 'cash', 'label': 'Cash', 'icon': Icons.money},
    {'value': 'bank', 'label': 'Bank Account', 'icon': Icons.account_balance},
    {'value': 'credit_card', 'label': 'Credit Card', 'icon': Icons.credit_card},
    {'value': 'loan', 'label': 'Loan', 'icon': Icons.receipt_long},
    {'value': 'other', 'label': 'Other', 'icon': Icons.wallet},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.account != null) {
      _nameController.text = widget.account!.name;
      _type = widget.account!.type;
      _balanceController.text = widget.account!.balance.toString();
      _noteController.text = widget.account!.note ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.account != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Account' : 'Add Account'),
        actions: isEdit
            ? [
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: _deleteAccount,
                ),
              ]
            : null,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Account Name
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Account Name *',
                border: OutlineInputBorder(),
                hintText: 'e.g., My Wallet, HDFC Bank',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter account name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Account Type
            DropdownButtonFormField<String>(
              value: _type,
              decoration: const InputDecoration(
                labelText: 'Account Type *',
                border: OutlineInputBorder(),
              ),
              items: _accountTypes
                  .map((type) => DropdownMenuItem(
                        value: type['value'],
                        child: Row(
                          children: [
                            Icon(type['icon'], size: 20),
                            const SizedBox(width: 12),
                            Text(type['label']),
                          ],
                        ),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _type = value!;
                });
              },
            ),
            const SizedBox(height: 16),

            // Balance
            TextFormField(
              controller: _balanceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: _type == 'credit_card' || _type == 'loan'
                    ? 'Outstanding Amount *'
                    : 'Current Balance *',
                prefixText: '₹ ',
                border: const OutlineInputBorder(),
                helperText: _type == 'credit_card' || _type == 'loan'
                    ? 'Enter positive amount for debt'
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

            // Note
            TextFormField(
              controller: _noteController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Note (Optional)',
                border: OutlineInputBorder(),
                hintText: 'Add account details...',
              ),
            ),
            const SizedBox(height: 24),

            // Save Button
            ElevatedButton(
              onPressed: _isLoading ? null : _saveAccount,
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

  Future<void> _saveAccount() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final account = AccountModel(
        id: widget.account?.id,
        name: _nameController.text,
        type: _type,
        balance: double.parse(_balanceController.text),
        note: _noteController.text.isEmpty ? null : _noteController.text,
      );

      if (widget.account != null) {
        await _accountService.updateAccount(widget.account!.id!, account);
      } else {
        await _accountService.addAccount(account);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.account != null
                ? 'Account updated'
                : 'Account added'),
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

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text('Are you sure you want to delete this account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await _accountService.deleteAccount(widget.account!.id!);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Account deleted'),
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
      }
    }
  }
}