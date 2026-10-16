import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kd_pannel/app_theme.dart';
import 'package:kd_pannel/core/responsive/responsive.dart';
import 'package:kd_pannel/core/repositories/notification_repository.dart';
import 'package:kd_pannel/core/network/websocket_service.dart';
import 'package:kd_pannel/core/services/analytics_service.dart';
import 'package:kd_pannel/features/shared/bloc/notifications_cubit.dart';
import 'package:kd_pannel/util/web_notification_helper.dart';
import 'package:intl/intl.dart';

class AlertsPage extends StatefulWidget {
  const AlertsPage({super.key});

  @override
  State<AlertsPage> createState() => _AlertsPageState();
}

class _AlertsPageState extends State<AlertsPage> {
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  String _selectedFilter = 'All'; // 'All' or 'Unread'
  StreamSubscription? _websocketSubscription;
  StreamSubscription? _cubitSubscription;

  @override
  void initState() {
    super.initState();
    AnalyticsService().updateContext(screen: '/alerts');
    requestNotificationPermission();
    _fetchNotifications(isInitial: true);

    // Subscribe to real-time WebSocket updates
    _websocketSubscription = WebSocketService().notificationUpdates.listen((_) {
      _fetchNotifications(isInitial: false);
    });

    // Also stay synced with NotificationsCubit periodic 15s polling
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final cubit = context.read<NotificationsCubit>();
      _cubitSubscription = cubit.stream.listen((notifState) {
        if (mounted && notifState.notifications.isNotEmpty) {
          setState(() {
            _notifications = List<Map<String, dynamic>>.from(notifState.notifications);
            _isLoading = false;
          });
        }
      });
    });
  }

  @override
  void dispose() {
    _websocketSubscription?.cancel();
    _cubitSubscription?.cancel();
    super.dispose();
  }

  Future<void> _fetchNotifications({bool isInitial = false}) async {
    if (isInitial) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final notifications = await NotificationRepository().fetchNotifications();
      if (mounted) {
        setState(() {
          _notifications = notifications;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[AlertsPage] Error fetching notifications: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      final success = await NotificationRepository().markAllAsRead();
      if (success) {
        await _fetchNotifications(isInitial: false);
        WebSocketService().triggerNotificationUpdate(); // Update sidebar/topbar badges
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'All notifications marked as read',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              backgroundColor: AppTheme.primaryColor,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[AlertsPage] Error marking read: $e');
    }
  }

  Future<void> _markAsRead(String id) async {
    try {
      final success = await NotificationRepository().markAsRead(id);
      if (success) {
        await _fetchNotifications(isInitial: false);
        WebSocketService().triggerNotificationUpdate();
      }
    } catch (e) {
      debugPrint('[AlertsPage] Error marking single notification as read: $e');
    }
  }

  Future<void> _deleteNotification(String id) async {
    try {
      // Optimistic UI: remove immediately
      setState(() {
        _notifications.removeWhere((n) => (n['_id'] ?? n['id']) == id);
      });
      final success = await NotificationRepository().deleteNotification(id);
      if (!success) {
        // Revert on failure
        await _fetchNotifications(isInitial: false);
      } else {
        WebSocketService().triggerNotificationUpdate();
      }
    } catch (e) {
      debugPrint('[AlertsPage] Error deleting notification: $e');
      await _fetchNotifications(isInitial: false);
    }
  }

  Future<void> _deleteAllNotifications() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Clear All Notifications',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        content: Text(
          'Are you sure you want to delete all notifications? This action cannot be undone.',
          style: GoogleFonts.outfit(fontSize: 14, color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.outfit(color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Clear All', style: GoogleFonts.outfit(color: AppTheme.error, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      setState(() => _notifications.clear());
      final success = await NotificationRepository().deleteAllNotifications();
      if (!success) {
        await _fetchNotifications(isInitial: false);
      } else {
        WebSocketService().triggerNotificationUpdate();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'All notifications cleared',
                style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
              ),
              backgroundColor: AppTheme.error,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[AlertsPage] Error clearing all notifications: $e');
      await _fetchNotifications(isInitial: false);
    }
  }

  List<Map<String, dynamic>> get _filteredNotifications {
    return _notifications.where((n) {
      if (_selectedFilter == 'Unread') {
        return n['isRead'] == false || n['isRead'] == null;
      }
      if (_selectedFilter == 'Tasks & Calls') {
        return NotificationsCubit.resolveCategoryBucket(n) == 'tasks_calls';
      }
      if (_selectedFilter == 'Leads & KYC') {
        return NotificationsCubit.resolveCategoryBucket(n) == 'leads_kyc';
      }
      if (_selectedFilter == 'Orders') {
        return NotificationsCubit.resolveCategoryBucket(n) == 'orders';
      }
      if (_selectedFilter == 'WhatsApp') {
        return NotificationsCubit.resolveCategoryBucket(n) == 'whatsapp';
      }
      return true;
    }).toList();
  }

  int _unreadCountForFilter(String filter) {
    return _notifications.where((n) {
      final isUnread = n['isRead'] == false || n['isRead'] == null;
      if (!isUnread) return false;
      if (filter == 'All' || filter == 'Unread') return true;
      if (filter == 'Tasks & Calls') {
        return NotificationsCubit.resolveCategoryBucket(n) == 'tasks_calls';
      }
      if (filter == 'Leads & KYC') {
        return NotificationsCubit.resolveCategoryBucket(n) == 'leads_kyc';
      }
      if (filter == 'Orders') {
        return NotificationsCubit.resolveCategoryBucket(n) == 'orders';
      }
      if (filter == 'WhatsApp') {
        return NotificationsCubit.resolveCategoryBucket(n) == 'whatsapp';
      }
      return false;
    }).length;
  }

  int get _unreadCount {
    return _notifications.where((n) => n['isRead'] == false || n['isRead'] == null).length;
  }

  String _formatTimeAgo(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inSeconds < 60) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = Responsive.isMobile(context);
    final items = _filteredNotifications;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SelectionArea(
        child: RefreshIndicator(
          onRefresh: () => _fetchNotifications(isInitial: false),
          color: AppTheme.primaryColor,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: AppTheme.getResponsivePadding(context),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Header Row
                    isMobile
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildTitle(),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  if (_unreadCount > 0) _buildMarkAllReadButton(isMobile),
                                  if (_unreadCount > 0) const SizedBox(width: 8),
                                  if (_notifications.isNotEmpty) _buildClearAllButton(isMobile),
                                ],
                              ),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildTitle(),
                              Row(
                                children: [
                                  if (_unreadCount > 0) _buildMarkAllReadButton(isMobile),
                                  if (_unreadCount > 0 && _notifications.isNotEmpty) const SizedBox(width: 8),
                                  if (_notifications.isNotEmpty) _buildClearAllButton(isMobile),
                                ],
                              ),
                            ],
                          ),
                    const SizedBox(height: 24),

                    // Category Filters Bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  for (final filter in const [
                                    'All',
                                    'Unread',
                                    'Tasks & Calls',
                                    'Leads & KYC',
                                    'Orders',
                                    'WhatsApp',
                                  ])
                                    _buildFilterButton(
                                      filter,
                                      _selectedFilter == filter,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${items.length} alert(s)',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ]),
                ),
              ),
              if (_isLoading)
                const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 60.0),
                      child: CircularProgressIndicator(color: AppTheme.primaryColor),
                    ),
                  ),
                )
              else if (items.isEmpty)
                SliverPadding(
                  padding: AppTheme.getResponsivePadding(context).copyWith(top: 0),
                  sliver: SliverToBoxAdapter(child: _buildEmptyState()),
                )
              else
                SliverPadding(
                  padding: AppTheme.getResponsivePadding(context).copyWith(top: 0),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final item = items[index];
                        final String? id = item['_id'] ?? item['id'];
                        if (id == null) return _buildNotificationCard(item);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Dismissible(
                            key: Key(id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              decoration: BoxDecoration(
                                color: AppTheme.error,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 24),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Delete',
                                    style: GoogleFonts.outfit(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            confirmDismiss: (_) async => true,
                            onDismissed: (_) => _deleteNotification(id),
                            child: _buildNotificationCard(item),
                          ),
                        );
                      },
                      childCount: items.length,
                    ),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Alerts & Notifications',
          style: GoogleFonts.outfit(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Real-time task reminders, lead assignments, KYC updates, orders, and WhatsApp alerts.',
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildMarkAllReadButton(bool isMobile) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: _markAllAsRead,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.done_all_rounded,
                color: AppTheme.primaryColor,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Mark all as read',
                style: GoogleFonts.outfit(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClearAllButton(bool isMobile) {
    return Material(
      color: AppTheme.error.withOpacity(0.06),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: _deleteAllNotifications,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.error.withOpacity(0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.delete_sweep_rounded,
                color: AppTheme.error,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Clear all',
                style: GoogleFonts.outfit(
                  color: AppTheme.error,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterButton(String filter, bool isActive) {
    final int badgeCount = filter == 'All' ? 0 : _unreadCountForFilter(filter);
    return Material(
      color: isActive ? Colors.white : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      elevation: isActive ? 1 : 0,
      shadowColor: isActive ? Colors.black.withOpacity(0.1) : Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedFilter = filter;
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                filter,
                style: GoogleFonts.outfit(
                  color: isActive ? AppTheme.textPrimary : const Color(0xFF64748B),
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              if (badgeCount > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: filter == 'Unread'
                        ? AppTheme.error.withOpacity(0.12)
                        : AppTheme.primaryColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$badgeCount',
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: filter == 'Unread' ? AppTheme.error : AppTheme.primaryColor,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Icon(
              Icons.notifications_off_outlined,
              size: 48,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _selectedFilter == 'Unread'
                ? 'No unread notifications'
                : _selectedFilter == 'All'
                    ? 'All caught up!'
                    : 'No $_selectedFilter alerts',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedFilter == 'Unread'
                ? 'You do not have any unread notifications at the moment.'
                : 'When new alerts or updates arrive in this category, they will appear here.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> item) {
    final isUnread = item['isRead'] == false || item['isRead'] == null;
    final title = (item['title'] ?? 'Notification').toString();
    final body = (item['body'] ?? '').toString();
    final type = (item['type'] ?? '').toString().toLowerCase();
    final priority = NotificationsCubit.resolvePriority(item);
    final bucket = NotificationsCubit.resolveCategoryBucket(item);
    final timeStr = item['createdAt'] != null ? _formatTimeAgo(item['createdAt'].toString()) : '';

    IconData iconData = Icons.notifications_rounded;
    Color iconColor = const Color(0xFF475569);
    Color iconBg = const Color(0xFFF1F5F9);
    String actionLabel = 'View Details';

    if (bucket == 'tasks_calls') {
      if (type == 'missed_call' || title.toLowerCase().contains('missed')) {
        iconData = Icons.phone_missed_rounded;
        iconColor = const Color(0xFFDC2626);
        iconBg = const Color(0xFFFEE2E2);
        actionLabel = 'Open Call Logs';
      } else {
        iconData = Icons.alarm_on_rounded;
        iconColor = priority == 'critical' ? const Color(0xFFDC2626) : const Color(0xFFD97706);
        iconBg = priority == 'critical' ? const Color(0xFFFEE2E2) : const Color(0xFFFEF3C7);
        actionLabel = 'Open Call Task';
      }
    } else if (bucket == 'whatsapp') {
      iconData = Icons.chat_bubble_rounded;
      iconColor = const Color(0xFF059669);
      iconBg = const Color(0xFFD1FAE5);
      actionLabel = 'Reply on WhatsApp';
    } else if (bucket == 'orders') {
      iconData = Icons.shopping_bag_rounded;
      iconColor = Colors.amber.shade800;
      iconBg = Colors.amber.withOpacity(0.14);
      actionLabel = 'View Orders';
    } else if (bucket == 'leads_kyc') {
      if (type.contains('kyc') || title.contains('KYC')) {
        iconData = type == 'kyc_rejected' ? Icons.gpp_bad_rounded : Icons.verified_user_rounded;
        iconColor = type == 'kyc_rejected'
            ? const Color(0xFFDC2626)
            : (type == 'kyc_sla_breach' ? const Color(0xFFD97706) : const Color(0xFF16A34A));
        iconBg = iconColor.withOpacity(0.12);
        actionLabel = type == 'kyc_verified' ? 'Open Dealer Profile' : 'Review KYC / Lead';
      } else {
        iconData = Icons.person_add_alt_1_rounded;
        iconColor = Colors.indigo;
        iconBg = Colors.indigo.withOpacity(0.12);
        actionLabel = type == 'dealer_assigned' ? 'Open Dealer Profile' : 'Open Lead Profile';
      }
    } else if (title.contains('Blocked') || type == 'account_blocked' || type == 'account_deleted') {
      iconData = Icons.block_rounded;
      iconColor = Colors.red;
      iconBg = Colors.red.withOpacity(0.12);
      actionLabel = 'View Record';
    }

    final String? id = (item['_id'] ?? item['id'])?.toString();
    final Color leftBarColor = priority == 'critical'
        ? const Color(0xFFDC2626)
        : AppTheme.primaryColor;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          if (isUnread && id != null) {
            _markAsRead(id);
            try {
              context.read<NotificationsCubit>().markAsRead(id);
            } catch (_) {}
          }
          NotificationsCubit.navigateToAlertTarget(item, context: context);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isUnread
                  ? (priority == 'critical'
                      ? const Color(0xFFDC2626).withOpacity(0.35)
                      : AppTheme.primaryColor.withOpacity(0.2))
                  : const Color(0xFFE2E8F0),
              width: isUnread ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isUnread ? 0.04 : 0.01),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                if (isUnread)
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: 4,
                    child: Container(color: leftBarColor),
                  ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: iconBg,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(iconData, color: iconColor, size: 20),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (priority == 'critical') ...[
                                  Container(
                                    margin: const EdgeInsets.only(right: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEE2E2),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFFFECACA)),
                                    ),
                                    child: Text(
                                      'URGENT',
                                      style: GoogleFonts.outfit(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFFDC2626),
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                                  ),
                                ],
                                Expanded(
                                  child: Text(
                                    title,
                                    style: GoogleFonts.outfit(
                                      fontSize: 14,
                                      fontWeight: isUnread ? FontWeight.w700 : FontWeight.w600,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              body,
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Text(
                                  timeStr,
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF94A3B8),
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        actionLabel,
                                        style: GoogleFonts.outfit(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.primaryColor,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(
                                        Icons.arrow_forward_rounded,
                                        size: 12,
                                        color: AppTheme.primaryColor,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (isUnread)
                        Container(
                          margin: const EdgeInsets.only(top: 4, left: 8),
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: leftBarColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
