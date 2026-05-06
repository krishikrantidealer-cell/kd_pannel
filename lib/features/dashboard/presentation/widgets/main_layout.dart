import 'package:flutter/material.dart';
import 'sidebar_widget.dart';
import 'topbar_widget.dart';

class MainLayout extends StatelessWidget {
  final Widget child;

  const MainLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Sidebar (fixed width)
          const SidebarWidget(),
          
          // Right Side (Topbar + Content)
          Expanded(
            child: Column(
              children: [
                // Topbar (fixed height)
                const TopbarWidget(),
                
                // Screen Content - Removed SingleChildScrollView to allow pages to manage their own constraints
                Expanded(
                  child: child,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
