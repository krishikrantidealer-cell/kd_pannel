import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kd_pannel/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

class LiveCustomerPulseWidget extends StatefulWidget {
  final List<Map<String, dynamic>> realTimeUsers;
  final Function(String userName)? onUserSelected;
  final VoidCallback? onRefresh;

  const LiveCustomerPulseWidget({
    super.key,
    required this.realTimeUsers,
    this.onUserSelected,
    this.onRefresh,
  });

  @override
  State<LiveCustomerPulseWidget> createState() => _LiveCustomerPulseWidgetState();
}

class _LiveCustomerPulseWidgetState extends State<LiveCustomerPulseWidget>
    with SingleTickerProviderStateMixin {
  String _selectedFilter = 'All';
  String _searchQuery = '';
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleanPhone.isEmpty) return;
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _openWhatsApp(String phoneNumber, String name) {
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleanPhone.isEmpty) return;
    final uri = Uri.parse('https://wa.me/$cleanPhone');
    launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String _getRelativeLastSeen(dynamic rawLastSeen) {
    if (rawLastSeen == null) return 'Live';
    int timestamp = 0;
    if (rawLastSeen is int) {
      timestamp = rawLastSeen;
    } else if (rawLastSeen is String) {
      final parsed = DateTime.tryParse(rawLastSeen);
      if (parsed != null) timestamp = parsed.millisecondsSinceEpoch;
    }
    if (timestamp == 0) return 'Live';

    final diff = DateTime.now().millisecondsSinceEpoch - timestamp;
    if (diff < 15000) return 'Live';
    if (diff < 60000) return '${(diff / 1000).floor()}s ago';
    if (diff < 3600000) return '${(diff / 60000).floor()}m ago';
    return '${(diff / 3600000).floor()}h ago';
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;

    int hotCount = 0;
    int warmCount = 0;
    int browsingCount = 0;

    for (final u in widget.realTimeUsers) {
      final label = u['intentLabel']?.toString() ?? '';
      if (label.contains('Hot')) {
        hotCount++;
      } else if (label.contains('Warm')) {
        warmCount++;
      } else {
        browsingCount++;
      }
    }

    final filteredUsers = widget.realTimeUsers.where((u) {
      final name = (u['userName'] ?? u['user'] ?? '').toString().toLowerCase();
      final phone = (u['userPhone'] ?? '').toString().toLowerCase();
      final screen = (u['currentScreen'] ?? '').toString().toLowerCase();
      final action = (u['action'] ?? '').toString().toLowerCase();
      final label = (u['intentLabel'] ?? '').toString();

      final matchesSearch = _searchQuery.isEmpty ||
          name.contains(_searchQuery.toLowerCase()) ||
          phone.contains(_searchQuery.toLowerCase()) ||
          screen.contains(_searchQuery.toLowerCase()) ||
          action.contains(_searchQuery.toLowerCase());

      bool matchesFilter = true;
      if (_selectedFilter == 'Hot Intent') {
        matchesFilter = label.contains('Hot') || screen.contains('checkout') || screen.contains('payment');
      } else if (_selectedFilter == 'Warm Interest') {
        matchesFilter = label.contains('Warm') || screen.contains('cart') || screen.contains('product');
      } else if (_selectedFilter == 'Browsing') {
        matchesFilter = label.contains('Browsing') || screen.contains('home');
      }

      return matchesSearch && matchesFilter;
    }).toList();

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: EdgeInsets.all(isDesktop ? 24 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Enterprise Command Bar Header
          _buildHeaderCommandBar(isDesktop),
          const SizedBox(height: 20),

          // 2. High-Impact Real-time Intent KPI Cards
          _buildIntentKpiBar(hotCount, warmCount, browsingCount, widget.realTimeUsers.length, isDesktop),
          const SizedBox(height: 20),

          // 3. Search & Filter Tool Bar
          _buildFilterToolBar(isDesktop),
          const SizedBox(height: 16),

          // 4. Live Pulse Customer Cards Grid
          if (filteredUsers.isEmpty)
            _buildEmptyPulseState()
          else
            _buildPulseGrid(filteredUsers, isDesktop),
        ],
      ),
    );
  }

  Widget _buildHeaderCommandBar(bool isDesktop) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            FadeTransition(
              opacity: _pulseController,
              child: Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: Color(0xFF10B981),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFF10B981),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Live Customer Pulse Feed',
                  style: GoogleFonts.outfit(
                    fontSize: isDesktop ? 20 : 16,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  'Real-time customer presence, purchase intent, and live app action stream',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF10B981).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.bolt_rounded, size: 14, color: Color(0xFF10B981)),
                  const SizedBox(width: 4),
                  Text(
                    'WebSocket Syncing',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
            ),
            if (widget.onRefresh != null) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 20),
                onPressed: widget.onRefresh,
                tooltip: 'Refresh Pulse Feed',
                style: IconButton.styleFrom(
                  backgroundColor: AppTheme.backgroundColor,
                  foregroundColor: AppTheme.textPrimary,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildIntentKpiBar(
    int hot,
    int warm,
    int browsing,
    int total,
    bool isDesktop,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double spacing = 12.0;
        final int columns = isDesktop ? 4 : 2;
        final double cardWidth = (constraints.maxWidth - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            _buildKpiCard(
              title: 'Active Customers',
              value: '$total',
              subtitle: 'Live session connections',
              icon: Icons.sensors_rounded,
              color: AppTheme.primaryColor,
              width: cardWidth,
            ),
            _buildKpiCard(
              title: 'Hot Intent 🔥',
              value: '$hot',
              subtitle: 'On Checkout / Payment',
              icon: Icons.local_fire_department_rounded,
              color: Colors.redAccent,
              width: cardWidth,
            ),
            _buildKpiCard(
              title: 'Warm Interest ☀️',
              value: '$warm',
              subtitle: 'Cart & Product views',
              icon: Icons.wb_sunny_rounded,
              color: Colors.orange,
              width: cardWidth,
            ),
            _buildKpiCard(
              title: 'Browsing 🍃',
              value: '$browsing',
              subtitle: 'General App Navigation',
              icon: Icons.explore_outlined,
              color: Colors.blue,
              width: cardWidth,
            ),
          ],
        );
      },
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required double width,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    color: AppTheme.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterToolBar(bool isDesktop) {
    final filters = ['All', 'Hot Intent', 'Warm Interest', 'Browsing'];

    return Row(
      children: [
        Expanded(
          flex: isDesktop ? 2 : 1,
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppTheme.backgroundColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Row(
              children: [
                const Icon(Icons.search_rounded, size: 18, color: AppTheme.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: GoogleFonts.outfit(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Search active customer, phone, screen...',
                      hintStyle: GoogleFonts.outfit(fontSize: 13, color: AppTheme.textSecondary),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  GestureDetector(
                    onTap: () => setState(() => _searchQuery = ''),
                    child: const Icon(Icons.close_rounded, size: 16, color: AppTheme.textSecondary),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: filters.map((filter) {
              final isSelected = _selectedFilter == filter;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(
                    filter,
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? Colors.white : AppTheme.textPrimary,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: AppTheme.primaryColor,
                  backgroundColor: AppTheme.backgroundColor,
                  onSelected: (val) {
                    if (val) setState(() => _selectedFilter = filter);
                  },
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildPulseGrid(List<Map<String, dynamic>> users, bool isDesktop) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double spacing = 14.0;
        final int columns = isDesktop
            ? (constraints.maxWidth > 1200 ? 3 : 2)
            : 1;
        final double cardWidth = (constraints.maxWidth - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: users.map((user) {
            final displayName = (user['userName'] ?? user['user'] ?? 'New Customer').toString();
            final displayPhone = (user['userPhone'] ?? '').toString();
            final currentScreen = (user['currentScreen'] ?? 'Home').toString();
            final action = (user['action'] ?? 'Browsing').toString();
            final intentLabel = (user['intentLabel'] ?? 'Browsing 🍃').toString();
            final journeyPath = (user['journeyPath'] ?? '').toString();
            final relativeSeen = _getRelativeLastSeen(user['lastSeen'] ?? user['_localLastSeen']);

            final isHot = intentLabel.contains('Hot') || currentScreen.toLowerCase().contains('checkout');
            final isWarm = intentLabel.contains('Warm') || currentScreen.toLowerCase().contains('cart');

            final accentColor = isHot
                ? Colors.redAccent
                : isWarm
                    ? Colors.orange
                    : AppTheme.primaryColor;

            return MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () {
                  if (widget.onUserSelected != null) {
                    widget.onUserSelected!(displayName);
                  }
                },
                child: Container(
                  width: cardWidth,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.02),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.35),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.06),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Customer Top Bar
                      Row(
                        children: [
                          Stack(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: accentColor.withValues(alpha: 0.15),
                                child: Text(
                                  displayName.isNotEmpty ? displayName[0].toUpperCase() : 'C',
                                  style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: accentColor,
                                  ),
                                ),
                              ),
                              Positioned(
                                right: -1,
                                bottom: -1,
                                child: Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 1.5),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayName,
                                  style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (displayPhone.isNotEmpty && displayPhone != displayName)
                                  Text(
                                    displayPhone,
                                    style: GoogleFonts.outfit(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              intentLabel,
                              style: GoogleFonts.outfit(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                                color: accentColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Current Operational Location
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.backgroundColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              currentScreen.toLowerCase().contains('checkout')
                                  ? Icons.shopping_cart_checkout_rounded
                                  : currentScreen.toLowerCase().contains('cart')
                                      ? Icons.shopping_cart_outlined
                                      : Icons.screen_search_desktop_outlined,
                              size: 14,
                              color: accentColor,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '$currentScreen • $action',
                                style: GoogleFonts.outfit(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),

                      if (journeyPath.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.alt_route_rounded, size: 12, color: AppTheme.primaryColor),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Trail: $journeyPath',
                                style: GoogleFonts.outfit(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 12),
                      const Divider(height: 1, color: AppTheme.borderColor),
                      const SizedBox(height: 8),

                      // Quick Action Bar & Time
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              if (displayPhone.isNotEmpty) ...[
                                InkWell(
                                  onTap: () => _makePhoneCall(displayPhone),
                                  borderRadius: BorderRadius.circular(4),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.phone_rounded, size: 12, color: AppTheme.primaryColor),
                                        const SizedBox(width: 4),
                                        Text('Call', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                InkWell(
                                  onTap: () => _openWhatsApp(displayPhone, displayName),
                                  borderRadius: BorderRadius.circular(4),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981).withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.chat_rounded, size: 12, color: Color(0xFF10B981)),
                                        const SizedBox(width: 4),
                                        Text('WhatsApp', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF10B981))),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              relativeSeen,
                              style: GoogleFonts.outfit(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF10B981),
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
          }).toList(),
        );
      },
    );
  }

  Widget _buildEmptyPulseState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        children: [
          const Icon(Icons.sensors_off_rounded, size: 40, color: AppTheme.textSecondary),
          const SizedBox(height: 12),
          Text(
            'No Active Customers Match Filter',
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Scanning network for incoming live presence heartbeats and actions...',
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
