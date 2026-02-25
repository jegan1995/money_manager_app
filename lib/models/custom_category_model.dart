import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CustomCategory {
  final String? id;
  final String userId;
  final String name;
  final String type;   // 'expense' or 'income'
  final String emoji;
  final int colorValue;
  final List<String> subcategories;
  final DateTime createdAt;

  const CustomCategory({
    this.id,
    required this.userId,
    required this.name,
    required this.type,
    required this.emoji,
    required this.colorValue,
    required this.subcategories,
    required this.createdAt,
  });

  Color get color => Color(colorValue);

  Map<String, dynamic> toMap() => {
        'userId':        userId,
        'name':          name,
        'type':          type,
        'emoji':         emoji,
        'colorValue':    colorValue,
        'subcategories': subcategories,
        'createdAt':     Timestamp.fromDate(createdAt),
      };

  factory CustomCategory.fromMap(Map<String, dynamic> map, String id) =>
      CustomCategory(
        id:             id,
        userId:         map['userId']   ?? '',
        name:           map['name']     ?? '',
        type:           map['type']     ?? 'expense',
        emoji:          map['emoji']    ?? '📦',
        colorValue:     map['colorValue'] ?? Colors.blue.value,
        subcategories: List<String>.from(map['subcategories'] ?? []),
        createdAt: map['createdAt'] != null
            ? (map['createdAt'] as Timestamp).toDate()
            : DateTime.now(),
      );

  factory CustomCategory.fromFirestore(DocumentSnapshot doc) =>
      CustomCategory.fromMap(doc.data() as Map<String, dynamic>, doc.id);

  CustomCategory copyWith({
    String? name,
    String? emoji,
    int? colorValue,
    List<String>? subcategories,
  }) =>
      CustomCategory(
        id:             id,
        userId:         userId,
        name:           name          ?? this.name,
        type:           type,
        emoji:          emoji         ?? this.emoji,
        colorValue:     colorValue    ?? this.colorValue,
        subcategories:  subcategories ?? this.subcategories,
        createdAt:      createdAt,
      );
}

// Available emojis for category picker
const kCategoryEmojis = [
  '🍔','🍕','🍜','☕','🛒','👕','👟','💻','📱','🎮',
  '🎬','🎵','🏋️','⚽','🚗','🛵','✈️','🏠','💡','📞',
  '🏥','💊','🎓','📚','💼','💰','💳','🎁','🐶','🌿',
  '🧴','✂️','🔧','🎨','📷','🎯','🛍️','🌮','🍦','🧁',
  '🚀','⭐','💎','🌟','🔑','🎪','🏖️','🌄','🍷','🎭',
];

// Available colors
const kCategoryColors = [
  Color(0xFFE53935), // Red
  Color(0xFFE91E63), // Pink
  Color(0xFF9C27B0), // Purple
  Color(0xFF3F51B5), // Indigo
  Color(0xFF1565C0), // Blue
  Color(0xFF0097A7), // Cyan
  Color(0xFF00897B), // Teal
  Color(0xFF43A047), // Green
  Color(0xFF7CB342), // Light Green
  Color(0xFFFDD835), // Yellow
  Color(0xFFFB8C00), // Orange
  Color(0xFF6D4C41), // Brown
  Color(0xFF546E7A), // Blue Grey
  Color(0xFF00ACC1), // Cyan light
  Color(0xFF8E24AA), // Deep Purple
];