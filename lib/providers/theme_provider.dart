import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Font size options
enum AppFontSize { small, medium, large }

class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode = false;
  AppFontSize _fontSize = AppFontSize.medium;

  static const String _themeKey = 'isDarkMode';
  static const String _fontSizeKey = 'appFontSize';

  bool get isDarkMode => _isDarkMode;
  AppFontSize get fontSize => _fontSize;

  // Returns the text scale factor based on selected font size
  double get textScaleFactor {
    switch (_fontSize) {
      case AppFontSize.small:
        return 0.85;
      case AppFontSize.medium:
        return 1.0;
      case AppFontSize.large:
        return 1.15;
    }
  }

  String get fontSizeLabel {
    switch (_fontSize) {
      case AppFontSize.small:
        return 'Small';
      case AppFontSize.medium:
        return 'Medium';
      case AppFontSize.large:
        return 'Large';
    }
  }

  ThemeProvider() {
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool(_themeKey) ?? false;
    final fontIndex = prefs.getInt(_fontSizeKey) ?? 1;
    _fontSize = AppFontSize.values[fontIndex.clamp(0, 2)];
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, _isDarkMode);
    notifyListeners();
  }

  Future<void> setFontSize(AppFontSize size) async {
    _fontSize = size;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_fontSizeKey, size.index);
    notifyListeners();
  }

  ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
        ),
      );

  ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
        ),
      );
}