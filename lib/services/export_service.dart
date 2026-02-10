import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_html/html.dart' as html;
import '../models/transaction_model.dart';
import '../models/account_model.dart';

class ExportService {
  // Export to CSV
  Future<String?> exportTransactionsToCSV(
    List<TransactionModel> transactions,
    List<AccountModel> accounts, {
    bool includeTransfers = true,
    bool includeIncome = true,
    bool includeExpense = true,
  }) async {
    try {
      // Build account ID to name map
      final accountMap = <String, String>{};
      for (var account in accounts) {
        if (account.id != null) {
          accountMap[account.id!] = account.name;
        }
      }

      // Filter transactions
      final filtered = _filterTransactions(
        transactions,
        includeTransfers: includeTransfers,
        includeIncome: includeIncome,
        includeExpense: includeExpense,
      );

      // Create CSV data
      List<List<dynamic>> rows = [];
      
      // Add headers
      rows.add([
        'Date',
        'Time',
        'Type',
        'Category',
        'Subcategory',
        'Amount',
        'Payment Method',
        'From Account',
        'To Account',
        'Note',
      ]);

      // Add transaction data
      for (var txn in filtered) {
        rows.add([
          DateFormat('yyyy-MM-dd').format(txn.date),
          DateFormat('HH:mm').format(txn.date),
          txn.type,
          txn.category,
          txn.subcategory ?? '',
          txn.amount.toStringAsFixed(2),
          txn.paymentMethod ?? '',
          txn.fromAccount != null ? (accountMap[txn.fromAccount] ?? txn.fromAccount) : '',
          txn.toAccount != null ? (accountMap[txn.toAccount] ?? txn.toAccount) : '',
          txn.note ?? '',
        ]);
      }

      // Convert to CSV string
      String csv = const ListToCsvConverter().convert(rows);
      final filename = 'MoneyManager_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';

      if (kIsWeb) {
        // Web download
        _downloadFileWeb(csv, filename, 'text/csv');
        return filename;
      } else {
        // Mobile download
        final directory = await getApplicationDocumentsDirectory();
        final path = '${directory.path}/$filename';
        final file = File(path);
        await file.writeAsString(csv);
        return path;
      }
    } catch (e) {
      throw Exception('Failed to export CSV: $e');
    }
  }

