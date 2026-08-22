import "package:kd_pannel/features/admin/presentation/pages/push_campaigns_page.dart";
import 'package:flutter/material.dart';
import 'package:kd_pannel/core/auth/auth_service.dart';
import 'package:kd_pannel/core/responsive/responsive.dart';
import 'package:kd_pannel/features/admin/presentation/pages/dealer_management_page.dart';
import 'package:kd_pannel/features/admin/presentation/pages/dashboard_page.dart';
import 'package:kd_pannel/features/admin/presentation/pages/leads_page.dart';
import 'package:kd_pannel/features/admin/presentation/pages/orders_page.dart';
import 'package:kd_pannel/features/admin/presentation/pages/products_page.dart';
import 'package:kd_pannel/features/admin/presentation/pages/sales_coupon_page.dart';
import 'package:kd_pannel/features/admin/presentation/pages/team_management_page.dart';
import 'package:kd_pannel/features/admin/presentation/pages/audit_logs_container_page.dart';
import 'package:kd_pannel/features/admin/presentation/pages/trash_page.dart';
import 'package:kd_pannel/features/admin/presentation/pages/alerts_page.dart';
import 'package:kd_pannel/features/sales/presentation/pages/sales_dashboard_page.dart';
import 'package:kd_pannel/features/admin/presentation/pages/estimate_generator_page.dart';
import 'package:kd_pannel/features/admin/presentation/pages/whatsapp_crm_page.dart';
import 'package:kd_pannel/features/admin/presentation/pages/call_logs_page.dart';
import 'package:kd_pannel/features/admin/presentation/pages/user_events_page.dart';
import 'package:kd_pannel/features/sales/presentation/pages/sales_customer_events_page.dart';
import 'sidebar_widget.dart';
import 'package:kd_pannel/core/network/websocket_service.dart';
import 'package:kd_pannel/core/services/analytics_service.dart';
import 'package:kd_pannel/core/utils/navigation_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kd_pannel/app_theme.dart';

class MainLayout extends StatefulWidget {
  final Widget? child;

  const MainLayout({super.key, this.child});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _currentIdx = 0;
  String? _lastProcessedRoute;
  static bool _isSidebarPinned = true;

  // Persistent static stack of Admin Pages (Preserves states!)
  final List<Widget> _adminPages = [
    const DashboardPage(),
    const ProductsPage(),
    const OrdersPage(),
    const LeadsPage(),
    const DealerManagementPage(),
    const SalesCouponPage(),
    const TeamManagementPage(),
    const UserEventsPage(),
    const AuditLogsContainerPage(),
    const PushCampaignsPage(),
    const TrashPage(),
    const AlertsPage(),
    const EstimateGeneratorPage(),
    const WhatsAppCrmPage(),
    const CallLogsPage(),
  ];

  // Persistent static stack of Sales Pages (Preserves states!)
  final List<Widget> _salesPages = [
    const SalesDashboardPage(),
    const ProductsPage(),
    const OrdersPage(),
    const LeadsPage(),
    const DealerManagementPage(),
    const SalesCouponPage(),
    const SalesCustomerEventsPage(),
    const AlertsPage(),
    const EstimateGeneratorPage(),
    const WhatsAppCrmPage(),
    const CallLogsPage(),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    if (AuthService().isInitialized) {
      // Connect to WebSockets
      WebSocketService().connect();

      // Pre-cache core layout assets to prevent empty/flickering render on direct load or restart
      precacheImage(const AssetImage('assets/images/logo.png'), context);
      precacheImage(const AssetImage('assets/images/admin.png'), context);
      
      _updateRouteIndex();
    }
  }

  void _updateRouteIndex() {
    if (!AuthService().isInitialized) return;

    final String? routeName = ModalRoute.of(context)?.settings.name;
    final role = AuthService().currentUserRole ?? UserRole.admin;

    if (routeName != null && routeName != _lastProcessedRoute) {
      _lastProcessedRoute = routeName;
      AnalyticsService().updateContext(screen: routeName);
      if (role == UserRole.admin) {
        if (routeName == '/dashboard') {
          _currentIdx = 0;
        } else if (routeName.startsWith('/products')) {
          _currentIdx = 1;
        } else if (routeName.startsWith('/orders')) {
          _currentIdx = 2;
        } else if (routeName == '/leads' || routeName.startsWith('/leads/')) {
          _currentIdx = 3;
        } else if (routeName == '/dealers' || routeName.startsWith('/dealers/')) {
          _currentIdx = 4;
        } else if (routeName == '/sales/coupons') {
          _currentIdx = 5;
        } else if (routeName == '/team' || routeName.startsWith('/team/')) {
          _currentIdx = 6;
        } else if (routeName == '/marketing') {
          _currentIdx = 7;
        } else if (routeName == '/logs' || routeName == '/admin/logs') {
          _currentIdx = 8;
        } else if (routeName == '/push-campaigns' || routeName == '/campaigns') {
          _currentIdx = 9;
        } else if (routeName == '/trash') {
          _currentIdx = 10;
        } else if (routeName == '/alerts') {
          _currentIdx = 11;
        } else if (routeName == '/sales/estimates') {
          _currentIdx = 12;
        } else if (routeName == '/support') {
          _currentIdx = 13;
        } else if (routeName == '/calls') {
          _currentIdx = 14;
        } else {
          _currentIdx = 0;
        }
      } else {
        if (routeName == '/dashboard' || routeName == '/sales/dashboard') {
          _currentIdx = 0;
        } else if (routeName.startsWith('/products')) {
          _currentIdx = 1;
        } else if (routeName.startsWith('/orders')) {
          _currentIdx = 2;
        } else if (routeName == '/leads' || routeName.startsWith('/leads/')) {
          _currentIdx = 3;
        } else if (routeName == '/dealers' || routeName.startsWith('/dealers/')) {
          _currentIdx = 4;
        } else if (routeName == '/sales/coupons') {
          _currentIdx = 5;
        } else if (routeName == '/marketing' || routeName == '/customer' || routeName == '/events') {
          _currentIdx = 6;
        } else if (routeName == '/alerts') {
          _currentIdx = 7;
        } else if (routeName == '/sales/estimates') {
          _currentIdx = 8;
        } else if (routeName == '/support') {
          _currentIdx = 9;
        } else if (routeName == '/calls') {
          _currentIdx = 10;
        } else {
          _currentIdx = 0;
        }
      }
    }
  }

