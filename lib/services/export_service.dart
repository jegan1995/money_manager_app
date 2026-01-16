import 'dart:io';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../models/transaction.dart' as app_transaction;

class ExportService {
  Future<String> exportToCSV(List<app_transaction.Transaction> transactions) async {
    List<List<dynamic>> rows = [];
    
    // Add headers
    rows.add(['Date', 'Title', 'Category', 'Type', 'Amount', 'Notes']);
    
    // Add transaction data
    for (var transaction in transactions) {
      rows.add([
        DateFormat('dd/MM/yyyy').format(transaction.date),
        transaction.title,
        transaction.category,
        transaction.type,
        transaction.amount.toString(),
        transaction.notes ?? '',
      ]);
    }
    
    // Convert to CSV
    String csv = const ListToCsvConverter().convert(rows);
    
    // Save to file
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/transactions_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
    final file = File(path);
    await file.writeAsString(csv);
    
    return path;
  }
}
