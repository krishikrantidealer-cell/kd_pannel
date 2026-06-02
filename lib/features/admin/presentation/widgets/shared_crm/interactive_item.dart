import 'package:flutter/material.dart';

class InteractiveItem extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final double borderRadius;

  const InteractiveItem({
    super.key,
    required this.child,
    required this.onTap,
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(borderRadius),
      hoverColor: Colors.transparent,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: child,
    );
  }
}
