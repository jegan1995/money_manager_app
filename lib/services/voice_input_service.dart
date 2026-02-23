import '../models/account_model.dart';

/// Parses natural language voice input into transaction fields.
/// Works fully offline — no API needed.
///
/// Examples it understands:
///   "add 200 petrol expense from SBI account"
///   "spent 500 on food today"
///   "received 50000 salary in HDFC"
///   "transfer 1000 from SBI to HDFC"
///   "paid 1500 electricity bill"
///   "zomato 350 food"
class VoiceParseResult {
  final double? amount;
  final String? type; // income | expense | transfer
  final String? category;
  final String? subcategory;
  final String? fromAccount; // account id
  final String? toAccount; // account id (transfer only)
  final String? note;
  final DateTime? date;
  final double confidence; // 0.0 – 1.0

  const VoiceParseResult({
    this.amount,
    this.type,
    this.category,
    this.subcategory,
    this.fromAccount,
    this.toAccount,
    this.note,
    this.date,
    this.confidence = 0.0,
  });
}

class VoiceInputService {
  // ── Keyword maps ─────────────────────────────────────────────────────────────

  static const _incomeKeywords = [
    'received', 'receive', 'got', 'earned', 'income', 'salary', 'credited',
    'credit', 'bonus', 'dividend', 'interest', 'refund', 'cashback',
    'freelance', 'payment received', 'deposited',
  ];

  static const _expenseKeywords = [
    'spent', 'spend', 'paid', 'pay', 'bought', 'buy', 'purchased', 'expense',
    'debit', 'debited', 'withdrew', 'withdrawal', 'added', 'add',
  ];

  static const _transferKeywords = [
    'transfer', 'transferred', 'send', 'sent', 'move', 'moved',
  ];

  /// Category → keywords mapping (expense)
  static const Map<String, List<String>> _expenseCategoryKeywords = {
    'Food & Dining': [
      'food', 'dinner', 'lunch', 'breakfast', 'restaurant', 'hotel',
      'café', 'cafe', 'coffee', 'tea', 'biryani', 'pizza', 'burger',
      'swiggy', 'zomato', 'groceries', 'grocery', 'supermarket', 'vegetables',
      'fruits', 'milk', 'bread', 'snacks', 'eating',
    ],
    'Transportation': [
      'petrol', 'diesel', 'fuel', 'gas', 'cng', 'auto', 'rickshaw',
      'taxi', 'cab', 'uber', 'ola', 'bus', 'train', 'metro', 'bike',
      'vehicle', 'car', 'parking', 'toll', 'rapido', 'transport',
    ],
    'Bills & Utilities': [
      'electricity', 'electric', 'power', 'water', 'internet', 'wifi',
      'broadband', 'phone', 'mobile', 'recharge', 'bill', 'rent',
      'maintenance', 'society', 'gas bill', 'dth', 'cable',
    ],
    'Healthcare': [
      'doctor', 'hospital', 'medicine', 'medical', 'pharmacy', 'clinic',
      'lab', 'test', 'health', 'gym', 'fitness', 'insurance',
    ],
    'Shopping': [
      'shopping', 'clothes', 'shirt', 'shoes', 'amazon', 'flipkart',
      'myntra', 'meesho', 'dress', 'jeans', 'bag', 'electronics',
      'mobile', 'laptop', 'watch', 'jewellery',
    ],
    'Entertainment': [
      'movie', 'cinema', 'netflix', 'hotstar', 'prime', 'spotify',
      'concert', 'game', 'games', 'sport', 'cricket', 'streaming',
      'subscription', 'ott',
    ],
    'Education': [
      'school', 'college', 'fees', 'tuition', 'course', 'book', 'books',
      'stationary', 'exam', 'coaching', 'class', 'training',
    ],
    'Travel': [
      'flight', 'hotel', 'trip', 'vacation', 'holiday', 'tour',
      'travel', 'outing', 'visit',
    ],
    'Personal Care': [
      'salon', 'haircut', 'spa', 'beauty', 'cosmetics', 'parlour',
    ],
  };

