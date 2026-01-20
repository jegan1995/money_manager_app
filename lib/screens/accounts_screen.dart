import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Accounts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const AddAccountScreen()),
              );
            },
          ),
        ],
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
                      size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 24),
                  Text('No accounts yet',
                      style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 18,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Text('Tap + to add your first account',
                      style: TextStyle(color: Colors.grey[500], fontSize: 14)),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const AddAccountScreen()),
                      );
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Add Account'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                    ),
                  ),
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

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {});
            },
            child: ListView(
              children: [
                // Summary Cards
                _buildSummarySection(totalAssets, totalDebt, netWorth),

                const SizedBox(height: 8),

                // Accounts List
                if (grouped.containsKey('cash'))
                  _buildAccountGroup('Cash', grouped['cash']!, Colors.green),
                if (grouped.containsKey('bank'))
                  _buildAccountGroup(
                      'Bank Accounts', grouped['bank']!, Colors.blue),
                if (grouped.containsKey('credit_card'))
                  _buildAccountGroup(
                      'Credit Cards', grouped['credit_card']!, Colors.orange),
                if (grouped.containsKey('loan'))
                  _buildAccountGroup('Loans', grouped['loan']!, Colors.red),
                if (grouped.containsKey('other'))
                  _buildAccountGroup('Others', grouped['other']!, Colors.grey),

                const SizedBox(height: 80), // Space for FAB
              ],
            ),
          );
        },
      ),
      // floatingActionButton: FloatingActionButton.extended(
      //   onPressed: () {
      //     Navigator.push(
      //       context,
      //       MaterialPageRoute(builder: (context) => const AddAccountScreen()),
      //     );
      //   },
      //   icon: const Icon(Icons.add),
        label: const Text('Add Account'),
      // ),
    );
  }

  Widget _buildSummarySection(double assets, double debt, double netWorth) {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Net Worth Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue[700]!, Colors.blue[500]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                const Text(
                  'Net Worth',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '₹${netWorth.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Assets and Debt Row
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'Assets',
                  assets,
                  Icons.account_balance_wallet,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  'Debt',
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '₹${amount.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountGroup(
      String title, List<AccountModel> accounts, Color color) {
    final total = accounts.fold<double>(0, (sum, acc) => sum + acc.balance);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Group Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(_getAccountIcon(accounts.first.type),
                        size: 20, color: color),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: color,
                      ),
                    ),
                  ],
                ),
                Text(
                  '₹${total.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: color,
                  ),
                ),
              ],
            ),
          ),

          // Accounts List
          ...accounts.asMap().entries.map((entry) {
            final index = entry.key;
            final account = entry.value;
            final isLast = index == accounts.length - 1;

            return Column(
              children: [
                _buildAccountTile(account),
                if (!isLast) Divider(height: 1, color: Colors.grey[200]),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildAccountTile(AccountModel account) {
    return ListTile(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AccountDetailScreen(account: account),
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
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
      subtitle: account.note != null && account.note!.isNotEmpty
          ? Text(
              account.note!,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : null,
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
