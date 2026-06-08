import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';

class AuthProvider extends ChangeNotifier {
  static const _googleDemoEmail = 'google.demo@gmail.com';
  static const _googleDemoPassword = 'GoogleDemo123!';

  static String get _baseUrl => AppConfig.baseUrl;
  static String get _webBaseUrl => AppConfig.webBaseUrl;

  final http.Client _client = http.Client();

  String? _token;
  Map<String, dynamic>? _user;
  bool _isLoading = false;

  String? get token => _token;
  Map<String, dynamic>? get user => _user;
  bool get isAuthenticated => _token != null;
  bool get isLoading => _isLoading;

  AuthProvider() {
    loadSession();
  }

  Future<bool> loginWithGoogle() async {
    try {
      return await login(_googleDemoEmail, _googleDemoPassword);
    } catch (_) {
      return register(
        'Google Demo User',
        _googleDemoEmail,
        _googleDemoPassword,
        country: 'Sri Lanka',
      );
    }
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

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (_token == null) return false;
    _isLoading = true;
    notifyListeners();
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/change-password'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: json.encode({
          'current_password': currentPassword,
          'new_password': newPassword,
          'new_password_confirmation': newPassword,
        }),
      ).timeout(const Duration(seconds: 10));
      if (_isSuccess(response.statusCode)) return true;
      final msg = _extractErrorMessage(response);
      throw Exception(msg ?? 'Failed to change password.');
    } on Exception {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      return await _loginInternal(email, password);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> register(
    String name,
    String email,
    String password, {
    String country = 'Sri Lanka',
    String? username,
    String? phone,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final body = <String, dynamic>{
        'name': name,
        'email': email,
        'password': password,
        'country': country,
      };
      if (username != null && username.isNotEmpty) body['username'] = username;
      if (phone != null && phone.isNotEmpty) body['phone'] = phone;

      final response = await _client
          .post(
            Uri.parse('$_baseUrl/register'),
            headers: _jsonHeaders,
            body: json.encode(body),
          )
          .timeout(const Duration(seconds: 10));

      if (_isSuccess(response.statusCode)) {
        await _storeSession(response.body);
        return true;
      }

      if (_shouldUseWebRegistrationFallback(response)) {
        final fallbackError = await _registerThroughWebForm(
          name: name,
          email: email,
          password: password,
          country: country,
          username: username,
          phone: phone,
        );

        try {
          return await _loginInternal(email, password);
        } catch (_) {
          if (fallbackError != null) {
            throw Exception(fallbackError);
          }

          throw Exception(
            'Your account could not be created on the current server.',
          );
        }
      }

      throw Exception(
        _extractErrorMessage(response) ?? 'Your account could not be created.',
      );
    } on TimeoutException {
      throw Exception('The server took too long to respond. Please try again.');
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }

      throw Exception('Something went wrong while creating your account.');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateProfile({
    String? name,
    String? username,
    String? phone,
    String? profileImagePath,
  }) async {
    if (_token == null) return false;
    _isLoading = true;
    notifyListeners();
    try {
      final uri = Uri.parse('$_baseUrl/profile/update');
      final request = http.MultipartRequest('POST', uri)
        ..headers.addAll({
          'Accept': 'application/json',
          'Authorization': 'Bearer $_token',
        });
      if (name != null) request.fields['name'] = name;
      if (username != null) request.fields['username'] = username;
      if (phone != null) request.fields['phone'] = phone;
      if (profileImagePath != null && profileImagePath.isNotEmpty) {
        request.files.add(await http.MultipartFile.fromPath('profile_photo', profileImagePath));
      }
      final streamed = await _client.send(request).timeout(const Duration(seconds: 15));
      final response = await http.Response.fromStream(streamed);
      if (_isSuccess(response.statusCode)) {
        final decoded = json.decode(response.body);
        if (decoded['user'] is Map<String, dynamic>) {
          _user = decoded['user'] as Map<String, dynamic>;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('auth_user', json.encode(_user));
        }
        return true;
      }
      return false;
    } catch (_) {
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshProfile() async {
    if (_token == null) return;
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/profile'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $_token',
        },
      ).timeout(const Duration(seconds: 10));
      if (_isSuccess(response.statusCode)) {
        final decoded = json.decode(response.body);
        if (decoded['user'] is Map<String, dynamic>) {
          _user = decoded['user'] as Map<String, dynamic>;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('auth_user', json.encode(_user));
          notifyListeners();
        }
      }
    } catch (_) {}
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      if (_token != null) {
        await _client.delete(
          Uri.parse('$_baseUrl/logout'),
          headers: {
            ..._jsonHeaders,
            'Authorization': 'Bearer $_token',
          },
        );
      }
    } catch (_) {
      // Proceed even if network request fails.
    }

    _token = null;
    _user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('auth_user');

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> _loginInternal(String email, String password) async {
    final response = await _client
        .post(
          Uri.parse('$_baseUrl/login'),
          headers: _jsonHeaders,
          body: json.encode({
            'email': email,
            'password': password,
          }),
        )
        .timeout(const Duration(seconds: 10));

    if (_isSuccess(response.statusCode)) {
      await _storeSession(response.body);
      return true;
    }

    throw Exception(
      _extractErrorMessage(response) ?? 'Email or password is incorrect.',
    );
  }

  Future<void> _storeSession(String body) async {
    final dynamic decoded = json.decode(body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('The server returned an invalid sign-in response.');
    }

    final token = decoded['token']?.toString();
    final user = decoded['user'];

    if (token == null || user is! Map<String, dynamic>) {
      throw Exception('The server returned an incomplete sign-in response.');
    }

    _token = token;
    _user = user;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', _token!);
    await prefs.setString('auth_user', json.encode(_user));
  }

  Future<String?> _registerThroughWebForm({
    required String name,
    required String email,
    required String password,
    required String country,
    String? username,
    String? phone,
  }) async {
    final registerUri = Uri.parse('$_webBaseUrl/register');

    final pageResponse = await _client.get(
      registerUri,
      headers: const {
        'Accept': 'text/html,application/xhtml+xml',
      },
    ).timeout(const Duration(seconds: 10));

    if (pageResponse.statusCode != 200) {
      return 'Registration is currently unavailable on this server.';
    }

    final csrfToken = _extractCsrfToken(pageResponse.body);
    final cookieHeader = _extractCookieHeader(pageResponse.headers['set-cookie']);

    if (csrfToken == null || cookieHeader.isEmpty) {
      return 'Registration could not be prepared on the current server.';
    }

    final request = http.Request('POST', registerUri)
      ..followRedirects = false
      ..headers.addAll({
        'Accept': 'text/html,application/xhtml+xml',
        'Content-Type': 'application/x-www-form-urlencoded',
        'Cookie': cookieHeader,
        'Origin': _webBaseUrl,
        'Referer': registerUri.toString(),
      })
      ..bodyFields = {
        '_token': csrfToken,
        'name': name,
        'email': email,
        'country': country,
        'password': password,
        'password_confirmation': password,
        'plan': 'Free Tier',
      };

    final streamedResponse = await _client
        .send(request)
        .timeout(const Duration(seconds: 12));
    final response = await http.Response.fromStream(streamedResponse);

    final location = response.headers['location'] ?? '';
    final isExpectedRedirect =
        location.contains('/login/two-factor') ||
        location.contains('/dashboard') ||
        location.contains('/login') ||
        location.contains('/?modal=login');

    if (isExpectedRedirect) {
      return null;
    }

    if (location.contains('/register')) {
      return _extractHtmlError(response.body) ??
          'That email may already be registered. Try logging in instead.';
    }

    if (response.statusCode >= 500) {
      return 'Registration is temporarily unavailable. Please try again shortly.';
    }

    return _extractHtmlError(response.body);
  }

  String? _extractRawErrorMessage(http.Response response) {
    try {
      final dynamic decoded = json.decode(response.body);
      if (decoded is Map<String, dynamic>) {
        final errors = decoded['errors'];
        if (errors is Map<String, dynamic>) {
          for (final value in errors.values) {
            if (value is List && value.isNotEmpty) {
              return value.first.toString();
            }
          }
        }

        final message = decoded['message']?.toString();
        if (message != null && message.isNotEmpty) {
          return message;
        }
      }
    } catch (_) {
      final body = response.body.trim();
      if (body.isNotEmpty) {
        return body;
      }
    }

    return null;
  }

  String? _extractErrorMessage(http.Response response) {
    final rawMessage = _extractRawErrorMessage(response);
    if (rawMessage == null || rawMessage.isEmpty) {
      return null;
    }

    return _humanizeMessage(rawMessage);
  }

  String _humanizeMessage(String message) {
    final clean = message.replaceAll('Exception: ', '').trim();
    final lower = clean.toLowerCase();

    if (lower.contains('invalid credentials')) {
      return 'Email or password is incorrect.';
    }

    if (lower.contains('route api/register could not be found')) {
      return 'Mobile sign-up is not available on this server yet.';
    }

    if (lower.contains('already been taken')) {
      return 'That email is already registered. Try logging in instead.';
    }

    return clean;
  }

  String? _extractHtmlError(String html) {
    final compactHtml = html.replaceAll('\n', ' ');

    final knownMessages = <Pattern, String>{
      'email has already been taken':
          'That email is already registered. Try logging in instead.',
      'password confirmation does not match':
          'Passwords do not match. Please re-enter them.',
      'country field is required': 'Please choose a country.',
      'password field is required': 'Please enter a password.',
      'name field is required': 'Please enter your name.',
    };

    for (final entry in knownMessages.entries) {
      if (compactHtml.toLowerCase().contains(entry.key)) {
        return entry.value;
      }
    }

    final match = RegExp(
      r'<(?:li|p|div)[^>]*class="[^"]*(?:text-red|text-rose|text-danger)[^"]*"[^>]*>(.*?)</(?:li|p|div)>',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(compactHtml);

    if (match != null) {
      final rawText = match.group(1) ?? '';
      final cleaned = rawText
          .replaceAll(RegExp(r'<[^>]+>'), ' ')
          .replaceAll('&amp;', '&')
          .replaceAll('&nbsp;', ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      if (cleaned.isNotEmpty) {
        return cleaned;
      }
    }

    return null;
  }

  String? _extractCsrfToken(String html) {
    final inputMatch = RegExp(
      r'name="_token"\s+value="([^"]+)"',
    ).firstMatch(html);
    if (inputMatch != null) {
      return inputMatch.group(1);
    }

    final metaMatch = RegExp(
      r'<meta name="csrf-token" content="([^"]+)"',
    ).firstMatch(html);
    return metaMatch?.group(1);
  }

  String _extractCookieHeader(String? rawCookieHeader) {
    if (rawCookieHeader == null || rawCookieHeader.isEmpty) {
      return '';
    }

    final cookieNames = ['XSRF-TOKEN', 'laravel-session', '__cf_bm'];
    final cookies = <String>[];

    for (final name in cookieNames) {
      final match = RegExp('$name=([^;]+)').firstMatch(rawCookieHeader);
      if (match != null) {
        cookies.add('$name=${match.group(1)}');
      }
    }

    return cookies.join('; ');
  }

  bool _shouldUseWebRegistrationFallback(http.Response response) {
    final message = (_extractRawErrorMessage(response) ?? '').toLowerCase();
    return response.statusCode == 404 &&
        message.contains('route api/register could not be found');
  }

  bool _isSuccess(int statusCode) => statusCode >= 200 && statusCode < 300;

  Map<String, String> get _jsonHeaders => const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }
}
