import 'package:flutter/material.dart';

class ThemeController extends ChangeNotifier {
  // In-session override only — always follows system on fresh app start
  bool? _userOverride; // null = follow system

  bool get isDark =>
      _userOverride ??
      (WidgetsBinding.instance.platformDispatcher.platformBrightness ==
          Brightness.dark);

  ThemeMode get themeMode {
    if (_userOverride == null) return ThemeMode.system;
    return _userOverride! ? ThemeMode.dark : ThemeMode.light;
  }

  void toggleTheme() {
    if (_userOverride == null) {
      final currentlyDark =
          WidgetsBinding.instance.platformDispatcher.platformBrightness ==
              Brightness.dark;
      _userOverride = !currentlyDark;
    } else {
      _userOverride = !_userOverride!;
    }
    notifyListeners();
  }

  void resetToSystem() {
    _userOverride = null;
    notifyListeners();
  }
}
