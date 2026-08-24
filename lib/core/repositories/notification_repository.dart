import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:kd_pannel/core/network/api_client.dart';

/// Repository for handling push and in-app notifications.
class NotificationRepository {
  static final NotificationRepository _instance =
      NotificationRepository._internal();
  factory NotificationRepository() => _instance;
  NotificationRepository._internal();

  final ApiClient _apiClient = ApiClient();

  /// Fetch all notifications
  Future<List<Map<String, dynamic>>> fetchNotifications() async {
    try {
      final res = await _apiClient.get('/users/notifications');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['notifications'] ?? []);
        }
      }
    } catch (e) {
      debugPrint('[NotificationRepository] fetchNotifications error: $e');
    }
    return [];
  }

  /// Mark single notification as read
  Future<bool> markAsRead(String notifId) async {
    try {
      final res = await _apiClient.put('/users/notifications/read', {
        'notificationId': notifId,
      });
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[NotificationRepository] markAsRead error: $e');
      return false;
    }
  }

  /// Mark all notifications as read
  Future<bool> markAllAsRead() async {
    try {
      final res = await _apiClient.put('/users/notifications/read', {});
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[NotificationRepository] markAllAsRead error: $e');
      return false;
    }
  }

  /// Delete notification
  Future<bool> deleteNotification(String notifId) async {
    try {
      final res = await _apiClient.delete('/users/notifications/$notifId');
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[NotificationRepository] deleteNotification error: $e');
      return false;
    }
  }

  /// Delete all notifications
  Future<bool> deleteAllNotifications() async {
    try {
      final res = await _apiClient.delete('/users/notifications/all');
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[NotificationRepository] deleteAllNotifications error: $e');
      return false;
    }
  }

  /// Send in-app notification to a user
  Future<bool> sendNotification({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      final res = await _apiClient.post('/users/notifications/send', {
        'userId': userId,
        'title': title,
        'body': body,
        if (data != null) 'data': data,
      });
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (e) {
      debugPrint('[NotificationRepository] sendNotification error: $e');
      return false;
    }
  }
}
