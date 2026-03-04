// lib/models/custom_category_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CustomSubSub {
  final String name;
  const CustomSubSub(this.name);

  Map<String, dynamic> toMap() => {'name': name};
  factory CustomSubSub.fromMap(Map<String, dynamic> m) =>
      CustomSubSub(m['name'] ?? '');
}

class CustomSubcategory {
  final String name;
  final List<String> subSubs; // 3rd level

  const CustomSubcategory({required this.name, this.subSubs = const []});

  Map<String, dynamic> toMap() => {
    'name': name,
    'subSubs': subSubs,
  };

  factory CustomSubcategory.fromMap(Map<String, dynamic> m) => CustomSubcategory(
    name: m['name'] ?? '',
    subSubs: List<String>.from(m['subSubs'] ?? []),
  );
}

class CustomCategory {
  final String? id;
  final String userId;
  final String type; // 'expense' | 'income'
  final String name;
  final String emoji;
  final Color color;
  final List<CustomSubcategory> subcategories;
  final bool isBuiltIn; // built-in cats cannot be deleted

  const CustomCategory({
    this.id,
    required this.userId,
    required this.type,
    required this.name,
    this.emoji = '📌',
    this.color = const Color(0xFF667eea),
    this.subcategories = const [],
    this.isBuiltIn = false,
  });

  Map<String, dynamic> toMap() => {
    'userId':        userId,
    'type':          type,
    'name':          name,
    'emoji':         emoji,
    'color':         color.value,
    'subcategories': subcategories.map((s) => s.toMap()).toList(),
    'isBuiltIn':     isBuiltIn,
  };

  factory CustomCategory.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return CustomCategory(
      id:    doc.id,
      userId: d['userId'] ?? '',
      type:  d['type'] ?? 'expense',
      name:  d['name'] ?? '',
      emoji: d['emoji'] ?? '📌',
      color: Color(d['color'] ?? 0xFF667eea),
      subcategories: (d['subcategories'] as List<dynamic>? ?? [])
          .map((s) => CustomSubcategory.fromMap(Map<String, dynamic>.from(s)))
          .toList(),
      isBuiltIn: d['isBuiltIn'] ?? false,
    );
  }

  CustomCategory copyWith({
    String? name,
    String? emoji,
    Color? color,
    List<CustomSubcategory>? subcategories,
  }) => CustomCategory(
    id:            id,
    userId:        userId,
    type:          type,
    name:          name ?? this.name,
    emoji:         emoji ?? this.emoji,
    color:         color ?? this.color,
    subcategories: subcategories ?? this.subcategories,
    isBuiltIn:     isBuiltIn,
  );
}