import 'package:flutter/material.dart';
import 'package:kd_pannel/core/auth/auth_service.dart';
import 'package:kd_pannel/core/responsive/responsive.dart';
import 'package:kd_pannel/features/admin/presentation/pages/dashboard_page.dart';
import 'package:kd_pannel/features/admin/presentation/pages/dealer_management_page.dart';
import 'package:kd_pannel/features/admin/presentation/pages/leads_page.dart';
import 'package:kd_pannel/features/admin/presentation/pages/orders_page.dart';
import 'package:kd_pannel/features/admin/presentation/pages/products_page.dart';
import 'package:kd_pannel/features/admin/presentation/pages/support_dashboard_page.dart';
import 'package:kd_pannel/features/sales/presentation/pages/sales_dashboard_page.dart';
import 'sidebar_widget.dart';
import 'package:kd_pannel/features/shared/widgets/topbar_widget.dart';

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
    // const DashboardPage(),
    // const DealerManagementPage(),
    const ProductsPage(),
    const OrdersPage(),
  ];

  // Persistent static stack of Sales Pages (Preserves states!)
  final List<Widget> _salesPages = [
    const SalesDashboardPage(),
    const LeadsPage(),
    const DealerManagementPage(),
    const OrdersPage(),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
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
        } else {
          _currentIdx = 0;
        }
      } else {
        if (routeName == '/sales/dashboard') _currentIdx = 0;
        if (routeName == '/leads' || routeName.startsWith('/leads/')) _currentIdx = 1;
        if (routeName == '/dealers' || routeName.startsWith('/dealers/')) _currentIdx = 2;
        if (routeName.startsWith('/orders')) _currentIdx = 3;
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
      if (index == 1) route = '/orders';
    } else {
      if (index == 0) route = '/sales/dashboard';
      if (index == 1) route = '/leads';
      if (index == 2) route = '/dealers';
      if (index == 3) route = '/orders';
    }

    final currentRoute = ModalRoute.of(context)?.settings.name;
    if (currentRoute != route || widget.child != null) {
      Navigator.pushReplacementNamed(context, route);
    }
  }

  void _handleLogout() {
    AuthService().logout();
    Navigator.pushReplacementNamed(context, '/login');
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