  void _handleTabSelected(int index) {
    // 1. Close drawer if open (Mobile/Tablet)
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      _scaffoldKey.currentState?.closeDrawer();
    }

    final role = AuthService().currentUserRole ?? UserRole.admin;
    String route = '/dashboard';
    if (role == UserRole.admin) {
      if (index == 0) route = '/dashboard';
      if (index == 1) route = '/products';
      if (index == 2) route = '/orders';
      if (index == 3) route = '/leads';
      if (index == 4) route = '/dealers';
      if (index == 5) route = '/sales/coupons';
      if (index == 6) route = '/team';
      if (index == 7) route = '/marketing';
      if (index == 8) route = '/logs';
      if (index == 9) route = '/push-campaigns';
      if (index == 10) route = '/trash';
      if (index == 11) route = '/alerts';
      if (index == 12) route = '/sales/estimates';
      if (index == 13) route = '/support';
      if (index == 14) route = '/calls';
    } else {
      if (index == 0) route = '/dashboard';
      if (index == 1) route = '/products';
      if (index == 2) route = '/orders';
      if (index == 3) route = '/leads';
      if (index == 4) route = '/dealers';
      if (index == 5) route = '/sales/coupons';
      if (index == 6) route = '/marketing';
      if (index == 7) route = '/alerts';
      if (index == 8) route = '/sales/estimates';
      if (index == 9) route = '/support';
      if (index == 10) route = '/calls';
    }

    final currentRoute = ModalRoute.of(context)?.settings.name;
    if (currentRoute != route || widget.child != null) {
      Navigator.pushReplacementNamed(context, route);
    }
  }

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Confirm Logout',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          content: Text(
            'Are you sure you want to log out?',
            style: GoogleFonts.outfit(
              color: AppTheme.textSecondary,
              fontSize: 14,
            ),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: GoogleFonts.outfit(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Close the dialog
                NavigationService.navigateToLogin(showSessionExpiredMessage: false);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.error,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
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
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!AuthService().isInitialized) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.primaryColor),
        ),
      );
    }

    if (AuthService().currentUserId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, '/login');
      });
      return const Scaffold();
    }

    // Connect WebSockets and ensure route index is calculated
    WebSocketService().connect();
    _updateRouteIndex();

    final bool isDesktop = Responsive.isDesktop(context);
    final role = AuthService().currentUserRole ?? UserRole.admin;
    final pages = role == UserRole.admin ? _adminPages : _salesPages;
    final int safeIdx = (_currentIdx >= 0 && _currentIdx < pages.length)
        ? _currentIdx
        : 0;

    final Widget screenContent = widget.child ?? pages[safeIdx];

    final Widget content = isDesktop
        ? screenContent
        : Column(
            children: [
              // Mobile-only compact app bar to access drawer
              Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.menu_rounded,
                        size: 22,
                        color: Color(0xFF334155),
                      ),
                      onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                    ),
                    const SizedBox(width: 4),
                    Image.asset(
                      'assets/images/logo_copy.png',
                      width: 24,
                      height: 24,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'KRISHI DEALER',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: const Color(0xFF1E293B),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(child: screenContent),
            ],
          );

    return Scaffold(
      key: _scaffoldKey,
      drawer: !isDesktop
          ? Drawer(
              width: 260,
              child: SidebarWidget(
                currentIdx: safeIdx,
                onTabSelected: _handleTabSelected,
                onLogout: _handleLogout,
                forceExpanded: true,
                isPinned: true,
              ),
            )
          : null,
      body: isDesktop
          ? Row(
              children: [
                SidebarWidget(
                  currentIdx: safeIdx,
                  onTabSelected: _handleTabSelected,
                  onLogout: _handleLogout,
                  isPinned: _isSidebarPinned,
                  onPinToggle: () {
                    setState(() {
                      _isSidebarPinned = !_isSidebarPinned;
                    });
                  },
                ),
                Expanded(child: content),
              ],
            )
          : content,
    );
  }
}
