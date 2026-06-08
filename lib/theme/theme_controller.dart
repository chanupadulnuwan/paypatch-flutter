import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController extends ChangeNotifier {
  static const String _keyOverrideSet = 'theme_user_override_set';
  static const String _keyIsDark = 'theme_is_dark';

  bool? _userOverride; // null = follow system

  bool get isDark =>
      _userOverride ??
      (WidgetsBinding.instance.platformDispatcher.platformBrightness ==
          Brightness.dark);

  ThemeMode get themeMode {
    if (_userOverride == null) return ThemeMode.system;
    return _userOverride! ? ThemeMode.dark : ThemeMode.light;
  }

  ThemeController() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final overrideSet = prefs.getBool(_keyOverrideSet) ?? false;
    if (overrideSet) {
      _userOverride = prefs.getBool(_keyIsDark) ?? false;
    } else {
      _userOverride = null;
    }
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    if (_userOverride == null) {
      // Currently following system — flip from current effective value
      final currentlyDark =
          WidgetsBinding.instance.platformDispatcher.platformBrightness ==
              Brightness.dark;
      _userOverride = !currentlyDark;
    } else {
      _userOverride = !_userOverride!;
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyOverrideSet, true);
    await prefs.setBool(_keyIsDark, _userOverride!);
  }

  Future<void> setTheme(bool dark) async {
    _userOverride = dark;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyOverrideSet, true);
    await prefs.setBool(_keyIsDark, dark);
  }

  Future<void> resetToSystem() async {
    _userOverride = null;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyOverrideSet);
    await prefs.remove(_keyIsDark);
  }
}
