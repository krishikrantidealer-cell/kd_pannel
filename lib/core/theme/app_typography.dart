import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTypography {
  static const TextStyle h1 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w900,
    color: AppColors.slate900,
    letterSpacing: -1.2,
  );

  static const TextStyle h2 = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w900,
    color: AppColors.slate900,
    letterSpacing: -1.0,
  );

  static const TextStyle h3 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w900,
    color: AppColors.slate900,
    letterSpacing: -0.8,
  );

  static const TextStyle body = TextStyle(
    fontSize: 13,
    color: AppColors.slate500,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle label = TextStyle(
    fontSize: 7.5,
    color: AppColors.slate400,
    fontWeight: FontWeight.w900,
    letterSpacing: 1.0,
  );

  static const TextStyle value = TextStyle(
    fontSize: 13,
    color: AppColors.slate900,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.3,
  );
  
  static const TextStyle sidebarLabel = TextStyle(
    fontSize: 7.5,
    color: AppColors.slate400,
    fontWeight: FontWeight.w900,
    letterSpacing: 1.2,
  );
  
  static const TextStyle sidebarValue = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w800,
    color: AppColors.slate800,
    letterSpacing: -0.1,
  );
}
