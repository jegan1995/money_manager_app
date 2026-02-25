import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:universal_html/html.dart' as html;
import '../models/transaction_model.dart';
import '../models/account_model.dart';

class PdfReportService {
  // ── Generate, preview in-app ───────────────────────────────────────────────
  static Future<void> previewPdf({
    required List<TransactionModel> transactions,
    required List<AccountModel> accounts,
    required DateTime month,
    required String userName,
  }) async {
    await Printing.layoutPdf(
      onLayout: (_) async => _buildPdf(
        transactions: transactions,
        accounts: accounts,
        month: month,
        userName: userName,
      ),
      name: 'MoneyManager_${DateFormat('MMM_yyyy').format(month)}_Report',
    );
  }

  // ── Generate and share/download ────────────────────────────────────────────
  static Future<void> generateAndShare({
    required List<TransactionModel> transactions,
    required List<AccountModel> accounts,
    required DateTime month,
    required String userName,
  }) async {
    final pdfBytes = await _buildPdf(
      transactions: transactions,
      accounts: accounts,
      month: month,
      userName: userName,
    );
    final filename =
        'MoneyManager_${DateFormat('MMM_yyyy').format(month)}_Report.pdf';

    if (kIsWeb) {
      final blob = html.Blob([pdfBytes], 'application/pdf');
      final url  = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', filename)
        ..click();
      html.Url.revokeObjectUrl(url);
    } else {
      final dir  = await getTemporaryDirectory();
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(pdfBytes);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/pdf')],
        subject:
            'Money Manager — ${DateFormat('MMMM yyyy').format(month)} Report',
      );
    }
  }

  // ── Core PDF builder ───────────────────────────────────────────────────────
  static Future<Uint8List> _buildPdf({
    required List<TransactionModel> transactions,
    required List<AccountModel> accounts,
    required DateTime month,
    required String userName,
  }) async {
    final pdf = pw.Document();

    // Filter to selected month
    final monthTxns = transactions
        .where((t) =>
            t.date.year == month.year && t.date.month == month.month)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final expenses     = monthTxns.where((t) => t.type == 'expense').toList();
    final income       = monthTxns.where((t) => t.type == 'income').toList();
    final totalIncome  = income.fold(0.0,   (s, t) => s + t.amount);
    final totalExpense = expenses.fold(0.0, (s, t) => s + t.amount);
    final netSavings   = totalIncome - totalExpense;

    // Category map
    final catMap = <String, double>{};
    for (final t in expenses) {
      catMap[t.category] = (catMap[t.category] ?? 0) + t.amount;
    }
    final sortedCats = catMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final monthLabel   = DateFormat('MMMM yyyy').format(month);
    final generatedOn  = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());

    // Colors
    const primary    = PdfColor.fromInt(0xFF1565C0);
    const green      = PdfColor.fromInt(0xFF2E7D32);
    const red        = PdfColor.fromInt(0xFFC62828);
    const greyText   = PdfColor.fromInt(0xFF757575);
    const darkText   = PdfColor.fromInt(0xFF212121);
    const divider    = PdfColor.fromInt(0xFFE0E0E0);
    const lightBg    = PdfColor.fromInt(0xFFF5F6FA);

    // ── Page 1: Summary ───────────────────────────────────────────────────────
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      header: (_) => _header(monthLabel, userName, primary, greyText),
      footer: (ctx) => _footer(ctx, generatedOn, greyText),
      build: (_) => [
        pw.SizedBox(height: 10),

        // Summary cards
        pw.Row(children: [
          _card('Total Income',  _fmt(totalIncome),  green, '↑'),
          pw.SizedBox(width: 10),
          _card('Total Expense', _fmt(totalExpense), red,   '↓'),
          pw.SizedBox(width: 10),
          _card('Net Savings',   _fmt(netSavings),
              netSavings >= 0 ? green : red,
              netSavings >= 0 ? '✓' : '!'),
        ]),

        pw.SizedBox(height: 16),

        // Savings rate banner
        if (totalIncome > 0)
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: netSavings >= 0 ? lightBg : PdfColor.fromInt(0xFFFFF8E1),
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(
                  color: netSavings >= 0 ? green : red, width: 0.5),
            ),
            child: pw.Text(
              'Savings Rate: ${(netSavings / totalIncome * 100).toStringAsFixed(1)}%  •  '
              '${netSavings >= 0 ? 'You saved' : 'Overspent by'} ${_fmt(netSavings.abs())} this month  •  '
              '${monthTxns.length} transactions recorded',
              style: pw.TextStyle(
                  fontSize: 10,
                  color: netSavings >= 0 ? green : red),
            ),
          ),

        pw.SizedBox(height: 20),

        // Category breakdown
        if (sortedCats.isNotEmpty) ...[
          _sectionTitle('Expense by Category', red),
          pw.SizedBox(height: 10),
          ...sortedCats.take(12).map((e) {
            final pct = totalExpense > 0 ? (e.value / totalExpense) : 0.0;
            return pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 9),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(e.key,
                          style: pw.TextStyle(fontSize: 10, color: darkText)),
                      pw.Text(
                        '${_fmt(e.value)}   ${(pct * 100).toStringAsFixed(1)}%',
                        style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: red),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 3),
                  pw.LayoutBuilder(
                    builder: (ctx, constraints) {
                      final totalW = constraints.maxWidth;
                      final fillW  = (totalW * pct.clamp(0.01, 1.0));
                      return pw.Stack(children: [
                        pw.Container(
                          width: totalW, height: 7,
                          decoration: pw.BoxDecoration(
                              color: divider,
                              borderRadius: pw.BorderRadius.circular(4))),
                        pw.Container(
                          width: fillW, height: 7,
                          decoration: pw.BoxDecoration(
                              color: red,
                              borderRadius: pw.BorderRadius.circular(4))),
                      ]);
                    },
                  ),
                ],
              ),
            );
          }),
        ],

        pw.SizedBox(height: 20),

        // Account balances
        if (accounts.isNotEmpty) ...[
          _sectionTitle('Account Balances', primary),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: divider, width: 0.5),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: primary),
                children: [
                  _th('Account', PdfColors.white),
                  _th('Type',    PdfColors.white),
                  _th('Balance', PdfColors.white),
                ],
              ),
              ...accounts.map((a) => pw.TableRow(children: [
                    _td(a.name),
                    _td(a.typeDisplayName),
                    _td(_fmt(a.balance),
                        color: a.balance >= 0 ? green : red,
                        bold: true),
                  ])),
            ],
          ),
        ],
      ],
    ));

    // ── Page 2: Transactions ───────────────────────────────────────────────────
    if (monthTxns.isNotEmpty) {
      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (_) =>
            _header('$monthLabel — Transactions', userName, primary, greyText),
        footer: (ctx) => _footer(ctx, generatedOn, greyText),
        build: (_) => [
          pw.SizedBox(height: 10),

          if (income.isNotEmpty) ...[
            _sectionTitle('Income  (${income.length} entries)', green),
            pw.SizedBox(height: 6),
            _txnTable(income, green, divider, greyText),
            pw.SizedBox(height: 4),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text('Total: ${_fmt(totalIncome)}',
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      color: green,
                      fontSize: 11)),
            ),
            pw.SizedBox(height: 20),
          ],

          if (expenses.isNotEmpty) ...[
            _sectionTitle('Expenses  (${expenses.length} entries)', red),
            pw.SizedBox(height: 6),
            _txnTable(expenses, red, divider, greyText),
            pw.SizedBox(height: 4),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text('Total: ${_fmt(totalExpense)}',
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      color: red,
                      fontSize: 11)),
            ),
          ],
        ],
      ));
    }

    return pdf.save();
  }

  // ── Reusable widgets ───────────────────────────────────────────────────────
  static pw.Widget _header(String title, String user,
      PdfColor primary, PdfColor grey) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
            bottom: pw.BorderSide(
                color: PdfColor.fromInt(0xFF1565C0), width: 2)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Money Manager',
                  style: pw.TextStyle(
                      fontSize: 15,
                      fontWeight: pw.FontWeight.bold,
                      color: primary)),
              pw.Text(title,
                  style: pw.TextStyle(fontSize: 10, color: grey)),
            ],
          ),
          pw.Text(user,
              style: pw.TextStyle(fontSize: 9, color: grey)),
        ],
      ),
    );
  }

  static pw.Widget _footer(
      pw.Context ctx, String generatedOn, PdfColor grey) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: const pw.BoxDecoration(
          border: pw.Border(
              top: pw.BorderSide(
                  color: PdfColor.fromInt(0xFFE0E0E0), width: 0.5))),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Generated: $generatedOn',
              style: pw.TextStyle(fontSize: 7, color: grey)),
          pw.Text('Page ${ctx.pageNumber} / ${ctx.pagesCount}',
              style: pw.TextStyle(fontSize: 7, color: grey)),
        ],
      ),
    );
  }

  static pw.Widget _card(
      String label, String value, PdfColor color, String icon) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: PdfColor(color.red, color.green, color.blue, 0.06),
          borderRadius: pw.BorderRadius.circular(8),
          border: pw.Border.all(color: color, width: 0.8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('$icon  $label',
                style: pw.TextStyle(fontSize: 9, color: color)),
            pw.SizedBox(height: 5),
            pw.Text(value,
                style: pw.TextStyle(
                    fontSize: 15,
                    fontWeight: pw.FontWeight.bold,
                    color: color)),
          ],
        ),
      ),
    );
  }

  static pw.Widget _sectionTitle(String title, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 8),
      decoration: pw.BoxDecoration(
        color: PdfColor(color.red, color.green, color.blue, 0.07),
        borderRadius: pw.BorderRadius.circular(4),
        border: pw.Border(left: pw.BorderSide(color: color, width: 3)),
      ),
      child: pw.Text(title,
          style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: color)),
    );
  }

  static pw.Widget _txnTable(List<TransactionModel> txns,
      PdfColor accent, PdfColor divider, PdfColor grey) {
    return pw.Table(
      border: pw.TableBorder.all(color: divider, width: 0.4),
      columnWidths: {
        0: const pw.FlexColumnWidth(1.4),
        1: const pw.FlexColumnWidth(2),
        2: const pw.FlexColumnWidth(3),
        3: const pw.FlexColumnWidth(1.6),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(
              color: PdfColor(accent.red, accent.green, accent.blue, 0.12)),
          children: [
            _th('Date',     accent),
            _th('Category', accent),
            _th('Note',     accent),
            _th('Amount',   accent),
          ],
        ),
        ...txns.asMap().entries.map((entry) {
          final even = entry.key % 2 == 0;
          final t    = entry.value;
          return pw.TableRow(
            decoration: pw.BoxDecoration(
                color: even
                    ? PdfColors.white
                    : const PdfColor.fromInt(0xFFFAFAFA)),
            children: [
              _td(DateFormat('dd MMM').format(t.date)),
              _td(t.subcategory != null
                  ? '${t.category} / ${t.subcategory}'
                  : t.category),
              _td(t.note ?? t.description ?? '—', color: grey),
              _td(_fmt(t.amount), color: accent, bold: true),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _th(String text, PdfColor color) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        child: pw.Text(text,
            style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: color)),
      );

  static pw.Widget _td(String text,
          {PdfColor? color, bool bold = false}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        child: pw.Text(text,
            style: pw.TextStyle(
                fontSize: 9,
                color: color ?? const PdfColor.fromInt(0xFF212121),
                fontWeight:
                    bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
      );

  static String _fmt(double v) {
    final abs = v.abs();
    final str = abs >= 10000000
        ? '${(abs / 10000000).toStringAsFixed(2)} Cr'
        : abs >= 100000
            ? '${(abs / 100000).toStringAsFixed(2)} L'
            : NumberFormat('#,##,##0.##').format(abs);
    return (v < 0 ? '-' : '') + '₹$str';
  }
}