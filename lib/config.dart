import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  static const String _defaultWebUrl = 'https://sea-turtle-app-4spaa.ondigitalocean.app';
  static const String _defaultApiUrl = '$_defaultWebUrl/api';

  static String _baseUrl = _defaultApiUrl;

  static String get baseUrl => _baseUrl;
  static String get webBaseUrl => _baseUrl.replaceFirst(RegExp(r'/api/?$'), '');

  static String normalizeBaseUrl(String url) {
    var formattedUrl = url.trim();

    if (formattedUrl.endsWith('/')) {
      formattedUrl = formattedUrl.substring(0, formattedUrl.length - 1);
    }

    if (!formattedUrl.endsWith('/api')) {
      formattedUrl = '$formattedUrl/api';
    }

    return formattedUrl;
  }

  /// Load Base URL from SharedPreferences
  static Future<void> loadIp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUrl = prefs.getString('api_base_url');
      if (savedUrl == null || savedUrl.trim().isEmpty) {
        _baseUrl = _defaultApiUrl;
        await prefs.setString('api_base_url', _baseUrl);
      } else {
        _baseUrl = normalizeBaseUrl(savedUrl);
      }
    } catch (_) {
      _baseUrl = _defaultApiUrl;
    }
  }

  /// Save Base URL to SharedPreferences and update memory cache
  static Future<void> saveIp(String url) async {
    _baseUrl = normalizeBaseUrl(url);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('api_base_url', _baseUrl);
    } catch (_) {}
  }
}
