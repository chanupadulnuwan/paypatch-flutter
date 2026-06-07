import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:contacts_service_plus/contacts_service_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../config.dart';

class FriendsProvider extends ChangeNotifier {
  static const String _baseUrl = AppConfig.baseUrl;

  final String? _token;
  List<dynamic> _friends = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Phone contacts list
  List<Contact> _contacts = [];
  bool _isLoadingContacts = false;
  bool _contactsPermissionDenied = false;

  List<dynamic> get friends => _friends;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<Contact> get contacts => _contacts;
  bool get isLoadingContacts => _isLoadingContacts;
  bool get contactsPermissionDenied => _contactsPermissionDenied;

  FriendsProvider(this._token) {
    if (_token != null) {
      fetchFriends();
    }
  }

  // --- CACHE HELPERS ---
  Future<File> _getCacheFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/friends_list.json');
  }

  Future<void> _writeToCache(String content) async {
    try {
      final file = await _getCacheFile();
      await file.writeAsString(content);
    } catch (_) {}
  }

  Future<String?> _readFromCache() async {
    try {
      final file = await _getCacheFile();
      if (await file.exists()) {
        return await file.readAsString();
      }
    } catch (_) {}
    return null;
  }

  // --- FETCH FRIENDS (NET BALANCES) ---
  Future<void> fetchFriends({bool isOnline = true}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    if (!isOnline || _token == null) {
      // Offline fallback
      final cachedStr = await _readFromCache();
      if (cachedStr != null) {
        final decoded = json.decode(cachedStr);
        _friends = decoded['friends'] ?? [];
      } else {
        // Mock fallback data
        _friends = [
          {'user_id': 3, 'name': 'Alice Wijesinghe', 'email': 'alice@example.com', 'balance': 45.0, 'status': 'owes_you'},
          {'user_id': 4, 'name': 'Bob Perera', 'email': 'bob@example.com', 'balance': -20.0, 'status': 'you_owe'},
        ];
      }
      _isLoading = false;
      notifyListeners();
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/friends'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $_token',
        },
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        _friends = decoded['friends'] ?? [];
        await _writeToCache(response.body);
      } else {
        throw Exception('Failed to load friends from backend');
      }
    } catch (e) {
      _errorMessage = e.toString();
      // Try to load cached data
      final cachedStr = await _readFromCache();
      if (cachedStr != null) {
        final decoded = json.decode(cachedStr);
        _friends = decoded['friends'] ?? [];
      } else {
        _friends = [
          {'user_id': 3, 'name': 'Alice Wijesinghe', 'email': 'alice@example.com', 'balance': 45.0, 'status': 'owes_you'},
          {'user_id': 4, 'name': 'Bob Perera', 'email': 'bob@example.com', 'balance': -20.0, 'status': 'you_owe'},
        ];
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- FETCH PHONE CONTACTS ---
  Future<void> fetchPhoneContacts() async {
    _isLoadingContacts = true;
    _contactsPermissionDenied = false;
    notifyListeners();

    try {
      final status = await Permission.contacts.request();
      if (status.isGranted) {
        final Iterable<Contact> contacts = await ContactsService.getContacts(
          withThumbnails: false,
          photoHighResolution: false,
        );
        _contacts = contacts.toList();
      } else {
        _contactsPermissionDenied = true;
      }
    } catch (_) {
      _contactsPermissionDenied = true;
    } finally {
      _isLoadingContacts = false;
      notifyListeners();
    }
  }
}
