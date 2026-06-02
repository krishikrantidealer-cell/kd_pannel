import 'package:flutter/material.dart';
import 'package:kd_pannel/core/theme/app_colors.dart';
import 'package:kd_pannel/core/theme/app_typography.dart';

class ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isPrimary;
  final bool isOutlined;
  final bool isSecondary;
  final VoidCallback? onTap;

  const ActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    this.isPrimary = false,
    this.isOutlined = false,
    this.isSecondary = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap ?? () {},
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: isPrimary
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color,
                    color.withValues(alpha: 0.85),
                  ],
                )
              : null,
          color: isPrimary
              ? null
              : (isSecondary
                  ? color.withValues(alpha: 0.14)
                  : (isOutlined ? Colors.transparent : AppColors.slate50)),
          borderRadius: BorderRadius.circular(14),
          border: isOutlined
              ? Border.all(
                  color: color.withValues(alpha: 0.35),
                  width: 1.5,
                )
              : (isPrimary ? null : Border.all(color: Colors.transparent, width: 1.5)),
          boxShadow: isPrimary
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.25),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  )
                ]
              : const [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isPrimary ? Colors.white : color,
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                label,
                style: AppTypography.sidebarValue.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: isPrimary ? Colors.white : color,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
