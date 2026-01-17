import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart' as app_transaction;
import '../models/transaction_filter.dart';
import '../services/firestore_service.dart';
import 'add_transaction_screen.dart';
import 'edit_transaction_screen.dart';
// import 'reports_screen.dart';
import '../utils/category_icons.dart';
// import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _searchController = TextEditingController();
  
  TransactionFilter _filter = TransactionFilter();
  
  final List<String> _allCategories = [
    'Food',
    'Transport',
    'Shopping',
    'Bills',
    'Entertainment',
    'Health',
    'Education',
    'Salary',
    'Business',
    'Investment',
    'Gift',
    'Other'
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<app_transaction.Transaction> _applyFilters(
      List<app_transaction.Transaction> transactions) {
    List<app_transaction.Transaction> filtered = transactions;

    // Filter by search query
    if (_filter.searchQuery.isNotEmpty) {
      filtered = filtered
          .where((t) => t.title
              .toLowerCase()
              .contains(_filter.searchQuery.toLowerCase()))
          .toList();
    }

    // Filter by type (income/expense)
    if (_filter.type != FilterType.all) {
      String typeString =
          _filter.type == FilterType.income ? 'income' : 'expense';
      filtered = filtered.where((t) => t.type == typeString).toList();
    }

    // Filter by category
    if (_filter.category != null) {
      filtered = filtered.where((t) => t.category == _filter.category).toList();
    }

    // Filter by date
    if (_filter.dateFilter != DateFilter.all) {
      DateTime now = DateTime.now();
      DateTime startOfDay = DateTime(now.year, now.month, now.day);

      switch (_filter.dateFilter) {
        case DateFilter.today:
          filtered = filtered
              .where((t) =>
                  t.date.isAfter(startOfDay.subtract(const Duration(days: 1))))
              .toList();
          break;
        case DateFilter.last7days:
          filtered = filtered
              .where((t) =>
                  t.date.isAfter(startOfDay.subtract(const Duration(days: 7))))
              .toList();
          break;
        case DateFilter.last30days:
          filtered = filtered
              .where((t) =>
                  t.date.isAfter(startOfDay.subtract(const Duration(days: 30))))
              .toList();
          break;
        case DateFilter.custom:
          if (_filter.startDate != null && _filter.endDate != null) {
            filtered = filtered
                .where((t) =>
                    t.date.isAfter(_filter.startDate!) &&
                    t.date.isBefore(_filter.endDate!.add(const Duration(days: 1))))
                .toList();
          }
          break;
        default:
          break;
      }
    }

    return filtered;
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Filter Transactions',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_filter.hasActiveFilters)
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _filter = TransactionFilter();
                            _searchController.clear();
                          });
                          Navigator.pop(context);
                        },
                        child: const Text('Clear All'),
                      ),
                  ],
                ),
                const SizedBox(height: 20),

                // Type Filter
                const Text(
                  'Type',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    FilterChip(
                      label: const Text('All'),
                      selected: _filter.type == FilterType.all,
                      onSelected: (selected) {
                        setModalState(() {
                          setState(() {
                            _filter = _filter.copyWith(type: FilterType.all);
                          });
                        });
                      },
                    ),
                    FilterChip(
                      label: const Text('Income'),
                      selected: _filter.type == FilterType.income,
                      selectedColor: Colors.green.shade100,
                      onSelected: (selected) {
                        setModalState(() {
                          setState(() {
                            _filter = _filter.copyWith(type: FilterType.income);
                          });
                        });
                      },
                    ),
                    FilterChip(
                      label: const Text('Expense'),
                      selected: _filter.type == FilterType.expense,
                      selectedColor: Colors.red.shade100,
                      onSelected: (selected) {
                        setModalState(() {
                          setState(() {
                            _filter = _filter.copyWith(type: FilterType.expense);
                          });
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Date Filter
                const Text(
                  'Date Range',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    FilterChip(
                      label: const Text('All Time'),
                      selected: _filter.dateFilter == DateFilter.all,
                      onSelected: (selected) {
                        setModalState(() {
                          setState(() {
                            _filter = _filter.copyWith(dateFilter: DateFilter.all);
                          });
                        });
                      },
                    ),
                    FilterChip(
                      label: const Text('Today'),
                      selected: _filter.dateFilter == DateFilter.today,
                      onSelected: (selected) {
                        setModalState(() {
                          setState(() {
                            _filter = _filter.copyWith(dateFilter: DateFilter.today);
                          });
                        });
                      },
                    ),
                    FilterChip(
                      label: const Text('Last 7 Days'),
                      selected: _filter.dateFilter == DateFilter.last7days,
                      onSelected: (selected) {
                        setModalState(() {
                          setState(() {
                            _filter =
                                _filter.copyWith(dateFilter: DateFilter.last7days);
                          });
                        });
                      },
                    ),
                    FilterChip(
                      label: const Text('Last 30 Days'),
                      selected: _filter.dateFilter == DateFilter.last30days,
                      onSelected: (selected) {
                        setModalState(() {
                          setState(() {
                            _filter =
                                _filter.copyWith(dateFilter: DateFilter.last30days);
                          });
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Category Filter
                const Text(
                  'Category',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilterChip(
                      label: const Text('All Categories'),
                      selected: _filter.category == null,
                      onSelected: (selected) {
                        setModalState(() {
                          setState(() {
                            _filter = _filter.copyWith(category: null);
                          });
                        });
                      },
                    ),
                    ..._allCategories.map((category) {
                      return FilterChip(
                        label: Text(category),
                        selected: _filter.category == category,
                        onSelected: (selected) {
                          setModalState(() {
                            setState(() {
                              _filter = _filter.copyWith(
                                  category: selected ? category : null);
                            });
                          });
                        },
                      );
                    }).toList(),
                  ],
                ),
                const SizedBox(height: 20),

                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                  child: const Text('Apply Filters'),
                ),
                const SizedBox(height: 10),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuickStats(List<app_transaction.Transaction> allTransactions) {
    DateTime now = DateTime.now();
    DateTime today = DateTime(now.year, now.month, now.day);
    DateTime weekAgo = today.subtract(const Duration(days: 7));
    
    double todayExpense = 0;
    double weekExpense = 0;
    
    for (var t in allTransactions) {
      if (t.type == 'expense') {
        if (t.date.isAfter(today.subtract(const Duration(days: 1)))) {
          todayExpense += t.amount;
        }
        if (t.date.isAfter(weekAgo)) {
          weekExpense += t.amount;
        }
      }
    }
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple.shade300, Colors.purple.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Column(
            children: [
              const Text(
                'Today',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                '₹${todayExpense.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Container(
            height: 40,
            width: 1,
            color: Colors.white30,
          ),
          Column(
            children: [
              const Text(
                'This Week',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                '₹${weekExpense.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  Widget _buildEnhancedStats(List<app_transaction.Transaction> allTransactions) {
    DateTime now = DateTime.now();
    DateTime startOfMonth = DateTime(now.year, now.month, 1);
    DateTime lastMonth = DateTime(now.year, now.month - 1, 1);
    DateTime endOfLastMonth = DateTime(now.year, now.month, 1);
    
    double monthIncome = 0;
    double monthExpense = 0;
    double lastMonthExpense = 0;
    
    for (var t in allTransactions) {
      if (t.date.isAfter(startOfMonth)) {
        if (t.type == 'income') {
          monthIncome += t.amount;
        } else {
          monthExpense += t.amount;
        }
      }
      
      if (t.date.isAfter(lastMonth) && t.date.isBefore(endOfLastMonth)) {
        if (t.type == 'expense') {
          lastMonthExpense += t.amount;
        }
      }
    }
    
    double changePercent = lastMonthExpense > 0 
        ? ((monthExpense - lastMonthExpense) / lastMonthExpense) * 100 
        : 0;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade300, Colors.indigo.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'This Month',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Income',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  Text(
                    '₹${monthIncome.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Expense',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  Text(
                    '₹${monthExpense.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              if (lastMonthExpense > 0)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'vs Last Month',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    Row(
                      children: [
                        Icon(
                          changePercent > 0 ? Icons.arrow_upward : Icons.arrow_downward,
                          color: changePercent > 0 ? Colors.red : Colors.green,
                          size: 16,
                        ),
                        Text(
                          '${changePercent.abs().toStringAsFixed(1)}%',
                          style: TextStyle(
                            color: changePercent > 0 ? Colors.red : Colors.green,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Money Manager'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.insert_chart),
            tooltip: 'Reports',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ReportsScreen(),
                ),
              );
            },
          ),
          if (_filter.hasActiveFilters)
            IconButton(
              icon: const Icon(Icons.filter_alt_off),
              tooltip: 'Clear Filters',
              onPressed: () {
                setState(() {
                  _filter = TransactionFilter();
                  _searchController.clear();
                });
              },
            ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filter',
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search transactions...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _filter = _filter.copyWith(searchQuery: '');
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
              onChanged: (value) {
                setState(() {
                  _filter = _filter.copyWith(searchQuery: value);
                });
              },
            ),
          ),

          // Active Filters Display
          if (_filter.hasActiveFilters)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (_filter.type != FilterType.all)
                    Chip(
                      label: Text(_filter.type == FilterType.income
                          ? 'Income'
                          : 'Expense'),
                      backgroundColor: _filter.type == FilterType.income
                          ? Colors.green.shade100
                          : Colors.red.shade100,
                      deleteIcon: const Icon(Icons.close, size: 18),
                      onDeleted: () {
                        setState(() {
                          _filter = _filter.copyWith(type: FilterType.all);
                        });
                      },
                    ),
                  if (_filter.category != null)
                    Chip(
                      label: Text(_filter.category!),
                      deleteIcon: const Icon(Icons.close, size: 18),
                      onDeleted: () {
                        setState(() {
                          _filter = _filter.copyWith(category: null);
                        });
                      },
                    ),
                  if (_filter.dateFilter != DateFilter.all)
                    Chip(
                      label: Text(_getDateFilterLabel()),
                      deleteIcon: const Icon(Icons.close, size: 18),
                      onDeleted: () {
                        setState(() {
                          _filter = _filter.copyWith(dateFilter: DateFilter.all);
                        });
                      },
                    ),
                ],
              ),
            ),

          // Balance card
          _buildBalanceCard(),
          
// Quick stats
          StreamBuilder<List<app_transaction.Transaction>>(
            stream: _firestoreService.getTransactions(),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                return _buildQuickStats(snapshot.data!);
              }
              return const SizedBox.shrink();
            },
          ),
          
          // Enhanced monthly stats
          StreamBuilder<List<app_transaction.Transaction>>(
            stream: _firestoreService.getTransactions(),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                return _buildEnhancedStats(snapshot.data!);
              }
              return const SizedBox.shrink();
            },
          ),

          // Transaction list
          Expanded(
            child: StreamBuilder<List<app_transaction.Transaction>>(
              stream: _firestoreService.getTransactions(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox, size: 80, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No transactions yet',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Tap + to add your first transaction',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                final allTransactions = snapshot.data!;
                final filteredTransactions = _applyFilters(allTransactions);

                if (filteredTransactions.isEmpty && _filter.hasActiveFilters) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.search_off, size: 80, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text(
                          'No transactions found',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _filter = TransactionFilter();
                              _searchController.clear();
                            });
                          },
                          child: const Text('Clear filters'),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: [
                    // Transaction count
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${filteredTransactions.length} transaction${filteredTransactions.length != 1 ? 's' : ''}',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (_filter.hasActiveFilters)
                            Text(
                              'of ${allTransactions.length} total',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Transaction list
                    Expanded(
                      child: ListView.builder(
                        itemCount: filteredTransactions.length,
                        itemBuilder: (context, index) {
                          return _buildTransactionTile(
                              filteredTransactions[index]);
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddTransactionScreen(),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  String _getDateFilterLabel() {
    switch (_filter.dateFilter) {
      case DateFilter.today:
        return 'Today';
      case DateFilter.last7days:
        return 'Last 7 Days';
      case DateFilter.last30days:
        return 'Last 30 Days';
      case DateFilter.custom:
        return 'Custom Range';
      default:
        return 'All Time';
    }
  }

  Widget _buildBalanceCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade400, Colors.blue.shade700],
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
      child: StreamBuilder<List<app_transaction.Transaction>>(
        stream: _firestoreService.getTransactions(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Column(
              children: [
                Text(
                  'Total Balance',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 8),
                CircularProgressIndicator(color: Colors.white),
              ],
            );
          }

          final filteredTransactions = _applyFilters(snapshot.data!);

          double totalIncome = 0;
          double totalExpense = 0;

          for (var transaction in filteredTransactions) {
            if (transaction.type == 'income') {
              totalIncome += transaction.amount;
            } else {
              totalExpense += transaction.amount;
            }
          }

          double balance = totalIncome - totalExpense;

          return Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Balance',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                  if (_filter.hasActiveFilters)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Filtered',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '₹${balance.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildBalanceInfo('Income', totalIncome, Colors.green),
                  _buildBalanceInfo('Expense', totalExpense, Colors.red),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBalanceInfo(String label, double amount, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(
              label == 'Income' ? Icons.arrow_upward : Icons.arrow_downward,
              color: color,
              size: 16,
            ),
            const SizedBox(width: 4),
            Text(
              '₹${amount.toStringAsFixed(2)}',
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

Widget _buildTransactionTile(app_transaction.Transaction transaction) {
    final isIncome = transaction.type == 'income';
    final color = isIncome ? Colors.green : Colors.red;

    return Dismissible(
      key: Key(transaction.id),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      direction: DismissDirection.endToStart,
      onDismissed: (direction) {
        _firestoreService.deleteTransaction(transaction.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaction deleted')),
        );
      },
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: CategoryIcons.getColor(transaction.category).withOpacity(0.2),
          child: Icon(
            CategoryIcons.getIcon(transaction.category),
            color: CategoryIcons.getColor(transaction.category),
          ),
        ),
        title: Text(
          transaction.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${transaction.category} • ${DateFormat('dd MMM yyyy').format(transaction.date)}',
            ),
            if (transaction.notes != null && transaction.notes!.isNotEmpty)
              Text(
                transaction.notes!,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        trailing: Text(
          '${isIncome ? '+' : '-'}₹${transaction.amount.toStringAsFixed(2)}',
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
              builder: (context) => EditTransactionScreen(transaction: transaction),
            ),
          );
        },
      ),
    );
  }
}
