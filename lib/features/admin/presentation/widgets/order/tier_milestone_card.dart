import 'package:flutter/material.dart';

class TierMilestoneCard extends StatefulWidget {
  final String label;
  final double threshold;
  final double price;
  final bool isUnlocked;
  final bool isActive;
  final String baseUnit;
  final VoidCallback? onTap;

  const TierMilestoneCard({
    super.key,
    required this.label,
    required this.threshold,
    required this.price,
    required this.isUnlocked,
    this.isActive = false,
    required this.baseUnit,
    this.onTap,
  });

  @override
  State<TierMilestoneCard> createState() => _TierMilestoneCardState();
}

class _TierMilestoneCardState extends State<TierMilestoneCard>
    with TickerProviderStateMixin {
  late AnimationController _unlockController;
  late AnimationController _bounceController;
  late Animation<double> _scaleAnimation;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();

    _unlockController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );

    _scaleAnimation =
        TweenSequence<double>([
          TweenSequenceItem<double>(
            tween: Tween<double>(
              begin: 1.0,
              end: 1.12,
            ).chain(CurveTween(curve: Curves.easeOut)),
            weight: 40.0,
          ),
          TweenSequenceItem<double>(
            tween: Tween<double>(
              begin: 1.12,
              end: 0.96,
            ).chain(CurveTween(curve: Curves.easeInOut)),
            weight: 30.0,
          ),
          TweenSequenceItem<double>(
            tween: Tween<double>(
              begin: 0.96,
              end: 1.0,
            ).chain(CurveTween(curve: Curves.easeOut)),
            weight: 30.0,
          ),
        ]).animate(
          CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut),
        );

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _shakeAnimation =
        TweenSequence<double>([
          TweenSequenceItem<double>(
            tween: Tween<double>(begin: 0.0, end: 5.0),
            weight: 15,
          ),
          TweenSequenceItem<double>(
            tween: Tween<double>(begin: 5.0, end: -5.0),
            weight: 20,
          ),
          TweenSequenceItem<double>(
            tween: Tween<double>(begin: -5.0, end: 3.0),
            weight: 15,
          ),
          TweenSequenceItem<double>(
            tween: Tween<double>(begin: 3.0, end: -3.0),
            weight: 15,
          ),
          TweenSequenceItem<double>(
            tween: Tween<double>(begin: -3.0, end: 1.0),
            weight: 15,
          ),
          TweenSequenceItem<double>(
            tween: Tween<double>(begin: 1.0, end: 0.0),
            weight: 20,
          ),
        ]).animate(
          CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut),
        );

    if (widget.isUnlocked) {
      _unlockController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant TierMilestoneCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isUnlocked && !oldWidget.isUnlocked) {
      _unlockController.forward(from: 0.0);
      _bounceController.forward(from: 0.0);
    } else if (!widget.isUnlocked && oldWidget.isUnlocked) {
      _unlockController.reverse(from: 1.0);
    } else {
      if (!_unlockController.isAnimating) {
        _unlockController.value = widget.isUnlocked ? 1.0 : 0.0;
      }
    }
  }

  @override
  void dispose() {
    _unlockController.dispose();
    _bounceController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryGreen = Color(0xFF298E4D);
    const Color secondaryGreen = Color(0xFFE8F5E9);

    final String unitLabel = widget.baseUnit == 'pcs'
        ? 'pcs'
        : widget.baseUnit == 'kg'
        ? 'kg'
        : 'lit.';
    final formattedPrice = widget.price % 1 == 0
        ? widget.price.toStringAsFixed(0)
        : widget.price.toStringAsFixed(2);
    final String perUnitStr = '₹$formattedPrice/$unitLabel';

    return GestureDetector(
      onTap: () {
        if (!widget.isUnlocked) {
          _shakeController.forward(from: 0.0);
        }
        widget.onTap?.call();
      },
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _unlockController,
          _bounceController,
          _shakeAnimation,
        ]),
        builder: (context, child) {
          final double animValue = _unlockController.value;

          final Color backgroundColor = Color.lerp(
            Colors.grey.shade100,
            secondaryGreen,
            animValue,
          )!;

          final Color borderColor = Color.lerp(
            Colors.grey.shade300,
            primaryGreen,
            animValue,
          )!;

          final Color textColor = Color.lerp(
            Colors.grey.shade700,
            primaryGreen,
            animValue,
          )!;

          final Color subtextColor = Color.lerp(
            Colors.grey.shade500,
            primaryGreen.withValues(alpha: 0.85),
            animValue,
          )!;

          final double shadowOpacity = animValue * 0.15;

          final double cardOpacity = !widget.isUnlocked
              ? 1.0
              : widget.isActive
              ? 1.0
              : 0.55;

          return Transform.translate(
            offset: Offset(_shakeAnimation.value, 0),
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Opacity(
                opacity: cardOpacity,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                      color: borderColor,
                      width: animValue > 0.5 ? 1.5 : 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: primaryGreen.withValues(alpha: shadowOpacity),
                        blurRadius: 6 * animValue,
                        spreadRadius: 1 * animValue,
                        offset: Offset(0, 2 * animValue),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Opacity(
                            opacity: (1.0 - animValue).clamp(0.0, 1.0),
                            child: Icon(
                              Icons.lock_outline_rounded,
                              color: Colors.grey.shade500,
                              size: 12,
                            ),
                          ),
                          Opacity(
                            opacity: animValue.clamp(0.0, 1.0),
                            child: const Icon(
                              Icons.verified_rounded,
                              color: primaryGreen,
                              size: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                widget.label,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w900,
                                  color: textColor,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                perUnitStr,
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: subtextColor,
                                  decoration:
                                      (widget.isUnlocked && !widget.isActive)
                                      ? TextDecoration.lineThrough
                                      : TextDecoration.none,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
