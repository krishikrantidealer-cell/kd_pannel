import 'package:flutter/material.dart';
import 'package:kd_pannel/app_theme.dart';
import 'package:kd_pannel/core/auth/auth_service.dart';

class SidebarWidget extends StatefulWidget {
  final int currentIdx;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onLogout;
  final bool forceExpanded;

  const SidebarWidget({
    super.key,
    required this.currentIdx,
    required this.onTabSelected,
    required this.onLogout,
    this.forceExpanded = false,
  });

  @override
  State<SidebarWidget> createState() => _SidebarWidgetState();
}

class _SidebarWidgetState extends State<SidebarWidget> {
  bool _isHovered = false;

  static const List<Map<String, dynamic>> _adminMenuItems = [
    {'icon': Icons.dashboard_rounded, 'title': 'Dashboard'},
    {'icon': Icons.inventory_2_rounded, 'title': 'Products'},
    {'icon': Icons.campaign_rounded, 'title': 'Leads'},
    {'icon': Icons.storefront_rounded, 'title': 'Dealers'},
    {'icon': Icons.support_agent_rounded, 'title': 'Support'},
  ];

  static const List<Map<String, dynamic>> _salesMenuItems = [
    {'icon': Icons.dashboard_rounded, 'title': 'Sales Dashboard'},
    {'icon': Icons.inventory_2_rounded, 'title': 'Products'},
    {'icon': Icons.campaign_rounded, 'title': 'My Leads'},
    {'icon': Icons.storefront_rounded, 'title': 'My Dealers'},
  ];

