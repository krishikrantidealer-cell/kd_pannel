import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppShadows {
  static final List<BoxShadow> sidebar = [
    BoxShadow(
      color: AppColors.slate900.withValues(alpha: 0.03),
      blurRadius: 40,
      offset: const Offset(0, 16),
    ),
  ];

  static final List<BoxShadow> card = [
    BoxShadow(
      color: AppColors.slate900.withValues(alpha: 0.015),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];

  static final List<BoxShadow> avatar = [
    BoxShadow(
      color: AppColors.primary.withValues(alpha: 0.15),
      blurRadius: 24,
      offset: const Offset(0, 10),
    ),
  ];

  static final List<BoxShadow> panel = [
    BoxShadow(
      color: AppColors.slate900.withValues(alpha: 0.15),
      blurRadius: 50,
      offset: const Offset(-20, 0),
    ),
  ];

  static final List<BoxShadow> button = [
    BoxShadow(
      color: AppColors.slate900.withValues(alpha: 0.2),
      blurRadius: 16,
      offset: const Offset(0, 8),
    ),
  ];
}
