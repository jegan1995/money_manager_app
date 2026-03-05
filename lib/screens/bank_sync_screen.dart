// lib/screens/bank_sync_screen.dart
// Bank Sync: SMS Auto-Read + Bank CSV Import
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import '../models/transaction_model.dart';
import '../models/account_model.dart';
import '../services/transaction_service.dart';
import '../services/account_service.dart';

// ── SMS platform channel (Android only) ──────────────────────────────────────
const _smsChannel = MethodChannel('com.jegan.money_manager_app/sms');

class BankSyncScreen extends StatefulWidget {
  const BankSyncScreen({super.key});
  @override
  State<BankSyncScreen> createState() => _BankSyncScreenState();
}

class _BankSyncScreenState extends State<BankSyncScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _txnSvc = TransactionService();
  final _accSvc = AccountService();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D1117) : const Color(0xFFF0F4FF),
      appBar: AppBar(
        title: const Text('Bank Sync',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        backgroundColor: const Color(0xFF667eea),
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.sms_rounded, size: 16), text: 'SMS Import'),
            Tab(icon: Icon(Icons.table_chart_rounded, size: 16), text: 'CSV Import'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _SmsImportTab(txnSvc: _txnSvc, accSvc: _accSvc),
          _CsvImportTab(txnSvc: _txnSvc, accSvc: _accSvc),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// SMS IMPORT TAB
// ════════════════════════════════════════════════════════════════════════════
class _SmsImportTab extends StatefulWidget {
  final TransactionService txnSvc;
  final AccountService accSvc;
  const _SmsImportTab({required this.txnSvc, required this.accSvc});
  @override
  State<_SmsImportTab> createState() => _SmsImportTabState();
}

class _SmsImportTabState extends State<_SmsImportTab> {
  bool _loading = false;
  bool _importing = false;
  String _status = '';
  List<_ParsedSms> _parsed = [];
  List<_ParsedSms> _selected = [];
  List<AccountModel> _accounts = [];
  int _importedCount = 0;
  int _daysBack = 30;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    final acc = await widget.accSvc.getAccountsList().first;
    if (mounted) setState(() => _accounts = acc);
  }

  // ── Read SMS via platform channel ─────────────────────────────────────────
  Future<void> _readSms() async {
    if (!Platform.isAndroid) {
      _showError('SMS reading is only available on Android');
      return;
    }
    setState(() { _loading = true; _status = 'Requesting SMS permission…'; _parsed = []; });
    try {
      final result = await _smsChannel.invokeMethod<List>('readBankSms', {
        'daysBack': _daysBack,
      });
      final messages = result?.cast<Map>() ?? [];
      setState(() => _status = 'Parsing ${messages.length} messages…');
      final parsed = <_ParsedSms>[];
      for (final msg in messages) {
        final p = SmsParser.parse(
          body: msg['body'] as String? ?? '',
          sender: msg['sender'] as String? ?? '',
          timestamp: msg['timestamp'] as int? ?? 0,
        );
        if (p != null) parsed.add(p);
      }
      // Deduplicate by amount+date
      final unique = <String, _ParsedSms>{};
      for (final p in parsed) {
        final key = '${p.amount}_${p.date.day}${p.date.month}${p.date.year}';
        unique[key] = p;
      }
      setState(() {
        _parsed = unique.values.toList()
          ..sort((a, b) => b.date.compareTo(a.date));
        _selected = List.from(_parsed);
        _status = '';
        _loading = false;
      });
    } on PlatformException catch (e) {
      setState(() {
        _loading = false;
        _status = '';
      });
      _showError(e.message ?? 'Permission denied or SMS unavailable');
    } catch (e) {
      setState(() { _loading = false; _status = ''; });
      _showError('Error reading SMS: $e');
    }
  }

  Future<void> _importSelected() async {
    if (_selected.isEmpty) return;
    if (_accounts.isEmpty) {
      _showError('Please add an account first');
      return;
    }
    setState(() { _importing = true; _importedCount = 0; });
    int count = 0;
    for (final s in _selected) {
      // Match account by last 4 digits if available
      String? accountId = _matchAccount(s.accountLast4);
      final txn = TransactionModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: '',
        type: s.isCredit ? 'income' : 'expense',
        amount: s.amount,
        category: s.isCredit ? 'Other Income' : _guessCategory(s.description),
        date: s.date,
        note: s.description,
        fromAccount: s.isCredit ? null : accountId,
        toAccount: s.isCredit ? accountId : null,
      );
      await widget.txnSvc.addTransaction(txn);
      count++;
      if (mounted) setState(() => _importedCount = count);
    }
    if (mounted) {
      setState(() => _importing = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('✅ Imported $count transactions'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ));
      setState(() { _parsed = []; _selected = []; });
    }
  }

  String? _matchAccount(String? last4) {
    if (last4 == null || _accounts.isEmpty) return _accounts.firstOrNull?.id;
    for (final a in _accounts) {
      if (a.name.contains(last4)) return a.id;
    }
    return _accounts.first.id;
  }

  String _guessCategory(String desc) {
    final d = desc.toLowerCase();
    if (d.contains('swiggy') || d.contains('zomato') || d.contains('food')) return 'Food & Dining';
    if (d.contains('amazon') || d.contains('flipkart') || d.contains('myntra')) return 'Shopping';
    if (d.contains('uber') || d.contains('ola') || d.contains('irctc') || d.contains('metro')) return 'Transport';
    if (d.contains('netflix') || d.contains('spotify') || d.contains('hotstar') || d.contains('prime')) return 'Subscriptions';
    if (d.contains('apollo') || d.contains('medplus') || d.contains('hospital') || d.contains('pharmacy')) return 'Health';
    if (d.contains('electricity') || d.contains('bescom') || d.contains('gas') || d.contains('water')) return 'Bills & Utilities';
    if (d.contains('rent') || d.contains('maintenance')) return 'Rent';
    if (d.contains('salary') || d.contains('payroll')) return 'Salary';
    if (d.contains('atm')) return 'Cash Withdrawal';
    return 'Other';
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.red,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E2530) : Colors.white;

    if (_importing) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Color(0xFF667eea)),
          const SizedBox(height: 16),
          Text('Importing $_importedCount / ${_selected.length}…',
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ));
    }

    // Results view
    if (_parsed.isNotEmpty) {
      return Column(children: [
        // Header bar
        Container(
          color: isDark ? const Color(0xFF1A1F2B) : Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(children: [
            Expanded(child: Text(
              '${_selected.length} of ${_parsed.length} selected',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            )),
            TextButton(
              onPressed: () => setState(() =>
                  _selected = _selected.length == _parsed.length ? [] : List.from(_parsed)),
              child: Text(_selected.length == _parsed.length ? 'Deselect all' : 'Select all'),
            ),
          ]),
        ),
        // List
        Expanded(child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
          itemCount: _parsed.length,
          itemBuilder: (ctx, i) {
            final p = _parsed[i];
            final sel = _selected.contains(p);
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
                border: sel
                    ? Border.all(color: const Color(0xFF667eea).withOpacity(0.4))
                    : null,
                boxShadow: [BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 6, offset: const Offset(0, 2))],
              ),
              child: CheckboxListTile(
                value: sel,
                activeColor: const Color(0xFF667eea),
                onChanged: (v) => setState(() {
                  if (v == true) _selected.add(p);
                  else _selected.remove(p);
                }),
                title: Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: p.isCredit
                          ? Colors.green.withOpacity(0.1)
                          : Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      p.isCredit ? '+ ₹${_fmt(p.amount)}' : '- ₹${_fmt(p.amount)}',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13,
                          color: p.isCredit ? Colors.green : Colors.red),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (p.bank != null)
                    Text(p.bank!, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                ]),
                subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 3),
                    Text(p.description, style: const TextStyle(fontSize: 12),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(DateFormat('d MMM yyyy, h:mm a').format(p.date),
                        style: TextStyle(fontSize: 10, color: Colors.grey[400])),
                  ],
                ),
              ),
            );
          },
        )),
        // Import button
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton.icon(
                onPressed: _selected.isEmpty ? null : _importSelected,
                icon: const Icon(Icons.download_rounded),
                label: Text('Import ${_selected.length} Transactions'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF667eea),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ),
        ),
      ]);
    }

    // Initial / empty state
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        const SizedBox(height: 20),
        // Icon
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            color: const Color(0xFF667eea).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.sms_rounded, color: Color(0xFF667eea), size: 36),
        ),
        const SizedBox(height: 16),
        const Text('SMS Auto-Import', style: TextStyle(
            fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(
          'Automatically reads your bank SMS messages\nand creates transactions.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Colors.grey[500]),
        ),
        const SizedBox(height: 24),

        // Supported banks
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
                blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Supported Banks', style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              'HDFC', 'ICICI', 'SBI', 'Kotak', 'Axis', 'Yes Bank',
              'IndusInd', 'IDFC', 'Federal', 'BOI', 'PNB', 'Canara',
              'GPay', 'PhonePe', 'Paytm',
            ].map((b) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF667eea).withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(b, style: const TextStyle(fontSize: 11,
                  color: Color(0xFF667eea), fontWeight: FontWeight.w600)),
            )).toList()),
          ]),
        ),
        const SizedBox(height: 16),

        // Days selector
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
                blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Read messages from last:', style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [7, 15, 30, 60, 90].map((d) {
                final sel = _daysBack == d;
                return GestureDetector(
                  onTap: () => setState(() => _daysBack = d),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: sel
                          ? const Color(0xFF667eea)
                          : const Color(0xFF667eea).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('$d days',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600,
                            color: sel ? Colors.white : const Color(0xFF667eea))),
                  ),
                );
              }).toList(),
            ),
          ]),
        ),
        const SizedBox(height: 16),

        // Note
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.withOpacity(0.3)),
          ),
          child: Row(children: [
            const Icon(Icons.info_outline, color: Colors.orange, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(
              'App only reads SMS — it cannot send or delete messages. '
              'You review & approve before import.',
              style: TextStyle(fontSize: 12, color: Colors.orange[700]),
            )),
          ]),
        ),
        const SizedBox(height: 24),

        if (_loading) ...[
          const CircularProgressIndicator(color: Color(0xFF667eea)),
          const SizedBox(height: 12),
          Text(_status, style: TextStyle(color: Colors.grey[500], fontSize: 13)),
        ] else
          SizedBox(
            width: double.infinity, height: 50,
            child: ElevatedButton.icon(
              onPressed: _readSms,
              icon: const Icon(Icons.sms_rounded),
              label: const Text('Read Bank SMS',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF667eea),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),

        if (!Platform.isAndroid) ...[
          const SizedBox(height: 12),
          Text('⚠️ SMS reading only works on Android app',
              style: TextStyle(fontSize: 12, color: Colors.orange[600])),
        ],
        const SizedBox(height: 40),
      ]),
    );
  }

  String _fmt(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }
}

