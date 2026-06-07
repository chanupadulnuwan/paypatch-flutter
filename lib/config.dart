import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  static String _baseUrl = 'https://sea-turtle-app-4spaa.ondigitalocean.app/api'; // Default hosted backend

  static String get baseUrl => _baseUrl;

  /// Load Base URL from SharedPreferences
  static Future<void> loadIp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUrl = prefs.getString('api_base_url');
      if (savedUrl == null || savedUrl.contains('192.168.') || savedUrl.contains('localhost')) {
        _baseUrl = 'https://sea-turtle-app-4spaa.ondigitalocean.app/api';
        await prefs.setString('api_base_url', _baseUrl);
      } else {
        _baseUrl = savedUrl;
      }
    } catch (_) {
      _baseUrl = 'https://sea-turtle-app-4spaa.ondigitalocean.app/api';
    }
  }

  /// Save Base URL to SharedPreferences and update memory cache
  static Future<void> saveIp(String url) async {
    String formattedUrl = url.trim();
    if (formattedUrl.endsWith('/')) {
      formattedUrl = formattedUrl.substring(0, formattedUrl.length - 1);
    }
    _baseUrl = formattedUrl;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('api_base_url', _baseUrl);
    } catch (_) {}
  }
}
