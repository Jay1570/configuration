import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dhipl_flutter/config/app_dependencies.dart';
import 'package:http/http.dart' as http;

class ActivityApiService {
  ActivityApiService._();

  static final instance = ActivityApiService._();
  final _storage = StorageService();

  Future<ActivityPage> fetchActivityListPaginated({
    required int page,
    required int limit,
    String? search,
    Map<String, int>? sort,
    Map<String, dynamic>? filter,
  }) async {
    final url = Uri.parse(ApiConstants.activityListPaginated);
    final token = await _storage.getToken();

    final body = <String, dynamic>{
      'paginate': {
        'page': page,
        'limit': limit,
      },
      'filter': filter ?? {},
      'sort': sort ?? {},
      'search_name': (search ?? '').trim(),
    };

    final resp = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (resp.statusCode == 401) {
      throw UnauthorizedException();
    }

    if (resp.statusCode != 200) {
      throw ApiException(resp.statusCode, 'Failed to fetch activity groups (${resp.statusCode})');
    }

    final j = jsonDecode(resp.body) as Map<String, dynamic>;
    return ActivityPage.fromJson(j);
  }

  Future<String?> createActivity({
    required String activityName,
    required int groupId,
  }) async {
    final url = Uri.parse(ApiConstants.activityListAdd);
    final token = await _storage.getToken();
    if (token == null || token.isEmpty) throw UnauthorizedException();

    final body = {
      'activity_name': activityName.trim(),
      'group_id': groupId,
    };

    try {
      final resp = await http
          .post(
            url,
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));

      if (resp.statusCode == 201 || resp.statusCode == 200) {
        final j = _tryDecode(resp.body);
        return (j?['message'] ?? 'Activity created').toString();
      }
      _throwForStatus(resp, fallback: 'Failed to create activity');
    } on SocketException {
      throw Exception('No internet connection. Please check your network.');
    } on TimeoutException {
      throw Exception('Request timed out. Please try again.');
    } on http.ClientException catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<String?> updateActivity({
    required int id,
    required String activityName,
    required int groupId,
  }) async {
    final url = Uri.parse(ApiConstants.activityListUpdate(id));
    final token = await _storage.getToken();
    if (token == null || token.isEmpty) throw UnauthorizedException();

    final body = {
      'activity_name': activityName.trim(),
      'group_id': groupId,
    };

    try {
      final resp = await http
          .post(
            url,
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));

      if (resp.statusCode == 200) {
        final j = _tryDecode(resp.body);
        return (j?['message'] ?? 'Activity updated').toString();
      }
      _throwForStatus(resp, fallback: 'Failed to update activity');
    } on SocketException {
      throw Exception('No internet connection. Please check your network.');
    } on TimeoutException {
      throw Exception('Request timed out. Please try again.');
    } on http.ClientException catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<String?> deleteActivity(int id) async {
    final url = Uri.parse(ApiConstants.activityListDelete(id));
    final token = await _storage.getToken();

    try {
      final response = await http.post(
        url,
        headers: {
          HttpHeaders.authorizationHeader: "Bearer $token",
          HttpHeaders.contentTypeHeader: "application/json",
        },
      );

      final decoded = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return decoded["message"] ?? "Activity deleted successfully";
      } else if (response.statusCode == 401) {
        throw UnauthorizedException();
      } else {
        throw ApiException(response.statusCode, decoded['error'] ?? decoded['message']);
      }
    } on SocketException {
      throw Exception('No internet connection. Please check your network.');
    } on TimeoutException {
      throw Exception('Request timed out. Please try again.');
    } on http.ClientException catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Helpers
  Map<String, dynamic>? _tryDecode(String body) {
    try {
      final j = jsonDecode(body);
      return j is Map<String, dynamic> ? j : null;
    } catch (_) {
      return null;
    }
  }

  Never _throwForStatus(http.Response resp, {String? fallback}) {
    final code = resp.statusCode;
    final msg = _extractMsg(resp, fallback: fallback ?? 'Request failed');
    switch (code) {
      case 400:
        throw ApiException(code, 'Bad Request: $msg');
      case 401:
        throw UnauthorizedException();
      case 403:
        throw ApiException(code, 'Forbidden: $msg');
      case 404:
        throw ApiException(code, 'Not Found: $msg');
      case 409:
        throw ApiException(code, 'Conflict: $msg');
      case 422:
        throw ApiException(code, 'Validation Error: $msg');
      case 429:
        throw ApiException(code, 'Too Many Requests: $msg');
      default:
        if (code >= 500) throw ApiException(code, 'Server Error ($code): $msg');
        throw ApiException(code, 'HTTP $code: $msg');
    }
  }

  String _extractMsg(http.Response resp, {String fallback = 'Request failed'}) {
    try {
      final j = jsonDecode(resp.body);
      if (j is Map<String, dynamic>) {
        if (j['message'] != null) return j['message'].toString();
        if (j['error'] != null) return j['error'].toString();
        if (j['msg'] != null) return j['msg'].toString();
        if (j['errors'] is List && (j['errors'] as List).isNotEmpty) {
          return (j['errors'] as List).join(', ');
        }
      }
      if (j is List && j.isNotEmpty) return j.first.toString();
    } catch (_) {}
    if (resp.body.isNotEmpty) return resp.body.length > 500 ? fallback : resp.body;
    return fallback;
  }
}
