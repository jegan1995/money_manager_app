import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction_model.dart';
import '../models/account_model.dart';
import '../services/transaction_service.dart';
import '../services/account_service.dart';
import '../services/auth_service.dart';
import '../services/pdf_report_service.dart';

class PdfReportScreen extends StatefulWidget {
  const PdfReportScreen({super.key});

  @override
  State<PdfReportScreen> createState() => _PdfReportScreenState();
}

class _PdfReportScreenState extends State<PdfReportScreen> {
  final _txnSvc  = TransactionService();
  final _accSvc  = AccountService();
  final _authSvc = AuthService();

  DateTime _selectedMonth =
      DateTime(DateTime.now().year, DateTime.now().month);
  bool _generating = false;
  bool _previewing = false;

  void _prevMonth() => setState(() =>
      _selectedMonth =
          DateTime(_selectedMonth.year, _selectedMonth.month - 1));

  void _nextMonth() {
    final now  = DateTime.now();
    final next =
        DateTime(_selectedMonth.year, _selectedMonth.month + 1);
    if (next.isBefore(DateTime(now.year, now.month + 1))) {
      setState(() => _selectedMonth = next);
    }
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _selectedMonth.year == now.year &&
        _selectedMonth.month == now.month;
  }

  Future<String> _getUserName() async {
    try {
      return await _authSvc.getUserName() ??
          _authSvc.currentUser?.email ??
          'User';
    } catch (_) {
      return _authSvc.currentUser?.email ?? 'User';
    }
  }

