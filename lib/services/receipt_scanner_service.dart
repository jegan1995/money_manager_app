import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ScannedReceiptData {
  final double? amount;
  final String? merchant;
  final String? category;
  final String? date; // ISO string yyyy-MM-dd
  final String? note;
  final String? paymentMethod;
  final String rawResponse;
  final bool success;
  final String? error;

  const ScannedReceiptData({
    this.amount,
    this.merchant,
    this.category,
    this.date,
    this.note,
    this.paymentMethod,
    required this.rawResponse,
    required this.success,
    this.error,
  });
}

class ReceiptScannerService {
  static const _geminiUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent';

  static const _validCategories = [
    'Food & Dining',
    'Transportation',
    'Shopping',
    'Entertainment',
    'Bills & Utilities',
    'Healthcare',
    'Education',
    'Personal Care',
    'Travel',
    'Groceries',
    'Rent',
    'Insurance',
    'Subscriptions',
    'Gifts',
    'Business',
    'Investments',
    'Others',
  ];

  static const _validPaymentMethods = [
    'Cash',
    'Credit Card',
    'Debit Card',
    'UPI',
    'Net Banking',
    'Wallet',
  ];

  Future<String?> _getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('gemini_api_key');
  }

  /// Scan a receipt image and extract transaction data
  Future<ScannedReceiptData> scanReceipt(Uint8List imageBytes) async {
    final apiKey = await _getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      return const ScannedReceiptData(
        rawResponse: '',
        success: false,
        error: 'No Gemini API key found. Go to Settings → Gemini API to add your key.',
      );
    }

    final base64Image = base64Encode(imageBytes);

    const prompt = '''
You are a receipt scanner. Extract information from this receipt image and respond ONLY with a valid JSON object. No explanation, no markdown, just the raw JSON.

Extract these fields:
- amount: total amount paid as a number (e.g. 245.50). Look for "Total", "Grand Total", "Amount Paid", "Net Amount". Return null if not found.
- merchant: store/restaurant/vendor name as a string. Return null if not found.
- category: pick ONE from this exact list: ["Food & Dining","Transportation","Shopping","Entertainment","Bills & Utilities","Healthcare","Education","Personal Care","Travel","Groceries","Rent","Insurance","Subscriptions","Gifts","Business","Investments","Others"]. Guess based on merchant name if not obvious.
- date: transaction date as "yyyy-MM-dd" string. Look for date on receipt. Return null if not found.
- note: short description like "Lunch at Saravana Bhavan" or "Grocery at DMart". Max 50 chars.
- payment_method: pick ONE from ["Cash","Credit Card","Debit Card","UPI","Net Banking","Wallet"] if visible on receipt. Return null if not found.

Respond with exactly this JSON format:
{"amount":245.50,"merchant":"Saravana Bhavan","category":"Food & Dining","date":"2025-03-15","note":"Lunch at Saravana Bhavan","payment_method":"UPI"}
''';

    try {
      final response = await http
          .post(
            Uri.parse('$_geminiUrl?key=$apiKey'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'contents': [
                {
                  'parts': [
                    {
                      'inline_data': {
                        'mime_type': 'image/jpeg',
                        'data': base64Image,
                      }
                    },
                    {'text': prompt}
                  ]
                }
              ],
              'generationConfig': {
                'temperature': 0.1,
                'maxOutputTokens': 300,
              }
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        return ScannedReceiptData(
          rawResponse: response.body,
          success: false,
          error: 'API error ${response.statusCode}. Check your API key.',
        );
      }

      final data = jsonDecode(response.body);
      final text =
          data['candidates'][0]['content']['parts'][0]['text'] as String;

      // Clean up any markdown wrapping
      final cleaned = text
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();

      final parsed = jsonDecode(cleaned) as Map<String, dynamic>;

      // Validate category
      final rawCat = parsed['category'] as String?;
      final category = _validCategories.contains(rawCat) ? rawCat : _guessCategory(parsed['merchant'] as String?);

      // Validate payment method
      final rawPay = parsed['payment_method'] as String?;
      final paymentMethod = _validPaymentMethods.contains(rawPay) ? rawPay : null;

      // Parse amount
      double? amount;
      final rawAmount = parsed['amount'];
      if (rawAmount != null) {
        amount = (rawAmount as num).toDouble();
        if (amount <= 0) amount = null;
      }

      return ScannedReceiptData(
        amount: amount,
        merchant: parsed['merchant'] as String?,
        category: category,
        date: parsed['date'] as String?,
        note: parsed['note'] as String?,
        paymentMethod: paymentMethod,
        rawResponse: cleaned,
        success: true,
      );
    } catch (e) {
      return ScannedReceiptData(
        rawResponse: '',
        success: false,
        error: 'Could not read receipt. Try a clearer photo.\n\nError: ${e.toString().substring(0, e.toString().length.clamp(0, 100))}',
      );
    }
  }

  String? _guessCategory(String? merchant) {
    if (merchant == null) return 'Others';
    final m = merchant.toLowerCase();
    if (m.contains('restaurant') || m.contains('cafe') || m.contains('hotel') ||
        m.contains('food') || m.contains('dhaba') || m.contains('biryani') ||
        m.contains('pizza') || m.contains('burger') || m.contains('swiggy') ||
        m.contains('zomato')) return 'Food & Dining';
    if (m.contains('mart') || m.contains('supermarket') || m.contains('grocery') ||
        m.contains('big bazaar') || m.contains('dmart') ||
        m.contains('reliance')) return 'Groceries';
    if (m.contains('uber') || m.contains('ola') || m.contains('rapido') ||
        m.contains('metro') || m.contains('bus') || m.contains('petrol') ||
        m.contains('fuel')) return 'Transportation';
    if (m.contains('hospital') || m.contains('clinic') || m.contains('pharmacy') ||
        m.contains('medical') || m.contains('apollo')) return 'Healthcare';
    if (m.contains('amazon') || m.contains('flipkart') || m.contains('myntra') ||
        m.contains('shop') || m.contains('store') ||
        m.contains('mall')) return 'Shopping';
    if (m.contains('airtel') || m.contains('jio') || m.contains('bsnl') ||
        m.contains('electricity') || m.contains('water') ||
        m.contains('bill')) return 'Bills & Utilities';
    if (m.contains('netflix') || m.contains('prime') || m.contains('hotstar') ||
        m.contains('spotify') || m.contains('youtube')) return 'Subscriptions';
    return 'Others';
  }
}