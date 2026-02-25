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

  // ── Preview: web = download, Android = in-app viewer ──────────────────────
  static Future<void> previewPdf({
    required List<TransactionModel> transactions,
    required List<AccountModel> accounts,
    required DateTime month,
    required String userName,
  }) async {
    final bytes = await _buildPdf(
      transactions: transactions,
      accounts: accounts,
      month: month,
      userName: userName,
    );
    final filename =
        'MoneyManager_${DateFormat('MMM_yyyy').format(month)}_Report.pdf';

    if (kIsWeb) {
      // Web: download directly (Printing.layoutPdf not supported on web)
      final blob = html.Blob([bytes], 'application/pdf');
      final url  = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', filename)
        ..click();
      html.Url.revokeObjectUrl(url);
    } else {
      // Android: show in-app PDF viewer
      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: filename,
      );
    }
  }

  // ── Share (Android share sheet / Web download) ─────────────────────────────
  static Future<void> generateAndShare({
    required List<TransactionModel> transactions,
    required List<AccountModel> accounts,
    required DateTime month,
    required String userName,
  }) async {
    final bytes = await _buildPdf(
      transactions: transactions,
      accounts: accounts,
      month: month,
      userName: userName,
    );
    final filename =
        'MoneyManager_${DateFormat('MMM_yyyy').format(month)}_Report.pdf';

    if (kIsWeb) {
      final blob = html.Blob([bytes], 'application/pdf');
      final url  = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', filename)
        ..click();
      html.Url.revokeObjectUrl(url);
    } else {
      final dir  = await getTemporaryDirectory();
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/pdf')],
        subject: 'Money Manager - ${DateFormat('MMMM yyyy').format(month)} Report',
      );
    }
  }

  // ── PDF Builder ────────────────────────────────────────────────────────────
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

    // Category breakdown for expenses
    final catMap = <String, double>{};
    for (final t in expenses) {
      catMap[t.category] = (catMap[t.category] ?? 0) + t.amount;
    }
    final sortedCats = catMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final monthLabel  = DateFormat('MMMM yyyy').format(month);
    final generatedOn = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());

    // ── Solid colors (no opacity tricks — avoids rendering issues) ────────────
    const cPrimary  = PdfColors.indigo800;
    const cGreen    = PdfColors.green800;
    const cRed      = PdfColors.red800;
    const cGreenBg  = PdfColors.green50;
    const cRedBg    = PdfColors.red50;
    const cBlueBg   = PdfColors.indigo50;
    const cGrey     = PdfColors.grey600;
    const cDark     = PdfColors.grey900;
    const cDivider  = PdfColors.grey300;
    const cWhite    = PdfColors.white;
    const cAltRow   = PdfColors.grey50;

    // ── Page 1: Summary ───────────────────────────────────────────────────────
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      header: (_) => _header(monthLabel, userName, cPrimary, cGrey),
      footer: (ctx) => _footer(ctx, generatedOn, cGrey),
      build: (_) => [
        pw.SizedBox(height: 10),

        // ── 3 summary cards ─────────────────────────────────────────────────
        pw.Row(children: [
          _card('Total Income',  _fmtPdf(totalIncome),
                cGreen, cGreenBg, '+'),
          pw.SizedBox(width: 10),
          _card('Total Expense', _fmtPdf(totalExpense),
                cRed, cRedBg, '-'),
          pw.SizedBox(width: 10),
          _card('Net Savings',   _fmtPdf(netSavings),
                netSavings >= 0 ? cGreen : cRed,
                netSavings >= 0 ? cGreenBg : cRedBg,
                netSavings >= 0 ? '=' : '!'),
        ]),

        pw.SizedBox(height: 14),

        // ── Savings rate banner ─────────────────────────────────────────────
        if (totalIncome > 0)
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: pw.BoxDecoration(
              color: netSavings >= 0 ? cGreenBg : cRedBg,
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(
                  color: netSavings >= 0 ? cGreen : cRed, width: 0.5),
            ),
            child: pw.Text(
              'Savings Rate: ${(netSavings / totalIncome * 100).toStringAsFixed(1)}%  |  '
              '${netSavings >= 0 ? 'Saved' : 'Overspent by'} ${_fmtPdf(netSavings.abs())} this month  |  '
              '${monthTxns.length} transactions',
              style: pw.TextStyle(
                  fontSize: 10,
                  color: netSavings >= 0 ? cGreen : cRed),
            ),
          ),

        pw.SizedBox(height: 20),

        // ── Category breakdown ──────────────────────────────────────────────
        if (sortedCats.isNotEmpty) ...[
          _sectionTitle('Expense by Category', cRed, cRedBg),
          pw.SizedBox(height: 10),
          ...sortedCats.take(12).map((e) {
            final pct    = totalExpense > 0 ? (e.value / totalExpense) : 0.0;
            final fillW  = (531 * pct.clamp(0.01, 1.0));
            return pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 9),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(e.key,
                          style: pw.TextStyle(fontSize: 10, color: cDark)),
                      pw.Text(
                        '${_fmtPdf(e.value)}   ${(pct * 100).toStringAsFixed(1)}%',
                        style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: cRed),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 4),
                  pw.Stack(children: [
                    pw.Container(
                      width: 531, height: 7,
                      decoration: pw.BoxDecoration(
                          color: cDivider,
                          borderRadius: pw.BorderRadius.circular(4))),
                    pw.Container(
                      width: fillW, height: 7,
                      decoration: pw.BoxDecoration(
                          color: cRed,
                          borderRadius: pw.BorderRadius.circular(4))),
                  ]),
                ],
              ),
            );
          }),
        ],

        pw.SizedBox(height: 20),

        // ── Account Balances ────────────────────────────────────────────────
        if (accounts.isNotEmpty) ...[
          _sectionTitle('Account Balances', cPrimary, cBlueBg),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: cDivider, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(3),
              1: const pw.FlexColumnWidth(2),
              2: const pw.FlexColumnWidth(2),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: cPrimary),
                children: [
                  _th('Account', cWhite),
                  _th('Type',    cWhite),
                  _th('Balance', cWhite),
                ],
              ),
              ...accounts.asMap().entries.map((entry) {
                final a    = entry.value;
                final even = entry.key % 2 == 0;
                return pw.TableRow(
                  decoration: pw.BoxDecoration(
                      color: even ? cWhite : cAltRow),
                  children: [
                    _td(a.name),
                    _td(a.typeDisplayName),
                    _td(_fmtPdf(a.balance),
                        color: a.balance >= 0 ? cGreen : cRed,
                        bold: true),
                  ],
                );
              }),
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
            _header('$monthLabel - Transactions', userName, cPrimary, cGrey),
        footer: (ctx) => _footer(ctx, generatedOn, cGrey),
        build: (_) => [
          pw.SizedBox(height: 10),

          if (income.isNotEmpty) ...[
            _sectionTitle('Income  (${income.length} entries)', cGreen, cGreenBg),
            pw.SizedBox(height: 6),
            _txnTable(income, cGreen, cGreenBg, cDivider, cGrey, cAltRow),
            pw.SizedBox(height: 4),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text('Total Income: ${_fmtPdf(totalIncome)}',
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      color: cGreen, fontSize: 11)),
            ),
            pw.SizedBox(height: 20),
          ],

          if (expenses.isNotEmpty) ...[
            _sectionTitle('Expenses  (${expenses.length} entries)', cRed, cRedBg),
            pw.SizedBox(height: 6),
            _txnTable(expenses, cRed, cRedBg, cDivider, cGrey, cAltRow),
            pw.SizedBox(height: 4),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text('Total Expense: ${_fmtPdf(totalExpense)}',
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      color: cRed, fontSize: 11)),
            ),
          ],
        ],
      ));
    }

    return pdf.save();
  }

  // ── Widgets ────────────────────────────────────────────────────────────────

  static pw.Widget _header(String title, String user,
      PdfColor primary, PdfColor grey) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 10),
      decoration: const pw.BoxDecoration(
          border: pw.Border(
              bottom: pw.BorderSide(color: PdfColors.indigo800, width: 2))),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('Money Manager',
                style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: primary)),
            pw.Text(title,
                style: pw.TextStyle(fontSize: 10, color: grey)),
          ]),
          pw.Text(user, style: pw.TextStyle(fontSize: 9, color: grey)),
        ],
      ),
    );
  }

  static pw.Widget _footer(pw.Context ctx, String gen, PdfColor grey) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: const pw.BoxDecoration(
          border: pw.Border(
              top: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Generated: $gen',
              style: pw.TextStyle(fontSize: 7, color: grey)),
          pw.Text('Page ${ctx.pageNumber} / ${ctx.pagesCount}',
              style: pw.TextStyle(fontSize: 7, color: grey)),
        ],
      ),
    );
  }

  static pw.Widget _card(String label, String value,
      PdfColor textColor, PdfColor bgColor, String prefix) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: bgColor,
          borderRadius: pw.BorderRadius.circular(8),
          border: pw.Border.all(color: textColor, width: 0.8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label,
                style: pw.TextStyle(
                    fontSize: 9,
                    color: textColor,
                    fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            pw.Text('$prefix $value',
                style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: textColor)),
          ],
        ),
      ),
    );
  }

  static pw.Widget _sectionTitle(
      String title, PdfColor textColor, PdfColor bgColor) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 10),
      decoration: pw.BoxDecoration(
        color: bgColor,
        borderRadius: pw.BorderRadius.circular(4),
        border: pw.Border(
            left: pw.BorderSide(color: textColor, width: 3)),
      ),
      child: pw.Text(title,
          style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: textColor)),
    );
  }

  static pw.Widget _txnTable(
      List<TransactionModel> txns,
      PdfColor accent,
      PdfColor accentBg,
      PdfColor divider,
      PdfColor grey,
      PdfColor altRow) {
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
          decoration: pw.BoxDecoration(color: accentBg),
          children: [
            _th('Date',     accent),
            _th('Category', accent),
            _th('Note',     accent),
            _th('Amount',   accent),
          ],
        ),
        ...txns.asMap().entries.map((entry) {
          final t    = entry.value;
          final even = entry.key % 2 == 0;
          final cat  = t.subcategory != null
              ? '${t.category} / ${t.subcategory}'
              : t.category;
          return pw.TableRow(
            decoration: pw.BoxDecoration(
                color: even ? PdfColors.white : altRow),
            children: [
              _td(DateFormat('dd MMM').format(t.date)),
              _td(cat),
              _td(t.note ?? t.description ?? '-', color: grey),
              _td(_fmtPdf(t.amount), color: accent, bold: true),
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
                color: color ?? PdfColors.grey900,
                fontWeight:
                    bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
      );

  // ── Number formatter — no emoji, no ₹ (use Rs. for PDF font compat) ───────
  static String _fmtPdf(double v) {
    final abs = v.abs();
    final str = abs >= 10000000
        ? 'Rs.${(abs / 10000000).toStringAsFixed(2)}Cr'
        : abs >= 100000
            ? 'Rs.${(abs / 100000).toStringAsFixed(2)}L'
            : 'Rs.${NumberFormat('#,##,##0').format(abs)}';
    return v < 0 ? '-$str' : str;
  }
}