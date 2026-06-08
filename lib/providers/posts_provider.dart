import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/group_post.dart';

class PostsProvider extends ChangeNotifier {
  static String get _baseUrl => AppConfig.baseUrl;

  String? _token;
  List<GroupPost> _posts = [];
  bool _isLoading = false;

  List<GroupPost> get posts => _posts;
  bool get isLoading => _isLoading;

  PostsProvider(this._token) {
    if (_token != null) fetchPosts();
  }

  void updateToken(String? token) {
    if (_token == token) return;
    _token = token;
    if (_token == null) {
      _posts = [];
      notifyListeners();
      return;
    }
    fetchPosts();
  }

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        'Authorization': 'Bearer $_token',
      };

  Future<void> fetchPosts() async {
    if (_token == null) return;
    _isLoading = true;
    notifyListeners();
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/posts'), headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        _posts = (data['posts'] as List? ?? [])
            .map((e) => GroupPost.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    _isLoading = false;
    notifyListeners();
  }

  String? _lastError;
  String? get lastError => _lastError;

  Future<GroupPost?> createPost({
    required String groupId,
    required String audience,
    String? caption,
    String? imagePath,
  }) async {
    if (_token == null) return null;
    _lastError = null;
    try {
      final req = http.MultipartRequest('POST', Uri.parse('$_baseUrl/posts'))
        ..headers.addAll(_headers)
        ..fields['group_id'] = groupId
        ..fields['audience'] = audience;
      if (caption != null && caption.isNotEmpty) {
        req.fields['caption'] = caption;
      }
      if (imagePath != null) {
        req.files.add(await http.MultipartFile.fromPath('image', imagePath));
      }
      final streamed = await req.send().timeout(const Duration(seconds: 30));
      final res = await http.Response.fromStream(streamed);
      if (res.statusCode == 201) {
        final data = json.decode(res.body);
        final post = GroupPost.fromJson(data['post'] as Map<String, dynamic>);
        _posts.insert(0, post);
        notifyListeners();
        return post;
      }
      // Surface the server error message
      try {
        final body = json.decode(res.body) as Map<String, dynamic>;
        _lastError = body['message']?.toString() ?? 'Server error ${res.statusCode}';
      } catch (_) {
        _lastError = 'Server error ${res.statusCode}';
      }
    } catch (e) {
      _lastError = e.toString();
    }
    return null;
  }

  Future<bool> toggleLike(String postId) async {
    if (_token == null) return false;
    final idx = _posts.indexWhere((p) => p.id == postId);
    if (idx == -1) return false;

    final old = _posts[idx];
    // Optimistic update
    _posts[idx] = old.copyWith(
      likedByMe: !old.likedByMe,
      likesCount: old.likedByMe ? old.likesCount - 1 : old.likesCount + 1,
    );
    notifyListeners();

    try {
      final res = await http
          .post(Uri.parse('$_baseUrl/posts/$postId/like'), headers: _headers)
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        _posts[idx] = _posts[idx].copyWith(
          likesCount: (data['likes_count'] as num).toInt(),
          likedByMe: data['liked'] as bool,
        );
        notifyListeners();
        return true;
      }
    } catch (_) {}
    // Revert on failure
    _posts[idx] = old;
    notifyListeners();
    return false;
  }

  Future<List<Map<String, dynamic>>> fetchComments(String postId) async {
    if (_token == null) return [];
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/posts/$postId/comments'), headers: _headers)
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        return List<Map<String, dynamic>>.from(
            (data['comments'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)));
      }
    } catch (_) {}
    return [];
  }

  Future<Map<String, dynamic>?> addComment(String postId, String comment) async {
    if (_token == null) return null;
    try {
      final res = await http
          .post(
            Uri.parse('$_baseUrl/posts/$postId/comments'),
            headers: {..._headers, 'Content-Type': 'application/json'},
            body: json.encode({'comment': comment}),
          )
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 201) {
        final data = json.decode(res.body);
        final idx = _posts.indexWhere((p) => p.id == postId);
        if (idx != -1) {
          _posts[idx] = _posts[idx].copyWith(commentsCount: _posts[idx].commentsCount + 1);
          notifyListeners();
        }
        return Map<String, dynamic>.from(data['comment'] as Map);
      }
    } catch (_) {}
    return null;
  }

  Future<bool> deletePost(String postId) async {
    if (_token == null) return false;
    try {
      final res = await http
          .delete(Uri.parse('$_baseUrl/posts/$postId'), headers: _headers)
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        _posts.removeWhere((p) => p.id == postId);
        notifyListeners();
        return true;
      }
    } catch (_) {}
    return false;
  }
}
