import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:ui' as ui;
import 'dart:convert';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import 'package:kd_pannel/app_theme.dart';
import 'package:kd_pannel/core/responsive/responsive.dart';
import 'package:kd_pannel/core/network/websocket_service.dart';
import 'package:kd_pannel/core/network/api_client.dart';
import 'package:kd_pannel/util/web_notification_helper.dart';
import 'package:kd_pannel/core/auth/auth_service.dart';
import 'package:kd_pannel/core/utils/navigation_service.dart';

class TopbarWidget extends StatefulWidget {
  final VoidCallback? onMenuPressed;
  const TopbarWidget({super.key, this.onMenuPressed});

  @override
  State<TopbarWidget> createState() => _TopbarWidgetState();
}

class _TopbarWidgetState extends State<TopbarWidget> {
  List<Map<String, dynamic>> _notifications = [];
  int _unreadCount = 0;
  StreamSubscription? _notificationSub;
  
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
    _fetchNotifications(isInitial: true);
    _notificationSub = WebSocketService().notificationUpdates.listen((_) {
      _fetchNotifications(isInitial: false);
    });
  }

  @override
  void dispose() {
    _notificationSub?.cancel();
    _overlayEntry?.remove();
    _overlayEntry = null;
    _profileOverlayEntry?.remove();
    _profileOverlayEntry = null;
    super.dispose();
  }

  Future<void> _fetchNotifications({bool isInitial = false}) async {
    try {
      final res = await ApiClient().get('/users/notifications');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) {
          final list = List<Map<String, dynamic>>.from(data['notifications'] ?? []);
          
          if (!isInitial && list.isNotEmpty) {
            final newUnreadNotifications = list.where((newNotif) {
              final isUnread = newNotif['isRead'] == false || newNotif['isRead'] == null;
              if (!isUnread) return false;
              final existsBefore = _notifications.any((oldNotif) => oldNotif['_id'] == newNotif['_id']);
              return !existsBefore;
            }).toList();

            for (final notif in newUnreadNotifications) {
              final title = notif['title'] ?? 'New Notification';
              final body = notif['body'] ?? '';
              showWebNotification(title, body);
            }
          }

          if (mounted) {
            setState(() {
              _notifications = list;
              _unreadCount = list.where((n) => n['isRead'] == false || n['isRead'] == null).length;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('[TopbarWidget] Error fetching notifications: $e');
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      final res = await ApiClient().put('/users/notifications/read', {});
      if (res.statusCode == 200) {
        await _fetchNotifications(isInitial: true);
        if (_isDropdownOpen) {
          _closeDropdown();
          _openDropdown(); // Rebuild dropdown overlay with updated state
        }
      }
    } catch (e) {
      debugPrint('[TopbarWidget] Error marking read: $e');
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

    _overlayEntry = OverlayEntry(
      builder: (context) {
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
                                    if (_unreadCount > 0) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppTheme.error.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          '$_unreadCount new',
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
                                if (_unreadCount > 0)
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
                            child: _notifications.isEmpty
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
                                      itemCount: _notifications.length,
                                      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                      itemBuilder: (context, index) {
                                        final item = _notifications[index];
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
                                          iconBg = Colors.indigo.withOpacity(0.12);
                                        } else if (title.contains('Blocked')) {
                                          iconData = Icons.block_outlined;
                                          iconColor = Colors.red;
                                          iconBg = Colors.red.withOpacity(0.12);
                                        } else if (title.contains('KYC')) {
                                          iconData = Icons.verified_user_outlined;
                                          iconColor = Colors.green;
                                          iconBg = Colors.green.withOpacity(0.12);
                                        }

                                        return InkWell(
                                          onTap: () {
                                            _closeDropdown();
                                            if (route != null && route.isNotEmpty) {
                                              // Profile routes (/leads/profile, /dealers/profile) require
                                              // route arguments (lead/dealer data) which are not stored in
                                              // the notification. Redirect to the list page instead.
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
                                                          fontWeight: FontWeight.w400,
                                                          color: const Color(0xFF64748B),
                                                        ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        timeStr,
                                                        style: GoogleFonts.outfit(
                                                          fontSize: 9,
                                                          fontWeight: FontWeight.w500,
                                                          color: const Color(0xFF94A3B8),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                if (isUnread)
                                                  Container(
                                                    margin: const EdgeInsets.only(top: 4, left: 4),
                                                    width: 6,
                                                    height: 6,
                                                    decoration: const BoxDecoration(
                                                      color: AppTheme.primaryColor,
                                                      shape: BoxShape.circle,
                                                    ),
                                                  ),
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
    final initials = email.isNotEmpty ? email[0].toUpperCase() : (isSales ? 'S' : 'A');

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
                                        isSales ? 'Sales Agent' : 'Administrator',
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
              WebSocketService().disconnect();
              AuthService().logout();
              NavigationService.navigateToLogin();
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

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = Responsive.isDesktop(context);
    final bool isMobile = Responsive.isMobile(context);

    final isSales = AuthService().isSales;
    final email = AuthService().currentUserEmail ?? '';
    final initials = email.isNotEmpty ? email[0].toUpperCase() : (isSales ? 'S' : 'A');

    final double height = isMobile ? 60 : 72;
    final String? currentRoute = ModalRoute.of(context)?.settings.name;
    final bool isProfileRoute =
        currentRoute == '/leads/profile' || currentRoute == '/dealers/profile';

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
                      Colors.white.withValues(alpha: 0.88),
                      AppTheme.cardColor.withValues(alpha: 0.9),
                    ],
            ),
            border: Border(
              bottom: BorderSide(
                color: isProfileRoute
                    ? const Color(0xFFC8E6C9)
                    : const Color(0xFFE5E7EB),
                width: 1,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 24),
          child: Row(
            children: [
              if (!isDesktop) ...[
                _TopbarIconButton(
                  tooltip: 'Menu',
                  size: isMobile ? 36 : 40,
                  onTap: widget.onMenuPressed,
                  icon: const Icon(
                    Icons.menu_rounded,
                    color: Color(0xFF334155),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
              ],

              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 620),
                  child: SizedBox(
                    height: isMobile ? 36 : 42,
                    child: CupertinoSearchTextField(
                      placeholder: isMobile
                          ? 'Search'
                          : 'Search orders, users, products...',
                      placeholderStyle: TextStyle(
                        color: const Color(0xFF94A3B8),
                        fontSize: isMobile ? 12 : 13,
                      ),
                      prefixInsets: EdgeInsets.symmetric(
                        horizontal: isMobile ? 10 : 14,
                      ),
                      itemColor: const Color(0xFF94A3B8),
                      style: TextStyle(
                        fontSize: isMobile ? 13 : 14,
                        color: const Color(0xFF0F172A),
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.75),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: const Color(0xFFE5E7EB),
                          width: 1,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 10),

              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CompositedTransformTarget(
                    link: _layerLink,
                    child: _TopbarIconButton(
                      tooltip: 'Notifications',
                      size: isMobile ? 36 : 40,
                      onTap: _toggleDropdown,
                      icon: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(
                            Icons.notifications_none_rounded,
                            color: const Color(0xFF334155),
                            size: isMobile ? 20 : 22,
                          ),
                          if (_unreadCount > 0)
                            Positioned(
                              top: -1,
                              right: -1,
                              child: Container(
                                width: 9,
                                height: 9,
                                decoration: BoxDecoration(
                                  color: AppTheme.error,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.9),
                                    width: 1.4,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  CompositedTransformTarget(
                    link: _profileLayerLink,
                    child: GestureDetector(
                      onTap: _toggleProfileDropdown,
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: Container(
                          width: isMobile ? 36 : 40,
                          height: isMobile ? 36 : 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSales ? const Color(0xFFA7F3D0) : const Color(0xFFE5E7EB),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 6),
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
                                          fontSize: isMobile ? 14 : 16,
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
                                          fontSize: isMobile ? 14 : 16,
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
