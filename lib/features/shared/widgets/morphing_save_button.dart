import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kd_pannel/app_theme.dart';

class MorphingSaveButton extends StatelessWidget {
  final bool isLoading;
  final bool isSuccess;
  final VoidCallback? onTap;
  final String text;
  final double width;
  final double height;

  const MorphingSaveButton({
    super.key,
    required this.isLoading,
    this.isSuccess = false,
    required this.onTap,
    this.text = 'Save',
    this.width = 160,
    this.height = 45,
  });

  @override
  Widget build(BuildContext context) {
    final bool isIdle = !isLoading && !isSuccess;

    final double currentWidth = isIdle ? width : height;
    final Color currentColor = isSuccess ? AppTheme.success : AppTheme.primaryColor;

    return GestureDetector(
      onTap: isIdle ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
        width: currentWidth,
        height: height,
        decoration: BoxDecoration(
          color: currentColor,
          borderRadius: BorderRadius.circular(isIdle ? 10 : height / 2),
          boxShadow: isIdle
              ? [
                  BoxShadow(
                    color: currentColor.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ]
              : [],
        ),
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _buildChild(isIdle, isSuccess),
          ),
        ),
      ),
    );
  }

  Widget _buildChild(bool isIdle, bool isSuccess) {
    if (isSuccess) {
      return const Icon(
        Icons.check_rounded,
        color: Colors.white,
        key: ValueKey('success'),
      );
    }
    if (isIdle) {
      return Text(
        text,
        key: const ValueKey('idle'),
        style: GoogleFonts.outfit(
          fontSize: 14,
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      );
    }
    return const SizedBox(
      key: ValueKey('loading'),
      width: 20,
      height: 20,
      child: CircularProgressIndicator(
        strokeWidth: 2.5,
        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
      ),
    );
  }
}
