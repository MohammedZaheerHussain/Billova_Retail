import 'package:flutter/material.dart';
import '../data/local/db_helper.dart';

class ThemeProvider extends ChangeNotifier {
  static const _themeKey = 'app_theme_mode';
  final DBHelper _db = DBHelper.instance;

  ThemeMode _themeMode = ThemeMode.dark;
  bool _isInitialized = false;

  ThemeMode get themeMode => _themeMode;
  bool get isDark => _themeMode == ThemeMode.dark;
  bool get isInitialized => _isInitialized;

  /// Load saved theme from persistent storage.
  /// Call this during app startup BEFORE UI renders.
  Future<void> loadSavedTheme() async {
    try {
      final saved = await _db.getSetting(_themeKey);
      if (saved != null) {
        _themeMode = saved == 'light' ? ThemeMode.light : ThemeMode.dark;
      }
      // If no saved preference, keep default (dark)
      debugPrint('🎨 ThemeProvider: restored theme = ${_themeMode == ThemeMode.dark ? "dark" : "light"}');
    } catch (e) {
      debugPrint('⚠️ ThemeProvider: failed to load theme, using default dark: $e');
    }
    _isInitialized = true;
    notifyListeners();
  }

  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    _persistTheme();
    notifyListeners();
  }

  void setTheme(ThemeMode mode) {
    if (_themeMode == mode) return;
    _themeMode = mode;
    _persistTheme();
    notifyListeners();
  }

  /// Persist theme preference to local DB
  Future<void> _persistTheme() async {
    final value = _themeMode == ThemeMode.dark ? 'dark' : 'light';
    try {
      await _db.setSetting(_themeKey, value);
      debugPrint('🎨 ThemeProvider: saved theme = $value');
    } catch (e) {
      debugPrint('⚠️ ThemeProvider: failed to save theme: $e');
    }
  }
}
