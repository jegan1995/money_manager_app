import 'package:excel/excel.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/transaction_model.dart';
import '../models/account_model.dart';
import 'account_service.dart';
import 'transaction_service.dart';

class ImportService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AccountService _accountService = AccountService();
  final TransactionService _transactionService = TransactionService();

  String? get _currentUserId => _auth.currentUser?.uid;

  // Parse Excel file and return list of transactions
  Future<List<Map<String, dynamic>>> parseExcelFile(List<int> bytes) async {
    try {
      print('Starting to parse Excel file...');
      final excel = Excel.decodeBytes(bytes);
      print('Excel decoded successfully');

      if (excel.tables.isEmpty) {
        throw Exception('No sheets found in Excel file');
      }

      final sheet = excel.tables.keys.first;
      print('Sheet name: $sheet');

      final table = excel.tables[sheet];

      if (table == null || table.rows.isEmpty) {
        throw Exception('Excel sheet is empty');
      }

      print('Total rows: ${table.rows.length}');

      // Get headers from first row
      final headers = table.rows.first
          .map((cell) => cell?.value?.toString() ?? '')
          .toList();

      print('Headers: $headers');

      // Map column indices
      final periodIndex = headers.indexOf('Period');
      final accountsIndex = headers.indexOf('Accounts');
      final categoryIndex = headers.indexOf('Category');
      final subcategoryIndex = headers.indexOf('Subcategory');
      final noteIndex = headers.indexOf('Note');
      final descriptionIndex = headers.indexOf('Description');
      final typeIndex = headers.indexOf('Income/Expense');

      // Try both 'Amount' and 'INR' columns
      int amountIndex = headers.indexOf('Amount');
      if (amountIndex == -1) {
        amountIndex = headers.indexOf('INR');
      }

      print('Column indices:');
      print('  Period: $periodIndex');
      print('  Accounts: $accountsIndex');
      print('  Category: $categoryIndex');
      print('  Amount: $amountIndex');
      print('  Type: $typeIndex');

      if (periodIndex == -1 ||
          accountsIndex == -1 ||
          categoryIndex == -1 ||
          amountIndex == -1) {
        throw Exception(
            'Required columns not found. Make sure Excel has: Period, Accounts, Category, Amount (or INR)');
      }

      List<Map<String, dynamic>> transactions = [];

      // Skip header row
      for (int i = 1; i < table.rows.length; i++) {
        final row = table.rows[i];

        try {
          // Get the amount - use toString and parse
          double? amount;
          final amountCell = row[amountIndex];

          if (amountCell?.value != null) {
            // Convert cell value to string and parse
            final valueStr = amountCell!.value.toString();

            if (i <= 3) {
              print('Row $i - Raw value: $valueStr');
            }

            // Clean and parse
            final cleaned = valueStr
                .replaceAll(',', '')
                .replaceAll('₹', '')
                .replaceAll('INR', '')
                .trim();

            amount = double.tryParse(cleaned)?.abs();
          }

          // Debug first few rows
          if (i <= 3) {
            print('Row $i:');
            print('  Period: ${row[periodIndex]?.value}');
            print('  Account: ${row[accountsIndex]?.value}');
            print('  Category: ${row[categoryIndex]?.value}');
            print('  Amount: $amount');
            print('  Type: ${row[typeIndex]?.value}');
          }

          // Only add if amount is not null and greater than zero
          if (amount != null && amount > 0) {
            final Map<String, dynamic> txn = {
              'period': row[periodIndex]?.value?.toString(),
              'account': row[accountsIndex]?.value?.toString()?.trim(),
              'category': row[categoryIndex]?.value?.toString()?.trim(),
              'subcategory': subcategoryIndex != -1
                  ? row[subcategoryIndex]?.value?.toString()?.trim()
                  : null,
              'note': noteIndex != -1
                  ? row[noteIndex]?.value?.toString()?.trim()
                  : null,
              'description': descriptionIndex != -1
                  ? row[descriptionIndex]?.value?.toString()?.trim()
                  : null,
              'amount': amount,
              'type': row[typeIndex]?.value?.toString()?.trim(),
            };
            transactions.add(txn);
          } else {
            if (i <= 3) {
              print('  Skipped (amount is $amount)');
            }
          }
        } catch (e) {
          print('Error parsing row $i: $e');
          continue;
        }
      }

      print('Total transactions parsed: ${transactions.length}');
      return transactions;
    } catch (e) {
      print('Excel parsing error: $e');
      throw Exception('Failed to parse Excel file: $e');
    }
  }

  // Get or create account by name
  Future<String> getOrCreateAccount(String accountName) async {
    if (_currentUserId == null) throw Exception('User not logged in');

    // Check if account exists
    final snapshot = await _firestore
        .collection('accounts')
        .where('userId', isEqualTo: _currentUserId)
        .where('name', isEqualTo: accountName)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      return snapshot.docs.first.id;
    }

    // Create new account
    final account = AccountModel(
      userId: _currentUserId!,
      name: accountName,
      type: _guessAccountType(accountName),
      balance: 0,
      createdAt: DateTime.now(),
    );

    final docRef = await _firestore.collection('accounts').add(account.toMap());
    return docRef.id;
  }

  String _guessAccountType(String accountName) {
    final lower = accountName.toLowerCase();
    if (lower.contains('cash')) return 'cash';
    if (lower.contains('cc') || lower.contains('credit')) return 'credit_card';
    if (lower.contains('loan')) return 'loan';
    return 'bank';
  }

  // Detect if transaction is a transfer
  bool _isTransfer(String category, List<String> accountNames) {
    return accountNames
        .any((name) => name.toLowerCase() == category.toLowerCase());
  }

  // Import transactions with progress callback
  Future<ImportResult> importTransactions(
    List<Map<String, dynamic>> rawTransactions,
    Function(int current, int total) onProgress,
  ) async {
    if (_currentUserId == null) throw Exception('User not logged in');

    int imported = 0;
    int skipped = 0;
    int errors = 0;
    List<String> errorMessages = [];

    // Get all accounts first
    final accountsSnapshot = await _firestore
        .collection('accounts')
        .where('userId', isEqualTo: _currentUserId)
        .get();

    final accountNames = accountsSnapshot.docs
        .map((doc) => AccountModel.fromFirestore(doc).name)
        .toList();

    // Track transfers to avoid duplicates
    Set<String> processedTransfers = {};

    for (int i = 0; i < rawTransactions.length; i++) {
      try {
        final raw = rawTransactions[i];
        onProgress(i + 1, rawTransactions.length);

        // Parse date
        DateTime date;
        try {
          date = DateTime.parse(raw['period']);
        } catch (e) {
          date = DateTime.now();
        }

        final category = raw['category'] ?? '';
        final accountName = raw['account'] ?? '';
        final amount = raw['amount'] ?? 0.0;

        // Check if it's a transfer
        if (_isTransfer(category, accountNames)) {
          // Create transfer key to avoid duplicates
          final transferKey =
              '${date.millisecondsSinceEpoch}_${accountName}_$category$amount';

          if (processedTransfers.contains(transferKey)) {
            skipped++;
            continue;
          }
          processedTransfers.add(transferKey);

          // Get account IDs
          final fromAccountId = await getOrCreateAccount(accountName);
          final toAccountId = await getOrCreateAccount(category);

          // Create transfer transaction
          final transfer = TransactionModel(
            id: '',
            userId: _currentUserId!,
            type: 'transfer',
            category: 'Transfer',
            subcategory: null,
            amount: amount,
            date: date,
            note: raw['note'],
            description: raw['description'],
            fromAccount: fromAccountId,
            toAccount: toAccountId,
            createdAt: DateTime.now(),
          );

          await _transactionService.addTransaction(transfer);
          imported++;
        } else {
          // Regular income/expense transaction
          final accountId = await getOrCreateAccount(accountName);

          // Determine type
          String type = 'expense';
          if (raw['type'] != null) {
            final typeStr = raw['type'].toString().toLowerCase();
            if (typeStr.contains('income')) {
              type = 'income';
            }
          }

          final transaction = TransactionModel(
            id: '',
            userId: _currentUserId!,
            type: type,
            category: category,
            subcategory:
                raw['subcategory']?.isEmpty == true ? null : raw['subcategory'],
            amount: amount,
            date: date,
            note: raw['note']?.isEmpty == true ? null : raw['note'],
            description:
                raw['description']?.isEmpty == true ? null : raw['description'],
            fromAccount: accountId,
            toAccount: null,
            createdAt: DateTime.now(),
          );

          await _transactionService.addTransaction(transaction);
          imported++;
        }
      } catch (e) {
        errors++;
        errorMessages.add('Row ${i + 1}: $e');
        print('Error importing row ${i + 1}: $e');
      }
    }

    return ImportResult(
      imported: imported,
      skipped: skipped,
      errors: errors,
      errorMessages: errorMessages,
    );
  }
}

class ImportResult {
  final int imported;
  final int skipped;
  final int errors;
  final List<String> errorMessages;

  ImportResult({
    required this.imported,
    required this.skipped,
    required this.errors,
    required this.errorMessages,
  });
}
