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

  /// Fetch full marketing campaign payload and banners.
  Future<Map<String, dynamic>> fetchFullMarketingPayload() async {
    final results = await Future.wait([
      _apiClient.get('/marketing/push-campaigns'),
      _apiClient.get('/banners'),
    ]);

    Map<String, dynamic> campaignsData = {};
    List<dynamic> bannersList = [];

    if (results[0].statusCode == 200) {
      final data = jsonDecode(results[0].body);
      if (data['success'] == true && data['data'] is Map) {
        campaignsData = Map<String, dynamic>.from(data['data']);
      }
    }

    if (results[1].statusCode == 200) {
      final data = jsonDecode(results[1].body);
      if (data['success'] == true && data['banners'] is List) {
        bannersList = data['banners'] as List;
      }
    }

    return {
      'campaignsData': campaignsData,
      'banners': bannersList,
    };
  }

  /// Create a push campaign.
  Future<Map<String, dynamic>> createCampaign(Map<String, dynamic> data) async {
    final response = await _apiClient.post('/marketing/push-campaigns', data);
    final resData = jsonDecode(response.body);
    if (response.statusCode == 200 || response.statusCode == 201) {
      if (resData['success'] == true) {
        invalidateCache();
        return resData;
      }
      throw Exception(resData['message'] ?? 'Failed to create campaign');
    }
    throw Exception(resData['message'] ?? 'Server error: ${response.statusCode}');
  }

  /// Update a push campaign.
  Future<Map<String, dynamic>> updateCampaign(String id, Map<String, dynamic> data) async {
    final response = await _apiClient.put('/marketing/push-campaigns/$id', data);
    final resData = jsonDecode(response.body);
    if (response.statusCode == 200) {
      if (resData['success'] == true) {
        invalidateCache();
        return resData;
      }
      throw Exception(resData['message'] ?? 'Failed to update campaign');
    }
    throw Exception(resData['message'] ?? 'Server error: ${response.statusCode}');
  }

  /// Delete a push campaign.
  Future<bool> deleteCampaign(String id) async {
    final response = await _apiClient.delete('/marketing/push-campaigns/$id');
    final resData = jsonDecode(response.body);
    if (response.statusCode == 200 && resData['success'] == true) {
      invalidateCache();
      return true;
    }
    throw Exception(resData['message'] ?? 'Failed to delete campaign');
  }

  /// Create an in-app promotional banner.
  Future<Map<String, dynamic>> createBanner(Map<String, dynamic> data) async {
    final response = await _apiClient.post('/banners', data);
    final resData = jsonDecode(response.body);
    if (response.statusCode == 200 || response.statusCode == 201) {
      if (resData['success'] == true) {
        invalidateCache();
        return resData;
      }
      throw Exception(resData['message'] ?? 'Failed to create banner');
    }
    throw Exception(resData['message'] ?? 'Server error: ${response.statusCode}');
  }

  /// Update an in-app promotional banner.
  Future<Map<String, dynamic>> updateBanner(String id, Map<String, dynamic> data) async {
    final response = await _apiClient.put('/banners/$id', data);
    final resData = jsonDecode(response.body);
    if (response.statusCode == 200) {
      if (resData['success'] == true) {
        invalidateCache();
        return resData;
      }
      throw Exception(resData['message'] ?? 'Failed to update banner');
    }
    throw Exception(resData['message'] ?? 'Server error: ${response.statusCode}');
  }

  /// Delete an in-app promotional banner.
  Future<bool> deleteBanner(String id) async {
    final response = await _apiClient.delete('/banners/$id');
    final resData = jsonDecode(response.body);
    if (response.statusCode == 200 && resData['success'] == true) {
      invalidateCache();
      return true;
    }
    throw Exception(resData['message'] ?? 'Failed to delete banner');
  }

  /// Manually trigger sending a push campaign immediately.
  Future<Map<String, dynamic>> triggerCampaign(String id) async {
    final response = await _apiClient.post('/marketing/push-campaigns/$id/trigger', {});
    final resData = jsonDecode(response.body);
    if (response.statusCode == 200 && resData['success'] == true) {
      invalidateCache();
      return resData;
    }
    throw Exception(resData['message'] ?? 'Failed to trigger campaign');
  }

  /// Create a new audience segment.
  Future<Map<String, dynamic>> createSegment(Map<String, dynamic> data) async {
    final response = await _apiClient.post('/marketing/segments', data);
    final resData = jsonDecode(response.body);
    if (response.statusCode == 200 || response.statusCode == 201) {
      if (resData['success'] == true) {
        invalidateCache();
        return resData;
      }
      throw Exception(resData['message'] ?? 'Failed to create segment');
    }
    throw Exception(resData['message'] ?? 'Server error: ${response.statusCode}');
  }

  /// Create a notification template.
  Future<Map<String, dynamic>> createTemplate(Map<String, dynamic> data) async {
    final response = await _apiClient.post('/marketing/templates', data);
    final resData = jsonDecode(response.body);
    if (response.statusCode == 200 || response.statusCode == 201) {
      if (resData['success'] == true) {
        invalidateCache();
        return resData;
      }
      throw Exception(resData['message'] ?? 'Failed to create template');
    }
    throw Exception(resData['message'] ?? 'Server error: ${response.statusCode}');
  }

  /// Update segment configuration.
  Future<Map<String, dynamic>> updateCampaignConfig(String segmentKey, Map<String, dynamic> config) async {
    final response = await _apiClient.put('/marketing/push-campaigns/$segmentKey/config', config);
    final resData = jsonDecode(response.body);
    if (response.statusCode == 200) {
      invalidateCache();
      return resData;
    }
    throw Exception(resData['message'] ?? 'Failed to update campaign config: ${response.statusCode}');
  }

  /// Delete campaign segment.
  Future<bool> deleteCampaignSegment(String segmentKey) async {
    final response = await _apiClient.delete('/marketing/push-campaigns/$segmentKey');
    if (response.statusCode == 200 || response.statusCode == 204) {
      invalidateCache();
      return true;
    }
    final resData = jsonDecode(response.body);
    throw Exception(resData['message'] ?? 'Failed to delete segment');
  }

  /// Add campaign template.
  Future<Map<String, dynamic>> addCampaignTemplate(String segmentKey, Map<String, dynamic> templateData) async {
    final response = await _apiClient.post('/marketing/push-campaigns/$segmentKey/templates', templateData);
    final resData = jsonDecode(response.body);
    if (response.statusCode == 200 || response.statusCode == 201) {
      invalidateCache();
      return resData;
    }
    throw Exception(resData['message'] ?? 'Failed to add template');
  }

  /// Update campaign template.
  Future<Map<String, dynamic>> updateCampaignTemplate(String segmentKey, String templateId, Map<String, dynamic> templateData) async {
    final response = await _apiClient.put('/marketing/push-campaigns/$segmentKey/templates/$templateId', templateData);
    final resData = jsonDecode(response.body);
    if (response.statusCode == 200) {
      invalidateCache();
      return resData;
    }
    throw Exception(resData['message'] ?? 'Failed to update template');
  }

  /// Delete campaign template.
  Future<bool> deleteCampaignTemplate(String segmentKey, String templateId) async {
    final response = await _apiClient.delete('/marketing/push-campaigns/$segmentKey/templates/$templateId');
    if (response.statusCode == 200) {
      invalidateCache();
      return true;
    }
    throw Exception('Failed to delete template');
  }

  /// Trigger segment broadcast now.
  Future<Map<String, dynamic>> triggerCampaignNow(String segmentKey, {Map<String, dynamic>? customTemplate}) async {
    final response = await _apiClient.post(
      '/marketing/push-campaigns/$segmentKey/trigger-now',
      customTemplate != null ? {'customTemplate': customTemplate} : {},
    );
    final resData = jsonDecode(response.body);
    if (response.statusCode == 200 && resData['success'] == true) {
      invalidateCache();
      return resData;
    }
    throw Exception(resData['message'] ?? 'Failed to trigger broadcast');
  }

  /// Send test push for a segment template.
  Future<Map<String, dynamic>> sendSegmentTestPush(String segmentKey, String phone, Map<String, dynamic> templateData) async {
    final response = await _apiClient.post(
      '/marketing/push-campaigns/$segmentKey/send-test',
      {
        'phoneNumber': phone,
        'template': templateData,
      },
    );
    final resData = jsonDecode(response.body);
    if (response.statusCode == 200 && resData['success'] == true) {
      return resData;
    }
    throw Exception(resData['message'] ?? 'Failed to send test push');
  }

  void invalidateCache() {
    _cachedSegments = null;
    _cachedTemplates = null;
    _segmentsCacheTime = null;
    _templatesCacheTime = null;
  }
}
