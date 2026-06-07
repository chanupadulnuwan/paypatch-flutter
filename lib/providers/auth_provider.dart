import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';

class AuthProvider extends ChangeNotifier {
  static const String _baseUrl = AppConfig.baseUrl;
  
  String? _token;
  Map<String, dynamic>? _user;
  bool _isLoading = false;

  String? get token => _token;
  Map<String, dynamic>? get user => _user;
  bool get isAuthenticated => _token != null;
  bool get isLoading => _isLoading;

  Future<bool> loginWithGoogle() async {
    _isLoading = true;
    notifyListeners();
    try {
      // Try logging in first
      final success = await login('google.demo@gmail.com', 'GoogleDemo123!');
      return success;
    } catch (_) {
      try {
        // If login fails (user doesn't exist yet), register them
        final success = await register('Google Demo User', 'google.demo@gmail.com', 'GoogleDemo123!');
        return success;
      } catch (e) {
        _isLoading = false;
        notifyListeners();
        rethrow;
      }
    }
  }

  AuthProvider() {
    loadSession();
  }

  Future<void> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    final userStr = prefs.getString('auth_user');
    if (userStr != null) {
      _user = json.decode(userStr) as Map<String, dynamic>;
    }
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/login'),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: json.encode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _token = data['token'];
        _user = data['user'];

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', _token!);
        await prefs.setString('auth_user', json.encode(_user));

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Failed to login');
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<bool> register(String name, String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/register'),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: json.encode({
          'name': name,
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = json.decode(response.body);
        _token = data['token'];
        _user = data['user'];

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', _token!);
        await prefs.setString('auth_user', json.encode(_user));

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Failed to register');
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      if (_token != null) {
        await http.delete(
          Uri.parse('$_baseUrl/logout'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $_token',
          },
        );
      }
    } catch (_) {
      // Proceed even if network request fails
    }

    _token = null;
    _user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('auth_user');

    _isLoading = false;
    notifyListeners();
  }
}
