import 'package:flutter/material.dart';
import 'package:kd_pannel/core/auth/auth_service.dart';
import 'package:kd_pannel/core/responsive/responsive.dart';
import 'package:kd_pannel/features/admin/presentation/pages/dealer_management_page.dart';
import 'package:kd_pannel/features/admin/presentation/pages/leads_page.dart';
import 'package:kd_pannel/features/admin/presentation/pages/orders_page.dart';
import 'package:kd_pannel/features/admin/presentation/pages/products_page.dart';
import 'package:kd_pannel/features/admin/presentation/pages/sales_coupon_page.dart';
import 'package:kd_pannel/features/admin/presentation/pages/team_management_page.dart';
import 'package:kd_pannel/features/admin/presentation/pages/user_events_page.dart';
import 'sidebar_widget.dart';
import 'package:kd_pannel/features/shared/widgets/topbar_widget.dart';
import 'package:kd_pannel/core/network/websocket_service.dart';
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
    const ProductsPage(),
    const OrdersPage(),
    const LeadsPage(),
    const DealerManagementPage(),
    const SalesCouponPage(),
    const TeamManagementPage(),
    const UserEventsPage(),
  ];

  // Persistent static stack of Sales Pages (Preserves states!)
  final List<Widget> _salesPages = [
    // const SalesDashboardPage(),
    const LeadsPage(),
    const DealerManagementPage(),
    const SalesCouponPage(),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Connect to WebSockets
    WebSocketService().connect();

    // Pre-cache core layout assets to prevent empty/flickering render on direct load or restart
    precacheImage(const AssetImage('assets/images/logo.png'), context);
    precacheImage(const AssetImage('assets/images/admin.png'), context);

    final String? routeName = ModalRoute.of(context)?.settings.name;
    final role = AuthService().currentUserRole ?? UserRole.admin;

    if (routeName != null && routeName != _lastProcessedRoute) {
      _lastProcessedRoute = routeName;
      if (role == UserRole.admin) {
        if (routeName.startsWith('/orders')) {
          _currentIdx = 1;
        } else if (routeName == '/leads' || routeName.startsWith('/leads/')) {
          _currentIdx = 2;
        } else if (routeName == '/dealers' || routeName.startsWith('/dealers/')) {
          _currentIdx = 3;
        } else if (routeName == '/sales/coupons') {
          _currentIdx = 4;
        } else if (routeName == '/team' || routeName.startsWith('/team/')) {
          _currentIdx = 5;
        } else if (routeName == '/marketing') {
          _currentIdx = 6;
        } else {
          _currentIdx = 0;
        }
      } else {
        if (routeName == '/leads' || routeName.startsWith('/leads/')) _currentIdx = 0;
        if (routeName == '/dealers' || routeName.startsWith('/dealers/')) _currentIdx = 1;
        if (routeName == '/sales/coupons') _currentIdx = 2;
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
      if (index == 0) route = '/products';
      if (index == 1) route = '/orders';
      if (index == 2) route = '/leads';
      if (index == 3) route = '/dealers';
      if (index == 4) route = '/sales/coupons';
      if (index == 5) route = '/team';
      if (index == 6) route = '/marketing';
    } else {
      if (index == 0) route = '/leads';
      if (index == 1) route = '/dealers';
      if (index == 2) route = '/sales/coupons';
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
                WebSocketService().disconnect();
                AuthService().logout();
                Navigator.pushReplacementNamed(context, '/login');
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
    final bool isDesktop = Responsive.isDesktop(context);
    final role = AuthService().currentUserRole ?? UserRole.admin;
    final pages = role == UserRole.admin ? _adminPages : _salesPages;
    final int safeIdx = (_currentIdx >= 0 && _currentIdx < pages.length)
        ? _currentIdx
        : 0;

    final Widget content = Column(
      children: [
        // Topbar (fixed height)
        TopbarWidget(
          onMenuPressed: () {
            _scaffoldKey.currentState?.openDrawer();
          },
        ),

        // Screen Content
        Expanded(
          child: widget.child ?? IndexedStack(index: safeIdx, children: pages),
        ),
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
