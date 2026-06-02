import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kd_pannel/app_theme.dart';
import 'package:kd_pannel/core/responsive/responsive.dart';

class StatCardWidget extends StatefulWidget {
  final String title;
  final String value;
  final String? subtext;
  final Color color;
  final IconData? icon;
  final String? imagePath;
  final double? width;
  final bool isCompact;

  const StatCardWidget({
    super.key,
    required this.title,
    required this.value,
    this.subtext,
    required this.color,
    this.icon,
    this.imagePath,
    this.width,
    this.isCompact = false,
  });

  @override
  State<StatCardWidget> createState() => _StatCardWidgetState();
}

class _StatCardWidgetState extends State<StatCardWidget> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    final bool isMobile = Responsive.isMobile(context);

    if (widget.isCompact) {
      final double cardHeight = isMobile ? 68.0 : 82.0;
      final double horizontalPadding = isMobile ? 12.0 : 16.0;

      return MouseRegion(
        onEnter: (_) => setState(() => isHovered = true),
        onExit: (_) => setState(() => isHovered = false),
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          width: widget.width,
          height: cardHeight,
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          transform: Matrix4.diagonal3Values(isHovered ? 1.02 : 1.0, isHovered ? 1.02 : 1.0, 1.0),
          transformAlignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: isHovered
                ? [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                      spreadRadius: 0,
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
            border: Border.all(
              color: isHovered
                  ? widget.color.withValues(alpha: 0.25)
                  : AppTheme.borderColor.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                width: isMobile ? 38 : 46,
                height: isMobile ? 38 : 46,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      widget.color.withValues(alpha: isHovered ? 0.22 : 0.16),
                      widget.color.withValues(alpha: isHovered ? 0.12 : 0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                    if (isHovered)
                      BoxShadow(
                        color: widget.color.withValues(alpha: 0.15),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                  ],
                ),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                    child: widget.imagePath != null
                        ? Image.asset(
                            widget.imagePath!,
                            color: widget.color,
                            height: isMobile ? 22 : 26,
                            width: isMobile ? 22 : 26,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => Icon(
                              widget.icon ?? Icons.analytics_rounded,
                              color: widget.color,
                              size: isMobile ? 22 : 26,
                            ),
                          )
                        : Icon(
                            widget.icon ?? Icons.analytics_rounded,
                            color: widget.color,
                            size: isMobile ? 22 : 26,
                          ),
                  ),
                ),
              ),
              SizedBox(width: isMobile ? 12 : 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.title,
                      style: GoogleFonts.outfit(
                        fontSize: isMobile ? 10.5 : 11.5,
                        color: AppTheme.textPrimary.withValues(alpha: 0.75),
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      widget.value,
                      style: GoogleFonts.outfit(
                        fontSize: isMobile ? 18 : 22,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.textPrimary,
                        height: 1.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Dynamic height adaptation for premium mobile vs desktop/tablet layout
    final double cardHeight = isMobile ? 145.0 : 175.0;

    return MouseRegion(
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        width: widget.width,
        height: cardHeight,
        transform: Matrix4.diagonal3Values(isHovered ? 1.02 : 1.0, isHovered ? 1.02 : 1.0, 1.0),
        transformAlignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusXLarge),
          boxShadow: isHovered
              ? [
                  BoxShadow(
                    color: widget.color.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                    spreadRadius: 2,
                  ),
                  ...AppTheme.softShadow,
                ]
              : AppTheme.softShadow,
          border: isHovered
              ? Border.all(color: widget.color.withValues(alpha: 0.2), width: 1.5)
              : null,
        ),
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            // 1. Premium top curved gradient overlay
            ClipRRect(
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppTheme.borderRadiusXLarge),
              ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: isMobile ? 65 : 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      widget.color.withValues(alpha: isHovered ? 0.25 : 0.18),
                      widget.color.withValues(alpha: 0.01),
                    ],
                  ),
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.elliptical(
                      isMobile ? 100 : 130,
                      isMobile ? 25 : 35,
                    ),
                  ),
                ),
              ),
            ),

            // 2. Premium circular container for the Icon or Image Asset
            Positioned(
              top: isMobile ? 16 : 20,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: isMobile ? 40 : 48,
                height: isMobile ? 40 : 48,
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: isHovered ? 0.2 : 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isHovered ? widget.color.withValues(alpha: 0.3) : AppTheme.cardColor,
                    width: 2,
                  ),
                  boxShadow: isHovered
                      ? [
                          BoxShadow(
                            color: widget.color.withValues(alpha: 0.2),
                            blurRadius: 8,
                            spreadRadius: 1,
                          )
                        ]
                      : null,
                ),
                child: Center(
                  child: widget.imagePath != null
                      ? Image.asset(
                          widget.imagePath!,
                          color: widget.color,
                          height: isMobile ? 20 : 24,
                          width: isMobile ? 20 : 24,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => Icon(
                            widget.icon ?? Icons.analytics_outlined,
                            color: widget.color,
                            size: isMobile ? 20 : 24,
                          ),
                        )
                      : (widget.icon != null
                            ? Icon(widget.icon, color: widget.color, size: isMobile ? 20 : 24)
                            : Icon(
                                Icons.analytics_outlined,
                                color: widget.color,
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
                    widget.title,
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
                    widget.value,
                    style: TextStyle(
                      fontSize: isMobile ? 18 : 22,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (widget.subtext != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      widget.subtext!,
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
      ),
    );
  }
}

class StatCardShimmer extends StatefulWidget {
  final bool isCompact;
  final double? width;

  const StatCardShimmer({super.key, this.isCompact = false, this.width});

  @override
  State<StatCardShimmer> createState() => _StatCardShimmerState();
}

class _StatCardShimmerState extends State<StatCardShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(
      begin: 0.3,
      end: 0.85,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 768;

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        final Color shimmerColor = Colors.grey.withValues(alpha: 
          _pulseAnimation.value * 0.15 + 0.05,
        );

        if (widget.isCompact) {
          return Container(
            width: widget.width,
            height: 92, // exact match to _buildAdvancedStatCard height
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(
                AppTheme.borderRadiusMedium + 2,
              ),
              boxShadow: AppTheme.cardShadow,
              border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                // Left: text block shimmer
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Title bar
                      Container(
                        width: 80,
                        height: 10,
                        decoration: BoxDecoration(
                          color: shimmerColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Value bar (bigger)
                      Container(
                        width: 54,
                        height: 20,
                        decoration: BoxDecoration(
                          color: shimmerColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Trend badge shimmer
                      Container(
                        width: 96,
                        height: 10,
                        decoration: BoxDecoration(
                          color: shimmerColor.withValues(alpha: 
                            (shimmerColor.a * 0.6).clamp(0.0, 1.0),
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Right: visual widget placeholder (sparkline / ring)
                Container(
                  width: 50,
                  height: 24,
                  decoration: BoxDecoration(
                    color: shimmerColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          );
        }

        // Standard layout shimmer
        final double cardHeight = isMobile ? 145.0 : 175.0;
        return Container(
          width: widget.width,
          height: cardHeight,
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: BorderRadius.circular(AppTheme.borderRadiusXLarge),
            boxShadow: AppTheme.softShadow,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: isMobile ? 40 : 48,
                height: isMobile ? 40 : 48,
                decoration: BoxDecoration(
                  color: shimmerColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: 90,
                height: 10,
                decoration: BoxDecoration(
                  color: shimmerColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: 55,
                height: 18,
                decoration: BoxDecoration(
                  color: shimmerColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
