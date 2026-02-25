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

  // ── Preview (Android: in-app viewer / Web: download) ──────────────────────
  static Future<void> previewPdf({
    required List<TransactionModel> transactions,
    required List<AccountModel> accounts,
    required DateTime month,
    required String userName,
  }) async {
    if (kIsWeb) {
      await generateAndShare(
        transactions: transactions,
        accounts: accounts,
        month: month,
        userName: userName,
      );
      return;
    }
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

  // ── Share / Download ───────────────────────────────────────────────────────
  static Future<void> generateAndShare({
    required List<TransactionModel> transactions,
    required List<AccountModel> accounts,
    required DateTime month,
    required String userName,
  }) async {
    final bytes    = await _buildPdf(
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
        subject:
            'Money Manager - ${DateFormat('MMMM yyyy').format(month)} Report',
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
    // Load fonts that support Rs. and standard ASCII (safe for all PDF viewers)
    final fontRegular = await PdfGoogleFonts.notoSansRegular();
    final fontBold    = await PdfGoogleFonts.notoSansBold();

    final pdf = pw.Document();

    // Helper styles using loaded fonts
    pw.TextStyle body(
        {double size = 10,
        PdfColor? color,
        pw.Font? font}) =>
        pw.TextStyle(
          font: font ?? fontRegular,
          fontSize: size,
          color: color ?? _cDark,
        );

    pw.TextStyle bold(
        {double size = 10, PdfColor? color}) =>
        pw.TextStyle(
          font: fontBold,
          fontSize: size,
          color: color ?? _cDark,
        );

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

    final monthLabel  = DateFormat('MMMM yyyy').format(month);
    final generatedOn = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());

    // ── Page 1: Summary ───────────────────────────────────────────────────────
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      header: (_) => _header(monthLabel, userName, body, bold),
      footer: (ctx) => _footer(ctx, generatedOn, body),
      build: (_) => [
        pw.SizedBox(height: 10),

        // Summary cards row
        pw.Row(children: [
          _card('Total Income',  _fmt(totalIncome),  _cGreen, _cGreenBg, bold),
          pw.SizedBox(width: 10),
          _card('Total Expense', _fmt(totalExpense), _cRed,   _cRedBg,   bold),
          pw.SizedBox(width: 10),
          _card('Net Savings',   _fmt(netSavings),
              netSavings >= 0 ? _cGreen : _cRed,
              netSavings >= 0 ? _cGreenBg : _cRedBg,
              bold),
        ]),

        pw.SizedBox(height: 14),

        // Savings rate banner
        if (totalIncome > 0)
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: pw.BoxDecoration(
              color: netSavings >= 0 ? _cGreenBg : _cRedBg,
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(
                  color: netSavings >= 0 ? _cGreen : _cRed, width: 0.5),
            ),
            child: pw.Text(
              'Savings Rate: ${(netSavings / totalIncome * 100).toStringAsFixed(1)}%   '
              '${netSavings >= 0 ? 'Saved' : 'Overspent by'} ${_fmt(netSavings.abs())} this month   '
              '${monthTxns.length} transactions recorded',
              style: body(
                  color: netSavings >= 0 ? _cGreen : _cRed,
                  font: fontBold),
            ),
          ),

        pw.SizedBox(height: 20),

        // Category breakdown
        if (sortedCats.isNotEmpty) ...[
          _sectionTitle('Expense by Category', _cRed, _cRedBg, bold),
          pw.SizedBox(height: 10),
          ...sortedCats.take(12).map((e) {
            final pct   = totalExpense > 0 ? e.value / totalExpense : 0.0;
            final fillW = 531 * pct.clamp(0.01, 1.0);
            return pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 9),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(_clean(e.key), style: body()),
                      pw.Text(
                        '${_fmt(e.value)}   ${(pct * 100).toStringAsFixed(1)}%',
                        style: bold(color: _cRed),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 4),
                  pw.Stack(children: [
                    pw.Container(
                      width: 531, height: 7,
                      decoration: pw.BoxDecoration(
                          color: _cDivider,
                          borderRadius: pw.BorderRadius.circular(4))),
                    pw.Container(
                      width: fillW, height: 7,
                      decoration: pw.BoxDecoration(
                          color: _cRed,
                          borderRadius: pw.BorderRadius.circular(4))),
                  ]),
                ],
              ),
            );
          }),
        ],

        pw.SizedBox(height: 20),

        // Account balances
        if (accounts.isNotEmpty) ...[
          _sectionTitle('Account Balances', _cPrimary, _cBlueBg, bold),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: _cDivider, width: 0.5),
            columnWidths: const {
              0: pw.FlexColumnWidth(3),
              1: pw.FlexColumnWidth(2),
              2: pw.FlexColumnWidth(2),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: _cPrimary),
                children: [
                  _th('Account', PdfColors.white, bold),
                  _th('Type',    PdfColors.white, bold),
                  _th('Balance', PdfColors.white, bold),
                ],
              ),
              ...accounts.asMap().entries.map((en) {
                final a    = en.value;
                final even = en.key % 2 == 0;
                return pw.TableRow(
                  decoration: pw.BoxDecoration(
                      color: even ? PdfColors.white : _cAltRow),
                  children: [
                    _td(a.name,            body),
                    _td(a.typeDisplayName, body),
                    _td(_fmt(a.balance),   bold,
                        color: a.balance >= 0 ? _cGreen : _cRed),
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
            _header('$monthLabel - Transactions', userName, body, bold),
        footer: (ctx) => _footer(ctx, generatedOn, body),
        build: (_) => [
          pw.SizedBox(height: 10),

          if (income.isNotEmpty) ...[
            _sectionTitle(
                'Income  (${income.length} entries)', _cGreen, _cGreenBg, bold),
            pw.SizedBox(height: 6),
            _txnTable(income, _cGreen, _cGreenBg, body, bold),
            pw.SizedBox(height: 4),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text('Total Income: ${_fmt(totalIncome)}',
                  style: bold(size: 11, color: _cGreen)),
            ),
            pw.SizedBox(height: 20),
          ],

          if (expenses.isNotEmpty) ...[
            _sectionTitle(
                'Expenses  (${expenses.length} entries)', _cRed, _cRedBg, bold),
            pw.SizedBox(height: 6),
            _txnTable(expenses, _cRed, _cRedBg, body, bold),
            pw.SizedBox(height: 4),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text('Total Expense: ${_fmt(totalExpense)}',
                  style: bold(size: 11, color: _cRed)),
            ),
          ],
        ],
      ));
    }

    return pdf.save();
  }

  // ── Colors — explicit hex to guarantee correct rendering ───────────────────
  static const _cPrimary  = PdfColor.fromInt(0xFF303F9F); // indigo700
  static const _cGreen    = PdfColor.fromInt(0xFF2E7D32); // green800
  static const _cRed      = PdfColor.fromInt(0xFFC62828); // red800
  static const _cGreenBg  = PdfColor.fromInt(0xFFE8F5E9); // green50
  static const _cRedBg    = PdfColor.fromInt(0xFFFFEBEE); // red50
  static const _cBlueBg   = PdfColor.fromInt(0xFFE8EAF6); // indigo50
  static const _cDark     = PdfColor.fromInt(0xFF212121);
  static const _cGrey     = PdfColor.fromInt(0xFF757575);
  static const _cDivider  = PdfColor.fromInt(0xFFE0E0E0);
  static const _cAltRow   = PdfColor.fromInt(0xFFF5F5F5);

  // ── Widget builders ────────────────────────────────────────────────────────

  static pw.Widget _header(
    String title,
    String user,
    pw.TextStyle Function({double size, PdfColor? color, pw.Font? font}) body,
    pw.TextStyle Function({double size, PdfColor? color}) bold,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 10),
      decoration: const pw.BoxDecoration(
          border: pw.Border(
              bottom: pw.BorderSide(
                  color: PdfColor.fromInt(0xFF303F9F), width: 2))),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Money Manager',
                  style: bold(size: 16, color: _cPrimary)),
              pw.Text(title, style: body(size: 10, color: _cGrey)),
            ],
          ),
          pw.Text(user, style: body(size: 9, color: _cGrey)),
        ],
      ),
    );
  }

  static pw.Widget _footer(
    pw.Context ctx,
    String gen,
    pw.TextStyle Function({double size, PdfColor? color, pw.Font? font}) body,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: const pw.BoxDecoration(
          border: pw.Border(
              top: pw.BorderSide(
                  color: PdfColor.fromInt(0xFFE0E0E0), width: 0.5))),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Generated: $gen', style: body(size: 7, color: _cGrey)),
          pw.Text('Page ${ctx.pageNumber} / ${ctx.pagesCount}',
              style: body(size: 7, color: _cGrey)),
        ],
      ),
    );
  }

  static pw.Widget _card(
    String label,
    String value,
    PdfColor textColor,
    PdfColor bgColor,
    pw.TextStyle Function({double size, PdfColor? color}) bold,
  ) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: bgColor,
          borderRadius: pw.BorderRadius.circular(8),
          border: pw.Border.all(color: textColor, width: 1),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label, style: bold(size: 9, color: textColor)),
            pw.SizedBox(height: 6),
            pw.Text(value, style: bold(size: 15, color: textColor)),
          ],
        ),
      ),
    );
  }

  static pw.Widget _sectionTitle(
    String title,
    PdfColor textColor,
    PdfColor bgColor,
    pw.TextStyle Function({double size, PdfColor? color}) bold,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 10),
      decoration: pw.BoxDecoration(
        color: bgColor,
        borderRadius: pw.BorderRadius.circular(4),
        border: pw.Border(
            left: pw.BorderSide(color: textColor, width: 3)),
      ),
      child: pw.Text(title, style: bold(size: 11, color: textColor)),
    );
  }

  static pw.Widget _txnTable(
    List<TransactionModel> txns,
    PdfColor accent,
    PdfColor accentBg,
    pw.TextStyle Function({double size, PdfColor? color, pw.Font? font}) body,
    pw.TextStyle Function({double size, PdfColor? color}) bold,
  ) {
    return pw.Table(
      border: pw.TableBorder.all(color: _cDivider, width: 0.4),
      columnWidths: const {
        0: pw.FlexColumnWidth(1.4),
        1: pw.FlexColumnWidth(2),
        2: pw.FlexColumnWidth(3),
        3: pw.FlexColumnWidth(1.6),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: accentBg),
          children: [
            _th('Date',     accent, bold),
            _th('Category', accent, bold),
            _th('Note',     accent, bold),
            _th('Amount',   accent, bold),
          ],
        ),
        ...txns.asMap().entries.map((en) {
          final t    = en.value;
          final even = en.key % 2 == 0;
          final cat  = t.subcategory != null
              ? '${_clean(t.category)} / ${_clean(t.subcategory)}'
              : _clean(t.category);
          return pw.TableRow(
            decoration: pw.BoxDecoration(
                color: even ? PdfColors.white : _cAltRow),
            children: [
              _td(DateFormat('dd MMM').format(t.date), body),
              _td(cat, body),
              _td(_clean(t.note ?? t.description), body, color: _cGrey),
              _td(_fmt(t.amount), bold, color: accent),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _th(
    String text,
    PdfColor color,
    pw.TextStyle Function({double size, PdfColor? color}) bold,
  ) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        child: pw.Text(text, style: bold(size: 9, color: color)),
      );

  static pw.Widget _td(
    String text,
    dynamic styleFn, {
    PdfColor? color,
  }) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        child: pw.Text(
          text,
          style: styleFn(size: 9, color: color ?? _cDark),
        ),
      );


  // Strip emoji and unsupported characters - keep only printable ASCII + basic latin
  static String _clean(String? input) {
    if (input == null || input.isEmpty) return '-';
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      // Keep printable ASCII (32-126) and extended latin (128-591)
      if (rune >= 32 && rune <= 591) {
        buffer.writeCharCode(rune);
      } else if (rune == 0x20 || rune == 0x2013 || rune == 0x2014) {
        // space, en-dash, em-dash
        buffer.write(' ');
      }
      // All emoji (>591 and not basic latin) are silently dropped
    }
    return buffer.toString().trim().isEmpty ? (input.trim()) : buffer.toString().trim();
  }

  // ── Formatter — no rupee symbol, no emoji, pure ASCII ─────────────────────
  static String _fmt(double v) {
    final neg = v < 0;
    final abs = v.abs();
    String str;
    if (abs >= 10000000) {
      str = 'Rs.${(abs / 10000000).toStringAsFixed(2)} Cr';
    } else if (abs >= 100000) {
      str = 'Rs.${(abs / 100000).toStringAsFixed(2)} L';
    } else {
      str = 'Rs.${NumberFormat('#,##,##0').format(abs)}';
    }
    return neg ? '-$str' : str;
  }
}