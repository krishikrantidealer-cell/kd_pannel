import 'package:flutter/material.dart';
import 'package:kd_pannel/app_theme.dart';
import 'package:kd_pannel/core/responsive/responsive.dart';

class StatCardWidget extends StatelessWidget {
  final String title;
  final String value;
  final String? subtext;
  final Color color;
  final IconData? icon;
  final String? imagePath;
  final double? width;

  const StatCardWidget({
    super.key,
    required this.title,
    required this.value,
    this.subtext,
    required this.color,
    this.icon,
    this.imagePath,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final bool isMobile = Responsive.isMobile(context);

    // Dynamic height adaptation for premium mobile vs desktop/tablet layout
    final double cardHeight = isMobile ? 145.0 : 175.0;

    return Container(
      width: width,
      height: cardHeight,
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusXLarge),
        boxShadow: AppTheme.softShadow,
      ),
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          // 1. Premium top curved gradient overlay
          ClipRRect(
            borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.borderRadiusXLarge)),
            child: Container(
              height: isMobile ? 65 : 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    color.withOpacity(0.18),
                    color.withOpacity(0.01),
                  ],
                ),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.elliptical(isMobile ? 100 : 130, isMobile ? 25 : 35),
                ),
              ),
            ),
          ),

          // 2. Premium circular container for the Icon or Image Asset
          Positioned(
            top: isMobile ? 16 : 20,
            child: Container(
              width: isMobile ? 40 : 48,
              height: isMobile ? 40 : 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.cardColor, width: 2),
              ),
              child: Center(
                child: icon != null
                    ? Icon(
                        icon,
                        color: color,
                        size: isMobile ? 20 : 24,
                      )
                    : (imagePath != null
                        ? Image.asset(
                            imagePath!,
                            color: color,
                            height: isMobile ? 20 : 24,
                            width: isMobile ? 20 : 24,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => Icon(
                              Icons.analytics_outlined,
                              color: color,
                              size: isMobile ? 20 : 24,
                            ),
                          )
                        : Icon(
                            Icons.analytics_outlined,
                            color: color,
                            size: isMobile ? 20 : 24,
                          )),
              ),
            ),
          ),

          // 3. Info text block positioned beautifully at the bottom
          Positioned(
            bottom: isMobile ? 12 : 16,
            left: 8,
            right: 8,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: isMobile ? 11 : 12,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: isMobile ? 3 : 5),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: isMobile ? 18 : 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtext != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtext!,
                    style: TextStyle(
                      fontSize: isMobile ? 9.5 : 11,
                      color: const Color(0xFF9CA3AF),
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
