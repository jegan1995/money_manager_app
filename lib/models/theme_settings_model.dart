import 'package:flutter/material.dart';

class ThemeSettingsModel {
  final bool isDarkMode;
  final Color primaryColor;
  final Color accentColor;
  final String fontFamily;

  ThemeSettingsModel({
    this.isDarkMode = false,
    this.primaryColor = Colors.blue,
    this.accentColor = Colors.orange,
    this.fontFamily = 'Roboto',
  });

  Map<String, dynamic> toMap() {
    return {
      'isDarkMode': isDarkMode,
      'primaryColor': primaryColor.value,
      'accentColor': accentColor.value,
      'fontFamily': fontFamily,
    };
  }

  factory ThemeSettingsModel.fromMap(Map<String, dynamic> map) {
    return ThemeSettingsModel(
      isDarkMode: map['isDarkMode'] ?? false,
      primaryColor: Color(map['primaryColor'] ?? Colors.blue.value),
      accentColor: Color(map['accentColor'] ?? Colors.orange.value),
      fontFamily: map['fontFamily'] ?? 'Roboto',
    );
  }

  ThemeSettingsModel copyWith({
    bool? isDarkMode,
    Color? primaryColor,
    Color? accentColor,
    String? fontFamily,
  }) {
    return ThemeSettingsModel(
      isDarkMode: isDarkMode ?? this.isDarkMode,
      primaryColor: primaryColor ?? this.primaryColor,
      accentColor: accentColor ?? this.accentColor,
      fontFamily: fontFamily ?? this.fontFamily,
    );
  }
}