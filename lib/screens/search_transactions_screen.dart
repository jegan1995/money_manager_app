import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction_model.dart';
import '../services/transaction_service.dart';
import '../utils/categories.dart';
import 'add_transaction_screen.dart';

class SearchTransactionsScreen extends StatefulWidget {
  const SearchTransactionsScreen({super.key});

  @override
  State<SearchTransactionsScreen> createState() =>
      _SearchTransactionsScreenState();
}

class _SearchTransactionsScreenState extends State<SearchTransactionsScreen> {
  final TransactionService _transactionService = TransactionService();
  final TextEditingController _searchController = TextEditingController();

  // Filter states
  String _searchQuery = '';
  String? _selectedType; // 'income', 'expense', or null for all
  String? _selectedCategory;
  DateTimeRange? _dateRange;
  double? _minAmount;
  double? _maxAmount;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Search Transactions'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          if (_hasActiveFilters())
            TextButton.icon(
              onPressed: _clearAllFilters,
              icon: const Icon(Icons.clear_all, size: 18),
              label: const Text('Clear'),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
            ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildQuickFilters(),
          if (_hasActiveFilters()) _buildActiveFilters(),
          _buildFilterChips(),
          Expanded(child: _buildResults()),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search by amount, category, or note...',
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.grey[100],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        onChanged: (value) {
          setState(() => _searchQuery = value);
        },
      ),
    );
  }

  Widget _buildQuickFilters() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildQuickFilterButton('Today', () => _setDateRange(0)),
            const SizedBox(width: 8),
            _buildQuickFilterButton('This Week', () => _setDateRange(7)),
            const SizedBox(width: 8),
            _buildQuickFilterButton('This Month', () => _setDateRange(30)),
            const SizedBox(width: 8),
            _buildQuickFilterButton('Last 3 Months', () => _setDateRange(90)),
            const SizedBox(width: 8),
            _buildQuickFilterButton(
              'Custom Range',
              () => _showDateRangePicker(),
              icon: Icons.date_range,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickFilterButton(String label, VoidCallback onPressed,
      {IconData? icon}) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon ?? Icons.calendar_today, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.blue,
        side: const BorderSide(color: Colors.blue),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 8,
        children: [
          _buildFilterChip(
            'Type',
            _selectedType == null ? 'All' : _selectedType!.toUpperCase(),
            Colors.blue,
            () => _showTypeFilter(),
          ),
          _buildFilterChip(
            'Category',
            _selectedCategory ?? 'All',
            Colors.purple,
            () => _showCategoryFilter(),
          ),
          _buildFilterChip(
            'Amount',
            _getAmountRangeText(),
            Colors.green,
            () => _showAmountFilter(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
      String label, String value, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$label: ',
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, color: color, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveFilters() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.blue[50],
      child: Row(
        children: [
          Icon(Icons.filter_list, size: 16, color: Colors.blue[700]),
          const SizedBox(width: 8),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: _getActiveFilterChips(),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _getActiveFilterChips() {
    List<Widget> chips = [];

    if (_selectedType != null) {
      chips.add(_buildActiveFilterChip(
        _selectedType!.toUpperCase(),
        () => setState(() => _selectedType = null),
      ));
    }

    if (_selectedCategory != null) {
      chips.add(_buildActiveFilterChip(
        _selectedCategory!,
        () => setState(() => _selectedCategory = null),
      ));
    }

    if (_dateRange != null) {
      chips.add(_buildActiveFilterChip(
        '${DateFormat('MMM d').format(_dateRange!.start)} - ${DateFormat('MMM d').format(_dateRange!.end)}',
        () => setState(() => _dateRange = null),
      ));
    }

    if (_minAmount != null || _maxAmount != null) {
      chips.add(_buildActiveFilterChip(
        _getAmountRangeText(),
        () => setState(() {
          _minAmount = null;
          _maxAmount = null;
        }),
      ));
    }

    return chips;
  }

  Widget _buildActiveFilterChip(String label, VoidCallback onRemove) {
    return Chip(
      label: Text(label),
      deleteIcon: const Icon(Icons.close, size: 16),
      onDeleted: onRemove,
      backgroundColor: Colors.white,
      labelStyle: TextStyle(color: Colors.blue[700], fontSize: 12),
      deleteIconColor: Colors.blue[700],
      side: BorderSide(color: Colors.blue[300]!),
    );
  }

  Widget _buildResults() {
    return StreamBuilder<List<TransactionModel>>(
      stream: _transactionService.getTransactions(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState('No transactions found');
        }

        var transactions = _filterTransactions(snapshot.data!);

        if (transactions.isEmpty) {
          return _buildEmptyState('No results match your filters');
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: transactions.length,
          itemBuilder: (context, index) {
            return _buildTransactionCard(transactions[index]);
          },
        );
      },
    );
  }

  Widget _buildTransactionCard(TransactionModel txn) {
    final isIncome = txn.type == 'income';
    final color = isIncome ? Colors.green : Colors.red;
    final icon = isIncome ? Icons.arrow_downward : Icons.arrow_upward;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Text(
          txn.category,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (txn.subcategory != null)
              Text(
                txn.subcategory!,
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            Text(
              DateFormat('MMM d, yyyy • h:mm a').format(txn.date),
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
            if (txn.note != null && txn.note!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  txn.note!,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
        trailing: Text(
          '${isIncome ? '+' : '-'}₹${txn.amount.toStringAsFixed(0)}',
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
              builder: (context) => AddTransactionScreen(transaction: txn),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // Filter logic
  List<TransactionModel> _filterTransactions(
      List<TransactionModel> transactions) {
    var filtered = transactions;

    // Search query filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((txn) {
        final query = _searchQuery.toLowerCase();
        return txn.category.toLowerCase().contains(query) ||
            (txn.subcategory?.toLowerCase().contains(query) ?? false) ||
            (txn.note?.toLowerCase().contains(query) ?? false) ||
            txn.amount.toString().contains(query);
      }).toList();
    }

    // Type filter
    if (_selectedType != null) {
      filtered = filtered.where((txn) => txn.type == _selectedType).toList();
    }

    // Category filter
    if (_selectedCategory != null) {
      filtered =
          filtered.where((txn) => txn.category == _selectedCategory).toList();
    }

    // Date range filter
    if (_dateRange != null) {
      filtered = filtered.where((txn) {
        return txn.date
                .isAfter(_dateRange!.start.subtract(const Duration(days: 1))) &&
            txn.date.isBefore(_dateRange!.end.add(const Duration(days: 1)));
      }).toList();
    }

    // Amount range filter
    if (_minAmount != null) {
      filtered = filtered.where((txn) => txn.amount >= _minAmount!).toList();
    }
    if (_maxAmount != null) {
      filtered = filtered.where((txn) => txn.amount <= _maxAmount!).toList();
    }

    // Sort by date descending
    filtered.sort((a, b) => b.date.compareTo(a.date));

    return filtered;
  }

  // Filter actions
  void _setDateRange(int days) {
    final now = DateTime.now();
    setState(() {
      _dateRange = DateTimeRange(
        start: now.subtract(Duration(days: days)),
        end: now,
      );
    });
  }

  Future<void> _showDateRangePicker() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
    );

    if (picked != null) {
      setState(() => _dateRange = picked);
    }
  }

  void _showTypeFilter() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.all_inclusive, color: Colors.grey),
              title: const Text('All Types'),
              onTap: () {
                setState(() => _selectedType = null);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.arrow_downward, color: Colors.green),
              title: const Text('Income Only'),
              onTap: () {
                setState(() => _selectedType = 'income');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.arrow_upward, color: Colors.red),
              title: const Text('Expense Only'),
              onTap: () {
                setState(() => _selectedType = 'expense');
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showCategoryFilter() {
    final categories = _selectedType == 'income'
        ? Categories.incomeCategories
        : _selectedType == 'expense'
            ? Categories.expenseCategories
            : [...Categories.incomeCategories, ...Categories.expenseCategories];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Select Category',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ),
            ListTile(
              title: const Text('All Categories'),
              onTap: () {
                setState(() => _selectedCategory = null);
                Navigator.pop(context);
              },
            ),
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final category = categories[index];
                  return ListTile(
                    title: Text(category),
                    selected: _selectedCategory == category,
                    onTap: () {
                      setState(() => _selectedCategory = category);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAmountFilter() {
    final minController = TextEditingController(
      text: _minAmount?.toString() ?? '',
    );
    final maxController = TextEditingController(
      text: _maxAmount?.toString() ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Amount Range'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: minController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Minimum Amount',
                prefixText: '₹',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: maxController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Maximum Amount',
                prefixText: '₹',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _minAmount = null;
                _maxAmount = null;
              });
              Navigator.pop(context);
            },
            child: const Text('Clear'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _minAmount = double.tryParse(minController.text);
                _maxAmount = double.tryParse(maxController.text);
              });
              Navigator.pop(context);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  void _clearAllFilters() {
    setState(() {
      _searchQuery = '';
      _selectedType = null;
      _selectedCategory = null;
      _dateRange = null;
      _minAmount = null;
      _maxAmount = null;
      _searchController.clear();
    });
  }

  bool _hasActiveFilters() {
    return _selectedType != null ||
        _selectedCategory != null ||
        _dateRange != null ||
        _minAmount != null ||
        _maxAmount != null;
  }

  String _getAmountRangeText() {
    if (_minAmount != null && _maxAmount != null) {
      return '₹${_minAmount!.toInt()}-₹${_maxAmount!.toInt()}';
    } else if (_minAmount != null) {
      return '≥₹${_minAmount!.toInt()}';
    } else if (_maxAmount != null) {
      return '≤₹${_maxAmount!.toInt()}';
    }
    return 'Any';
  }
}
