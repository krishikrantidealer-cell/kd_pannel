import 'package:flutter/material.dart';
import 'package:kd_pannel/app_theme.dart';

class StatCardWidget extends StatelessWidget {
  final String title;
  final String value;
  final String? subtext;
  final Color color;
  final IconData icon;
  final bool isSmall;

  const StatCardWidget({
    super.key,
    required this.title,
    required this.value,
    this.subtext,
    required this.color,
    required this.icon,
    this.isSmall = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isSmall) {
      // 5 Square-ish cards
      return Container(
        padding: const EdgeInsets.symmetric(
          vertical: 20,
          horizontal: AppTheme.spacingMedium - 4,
        ),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusXLarge),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingMedium - 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: AppTheme.spacingMedium - 4),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF757575), // Using a generic gray for now as it doesn't match exactly textSecondary
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacingXSmall),
            Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF212121), // Using a dark gray
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    } else {
      // 4 Rectangular cards
      return Container(
        padding: const EdgeInsets.all(AppTheme.spacingXLarge - 12), // 20
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: AppTheme.spacingSmall),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF424242),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingMedium - 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF212121),
              ),
            ),
            if (subtext != null) ...[
              const SizedBox(height: AppTheme.spacingXSmall),
              Text(
                subtext!,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ],
        ),
      );
    }
  }
}
