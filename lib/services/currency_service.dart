import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import '../models/currency_model.dart';

class CurrencyService extends ChangeNotifier {
  static final CurrencyService _instance = CurrencyService._internal();
  factory CurrencyService() => _instance;
  CurrencyService._internal();

  CurrencyModel _selectedCurrency = CurrencyModel.currencies[0]; // Default INR
  CurrencyModel get selectedCurrency => _selectedCurrency;

  Future<void> loadCurrency() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString('currencyCode') ?? 'INR';
    _selectedCurrency =
        CurrencyModel.findByCode(code) ?? CurrencyModel.currencies[0];
    notifyListeners();
  }

  Future<void> setCurrency(CurrencyModel currency) async {
    _selectedCurrency = currency;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('currencyCode', currency.code);
    notifyListeners();
  }

  String formatAmount(double amount, {bool showSymbol = true}) {
    if (showSymbol) {
      return '${_selectedCurrency.symbol}${amount.toStringAsFixed(2)}';
    }
    return amount.toStringAsFixed(2);
  }

  double convertToSelectedCurrency(double amountInINR) {
    return _selectedCurrency.convertFromINR(amountInINR);
  }

  double convertToINR(double amount) {
    return _selectedCurrency.convertToINR(amount);
  }
}
