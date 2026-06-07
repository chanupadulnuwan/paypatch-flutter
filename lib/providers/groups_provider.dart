import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../config.dart';
import '../data/sample_data.dart';
import '../models/group.dart';

class GroupsProvider extends ChangeNotifier {
  static String get _baseUrl => AppConfig.baseUrl;

  final http.Client _client = http.Client();

  String? _token;
  List<Group> _groups = [];
  bool _isLoading = false;
  String? _errorMessage;
  Map<String, dynamic>? _selectedGroupDetails;
  bool _isLoadingDetails = false;
  double? _usdToLkrRate;

  List<Group> get groups => _groups;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  Map<String, dynamic>? get selectedGroupDetails => _selectedGroupDetails;
  bool get isLoadingDetails => _isLoadingDetails;
  double? get usdToLkrRate => _usdToLkrRate;

  GroupsProvider(this._token) {
    if (_token != null) {
      fetchGroups();
      fetchUsdToLkrRate();
    }
  }

  void updateToken(String? token) {
    if (_token == token) {
      return;
    }

    _token = token;
    if (_token == null) {
      _groups = [];
      _selectedGroupDetails = null;
      _usdToLkrRate = null;
      notifyListeners();
      return;
    }

    fetchGroups();
    fetchUsdToLkrRate();
  }

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

  Map<String, String> get _authJsonHeaders => {
        'Accept': 'application/json',
        'Authorization': 'Bearer $_token',
      };

