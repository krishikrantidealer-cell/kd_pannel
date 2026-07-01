import 'dart:convert';
import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:kd_pannel/core/utils/local_cache_helper.dart';
import 'package:kd_pannel/core/utils/navigation_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http_parser/http_parser.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal() {
    // Workaround for Dart compiler tree-shaking bug on Web (NoSuchMethodError on Map.containsKey)
    try {
      final map = UnmodifiableMapView<String, String>({});
      map.containsKey('');
      final mediaType = MediaType('application', 'json');
      mediaType.parameters.containsKey('charset');
    } catch (_) {}
  }

  // The local Node.js server runs on port 5000 by default.
  // Using localhost is correct for Web.
  final String baseUrl =
      'https://krishi-backend-123180953109.asia-south1.run.app/api';

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

  Future<void> setTokens(
    String access,
    String refresh, {
    bool persistent = true,
  }) async {
    _accessToken = access;
    _refreshToken = refresh;
    if (persistent) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('kd_access_token', access);
        await prefs.setString('kd_refresh_token', refresh);
      } catch (e) {
        debugPrint('Failed to persist tokens: $e');
      }
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
      await prefs.remove('kd_user_id');
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

  Future<bool>? _refreshFuture;

  Future<bool> _refreshAccessToken() async {
    if (_refreshFuture != null) {
      return _refreshFuture!;
    }

    _refreshFuture = () async {
      try {
        await _ensureTokensLoaded();
        if (_refreshToken == null || _refreshToken!.isEmpty) return false;

        final uri = Uri.parse('$baseUrl/auth/refresh');
        final response = await http
            .post(
              uri,
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
              body: jsonEncode({'refreshToken': _refreshToken}),
            )
            .timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          try {
            final decoded = jsonDecode(response.body);
            if (decoded is Map) {
              final bool hasSuccess = decoded['success'] == true;
              final bool hasToken = decoded['token'] != null || decoded['accessToken'] != null;
              
              if (hasSuccess || hasToken) {
                final String? newAccess = (decoded['accessToken'] ?? decoded['token'])?.toString();
                if (newAccess != null) {
                  // Update but keep old refresh token if a new one isn't provided
                  final String newRefresh = decoded['refreshToken']?.toString() ?? _refreshToken!;
                  await setTokens(newAccess, newRefresh, persistent: true);
                  return true;
                }
              }
            }
          } catch (e) {
            debugPrint('[ApiClient] Token refresh logic error: $e');
          }
        }

        // If refresh failed with authorization error, clear tokens
        if (response.statusCode == 401 ||
            response.statusCode == 403 ||
            response.statusCode == 400) {
          await clearTokens();
          NavigationService.navigateToLogin();
        }
        return false;
      } catch (e) {
        debugPrint('Token refresh error: $e');
        return false;
      } finally {
        _refreshFuture = null;
      }
    }();

    return _refreshFuture!;
  }

  /// Helper to run request with automatic retries and exponential backoff.
  /// Designed to seamlessly handle backend server cold starts and network glitches.
  Future<http.Response> _requestWithRetry(
    Future<http.Response> Function(Duration currentTimeout) requestFn, {
    int maxRetries = 4,
    Duration initialDelay = const Duration(seconds: 1),
    bool isRetryAfterRefresh = false,
  }) async {
    int attempt = 0;
    while (true) {
      attempt++;
      // Give more timeout budget on subsequent attempts as server boots up.
      // 30s for the first attempt to account for backend cold starts (Cloud Run).
      final currentTimeout = attempt == 1
          ? const Duration(seconds: 30)
          : const Duration(seconds: 45);

      try {
        final response = await requestFn(currentTimeout);

        // Silent token refresh interceptor
        if (response.statusCode == 401 && !isRetryAfterRefresh) {
          final refreshed = await _refreshAccessToken();
          if (refreshed) {
            return await _requestWithRetry(
              requestFn,
              maxRetries: 1, // Only try once more after a fresh token
              isRetryAfterRefresh: true,
            );
          }
        }

        // Server cold start might return 502 / 503 / 504 gateway errors while booting
        if ((response.statusCode == 502 ||
                response.statusCode == 503 ||
                response.statusCode == 504) &&
            attempt < maxRetries) {
          if (!isBackendWakingUp.value) {
            isBackendWakingUp.value = true;
          }
          final delay = initialDelay * (1 << (attempt - 1));
          debugPrint(
            '[ApiClient] Server returned ${response.statusCode} (attempt $attempt). Retrying in ${delay.inSeconds}s...',
          );
          await Future.delayed(delay);
          continue;
        }

        // Success! Clear waking up indicator
        if (isBackendWakingUp.value) {
          isBackendWakingUp.value = false;
        }
        _handleTerminalAuthFailure(response);
        return response;
      } catch (e) {
        final isTimeout = e is TimeoutException;
        final errStr = e.toString().toLowerCase();
        final isConnectionError =
            errStr.contains('socketexception') ||
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
          debugPrint(
            '[ApiClient] Network error ($e) on attempt $attempt. Retrying in ${delay.inSeconds}s...',
          );
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

  // Multipart request helper for creating/updating products with images.
  // [filesBuilder] is called on EVERY attempt so each retry gets
  // fresh MultipartFile instances — reusing the same instances across
  // retries causes "Bad state: Can not finalize a finalized MultipartFile".
  Future<http.Response> multipartRequest({
    required String method,
    required String endpoint,
    required Map<String, String> fields,
    required List<http.MultipartFile> Function() filesBuilder,
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

      // Build fresh file instances for this attempt
      request.files.addAll(filesBuilder());

      final streamedResponse = await request.send().timeout(timeoutDuration);
      return await http.Response.fromStream(streamedResponse);
    });
  }

  // Like multipartRequest but calls [onProgress] with 0.0–1.0 as bytes upload.
  // Note: Does NOT retry network failures — progress streams cannot be rewound.
  // However, it does handle 401 unauthorized token refresh and retries the entire request once.
  Future<http.Response> multipartRequestWithProgress({
    required String method,
    required String endpoint,
    required Map<String, String> fields,
    required List<http.MultipartFile> Function() filesBuilder,
    required void Function(double progress) onProgress,
    bool isRetryAfterRefresh = false,
  }) async {
    await _ensureTokensLoaded();

    final uri = Uri.parse('$baseUrl$endpoint');

    // Build the multipart request to get its finalized stream + content type
    final mpRequest = http.MultipartRequest(method, uri);
    mpRequest.headers.addAll({'Accept': 'application/json'});
    if (_accessToken != null) {
      mpRequest.headers['Authorization'] = 'Bearer $_accessToken';
    }
    mpRequest.fields.addAll(fields);
    mpRequest.files.addAll(filesBuilder());

    final totalBytes = mpRequest.contentLength;
    final bodyStream = mpRequest.finalize(); // consumes the MultipartRequest

    int sentBytes = 0;
    final countingStream = bodyStream.map((chunk) {
      sentBytes += chunk.length;
      if (totalBytes != null && totalBytes > 0) {
        onProgress((sentBytes / totalBytes).clamp(0.0, 1.0));
      }
      return chunk;
    });

    // Build a StreamedRequest and pipe our counting stream into it
    final streamedReq = http.StreamedRequest(method, uri);
    streamedReq.headers.addAll(mpRequest.headers);
    if (totalBytes != null) streamedReq.contentLength = totalBytes;

    // Pipe counting stream → StreamedRequest sink (non-blocking)
    countingStream.listen(
      streamedReq.sink.add,
      onError: streamedReq.sink.addError,
      onDone: streamedReq.sink.close,
    );

    final streamedResponse = await http.Client()
        .send(streamedReq)
        .timeout(const Duration(minutes: 5));
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 401 && !isRetryAfterRefresh) {
      final refreshed = await _refreshAccessToken();
      if (refreshed) {
        final retryRes = await multipartRequestWithProgress(
          method: method,
          endpoint: endpoint,
          fields: fields,
          filesBuilder: filesBuilder,
          onProgress: onProgress,
          isRetryAfterRefresh: true,
        );
        _handleTerminalAuthFailure(retryRes);
        return retryRes;
      }
    }

    _handleTerminalAuthFailure(response);
    return response;
  }

  /// Uploads a large file in smaller chunks to the backend to prevent OOM errors,
  /// bypass Cloudflare's payload limits, and avoid browser CORS errors.
  Future<String> uploadFileInChunks({
    required Uint8List fileBytes,
    required String fileName,
    required String categoryName,
    required void Function(double progress) onProgress,
  }) async {
    const int chunkSize = 5 * 1024 * 1024; // 5 MB chunks
    final int totalChunks = (fileBytes.length / chunkSize).ceil();

    // 1. Initialize chunked upload
    final initResponse = await post('/products/categories/upload/init', {
      'fileName': fileName,
      'totalChunks': totalChunks,
      'categoryName': categoryName,
    });

    if (initResponse.statusCode != 200) {
      final err = jsonDecode(initResponse.body);
      throw Exception(err['message'] ?? 'Failed to initialize chunked upload');
    }

    final initData = jsonDecode(initResponse.body);
    if (initData['success'] != true) {
      throw Exception('Failed to initialize chunked upload');
    }

    final String uploadId = initData['uploadId'];

    // 2. Upload chunks sequentially
    for (int i = 0; i < totalChunks; i++) {
      final int start = i * chunkSize;
      final int end = (start + chunkSize < fileBytes.length)
          ? start + chunkSize
          : fileBytes.length;
      final Uint8List chunkBytes = fileBytes.sublist(start, end);

      final ext = fileName.split('.').last.toLowerCase();
      final contentType = ext == 'pdf'
          ? MediaType('application', 'pdf')
          : MediaType('application', 'octet-stream');

      final chunkResponse = await multipartRequest(
        method: 'POST',
        endpoint: '/products/categories/upload/chunk',
        fields: {'uploadId': uploadId, 'chunkIndex': i.toString()},
        filesBuilder: () => [
          http.MultipartFile.fromBytes(
            'file',
            chunkBytes,
            filename: '${fileName}_chunk_$i',
            contentType: contentType,
          ),
        ],
      );

      if (chunkResponse.statusCode != 200) {
        final err = jsonDecode(chunkResponse.body);
        throw Exception(err['message'] ?? 'Failed to upload chunk $i');
      }

      onProgress(((i + 1) / totalChunks).clamp(0.0, 1.0));
    }

    // 3. Complete chunked upload
    final completeResponse = await post(
      '/products/categories/upload/complete',
      {'uploadId': uploadId},
    );

    if (completeResponse.statusCode != 200) {
      final err = jsonDecode(completeResponse.body);
      throw Exception(err['message'] ?? 'Failed to finalize chunked upload');
    }

    final completeData = jsonDecode(completeResponse.body);
    if (completeData['success'] != true || completeData['fileUrl'] == null) {
      throw Exception('Failed to finalize chunked upload');
    }

    return completeData['fileUrl'];
  }

  void _handleTerminalAuthFailure(http.Response response) {
    if (response.statusCode == 401 || response.statusCode == 403) {
      final path = response.request?.url.path ?? '';
      if (!path.endsWith('/auth/admin/login')) {
        // Only log and redirect if we aren't already doing so
        if (!NavigationService.isRedirectingToLogin) {
          debugPrint('[ApiClient] Terminal auth failure (${response.statusCode}) at path: $path. Redirecting to login.');
          NavigationService.navigateToLogin();
        }
      }
    }
  }
}
