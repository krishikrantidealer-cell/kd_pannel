import 'package:flutter/material.dart';
import 'package:kd_pannel/core/auth/auth_service.dart';
import 'package:kd_pannel/core/responsive/responsive.dart';
import 'package:kd_pannel/core/network/api_client.dart';
// import 'package:kd_pannel/features/admin/presentation/pages/dashboard_page.dart';
// import 'package:kd_pannel/features/admin/presentation/pages/dealer_management_page.dart';
// import 'package:kd_pannel/features/admin/presentation/pages/leads_page.dart';
// import 'package:kd_pannel/features/admin/presentation/pages/support_dashboard_page.dart';
// import 'package:kd_pannel/features/sales/presentation/pages/sales_dashboard_page.dart';
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
  final List<Widget> _adminPages = const [ProductsPage()];

  // Persistent static stack of Sales Pages (Preserves states!)
  final List<Widget> _salesPages = const [ProductsPage()];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Pre-cache core layout assets to prevent empty/flickering render on direct load or restart
    precacheImage(const AssetImage('assets/images/logo.png'), context);
    precacheImage(const AssetImage('assets/images/admin.png'), context);

    _currentIdx = 0;
  }

  void _handleTabSelected(int index) {
    setState(() {
      _currentIdx = 0;
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

                // Global Wakeup Alert banner (Backend Cold-Start handling)
                ValueListenableBuilder<bool>(
                  valueListenable: ApiClient().isBackendWakingUp,
                  builder: (context, isWakingUp, child) {
                    if (!isWakingUp) return const SizedBox.shrink();
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color(0xFFFFF3CD),
                            Color(0xFFFFF8E1),
                          ], // Soft warning amber
                        ),
                        border: Border(
                          bottom: BorderSide(
                            color: Color(0xFFFFEBAA),
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFF856404),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              '⚡ Waking up the server... This may take a few seconds on the first request.',
                              style: TextStyle(
                                color: Color(0xFF856404),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
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
