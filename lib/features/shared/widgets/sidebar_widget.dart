import 'package:flutter/material.dart';
import 'package:kd_pannel/app_theme.dart';
import 'package:kd_pannel/core/auth/auth_service.dart';

class SidebarWidget extends StatelessWidget {
  const SidebarWidget({super.key});

  static const List<Map<String, dynamic>> _adminMenuItems = [
    {
      'icon': Icons.dashboard_rounded,
      'title': 'Dashboard',
      'route': '/dashboard',
    },
    {'icon': Icons.campaign_rounded, 'title': 'Leads', 'route': '/leads'},
    {'icon': Icons.storefront_rounded, 'title': 'Dealers', 'route': '/dealers'},
    {'icon': Icons.support_agent_rounded, 'title': 'Support', 'route': '/support'},
  ];

  static const List<Map<String, dynamic>> _salesMenuItems = [
    {
      'icon': Icons.dashboard_rounded,
      'title': 'Sales Dashboard',
      'route': '/sales/dashboard',
    },
    {'icon': Icons.campaign_rounded, 'title': 'My Leads', 'route': '/leads'},
    {'icon': Icons.storefront_rounded, 'title': 'My Dealers', 'route': '/dealers'},
  ];

  @override
  Widget build(BuildContext context) {
    final currentRoute = ModalRoute.of(context)?.settings.name;
    final role = AuthService().currentUserRole ?? UserRole.admin;
    final menuItems = role == UserRole.admin ? _adminMenuItems : _salesMenuItems;

    return Container(
      width: 260,
      height: double.infinity,
      decoration: const BoxDecoration(
        color: AppTheme.cardColor,
        border: Border(right: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Column(
        children: [
          // 1. Sidebar Header (Logo Section)
          Container(
            height: 70,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
              ),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Image.asset(
                'assets/images/logo.png',
                width: 150,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.storefront_rounded,
                  color: AppTheme.primaryColor,
                  size: 32,
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 2. Navigation Menu
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: menuItems.length,
              itemBuilder: (context, index) {
                final item = menuItems[index];
                final isActive = currentRoute == item['route'];

                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _SidebarItem(
                    icon: item['icon'] as IconData,
                    title: item['title'] as String,
                    isActive: isActive,
                    onTap: () {
                      if (currentRoute != item['route']) {
                        Navigator.pushReplacementNamed(
                          context,
                          item['route'] as String,
                        );
                      }
                    },
                  ),
                );
              },
            ),
          ),

          // Logout Button
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: _SidebarItem(
              icon: Icons.logout_rounded,
              title: 'Logout',
              isActive: false,
              onTap: () {
                AuthService().logout();
                Navigator.pushReplacementNamed(context, '/login');
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool isActive;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.title,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: AppTheme.primaryColor.withOpacity(0.04),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isActive
              ? AppTheme.primaryColor.withOpacity(0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: isActive ? AppTheme.primaryColor : const Color(0xFF6B7280),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: isActive
                      ? AppTheme.primaryColor
                      : const Color(0xFF374151),
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

