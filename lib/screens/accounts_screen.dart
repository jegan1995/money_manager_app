import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/account_model.dart';
import '../services/account_service.dart';
import 'add_account_screen.dart';

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
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _accountService.getAccounts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.account_balance_wallet_outlined,
                      size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text('No accounts yet',
                      style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                  const SizedBox(height: 8),
                  Text('Tap + to add your first account',
                      style: TextStyle(color: Colors.grey[500], fontSize: 14)),
                ],
              ),
            );
          }

          final accounts = snapshot.data!.docs
              .map((doc) => AccountModel.fromMap(
                    doc.data() as Map<String, dynamic>,
                    doc.id,
                  ))
              .toList();

          // Calculate totals
          double totalCash = 0;
          double totalBank = 0;
          double totalDebt = 0;
          double totalOther = 0;

          for (var account in accounts) {
            switch (account.type) {
              case 'cash':
                totalCash += account.balance;
                break;
              case 'bank':
                totalBank += account.balance;
                break;
              case 'credit_card':
              case 'loan':
                totalDebt += account.balance;
                break;
              default:
                totalOther += account.balance;
            }
          }

          final totalAssets = totalCash + totalBank + totalOther;
          final netWorth = totalAssets - totalDebt;

          // Group accounts by type
          final grouped = <String, List<AccountModel>>{};
          for (var account in accounts) {
            grouped.putIfAbsent(account.type, () => []).add(account);
          }

          return Column(
            children: [
              // Summary Cards
              _buildSummarySection(totalAssets, totalDebt, netWorth),

              const Divider(height: 1),

              // Accounts List
              Expanded(
                child: ListView(
                  children: [
                    if (grouped.containsKey('cash'))
                      _buildAccountGroup('Cash', grouped['cash']!),
                    if (grouped.containsKey('bank'))
                      _buildAccountGroup('Bank Accounts', grouped['bank']!),
                    if (grouped.containsKey('credit_card'))
                      _buildAccountGroup('Credit Cards', grouped['credit_card']!),
                    if (grouped.containsKey('loan'))
                      _buildAccountGroup('Loans', grouped['loan']!),
                    if (grouped.containsKey('other'))
                      _buildAccountGroup('Others', grouped['other']!),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddAccountScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSummarySection(double assets, double debt, double netWorth) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        children: [
          // Net Worth
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue[700]!, Colors.blue[500]!],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                const Text(
                  'Net Worth',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '₹${netWorth.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Assets and Debt
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'Total Assets',
                  assets,
                  Icons.account_balance_wallet,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  'Total Debt',
                  debt,
                  Icons.credit_card,
                  Colors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
      String label, double amount, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '₹${amount.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountGroup(String title, List<AccountModel> accounts) {
    final total = accounts.fold<double>(0, (sum, acc) => sum + acc.balance);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Colors.grey[100],
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              Text(
                '₹${total.toStringAsFixed(0)}',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: total >= 0 ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
        ),
        ...accounts.map((account) => _buildAccountTile(account)),
      ],
    );
  }

  Widget _buildAccountTile(AccountModel account) {
    return ListTile(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AddAccountScreen(account: account),
          ),
        );
      },
      leading: CircleAvatar(
        backgroundColor: _getAccountColor(account.type).withOpacity(0.2),
        child: Icon(
          _getAccountIcon(account.type),
          color: _getAccountColor(account.type),
          size: 20,
        ),
      ),
      title: Text(
        account.name,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(account.typeDisplayName),
      trailing: Text(
        '₹${account.balance.toStringAsFixed(0)}',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: account.balance >= 0 ? Colors.green : Colors.red,
        ),
      ),
    );
  }

  IconData _getAccountIcon(String type) {
    switch (type) {
      case 'cash':
        return Icons.money;
      case 'bank':
        return Icons.account_balance;
      case 'credit_card':
        return Icons.credit_card;
      case 'loan':
        return Icons.receipt_long;
      default:
        return Icons.wallet;
    }
  }

  Color _getAccountColor(String type) {
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
}