import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:kd_pannel/app_theme.dart';
import 'package:kd_pannel/core/responsive/responsive.dart';

class TopbarWidget extends StatelessWidget {
  final VoidCallback? onMenuPressed;
  const TopbarWidget({super.key, this.onMenuPressed});

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = Responsive.isDesktop(context);
    final bool isMobile = Responsive.isMobile(context);

    return Container(
      height: isMobile ? 60 : 70,
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppTheme.cardColor,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
        ),
      ),
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Menu button for Mobile/Tablet
          if (!isDesktop) ...[
            IconButton(
              onPressed: onMenuPressed,
              icon: Icon(Icons.menu, color: const Color(0xFF4B5563), size: isMobile ? 22 : 24),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            SizedBox(width: isMobile ? 8 : 12),
          ],

          // 1. Search Bar (Left aligned, pill shape)
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 550),
              height: isMobile ? 36 : 40,
              child: CupertinoSearchTextField(
                placeholder: 'Search...',
                placeholderStyle: TextStyle(
                  color: const Color(0xFF9CA3AF),
                  fontSize: isMobile ? 12 : 13,
                ),
                prefixInsets: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 14),
                itemColor: const Color(0xFF9CA3AF),
                style: TextStyle(fontSize: isMobile ? 13 : 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
                ),
              ),
            ),
          ),

          SizedBox(width: isMobile ? 12 : 16),

          // 2. Right Side Icons (Notification + Profile)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Notification Icon
              Container(
                width: isMobile ? 34 : 40,
                height: isMobile ? 34 : 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(isMobile ? 8 : 10),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(Icons.notifications_none_outlined, color: const Color(0xFF4B5563), size: isMobile ? 20 : 22),
                    Positioned(
                      top: isMobile ? 8 : 10,
                      right: isMobile ? 8 : 10,
                      child: Container(
                        width: isMobile ? 6 : 8,
                        height: isMobile ? 6 : 8,
                        decoration: BoxDecoration(
                          color: AppTheme.error,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: isMobile ? 10 : 16),
              // Profile Image
              Container(
                width: isMobile ? 34 : 40,
                height: isMobile ? 34 : 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE5E7EB), width: isMobile ? 1.5 : 2),
                  image: const DecorationImage(
                    image: AssetImage('assets/images/admin.png'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
