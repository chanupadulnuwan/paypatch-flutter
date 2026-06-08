import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController extends ChangeNotifier {
  static const String _key = 'theme_is_dark';
  bool _isDark = false;

  bool get isDark => _isDark;

  ThemeMode get themeMode => _isDark ? ThemeMode.dark : ThemeMode.light;

  ThemeController() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getBool(_key);
    if (saved != null) {
      _isDark = saved;
    } else {
      // First launch: follow device system brightness
      _isDark = WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
    }
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _isDark = !_isDark;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, _isDark);
  }

  Future<void> setTheme(bool dark) async {
    if (_isDark != dark) {
      _isDark = dark;
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, _isDark);
    }
  }
}
