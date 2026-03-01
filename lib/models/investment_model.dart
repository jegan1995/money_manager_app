// lib/models/investment_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class InvestmentModel {
  final String? id;
  final String  userId;
  final String  name;
  final String  type;        // stocks, mutual_fund, gold, fd, ppf, crypto, real_estate, other
  final double  invested;    // amount invested
  final double  currentValue;
  final double  quantity;    // units/shares/grams
  final double  buyPrice;    // per unit
  final String? symbol;      // stock ticker / fund code
  final String? broker;      // Zerodha, Groww, etc.
  final DateTime purchaseDate;
  final String? note;
  final DateTime createdAt;

  InvestmentModel({
    this.id,
    required this.userId,
    required this.name,
    required this.type,
    required this.invested,
    required this.currentValue,
    this.quantity = 1,
    this.buyPrice = 0,
    this.symbol,
    this.broker,
    required this.purchaseDate,
    this.note,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  double get returns      => currentValue - invested;
  double get returnsPct   => invested > 0 ? (returns / invested) * 100 : 0;
  bool   get isProfit     => returns >= 0;
  double get xirr         => returnsPct; // simplified

  Map<String, dynamic> toMap() => {
    'userId':       userId,
    'name':         name,
    'type':         type,
    'invested':     invested,
    'currentValue': currentValue,
    'quantity':     quantity,
    'buyPrice':     buyPrice,
    'symbol':       symbol,
    'broker':       broker,
    'purchaseDate': Timestamp.fromDate(purchaseDate),
    'note':         note,
    'createdAt':    Timestamp.fromDate(createdAt),
  };

  factory InvestmentModel.fromMap(Map<String, dynamic> m, String id) =>
      InvestmentModel(
        id:           id,
        userId:       m['userId'] ?? '',
        name:         m['name'] ?? '',
        type:         m['type'] ?? 'other',
        invested:     (m['invested'] ?? 0).toDouble(),
        currentValue: (m['currentValue'] ?? 0).toDouble(),
        quantity:     (m['quantity'] ?? 1).toDouble(),
        buyPrice:     (m['buyPrice'] ?? 0).toDouble(),
        symbol:       m['symbol'],
        broker:       m['broker'],
        purchaseDate: m['purchaseDate'] != null
            ? (m['purchaseDate'] as Timestamp).toDate()
            : DateTime.now(),
        note:         m['note'],
        createdAt:    m['createdAt'] != null
            ? (m['createdAt'] as Timestamp).toDate()
            : DateTime.now(),
      );

  factory InvestmentModel.fromFirestore(DocumentSnapshot doc) =>
      InvestmentModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);

  InvestmentModel copyWith({
    String? id, String? userId, String? name, String? type,
    double? invested, double? currentValue, double? quantity,
    double? buyPrice, String? symbol, String? broker,
    DateTime? purchaseDate, String? note,
  }) => InvestmentModel(
    id: id ?? this.id, userId: userId ?? this.userId,
    name: name ?? this.name, type: type ?? this.type,
    invested: invested ?? this.invested,
    currentValue: currentValue ?? this.currentValue,
    quantity: quantity ?? this.quantity,
    buyPrice: buyPrice ?? this.buyPrice,
    symbol: symbol ?? this.symbol, broker: broker ?? this.broker,
    purchaseDate: purchaseDate ?? this.purchaseDate,
    note: note ?? this.note, createdAt: createdAt,
  );
}