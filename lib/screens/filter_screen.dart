import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/transaction_model.dart';
import '../services/transaction_service.dart';
// import '../utils/subcategories.dart';
import '../utils/categories.dart';
import 'transaction_detail_screen.dart';

class FilterScreen extends StatefulWidget {
  const FilterScreen({super.key});

  @override
  State<FilterScreen> createState() => _FilterScreenState();
}

class _FilterScreenState extends State<FilterScreen> {
  final TransactionService _transactionService = TransactionService();

  String? _selectedType;
  String? _selectedCategory;
  DateTime? _startDate;
  DateTime? _endDate;
  double? _minAmount;
  double? _maxAmount;

  List<TransactionModel> _filteredTransactions = [];
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Filter Transactions'),
        actions: [
          TextButton(
            onPressed: _clearFilters,
            child: const Text('Clear All'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Type Filter
                const Text('Type', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    FilterChip(
                      label: const Text('All'),
                      selected: _selectedType == null,
                      onSelected: (selected) {
                        setState(() {
                          _selectedType = null;
                        });
                      },
                    ),
                    FilterChip(
                      label: const Text('Income'),
                      selected: _selectedType == 'income',
                      onSelected: (selected) {
                        setState(() {
                          _selectedType = selected ? 'income' : null;
                        });
                      },
                    ),
                    FilterChip(
                      label: const Text('Expense'),
                      selected: _selectedType == 'expense',
                      onSelected: (selected) {
                        setState(() {
                          _selectedType = selected ? 'expense' : null;
                        });
                      },
                    ),
                    FilterChip(
                      label: const Text('Transfer'),
                      selected: _selectedType == 'transfer',
                      onSelected: (selected) {
                        setState(() {
                          _selectedType = selected ? 'transfer' : null;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Category Filter
                const Text('Category', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Select category',
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All Categories')),
                    ...Categories.getMainCategories('expense')
                        .map((cat) => DropdownMenuItem(value: cat, child: Text(cat))),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedCategory = value;
                    });
                  },
                ),
                const SizedBox(height: 24),

                // Date Range
                const Text('Date Range', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _startDate ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (date != null) {
                            setState(() {
                              _startDate = date;
                            });
                          }
                        },
                        icon: const Icon(Icons.calendar_today),
                        label: Text(_startDate == null
                            ? 'Start Date'
                            : DateFormat('MMM d, yyyy').format(_startDate!)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _endDate ?? DateTime.now(),
                            firstDate: _startDate ?? DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (date != null) {
                            setState(() {
                              _endDate = date;
                            });
                          }
                        },
                        icon: const Icon(Icons.calendar_today),
                        label: Text(_endDate == null
                            ? 'End Date'
                            : DateFormat('MMM d, yyyy').format(_endDate!)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Amount Range
                const Text('Amount Range', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Min Amount',
                          prefixText: '₹ ',
                        ),
                        onChanged: (value) {
                          _minAmount = double.tryParse(value);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Max Amount',
                          prefixText: '₹ ',
                        ),
                        onChanged: (value) {
                          _maxAmount = double.tryParse(value);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Apply Button
          Container(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: _isLoading ? null : _applyFilters,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                minimumSize: const Size.fromHeight(50),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('APPLY FILTERS',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  void _clearFilters() {
    setState(() {
      _selectedType = null;
      _selectedCategory = null;
      _startDate = null;
      _endDate = null;
      _minAmount = null;
      _maxAmount = null;
      _filteredTransactions = [];
    });
  }

  Future<void> _applyFilters() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final snapshot = await _transactionService.getTransactions().first;
      final allTransactions = snapshot.docs
          .map((doc) => TransactionModel.fromFirestore(doc))
          .toList();

      final filtered = allTransactions.where((txn) {
        // Type filter
        if (_selectedType != null && txn.type != _selectedType) return false;

        // Category filter
        if (_selectedCategory != null && txn.category != _selectedCategory)
          return false;

        // Date range filter
        if (_startDate != null && txn.date.isBefore(_startDate!)) return false;
        if (_endDate != null && txn.date.isAfter(_endDate!)) return false;

        // Amount range filter
        if (_minAmount != null && txn.amount < _minAmount!) return false;
        if (_maxAmount != null && txn.amount > _maxAmount!) return false;

        return true;
      }).toList();

      setState(() {
        _filteredTransactions = filtered;
        _isLoading = false;
      });

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FilterResultsScreen(
              transactions: _filteredTransactions,
              filterSummary: _getFilterSummary(),
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _getFilterSummary() {
    List<String> filters = [];
    if (_selectedType != null) filters.add('Type: $_selectedType');
    if (_selectedCategory != null) filters.add('Category: $_selectedCategory');
    if (_startDate != null)
      filters.add('From: ${DateFormat('MMM d').format(_startDate!)}');
    if (_endDate != null)
      filters.add('To: ${DateFormat('MMM d').format(_endDate!)}');
    if (_minAmount != null) filters.add('Min: ₹$_minAmount');
    if (_maxAmount != null) filters.add('Max: ₹$_maxAmount');

    return filters.isEmpty ? 'All Transactions' : filters.join(' • ');
  }
}

class FilterResultsScreen extends StatelessWidget {
  final List<TransactionModel> transactions;
  final String filterSummary;

  const FilterResultsScreen({
    super.key,
    required this.transactions,
    required this.filterSummary,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Filter Results'),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue[50],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${transactions.length} transactions found',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  filterSummary,
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
              ],
            ),
          ),
          Expanded(
            child: transactions.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        const Text('No transactions match your filters'),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: transactions.length,
                    itemBuilder: (context, index) {
                      final txn = transactions[index];
                      final isExpense = txn.type == 'expense';
                      final isTransfer = txn.type == 'transfer';

                      return ListTile(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  TransactionDetailScreen(transaction: txn),
                            ),
                          );
                        },
                        leading: CircleAvatar(
                          backgroundColor: isTransfer
                              ? Colors.blue[50]
                              : (isExpense ? Colors.red[50] : Colors.green[50]),
                          child: Icon(
                            isTransfer ? Icons.swap_horiz : Icons.category,
                            color: isTransfer
                                ? Colors.blue
                                : (isExpense ? Colors.red : Colors.green),
                          ),
                        ),
                        title: Text(txn.category),
                        subtitle: Text(DateFormat('MMM d, yyyy').format(txn.date)),
                        trailing: Text(
                          isTransfer
                              ? '₹${txn.amount.toStringAsFixed(0)}'
                              : '${isExpense ? '-' : '+'}₹${txn.amount.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isTransfer
                                ? Colors.blue
                                : (isExpense ? Colors.red : Colors.green),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
