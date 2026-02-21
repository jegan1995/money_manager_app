import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../services/import_service.dart';

class ImportTransactionsScreen extends StatefulWidget {
  const ImportTransactionsScreen({super.key});

  @override
  State<ImportTransactionsScreen> createState() =>
      _ImportTransactionsScreenState();
}

class _ImportTransactionsScreenState extends State<ImportTransactionsScreen> {
  final ImportService _importService = ImportService();

  bool _isLoading = false;
  bool _isParsing = false;
  bool _isImporting = false;

  List<Map<String, dynamic>>? _parsedTransactions;
  String? _fileName;
  int _importProgress = 0;
  int _importTotal = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Import Transactions'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isImporting) {
      return _buildImportingProgress();
    }

    if (_parsedTransactions != null) {
      return _buildPreview();
    }

    return _buildFilePicker();
  }

  Widget _buildFilePicker() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.upload_file,
                size: 80,
                color: Colors.blue[400],
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Import from Excel',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              'Upload your Money Manager export file',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: _isParsing ? null : _pickFile,
              icon: _isParsing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.folder_open),
              label: Text(_isParsing ? 'Reading file...' : 'Choose Excel File'),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: Colors.blue[700], size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Required Format',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildFormatItem('Period', 'Date and time'),
                  _buildFormatItem('Accounts', 'Account name'),
                  _buildFormatItem('Category', 'Category name'),
                  _buildFormatItem('Subcategory', 'Subcategory (optional)'),
                  _buildFormatItem('Note', 'Note (optional)'),
                  _buildFormatItem('Description', 'Description (optional)'),
                  _buildFormatItem('INR', 'Amount'),
                  _buildFormatItem('Income/Expense', 'Transaction type'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormatItem(String field, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              field,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.blue[700],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            description,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    final total = _parsedTransactions!.length;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.description, color: Colors.blue[700]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _fileName ?? 'Excel File',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$total transactions found',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _parsedTransactions = null;
                        _fileName = null;
                      });
                    },
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Cancel'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _startImport,
                  icon: const Icon(Icons.upload),
                  label: Text('Import $total Transactions'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _parsedTransactions!.length > 50
                ? 50
                : _parsedTransactions!.length,
            itemBuilder: (context, index) {
              final txn = _parsedTransactions![index];
              return _buildPreviewCard(txn, index);
            },
          ),
        ),
        if (_parsedTransactions!.length > 50)
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.amber[50],
            child: Row(
              children: [
                Icon(Icons.info, color: Colors.amber[700], size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Showing first 50 transactions. All ${_parsedTransactions!.length} will be imported.',
                    style: TextStyle(
                      color: Colors.amber[900],
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildPreviewCard(Map<String, dynamic> txn, int index) {
    final amount = txn['amount'] ?? 0.0;
    final type = txn['type']?.toString().toLowerCase() ?? '';
    final isIncome = type.contains('income');

    DateTime date;
    try {
      date = DateTime.parse(txn['period']);
    } catch (e) {
      date = DateTime.now();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: CircleAvatar(
          backgroundColor: isIncome
              ? Colors.green.withOpacity(0.1)
              : Colors.red.withOpacity(0.1),
          child: Icon(
            isIncome ? Icons.arrow_downward : Icons.arrow_upward,
            color: isIncome ? Colors.green : Colors.red,
            size: 20,
          ),
        ),
        title: Text(
          txn['category'] ?? 'Unknown',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (txn['subcategory'] != null &&
                txn['subcategory'].toString().isNotEmpty)
              Text(
                txn['subcategory'],
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            Text(
              DateFormat('MMM d, yyyy h:mm a').format(date),
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
            if (txn['description'] != null &&
                txn['description'].toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  txn['description'],
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${isIncome ? '+' : '-'}₹${amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: isIncome ? Colors.green : Colors.red,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                txn['account'] ?? '',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[700],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImportingProgress() {
    final percentage =
        _importTotal > 0 ? (_importProgress / _importTotal * 100).toInt() : 0;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 120,
              height: 120,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: CircularProgressIndicator(
                      value: _importTotal > 0
                          ? _importProgress / _importTotal
                          : null,
                      strokeWidth: 8,
                      backgroundColor: Colors.grey[200],
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(Colors.blue),
                    ),
                  ),
                  Text(
                    '$percentage%',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Importing Transactions',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              '$_importProgress of $_importTotal',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                  const SizedBox(width: 12),
                  Text(
                    'Please wait, do not close this screen',
                    style: TextStyle(
                      color: Colors.blue[900],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFile() async {
    try {
      setState(() => _isParsing = true);

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        withData: true,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;

        // Check if bytes are available
        if (file.bytes == null) {
          throw Exception('Could not read file data');
        }

        _fileName = file.name;

        // Show loading message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 16),
                  Text('Reading Excel file...'),
                ],
              ),
              duration: Duration(seconds: 5),
            ),
          );
        }

        // Parse the Excel file
        final transactions = await _importService.parseExcelFile(
          file.bytes!,
        );

        if (mounted) {
          setState(() {
            _parsedTransactions = transactions;
            _isParsing = false;
          });

          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  Text('Found ${transactions.length} transactions'),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        setState(() => _isParsing = false);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No file selected'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isParsing = false);

      if (mounted) {
        print('Error picking file: $e'); // Debug log

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Error reading file',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  e.toString(),
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ),
          ),
        );
      }
    }
  }

  Future<void> _startImport() async {
    if (_parsedTransactions == null) return;

    setState(() {
      _isImporting = true;
      _importProgress = 0;
      _importTotal = _parsedTransactions!.length;
    });

    try {
      final result = await _importService.importTransactions(
        _parsedTransactions!,
        (current, total) {
          setState(() {
            _importProgress = current;
            _importTotal = total;
          });
        },
      );

      if (mounted) {
        Navigator.pop(context);

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green[600]),
                const SizedBox(width: 12),
                const Text('Import Complete'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildResultRow('Imported', result.imported, Colors.green),
                _buildResultRow('Skipped', result.skipped, Colors.orange),
                _buildResultRow('Errors', result.errors, Colors.red),
                if (result.errorMessages.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Error Details:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: result.errorMessages
                            .take(10)
                            .map((msg) => Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text(
                                    msg,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.red[700],
                                    ),
                                  ),
                                ))
                            .toList(),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isImporting = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Widget _buildResultRow(String label, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              count.toString(),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
