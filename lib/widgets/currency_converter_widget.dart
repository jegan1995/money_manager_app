import 'package:flutter/material.dart';
import '../models/currency_model.dart';

class CurrencyConverterWidget extends StatefulWidget {
  const CurrencyConverterWidget({super.key});

  @override
  State<CurrencyConverterWidget> createState() =>
      _CurrencyConverterWidgetState();
}

class _CurrencyConverterWidgetState extends State<CurrencyConverterWidget> {
  final TextEditingController _amountController = TextEditingController();
  CurrencyModel _fromCurrency = CurrencyModel.currencies[0];
  CurrencyModel _toCurrency = CurrencyModel.currencies[1];
  double _result = 0;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _convert() {
    final amount = double.tryParse(_amountController.text) ?? 0;
    setState(() {
      _result =
          CurrencyModel.convert(amount, _fromCurrency.code, _toCurrency.code);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Currency Converter',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (value) => _convert(),
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<CurrencyModel>(
                value: _fromCurrency,
                items: CurrencyModel.currencies.map((currency) {
                  return DropdownMenuItem(
                    value: currency,
                    child: Text(currency.code),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _fromCurrency = value!;
                    _convert();
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.swap_vert, color: Colors.blue),
                onPressed: () {
                  setState(() {
                    final temp = _fromCurrency;
                    _fromCurrency = _toCurrency;
                    _toCurrency = temp;
                    _convert();
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Converted Amount',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_toCurrency.symbol}${_result.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<CurrencyModel>(
                value: _toCurrency,
                items: CurrencyModel.currencies.map((currency) {
                  return DropdownMenuItem(
                    value: currency,
                    child: Text(currency.code),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _toCurrency = value!;
                    _convert();
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
