import 'package:shared_preferences/shared_preferences.dart';

class OnboardingPrefs {
  static const String _keyPrefix = 'onboarding_seen_';

  static Future<bool> hasSeenForUser(Map<String, dynamic>? user) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_storageKeyForUser(user)) ?? false;
  }

  static Future<void> markSeenForUser(Map<String, dynamic>? user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_storageKeyForUser(user), true);
  }

  static String _storageKeyForUser(Map<String, dynamic>? user) {
    final id = user?['id']?.toString().trim();
    if (id != null && id.isNotEmpty) {
      return '$_keyPrefix$id';
    }

    final email = user?['email']?.toString().trim().toLowerCase();
    if (email != null && email.isNotEmpty) {
      return '$_keyPrefix$email';
    }

    return '${_keyPrefix}guest';
  }
}