  @override
  Widget build(BuildContext context) {
    final role = AuthService().currentUserRole ?? UserRole.admin;
    final menuItems = role == UserRole.admin ? _adminMenuItems : _salesMenuItems;
    
    const double collapsedWidth = 72.0; 
    const double expandedWidth = 250.0;
    
    final bool isExpanded = widget.forceExpanded || _isHovered;
    final Color deepGreen = const Color(0xFF164D29);
    final Color midGreen = AppTheme.primaryColor;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        width: isExpanded ? expandedWidth : collapsedWidth,
        height: double.infinity,
        decoration: BoxDecoration(
          color: deepGreen,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 40,
              offset: const Offset(10, 0),
            ),
          ],
        ),
        child: RepaintBoundary(
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              // 1. Premium Layered Background
              Positioned.fill(
                child: RepaintBoundary(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          deepGreen,
                          deepGreen.withValues(alpha: 0.95),
                          midGreen.withValues(alpha: 0.8),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
  
              // 2. Subtle Radial Glow
              Positioned(
                top: -80,
                right: -80,
                child: RepaintBoundary(
                  child: Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.08),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
  
              // 3. Subtle Right Border
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 1,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
  
              // 4. Main Content
              Column(
                children: [
                  _SidebarHeader(isExpanded: isExpanded),
                  
                  const SizedBox(height: 12), 
                  
                  // Navigation Section
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      itemCount: menuItems.length,
                      physics: const BouncingScrollPhysics(),
                      itemBuilder: (context, index) {
                        final item = menuItems[index];
                        final isActive = widget.currentIdx == index;
  
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: _SidebarItem(
                            icon: item['icon'] as IconData,
                            title: item['title'] as String,
                            isActive: isActive,
                            isExpanded: isExpanded,
                            onTap: () => widget.onTabSelected(index),
                          ),
                        );
                      },
                    ),
                  ),
  
                  // Footer Section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    child: Column(
                      children: [
                        Container(
                          height: 1,
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withValues(alpha: 0.0),
                                Colors.white.withValues(alpha: 0.1),
                                Colors.white.withValues(alpha: 0.0),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _SidebarItem(
                          icon: Icons.logout_rounded,
                          title: 'Logout',
                          isActive: false,
                          isExpanded: isExpanded,
                          onTap: widget.onLogout,
                          isLogout: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarHeader extends StatelessWidget {
  final bool isExpanded;

  const _SidebarHeader({required this.isExpanded});

  @override
  Widget build(BuildContext context) {
    final double headerHeight = isExpanded ? 110 : 72;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      height: headerHeight,
      width: double.infinity,
      curve: Curves.easeOutCubic,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 1. Collapsed State: Mathematically Centered
          AnimatedOpacity(
            duration: const Duration(milliseconds: 180),
            opacity: isExpanded ? 0 : 1,
            child: SizedBox(
              width: 72, 
              child: Center(
                child: Image.asset(
                  'assets/images/logo_copy.png',
                  width: 32,
                  height: 32,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          
          // 2. Expanded State: Compact Branding Zone
          AnimatedOpacity(
            duration: const Duration(milliseconds: 250),
            opacity: isExpanded ? 1 : 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 48, 20, 4),
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.6, -0.2),
                  radius: 1.4,
                  colors: [
                    Colors.white.withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Image.asset(
                'assets/images/logo.png',
                width: 180,
                fit: BoxFit.fitWidth,
                alignment: Alignment.centerLeft,
                filterQuality: FilterQuality.high,
                errorBuilder: (context, error, stackTrace) => Text(
                  'KRISHI DEALER',
                  style: AppTheme.headingXL.copyWith(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatefulWidget {
  final IconData icon;
  final String title;
  final bool isActive;
  final bool isExpanded;
  final VoidCallback onTap;
  final bool isLogout;

  const _SidebarItem({
    required this.icon,
    required this.title,
    required this.isActive,
    required this.isExpanded,
    required this.onTap,
    this.isLogout = false,
  });

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final bool showActive = widget.isActive;
    
    return RepaintBoundary(
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            height: 44, // Compact height
            decoration: BoxDecoration(
              gradient: showActive
                  ? LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.14),
                        Colors.white.withValues(alpha: 0.06),
                      ],
                    )
                  : (_isHovered
                      ? LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.08),
                            Colors.white.withValues(alpha: 0.02),
                          ],
                        )
                      : null),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: showActive
                    ? Colors.white.withValues(alpha: 0.15)
                    : (_isHovered
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.transparent),
                width: 1,
              ),
            ),
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                // Active Indicator
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  left: showActive ? 0 : -6,
                  top: 10,
                  bottom: 10,
                  width: 3,
                  child: Container(
                    decoration: BoxDecoration(
                      color: widget.isLogout ? AppTheme.error : AppTheme.accentColor,
                      borderRadius: const BorderRadius.horizontal(right: Radius.circular(3)),
                      boxShadow: [
                        BoxShadow(
                          color: (widget.isLogout ? AppTheme.error : AppTheme.accentColor)
                              .withValues(alpha: 0.5),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                ),
  
                Row(
                  children: [
                    // Icon Container: Sized to fit perfectly within collapsed width (72 - 10 - 10 = 52)
                    // Subtracting 2px for borders = 50
                    SizedBox(
                      width: 50,
                      child: Center(
                        child: AnimatedScale(
                          duration: const Duration(milliseconds: 200),
                          scale: _isHovered ? 1.05 : 1.0,
                          child: Icon(
                            widget.icon,
                            size: 19, 
                            color: showActive
                                ? (widget.isLogout ? AppTheme.error : AppTheme.accentColor)
                                : Colors.white.withValues(alpha: _isHovered ? 1.0 : 0.65),
                          ),
                        ),
                      ),
                    ),
  
                    // Label Text: Wrapped in Flexible with ellipsis to prevent overflow
                    if (widget.isExpanded) 
                      Flexible(
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          opacity: widget.isExpanded ? 1 : 0,
                          child: Text(
                            widget.title,
                            style: AppTheme.bodyLG.copyWith(
                              color: Colors.white.withValues(
                                alpha: showActive || _isHovered ? 1.0 : 0.75,
                              ),
                              fontWeight: showActive ? FontWeight.w800 : FontWeight.w600,
                              fontSize: 13.5,
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            softWrap: false,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