  Future<void> _preview(
      List<TransactionModel> txns, List<AccountModel> accs) async {
    setState(() => _previewing = true);
    try {
      final name = await _getUserName();
      await PdfReportService.previewPdf(
        transactions: txns,
        accounts: accs,
        month: _selectedMonth,
        userName: name,
      );
      if (mounted && kIsWeb) {
        _snack('PDF downloaded to your device!', Colors.green);
      }
    } catch (e) {
      if (mounted) _snack('Error: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _previewing = false);
    }
  }

  Future<void> _share(
      List<TransactionModel> txns, List<AccountModel> accs) async {
    setState(() => _generating = true);
    try {
      final name = await _getUserName();
      await PdfReportService.generateAndShare(
        transactions: txns,
        accounts: accs,
        month: _selectedMonth,
        userName: name,
      );
    } catch (e) {
      if (mounted) _snack('Error: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark =
        Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0D1117) : const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('Monthly PDF Report'),
        backgroundColor: const Color(0xFF303F9F),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<TransactionModel>>(
        stream: _txnSvc.getTransactions(),
        builder: (context, txnSnap) {
          if (txnSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          return StreamBuilder<List<AccountModel>>(
            stream: _accSvc.getAccounts(),
            builder: (context, accSnap) {
              final allTxns  = txnSnap.data ?? [];
              final accounts = accSnap.data ?? [];

              final monthTxns = allTxns
                  .where((t) =>
                      t.date.year == _selectedMonth.year &&
                      t.date.month == _selectedMonth.month)
                  .toList();

              final expenses    =
                  monthTxns.where((t) => t.type == 'expense').toList();
              final income      =
                  monthTxns.where((t) => t.type == 'income').toList();
              final totalIncome =
                  income.fold(0.0,   (s, t) => s + t.amount);
              final totalExp    =
                  expenses.fold(0.0, (s, t) => s + t.amount);
              final netSavings  = totalIncome - totalExp;
              final hasData     = monthTxns.isNotEmpty;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(children: [

                  // ── Month Selector ────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E2530)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8)
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left),
                          onPressed: _prevMonth,
                          color: const Color(0xFF303F9F),
                        ),
                        Column(children: [
                          Text(
                            DateFormat('MMMM yyyy')
                                .format(_selectedMonth),
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold),
                          ),
                          if (_isCurrentMonth)
                            Container(
                              margin: const EdgeInsets.only(top: 2),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius:
                                    BorderRadius.circular(8),
                              ),
                              child: const Text('Current Month',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.blue,
                                      fontWeight:
                                          FontWeight.w600)),
                            ),
                        ]),
                        IconButton(
                          icon: const Icon(Icons.chevron_right),
                          onPressed:
                              _isCurrentMonth ? null : _nextMonth,
                          color: _isCurrentMonth
                              ? Colors.grey
                              : const Color(0xFF303F9F),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Report Card ────────────────────────────────────────────
                  Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E2530)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4))
                      ],
                    ),
                    child: Column(children: [

                      // Cover gradient header
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(0xFF303F9F),
                              Color(0xFF3F51B5)
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.vertical(
                              top: Radius.circular(16)),
                        ),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white
                                      .withOpacity(0.15),
                                  borderRadius:
                                      BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                    Icons.picture_as_pdf,
                                    color: Colors.white,
                                    size: 28),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  const Text('Financial Report',
                                      style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12)),
                                  Text(
                                    DateFormat('MMMM yyyy')
                                        .format(_selectedMonth),
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight:
                                            FontWeight.bold),
                                  ),
                                ],
                              ),
                            ]),
                            const SizedBox(height: 20),
                            const Divider(color: Colors.white24),
                            const SizedBox(height: 16),
                            if (hasData)
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  _stat('Income',
                                      _fmtShort(totalIncome),
                                      Colors.greenAccent),
                                  _stat('Expense',
                                      _fmtShort(totalExp),
                                      Colors.redAccent),
                                  _stat(
                                      'Savings',
                                      _fmtShort(netSavings),
                                      netSavings >= 0
                                          ? Colors.greenAccent
                                          : Colors.orangeAccent),
                                ],
                              )
                            else
                              Center(
                                child: Text(
                                  'No transactions in\n${DateFormat('MMMM yyyy').format(_selectedMonth)}',
                                  style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                          ],
                        ),
                      ),

                      // Transaction count chips
                      if (hasData)
                        Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceAround,
                            children: [
                              _chip('${monthTxns.length} total',
                                  Colors.blue),
                              _chip(
                                  '${income.length} income',
                                  Colors.green),
                              _chip(
                                  '${expenses.length} expenses',
                                  Colors.red),
                            ],
                          ),
                        ),

                      // Buttons
                      Padding(
                        padding:
                            const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Column(children: [

                          // Button 1: Preview (Android) / Download (Web)
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: hasData &&
                                      !_previewing &&
                                      !_generating
                                  ? () => _preview(allTxns, accounts)
                                  : null,
                              icon: _previewing
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2))
                                  : Icon(kIsWeb
                                      ? Icons.download
                                      : Icons.preview),
                              label: Text(
                                _previewing
                                    ? 'Generating...'
                                    : kIsWeb
                                        ? 'Download PDF'
                                        : 'Preview PDF',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    const Color(0xFF303F9F),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(12)),
                                textStyle: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),

                          const SizedBox(height: 10),

                          // Button 2: Share (Android) / Download again (Web)
                          if (!kIsWeb)
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: hasData &&
                                        !_generating &&
                                        !_previewing
                                    ? () => _share(allTxns, accounts)
                                    : null,
                                icon: _generating
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child:
                                            CircularProgressIndicator(
                                                color: Color(
                                                    0xFF303F9F),
                                                strokeWidth: 2))
                                    : const Icon(Icons.share),
                                label: Text(_generating
                                    ? 'Preparing...'
                                    : 'Share PDF'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor:
                                      const Color(0xFF303F9F),
                                  padding:
                                      const EdgeInsets.symmetric(
                                          vertical: 14),
                                  side: const BorderSide(
                                      color: Color(0xFF303F9F)),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(12)),
                                  textStyle: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),

                          // Web info note
                          if (kIsWeb && hasData)
                            Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.blue.withOpacity(0.2)),
                                ),
                                child: const Row(children: [
                                  Icon(Icons.info_outline, size: 14, color: Colors.blue),
                                  SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'PDF Preview is available on the Android app. On web, PDF downloads directly to your device.',
                                      style: TextStyle(fontSize: 11, color: Colors.blue),
                                    ),
                                  ),
                                ]),
                              ),
                            ),

                          if (!hasData)
                            Padding(
                              padding:
                                  const EdgeInsets.only(top: 12),
                              child: Text(
                                'Add transactions for ' + DateFormat('MMMM').format(_selectedMonth) + ' to generate a report',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[500]),
                                textAlign: TextAlign.center,
                              ),
                            ),
                        ]),
                      ),
                    ]),
                  ),

                  const SizedBox(height: 20),

                  // ── What's inside ─────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E2530)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 8)
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('What\'s in the PDF',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14)),
                        const SizedBox(height: 12),
                        _infoRow(Icons.bar_chart,    'Page 1 - Summary',
                            'Income, expense, savings rate & category progress bars'),
                        _infoRow(Icons.account_balance, 'Page 1 - Accounts',
                            'All account balances'),
                        _infoRow(Icons.arrow_upward, 'Page 2 - Income list',
                            'Date, category, note & amount'),
                        _infoRow(Icons.arrow_downward, 'Page 2 - Expense list',
                            'Date, category, note & amount'),
                        _infoRow(
                            kIsWeb ? Icons.download : Icons.share,
                            kIsWeb ? 'Download' : 'Shareable',
                            kIsWeb
                                ? 'Downloads directly to your device'
                                : 'Share via WhatsApp, Gmail, Google Drive'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 80),
                ]),
              );
            },
          );
        },
      ),
    );
  }

  Widget _stat(String label, String value, Color color) =>
      Column(children: [
        Text(label,
            style: const TextStyle(
                color: Colors.white60, fontSize: 11)),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 15)),
      ]);

  Widget _chip(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w600)),
      );

  Widget _infoRow(IconData icon, String title, String desc) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFF303F9F).withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon,
                  size: 16,
                  color: const Color(0xFF303F9F)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                  Text(desc,
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey[500])),
                ],
              ),
            ),
          ],
        ),
      );

  String _fmtShort(double v) {
    final neg = v < 0;
    final abs = v.abs();
    String s;
    if (abs >= 10000000)    s = '${(abs / 10000000).toStringAsFixed(1)}Cr';
    else if (abs >= 100000) s = '${(abs / 100000).toStringAsFixed(1)}L';
    else if (abs >= 1000)   s = '${(abs / 1000).toStringAsFixed(1)}k';
    else                    s = abs.toStringAsFixed(0);
    return '${neg ? '-' : ''}Rs.$s';
  }
}