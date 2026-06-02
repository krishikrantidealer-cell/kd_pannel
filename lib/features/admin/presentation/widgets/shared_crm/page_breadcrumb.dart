import 'package:flutter/material.dart';
import 'package:kd_pannel/core/theme/app_colors.dart';
import 'package:kd_pannel/features/admin/presentation/widgets/shared_crm/interactive_item.dart';

class PageBreadcrumb extends StatelessWidget {
  const PageBreadcrumb({super.key});

  @override
  Widget build(BuildContext context) {
    return InteractiveItem(
      onTap: () => Navigator.pop(context),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.lightBorder, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(
          Icons.arrow_back_ios_new_rounded,
          size: 14,
          color: AppColors.slate800,
        ),
      ),
    );
  }
}
