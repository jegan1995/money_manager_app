import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction_model.dart';
import '../models/account_model.dart';
import '../services/transaction_service.dart';
import '../services/account_service.dart';
import '../services/export_service.dart';

class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  final TransactionService _transactionService = TransactionService();
  final AccountService _accountService = AccountService();
  final ExportService _exportService = ExportService();

  DateTime? _startDate;
  DateTime? _endDate;
  bool _includeIncome = true;
  bool _includeExpense = true;
  bool _includeTransfers = true;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    // Default to current month
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, 1);
    _endDate = now;
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  Future<List<TransactionModel>> _getFilteredTransactions() async {
    final allTransactions = await _transactionService.getTransactionsList();
    
    return allTransactions.where((txn) {
      // Date filter
      if (_startDate != null && txn.date.isBefore(_startDate!)) return false;
      if (_endDate != null && txn.date.isAfter(_endDate!.add(const Duration(days: 1)))) return false;
      
      return true;
    }).toList();
  }

  Future<void> _exportToCSV() async {
    setState(() => _isExporting = true);

    try {
      final transactions = await _getFilteredTransactions();
      final accounts = await _accountService.getAccountsList().first;
      
      if (transactions.isEmpty) {
        _showMessage('No transactions to export', isError: true);
        return;
      }

      final filePath = await _exportService.exportTransactionsToCSV(
        transactions,
        accounts,
        includeIncome: _includeIncome,
        includeExpense: _includeExpense,
        includeTransfers: _includeTransfers,
      );

      if (filePath != null && mounted) {
        _showExportSuccess(filePath, 'CSV', transactions.length);
      }
    } catch (e) {
      _showMessage('Export failed: $e', isError: true);
    } finally {
      setState(() => _isExporting = false);
    }
  }

  Future<void> _exportToExcel() async {
    setState(() => _isExporting = true);

    try {
      final transactions = await _getFilteredTransactions();
      final accounts = await _accountService.getAccountsList().first;
      
      if (transactions.isEmpty) {
        _showMessage('No transactions to export', isError: true);
        return;
      }

      final filePath = await _exportService.exportTransactionsToExcel(
        transactions,
        accounts,
        includeIncome: _includeIncome,
        includeExpense: _includeExpense,
        includeTransfers: _includeTransfers,
      );

      if (filePath != null && mounted) {
        _showExportSuccess(filePath, 'Excel', transactions.length);
      }
    } catch (e) {
      _showMessage('Export failed: $e', isError: true);
    } finally {
      setState(() => _isExporting = false);
    }
  }

  void _showExportSuccess(String filePath, String format, int count) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 28),
            const SizedBox(width: 12),
            const Text('Export Successful'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Exported $count transactions to $format'),
            const SizedBox(height: 16),
            Text(
              'File saved to:\n${filePath.split('/').last}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              await _exportService.shareFile(filePath, filePath.split('/').last);
            },
            icon: const Icon(Icons.share),
            label: const Text('Share'),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Export & Backup'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Info Card
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Export your transactions to CSV or Excel format',
                        style: TextStyle(color: Colors.blue.shade900),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Date Range Section
            Text(
              'Date Range',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.calendar_today, color: Colors.blue),
                title: Text(
                  _startDate != null && _endDate != null
                      ? '${DateFormat('MMM d, yyyy').format(_startDate!)} - ${DateFormat('MMM d, yyyy').format(_endDate!)}'
                      : 'Select date range',
                ),
                subtitle: const Text('Tap to change'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: _selectDateRange,
              ),
            ),
            const SizedBox(height: 24),

            // Quick Date Presets
            Text(
              'Quick Filters',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildQuickFilter('This Month', () {
                  final now = DateTime.now();
                  setState(() {
                    _startDate = DateTime(now.year, now.month, 1);
                    _endDate = now;
                  });
                }),
                _buildQuickFilter('Last Month', () {
                  final now = DateTime.now();
                  final lastMonth = DateTime(now.year, now.month - 1, 1);
                  setState(() {
                    _startDate = lastMonth;
                    _endDate = DateTime(now.year, now.month, 1).subtract(const Duration(days: 1));
                  });
                }),
                _buildQuickFilter('This Year', () {
                  final now = DateTime.now();
                  setState(() {
                    _startDate = DateTime(now.year, 1, 1);
                    _endDate = now;
                  });
                }),
                _buildQuickFilter('All Time', () {
                  setState(() {
                    _startDate = null;
                    _endDate = null;
                  });
                }),
              ],
            ),
            const SizedBox(height: 24),

            // Transaction Types
            Text(
              'Include Transaction Types',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  CheckboxListTile(
                    title: const Text('Income'),
                    secondary: const Icon(Icons.arrow_downward, color: Colors.green),
                    value: _includeIncome,
                    onChanged: (value) => setState(() => _includeIncome = value ?? true),
                  ),
                  const Divider(height: 1),
                  CheckboxListTile(
                    title: const Text('Expenses'),
                    secondary: const Icon(Icons.arrow_upward, color: Colors.red),
                    value: _includeExpense,
                    onChanged: (value) => setState(() => _includeExpense = value ?? true),
                  ),
                  const Divider(height: 1),
                  CheckboxListTile(
                    title: const Text('Transfers'),
                    secondary: const Icon(Icons.swap_horiz, color: Colors.blue),
                    value: _includeTransfers,
                    onChanged: (value) => setState(() => _includeTransfers = value ?? true),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Export Preview
            FutureBuilder<List<TransactionModel>>(
              future: _getFilteredTransactions(),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  final filtered = snapshot.data!.where((txn) {
                    if (txn.type == 'income' && !_includeIncome) return false;
                    if (txn.type == 'expense' && !_includeExpense) return false;
                    if (txn.type == 'transfer' && !_includeTransfers) return false;
                    return true;
                  }).toList();

                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.preview, size: 48, color: Colors.grey),
                        const SizedBox(height: 12),
                        Text(
                          '${filtered.length} Transactions',
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        const Text('will be exported', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            const SizedBox(height: 24),

            // Export Buttons
            ElevatedButton.icon(
              onPressed: _isExporting ? null : _exportToExcel,
              icon: _isExporting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.table_chart),
              label: Text(_isExporting ? 'Exporting...' : 'Export to Excel'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _isExporting ? null : _exportToCSV,
              icon: const Icon(Icons.file_present),
              label: const Text('Export to CSV'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickFilter(String label, VoidCallback onTap) {
    return FilterChip(
      label: Text(label),
      onSelected: (_) => onTap(),
      backgroundColor: Colors.grey.shade200,
    );
  }
}