// ════════════════════════════════════════════════════════════════════════════
// CSV IMPORT TAB
// ════════════════════════════════════════════════════════════════════════════
class _CsvImportTab extends StatefulWidget {
  final TransactionService txnSvc;
  final AccountService accSvc;
  const _CsvImportTab({required this.txnSvc, required this.accSvc});
  @override
  State<_CsvImportTab> createState() => _CsvImportTabState();
}

class _CsvImportTabState extends State<_CsvImportTab> {
  bool _loading = false;
  bool _importing = false;
  String _detectedBank = '';
  String? _fileName;
  List<_ParsedCsv> _rows = [];
  List<_ParsedCsv> _selected = [];
  List<AccountModel> _accounts = [];
  AccountModel? _targetAccount;
  int _importedCount = 0;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    final acc = await widget.accSvc.getAccountsList().first;
    if (mounted) setState(() {
      _accounts = acc;
      _targetAccount = acc.firstOrNull;
    });
  }

  Future<void> _pickFile() async {
    setState(() { _loading = true; _rows = []; _detectedBank = ''; });
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'CSV'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) {
        setState(() => _loading = false);
        return;
      }
      final file = result.files.first;
      setState(() => _fileName = file.name);
      final bytes = file.bytes;
      if (bytes == null) {
        setState(() => _loading = false);
        return;
      }
      final content = String.fromCharCodes(bytes);
      final rows = const CsvToListConverter(eol: '\n').convert(content);
      final parsed = BankCsvParser.parse(rows, file.name);
      setState(() {
        _rows = parsed.rows;
        _selected = List.from(parsed.rows);
        _detectedBank = parsed.bankName;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error reading file: $e'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _importSelected() async {
    if (_selected.isEmpty) return;
    if (_targetAccount == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please select a target account'),
        backgroundColor: Colors.red,
      ));
      return;
    }
    setState(() { _importing = true; _importedCount = 0; });
    int count = 0;
    for (final row in _selected) {
      final txn = TransactionModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: '',
        type: row.isCredit ? 'income' : 'expense',
        amount: row.amount,
        category: row.isCredit ? 'Other Income' : _guessCategory(row.description),
        date: row.date,
        note: row.description,
        fromAccount: row.isCredit ? null : _targetAccount!.id,
        toAccount: row.isCredit ? _targetAccount!.id : null,
      );
      await widget.txnSvc.addTransaction(txn);
      count++;
      if (mounted) setState(() => _importedCount = count);
    }
    if (mounted) {
      setState(() => _importing = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('✅ Imported $count transactions into ${_targetAccount!.name}'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ));
      setState(() { _rows = []; _selected = []; _fileName = null; });
    }
  }

  String _guessCategory(String desc) {
    final d = desc.toLowerCase();
    if (d.contains('swiggy') || d.contains('zomato') || d.contains('food')) return 'Food & Dining';
    if (d.contains('amazon') || d.contains('flipkart') || d.contains('myntra')) return 'Shopping';
    if (d.contains('uber') || d.contains('ola') || d.contains('irctc') || d.contains('metro')) return 'Transport';
    if (d.contains('netflix') || d.contains('spotify') || d.contains('hotstar') || d.contains('prime')) return 'Subscriptions';
    if (d.contains('apollo') || d.contains('hospital') || d.contains('pharmacy')) return 'Health';
    if (d.contains('electricity') || d.contains('gas') || d.contains('water')) return 'Bills & Utilities';
    if (d.contains('rent') || d.contains('maintenance')) return 'Rent';
    if (d.contains('salary') || d.contains('payroll')) return 'Salary';
    if (d.contains('atm')) return 'Cash Withdrawal';
    if (d.contains('upi')) return 'UPI Transfer';
    if (d.contains('neft') || d.contains('imps') || d.contains('rtgs')) return 'Bank Transfer';
    return 'Other';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E2530) : Colors.white;

    if (_importing) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Color(0xFF667eea)),
          const SizedBox(height: 16),
          Text('Importing $_importedCount / ${_selected.length}…',
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ));
    }

    // Results view
    if (_rows.isNotEmpty) {
      return Column(children: [
        // Header
        Container(
          color: isDark ? const Color(0xFF1A1F2B) : Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(children: [
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_fileName ?? 'CSV File',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  if (_detectedBank.isNotEmpty)
                    Text('Detected: $_detectedBank',
                        style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                ],
              )),
              TextButton(
                onPressed: () => setState(() =>
                    _selected = _selected.length == _rows.length ? [] : List.from(_rows)),
                child: Text(_selected.length == _rows.length ? 'Deselect all' : 'Select all'),
              ),
            ]),
            const SizedBox(height: 8),
            // Account selector
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF667eea).withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF667eea).withOpacity(0.2)),
              ),
              child: Row(children: [
                const Icon(Icons.account_balance_wallet_rounded,
                    size: 14, color: Color(0xFF667eea)),
                const SizedBox(width: 8),
                const Text('Import into:', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 8),
                Expanded(child: DropdownButtonHideUnderline(
                  child: DropdownButton<AccountModel>(
                    value: _targetAccount,
                    isDense: true,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold,
                        color: Color(0xFF667eea)),
                    items: _accounts.map((a) => DropdownMenuItem(
                      value: a,
                      child: Text(a.name),
                    )).toList(),
                    onChanged: (a) => setState(() => _targetAccount = a),
                  ),
                )),
                Text('${_selected.length} selected',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              ]),
            ),
          ]),
        ),
        // List
        Expanded(child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
          itemCount: _rows.length,
          itemBuilder: (ctx, i) {
            final row = _rows[i];
            final sel = _selected.contains(row);
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
                border: sel
                    ? Border.all(color: const Color(0xFF667eea).withOpacity(0.4))
                    : null,
                boxShadow: [BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 6, offset: const Offset(0, 2))],
              ),
              child: CheckboxListTile(
                value: sel,
                activeColor: const Color(0xFF667eea),
                onChanged: (v) => setState(() {
                  if (v == true) _selected.add(row);
                  else _selected.remove(row);
                }),
                title: Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: row.isCredit
                          ? Colors.green.withOpacity(0.1)
                          : Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      row.isCredit ? '+ ₹${_fmt(row.amount)}' : '- ₹${_fmt(row.amount)}',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13,
                          color: row.isCredit ? Colors.green : Colors.red),
                    ),
                  ),
                ]),
                subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 3),
                    Text(row.description, style: const TextStyle(fontSize: 12),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(DateFormat('d MMM yyyy').format(row.date),
                        style: TextStyle(fontSize: 10, color: Colors.grey[400])),
                  ],
                ),
              ),
            );
          },
        )),
        // Import button
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton.icon(
                onPressed: _selected.isEmpty ? null : _importSelected,
                icon: const Icon(Icons.download_rounded),
                label: Text('Import ${_selected.length} Transactions'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF667eea),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ),
        ),
      ]);
    }

    // Initial state
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        const SizedBox(height: 20),
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            color: Colors.teal.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.table_chart_rounded, color: Colors.teal, size: 36),
        ),
        const SizedBox(height: 16),
        const Text('Bank CSV Import', style: TextStyle(
            fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(
          'Import your bank statement CSV directly\nfrom net banking.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Colors.grey[500]),
        ),
        const SizedBox(height: 24),

        // Supported banks
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
                blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('How to get your CSV', style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 12),
            ...[
              ('🏦', 'HDFC',    'Net Banking → My Accounts → Download → CSV'),
              ('🏦', 'ICICI',   'Net Banking → Account → Statement → Download CSV'),
              ('🏦', 'SBI',     'YONO → Statements → Download → CSV'),
              ('🏦', 'Kotak',   'Net Banking → Account Summary → Download CSV'),
              ('🏦', 'Axis',    'Net Banking → Account → E-Statements → CSV'),
              ('🏦', 'Yes Bank','Net Banking → Accounts → Download Statement → CSV'),
            ].map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                Text(item.$1, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(item.$2, style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 12)),
                  Text(item.$3, style: TextStyle(
                      fontSize: 10, color: Colors.grey[500])),
                ]),
              ]),
            )),
          ]),
        ),
        const SizedBox(height: 24),

        if (_loading)
          const CircularProgressIndicator(color: Colors.teal)
        else
          SizedBox(
            width: double.infinity, height: 50,
            child: ElevatedButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.upload_file_rounded),
              label: const Text('Choose CSV File',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        const SizedBox(height: 40),
      ]),
    );
  }

  String _fmt(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }
}