  /// Category → keywords mapping (income)
  static const Map<String, List<String>> _incomeCategoryKeywords = {
    'Salary': [
      'salary', 'sal', 'wages', 'stipend', 'paycheck', 'monthly salary',
    ],
    'Business': [
      'business', 'sales', 'profit', 'revenue', 'income', 'sale',
    ],
    'Freelance': [
      'freelance', 'freelancing', 'project', 'client', 'consulting',
    ],
    'Investments': [
      'dividend', 'interest', 'returns', 'mutual fund', 'stocks', 'fd',
      'rd', 'investment',
    ],
    'Gifts': [
      'gift', 'gifted', 'birthday', 'reward', 'prize',
    ],
    'Rental Income': [
      'rent', 'rental', 'tenant', 'lease',
    ],
  };

  /// Subcategory → keywords mapping
  static const Map<String, String> _subcategoryKeywords = {
    'petrol': 'Fuel',
    'diesel': 'Fuel',
    'fuel': 'Fuel',
    'cng': 'Fuel',
    'grocery': 'Groceries',
    'groceries': 'Groceries',
    'supermarket': 'Groceries',
    'restaurant': 'Restaurants',
    'hotel': 'Restaurants',
    'swiggy': 'Food Delivery',
    'zomato': 'Food Delivery',
    'electricity': 'Electricity',
    'water': 'Water',
    'internet': 'Internet',
    'wifi': 'Internet',
    'rent': 'Rent',
    'recharge': 'Phone',
    'doctor': 'Doctor',
    'medicine': 'Medicine',
    'pharmacy': 'Medicine',
    'gym': 'Gym',
    'insurance': 'Insurance',
    'uber': 'Taxi/Uber',
    'ola': 'Taxi/Uber',
    'cab': 'Taxi/Uber',
    'bus': 'Public Transport',
    'metro': 'Public Transport',
    'train': 'Public Transport',
    'parking': 'Parking',
    'salary': 'Monthly Salary',
    'bonus': 'Bonus',
    'dividend': 'Dividends',
    'interest': 'Interest',
    'netflix': 'Subscriptions',
    'hotstar': 'Subscriptions',
    'prime': 'Subscriptions',
    'spotify': 'Subscriptions',
    'movie': 'Movies',
    'cinema': 'Movies',
    'salon': 'Salon',
    'haircut': 'Salon',
    'tuition': 'Tuition',
    'school fees': 'Tuition',
    'college fees': 'Tuition',
  };

  // ── Main parse method ─────────────────────────────────────────────────────────

