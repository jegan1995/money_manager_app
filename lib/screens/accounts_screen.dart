import 'package:flutter/material.dart';
import '../models/account_model.dart';
import '../services/account_service.dart';
import 'add_account_screen.dart';
import 'account_detail_screen.dart';

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  final AccountService _accountService = AccountService();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF121212) : const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text(
          'Accounts',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<List<AccountModel>>(
        stream: _accountService.getAccounts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyState(isDark);
          }

          final accounts = snapshot.data!;

          double totalAssets = 0;
          double totalDebt = 0;

          for (var account in accounts) {
            if (account.type == 'credit_card' || account.type == 'loan') {
              totalDebt += account.balance.abs();
            } else {
              if (account.balance > 0) totalAssets += account.balance;
            }
          }

          final netWorth = totalAssets - totalDebt;

          return Column(
            children: [
              _buildSummaryHeader(totalAssets, totalDebt, netWorth, isDark),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
                  itemCount: accounts.length,
                  itemBuilder: (context, index) =>
                      _buildAccountCard(accounts[index], isDark),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AddAccountScreen()),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildSummaryHeader(
      double assets, double debt, double net, bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1565C0), const Color(0xFF283593)]
              : [const Color(0xFF1976D2), const Color(0xFF42A5F5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _summaryItem('Assets', assets, Colors.greenAccent, isDark),
          _vDivider(),
          _summaryItem('Debt', debt, Colors.redAccent[100]!, isDark),
          _vDivider(),
          _summaryItem(
            'Net Worth',
            net,
            net >= 0 ? Colors.greenAccent : Colors.redAccent[100]!,
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, double amount, Color color, bool isDark) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.75),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '₹${_fmt(amount)}',
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _vDivider() => Container(
        width: 1,
        height: 30,
        color: Colors.white.withOpacity(0.25),
      );

  Widget _buildAccountCard(AccountModel account, bool isDark) {
    final color = _accountColor(account.type);
    final isNegative = account.balance < 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        // ✅ FIX: Opens AccountDetailScreen (was incorrectly opening AddAccountScreen)
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AccountDetailScreen(account: account),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              // Account icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_accountIcon(account.type), color: color, size: 20),
              ),
              const SizedBox(width: 12),
              // Name + type
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: isDark ? Colors.white : Colors.grey[900],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _accountTypeName(account.type),
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.grey[500] : Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
              // Balance + edit
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${isNegative ? '-' : ''}₹${_fmt(account.balance.abs())}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isNegative ? Colors.red : Colors.green,
                    ),
                  ),
                  const SizedBox(height: 2),
                  if (isNegative)
                    Text(
                      'Overdrawn',
                      style: TextStyle(fontSize: 10, color: Colors.red[400]),
                    ),
                ],
              ),
              const SizedBox(width: 8),
              // Edit icon
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddAccountScreen(account: account),
                  ),
                ),
                child: Icon(
                  Icons.edit_outlined,
                  size: 16,
                  color: isDark ? Colors.grey[600] : Colors.grey[400],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.account_balance_wallet_outlined,
              size: 64, color: isDark ? Colors.grey[700] : Colors.grey[300]),
          const SizedBox(height: 16),
          Text('No accounts yet',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey[500] : Colors.grey[600])),
          const SizedBox(height: 6),
          Text('Tap + to add your first account',
              style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.grey[600] : Colors.grey[400])),
        ],
      ),
    );
  }

  Color _accountColor(String type) {
    switch (type) {
      case 'cash':
        return Colors.green;
      case 'bank':
        return Colors.blue;
      case 'credit_card':
        return Colors.orange;
      case 'loan':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _accountIcon(String type) {
    switch (type) {
      case 'cash':
        return Icons.payments;
      case 'bank':
        return Icons.account_balance;
      case 'credit_card':
        return Icons.credit_card;
      case 'loan':
        return Icons.money_off;
      default:
        return Icons.account_balance_wallet;
    }
  }

  String _accountTypeName(String type) {
    switch (type) {
      case 'cash':
        return 'Cash';
      case 'bank':
        return 'Bank Account';
      case 'credit_card':
        return 'Credit Card';
      case 'loan':
        return 'Loan';
      default:
        return type;
    }
  }

  String _fmt(double amount) {
    if (amount >= 10000000) return '${(amount / 10000000).toStringAsFixed(1)}Cr';
    if (amount >= 100000) return '${(amount / 100000).toStringAsFixed(1)}L';
    if (amount >= 1000) {
      final formatter = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
      return amount
          .toInt()
          .toString()
          .replaceAllMapped(formatter, (m) => '${m[1]},');
    }
    return amount.toStringAsFixed(0);
  }
}