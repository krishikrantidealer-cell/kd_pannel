import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:google_fonts/google_fonts.dart';
import 'package:kd_pannel/app_theme.dart';
import 'package:kd_pannel/core/responsive/responsive.dart';
import 'package:kd_pannel/util/web_notification_helper.dart';
import 'package:kd_pannel/core/auth/auth_service.dart';
import 'package:kd_pannel/core/utils/navigation_service.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kd_pannel/features/shared/bloc/notifications_cubit.dart';
import 'package:kd_pannel/features/shared/bloc/notifications_state.dart';

class TopbarWidget extends StatefulWidget {
  final VoidCallback? onMenuPressed;
  const TopbarWidget({super.key, this.onMenuPressed});

  @override
  State<TopbarWidget> createState() => _TopbarWidgetState();
}

class _TopbarWidgetState extends State<TopbarWidget> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isDropdownOpen = false;

  final LayerLink _profileLayerLink = LayerLink();
  OverlayEntry? _profileOverlayEntry;
  bool _isProfileDropdownOpen = false;

  @override
  void initState() {
    super.initState();
    requestNotificationPermission();
    
    // Refresh profile if data is incomplete
    if (AuthService().currentUserName == null || AuthService().currentUserName!.isEmpty) {
      AuthService().refreshProfile().then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _profileOverlayEntry?.remove();
    _profileOverlayEntry = null;
    super.dispose();
  }

  void _markAllAsRead() {
    context.read<NotificationsCubit>().markAllAsRead();
    if (_isDropdownOpen) {
      _closeDropdown();
      _openDropdown(); // Rebuild dropdown overlay with updated state
    }
  }

  void _toggleDropdown() {
    if (_isDropdownOpen) {
      _closeDropdown();
    } else {
      _openDropdown();
    }
  }

  void _closeDropdown() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted) {
      setState(() {
        _isDropdownOpen = false;
      });
    }
  }

  void _openDropdown() {
    final overlay = Overlay.of(context);
    final notifCubit = context.read<NotificationsCubit>();

    _overlayEntry = OverlayEntry(
      builder: (overlayCtx) {
        return BlocBuilder<NotificationsCubit, NotificationsState>(
          bloc: notifCubit,
          builder: (ctx, notifState) {
            final unreadCount = notifState.unreadCount;
            final notifications = notifState.notifications;

            return Stack(
              children: [
                GestureDetector(
                  onTap: _closeDropdown,
                  behavior: HitTestBehavior.translucent,
                  child: Container(
                    width: double.infinity,
                    height: double.infinity,
                    color: Colors.transparent,
                  ),
                ),
                Positioned(
                  width: 360,
                  child: CompositedTransformFollower(
                    link: _layerLink,
                    showWhenUnlinked: false,
                    offset: const Offset(-310, 48),
                    child: Material(
                      elevation: 16,
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.white,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Dropdown Header
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFF8FAFC),
                                  border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          'Notifications',
                                          style: GoogleFonts.outfit(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF1E293B),
                                          ),
                                        ),
                                        if (unreadCount > 0) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppTheme.error.withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Text(
                                              '$unreadCount new',
                                              style: GoogleFonts.outfit(
                                                fontSize: 9,
                                                fontWeight: FontWeight.w800,
                                                color: AppTheme.error,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    if (unreadCount > 0)
                                      TextButton(
                                        onPressed: _markAllAsRead,
                                        style: TextButton.styleFrom(
                                          padding: EdgeInsets.zero,
                                          minimumSize: Size.zero,
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        child: Text(
                                          'Mark all as read',
                                          style: GoogleFonts.outfit(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.primaryColor,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              // Dropdown Content
                              Flexible(
                                child: notifications.isEmpty
                                    ? Container(
                                        padding: const EdgeInsets.symmetric(vertical: 32),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.notifications_off_outlined,
                                              size: 36,
                                              color: Color(0xFF94A3B8),
                                            ),
                                            const SizedBox(height: 10),
                                            Text(
                                              'No new notifications',
                                              style: GoogleFonts.outfit(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                                color: const Color(0xFF64748B),
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : ConstrainedBox(
                                        constraints: const BoxConstraints(maxHeight: 280),
                                        child: ListView.separated(
                                          shrinkWrap: true,
                                          padding: EdgeInsets.zero,
                                          itemCount: notifications.length,
                                          separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                          itemBuilder: (context, index) {
                                            final item = notifications[index];
                                            final isUnread = item['isRead'] == false || item['isRead'] == null;
                                            final title = item['title'] ?? 'Notification';
                                            final body = item['body'] ?? '';
                                            final route = item['actionRoute'];
                                            final timeStr = item['createdAt'] != null
                                                ? _formatTimeAgo(item['createdAt'])
                                                : '';

                                            IconData iconData = Icons.notifications_outlined;
                                            Color iconColor = const Color(0xFF475569);
                                            Color iconBg = const Color(0xFFF1F5F9);

                                            if (title.contains('Assigned') || title.contains('Agent')) {
                                              iconData = Icons.person_add_outlined;
                                              iconColor = Colors.indigo;
                                              iconBg = Colors.indigo.withValues(alpha: 0.12);
                                            } else if (title.contains('Blocked')) {
                                              iconData = Icons.block_outlined;
                                              iconColor = Colors.red;
                                              iconBg = Colors.red.withValues(alpha: 0.12);
                                            } else if (title.contains('KYC')) {
                                              iconData = Icons.verified_user_outlined;
                                              iconColor = Colors.green;
                                              iconBg = Colors.green.withValues(alpha: 0.12);
                                            }

                                            return InkWell(
                                              onTap: () {
                                                _closeDropdown();
                                                if (isUnread && item['_id'] != null) {
                                                  notifCubit.markAsRead(item['_id']);
                                                }
                                                if (route != null && route.isNotEmpty) {
                                                  String navRoute = route;
                                                  if (route == '/leads/profile') navRoute = '/leads';
                                                  if (route == '/dealers/profile') navRoute = '/dealers';
                                                  Navigator.pushNamed(context, navRoute);
                                                }
                                              },
                                              child: Container(
                                                padding: const EdgeInsets.all(12),
                                                color: isUnread ? const Color(0xFFF8FAFC) : Colors.transparent,
                                                child: Row(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Container(
                                                      padding: const EdgeInsets.all(6),
                                                      decoration: BoxDecoration(
                                                        color: iconBg,
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: Icon(iconData, color: iconColor, size: 14),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text(
                                                            title,
                                                            style: GoogleFonts.outfit(
                                                              fontSize: 12,
                                                              fontWeight: isUnread ? FontWeight.w700 : FontWeight.w600,
                                                              color: const Color(0xFF1E293B),
                                                            ),
                                                          ),
                                                          const SizedBox(height: 2),
                                                          Text(
                                                            body,
                                                            style: GoogleFonts.outfit(
                                                              fontSize: 11,
                                                              color: const Color(0xFF64748B),
                                                            ),
                                                            maxLines: 2,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                          if (timeStr.isNotEmpty) ...[
                                                            const SizedBox(height: 4),
                                                            Text(
                                                              timeStr,
                                                              style: GoogleFonts.outfit(
                                                                fontSize: 10,
                                                                color: const Color(0xFF94A3B8),
                                                              ),
                                                            ),
                                                          ],
                                                        ],
                                                      ),
                                                    ),
                                                    if (isUnread) ...[
                                                      const SizedBox(width: 8),
                                                      Container(
                                                        width: 6,
                                                        height: 6,
                                                        decoration: BoxDecoration(
                                                          color: AppTheme.primaryColor,
                                                          shape: BoxShape.circle,
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    overlay.insert(_overlayEntry!);
    setState(() {
      _isDropdownOpen = true;
    });
  }

  void _toggleProfileDropdown() {
    if (_isProfileDropdownOpen) {
      _closeProfileDropdown();
    } else {
      _openProfileDropdown();
    }
  }

  void _closeProfileDropdown() {
    _profileOverlayEntry?.remove();
    _profileOverlayEntry = null;
    if (mounted) {
      setState(() {
        _isProfileDropdownOpen = false;
      });
    }
  }

  void _openProfileDropdown() {
    final overlay = Overlay.of(context);
    final isSales = AuthService().isSales;
    final email = AuthService().currentUserEmail ?? (isSales ? 'sales@krishikranti.com' : 'admin@krishikranti.com');
    final rawName = AuthService().currentUserName ?? '';
    final name = rawName.isNotEmpty ? rawName : (isSales ? 'Sales Agent' : 'Administrator');
    final initials = name.isNotEmpty ? name[0].toUpperCase() : (isSales ? 'S' : 'A');

    _profileOverlayEntry = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            GestureDetector(
              onTap: _closeProfileDropdown,
              behavior: HitTestBehavior.translucent,
              child: Container(
                width: double.infinity,
                height: double.infinity,
                color: Colors.transparent,
              ),
            ),
            Positioned(
              width: 240,
              child: CompositedTransformFollower(
                link: _profileLayerLink,
                showWhenUnlinked: false,
                offset: const Offset(-200, 48),
                child: Material(
                  elevation: 16,
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            color: const Color(0xFFF8FAFC),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: isSales 
                                              ? [const Color(0xFF34D399), const Color(0xFF059669)]
                                              : [Colors.indigo.shade300, Colors.indigo.shade600],
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          initials,
                                          style: GoogleFonts.outfit(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        name,
                                        style: GoogleFonts.outfit(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF1E293B),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  email,
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w400,
                                    color: const Color(0xFF64748B),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isSales
                                        ? const Color(0xFFECFDF5)
                                        : const Color(0xFFEEF2FF),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: isSales
                                          ? const Color(0xFFA7F3D0)
                                          : const Color(0xFFC7D2FE),
                                    ),
                                  ),
                                  child: Text(
                                    isSales ? 'SALES ROLE' : 'ADMIN ROLE',
                                    style: GoogleFonts.outfit(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: isSales
                                          ? const Color(0xFF047857)
                                          : const Color(0xFF4338CA),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1, color: Color(0xFFE2E8F0)),
                          InkWell(
                            onTap: () {
                              _closeProfileDropdown();
                              _handleLogout();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.logout_rounded,
                                    color: Colors.redAccent,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Logout',
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.redAccent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    overlay.insert(_profileOverlayEntry!);
    setState(() {
      _isProfileDropdownOpen = true;
    });
  }

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Confirm Logout',
          style: GoogleFonts.outfit(
            color: const Color(0xFF1E293B),
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Are you sure you want to log out?',
          style: GoogleFonts.outfit(
            color: const Color(0xFF64748B),
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.outfit(
                color: const Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              NavigationService.navigateToLogin(showSessionExpiredMessage: false);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Logout',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimeAgo(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays == 1) return 'Yesterday';
      return '${diff.inDays}d ago';
    } catch (_) {
      return '';
    }
  }

  Map<String, String> _getRouteInfo(String? routeName, bool isSales) {
    if (routeName == null) {
      return {'title': isSales ? 'Sales Dashboard' : 'Admin Dashboard', 'subtitle': 'Overview & Real-time Metrics'};
    }
    if (routeName.startsWith('/products')) return {'title': 'Products Catalog', 'subtitle': 'Inventory & Pricing'};
    if (routeName.startsWith('/orders')) return {'title': 'Orders Management', 'subtitle': 'Live & Completed Shipments'};
    if (routeName.startsWith('/leads/profile')) return {'title': 'Lead Profile', 'subtitle': 'Prospect Details & Activity'};
    if (routeName.startsWith('/leads')) return {'title': 'Leads CRM', 'subtitle': 'Prospects & Follow-ups'};
    if (routeName.startsWith('/dealers/profile')) return {'title': 'Dealer Profile', 'subtitle': 'Partner Details & Performance'};
    if (routeName.startsWith('/dealers')) return {'title': 'Dealers Management', 'subtitle': 'Verified Partners Network'};
    if (routeName.startsWith('/sales/coupons')) return {'title': 'Coupons & Offers', 'subtitle': 'Promotions Management'};
    if (routeName.startsWith('/team')) return {'title': 'Team Management', 'subtitle': 'Staff & Roles'};
    if (routeName.startsWith('/marketing') || routeName.startsWith('/events') || routeName.startsWith('/customer')) {
      return {'title': 'Live Customer Pulse', 'subtitle': 'Real-Time User Events'};
    }
    if (routeName.startsWith('/logs') || routeName.startsWith('/admin/logs')) return {'title': 'Audit Logs', 'subtitle': 'System Activity & Security'};
    if (routeName.startsWith('/trash')) return {'title': 'Trash & Archive', 'subtitle': 'Deleted Records'};
    if (routeName.startsWith('/alerts')) return {'title': 'Alerts & Notices', 'subtitle': 'Broadcast Messages'};
    if (routeName.startsWith('/sales/estimates')) return {'title': 'Estimate Generator', 'subtitle': 'Quotes & Invoices'};
    if (routeName.startsWith('/support')) return {'title': 'WhatsApp Support', 'subtitle': 'Customer Conversations'};
    if (routeName.startsWith('/calls')) return {'title': 'Call Logs', 'subtitle': 'OBD & Telephony Records'};
    return {'title': isSales ? 'Sales Dashboard' : 'Admin Dashboard', 'subtitle': 'Overview & Real-time Metrics'};
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = context.watch<NotificationsCubit>().state.unreadCount;
    final bool isDesktop = Responsive.isDesktop(context);
    final bool isMobile = Responsive.isMobile(context);

    final isSales = AuthService().isSales;
    final rawName = AuthService().currentUserName ?? '';
    final name = rawName.isNotEmpty ? rawName : (isSales ? 'Sales Agent' : 'Administrator');
    final initials = name.isNotEmpty ? name[0].toUpperCase() : (isSales ? 'S' : 'A');

    final double height = isMobile ? 50 : 54;
    final String? currentRoute = ModalRoute.of(context)?.settings.name;
    final bool isProfileRoute =
        currentRoute == '/leads/profile' || currentRoute == '/dealers/profile';
    final routeInfo = _getRouteInfo(currentRoute, isSales);

    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: height,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isProfileRoute
                  ? [
                      const Color(0xFFF1F8E9).withValues(alpha: 0.9),
                      const Color(0xFFE8F5E9).withValues(alpha: 0.95),
                    ]
                  : [
                      Colors.white.withValues(alpha: 0.92),
                      AppTheme.cardColor.withValues(alpha: 0.95),
                    ],
            ),
            border: Border(
              bottom: BorderSide(
                color: isProfileRoute
                    ? const Color(0xFFC8E6C9)
                    : const Color(0xFFE2E8F0),
                width: 1,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20),
          child: Row(
            children: [
              if (!isDesktop) ...[
                _TopbarIconButton(
                  tooltip: 'Menu',
                  size: 34,
                  onTap: widget.onMenuPressed,
                  icon: const Icon(
                    Icons.menu_rounded,
                    color: Color(0xFF334155),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
              ],

              // Current Page Title on the left
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        routeInfo['title'] ?? 'Dashboard',
                        style: GoogleFonts.outfit(
                          fontSize: isMobile ? 14 : 16,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                          letterSpacing: -0.2,
                        ),
                      ),
                      if (!isMobile && routeInfo['subtitle'] != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          '•  ${routeInfo['subtitle']}',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),

              const Spacer(),

              // Live Sync Pill
              if (!isMobile) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFA7F3D0), width: 0.8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Live Sync',
                        style: GoogleFonts.outfit(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF047857),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
              ],

              // Notifications + Profile Actions on Right
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CompositedTransformTarget(
                    link: _layerLink,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        _TopbarIconButton(
                          tooltip: 'Notifications',
                          size: 34,
                          onTap: _toggleDropdown,
                          icon: const Icon(
                            Icons.notifications_none_rounded,
                            color: Color(0xFF334155),
                            size: 18,
                          ),
                        ),
                        if (unreadCount > 0)
                          Positioned(
                            top: -2,
                            right: -2,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                color: AppTheme.error,
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 15,
                                minHeight: 15,
                              ),
                              child: Center(
                                child: Text(
                                  unreadCount > 9 ? '9+' : '$unreadCount',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  CompositedTransformTarget(
                    link: _profileLayerLink,
                    child: GestureDetector(
                      onTap: _toggleProfileDropdown,
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSales ? const Color(0xFFA7F3D0) : const Color(0xFFE2E8F0),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: isSales
                                ? Container(
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [Color(0xFF34D399), Color(0xFF059669)],
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        initials,
                                        style: GoogleFonts.outfit(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  )
                                : Container(
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [Color(0xFFFA9527), Color(0xFFFA6400)],
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        initials,
                                        style: GoogleFonts.outfit(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopbarIconButton extends StatefulWidget {
  final Widget icon;
  final VoidCallback? onTap;
  final String tooltip;
  final double size;

  const _TopbarIconButton({
    required this.icon,
    required this.tooltip,
    required this.size,
    this.onTap,
  });

  @override
  State<_TopbarIconButton> createState() => _TopbarIconButtonState();
}

class _TopbarIconButtonState extends State<_TopbarIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Tooltip(
        message: widget.tooltip,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: _hovered
                  ? Colors.white.withOpacity(0.85)
                  : Colors.white.withOpacity(0.6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _hovered
                    ? const Color(0xFFCBD5E1)
                    : const Color(0xFFE5E7EB),
              ),
            ),
            child: Center(child: widget.icon),
          ),
        ),
      ),
    );
  }
}
