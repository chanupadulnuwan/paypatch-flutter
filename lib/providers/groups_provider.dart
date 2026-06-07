import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../models/group.dart';
import '../data/sample_data.dart';
import '../config.dart';

class GroupsProvider extends ChangeNotifier {
  static const String _baseUrl = AppConfig.baseUrl;

  final String? _token;
  List<Group> _groups = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Selected group details
  Map<String, dynamic>? _selectedGroupDetails;
  bool _isLoadingDetails = false;

  List<Group> get groups => _groups;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Map<String, dynamic>? get selectedGroupDetails => _selectedGroupDetails;
  bool get isLoadingDetails => _isLoadingDetails;

  GroupsProvider(this._token) {
    if (_token != null) {
      fetchGroups();
    }
  }

  // --- LOCAL CACHING HELPERS ---
  Future<File> _getCacheFile(String filename) async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$filename');
  }

  Future<void> _writeToCache(String filename, String content) async {
    try {
      final file = await _getCacheFile(filename);
      await file.writeAsString(content);
    } catch (_) {}
  }

  Future<String?> _readFromCache(String filename) async {
    try {
      final file = await _getCacheFile(filename);
      if (await file.exists()) {
        return await file.readAsString();
      }
    } catch (_) {}
    return null;
  }

  // --- FETCH GROUPS (ONLINE / OFFLINE CACHE) ---
  Future<void> fetchGroups({bool isOnline = true}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    if (!isOnline || _token == null) {
      // Offline: load from cache
      final cachedStr = await _readFromCache('groups_list.json');
      if (cachedStr != null) {
        final decoded = json.decode(cachedStr);
        final List data = decoded['data'] ?? [];
        _groups = data.map((item) => Group.fromJson(item)).toList();
      } else {
        // No cache: fallback to mock data
        _groups = sampleGroups;
      }
      _isLoading = false;
      notifyListeners();
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/groups'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $_token',
        },
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final List data = decoded['data'] ?? [];
        _groups = data.map((item) => Group.fromJson(item)).toList();
        await _writeToCache('groups_list.json', response.body);
      } else {
        throw Exception('Failed to fetch groups from server');
      }
    } catch (e) {
      _errorMessage = e.toString();
      // Try to load cached data on API error
      final cachedStr = await _readFromCache('groups_list.json');
      if (cachedStr != null) {
        final decoded = json.decode(cachedStr);
        final List data = decoded['data'] ?? [];
        _groups = data.map((item) => Group.fromJson(item)).toList();
      } else {
        _groups = sampleGroups;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- FETCH GROUP DETAILS (ONLINE / OFFLINE CACHE) ---
  Future<void> fetchGroupDetails(String groupId, {bool isOnline = true}) async {
    _isLoadingDetails = true;
    _selectedGroupDetails = null;
    notifyListeners();

    final cacheName = 'group_details_$groupId.json';

    if (!isOnline || _token == null) {
      // Offline: load details from cache
      final cachedStr = await _readFromCache(cacheName);
      if (cachedStr != null) {
        _selectedGroupDetails = json.decode(cachedStr);
      } else {
        // Fallback: mock structure
        _selectedGroupDetails = {
          'group': {
            'id': groupId,
            'name': 'Group $groupId (Offline)',
            'member_count': 4,
            'your_balance': 0.0,
            'currency': 'LKR',
            'expenses': []
          },
          'members': []
        };
      }
      _isLoadingDetails = false;
      notifyListeners();
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/groups/$groupId'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $_token',
        },
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        _selectedGroupDetails = decoded;
        await _writeToCache(cacheName, response.body);
      } else {
        throw Exception('Failed to fetch group details');
      }
    } catch (e) {
      // Error: try to load cached details
      final cachedStr = await _readFromCache(cacheName);
      if (cachedStr != null) {
        _selectedGroupDetails = json.decode(cachedStr);
      } else {
        _selectedGroupDetails = {
          'group': {
            'id': groupId,
            'name': 'Offline details unavailable',
            'member_count': 0,
            'your_balance': 0.0,
            'currency': 'LKR',
            'expenses': []
          },
          'members': []
        };
      }
    } finally {
      _isLoadingDetails = false;
      notifyListeners();
    }
  }

  // --- CREATE GROUP (ONLINE ONLY) ---
  Future<bool> createGroup(String name) async {
    if (_token == null) return false;
    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/groups'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: json.encode({'name': name}),
      );

      _isLoading = false;
      if (response.statusCode == 201 || response.statusCode == 200) {
        await fetchGroups(isOnline: true);
        return true;
      }
      return false;
    } catch (_) {
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // --- ADD EXPENSE (ONLINE ONLY) ---
  Future<bool> addExpense(String groupId, String title, double amount, int paidById, {String? locationName, String? localImagePath}) async {
    if (_token == null) return false;
    _isLoadingDetails = true;
    notifyListeners();

    // Attach location coordinates to the title to show sensor integration
    String finalTitle = title;
    if (locationName != null) {
      finalTitle = '$title ($locationName)';
    }

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/expenses'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: json.encode({
          'group_id': int.parse(groupId),
          'paid_by': paidById,
          'title': finalTitle,
          'amount': amount,
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        // Refresh detail screen
        await fetchGroupDetails(groupId, isOnline: true);
        // Also refresh summary list to reflect new net balances
        await fetchGroups(isOnline: true);
        
        // If an image was taken, cache its path locally for this expense in our cache
        if (localImagePath != null && _selectedGroupDetails != null) {
          final cacheName = 'group_details_$groupId.json';
          final expenses = _selectedGroupDetails!['group']['expenses'] as List?;
          if (expenses != null && expenses.isNotEmpty) {
            // Match the newest expense (highest ID or first) and add image path
            expenses.first['receipt_image'] = localImagePath;
            await _writeToCache(cacheName, json.encode(_selectedGroupDetails));
          }
        }
        
        return true;
      }
      _isLoadingDetails = false;
      notifyListeners();
      return false;
    } catch (_) {
      _isLoadingDetails = false;
      notifyListeners();
      return false;
    }
  }
}
