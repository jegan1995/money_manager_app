import 'dart:io';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/transaction_model.dart';

class ExportService {
  Future<String?> exportTransactionsToCSV(
      List<TransactionModel> transactions) async {
    try {
      // Create CSV data
      List<List<dynamic>> rows = [];

      // Add headers
      rows.add([
        'Date',
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
      for (var txn in transactions) {
        rows.add([
          DateFormat('yyyy-MM-dd HH:mm').format(txn.date),
          txn.type,
          txn.category,
          txn.subcategory ?? '',
          txn.amount.toStringAsFixed(2),
          txn.paymentMethod ?? '',
          txn.fromAccount ?? '',
          txn.toAccount ?? '',
          txn.note ?? '',
        ]);
      }

      // Convert to CSV string
      String csv = const ListToCsvConverter().convert(rows);

      // Save to file
      final directory = await getApplicationDocumentsDirectory();
      final path =
          '${directory.path}/transactions_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
      final file = File(path);
      await file.writeAsString(csv);

      return path;
    } catch (e) {
      throw Exception('Failed to export CSV: $e');
    }
  }

  Future<void> shareCSV(String filePath) async {
    try {
      await Share.shareXFiles([XFile(filePath)],
          text: 'Money Manager Transactions Export');
    } catch (e) {
      throw Exception('Failed to share CSV: $e');
    }
  }
}
