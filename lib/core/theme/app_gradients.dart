import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppGradients {
  static final LinearGradient sidebar = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Colors.white,
      AppColors.slate50.withValues(alpha: 0.9),
      AppColors.slate100.withValues(alpha: 0.5),
      AppColors.slate200.withValues(alpha: 0.2),
    ],
    stops: const [0.0, 0.4, 0.8, 1.0],
  );

  static final RadialGradient primaryAura = RadialGradient(
    colors: [
      AppColors.primary.withValues(alpha: 0.1),
      AppColors.primary.withValues(alpha: 0.0),
    ],
  );

  static final RadialGradient secondaryAura = RadialGradient(
    colors: [
      AppColors.secondary.withValues(alpha: 0.06),
      AppColors.secondary.withValues(alpha: 0.0),
    ],
  );

  static final LinearGradient avatarRing = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      AppColors.primary.withValues(alpha: 0.3),
      AppColors.primary.withValues(alpha: 0.0),
      AppColors.secondary.withValues(alpha: 0.2),
    ],
  );

  static final LinearGradient statusBadge = LinearGradient(
    colors: [
      const Color(0xFFDCFCE7),
      const Color(0xFFF0FDF4).withValues(alpha: 0.8),
    ],
  );
  
  static LinearGradient primaryButton = const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.slate900, AppColors.slate800],
  );
}
