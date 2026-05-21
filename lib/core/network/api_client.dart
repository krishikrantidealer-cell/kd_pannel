import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:kd_pannel/core/utils/local_cache_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  // The local Node.js server runs on port 5000 by default.
  // Using localhost is correct for Web.
  final String baseUrl = 'https://api.krishikrantiorganics.com/api';

  String? _accessToken;
  String? _refreshToken;

  // Global Backend Cold-Start Detector
  final ValueNotifier<bool> isBackendWakingUp = ValueNotifier<bool>(false);

  // Memory Cache for instant UI response
  List<Map<String, dynamic>>? cachedProducts;
  List<Map<String, dynamic>>? cachedCollections;
  List<dynamic>? cachedCategories;

  void clearCache() {
    cachedProducts = null;
    cachedCollections = null;
    cachedCategories = null;
    LocalCacheHelper.clearAllCache();
  }

  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;

  Future<void> _ensureTokensLoaded() async {
    if (_accessToken != null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _accessToken = prefs.getString('kd_access_token');
      _refreshToken = prefs.getString('kd_refresh_token');
    } catch (e) {
      debugPrint('Failed to load persisted tokens: $e');
    }
  }

  Future<void> setTokens(String access, String refresh) async {
    _accessToken = access;
    _refreshToken = refresh;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('kd_access_token', access);
      await prefs.setString('kd_refresh_token', refresh);
    } catch (e) {
      debugPrint('Failed to persist tokens: $e');
    }
  }

  Future<void> clearTokens() async {
    _accessToken = null;
    _refreshToken = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('kd_access_token');
      await prefs.remove('kd_refresh_token');
      await prefs.remove('kd_user_role');
    } catch (e) {
      debugPrint('Failed to clear persisted tokens: $e');
    }
  }

  Map<String, String> _getHeaders() {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_accessToken != null) {
      headers['Authorization'] = 'Bearer $_accessToken';
    }
    return headers;
  }

  /// Helper to run request with automatic retries and exponential backoff.
  /// Designed to seamlessly handle Render free tier cold starts and network glitches.
  Future<http.Response> _requestWithRetry(
    Future<http.Response> Function(Duration currentTimeout) requestFn, {
    int maxRetries = 4,
    Duration initialDelay = const Duration(seconds: 1),
  }) async {
    int attempt = 0;
    while (true) {
      attempt++;
      // Give more timeout budget on subsequent attempts as server boots up
      final currentTimeout = attempt == 1 
          ? const Duration(seconds: 15) 
          : const Duration(seconds: 25);

      try {
        final response = await requestFn(currentTimeout);

        // Render cold start might return 502 / 503 / 504 gateway errors while booting
        if ((response.statusCode == 502 || 
             response.statusCode == 503 || 
             response.statusCode == 504) && 
            attempt < maxRetries) {
          if (!isBackendWakingUp.value) {
            isBackendWakingUp.value = true;
          }
          final delay = initialDelay * (1 << (attempt - 1));
          debugPrint('[ApiClient] Server returned ${response.statusCode} (attempt $attempt). Retrying in ${delay.inSeconds}s...');
          await Future.delayed(delay);
          continue;
        }

        // Success! Clear waking up indicator
        if (isBackendWakingUp.value) {
          isBackendWakingUp.value = false;
        }
        return response;
      } catch (e) {
        final isTimeout = e is TimeoutException;
        final errStr = e.toString().toLowerCase();
        final isConnectionError = errStr.contains('socketexception') ||
                                  errStr.contains('clientexception') ||
                                  errStr.contains('connection refused') ||
                                  errStr.contains('failed to connect') ||
                                  errStr.contains('xmlhttprequest') ||
                                  errStr.contains('networkerror') ||
                                  errStr.contains('handshake');

        final isNetworkError = isTimeout || isConnectionError;

        if (isNetworkError && attempt < maxRetries) {
          if (!isBackendWakingUp.value) {
            isBackendWakingUp.value = true;
          }
          final delay = initialDelay * (1 << (attempt - 1));
          debugPrint('[ApiClient] Network error ($e) on attempt $attempt. Retrying in ${delay.inSeconds}s...');
          await Future.delayed(delay);
          continue;
        }

        // Reset state on terminal failure
        if (isBackendWakingUp.value) {
          isBackendWakingUp.value = false;
        }
        rethrow;
      }
    }
  }

  Future<http.Response> get(String endpoint) async {
    await _ensureTokensLoaded();
    return await _requestWithRetry((timeoutDuration) async {
      final uri = Uri.parse('$baseUrl$endpoint');
      return await http
          .get(uri, headers: _getHeaders())
          .timeout(timeoutDuration);
    });
  }

  Future<http.Response> post(String endpoint, Map<String, dynamic> body) async {
    await _ensureTokensLoaded();
    return await _requestWithRetry((timeoutDuration) async {
      final uri = Uri.parse('$baseUrl$endpoint');
      return await http
          .post(uri, headers: _getHeaders(), body: jsonEncode(body))
          .timeout(timeoutDuration);
    });
  }

  Future<http.Response> put(String endpoint, Map<String, dynamic> body) async {
    await _ensureTokensLoaded();
    return await _requestWithRetry((timeoutDuration) async {
      final uri = Uri.parse('$baseUrl$endpoint');
      return await http
          .put(uri, headers: _getHeaders(), body: jsonEncode(body))
          .timeout(timeoutDuration);
    });
  }

  Future<http.Response> delete(String endpoint) async {
    await _ensureTokensLoaded();
    return await _requestWithRetry((timeoutDuration) async {
      final uri = Uri.parse('$baseUrl$endpoint');
      return await http
          .delete(uri, headers: _getHeaders())
          .timeout(timeoutDuration);
    });
  }

  // Multipart request helper for creating/updating products with images
  Future<http.Response> multipartRequest({
    required String method,
    required String endpoint,
    required Map<String, String> fields,
    required List<http.MultipartFile> files,
  }) async {
    await _ensureTokensLoaded();
    return await _requestWithRetry((timeoutDuration) async {
      final uri = Uri.parse('$baseUrl$endpoint');
      final request = http.MultipartRequest(method, uri);

      // Add headers
      request.headers.addAll({'Accept': 'application/json'});
      if (_accessToken != null) {
        request.headers['Authorization'] = 'Bearer $_accessToken';
      }

      // Add fields
      request.fields.addAll(fields);

      // Add files
      request.files.addAll(files);

      final streamedResponse = await request.send().timeout(timeoutDuration);
      return await http.Response.fromStream(streamedResponse);
    });
  }
}
