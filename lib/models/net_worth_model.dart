import 'package:cloud_firestore/cloud_firestore.dart';

// A single asset or liability item
class NetWorthItem {
  final String? id;
  final String userId;
  final String name;
  final String category; // e.g. 'Real Estate', 'Vehicle', 'FD', 'Loan'
  final String type;     // 'asset' or 'liability'
  final double value;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;

  const NetWorthItem({
    this.id,
    required this.userId,
    required this.name,
    required this.category,
    required this.type,
    required this.value,
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isAsset     => type == 'asset';
  bool get isLiability => type == 'liability';

  Map<String, dynamic> toMap() => {
        'userId':    userId,
        'name':      name,
        'category':  category,
        'type':      type,
        'value':     value,
        'note':      note,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  factory NetWorthItem.fromMap(Map<String, dynamic> map, String id) =>
      NetWorthItem(
        id:        id,
        userId:    map['userId']   ?? '',
        name:      map['name']     ?? '',
        category:  map['category'] ?? 'Other',
        type:      map['type']     ?? 'asset',
        value:     (map['value']   ?? 0).toDouble(),
        note:      map['note'],
        createdAt: map['createdAt'] != null
            ? (map['createdAt'] as Timestamp).toDate()
            : DateTime.now(),
        updatedAt: map['updatedAt'] != null
            ? (map['updatedAt'] as Timestamp).toDate()
            : DateTime.now(),
      );

  factory NetWorthItem.fromFirestore(DocumentSnapshot doc) =>
      NetWorthItem.fromMap(doc.data() as Map<String, dynamic>, doc.id);

  NetWorthItem copyWith({
    String? id, String? name, String? category,
    String? type, double? value, String? note,
  }) =>
      NetWorthItem(
        id:        id        ?? this.id,
        userId:    userId,
        name:      name      ?? this.name,
        category:  category  ?? this.category,
        type:      type      ?? this.type,
        value:     value     ?? this.value,
        note:      note      ?? this.note,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );
}

// Monthly snapshot stored in Firestore for history chart
class NetWorthSnapshot {
  final String? id;
  final String userId;
  final double totalAssets;
  final double totalLiabilities;
  final double netWorth;
  final DateTime date;

  const NetWorthSnapshot({
    this.id,
    required this.userId,
    required this.totalAssets,
    required this.totalLiabilities,
    required this.netWorth,
    required this.date,
  });

  Map<String, dynamic> toMap() => {
        'userId':            userId,
        'totalAssets':       totalAssets,
        'totalLiabilities':  totalLiabilities,
        'netWorth':          netWorth,
        'date':              Timestamp.fromDate(date),
      };

  factory NetWorthSnapshot.fromMap(Map<String, dynamic> map, String id) =>
      NetWorthSnapshot(
        id:                id,
        userId:            map['userId']           ?? '',
        totalAssets:       (map['totalAssets']      ?? 0).toDouble(),
        totalLiabilities:  (map['totalLiabilities'] ?? 0).toDouble(),
        netWorth:          (map['netWorth']          ?? 0).toDouble(),
        date:              map['date'] != null
            ? (map['date'] as Timestamp).toDate()
            : DateTime.now(),
      );

  factory NetWorthSnapshot.fromFirestore(DocumentSnapshot doc) =>
      NetWorthSnapshot.fromMap(doc.data() as Map<String, dynamic>, doc.id);
}

// Predefined asset categories
const kAssetCategories = [
  'Cash & Bank',
  'Real Estate',
  'Vehicle',
  'Fixed Deposit',
  'Stocks & MF',
  'Gold & Jewellery',
  'PPF / EPF',
  'Business',
  'Other Asset',
];

// Predefined liability categories
const kLiabilityCategories = [
  'Home Loan',
  'Car Loan',
  'Personal Loan',
  'Education Loan',
  'Credit Card Debt',
  'Business Loan',
  'Other Liability',
];