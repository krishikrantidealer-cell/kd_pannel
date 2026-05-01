import 'package:flutter/material.dart';

class SidebarWidget extends StatelessWidget {
  const SidebarWidget({super.key});

  @override
  Widget build(BuildContext context) {
    //bjgbjb
    return Container(
      width: 260,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Color(0xFFF3F4F6))),
      ),
      child: Column(
        children: [
          const SizedBox(height: 32), // Top padding
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _MenuItem(
              icon: Icons.dashboard_rounded,
              title: 'Dashboard',
              isActive: true,
              onTap: () {},
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool isActive;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.title,
    this.isActive = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF4CAF50).withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: isActive ? const Color(0xFF4CAF50) : const Color(0xFF6B7280),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                color: isActive ? const Color(0xFF2E7D32) : const Color(0xFF374151),
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