// ════════════════════════════════════════════════════════════════════════════
// SMS PARSER
// ════════════════════════════════════════════════════════════════════════════
class _ParsedSms {
  final double amount;
  final bool isCredit;
  final DateTime date;
  final String description;
  final String? bank;
  final String? accountLast4;

  const _ParsedSms({
    required this.amount, required this.isCredit, required this.date,
    required this.description, this.bank, this.accountLast4,
  });
}

class SmsParser {
  static final _amountPatterns = [
    RegExp(r'(?:INR|Rs\.?|₹)\s*([\d,]+(?:\.\d{1,2})?)', caseSensitive: false),
    RegExp(r'([\d,]+(?:\.\d{1,2})?)\s*(?:INR|Rs\.?|₹)', caseSensitive: false),
  ];

  static final _debitKeywords = RegExp(
      r'\b(?:debited|debit|withdrawn|spent|paid|payment|purchase|deducted|dr\b)',
      caseSensitive: false);

  static final _creditKeywords = RegExp(
      r'\b(?:credited|credit|received|deposited|refund|cashback|cr\b)',
      caseSensitive: false);

  static final _bankSenders = {
    'HDFCBK': 'HDFC', 'HDFC':    'HDFC',
    'ICICIB': 'ICICI','ICICI':   'ICICI',
    'SBIINB': 'SBI',  'SBI':     'SBI',
    'KOTAKB': 'Kotak','KOTAK':   'Kotak',
    'AXISBK': 'Axis', 'AXIS':    'Axis',
    'YESBK':  'Yes Bank',
    'INDBNK': 'IndusInd',
    'IDFCBK': 'IDFC',
    'FEDBK':  'Federal',
    'CANBNK': 'Canara',
    'PNBSMS': 'PNB',
    'BOISMS': 'BOI',
    'GPAY':   'GPay',
    'PHONEPE':'PhonePe',
    'PAYTM':  'Paytm',
  };

