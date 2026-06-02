import 'package:flutter/material.dart';
import 'package:kd_pannel/core/theme/app_colors.dart';
import 'package:kd_pannel/core/theme/app_typography.dart';

class TimelineStreamItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String time;
  final String desc;
  final bool isLast;

  const TimelineStreamItem({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.time,
    required this.desc,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: color.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
              child: Icon(icon, size: 14, color: color),
            ),
            if (!isLast)
              Container(
                width: 1.2,
                height: 38,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      color.withValues(alpha: 0.22),
                      AppColors.lightBorder,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: AppTypography.h3.copyWith(
                      fontSize: 14,
                      letterSpacing: -0.3,
                    ),
                  ),
                  Text(
                    time,
                    style: AppTypography.body.copyWith(
                      fontSize: 11,
                      color: AppColors.slate400,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                desc,
                style: AppTypography.body.copyWith(
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ],
    );
  }
}