  Future<void> fetchUsdToLkrRate() async {
    if (_token == null) {
      _usdToLkrRate = null;
      return;
    }

    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/exchange-rates/usd-lkr'),
        headers: _authJsonHeaders,
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = json.decode(response.body) as Map<String, dynamic>;
        final rate = decoded['rate'];
        if (rate is num) {
          _usdToLkrRate = rate.toDouble();
          notifyListeners();
        }
      }
    } catch (_) {
      _usdToLkrRate ??= 325.40;
    }
  }

  Future<void> fetchGroups({bool isOnline = true}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    if (!isOnline || _token == null) {
      final cachedStr = await _readFromCache('groups_list.json');
      if (cachedStr != null) {
        final decoded = json.decode(cachedStr) as Map<String, dynamic>;
        final List data = decoded['data'] ?? [];
        _groups = data
            .whereType<Map<String, dynamic>>()
            .map(Group.fromJson)
            .toList();
      } else {
        _groups = sampleGroups;
      }

      _isLoading = false;
      notifyListeners();
      return;
    }

    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/groups'),
        headers: _authJsonHeaders,
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body) as Map<String, dynamic>;
        final List data = decoded['data'] ?? [];
        _groups = data
            .whereType<Map<String, dynamic>>()
            .map(Group.fromJson)
            .toList();
        await _writeToCache('groups_list.json', response.body);
      } else {
        throw Exception(
          _extractErrorMessage(response) ?? 'Failed to fetch groups.',
        );
      }
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '').trim();
      final cachedStr = await _readFromCache('groups_list.json');
      if (cachedStr != null) {
        final decoded = json.decode(cachedStr) as Map<String, dynamic>;
        final List data = decoded['data'] ?? [];
        _groups = data
            .whereType<Map<String, dynamic>>()
            .map(Group.fromJson)
            .toList();
      } else {
        _groups = sampleGroups;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchGroupDetails(String groupId, {bool isOnline = true}) async {
    _isLoadingDetails = true;
    _selectedGroupDetails = null;
    notifyListeners();

    final cacheName = 'group_details_$groupId.json';

    if (!isOnline || _token == null) {
      final cachedStr = await _readFromCache(cacheName);
      if (cachedStr != null) {
        _selectedGroupDetails = json.decode(cachedStr) as Map<String, dynamic>;
      } else {
        _selectedGroupDetails = {
          'group': {
            'id': groupId,
            'name': 'Offline Group',
            'member_count': 0,
            'your_balance': 0.0,
            'currency': 'LKR',
            'expenses': const [],
            'can_edit': false,
          },
          'members': const [],
          'meta': {
            'usd_lkr_rate': _usdToLkrRate ?? 325.40,
          },
        };
      }

      _isLoadingDetails = false;
      notifyListeners();
      return;
    }

    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/groups/$groupId'),
        headers: _authJsonHeaders,
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body) as Map<String, dynamic>;
        _selectedGroupDetails = decoded;
        final meta = decoded['meta'];
        if (meta is Map<String, dynamic>) {
          final rate = meta['usd_lkr_rate'];
          if (rate is num) {
            _usdToLkrRate = rate.toDouble();
          }
        }
        await _writeToCache(cacheName, response.body);
      } else {
        throw Exception(
          _extractErrorMessage(response) ?? 'Failed to fetch group details.',
        );
      }
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '').trim();
      final cachedStr = await _readFromCache(cacheName);
      if (cachedStr != null) {
        _selectedGroupDetails = json.decode(cachedStr) as Map<String, dynamic>;
      } else {
        _selectedGroupDetails = {
          'group': {
            'id': groupId,
            'name': 'Offline details unavailable',
            'member_count': 0,
            'your_balance': 0.0,
            'currency': 'LKR',
            'expenses': const [],
            'can_edit': false,
          },
          'members': const [],
          'meta': {
            'usd_lkr_rate': _usdToLkrRate ?? 325.40,
          },
        };
      }
    } finally {
      _isLoadingDetails = false;
      notifyListeners();
    }
  }

  Future<List<Map<String, dynamic>>> searchUsers(
    String query, {
    String? groupId,
  }) async {
    if (_token == null || query.trim().isEmpty) {
      return [];
    }

    try {
      final uri = Uri.parse('$_baseUrl/users/search').replace(
        queryParameters: {
          'q': query.trim(),
          if (groupId?.isNotEmpty ?? false) 'group_id': groupId!,
        },
      );

      final response = await _client.get(uri, headers: _authJsonHeaders);
      if (response.statusCode != 200) {
        _errorMessage = _extractErrorMessage(response) ?? 'User search failed.';
        notifyListeners();
        return [];
      }

      final decoded = json.decode(response.body) as Map<String, dynamic>;
      final users = decoded['users'] as List? ?? const [];
      return users
          .whereType<Map<String, dynamic>>()
          .map((user) => Map<String, dynamic>.from(user))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<bool> createGroup({
    required String name,
    required String currency,
    List<int> memberIds = const [],
  }) async {
    if (_token == null) {
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _sendMultipartRequest(
        uri: Uri.parse('$_baseUrl/groups'),
        fields: {
          'name': name,
          'currency': currency,
          if (memberIds.isNotEmpty) 'member_ids': json.encode(memberIds),
        },
      );

      if (_isSuccessful(response.statusCode)) {
        await fetchGroups(isOnline: true);
        return true;
      }

      _errorMessage =
          _extractErrorMessage(response) ?? 'Failed to create group.';
      return false;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '').trim();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateGroup({
    required String groupId,
    required String name,
    required String currency,
    String? coverImagePath,
    String? profileImagePath,
  }) async {
    if (_token == null) {
      return false;
    }

    _isLoadingDetails = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _sendMultipartRequest(
        uri: Uri.parse('$_baseUrl/groups/$groupId/update'),
        fields: {
          'name': name,
          'currency': currency,
        },
        fileFields: {
          'cover_image': coverImagePath,
          'profile_image': profileImagePath,
        },
      );

      if (_isSuccessful(response.statusCode)) {
        await fetchGroupDetails(groupId, isOnline: true);
        await fetchGroups(isOnline: true);
        return true;
      }

      _errorMessage =
          _extractErrorMessage(response) ?? 'Failed to update group.';
      return false;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '').trim();
      return false;
    } finally {
      _isLoadingDetails = false;
      notifyListeners();
    }
  }

  Future<bool> addMember(String groupId, int memberId) async {
    if (_token == null) {
      return false;
    }

    _isLoadingDetails = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/groups/$groupId/members'),
        headers: {
          ..._authJsonHeaders,
          'Content-Type': 'application/json',
        },
        body: json.encode({'member_id': memberId}),
      );

      if (_isSuccessful(response.statusCode)) {
        await fetchGroupDetails(groupId, isOnline: true);
        await fetchGroups(isOnline: true);
        return true;
      }

      _errorMessage = _extractErrorMessage(response) ?? 'Failed to add member.';
      return false;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '').trim();
      return false;
    } finally {
      _isLoadingDetails = false;
      notifyListeners();
    }
  }

  Future<bool> removeMember(String groupId, int memberId) async {
    if (_token == null) {
      return false;
    }

    _isLoadingDetails = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _client.delete(
        Uri.parse('$_baseUrl/groups/$groupId/members/$memberId'),
        headers: _authJsonHeaders,
      );

      if (_isSuccessful(response.statusCode)) {
        await fetchGroupDetails(groupId, isOnline: true);
        await fetchGroups(isOnline: true);
        return true;
      }

      _errorMessage =
          _extractErrorMessage(response) ?? 'Failed to remove member.';
      return false;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '').trim();
      return false;
    } finally {
      _isLoadingDetails = false;
      notifyListeners();
    }
  }

  Future<bool> deleteGroup(String groupId) async {
    if (_token == null) {
      return false;
    }

    _isLoadingDetails = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _client.delete(
        Uri.parse('$_baseUrl/groups/$groupId'),
        headers: _authJsonHeaders,
      );

      if (_isSuccessful(response.statusCode)) {
        if (_selectedGroupDetails?['group']?['id']?.toString() == groupId) {
          _selectedGroupDetails = null;
        }
        await fetchGroups(isOnline: true);
        return true;
      }

      _errorMessage =
          _extractErrorMessage(response) ?? 'Failed to delete group.';
      return false;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '').trim();
      return false;
    } finally {
      _isLoadingDetails = false;
      notifyListeners();
    }
  }

  Future<bool> addExpense(
    String groupId,
    String title,
    double amount,
    int paidById, {
    String? locationName,
    String? localImagePath,
  }) async {
    if (_token == null) {
      return false;
    }

    _isLoadingDetails = true;
    _errorMessage = null;
    notifyListeners();

    var finalTitle = title;
    if (locationName != null && locationName.isNotEmpty) {
      finalTitle = '$title ($locationName)';
    }

    try {
      final response = await _sendMultipartRequest(
        uri: Uri.parse('$_baseUrl/expenses'),
        fields: {
          'group_id': groupId,
          'paid_by': paidById.toString(),
          'title': finalTitle,
          'amount': amount.toStringAsFixed(2),
        },
        fileFields: {
          'receipt_image': localImagePath,
        },
      );

      if (_isSuccessful(response.statusCode)) {
        await fetchGroupDetails(groupId, isOnline: true);
        await fetchGroups(isOnline: true);
        return true;
      }

      _errorMessage =
          _extractErrorMessage(response) ?? 'Failed to add expense.';
      return false;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '').trim();
      return false;
    } finally {
      _isLoadingDetails = false;
      notifyListeners();
    }
  }

  Future<bool> deleteExpense(String groupId, int expenseId) async {
    if (_token == null) {
      return false;
    }

    _isLoadingDetails = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _client.delete(
        Uri.parse('$_baseUrl/expenses/$expenseId'),
        headers: _authJsonHeaders,
      );

      if (_isSuccessful(response.statusCode)) {
        await fetchGroupDetails(groupId, isOnline: true);
        await fetchGroups(isOnline: true);
        return true;
      }

      _errorMessage =
          _extractErrorMessage(response) ?? 'Failed to delete expense.';
      return false;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '').trim();
      return false;
    } finally {
      _isLoadingDetails = false;
      notifyListeners();
    }
  }

  Future<bool> settleUp({
    required String groupId,
    required int fromUserId,
    required int toUserId,
    required double amount,
  }) async {
    if (_token == null) return false;
    _isLoadingDetails = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/groups/$groupId/settle'),
        headers: {..._authJsonHeaders, 'Content-Type': 'application/json'},
        body: json.encode({
          'from_user_id': fromUserId,
          'to_user_id': toUserId,
          'amount': amount,
        }),
      );
      if (_isSuccessful(response.statusCode)) {
        await fetchGroupDetails(groupId, isOnline: true);
        await fetchGroups(isOnline: true);
        return true;
      }
      _errorMessage = _extractErrorMessage(response) ?? 'Failed to record settlement.';
      return false;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '').trim();
      return false;
    } finally {
      _isLoadingDetails = false;
      notifyListeners();
    }
  }

  Future<bool> sendReminders(String groupId, List<int> memberIds) async {
    if (_token == null) return false;
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/groups/$groupId/remind'),
        headers: {..._authJsonHeaders, 'Content-Type': 'application/json'},
        body: json.encode({'member_ids': memberIds}),
      );
      return _isSuccessful(response.statusCode);
    } catch (_) {
      return false;
    }
  }

  Future<http.Response> _sendMultipartRequest({
    required Uri uri,
    required Map<String, String> fields,
    Map<String, String?> fileFields = const {},
  }) async {
    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll(_authJsonHeaders)
      ..fields.addAll(fields);

    for (final entry in fileFields.entries) {
      final filePath = entry.value;
      if (filePath == null || filePath.trim().isEmpty) {
        continue;
      }

      request.files.add(
        await http.MultipartFile.fromPath(entry.key, filePath),
      );
    }

    final streamedResponse = await _client.send(request);
    return http.Response.fromStream(streamedResponse);
  }

  String? _extractErrorMessage(http.Response response) {
    try {
      final decoded = json.decode(response.body);
      if (decoded is Map<String, dynamic>) {
        final errors = decoded['errors'];
        if (errors is Map<String, dynamic>) {
          for (final value in errors.values) {
            if (value is List && value.isNotEmpty) {
              return value.first.toString();
            }
          }
        }

        final message = decoded['message'];
        if (message is String && message.trim().isNotEmpty) {
          return message.trim();
        }
      }
    } catch (_) {
      if (response.body.trim().isNotEmpty) {
        return response.body.trim();
      }
    }

    return null;
  }

  bool _isSuccessful(int statusCode) => statusCode >= 200 && statusCode < 300;

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }
}
