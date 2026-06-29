import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:kd_pannel/core/network/api_client.dart';
import 'package:kd_pannel/core/auth/auth_service.dart';

class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  final ApiClient _apiClient = ApiClient();

  /// Logs a user event to the database via JS Backend /events endpoint
  Future<void> logEvent(String eventName, {Map<String, dynamic>? properties}) async {
    try {
      final userEmail = AuthService().currentUserEmail ?? 'Guest';
      final role = AuthService().currentUserRole?.name ?? 'unknown';
      final timestamp = DateTime.now().toUtc().toIso8601String();
      
      String device = 'Unknown Device';
      if (kIsWeb) {
        device = 'Chrome/Safari Browser (Web)';
      } else {
        device = '${defaultTargetPlatform.name.toUpperCase()} Mobile App';
      }

      // Generate a user-friendly detail text
      String details = '';
      if (properties != null && properties.isNotEmpty) {
        if (properties.containsKey('details')) {
          details = properties['details'].toString();
        } else {
          details = properties.entries
              .where((e) => e.key != 'details' && e.value != null)
              .take(3)
              .map((e) => '${e.key}: ${e.value}')
              .join(' • ');
        }
      }

      final body = {
        'user': userEmail,
        'eventType': eventName,
        'device': device,
        'details': details,
        'payload': properties ?? {},
        'timestamp': timestamp,
        'role': role,
      };

      debugPrint('[AnalyticsService] Tracking: $eventName');
      
      // Call backend API
      final response = await _apiClient.post('/events', body);
      if (response.statusCode != 200 && response.statusCode != 201) {
        debugPrint('[AnalyticsService] Failed to log event. Status: ${response.statusCode}, Body: ${response.body}');
      }
    } catch (e) {
      debugPrint('[AnalyticsService] Error logging event: $e');
    }
  }

  /// Fetches logged events from the database
  Future<List<Map<String, dynamic>>> fetchEvents() async {
    try {
      final response = await _apiClient.get('/events');
      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);
        if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        } else if (data is Map) {
          if (data['success'] == true && data['data'] is List) {
            return List<Map<String, dynamic>>.from(data['data']);
          } else if (data['events'] is List) {
            return List<Map<String, dynamic>>.from(data['events']);
          }
        }
      }
      debugPrint('[AnalyticsService] Failed to fetch events. Status: ${response.statusCode}');
      return [];
    } catch (e) {
      debugPrint('[AnalyticsService] Error fetching events: $e');
      return [];
    }
  }
}
