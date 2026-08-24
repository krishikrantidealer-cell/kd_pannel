import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kd_pannel/core/network/api_client.dart';
import 'package:kd_pannel/core/network/websocket_service.dart';
import 'package:kd_pannel/features/shared/bloc/notifications_state.dart';
import 'package:kd_pannel/util/web_notification_helper.dart';

class NotificationsCubit extends Cubit<NotificationsState> {
  StreamSubscription? _webSocketSub;

  NotificationsCubit() : super(const NotificationsState()) {
    _init();
  }

  void _init() {
    _webSocketSub = WebSocketService().notificationUpdates.listen((_) {
      fetchNotifications(isInitial: false);
    });
  }

  Future<void> fetchNotifications({bool isInitial = false}) async {
    if (isInitial && state.notifications.isEmpty) {
      emit(state.copyWith(isLoading: true));
    }

    try {
      final res = await ApiClient().get('/users/notifications');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) {
          final list = List<Map<String, dynamic>>.from(data['notifications'] ?? []);

          // Check for brand new unread notifications received in real-time
          if (!isInitial && list.isNotEmpty) {
            final newUnreadNotifications = list.where((newNotif) {
              final isUnread = newNotif['isRead'] == false || newNotif['isRead'] == null;
              if (!isUnread) return false;
              final existsBefore = state.notifications.any((oldNotif) => oldNotif['_id'] == newNotif['_id']);
              return !existsBefore;
            }).toList();

            for (final notif in newUnreadNotifications) {
              final title = notif['title'] ?? 'New Notification';
              final body = notif['body'] ?? '';
              showWebNotification(title, body);
            }
          }

          final unread = list.where((n) => n['isRead'] == false || n['isRead'] == null).length;
          emit(state.copyWith(
            notifications: list,
            unreadCount: unread,
            isLoading: false,
          ));
        }
      } else {
        emit(state.copyWith(isLoading: false));
      }
    } catch (e) {
      debugPrint('[NotificationsCubit] Error fetching notifications: $e');
      emit(state.copyWith(isLoading: false, errorMessage: e.toString()));
    }
  }

  Future<void> markAsRead(String notifId) async {
    final updated = state.notifications.map((n) {
      if (n['_id'] == notifId) {
        return {...n, 'isRead': true};
      }
      return n;
    }).toList();

    final unread = updated.where((n) => n['isRead'] == false || n['isRead'] == null).length;
    emit(state.copyWith(notifications: updated, unreadCount: unread));

    try {
      await ApiClient().put('/users/notifications/$notifId/read', {});
    } catch (e) {
      debugPrint('[NotificationsCubit] Error marking as read: $e');
    }
  }

  Future<void> markAllAsRead() async {
    final updated = state.notifications.map((n) => {...n, 'isRead': true}).toList();
    emit(state.copyWith(notifications: updated, unreadCount: 0));

    try {
      await ApiClient().put('/users/notifications/read-all', {});
    } catch (e) {
      debugPrint('[NotificationsCubit] Error marking all read: $e');
    }
  }

  Future<void> deleteNotification(String notifId) async {
    final updated = state.notifications.where((n) => n['_id'] != notifId).toList();
    final unread = updated.where((n) => n['isRead'] == false || n['isRead'] == null).length;
    emit(state.copyWith(notifications: updated, unreadCount: unread));

    try {
      await ApiClient().delete('/users/notifications/$notifId');
    } catch (e) {
      debugPrint('[NotificationsCubit] Error deleting notification: $e');
    }
  }

  void reset() {
    emit(const NotificationsState());
  }

  @override
  Future<void> close() {
    _webSocketSub?.cancel();
    return super.close();
  }
}
