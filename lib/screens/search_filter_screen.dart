import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction_model.dart';
import '../models/account_model.dart';
import '../services/transaction_service.dart';
import '../services/account_service.dart';
import 'transaction_detail_screen.dart';

class SearchFilterScreen extends StatefulWidget {
  const SearchFilterScreen({super.key});

  @override
  State<SearchFilterScreen> createState() => _SearchFilterScreenState();
}

class _SearchFilterScreenState extends State<SearchFilterScreen> {
  final TransactionService _transactionService = TransactionService();
  final AccountService _accountService = AccountService();
  final TextEditingController _searchController = TextEditingController();

  List<TransactionModel> _allTransactions = [];
  List<TransactionModel> _filteredTransactions = [];
  List<AccountModel> _accounts = [];

  // Filter criteria
  String? _selectedType; // income, expense, transfer
  String? _selectedCategory;
  String? _selectedAccount;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    final transactions = await _transactionService.getTransactionsList();
    final accountsStream = _accountService.getAccountsList();
    final accounts = await accountsStream.first;

    setState(() {
      _allTransactions = transactions;
      _filteredTransactions = transactions;
      _accounts = accounts;
      _isLoading = false;
    });
  }

  void _applyFilters() {
    setState(() {
      _filteredTransactions = _allTransactions.where((transaction) {
        // Search query
        if (_searchController.text.isNotEmpty) {
          final query = _searchController.text.toLowerCase();
          final matchesSearch = transaction.category.toLowerCase().contains(query) ||
              (transaction.subcategory?.toLowerCase().contains(query) ?? false) ||
              (transaction.note?.toLowerCase().contains(query) ?? false);
          if (!matchesSearch) return false;
        }

        // Type filter
        if (_selectedType != null && transaction.type != _selectedType) {
          return false;
        }

        // Category filter
        if (_selectedCategory != null && transaction.category != _selectedCategory) {
          return false;
        }

        // Account filter
        if (_selectedAccount != null) {
          final matchesAccount = (transaction.fromAccount == _selectedAccount) ||
              (transaction.toAccount == _selectedAccount);
          if (!matchesAccount) return false;
        }

        // Date range filter
        if (_startDate != null && transaction.date.isBefore(_startDate!)) {
          return false;
        }
        if (_endDate != null && transaction.date.isAfter(_endDate!.add(const Duration(days: 1)))) {
          return false;
        }

        return true;
      }).toList();
    });
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _selectedType = null;
      _selectedCategory = null;
      _selectedAccount = null;
      _startDate = null;
      _endDate = null;
      _filteredTransactions = _allTransactions;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasActiveFilters = _selectedType != null ||
        _selectedCategory != null ||
        _selectedAccount != null ||
        _startDate != null ||
        _endDate != null ||
        _searchController.text.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search & Filter'),
        actions: [
          if (hasActiveFilters)
            IconButton(
              icon: const Icon(Icons.clear_all),
              tooltip: 'Clear all filters',
              onPressed: _clearFilters,
            ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search transactions...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _applyFilters();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
              onChanged: (value) => _applyFilters(),
            ),
          ),

          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildFilterChip(
                  'Type',
                  _selectedType,
                  () => _showTypeFilter(),
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'Category',
                  _selectedCategory,
                  () => _showCategoryFilter(),
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'Account',
                  _selectedAccount != null
                      ? _accounts.firstWhere((a) => a.id == _selectedAccount).name
                      : null,
                  () => _showAccountFilter(),
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'Date Range',
                  _startDate != null
                      ? '${DateFormat('MMM d').format(_startDate!)} - ${_endDate != null ? DateFormat('MMM d').format(_endDate!) : 'Now'}'
                      : null,
                  () => _showDateRangeFilter(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Results count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_filteredTransactions.length} transaction${_filteredTransactions.length != 1 ? 's' : ''}',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (hasActiveFilters)
                  Text(
                    'of ${_allTransactions.length} total',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Transactions list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredTransactions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text(
                              hasActiveFilters
                                  ? 'No transactions match your filters'
                                  : 'No transactions yet',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            if (hasActiveFilters) ...[
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: _clearFilters,
                                child: const Text('Clear filters'),
                              ),
                            ],
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: _filteredTransactions.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final transaction = _filteredTransactions[index];
                          return _buildTransactionTile(transaction);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String? value, VoidCallback onTap) {
    final isActive = value != null;
    
    return FilterChip(
      label: Text(
        isActive ? '$label: $value' : label,
        style: TextStyle(
          color: isActive ? Colors.blue : Colors.grey.shade700,
          fontSize: 13,
        ),
      ),
      selected: isActive,
      onSelected: (_) => onTap(),
      selectedColor: Colors.blue.shade100,
      checkmarkColor: Colors.blue,
      side: BorderSide(
        color: isActive ? Colors.blue : Colors.grey.shade300,
      ),
    );
  }

  Widget _buildTransactionTile(TransactionModel transaction) {
    final isIncome = transaction.type == 'income';
    final color = isIncome ? Colors.green : (transaction.type == 'transfer' ? Colors.blue : Colors.red);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.1),
        child: Icon(
          _getCategoryIcon(transaction.category),
          color: color,
          size: 20,
        ),
      ),
      title: Text(
        transaction.category,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (transaction.subcategory != null)
            Text(
              transaction.subcategory!,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          Text(
            DateFormat('MMM d, yyyy').format(transaction.date),
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
        ],
      ),
      trailing: Text(
        '${isIncome ? '+' : transaction.type == 'transfer' ? '' : '-'}₹${transaction.amount.toStringAsFixed(0)}',
        style: TextStyle(
          color: color,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TransactionDetailScreen(transaction: transaction),
          ),
        ).then((_) => _loadData());
      },
    );
  }

  void _showTypeFilter() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('All Types'),
              trailing: _selectedType == null ? const Icon(Icons.check) : null,
              onTap: () {
                setState(() => _selectedType = null);
                _applyFilters();
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.add_circle, color: Colors.green),
              title: const Text('Income'),
              trailing: _selectedType == 'income' ? const Icon(Icons.check) : null,
              onTap: () {
                setState(() => _selectedType = 'income');
                _applyFilters();
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.remove_circle, color: Colors.red),
              title: const Text('Expense'),
              trailing: _selectedType == 'expense' ? const Icon(Icons.check) : null,
              onTap: () {
                setState(() => _selectedType = 'expense');
                _applyFilters();
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.swap_horiz, color: Colors.blue),
              title: const Text('Transfer'),
              trailing: _selectedType == 'transfer' ? const Icon(Icons.check) : null,
              onTap: () {
                setState(() => _selectedType = 'transfer');
                _applyFilters();
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showCategoryFilter() {
    final categories = _allTransactions.map((t) => t.category).toSet().toList()..sort();

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('All Categories'),
              trailing: _selectedCategory == null ? const Icon(Icons.check) : null,
              onTap: () {
                setState(() => _selectedCategory = null);
                _applyFilters();
                Navigator.pop(context);
              },
            ),
            ...categories.map((category) => ListTile(
                  title: Text(category),
                  trailing: _selectedCategory == category ? const Icon(Icons.check) : null,
                  onTap: () {
                    setState(() => _selectedCategory = category);
                    _applyFilters();
                    Navigator.pop(context);
                  },
                )),
          ],
        ),
      ),
    );
  }

  void _showAccountFilter() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('All Accounts'),
              trailing: _selectedAccount == null ? const Icon(Icons.check) : null,
              onTap: () {
                setState(() => _selectedAccount = null);
                _applyFilters();
                Navigator.pop(context);
              },
            ),
            ..._accounts.map((account) => ListTile(
                  leading: Icon(_getAccountIcon(account.type)),
                  title: Text(account.name),
                  trailing: _selectedAccount == account.id ? const Icon(Icons.check) : null,
                  onTap: () {
                    setState(() => _selectedAccount = account.id);
                    _applyFilters();
                    Navigator.pop(context);
                  },
                )),
          ],
        ),
      ),
    );
  }

  Future<void> _showDateRangeFilter() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _applyFilters();
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
      case 'Transfer':
        return Icons.swap_horiz;
      default:
        return Icons.category;
    }
  }

  IconData _getAccountIcon(String type) {
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
}