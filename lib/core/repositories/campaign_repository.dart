import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:kd_pannel/core/network/api_client.dart';

/// Repository for handling Push Campaigns, Templates, and Audience Segments.
class CampaignRepository {
  static final CampaignRepository _instance = CampaignRepository._internal();
  factory CampaignRepository() => _instance;
  CampaignRepository._internal();

  final ApiClient _apiClient = ApiClient();

  List<Map<String, dynamic>>? _cachedSegments;
  List<Map<String, dynamic>>? _cachedTemplates;
  DateTime? _segmentsCacheTime;
  DateTime? _templatesCacheTime;
  static const Duration _cacheTtl = Duration(minutes: 3);

  /// Fetch marketing campaign segments.
  Future<List<Map<String, dynamic>>> getSegments({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _cachedSegments != null &&
        _segmentsCacheTime != null &&
        DateTime.now().difference(_segmentsCacheTime!) < _cacheTtl) {
      return _cachedSegments!;
    }

    try {
      final response = await _apiClient.get('/marketing/segments');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List list = data is List
            ? data
            : (data['segments'] ?? data['data'] ?? []);
        final parsed = list
            .map((s) => Map<String, dynamic>.from(s as Map))
            .toList();
        _cachedSegments = parsed;
        _segmentsCacheTime = DateTime.now();
        return parsed;
      }
    } catch (e) {
      debugPrint('[CampaignRepository] getSegments error: $e');
    }

    return _cachedSegments ?? [];
  }

  /// Fetch notification templates.
  Future<List<Map<String, dynamic>>> getTemplates({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _cachedTemplates != null &&
        _templatesCacheTime != null &&
        DateTime.now().difference(_templatesCacheTime!) < _cacheTtl) {
      return _cachedTemplates!;
    }

    try {
      final response = await _apiClient.get('/marketing/templates');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List list = data is List
            ? data
            : (data['templates'] ?? data['data'] ?? []);
        final parsed = list
            .map((t) => Map<String, dynamic>.from(t as Map))
            .toList();
        _cachedTemplates = parsed;
        _templatesCacheTime = DateTime.now();
        return parsed;
      }
    } catch (e) {
      debugPrint('[CampaignRepository] getTemplates error: $e');
    }

    return _cachedTemplates ?? [];
  }

  /// Send test push notification.
  Future<Map<String, dynamic>> sendTestPush({
    required String phone,
    required String title,
    required String body,
    String? imageUrl,
    Map<String, dynamic>? data,
  }) async {
    try {
      final payload = {
        'phone': phone.trim(),
        'title': title.trim(),
        'body': body.trim(),
        if (imageUrl != null && imageUrl.trim().isNotEmpty) 'imageUrl': imageUrl.trim(),
        if (data != null) 'data': data,
      };

      final response = await _apiClient.post(
        '/marketing/push/test',
        payload,
      );

      if (response.statusCode == 200) {
        final resData = jsonDecode(response.body);
        return {
          'success': resData['success'] == true,
          'message': resData['message'] ?? 'Test notification sent successfully',
        };
      } else {
        final resData = jsonDecode(response.body);
        return {
          'success': false,
          'message': resData['message'] ?? 'Failed to send test push (HTTP ${response.statusCode})',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  void invalidateCache() {
    _cachedSegments = null;
    _cachedTemplates = null;
    _segmentsCacheTime = null;
    _templatesCacheTime = null;
  }
}
