import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:ui' as ui;
import 'package:kd_pannel/app_theme.dart';
import 'package:kd_pannel/core/responsive/responsive.dart';

class TopbarWidget extends StatelessWidget {
  final VoidCallback? onMenuPressed;
  const TopbarWidget({super.key, this.onMenuPressed});

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = Responsive.isDesktop(context);
    final bool isMobile = Responsive.isMobile(context);

    final double height = isMobile ? 60 : 72;

    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: height,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.88),
                AppTheme.cardColor.withValues(alpha: 0.9),
              ],
            ),
            border: const Border(
              bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 24),
          child: Row(
            children: [
              // Menu button for Mobile/Tablet
              if (!isDesktop) ...[
                _TopbarIconButton(
                  tooltip: 'Menu',
                  size: isMobile ? 36 : 40,
                  onTap: onMenuPressed,
                  icon: Icon(
                    Icons.menu_rounded,
                    color: const Color(0xFF334155),
                    size: isMobile ? 20 : 22,
                  ),
                ),
                SizedBox(width: isMobile ? 10 : 14),
              ],

              // Search Bar
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 620),
                  child: SizedBox(
                    height: isMobile ? 36 : 42,
                    child: CupertinoSearchTextField(
                      placeholder: isMobile ? 'Search' : 'Search orders, users, products...',
                      placeholderStyle: TextStyle(
                        color: const Color(0xFF94A3B8),
                        fontSize: isMobile ? 12 : 13,
                      ),
                      prefixInsets: EdgeInsets.symmetric(
                        horizontal: isMobile ? 10 : 14,
                      ),
                      itemColor: const Color(0xFF94A3B8),
                      style: TextStyle(
                        fontSize: isMobile ? 13 : 14,
                        color: const Color(0xFF0F172A),
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: const Color(0xFFE5E7EB),
                          width: 1,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              SizedBox(width: isMobile ? 10 : 16),

              // Right Side Actions
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _TopbarIconButton(
                    tooltip: 'Notifications',
                    size: isMobile ? 36 : 40,
                    onTap: () {},
                    icon: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(
                          Icons.notifications_none_rounded,
                          color: const Color(0xFF334155),
                          size: isMobile ? 20 : 22,
                        ),
                        Positioned(
                          top: -1,
                          right: -1,
                          child: Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(
                              color: AppTheme.error,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.9),
                                width: 1.4,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: isMobile ? 10 : 12),
                  Container(
                    width: isMobile ? 36 : 40,
                    height: isMobile ? 36 : 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFE5E7EB),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/admin.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopbarIconButton extends StatefulWidget {
  final Widget icon;
  final VoidCallback? onTap;
  final String tooltip;
  final double size;

  const _TopbarIconButton({
    required this.icon,
    required this.tooltip,
    required this.size,
    this.onTap,
  });

  @override
  State<_TopbarIconButton> createState() => _TopbarIconButtonState();
}

class _TopbarIconButtonState extends State<_TopbarIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Tooltip(
        message: widget.tooltip,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: _hovered
                  ? Colors.white.withValues(alpha: 0.85)
                  : Colors.white.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _hovered
                    ? const Color(0xFFCBD5E1)
                    : const Color(0xFFE5E7EB),
              ),
            ),
            child: Center(child: widget.icon),
          ),
        ),
      ),
    );
  }
}
