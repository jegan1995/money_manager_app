import 'package:flutter/material.dart';
import '../models/account.dart';
import '../services/account_service.dart';

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  final AccountService _accountService = AccountService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Accounts'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: StreamBuilder<List<Account>>(
        stream: _accountService.getAccounts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.account_balance, size: 80, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('No accounts added', style: TextStyle(fontSize: 18, color: Colors.grey)),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () => _showAddAccountDialog(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Account'),
                  ),
                ],
              ),
            );
          }

          final totalBalance = snapshot.data!.fold(0.0, (sum, acc) => sum + acc.balance);

          return Column(
            children: [
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.teal.shade400, Colors.teal.shade700],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Total Balance',
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '₹${totalBalance.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.data!.length} account${snapshot.data!.length != 1 ? 's' : ''}',
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) {
                    final account = snapshot.data![index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _getAccountColor(account.type).withOpacity(0.2),
                          child: Icon(
                            _getAccountIcon(account.type),
                            color: _getAccountColor(account.type),
                          ),
                        ),
                        title: Text(
                          account.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(_getAccountTypeLabel(account.type)),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '₹${account.balance.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                              onPressed: () => _accountService.deleteAccount(account.id),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddAccountDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  IconData _getAccountIcon(String type) {
    switch (type) {
      case 'bank':
        return Icons.account_balance;
      case 'cash':
        return Icons.money;
      case 'card':
        return Icons.credit_card;
      case 'wallet':
        return Icons.account_balance_wallet;
      default:
        return Icons.account_balance;
    }
  }

  Color _getAccountColor(String type) {
    switch (type) {
      case 'bank':
        return Colors.blue;
      case 'cash':
        return Colors.green;
      case 'card':
        return Colors.purple;
      case 'wallet':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _getAccountTypeLabel(String type) {
    return type[0].toUpperCase() + type.substring(1);
  }

  void _showAddAccountDialog(BuildContext context) {
    final nameController = TextEditingController();
    final balanceController = TextEditingController();
    String selectedType = 'bank';
    final types = ['bank', 'cash', 'card', 'wallet'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Account'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Account Name'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedType,
                decoration: const InputDecoration(labelText: 'Account Type'),
                items: types.map((t) => DropdownMenuItem(value: t, child: Text(_getAccountTypeLabel(t)))).toList(),
                onChanged: (value) => setState(() => selectedType = value!),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: balanceController,
                decoration: const InputDecoration(labelText: 'Initial Balance'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final balance = double.tryParse(balanceController.text) ?? 0;
                if (nameController.text.isNotEmpty) {
                  final account = Account(
                    id: '',
                    name: nameController.text,
                    type: selectedType,
                    balance: balance,
                    createdDate: DateTime.now(),
                  );
                  await _accountService.addAccount(account);
                  Navigator.pop(context);
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
}
