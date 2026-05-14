import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ThemeProvider uses SharedPreferences (localStorage on web) to persist
/// the user's theme choice. This survives hard refresh and app restart.
/// DO NOT use DBHelper for settings on web — _WebDB is in-memory only.
class ThemeProvider extends ChangeNotifier {
  static const _themeKey = 'app_theme_mode';

  ThemeMode _themeMode = ThemeMode.dark;
  bool _isInitialized = false;

  ThemeMode get themeMode => _themeMode;
  bool get isDark => _themeMode == ThemeMode.dark;
  bool get isInitialized => _isInitialized;

  /// Load saved theme from SharedPreferences (localStorage on web).
  /// Call this during app startup BEFORE UI renders.
  Future<void> loadSavedTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_themeKey);
      if (saved != null) {
        _themeMode = saved == 'light' ? ThemeMode.light : ThemeMode.dark;
      }
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

  /// Persist theme preference via SharedPreferences (localStorage on web)
  Future<void> _persistTheme() async {
    final value = _themeMode == ThemeMode.dark ? 'dark' : 'light';
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeKey, value);
      debugPrint('🎨 ThemeProvider: saved theme = $value');
    } catch (e) {
      debugPrint('⚠️ ThemeProvider: failed to save theme: $e');
    }
  }
}
