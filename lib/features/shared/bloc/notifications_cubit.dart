import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kd_pannel/core/network/websocket_service.dart';
import 'package:kd_pannel/core/repositories/notification_repository.dart';
import 'package:kd_pannel/features/shared/bloc/notifications_state.dart';
import 'package:kd_pannel/util/web_notification_helper.dart';

class NotificationsCubit extends Cubit<NotificationsState> {
  StreamSubscription? _webSocketSub;
  final NotificationRepository _notificationRepo = NotificationRepository();

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
      final list = await _notificationRepo.fetchNotifications();

      // Check for brand new unread notifications received in real-time
      if (!isInitial && list.isNotEmpty) {
        final newUnreadNotifications = list.where((newNotif) {
          final isUnread =
              newNotif['isRead'] == false || newNotif['isRead'] == null;
          if (!isUnread) return false;
          final existsBefore = state.notifications.any(
            (oldNotif) => oldNotif['_id'] == newNotif['_id'],
          );
          return !existsBefore;
        }).toList();

        for (final notif in newUnreadNotifications) {
          final title = notif['title'] ?? 'New Notification';
          final body = notif['body'] ?? '';
          showWebNotification(title, body);
        }
      }

      final unread = list
          .where((n) => n['isRead'] == false || n['isRead'] == null)
          .length;
      emit(
        state.copyWith(
          notifications: list,
          unreadCount: unread,
          isLoading: false,
        ),
      );
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

    final unread = updated
        .where((n) => n['isRead'] == false || n['isRead'] == null)
        .length;
    emit(state.copyWith(notifications: updated, unreadCount: unread));

    await _notificationRepo.markAsRead(notifId);
  }

  Future<void> markAllAsRead() async {
    final updated = state.notifications
        .map((n) => {...n, 'isRead': true})
        .toList();
    emit(state.copyWith(notifications: updated, unreadCount: 0));

    await _notificationRepo.markAllAsRead();
  }

  Future<void> deleteNotification(String notifId) async {
    final updated = state.notifications
        .where((n) => n['_id'] != notifId)
        .toList();
    final unread = updated
        .where((n) => n['isRead'] == false || n['isRead'] == null)
        .length;
    emit(state.copyWith(notifications: updated, unreadCount: unread));

    await _notificationRepo.deleteNotification(notifId);
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
