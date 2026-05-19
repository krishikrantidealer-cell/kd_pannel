import 'package:flutter/material.dart';
import 'package:kd_pannel/core/auth/auth_service.dart';
import 'package:kd_pannel/core/responsive/responsive.dart';
import 'package:kd_pannel/features/admin/presentation/pages/dashboard_page.dart';
import 'package:kd_pannel/features/admin/presentation/pages/dealer_management_page.dart';
import 'package:kd_pannel/features/admin/presentation/pages/leads_page.dart';
import 'package:kd_pannel/features/admin/presentation/pages/support_dashboard_page.dart';
import 'package:kd_pannel/features/sales/presentation/pages/sales_dashboard_page.dart';
import 'package:kd_pannel/features/admin/presentation/pages/products_page.dart';
import 'sidebar_widget.dart';
import 'topbar_widget.dart';

class MainLayout extends StatefulWidget {
  final Widget? child;

  const MainLayout({super.key, this.child});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _currentIdx = 0;

  // Persistent static stack of Admin Pages (Preserves states!)
  final List<Widget> _adminPages = const [
    DashboardPage(),
    ProductsPage(),
    LeadsPage(),
    DealerManagementPage(),
    SupportDashboardPage(),
  ];

  // Persistent static stack of Sales Pages (Preserves states!)
  final List<Widget> _salesPages = const [
    SalesDashboardPage(),
    ProductsPage(),
    LeadsPage(),
    DealerManagementPage(),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Pre-cache core layout assets to prevent empty/flickering render on direct load or restart
    precacheImage(const AssetImage('assets/images/logo.png'), context);
    precacheImage(const AssetImage('assets/images/admin.png'), context);

    final String? routeName = ModalRoute.of(context)?.settings.name;
    final role = AuthService().currentUserRole ?? UserRole.admin;

    if (routeName != null) {
      if (role == UserRole.admin) {
        if (routeName == '/dashboard') _currentIdx = 0;
        if (routeName == '/products') _currentIdx = 1;
        if (routeName == '/leads') _currentIdx = 2;
        if (routeName == '/dealers') _currentIdx = 3;
        if (routeName == '/support') _currentIdx = 4;
      } else {
        if (routeName == '/sales/dashboard') _currentIdx = 0;
        if (routeName == '/products') _currentIdx = 1;
        if (routeName == '/leads') _currentIdx = 2;
        if (routeName == '/dealers') _currentIdx = 3;
      }
    }
  }

  void _handleTabSelected(int index) {
    setState(() {
      _currentIdx = index;
    });
    // If mobile drawer is open, auto-close it
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.pop(context);
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

    return Scaffold(
      key: _scaffoldKey,
      drawer: !isDesktop
          ? Drawer(
              width: 260,
              child: SidebarWidget(
                currentIdx: _currentIdx,
                onTabSelected: _handleTabSelected,
                onLogout: _handleLogout,
              ),
            )
          : null,
      body: Row(
        children: [
          // Sidebar (fixed width) - Only show on desktop
          if (isDesktop)
            SidebarWidget(
              currentIdx: _currentIdx,
              onTabSelected: _handleTabSelected,
              onLogout: _handleLogout,
            ),

          // Right Side (Topbar + Content)
          Expanded(
            child: Column(
              children: [
                // Topbar (fixed height)
                TopbarWidget(
                  onMenuPressed: () {
                    _scaffoldKey.currentState?.openDrawer();
                  },
                ),

                // Screen Content
                Expanded(
                  child:
                      widget.child ??
                      IndexedStack(
                        index: _currentIdx,
                        children: role == UserRole.admin
                            ? _adminPages
                            : _salesPages,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
