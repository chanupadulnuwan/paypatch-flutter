import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config.dart';

class ActivityBadgeProvider extends ChangeNotifier {
  static String get _baseUrl => AppConfig.baseUrl;

  String? _token;
  int _unreadCount = 0;

  int get unreadCount => _unreadCount;

  ActivityBadgeProvider(this._token) {
    if (_token != null) fetchUnreadCount();
  }

  void updateToken(String? token) {
    if (_token == token) return;
    _token = token;
    if (_token == null) {
      _unreadCount = 0;
      notifyListeners();
      return;
    }
    fetchUnreadCount();
  }

  Future<void> fetchUnreadCount() async {
    if (_token == null) return;
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/activity/unread-count'),
        headers: {'Accept': 'application/json', 'Authorization': 'Bearer $_token'},
      ).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final count = (decoded['unread_count'] as num?)?.toInt() ?? 0;
        if (count != _unreadCount) {
          _unreadCount = count;
          notifyListeners();
        }
      }
    } catch (_) {}
  }

  void clearBadge() {
    if (_unreadCount != 0) {
      _unreadCount = 0;
      notifyListeners();
    }
  }
}