  VoiceParseResult parse(String input, List<AccountModel> accounts) {
    final text = input.toLowerCase().trim();
    final words = text.split(RegExp(r'\s+'));

    double score = 0.0;

    // 1. Extract amount
    final amount = _extractAmount(text);
    if (amount != null) score += 0.3;

    // 2. Detect type
    final type = _detectType(text);
    if (type != null) score += 0.2;

    // 3. Auto-categorize
    String? category;
    String? subcategory;
    final effectiveType = type ?? 'expense';

    if (effectiveType == 'income') {
      category = _matchCategory(text, _incomeCategoryKeywords);
    } else if (effectiveType == 'expense') {
      category = _matchCategory(text, _expenseCategoryKeywords);
    }
    if (category != null) score += 0.2;

    // 4. Subcategory from keyword map
    subcategory = _matchSubcategory(text);

    // 5. Match accounts
    String? fromAccount;
    String? toAccount;

    if (effectiveType == 'transfer') {
      final accs = _extractTransferAccounts(text, accounts);
      fromAccount = accs[0];
      toAccount = accs[1];
      if (fromAccount != null) score += 0.15;
      if (toAccount != null) score += 0.15;
    } else {
      fromAccount = _matchAccount(text, accounts);
      if (fromAccount != null) score += 0.2;
    }

    // 6. Build auto note from recognized keywords
    final note = _buildNote(text, words);

    return VoiceParseResult(
      amount: amount,
      type: effectiveType,
      category: category,
      subcategory: subcategory,
      fromAccount: fromAccount,
      toAccount: toAccount,
      note: note,
      date: DateTime.now(),
      confidence: score.clamp(0.0, 1.0),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  double? _extractAmount(String text) {
    // Match patterns: "200", "1,500", "1.5k", "50000", "₹200"
    final patterns = [
      RegExp(r'₹\s*(\d+(?:[,\d]*)?(?:\.\d+)?)'),
      RegExp(r'rs\.?\s*(\d+(?:[,\d]*)?(?:\.\d+)?)'),
      RegExp(r'(\d+(?:[,\d]*)?(?:\.\d+)?)\s*k\b'), // 1.5k
      RegExp(r'(\d+(?:[,\d]*)?(?:\.\d+)?)\s*lakh'), // 1 lakh
      RegExp(r'\b(\d+(?:[,\d]*)?(?:\.\d+)?)\b'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        var raw = match.group(1)!.replaceAll(',', '');
        double? value = double.tryParse(raw);
        if (value != null) {
          if (pattern.pattern.contains('k\\b')) value *= 1000;
          if (pattern.pattern.contains('lakh')) value *= 100000;
          if (value > 0 && value < 10000000) return value;
        }
      }
    }
    return null;
  }

  String? _detectType(String text) {
    for (final kw in _transferKeywords) {
      if (text.contains(kw)) return 'transfer';
    }
    for (final kw in _incomeKeywords) {
      if (text.contains(kw)) return 'income';
    }
    for (final kw in _expenseKeywords) {
      if (text.contains(kw)) return 'expense';
    }
    return null; // will default to expense
  }

  String? _matchCategory(String text, Map<String, List<String>> map) {
    int bestScore = 0;
    String? bestCategory;
    for (final entry in map.entries) {
      int score = 0;
      for (final kw in entry.value) {
        if (text.contains(kw)) score++;
      }
      if (score > bestScore) {
        bestScore = score;
        bestCategory = entry.key;
      }
    }
    return bestCategory;
  }

  String? _matchSubcategory(String text) {
    for (final entry in _subcategoryKeywords.entries) {
      if (text.contains(entry.key)) return entry.value;
    }
    return null;
  }

  String? _matchAccount(String text, List<AccountModel> accounts) {
    String? bestId;
    int bestScore = 0;

    for (final acc in accounts) {
      final accName = acc.name.toLowerCase();
      int score = 0;

      // Exact full name match = highest priority
      if (text.contains(accName)) {
        score += 20;
      } else {
        // Score each word in account name
        final nameWords = accName.split(RegExp(r'[\s_-]+'));
        int wordMatches = 0;
        for (final word in nameWords) {
          if (word.length > 1 && text.contains(word)) {
            wordMatches++;
            score += 3;
          }
        }
        // Bonus: consecutive word matches (phrase match)
        if (wordMatches >= 2) score += wordMatches * 2;
      }

      // Account type keywords (cc, sb, savings, current, credit)
      final typeAbbreviations = {
        'cc': ['credit card', 'credit', 'cc'],
        'sb': ['savings', 'saving', 'sb'],
        'ca': ['current', 'ca'],
        'fd': ['fixed deposit', 'fd'],
        'wallet': ['wallet', 'paytm', 'gpay'],
        'cash': ['cash'],
        'loan': ['loan', 'emi'],
      };

      for (final entry in typeAbbreviations.entries) {
        for (final kw in entry.value) {
          if (accName.contains(kw) && text.contains(entry.key)) score += 5;
          if (accName.contains(kw) && text.contains(kw)) score += 5;
        }
      }

      if (score > bestScore) {
        bestScore = score;
        bestId = acc.id;
      }
    }
    // Only return if we have reasonable confidence
    return bestScore >= 3 ? bestId : null;
  }

  List<String?> _extractTransferAccounts(
      String text, List<AccountModel> accounts) {
    // "transfer X from A to B"
    String? fromId;
    String? toId;

    final fromMatch =
        RegExp(r'from\s+(.+?)\s+to\s+').firstMatch(text);
    final toMatch = RegExp(r'\bto\s+(.+)$').firstMatch(text);

    if (fromMatch != null) {
      final fromHint = fromMatch.group(1)!;
      fromId = _matchAccount(fromHint, accounts);
    }
    if (toMatch != null) {
      final toHint = toMatch.group(1)!;
      toId = _matchAccount(toHint, accounts);
    }

    return [fromId, toId];
  }

  String _buildNote(String text, List<String> words) {
    // Remove amount numbers and common filler words to create a clean note
    final fillers = {
      'add', 'added', 'spent', 'paid', 'received', 'got', 'transfer',
      'transferred', 'from', 'to', 'in', 'on', 'at', 'the', 'a', 'an',
      'my', 'for', 'and', 'with', 'expense', 'income', 'today', 'yesterday',
    };

    final noteWords = words.where((w) {
      if (fillers.contains(w)) return false;
      if (RegExp(r'^\d+([,\d]*(\.\d+)?)?$').hasMatch(w)) return false;
      return w.length > 1;
    }).toList();

    return noteWords.join(' ');
  }
}