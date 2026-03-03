// lib/screens/receipt_scanner_screen.dart
// Receipt Scanner — AI-powered receipt reading using Claude Vision API
// Pick photo → Claude extracts amount/merchant/category/date → pre-fills form
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../config/app_config.dart';
import 'package:flutter/services.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../models/transaction_model.dart';
import '../models/account_model.dart';
import '../services/transaction_service.dart';
import '../services/account_service.dart';

// ── Extracted receipt data model ──────────────────────────────────────────────
class ReceiptData {
  final double?  amount;
  final String?  merchant;
  final String?  category;
  final DateTime? date;
  final String?  note;
  final List<ReceiptItem> items;

  const ReceiptData({
    this.amount,   this.merchant, this.category,
    this.date,     this.note,     this.items = const [],
  });

  factory ReceiptData.fromJson(Map<String, dynamic> j) {
    DateTime? parsedDate;
    try {
      if (j['date'] != null && (j['date'] as String).isNotEmpty) {
        parsedDate = DateTime.parse(j['date'] as String);
      }
    } catch (_) {}

    return ReceiptData(
      amount:   (j['amount'] as num?)?.toDouble(),
      merchant: j['merchant'] as String?,
      category: j['category'] as String?,
      date:     parsedDate,
      note:     j['note'] as String?,
      items:    (j['items'] as List<dynamic>? ?? [])
          .map((i) => ReceiptItem.fromJson(i as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ReceiptItem {
  final String name;
  final double amount;
  const ReceiptItem({required this.name, required this.amount});
  factory ReceiptItem.fromJson(Map<String, dynamic> j) => ReceiptItem(
        name:   j['name'] as String? ?? '',
        amount: (j['amount'] as num?)?.toDouble() ?? 0,
      );
}

// ════════════════════════════════════════════════════════════════════════════
class ReceiptScannerScreen extends StatefulWidget {
  const ReceiptScannerScreen({super.key});
  @override
  State<ReceiptScannerScreen> createState() =>
      _ReceiptScannerScreenState();
}

class _ReceiptScannerScreenState extends State<ReceiptScannerScreen> {
  final _picker    = ImagePicker();
  final _txnSvc    = TransactionService();
  final _accSvc    = AccountService();

  Uint8List?   _imageBytes;
  ReceiptData? _receipt;
  String?      _error;
  bool         _scanning  = false;
  bool         _saving    = false;

  // Form controllers — pre-filled from scan
  final _amountCtrl   = TextEditingController();
  final _merchantCtrl = TextEditingController();
  final _noteCtrl     = TextEditingController();
  String  _category    = 'Shopping';
  String  _type        = 'expense';
  DateTime _date       = DateTime.now();
  String?  _fromAccount;
  List<AccountModel> _accounts = [];

  static const _categories = [
    'Food & Dining', 'Shopping', 'Transport', 'Health',
    'Entertainment', 'Bills', 'Groceries', 'Travel',
    'Education', 'Other',
  ];

  // ── Anthropic API key ────────────────────────────────────────────────────────
  // Stored in lib/config/app_config.dart (gitignored — never in git)
  static const _apiKey = AppConfig.anthropicApiKey;

  @override
  void initState() {
    super.initState();
    _accSvc.getAccounts().listen((list) {
      if (mounted) setState(() => _accounts = list);
    });
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _merchantCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  // ── Pick image ─────────────────────────────────────────────────────────────
  Future<void> _pick(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth:  800,
        maxHeight: 800,
        imageQuality: 50,   // Aggressive compression — receipt text still readable
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      setState(() {
        _imageBytes = bytes;
        _receipt    = null;
        _error      = null;
      });
      await _scan(bytes);
    } catch (e) {
      setState(() => _error = 'Could not open image: $e');
    }
  }

  // ── Call Claude Vision API ─────────────────────────────────────────────────
  Future<void> _scan(Uint8List bytes) async {
    // CORS fix: Anthropic API cannot be called directly from browsers.
    // On web, show a manual-fill message. Full AI works on Android APK.
    if (kIsWeb) {
      setState(() {
        _scanning = false;
        _error = null;
        // Create a dummy receipt so the form shows for manual entry
        _receipt = ReceiptData(
          amount: null,
          merchant: null,
          category: null,
          date: DateTime.now(),
          note: null,
          items: [],
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(children: [
            Icon(Icons.info_outline, color: Colors.white, size: 16),
            SizedBox(width: 8),
            Expanded(child: Text(
              'AI scan works on Android app. Fill details manually below.',
              style: TextStyle(fontSize: 12),
            )),
          ]),
          backgroundColor: Color(0xFF667eea),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    setState(() { _scanning = true; _error = null; });

    try {
      // Size guard — API rejects very large payloads
      // 800x800 @ quality 50 should be ~80-150KB; base64 is ~1.3x that
      if (bytes.length > 1500000) {
        // Over 1.5MB raw — too big, show friendly error
        setState(() {
          _scanning = false;
          _error = 'Image too large. Try again with a closer, cropped photo.';
        });
        return;
      }

      final base64Image = base64Encode(bytes);

      // Detect JPEG vs PNG from header bytes
      final mime = (bytes[0] == 0xFF && bytes[1] == 0xD8)
          ? 'image/jpeg' : 'image/png';

      final prompt = '''
You are a receipt parser. Extract the following from this receipt image and return ONLY a valid JSON object (no markdown, no explanation):

{
  "amount": <total amount as number, e.g. 450.00>,
  "merchant": "<store/restaurant name>",
  "category": "<one of: Food & Dining, Shopping, Transport, Health, Entertainment, Bills, Groceries, Travel, Education, Other>",
  "date": "<YYYY-MM-DD format, or empty string if not found>",
  "note": "<short description of purchase, max 60 chars>",
  "items": [
    {"name": "<item name>", "amount": <item price>},
    ...
  ]
}

Rules:
- amount must be the TOTAL (grand total / final amount paid)
- If no total found, sum the items
- category must be exactly one of the listed options
- items: list up to 5 main line items (skip tax/discount lines)
- Return ONLY the JSON, no other text
''';

      final response = await http.post(
        Uri.parse('https://api.anthropic.com/v1/messages'),
        headers: {
          'Content-Type':      'application/json',
          'x-api-key':         _apiKey,
          'anthropic-version': '2023-06-01',
        },
        body: jsonEncode({
          'model':      'claude-opus-4-5',
          'max_tokens': 512,
          'messages': [
            {
              'role': 'user',
              'content': [
                {
                  'type': 'image',
                  'source': {
                    'type':       'base64',
                    'media_type': mime,
                    'data':       base64Image,
                  },
                },
                {
                  'type': 'text',
                  'text': prompt,
                },
              ],
            }
          ],
        }),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('Request timed out. Check internet connection.'),
      );

      if (response.statusCode != 200) {
        throw Exception(
            'API error ${response.statusCode}: ${response.body}');
      }

      final body  = jsonDecode(response.body) as Map<String, dynamic>;
      final text  = (body['content'] as List).first['text'] as String;

      // Strip any accidental markdown fences
      final clean = text
          .replaceAll(RegExp(r'```json\s*'), '')
          .replaceAll(RegExp(r'```\s*'), '')
          .trim();

      final json    = jsonDecode(clean) as Map<String, dynamic>;
      final receipt = ReceiptData.fromJson(json);

      // Pre-fill form
      _amountCtrl.text   = receipt.amount != null
          ? receipt.amount!.toStringAsFixed(0) : '';
      _merchantCtrl.text = receipt.merchant ?? '';
      _noteCtrl.text     = receipt.note     ?? receipt.merchant ?? '';
      if (receipt.category != null &&
          _categories.contains(receipt.category)) {
        _category = receipt.category!;
      }
      if (receipt.date != null) _date = receipt.date!;

      setState(() { _receipt = receipt; _scanning = false; });
      HapticFeedback.lightImpact();
    } catch (e) {
      setState(() {
        _scanning = false;
        String errMsg = e.toString();
        if (errMsg.contains('Connection closed') || errMsg.contains('SocketException')) {
          errMsg = 'Connection dropped. Try a smaller/clearer photo.';
        } else if (errMsg.contains('401') || errMsg.contains('authentication')) {
          errMsg = 'API key error. Please contact support.';
        } else if (errMsg.contains('timed out')) {
          errMsg = 'Timed out. Try a smaller photo or check internet.';
        } else if (errMsg.length > 80) {
          errMsg = errMsg.substring(0, 80);
        }
        _error = 'Could not read receipt: $errMsg';
      });
    }
  }

  // ── Save transaction ───────────────────────────────────────────────────────
  Future<void> _save() async {
    if (_amountCtrl.text.trim().isEmpty) {
      _snack('Enter the amount', isError: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final txn = TransactionModel(
        id:          '',
        userId:      '',
        type:        _type,
        amount:      double.tryParse(_amountCtrl.text) ?? 0,
        category:    _category,
        date:        _date,
        note:        _noteCtrl.text.trim().isNotEmpty
            ? _noteCtrl.text.trim() : null,
        description: _merchantCtrl.text.trim().isNotEmpty
            ? _merchantCtrl.text.trim() : null,
        paymentMethod: 'Other',
        fromAccount: _type == 'expense' ? _fromAccount : null,
        toAccount:   _type == 'income'  ? _fromAccount : null,
        isRecurring: false,
        createdAt:   DateTime.now(),
      );
      await _txnSvc.addTransaction(txn);
      HapticFeedback.mediumImpact();
      if (mounted) {
        _snack('Transaction saved ✅');
        await Future.delayed(const Duration(milliseconds: 600));
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _saving = false);
      _snack('Failed to save: $e', isError: true);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : Colors.green,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ────────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final bg      = isDark ? const Color(0xFF0D1117) : const Color(0xFFF0F2F8);
    final cardBg  = isDark ? const Color(0xFF1E2530) : Colors.white;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Receipt Scanner',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: isDark ? const Color(0xFF1E2530) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        elevation: 0,
        actions: [
          if (_receipt != null && !_saving)
            TextButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_rounded, size: 16),
              label: const Text('Save',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF667eea)),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Step 1: Image picker ────────────────────────────────────────
          _StepCard(
            step: 1, title: 'Scan Receipt',
            isDark: isDark, cardBg: cardBg,
            child: Column(children: [
              // ── Web notice banner ──────────────────────────────────────
              if (kIsWeb) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF667eea).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: const Color(0xFF667eea).withOpacity(0.3)),
                  ),
                  child: Row(children: [
                    const Text('📱', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 10),
                    const Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('AI Scan — Android Only',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: Color(0xFF667eea))),
                        SizedBox(height: 2),
                        Text(
                          'Upload a photo to fill details manually,\nor use the Android APK for full AI scanning.',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    )),
                  ]),
                ),
              ],

              // Image preview
              if (_imageBytes != null)
                Stack(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      _imageBytes!,
                      width: double.infinity,
                      height: 220,
                      fit: BoxFit.cover,
                    ),
                  ),
                  if (_scanning)
                    Positioned.fill(child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                        CircularProgressIndicator(
                            color: Colors.white),
                        SizedBox(height: 14),
                        Text('Reading receipt with AI...',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                      ]),
                    )),
                ])
              else
                GestureDetector(
                  onTap: () => _pick(ImageSource.gallery),
                  child: Container(
                    height: 180,
                    decoration: BoxDecoration(
                      color: const Color(0xFF667eea).withOpacity(0.06),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF667eea).withOpacity(0.3),
                        width: 2,
                        strokeAlign: BorderSide.strokeAlignCenter,
                      ),
                    ),
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                      const Icon(Icons.receipt_long_rounded,
                          size: 52,
                          color: Color(0xFF667eea)),
                      const SizedBox(height: 12),
                      const Text('Tap to choose a receipt photo',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Color(0xFF667eea))),
                      const SizedBox(height: 4),
                      Text('Camera or gallery',
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[500])),
                    ]),
                  ),
                ),

              const SizedBox(height: 14),

              // Action buttons
              Row(children: [
                Expanded(child: _pickerBtn(
                  Icons.camera_alt_rounded, 'Camera',
                  const Color(0xFF667eea),
                  () => _pick(ImageSource.camera),
                  isDark,
                )),
                const SizedBox(width: 12),
                Expanded(child: _pickerBtn(
                  Icons.photo_library_rounded, 'Gallery',
                  Colors.orange,
                  () => _pick(ImageSource.gallery),
                  isDark,
                )),
              ]),

              // Error message
              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(children: [
                    const Icon(Icons.error_outline,
                        color: Colors.red, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!,
                        style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12))),
                  ]),
                ),
              ],
            ]),
          ),

          // ── Step 2: Extracted data ──────────────────────────────────────
          if (_receipt != null) ...[
            const SizedBox(height: 16),
            _StepCard(
              step: 2,
              title: 'AI Extracted Data',
              isDark: isDark,
              cardBg: cardBg,
              badge: 'AI',
              child: Column(children: [
                // Success banner — different message for web vs Android
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: kIsWeb
                        ? const Color(0xFF667eea).withOpacity(0.08)
                        : Colors.green.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(children: [
                    Icon(
                      kIsWeb ? Icons.edit_note_rounded : Icons.auto_awesome_rounded,
                      color: kIsWeb ? const Color(0xFF667eea) : Colors.green,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(
                      kIsWeb
                          ? 'Photo uploaded. AI scan works on Android APK — fill details manually below.'
                          : 'Receipt scanned! Review and edit below.',
                      style: TextStyle(
                          color: kIsWeb ? const Color(0xFF667eea) : Colors.green[700],
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    )),
                  ]),
                ),

                // Items list
                if (_receipt!.items.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.04)
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(children: [
                      ..._receipt!.items.map((item) => Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 3),
                        child: Row(children: [
                          const Text('•  ',
                              style: TextStyle(
                                  color: Colors.grey)),
                          Expanded(child: Text(item.name,
                              style: const TextStyle(
                                  fontSize: 12))),
                          Text('₹${item.amount.toStringAsFixed(0)}',
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                        ]),
                      )),
                      Divider(color: Colors.grey.withOpacity(0.2),
                          height: 12),
                      Row(children: [
                        const Spacer(),
                        const Text('Total  ',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13)),
                        Text(
                          '₹${_receipt!.amount?.toStringAsFixed(0) ?? "?"}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Color(0xFF667eea))),
                      ]),
                    ]),
                  ),
                ],
              ]),
            ),

            // ── Step 3: Edit & confirm ──────────────────────────────────
            const SizedBox(height: 16),
            _StepCard(
              step: 3,
              title: 'Review & Save',
              isDark: isDark,
              cardBg: cardBg,
              child: Column(children: [
                // Type toggle
                Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.06)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(children: [
                    _typeTab('expense', '↑ Expense',
                        const Color(0xFFfa709a)),
                    _typeTab('income',  '↓ Income',
                        const Color(0xFF43e97b)),
                  ]),
                ),
                const SizedBox(height: 14),

                // Amount
                _formField(
                  _amountCtrl, '₹ Total Amount *',
                  isDark, num: true,
                  prefix: '₹',
                ),
                const SizedBox(height: 10),

                // Merchant
                _formField(
                  _merchantCtrl, 'Merchant / Store Name',
                  isDark,
                  cap: TextCapitalization.words,
                ),
                const SizedBox(height: 10),

                // Note
                _formField(
                  _noteCtrl, 'Note (auto-filled)',
                  isDark,
                  cap: TextCapitalization.sentences,
                ),
                const SizedBox(height: 12),

                // Category dropdown
                DropdownButtonFormField<String>(
                  value: _category,
                  decoration: InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: isDark
                        ? Colors.white.withOpacity(0.05)
                        : Colors.grey.shade50,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 14),
                  ),
                  items: _categories.map((c) =>
                      DropdownMenuItem(value: c, child: Text(c,
                          style: const TextStyle(fontSize: 13))))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _category = v ?? _category),
                ),
                const SizedBox(height: 10),

                // Date
                GestureDetector(
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (d != null) setState(() => _date = d);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 14),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.grey.shade50,
                      border: Border.all(
                          color: isDark
                              ? Colors.white24
                              : Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(children: [
                      Icon(Icons.calendar_today_rounded,
                          size: 14,
                          color: Colors.grey[500]),
                      const SizedBox(width: 10),
                      Text(DateFormat('d MMM y').format(_date),
                          style: const TextStyle(fontSize: 13)),
                      const Spacer(),
                      Icon(Icons.edit_rounded,
                          size: 14, color: Colors.grey[400]),
                    ]),
                  ),
                ),

                // Account
                if (_accounts.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: _fromAccount,
                    decoration: InputDecoration(
                      labelText: _type == 'expense'
                          ? 'Debit Account (optional)'
                          : 'Credit Account (optional)',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.grey.shade50,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 14),
                    ),
                    items: [
                      const DropdownMenuItem(
                          value: null,
                          child: Text('None',
                              style: TextStyle(fontSize: 13))),
                      ..._accounts.map((a) =>
                          DropdownMenuItem(
                              value: a.id,
                              child: Text(a.name,
                                  style: const TextStyle(
                                      fontSize: 13)))),
                    ],
                    onChanged: (v) =>
                        setState(() => _fromAccount = v),
                  ),
                ],

                const SizedBox(height: 20),

                // Save button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white))
                        : const Icon(Icons.save_rounded),
                    label: Text(
                      _saving ? 'Saving...' : 'Save Transaction',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF667eea),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          const Color(0xFF667eea).withOpacity(0.6),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ]),
            ),
          ],

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _typeTab(String type, String label, Color color) {
    final sel = _type == type;
    return Expanded(child: GestureDetector(
      onTap: () => setState(() => _type = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: sel ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(child: Text(label,
            style: TextStyle(
                color: sel ? Colors.white : Colors.grey,
                fontWeight: sel
                    ? FontWeight.bold : FontWeight.normal,
                fontSize: 13))),
      ),
    ));
  }

  Widget _pickerBtn(IconData icon, String label, Color color,
      VoidCallback onTap, bool isDark) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: color.withOpacity(0.3), width: 1.5),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center,
              children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
          ]),
        ),
      );

  Widget _formField(
    TextEditingController ctrl,
    String label,
    bool isDark, {
    bool num = false,
    String? prefix,
    TextCapitalization cap = TextCapitalization.none,
  }) =>
      TextField(
        controller: ctrl,
        keyboardType: num
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        inputFormatters: num
            ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]
            : null,
        textCapitalization: cap,
        decoration: InputDecoration(
          labelText: label,
          prefixText: prefix,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: isDark
              ? Colors.white.withOpacity(0.05)
              : Colors.grey.shade50,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 14),
          labelStyle:
              const TextStyle(fontSize: 12),
        ),
        style: const TextStyle(fontSize: 13),
      );
}

// ── Step card wrapper ─────────────────────────────────────────────────────────
class _StepCard extends StatelessWidget {
  final int    step;
  final String title;
  final Widget child;
  final bool   isDark;
  final Color  cardBg;
  final String? badge;

  const _StepCard({
    required this.step,   required this.title,
    required this.child,  required this.isDark,
    required this.cardBg, this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 10, offset: const Offset(0, 4),
        )],
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        Row(children: [
          Container(
            width: 26, height: 26,
            decoration: const BoxDecoration(
              color: Color(0xFF667eea),
              shape: BoxShape.circle,
            ),
            child: Center(child: Text('$step',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12))),
          ),
          const SizedBox(width: 10),
          Text(title, style: const TextStyle(
              fontWeight: FontWeight.bold, fontSize: 15)),
          if (badge != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF667eea), Color(0xFF764ba2)]),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(badge!,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ]),
        const SizedBox(height: 16),
        child,
      ]),
    );
  }
}