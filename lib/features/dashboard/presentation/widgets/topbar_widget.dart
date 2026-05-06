import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:kd_pannel/app_theme.dart';

class TopbarWidget extends StatelessWidget {
  const TopbarWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppTheme.cardColor,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 1. Search Bar (Left aligned, pill shape)
          SizedBox(
            width: 550, // Fixed medium width
            height: 40,
            child: CupertinoSearchTextField(
              placeholder: 'Search anything here...',
              placeholderStyle: const TextStyle(
                color: Color(0xFF9CA3AF),
                fontSize: 13,
              ),
              prefixInsets: const EdgeInsets.symmetric(horizontal: 14),
              itemColor: const Color(0xFF9CA3AF),
              style: const TextStyle(fontSize: 14),
              // Thin grey border added as requested
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
              ),
            ),
          ),

          // 2. Right Side Icons (Notification + Profile)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Notification Icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Icon(Icons.notifications_none_outlined, color: Color(0xFF4B5563), size: 22),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        width: 8,
                        height: 8,
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
              const SizedBox(width: 16),
              // Profile Image
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE5E7EB), width: 2),
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
