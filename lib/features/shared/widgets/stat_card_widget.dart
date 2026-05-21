import 'package:flutter/material.dart';
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
  bool _isHovered = false;

  Widget _buildAnimatedValue(String val, TextStyle style) {
    final cleanVal = val.replaceAll(RegExp(r'[^\d.]'), '');
    final double? targetVal = double.tryParse(cleanVal);

    if (targetVal == null) {
      return Text(
        val,
        style: style,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
      );
    }

    final prefix = val.split(cleanVal).first;
    final suffix = val.split(cleanVal).last;
    final isInt = !cleanVal.contains('.');

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: targetVal),
      duration: const Duration(milliseconds: 1500),
      curve: Curves.easeOutCubic,
      builder: (context, current, child) {
        final displayNum = isInt
            ? current.toInt().toString()
            : current.toStringAsFixed(2);
        return Text(
          '$prefix$displayNum$suffix',
          style: style,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = Responsive.isMobile(context);

    Widget content;
    if (widget.isCompact) {
      final double cardHeight = isMobile ? 64.0 : 72.0;
      final double padding = isMobile ? 10.0 : 12.0;

      content = Container(
        width: widget.width,
        height: cardHeight,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
          boxShadow: [
            BoxShadow(
              color: widget.color.withOpacity(_isHovered ? 0.15 : 0.08),
              blurRadius: _isHovered ? 15 : 10,
              offset: Offset(0, _isHovered ? 6 : 4),
            ),
            AppTheme.cardShadow.first,
          ],
          border: Border.all(color: widget.color.withOpacity(0.15), width: 1),
        ),
        child: Stack(
          children: [
            // Background Watermark Icon
            Positioned(
              right: -5,
              bottom: -5,
              child: Transform.rotate(
                angle: -0.2,
                child: Icon(
                  widget.icon ?? Icons.analytics_outlined,
                  size: 45,
                  color: widget.color.withOpacity(0.04),
                ),
              ),
            ),
            // Main Content
            Padding(
              padding: EdgeInsets.symmetric(horizontal: padding),
              child: Row(
                children: [
                  Container(
                    width: isMobile ? 32 : 38,
                    height: isMobile ? 32 : 38,
                    decoration: BoxDecoration(
                      color: widget.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: widget.color.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: widget.imagePath != null
                          ? Image.asset(
                              widget.imagePath!,
                              color: widget.color,
                              height: isMobile ? 16 : 18,
                              width: isMobile ? 16 : 18,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) =>
                                  Icon(
                                    widget.icon ?? Icons.analytics_outlined,
                                    color: widget.color,
                                    size: isMobile ? 16 : 18,
                                  ),
                            )
                          : Icon(
                              widget.icon ?? Icons.analytics_outlined,
                              color: widget.color,
                              size: isMobile ? 16 : 18,
                            ),
                    ),
                  ),
                  SizedBox(width: isMobile ? 8 : 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.title,
                          style: TextStyle(
                            fontSize: isMobile ? 10.5 : 11.5,
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 1),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Flexible(
                              child: _buildAnimatedValue(
                                widget.value,
                                TextStyle(
                                  fontSize: isMobile ? 16 : 18,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ),
                            if (widget.subtext != null) ...[
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  widget.subtext!,
                                  style: TextStyle(
                                    fontSize: isMobile ? 9 : 10,
                                    color: widget.color,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      // Dynamic height adaptation for premium mobile vs desktop/tablet layout
      final double cardHeight = isMobile ? 145.0 : 175.0;

      content = Container(
        width: widget.width,
        height: cardHeight,
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusXLarge),
          boxShadow: _isHovered
              ? [
                  BoxShadow(
                    color: widget.color.withOpacity(0.12),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                  ...AppTheme.softShadow,
                ]
              : AppTheme.softShadow,
        ),
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            // 1. Premium top curved gradient overlay
            ClipRRect(
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppTheme.borderRadiusXLarge),
              ),
              child: Container(
                height: isMobile ? 65 : 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      widget.color.withOpacity(0.18),
                      widget.color.withOpacity(0.01),
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
              child: Container(
                width: isMobile ? 40 : 48,
                height: isMobile ? 40 : 48,
                decoration: BoxDecoration(
                  color: widget.color.withOpacity(0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.cardColor, width: 2),
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
                            ? Icon(
                                widget.icon,
                                color: widget.color,
                                size: isMobile ? 20 : 24,
                              )
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
                  _buildAnimatedValue(
                    widget.value,
                    TextStyle(
                      fontSize: isMobile ? 18 : 22,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
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
      );
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.basic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        transform: Matrix4.identity()..scale(_isHovered ? 1.01 : 1.0),
        child: content,
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
        final Color shimmerColor = Colors.grey.withOpacity(
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
              border: Border.all(color: AppTheme.borderColor.withOpacity(0.4)),
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
                          color: shimmerColor.withOpacity(
                            (shimmerColor.opacity * 0.6).clamp(0.0, 1.0),
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
