import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kd_pannel/app_theme.dart';
import 'package:kd_pannel/core/responsive/responsive.dart';
import 'package:kd_pannel/util/dealers.dart';

class DealerDetailsPage extends StatefulWidget {
  final Dealer dealer;

  const DealerDetailsPage({super.key, required this.dealer});

  @override
  State<DealerDetailsPage> createState() => _DealerDetailsPageState();
}

class _DealerDetailsPageState extends State<DealerDetailsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isStarred = false;
  int _selectedTabIndex = 0;

  // Derived display fields from the dealer model
  String get _dealerName => widget.dealer.name;
  String get _phone => widget.dealer.phone;
  String get _city => widget.dealer.city;
  String get _state => widget.dealer.state;
  String get _agent => widget.dealer.agent;
  String get _gstStatus => widget.dealer.gstStatus;
  int get _totalOrders => widget.dealer.totalOrders;
  String get _purchaseValue => widget.dealer.purchaseValue;

  // Derived info
  String get _role =>
      widget.dealer.isHighValue ? 'Platinum Distributor' : 'Authorized Dealer';
  String get _location => '${widget.dealer.city}, ${widget.dealer.state}';
  String get _level => widget.dealer.isHighValue ? 'Tier 1' : 'Tier 2';
  String get _email =>
      '${widget.dealer.name.toLowerCase().replaceAll(' ', '.')}@krishi.in';
  String get _gst =>
      '${widget.dealer.state == 'Maharashtra'
          ? '27'
          : widget.dealer.state == 'Gujarat'
          ? '24'
          : '23'}AABCD${widget.dealer.phone.replaceAll(RegExp(r'[^0-9]'), '').substring(0, 4)}Z1';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_selectedTabIndex != _tabController.index) {
        setState(() => _selectedTabIndex = _tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = Responsive.isDesktop(context);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── 1. Premium Hero Banner ──
          SliverToBoxAdapter(
            child: Stack(
              children: [
                // Background gradient
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF0A1F14), Color(0xFF134E2F)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  padding: EdgeInsets.fromLTRB(
                    isDesktop ? 28 : 20,
                    isDesktop ? 24 : 20,
                    isDesktop ? 28 : 20,
                    isDesktop ? 22 : 18,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Row: back button + avatar + name info
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Back button
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.12),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.25),
                                  width: 1,
                                ),
                              ),
                              child: const Icon(
                                Icons.arrow_back_ios_new_rounded,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          // Avatar circle
                          Container(
                            width: isDesktop ? 62 : 52,
                            height: isDesktop ? 62 : 52,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withOpacity(0.22),
                                  Colors.white.withOpacity(0.06),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              _dealerName[0].toUpperCase(),
                              style: GoogleFonts.outfit(
                                fontSize: isDesktop ? 28 : 22,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          // Name + badges + details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        _dealerName,
                                        style: GoogleFonts.outfit(
                                          fontSize: isDesktop ? 20 : 16,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                          height: 1.15,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    _buildHeroBadge(
                                      _gstStatus == 'Verified'
                                          ? 'VERIFIED'
                                          : _gstStatus.toUpperCase(),
                                      _gstStatus == 'Verified'
                                          ? const Color(0xFF10B981)
                                          : _gstStatus == 'Pending'
                                          ? const Color(0xFFF59E0B)
                                          : const Color(0xFFEF4444),
                                    ),
                                    if (widget.dealer.isHighValue) ...[
                                      const SizedBox(width: 4),
                                      _buildHeroBadge(
                                        '★ HIGH VALUE',
                                        const Color(0xFFF59E0B),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  _role,
                                  style: GoogleFonts.outfit(
                                    fontSize: isDesktop ? 11.5 : 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withOpacity(0.75),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.location_on_rounded,
                                      size: 11,
                                      color: Colors.white.withOpacity(0.5),
                                    ),
                                    const SizedBox(width: 3),
                                    Flexible(
                                      child: Text(
                                        _location,
                                        style: GoogleFonts.outfit(
                                          fontSize: isDesktop ? 11 : 10,
                                          color: Colors.white.withOpacity(0.5),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      // Quick-action pills
                      Row(
                        children: [
                          _buildQuickAction(
                            Icons.phone_rounded,
                            _phone,
                            const Color(0xFF10B981),
                          ),
                          const SizedBox(width: 8),
                          _buildQuickAction(
                            Icons.person_rounded,
                            _agent,
                            const Color(0xFF6366F1),
                          ),
                          const SizedBox(width: 8),
                          _buildQuickAction(
                            Icons.layers_rounded,
                            _level,
                            const Color(0xFF0EA5E9),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Decorative glowing orb
                Positioned(
                  right: -30,
                  top: -20,
                  child: IgnorePointer(
                    child: Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFF10B981).withOpacity(0.15),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── 2. KPI Metrics + Tab Content ──
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 28 : 16,
                vertical: 20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildKpiMetricsGrid(isDesktop),
                  const SizedBox(height: 24),

                  // Pill-style tab bar
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.borderColor),
                      boxShadow: AppTheme.softShadow,
                    ),
                    padding: const EdgeInsets.all(3),
                    child: TabBar(
                      controller: _tabController,
                      labelColor: Colors.white,
                      unselectedLabelColor: AppTheme.textSecondary,
                      indicator: BoxDecoration(
                        color: AppTheme.primaryColor,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      splashBorderRadius: BorderRadius.circular(9),
                      labelStyle: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      unselectedLabelStyle: GoogleFonts.outfit(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      tabs: const [
                        Tab(text: 'General Info'),
                        Tab(text: 'Active Orders'),
                        Tab(text: 'Live Logs'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Animated tab content
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.04),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: KeyedSubtree(
                      key: ValueKey(_selectedTabIndex),
                      child: _buildTabContent(isDesktop),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent(bool isDesktop) {
    switch (_selectedTabIndex) {
      case 0:
        return _buildGeneralInfo(isDesktop);
      case 1:
        return _buildActiveOrdersList();
      case 2:
        return _buildUserTelemetryLogs();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildHeroBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4), width: 0.8),
      ),
      child: Text(
        label,
        style: GoogleFonts.outfit(
          fontSize: 8,
          fontWeight: FontWeight.w900,
          color: color,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _buildQuickAction(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiMetricsGrid(bool isDesktop) {
    final List<Map<String, dynamic>> kpis = [
      {
        'title': 'Total Orders',
        'value': _totalOrders.toString(),
        'sub': 'Lifetime orders placed',
        'icon': Icons.shopping_bag_rounded,
        'color': AppTheme.primaryColor,
      },
      {
        'title': 'Purchase Value',
        'value': _purchaseValue,
        'sub': 'Cumulative spend',
        'icon': Icons.currency_rupee_rounded,
        'color': AppTheme.success,
      },
      {
        'title': 'Dealer Tier',
        'value': _level,
        'sub': widget.dealer.isHighValue ? 'High Value Account' : 'Standard',
        'icon': Icons.workspace_premium_rounded,
        'color': widget.dealer.isHighValue
            ? const Color(0xFFF59E0B)
            : AppTheme.info,
      },
    ];

    final double spacing = isDesktop ? 14 : 10;

    if (isDesktop) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final double cardWidth =
              (constraints.maxWidth - spacing * 2) / kpis.length;
          return Row(
            children: kpis.asMap().entries.map((e) {
              final kpi = e.value;
              final color = kpi['color'] as Color;
              return Container(
                width: cardWidth,
                margin: EdgeInsets.only(
                  right: e.key < kpis.length - 1 ? spacing : 0,
                ),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.cardColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppTheme.borderColor.withOpacity(0.7),
                  ),
                  boxShadow: AppTheme.cardShadow,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        kpi['icon'] as IconData,
                        size: 18,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            kpi['title'] as String,
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textSecondary,
                              letterSpacing: 0.3,
                            ),
                          ),
                          Text(
                            kpi['value'] as String,
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.textPrimary,
                              height: 1.2,
                            ),
                          ),
                          Text(
                            kpi['sub'] as String,
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          );
        },
      );
    }

    return Column(
      children: kpis.map((kpi) {
        final color = kpi['color'] as Color;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderColor.withOpacity(0.7)),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(kpi['icon'] as IconData, size: 16, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      kpi['title'] as String,
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    Text(
                      kpi['value'] as String,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildGeneralInfo(bool isDesktop) {
    final List<Map<String, dynamic>> fields = [
      {
        'label': 'Registered Email',
        'value': _email,
        'icon': Icons.email_outlined,
      },
      {'label': 'Contact Phone', 'value': _phone, 'icon': Icons.phone_outlined},
      {'label': 'City', 'value': _city, 'icon': Icons.location_city_outlined},
      {'label': 'State', 'value': _state, 'icon': Icons.map_outlined},
      {'label': 'GSTIN', 'value': _gst, 'icon': Icons.receipt_long_outlined},
      {
        'label': 'GST Status',
        'value': _gstStatus,
        'icon': Icons.verified_outlined,
        'isStatus': true,
      },
      {
        'label': 'Assigned Agent',
        'value': _agent,
        'icon': Icons.person_outline_rounded,
      },
      {
        'label': 'Distribution Tier',
        'value': _level,
        'icon': Icons.layers_outlined,
      },
      {
        'label': 'Account Type',
        'value': _role,
        'icon': Icons.business_outlined,
      },
      {
        'label': 'High Value',
        'value': widget.dealer.isHighValue ? 'Yes' : 'No',
        'icon': Icons.star_outline_rounded,
      },
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.7)),
        boxShadow: AppTheme.cardShadow,
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.business_center_rounded,
                  size: 16,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Business Profile Overview',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Grid of info fields
          LayoutBuilder(
            builder: (context, constraints) {
              final int columns = isDesktop ? 2 : 1;
              final double itemWidth =
                  (constraints.maxWidth - (columns > 1 ? 20 : 0)) / columns;
              return Wrap(
                spacing: 20,
                runSpacing: 0,
                children: fields.map((f) {
                  final isStatus = f['isStatus'] == true;
                  Color statusColor = AppTheme.textPrimary;
                  if (isStatus) {
                    statusColor = f['value'] == 'Verified'
                        ? AppTheme.success
                        : f['value'] == 'Pending'
                        ? AppTheme.warning
                        : AppTheme.error;
                  }

                  return SizedBox(
                    width: itemWidth,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                f['icon'] as IconData,
                                size: 13,
                                color: AppTheme.textSecondary,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                f['label'] as String,
                                style: GoogleFonts.outfit(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textSecondary,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          if (isStatus)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: statusColor.withOpacity(0.25),
                                ),
                              ),
                              child: Text(
                                f['value'] as String,
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: statusColor,
                                ),
                              ),
                            )
                          else
                            Text(
                              f['value'] as String,
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          const SizedBox(height: 10),
                          const Divider(
                            height: 1,
                            color: AppTheme.lightBorderColor,
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActiveOrdersList() {
    // Generate order data based on totalOrders count
    final orders = [
      {
        'id': 'ORD-${900000 + (_totalOrders * 47) % 99999}',
        'items': 'Drip Irrigation Kit x2 • Seed Pack x3',
        'status': 'Processing',
        'value': '₹7,900',
        'date': '2 Jun 2026',
        'color': AppTheme.warning,
      },
      {
        'id': 'ORD-${800000 + (_totalOrders * 31) % 99999}',
        'items': 'Water Pump 5HP x1 • Fertilizer 50kg x5',
        'status': 'Completed',
        'value': '₹11,500',
        'date': '28 May 2026',
        'color': AppTheme.success,
      },
      {
        'id': 'ORD-${700000 + (_totalOrders * 13) % 99999}',
        'items': 'Pesticide Kit x4',
        'status': 'Delivered',
        'value': '₹3,200',
        'date': '20 May 2026',
        'color': AppTheme.success,
      },
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.7)),
        boxShadow: AppTheme.cardShadow,
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.receipt_long_rounded,
                      size: 16,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Order Ledger',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$_totalOrders total',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: orders.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final o = orders[index];
              final statusColor = o['color'] as Color;
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundColor.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppTheme.borderColor.withOpacity(0.5),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                o['id'] as String,
                                style: GoogleFonts.outfit(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(
                                    color: statusColor.withOpacity(0.2),
                                  ),
                                ),
                                child: Text(
                                  o['status'] as String,
                                  style: GoogleFonts.outfit(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: statusColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            o['items'] as String,
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            o['date'] as String,
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              color: AppTheme.textSecondary.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      o['value'] as String,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildUserTelemetryLogs() {
    final List<Map<String, dynamic>> logs = [
      {
        'event': 'Login Success',
        'details': 'Android 14 · IP: 157.45.12.8',
        'time': 'Just now',
        'icon': Icons.login_rounded,
        'color': AppTheme.success,
      },
      {
        'event': 'Order Placed',
        'details': 'ORD-${(900000 + _totalOrders * 47) % 999999} · ₹7,900',
        'time': '5 mins ago',
        'icon': Icons.shopping_cart_checkout_rounded,
        'color': AppTheme.primaryColor,
      },
      {
        'event': 'Payment Success',
        'details':
            'TXN-${_phone.replaceAll(RegExp(r'[^0-9]'), '').substring(5)} · UPI',
        'time': '8 mins ago',
        'icon': Icons.check_circle_outline_rounded,
        'color': const Color(0xFF10B981),
      },
      {
        'event': 'Coupon Applied',
        'details': 'MONSOON10 · Saved ₹2,250',
        'time': '10 mins ago',
        'icon': Icons.local_offer_outlined,
        'color': const Color(0xFF6366F1),
      },
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.7)),
        boxShadow: AppTheme.cardShadow,
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.timeline_rounded,
                  size: 16,
                  color: Color(0xFF6366F1),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Session Events & Telemetry',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final log = logs[index];
              final color = log['color'] as Color;
              final isLast = index == logs.length - 1;
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Timeline column
                    SizedBox(
                      width: 28,
                      child: Column(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              log['icon'] as IconData,
                              size: 13,
                              color: color,
                            ),
                          ),
                          if (!isLast)
                            Expanded(
                              child: Container(
                                width: 1.5,
                                color: AppTheme.borderColor,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Content
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  log['event'] as String,
                                  style: GoogleFonts.outfit(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                Text(
                                  log['time'] as String,
                                  style: GoogleFonts.outfit(
                                    fontSize: 10,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              log['details'] as String,
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
