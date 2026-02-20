class CurrencyModel {
  final String code;
  final String name;
  final String symbol;
  final double exchangeRate; // Relative to INR

  const CurrencyModel({
    required this.code,
    required this.name,
    required this.symbol,
    this.exchangeRate = 1.0,
  });

  static const List<CurrencyModel> currencies = [
    CurrencyModel(
        code: 'INR', name: 'Indian Rupee', symbol: '₹', exchangeRate: 1.0),
    CurrencyModel(
        code: 'USD', name: 'US Dollar', symbol: '\$', exchangeRate: 83.0),
    CurrencyModel(code: 'EUR', name: 'Euro', symbol: '€', exchangeRate: 90.0),
    CurrencyModel(
        code: 'GBP', name: 'British Pound', symbol: '£', exchangeRate: 105.0),
    CurrencyModel(
        code: 'AED', name: 'UAE Dirham', symbol: 'د.إ', exchangeRate: 22.6),
    CurrencyModel(
        code: 'SAR', name: 'Saudi Riyal', symbol: '﷼', exchangeRate: 22.1),
    CurrencyModel(
        code: 'JPY', name: 'Japanese Yen', symbol: '¥', exchangeRate: 0.56),
    CurrencyModel(
        code: 'CNY', name: 'Chinese Yuan', symbol: '¥', exchangeRate: 11.5),
    CurrencyModel(
        code: 'AUD',
        name: 'Australian Dollar',
        symbol: 'A\$',
        exchangeRate: 54.0),
    CurrencyModel(
        code: 'CAD',
        name: 'Canadian Dollar',
        symbol: 'C\$',
        exchangeRate: 61.0),
  ];

  static CurrencyModel? findByCode(String code) {
    try {
      return currencies.firstWhere((c) => c.code == code);
    } catch (e) {
      return null;
    }
  }

  double convertToINR(double amount) {
    return amount * exchangeRate;
  }

  double convertFromINR(double amountInINR) {
    return amountInINR / exchangeRate;
  }

  static double convert(double amount, String fromCode, String toCode) {
    final fromCurrency = findByCode(fromCode) ?? currencies[0];
    final toCurrency = findByCode(toCode) ?? currencies[0];

    // Convert to INR first, then to target currency
    final inrAmount = fromCurrency.convertToINR(amount);
    return toCurrency.convertFromINR(inrAmount);
  }
}
