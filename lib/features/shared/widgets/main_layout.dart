import 'package:flutter/material.dart';
import 'package:kd_pannel/core/responsive/responsive.dart';
import 'sidebar_widget.dart';
import 'topbar_widget.dart';

class MainLayout extends StatefulWidget {
  final Widget child;

  const MainLayout({super.key, required this.child});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = Responsive.isDesktop(context);

    return Scaffold(
      key: _scaffoldKey,
      drawer: !isDesktop
          ? const Drawer(
              width: 260,
              child: SidebarWidget(),
            )
          : null,
      body: Row(
        children: [
          // Sidebar (fixed width) - Only show on desktop
          if (isDesktop) const SidebarWidget(),

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
                  child: widget.child,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