  static final _acLast4 = RegExp(r'[Aa]/[Cc]\s*[Xx*]+(\d{4})|account\s*[Xx*]+(\d{4})',
      caseSensitive: false);

  static _ParsedSms? parse({
    required String body, required String sender, required int timestamp,
  }) {
    // Only bank messages
    final senderUp = sender.toUpperCase().replaceAll('-', '').replaceAll(' ', '');
    String? bankName;
    for (final entry in _bankSenders.entries) {
      if (senderUp.contains(entry.key)) { bankName = entry.value; break; }
    }
    // Also check body for bank name patterns
    if (bankName == null) {
      final bodyLower = body.toLowerCase();
      if (bodyLower.contains('hdfc'))    bankName = 'HDFC';
      else if (bodyLower.contains('icici')) bankName = 'ICICI';
      else if (bodyLower.contains('sbi'))   bankName = 'SBI';
      else if (bodyLower.contains('kotak')) bankName = 'Kotak';
      else if (bodyLower.contains('axis'))  bankName = 'Axis';
    }
    if (bankName == null) return null;

    // Extract amount
    double? amount;
    for (final pat in _amountPatterns) {
      final m = pat.firstMatch(body);
      if (m != null) {
        final s = (m.group(1) ?? m.group(0) ?? '').replaceAll(',', '');
        amount = double.tryParse(s);
        if (amount != null && amount > 0) break;
      }
    }
    if (amount == null || amount <= 0) return null;

    // Determine credit/debit
    final isCredit = _creditKeywords.hasMatch(body) && !_debitKeywords.hasMatch(body);

    // Account last 4
    final acMatch = _acLast4.firstMatch(body);
    final last4 = acMatch?.group(1) ?? acMatch?.group(2);

    // Date from timestamp
    final date = timestamp > 0
        ? DateTime.fromMillisecondsSinceEpoch(timestamp)
        : DateTime.now();

    // Clean description
    String desc = body.length > 120 ? body.substring(0, 120) : body;
    desc = desc.replaceAll(RegExp(r'\s+'), ' ').trim();

    return _ParsedSms(
      amount: amount, isCredit: isCredit, date: date,
      description: desc, bank: bankName, accountLast4: last4,
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// CSV PARSER
// ════════════════════════════════════════════════════════════════════════════
class _ParsedCsv {
  final double amount;
  final bool isCredit;
  final DateTime date;
  final String description;
  const _ParsedCsv({
    required this.amount, required this.isCredit,
    required this.date, required this.description,
  });
}

class _CsvParseResult {
  final List<_ParsedCsv> rows;
  final String bankName;
  const _CsvParseResult(this.rows, this.bankName);
}

class BankCsvParser {
  static _CsvParseResult parse(List<List<dynamic>> raw, String fileName) {
    if (raw.isEmpty) return const _CsvParseResult([], 'Unknown');

    // Find header row (first non-empty row with text)
    int headerIdx = 0;
    for (int i = 0; i < raw.length && i < 10; i++) {
      final row = raw[i];
      if (row.any((c) => c.toString().trim().isNotEmpty &&
          RegExp(r'[a-zA-Z]').hasMatch(c.toString()))) {
        headerIdx = i;
        break;
      }
    }

    final headers = raw[headerIdx]
        .map((h) => h.toString().trim().toLowerCase())
        .toList();

    // Detect bank
    final bankName = _detectBank(headers, fileName, raw);

    // Find column indices
    final dateCol    = _findCol(headers, ['date', 'tran date', 'txn date', 'transaction date', 'value date']);
    final descCol    = _findCol(headers, ['description', 'narration', 'particulars', 'transaction remarks', 'remarks', 'details']);
    final debitCol   = _findCol(headers, ['debit', 'withdrawal', 'dr', 'withdrawal amt', 'debit amount', 'withdrawal amount (inr)']);
    final creditCol  = _findCol(headers, ['credit', 'deposit', 'cr', 'deposit amt', 'credit amount', 'deposit amount (inr)']);
    final amountCol  = _findCol(headers, ['amount', 'transaction amount']);
    final typeCol    = _findCol(headers, ['type', 'cr/dr', 'dr/cr', 'transaction type']);

    final rows = <_ParsedCsv>[];
    for (int i = headerIdx + 1; i < raw.length; i++) {
      final row = raw[i];
      if (row.length <= 1) continue;

      // Parse date
      DateTime? date;
      if (dateCol >= 0 && dateCol < row.length) {
        date = _parseDate(row[dateCol].toString().trim());
      }
      if (date == null) continue;

      // Parse description
      String desc = '';
      if (descCol >= 0 && descCol < row.length) {
        desc = row[descCol].toString().trim();
      }
      if (desc.isEmpty) continue;

      // Parse amount & direction
      double? amount;
      bool isCredit = false;

      if (debitCol >= 0 && creditCol >= 0) {
        // Separate debit/credit columns
        final dStr = debitCol < row.length ? row[debitCol].toString().trim() : '';
        final cStr = creditCol < row.length ? row[creditCol].toString().trim() : '';
        final debit  = _parseAmount(dStr);
        final credit = _parseAmount(cStr);
        if (credit != null && credit > 0) { amount = credit; isCredit = true; }
        else if (debit != null && debit > 0) { amount = debit; isCredit = false; }
      } else if (amountCol >= 0) {
        amount = _parseAmount(amountCol < row.length ? row[amountCol].toString() : '');
        if (typeCol >= 0 && typeCol < row.length) {
          final t = row[typeCol].toString().trim().toLowerCase();
          isCredit = t == 'cr' || t == 'credit' || t.contains('credit');
        }
      }

      if (amount == null || amount <= 0) continue;
      rows.add(_ParsedCsv(amount: amount, isCredit: isCredit, date: date, description: desc));
    }

    return _CsvParseResult(rows, bankName);
  }

  static String _detectBank(List<String> headers, String fileName, List<List<dynamic>> raw) {
    final allText = (headers.join(' ') + fileName + raw.take(5).map((r) => r.join(' ')).join(' ')).toLowerCase();
    if (allText.contains('hdfc'))    return 'HDFC Bank';
    if (allText.contains('icici'))   return 'ICICI Bank';
    if (allText.contains('sbi') || allText.contains('state bank')) return 'SBI';
    if (allText.contains('kotak'))   return 'Kotak Bank';
    if (allText.contains('axis'))    return 'Axis Bank';
    if (allText.contains('yes bank') || allText.contains('yesbank')) return 'Yes Bank';
    if (allText.contains('indusind')) return 'IndusInd Bank';
    if (allText.contains('federal')) return 'Federal Bank';
    if (allText.contains('idfc'))    return 'IDFC Bank';
    if (allText.contains('canara'))  return 'Canara Bank';
    if (allText.contains('pnb') || allText.contains('punjab national')) return 'PNB';
    return 'Unknown Bank';
  }

  static int _findCol(List<String> headers, List<String> names) {
    for (final name in names) {
      for (int i = 0; i < headers.length; i++) {
        if (headers[i].contains(name)) return i;
      }
    }
    return -1;
  }

  static DateTime? _parseDate(String s) {
    if (s.isEmpty) return null;
    s = s.trim();
    final formats = [
      'dd/MM/yyyy', 'dd-MM-yyyy', 'MM/dd/yyyy',
      'yyyy-MM-dd', 'dd MMM yyyy', 'd MMM yyyy',
      'dd/MM/yy', 'dd-MM-yy', 'MM/dd/yy',
    ];
    for (final fmt in formats) {
      try { return DateFormat(fmt).parseStrict(s); } catch (_) {}
    }
    return null;
  }

  static double? _parseAmount(String s) {
    if (s.isEmpty || s == '-' || s.toLowerCase() == 'nil') return null;
    final clean = s.replaceAll(',', '').replaceAll('₹', '').replaceAll('INR', '')
        .replaceAll('Rs', '').replaceAll(' ', '').trim();
    if (clean.isEmpty) return null;
    return double.tryParse(clean);
  }
}