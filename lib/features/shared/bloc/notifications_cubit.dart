import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kd_pannel/core/network/api_client.dart';
import 'package:kd_pannel/core/network/websocket_service.dart';
import 'package:kd_pannel/core/repositories/notification_repository.dart';
import 'package:kd_pannel/core/utils/navigation_service.dart';
import 'package:kd_pannel/features/shared/bloc/notifications_state.dart';
import 'package:kd_pannel/util/web_notification_helper.dart';

class NotificationsCubit extends Cubit<NotificationsState> {
  StreamSubscription? _webSocketSub;
  StreamSubscription? _payloadSub;
  Timer? _pollingTimer;
  final NotificationRepository _notificationRepo = NotificationRepository();
  final Set<String> _seenNotificationIds = {};
  bool _hasSeededInitial = false;
  bool _isFetching = false;

  NotificationsCubit() : super(const NotificationsState()) {
    _init();
  }

  void _init() {
    // 0ms Instant WebSocket Payload Ingestion
    _payloadSub = WebSocketService().notificationPayloads.listen((notif) {
      _ingestLiveNotification(notif);
    });

    // Standard WebSocket notification signal fallback
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

  void _ingestLiveNotification(Map<String, dynamic> newNotif) {
    final id = (newNotif['_id'] ?? newNotif['id'])?.toString() ?? '';
    if (id.isEmpty) return;

    final isUnread = newNotif['isRead'] == false || newNotif['isRead'] == null;
    final bool isFirstSeen = !_seenNotificationIds.contains(id);
    _seenNotificationIds.add(id);

    if (isFirstSeen && isUnread) {
      _triggerBrowserNotification(newNotif);
    }

    // Merge or prepend into state list immediately
    final existingIdx = state.notifications.indexWhere(
      (n) => (n['_id'] ?? n['id'])?.toString() == id,
    );
    final List<Map<String, dynamic>> updated = List<Map<String, dynamic>>.from(
      state.notifications,
    );
    if (existingIdx >= 0) {
      updated[existingIdx] = newNotif;
    } else {
      updated.insert(0, newNotif);
    }

    final unread = updated
        .where((n) => n['isRead'] == false || n['isRead'] == null)
        .length;
    emit(state.copyWith(notifications: updated, unreadCount: unread));
  }

  void _triggerBrowserNotification(Map<String, dynamic> notif) {
    final title = (notif['title'] ?? 'New Panel Alert').toString();
    final body = (notif['body'] ?? '').toString();
    final priority = resolvePriority(notif);

    showWebNotification(
      title,
      body,
      priority: priority,
      onTap: () {
        final id = (notif['_id'] ?? notif['id'])?.toString();
        if (id != null && id.isNotEmpty) {
          markAsRead(id);
        }
        navigateToAlertTarget(notif);
      },
    );
  }

  /// Resolves the structured alert category for UI tabs & icons:
  /// Returns one of: 'tasks_calls', 'leads_kyc', 'orders', 'whatsapp', 'system'
  static String resolveCategoryBucket(Map<String, dynamic> item) {
    final type = (item['type'] ?? '').toString().toLowerCase();
    final title = (item['title'] ?? '').toString().toLowerCase();
    final route = (item['actionRoute'] ?? '').toString().toLowerCase();

    if (type == 'task_reminder' ||
        type == 'task_due_now' ||
        type == 'task_overdue_digest' ||
        type == 'missed_call' ||
        title.contains('reminder') ||
        title.contains('task due') ||
        title.contains('missed') ||
        route.contains('call')) {
      return 'tasks_calls';
    }

    if (type == 'whatsapp_inbound' ||
        title.contains('whatsapp') ||
        route.contains('whatsapp') ||
        route.contains('support')) {
      return 'whatsapp';
    }

    if (type == 'order_placed' ||
        type == 'order_updated' ||
        title.contains('order') ||
        route.contains('order')) {
      return 'orders';
    }

    if (type == 'lead_assigned' ||
        type == 'dealer_assigned' ||
        type == 'unassigned_lead_inflow' ||
        type == 'kyc_submitted' ||
        type == 'kyc_verified' ||
        type == 'kyc_rejected' ||
        type == 'kyc_sla_breach' ||
        title.contains('lead') ||
        title.contains('dealer') ||
        title.contains('assigned') ||
        title.contains('kyc') ||
        route.contains('lead') ||
        route.contains('dealer')) {
      return 'leads_kyc';
    }

    return 'system';
  }

  /// Resolves urgency priority ('critical', 'high', 'normal') with fallback inference for older records
  static String resolvePriority(Map<String, dynamic> item) {
    final rawPriority = (item['priority'] ?? '').toString().toLowerCase();
    if (rawPriority == 'critical' || rawPriority == 'high') {
      return rawPriority;
    }
    final type = (item['type'] ?? '').toString().toLowerCase();
    final title = (item['title'] ?? '').toString().toLowerCase();
    if (type == 'task_due_now' ||
        type == 'kyc_sla_breach' ||
        type == 'account_deleted' ||
        title.contains('due now') ||
        title.contains('sla breach')) {
      return 'critical';
    }
    if (type == 'task_reminder' ||
        type == 'lead_assigned' ||
        type == 'dealer_assigned' ||
        type == 'kyc_verified' ||
        type == 'kyc_rejected' ||
        type == 'kyc_submitted' ||
        type == 'order_placed' ||
        type == 'missed_call' ||
        title.contains('reminder') ||
        title.contains('assigned') ||
        title.contains('order')) {
      return 'high';
    }
    return 'normal';
  }

  /// Deep-links directly to the relevant CRM entity or module screen
  static void navigateToAlertTarget(
    Map<String, dynamic> item, {
    BuildContext? context,
  }) {
    final navState = NavigationService.navigatorKey.currentState;
    if (navState == null && context == null) return;

    final String type = (item['type'] ?? '').toString().toLowerCase();
    final String entityType = (item['entityType'] ?? '').toString().toLowerCase();
    final String rawEntityId = (item['entityId'] ?? '').toString().trim();
    final String rawRoute = (item['actionRoute'] ?? '').toString().trim();
    final Map<String, dynamic> metadata = item['metadata'] is Map
        ? Map<String, dynamic>.from(item['metadata'] as Map)
        : <String, dynamic>{};

    final bool hasValidObjectId =
        RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(rawEntityId);

    void pushRoute(String routeName, {Object? arguments}) {
      if (context != null) {
        Navigator.pushNamed(context, routeName, arguments: arguments);
      } else {
        navState?.pushNamed(routeName, arguments: arguments);
      }
    }

    // 1. Dealer Profile Deep-Link
    if ((entityType == 'dealer' ||
            type == 'dealer_assigned' ||
            type == 'kyc_verified' ||
            rawRoute == '/dealers/profile') &&
        hasValidObjectId) {
      final customerName =
          (metadata['customerName'] ?? metadata['name'] ?? 'Dealer').toString();
      final phone =
          (metadata['phoneNumber'] ?? metadata['phone'] ?? '').toString();
      final shopName = (metadata['shopName'] ?? '').toString();

      pushRoute(
        '/dealers/profile',
        arguments: {
          '_id': rawEntityId,
          'id': rawEntityId,
          'name': customerName,
          'firstName': customerName,
          'phone': phone,
          'phoneNumber': phone,
          'shopName': shopName,
          'kycStatus': 'verified',
        },
      );
      return;
    }

    // 2. Lead Profile Deep-Link
    if ((entityType == 'lead' ||
            type == 'lead_assigned' ||
            type == 'unassigned_lead_inflow' ||
            type == 'kyc_submitted' ||
            type == 'kyc_rejected' ||
            rawRoute == '/leads/profile') &&
        hasValidObjectId) {
      final customerName =
          (metadata['customerName'] ?? metadata['name'] ?? 'Lead').toString();
      final phone =
          (metadata['phoneNumber'] ?? metadata['phone'] ?? '').toString();
      final shopName = (metadata['shopName'] ?? '').toString();

      pushRoute(
        '/leads/profile',
        arguments: {
          '_id': rawEntityId,
          'id': rawEntityId,
          'name': customerName,
          'firstName': customerName,
          'phone': phone,
          'phoneNumber': phone,
          'shopName': shopName,
        },
      );
      return;
    }

    // 3. Call Logs / Task Reminders / Missed Calls
    if (type == 'task_reminder' ||
        type == 'task_due_now' ||
        type == 'missed_call' ||
        type == 'task_overdue_digest' ||
        rawRoute == '/call-logs' ||
        rawRoute == '/calls' ||
        rawRoute == '/call-recordings') {
      pushRoute('/calls');
      return;
    }

    // 4. WhatsApp CRM
    if (type == 'whatsapp_inbound' ||
        rawRoute == '/whatsapp-crm' ||
        rawRoute == '/whatsapp' ||
        rawRoute == '/support') {
      pushRoute('/whatsapp');
      return;
    }

    // 5. Orders
    if (type == 'order_placed' ||
        type == 'order_updated' ||
        entityType == 'order' ||
        rawRoute.startsWith('/orders')) {
      pushRoute('/orders');
      return;
    }

    // 6. Fallback route normalization
    if (rawRoute.isNotEmpty && rawRoute != '/') {
      String navRoute = rawRoute;
      if (rawRoute == '/leads/profile') navRoute = '/leads';
      if (rawRoute == '/dealers/profile') navRoute = '/dealers';
      pushRoute(navRoute);
    }
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
              _triggerBrowserNotification(newNotif);
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

  Future<void> clearAllNotifications() async {
    _seenNotificationIds.clear();
    emit(state.copyWith(notifications: const [], unreadCount: 0));
    await _notificationRepo.deleteNotification('all');
  }

  void reset() {
    _seenNotificationIds.clear();
    _hasSeededInitial = false;
    emit(const NotificationsState());
  }

  @override
  Future<void> close() {
    _webSocketSub?.cancel();
    _payloadSub?.cancel();
    _pollingTimer?.cancel();
    return super.close();
  }
}

