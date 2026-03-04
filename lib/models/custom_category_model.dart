// lib/models/custom_category_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CustomSubcategory {
  final String name;
  final List<String> subSubs;

  const CustomSubcategory({required this.name, this.subSubs = const []});

  Map<String, dynamic> toMap() => {
    'name':    name,
    'subSubs': subSubs,
  };

  factory CustomSubcategory.fromMap(dynamic raw) {
    try {
      final m = Map<String, dynamic>.from(raw as Map);
      return CustomSubcategory(
        name:    m['name']?.toString() ?? '',
        subSubs: (m['subSubs'] as List<dynamic>? ?? [])
            .map((e) => e?.toString() ?? '')
            .where((e) => e.isNotEmpty)
            .toList(),
      );
    } catch (_) {
      return const CustomSubcategory(name: '');
    }
  }
}

class CustomCategory {
  final String? id;
  final String  userId;
  final String  type;
  final String  name;
  final String  emoji;
  final Color   color;
  final List<CustomSubcategory> subcategories;
  final bool    isBuiltIn;

  const CustomCategory({
    this.id,
    required this.userId,
    required this.type,
    required this.name,
    this.emoji         = '📌',
    this.color         = const Color(0xFF667eea),
    this.subcategories = const [],
    this.isBuiltIn     = false,
  });

  Map<String, dynamic> toMap() => {
    'userId':        userId,
    'type':          type,
    'name':          name,
    'emoji':         emoji,
    // Store as int string to avoid web 64-bit issue
    'colorHex':      color.value.toRadixString(16).padLeft(8, '0'),
    'subcategories': subcategories.map((s) => s.toMap()).toList(),
    'isBuiltIn':     isBuiltIn,
  };

  factory CustomCategory.fromFirestore(DocumentSnapshot doc) {
    try {
      final d = doc.data() as Map<String, dynamic>;

      // ── Color: try colorHex string first, fallback to legacy int ──────────
      Color parsedColor = const Color(0xFF667eea);
      try {
        final hex = d['colorHex']?.toString();
        if (hex != null && hex.length >= 6) {
          parsedColor = Color(int.parse(hex.padLeft(8, 'f'), radix: 16));
        } else if (d['color'] != null) {
          // Legacy: stored as number — handle both int and double on web
          final raw = d['color'];
          final intVal = raw is double ? raw.toInt() : (raw as int);
          parsedColor = Color(intVal & 0xFFFFFFFF);
        }
      } catch (_) {}

      // ── Subcategories: safe parse ─────────────────────────────────────────
      List<CustomSubcategory> subs = [];
      try {
        final rawList = d['subcategories'];
        if (rawList is List) {
          subs = rawList
              .map((e) => CustomSubcategory.fromMap(e))
              .where((s) => s.name.isNotEmpty)
              .toList();
        }
      } catch (_) {}

      return CustomCategory(
        id:            doc.id,
        userId:        d['userId']?.toString()   ?? '',
        type:          d['type']?.toString()     ?? 'expense',
        name:          d['name']?.toString()     ?? '',
        emoji:         d['emoji']?.toString()    ?? '📌',
        color:         parsedColor,
        subcategories: subs,
        isBuiltIn:     d['isBuiltIn'] as bool?   ?? false,
      );
    } catch (e) {
      // Fallback — never crash the stream
      return CustomCategory(
        id:     doc.id,
        userId: '',
        type:   'expense',
        name:   '(error)',
        emoji:  '⚠️',
        color:  Colors.grey,
      );
    }
  }

  CustomCategory copyWith({
    String? name,
    String? emoji,
    Color?  color,
    List<CustomSubcategory>? subcategories,
  }) =>
      CustomCategory(
        id:            id,
        userId:        userId,
        type:          type,
        name:          name          ?? this.name,
        emoji:         emoji         ?? this.emoji,
        color:         color         ?? this.color,
        subcategories: subcategories ?? this.subcategories,
        isBuiltIn:     isBuiltIn,
      );
}