import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kd_pannel/core/network/api_client.dart';
import 'package:kd_pannel/core/network/websocket_service.dart';
import 'package:kd_pannel/core/repositories/notification_repository.dart';
import 'package:kd_pannel/features/shared/bloc/notifications_state.dart';
import 'package:kd_pannel/util/web_notification_helper.dart';

class NotificationsCubit extends Cubit<NotificationsState> {
  StreamSubscription? _webSocketSub;
  Timer? _pollingTimer;
  final NotificationRepository _notificationRepo = NotificationRepository();
  final Set<String> _seenNotificationIds = {};
  bool _hasSeededInitial = false;
  bool _isFetching = false;

  NotificationsCubit() : super(const NotificationsState()) {
    _init();
  }

  void _init() {
    _webSocketSub = WebSocketService().notificationUpdates.listen((_) {
      fetchNotifications(isInitial: false);
    });

    // Periodic 15-second sync so alerts from Cloud Scheduler cron jobs (e.g. Task Reminders)
    // or other Cloud Run instances always trigger browser notifications promptly.
    _pollingTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      final token = ApiClient().accessToken;
      if (token != null && token.isNotEmpty) {
        fetchNotifications(isInitial: false);
      }
    });
  }

  Future<void> fetchNotifications({bool isInitial = false}) async {
    final token = ApiClient().accessToken;
    if (token == null || token.isEmpty) {
      return;
    }

    if (_isFetching) return;
    _isFetching = true;

    if (isInitial && state.notifications.isEmpty) {
      emit(state.copyWith(isLoading: true));
    }

    try {
      final list = await _notificationRepo.fetchNotifications();

      if (!_hasSeededInitial) {
        for (final notif in list) {
          final id = (notif['_id'] ?? notif['id'])?.toString();
          if (id != null && id.isNotEmpty) {
            _seenNotificationIds.add(id);
          }
        }
        _hasSeededInitial = true;
      } else if (list.isNotEmpty) {
        // Detect any brand-new unread notifications and fire browser notification
        for (final newNotif in list) {
          final id = (newNotif['_id'] ?? newNotif['id'])?.toString() ?? '';
          if (id.isEmpty) continue;

          final isUnread =
              newNotif['isRead'] == false || newNotif['isRead'] == null;

          if (!_seenNotificationIds.contains(id)) {
            _seenNotificationIds.add(id);
            if (isUnread) {
              final title =
                  (newNotif['title'] ?? 'New Panel Alert').toString();
              final body = (newNotif['body'] ?? '').toString();
              showWebNotification(title, body);
            }
          }
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
    } finally {
      _isFetching = false;
    }
  }

  Future<void> markAsRead(String notifId) async {
    _seenNotificationIds.add(notifId);
    final updated = state.notifications.map((n) {
      if ((n['_id'] ?? n['id']) == notifId) {
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
    for (final n in state.notifications) {
      final id = (n['_id'] ?? n['id'])?.toString();
      if (id != null) _seenNotificationIds.add(id);
    }
    final updated = state.notifications
        .map((n) => {...n, 'isRead': true})
        .toList();
    emit(state.copyWith(notifications: updated, unreadCount: 0));

    await _notificationRepo.markAllAsRead();
  }

  Future<void> deleteNotification(String notifId) async {
    _seenNotificationIds.remove(notifId);
    final updated = state.notifications
        .where((n) => (n['_id'] ?? n['id']) != notifId)
        .toList();
    final unread = updated
        .where((n) => n['isRead'] == false || n['isRead'] == null)
        .length;
    emit(state.copyWith(notifications: updated, unreadCount: unread));

    await _notificationRepo.deleteNotification(notifId);
  }

  void reset() {
    _seenNotificationIds.clear();
    _hasSeededInitial = false;
    emit(const NotificationsState());
  }

  @override
  Future<void> close() {
    _webSocketSub?.cancel();
    _pollingTimer?.cancel();
    return super.close();
  }
}