  // Export to Excel
  Future<String?> exportTransactionsToExcel(
    List<TransactionModel> transactions,
    List<AccountModel> accounts, {
    bool includeTransfers = true,
    bool includeIncome = true,
    bool includeExpense = true,
  }) async {
    try {
      final filtered = _filterTransactions(
        transactions,
        includeTransfers: includeTransfers,
        includeIncome: includeIncome,
        includeExpense: includeExpense,
      );

      var excel = Excel.createExcel();
      excel.delete('Sheet1');

      // Create all sheets
      _createSummarySheet(excel, filtered, accounts);
      _createAllTransactionsSheet(excel, filtered, accounts);
      if (includeIncome) _createIncomeSheet(excel, filtered);
      if (includeExpense) _createExpenseSheet(excel, filtered);
      if (includeTransfers) _createTransfersSheet(excel, filtered, accounts);
      _createCategoryAnalysisSheet(excel, filtered);

      final filename = 'MoneyManager_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';
      final fileBytes = excel.save();

      if (fileBytes != null) {
        if (kIsWeb) {
          // Web download
          _downloadFileBytesWeb(fileBytes, filename, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
          return filename;
        } else {
          // Mobile download
          final directory = await getApplicationDocumentsDirectory();
          final path = '${directory.path}/$filename';
          File(path)
            ..createSync(recursive: true)
            ..writeAsBytesSync(fileBytes);
          return path;
        }
      }

      return null;
    } catch (e) {
      throw Exception('Failed to export Excel: $e');
    }
  }

  // Web download helper for text files
  void _downloadFileWeb(String content, String filename, String mimeType) {
    final bytes = utf8.encode(content);
    final blob = html.Blob([bytes], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  // Web download helper for binary files
  void _downloadFileBytesWeb(List<int> bytes, String filename, String mimeType) {
    final blob = html.Blob([bytes], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  // Create Summary Sheet
  void _createSummarySheet(Excel excel, List<TransactionModel> transactions, List<AccountModel> accounts) {
    var sheet = excel['Summary'];

    // Title
    sheet.merge(CellIndex.indexByString('A1'), CellIndex.indexByString('D1'));
    var titleCell = sheet.cell(CellIndex.indexByString('A1'));
    titleCell.value = TextCellValue('Money Manager - Financial Summary');
    titleCell.cellStyle = CellStyle(bold: true, fontSize: 16, horizontalAlign: HorizontalAlign.Center);

    sheet.cell(CellIndex.indexByString('A2')).value = 
        TextCellValue('Export Date: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}');

    // Statistics
    double totalIncome = 0, totalExpense = 0, totalTransfers = 0;
    for (var txn in transactions) {
      if (txn.type == 'income') totalIncome += txn.amount;
      if (txn.type == 'expense') totalExpense += txn.amount;
      if (txn.type == 'transfer') totalTransfers += txn.amount;
    }

    int row = 4;
    sheet.cell(CellIndex.indexByString('A$row')).value = TextCellValue('Category');
    sheet.cell(CellIndex.indexByString('B$row')).value = TextCellValue('Amount');
    sheet.cell(CellIndex.indexByString('C$row')).value = TextCellValue('Count');

    row++;
    sheet.cell(CellIndex.indexByString('A$row')).value = TextCellValue('Total Income');
    sheet.cell(CellIndex.indexByString('B$row')).value = TextCellValue('₹${totalIncome.toStringAsFixed(2)}');
    sheet.cell(CellIndex.indexByString('C$row')).value = IntCellValue(transactions.where((t) => t.type == 'income').length);

    row++;
    sheet.cell(CellIndex.indexByString('A$row')).value = TextCellValue('Total Expense');
    sheet.cell(CellIndex.indexByString('B$row')).value = TextCellValue('₹${totalExpense.toStringAsFixed(2)}');
    sheet.cell(CellIndex.indexByString('C$row')).value = IntCellValue(transactions.where((t) => t.type == 'expense').length);

    row++;
    sheet.cell(CellIndex.indexByString('A$row')).value = TextCellValue('Total Transfers');
    sheet.cell(CellIndex.indexByString('B$row')).value = TextCellValue('₹${totalTransfers.toStringAsFixed(2)}');
    sheet.cell(CellIndex.indexByString('C$row')).value = IntCellValue(transactions.where((t) => t.type == 'transfer').length);

    row++;
    sheet.cell(CellIndex.indexByString('A$row')).value = TextCellValue('Net Balance');
    sheet.cell(CellIndex.indexByString('B$row')).value = TextCellValue('₹${(totalIncome - totalExpense).toStringAsFixed(2)}');
    sheet.cell(CellIndex.indexByString('C$row')).value = TextCellValue('-');

    row += 2;
    sheet.cell(CellIndex.indexByString('A$row')).value = TextCellValue('Account Balances');
    row++;
    sheet.cell(CellIndex.indexByString('A$row')).value = TextCellValue('Account Name');
    sheet.cell(CellIndex.indexByString('B$row')).value = TextCellValue('Balance');
    sheet.cell(CellIndex.indexByString('C$row')).value = TextCellValue('Type');

    for (var account in accounts) {
      row++;
      sheet.cell(CellIndex.indexByString('A$row')).value = TextCellValue(account.name);
      sheet.cell(CellIndex.indexByString('B$row')).value = TextCellValue('₹${account.balance.toStringAsFixed(2)}');
      sheet.cell(CellIndex.indexByString('C$row')).value = TextCellValue(account.type);
    }
  }

  void _createAllTransactionsSheet(Excel excel, List<TransactionModel> transactions, List<AccountModel> accounts) {
    var sheet = excel['All Transactions'];
    
    // Build account map
    final accountMap = <String, String>{};
    for (var account in accounts) {
      if (account.id != null) {
        accountMap[account.id!] = account.name;
      }
    }
    
    var headers = ['Date', 'Time', 'Type', 'Category', 'Subcategory', 'Amount', 'Payment', 'From', 'To', 'Note'];
    for (int i = 0; i < headers.length; i++) {
      var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = CellStyle(bold: true);
    }
    for (int i = 0; i < transactions.length; i++) {
      var txn = transactions[i];
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: i + 1)).value = TextCellValue(DateFormat('yyyy-MM-dd').format(txn.date));
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: i + 1)).value = TextCellValue(DateFormat('HH:mm').format(txn.date));
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: i + 1)).value = TextCellValue(txn.type);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: i + 1)).value = TextCellValue(txn.category);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: i + 1)).value = TextCellValue(txn.subcategory ?? '');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: i + 1)).value = TextCellValue(txn.amount.toStringAsFixed(2));
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: i + 1)).value = TextCellValue(txn.paymentMethod ?? '');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: i + 1)).value = TextCellValue(txn.fromAccount != null ? (accountMap[txn.fromAccount] ?? txn.fromAccount!) : '');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: i + 1)).value = TextCellValue(txn.toAccount != null ? (accountMap[txn.toAccount] ?? txn.toAccount!) : '');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: i + 1)).value = TextCellValue(txn.note ?? '');
    }
  }

  void _createIncomeSheet(Excel excel, List<TransactionModel> transactions) {
    var incomeTransactions = transactions.where((t) => t.type == 'income').toList();
    var sheet = excel['Income'];
    var headers = ['Date', 'Category', 'Subcategory', 'Amount', 'Note'];
    for (int i = 0; i < headers.length; i++) {
      var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = CellStyle(bold: true);
    }
    for (int i = 0; i < incomeTransactions.length; i++) {
      var txn = incomeTransactions[i];
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: i + 1)).value = TextCellValue(DateFormat('yyyy-MM-dd').format(txn.date));
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: i + 1)).value = TextCellValue(txn.category);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: i + 1)).value = TextCellValue(txn.subcategory ?? '');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: i + 1)).value = TextCellValue(txn.amount.toStringAsFixed(2));
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: i + 1)).value = TextCellValue(txn.note ?? '');
    }
  }

  void _createExpenseSheet(Excel excel, List<TransactionModel> transactions) {
    var expenseTransactions = transactions.where((t) => t.type == 'expense').toList();
    var sheet = excel['Expenses'];
    var headers = ['Date', 'Category', 'Subcategory', 'Amount', 'Payment', 'Note'];
    for (int i = 0; i < headers.length; i++) {
      var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = CellStyle(bold: true);
    }
    for (int i = 0; i < expenseTransactions.length; i++) {
      var txn = expenseTransactions[i];
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: i + 1)).value = TextCellValue(DateFormat('yyyy-MM-dd').format(txn.date));
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: i + 1)).value = TextCellValue(txn.category);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: i + 1)).value = TextCellValue(txn.subcategory ?? '');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: i + 1)).value = TextCellValue(txn.amount.toStringAsFixed(2));
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: i + 1)).value = TextCellValue(txn.paymentMethod ?? '');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: i + 1)).value = TextCellValue(txn.note ?? '');
    }
  }

  void _createTransfersSheet(Excel excel, List<TransactionModel> transactions, List<AccountModel> accounts) {
    var transferTransactions = transactions.where((t) => t.type == 'transfer').toList();
    var sheet = excel['Transfers'];
    
    // Build account map
    final accountMap = <String, String>{};
    for (var account in accounts) {
      if (account.id != null) {
        accountMap[account.id!] = account.name;
      }
    }
    
    var headers = ['Date', 'Amount', 'From Account', 'To Account', 'Note'];
    for (int i = 0; i < headers.length; i++) {
      var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = CellStyle(bold: true);
    }
    for (int i = 0; i < transferTransactions.length; i++) {
      var txn = transferTransactions[i];
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: i + 1)).value = TextCellValue(DateFormat('yyyy-MM-dd').format(txn.date));
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: i + 1)).value = TextCellValue(txn.amount.toStringAsFixed(2));
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: i + 1)).value = TextCellValue(txn.fromAccount != null ? (accountMap[txn.fromAccount] ?? txn.fromAccount!) : '');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: i + 1)).value = TextCellValue(txn.toAccount != null ? (accountMap[txn.toAccount] ?? txn.toAccount!) : '');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: i + 1)).value = TextCellValue(txn.note ?? '');
    }
  }

  void _createCategoryAnalysisSheet(Excel excel, List<TransactionModel> transactions) {
    var sheet = excel['Category Analysis'];
    Map<String, double> categoryTotals = {};
    for (var txn in transactions.where((t) => t.type == 'expense')) {
      categoryTotals[txn.category] = (categoryTotals[txn.category] ?? 0) + txn.amount;
    }
    var sortedCategories = categoryTotals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    sheet.cell(CellIndex.indexByString('A1')).value = TextCellValue('Category');
    sheet.cell(CellIndex.indexByString('B1')).value = TextCellValue('Total Amount');
    sheet.cell(CellIndex.indexByString('C1')).value = TextCellValue('Percentage');

    double total = sortedCategories.fold(0, (sum, e) => sum + e.value);
    for (int i = 0; i < sortedCategories.length; i++) {
      var entry = sortedCategories[i];
      double percentage = (entry.value / total) * 100;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: i + 1)).value = TextCellValue(entry.key);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: i + 1)).value = TextCellValue('₹${entry.value.toStringAsFixed(2)}');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: i + 1)).value = TextCellValue('${percentage.toStringAsFixed(1)}%');
    }
  }

  List<TransactionModel> _filterTransactions(
    List<TransactionModel> transactions, {
    required bool includeTransfers,
    required bool includeIncome,
    required bool includeExpense,
  }) {
    return transactions.where((txn) {
      if (txn.type == 'transfer' && !includeTransfers) return false;
      if (txn.type == 'income' && !includeIncome) return false;
      if (txn.type == 'expense' && !includeExpense) return false;
      return true;
    }).toList();
  }

  Future<void> shareFile(String filePath, String fileName) async {
    if (kIsWeb) {
      // File already downloaded in browser
      return;
    }
    try {
      await Share.shareXFiles([XFile(filePath)], text: 'Money Manager Export - $fileName');
    } catch (e) {
      throw Exception('Failed to share file: $e');
    }
  }
}