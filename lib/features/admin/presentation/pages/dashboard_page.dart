import 'dart:async';
import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kd_pannel/app_theme.dart';
import 'package:kd_pannel/core/responsive/responsive.dart';
import 'package:kd_pannel/core/services/dashboard_service.dart';
import 'package:kd_pannel/features/shared/widgets/stat_card_widget.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String selectedDropdown = 'This Month';
  PickerDateRange? _selectedRange;

  // Modern dashboard state variables
  String activeTimeframe = '1M'; // '1W', '1M', '3M'
  int? hoveredChartIndex;
  int _hoveredPipelineIndex =
      -1; // Synchronized hover state between donut and legend!
  int activeTableTab =
      0; // 0: Recent Orders, 1: Recent Leads, 2: Active Dealers
  bool isExporting = false;

  // Clock and Scroll state variables
  Timer? _clockTimer;
  String _timeString = '';
  String _dateString = '';
  final ScrollController _scrollController = ScrollController();

  // Dynamic getters for administrative operational stats
  int get pendingOrdersCount =>
      _ordersData.where((order) => order['status'] == 'Pending').length;
  int get verifiedDealersCount =>
      _dealersData.where((dealer) => dealer['gst'] == 'Verified').length;

  // Cached futures to prevent visual shifting during hover/rebuild states
  late Future<String> _totalSalesFuture;
  late Future<String> _totalOrdersFuture;
  late Future<String> _totalDealersFuture;
  late Future<String> _totalLeadsFuture;

  @override
  void initState() {
    super.initState();
    _refreshData();
    _updateClock(shouldSetState: false);
    _clockTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      _updateClock(shouldSetState: true);
    });
  }

  void _updateClock({bool shouldSetState = true}) {
    final now = DateTime.now();
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');

    final weekdays = [
      'Sunday',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
    ];
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    final timeStr = '$hour:$minute';
    final dateStr =
        '${weekdays[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}';

    if (shouldSetState && mounted) {
      setState(() {
        _timeString = timeStr;
        _dateString = dateStr;
      });
    } else {
      _timeString = timeStr;
      _dateString = dateStr;
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Pre-cache logo and admin avatar to prevent empty frame renders on direct reload or hot restart
    precacheImage(const AssetImage('assets/images/logo.png'), context);
    precacheImage(const AssetImage('assets/images/admin.png'), context);
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToTerminalAndSwitchTab(int tabIndex) {
    setState(() {
      activeTableTab = tabIndex;
    });
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        480.0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _scrollToPosition(double offset) {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  /// Refreshes all stat card data based on the active filter period.
  /// Called on initState and whenever the dropdown or date range changes.
  void _refreshData() {
    final service = DashboardService();
    // In a real app, pass [selectedDropdown] to each service call
    // so the backend returns period-specific values.
    _totalSalesFuture = service.getTotalSales(period: selectedDropdown);
    _totalOrdersFuture = service.getTotalOrders(period: selectedDropdown);
    _totalDealersFuture = service.getTotalDealers(period: selectedDropdown);
    _totalLeadsFuture = service.getTotalLeads(period: selectedDropdown);
  }

  final List<String> dropdownOptions = [
    'Last 1 Week',
    'Last 2 Weeks',
    'Last 3 Weeks',
    'Last 1 Month',
    'Last 3 Months',
    'Last 6 Months',
    'This Month',
  ];

  // Mock data for trends based on timeframe
  List<double> _getSalesData() {
    switch (activeTimeframe) {
      case '1W':
        return [1200.0, 1500.0, 1100.0, 1800.0, 2200.0, 1900.0, 2450.0];
      case '3M':
        return [1800.0, 2200.0, 2450.0];
      case '1M':
      default:
        return [800.0, 1600.0, 2100.0, 2450.0];
    }
  }

  List<double> _getLeadsData() {
    switch (activeTimeframe) {
      case '1W':
        return [800.0, 1100.0, 950.0, 1300.0, 1600.0, 1400.0, 1850.0];
      case '3M':
        return [1400.0, 1800.0, 1950.0];
      case '1M':
      default:
        return [600.0, 1200.0, 1700.0, 1950.0];
    }
  }

  List<String> _getLabels() {
    switch (activeTimeframe) {
      case '1W':
        return ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      case '3M':
        return ['Mar', 'Apr', 'May'];
      case '1M':
      default:
        return ['Week 1', 'Week 2', 'Week 3', 'Week 4'];
    }
  }

  String get _rangeDisplay {
    if (_selectedRange != null &&
        _selectedRange!.startDate != null &&
        _selectedRange!.endDate != null) {
      final start = _selectedRange!.startDate!;
      final end = _selectedRange!.endDate!;
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${start.day.toString().padLeft(2, '0')} ${months[start.month - 1]} - ${end.day.toString().padLeft(2, '0')} ${months[end.month - 1]}';
    }
    return selectedDropdown;
  }

  void _showSyncfusionDatePicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        content: SizedBox(
          height: 400,
          width: 350,
          child: SfDateRangePicker(
            backgroundColor: Colors.white,
            selectionMode: DateRangePickerSelectionMode.range,
            showActionButtons: true,
            confirmText: 'Apply',
            cancelText: 'Cancel',
            selectionShape: DateRangePickerSelectionShape.rectangle,
            rangeSelectionColor: AppTheme.primaryColor.withOpacity(0.12),
            startRangeSelectionColor: AppTheme.primaryColor,
            endRangeSelectionColor: AppTheme.primaryColor,
            initialSelectedRange: _selectedRange,
            onSubmit: (Object? val) {
              if (val is PickerDateRange &&
                  val.startDate != null &&
                  val.endDate != null) {
                setState(() {
                  _selectedRange = val;
                  selectedDropdown = ''; // Calendar overrides dropdown text
                });
                Navigator.pop(context);
              }
            },
            onCancel: () => Navigator.pop(context),
          ),
        ),
      ),
    );
  }

  void _showNotificationBroadcastDialog() {
    showDialog(
      context: context,
      builder: (context) => const _AnnouncementDialog(),
    );
  }

  void _triggerExport() async {
    setState(() => isExporting = true);

    // Simulate export background service
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      setState(() => isExporting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.info,
          behavior: SnackBarBehavior.floating,
          content: Row(
            children: [
              const Icon(Icons.download, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                'Sales & Dealer Reports exported successfully to CSV!',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = Responsive.isDesktop(context);
    final double gap = isDesktop ? 20.0 : 14.0;

    return SingleChildScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 28 : 16,
        vertical: isDesktop ? 20 : 12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Sleek Modern Welcome Header Card
          _buildWelcomeHeader(isDesktop),
          SizedBox(height: gap),

          // 2. Custom Elite Visual Stats Grid
          _buildVisualStatsGrid(isDesktop),
          SizedBox(height: gap),

          // 3. Interactive Operations Terminal in Full Width
          _buildInteractiveOperationsTable(),
          SizedBox(height: gap),

          // 4. Graphical Analytics Layer
          if (MediaQuery.of(context).size.width >= 850)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: _buildInteractiveBezierTrendCard()),
                const SizedBox(width: 20),
                Expanded(flex: 2, child: _buildLeadPipelineBreakdownCard()),
              ],
            )
          else
            Column(
              children: [
                _buildInteractiveBezierTrendCard(),
                SizedBox(height: gap),
                _buildLeadPipelineBreakdownCard(),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildWelcomeHeader(bool isDesktop) {
    final bool isMobile = Responsive.isMobile(context);
    final String greeting = _getGreeting();

    // Left-side column of content
    final infoColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Pulsing system status badge
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 10 : 8,
            vertical: isDesktop ? 4 : 2.5,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withOpacity(0.15)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const LivePulsingBadge(color: Colors.greenAccent),
              const SizedBox(width: 4),
              Text(
                'LOGISTICS HUB • MADHYA PRADESH',
                style: GoogleFonts.outfit(
                  fontSize: isDesktop ? 9 : 8,
                  fontWeight: FontWeight.w800,
                  color: Colors.white.withOpacity(0.9),
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: isDesktop ? 12 : 8),
        Row(
          children: [
            Text(
              '$greeting, Admin',
              style: GoogleFonts.outfit(
                fontSize: isDesktop ? 26 : 18,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                height: 1.1,
              ),
            ),
            const SizedBox(width: 8),
            WelcomeAnimation(size: isDesktop ? 24 : 16),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          isDesktop
              ? 'Here is what\'s happening on the KrishiDealer platform today.'
              : 'Real-time operations summary.',
          style: GoogleFonts.outfit(
            fontSize: isDesktop ? 13 : 10.5,
            color: Colors.white.withOpacity(0.75),
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: isDesktop ? 16 : 8),
        // Live administrative operational stats (desktop/tablet only)
        if (!isMobile) ...[
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildSystemPill(
                icon: Icons.check_circle_outline,
                label: 'Fulfillment',
                value: '85% Success',
                statusColor: Colors.greenAccent,
                onTap: () => _scrollToTerminalAndSwitchTab(0), // Orders tab
              ),
              _buildSystemPill(
                icon: Icons.track_changes_outlined,
                label: 'Target',
                value: '74% Achieved',
                statusColor: Colors.cyanAccent,
                onTap: () =>
                    _scrollToPosition(820.0), // Focuses graphical trends card
              ),
              _buildSystemPill(
                icon: Icons.speed_outlined,
                label: 'Processing',
                value: '4.2 Hours',
                statusColor: Colors.orangeAccent,
                onTap: () =>
                    _scrollToPosition(820.0), // Focuses metrics pipeline
              ),
            ],
          ),
        ],
      ],
    );

    // Right-side dynamic clock, date, and filters
    final filterAndClockColumn = Column(
      crossAxisAlignment: isMobile
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Digital Clock and dynamic date
        Column(
          crossAxisAlignment: isMobile
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.end,
          children: [
            Text(
              _timeString,
              style: GoogleFonts.outfit(
                fontSize: isDesktop ? 32 : 24,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
            Text(
              _dateString,
              style: GoogleFonts.outfit(
                fontSize: isDesktop ? 12 : 11,
                color: Colors.white.withOpacity(0.8),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        if (!isMobile) const SizedBox(height: 20),
        // Glassmorphic Filter Row
        _buildFilterRow(true),
      ],
    );

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0F2E1E), // Deep Forest Emerald
            AppTheme.primaryColor, // Official Green
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusXLarge),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.18),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Futuristic tech-grid & glowing orb painter background overlay
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: WelcomeHeaderBackgroundPainter(
                  primaryColor: AppTheme.primaryColor,
                  accentColor: AppTheme.accentColor,
                ),
              ),
            ),
          ),

          // Actual interactive layout
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 24 : 16,
              vertical: isDesktop ? 20 : 12,
            ),
            child: isMobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _timeString,
                                  style: GoogleFonts.outfit(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  _dateString,
                                  style: GoogleFonts.outfit(
                                    fontSize: 10.5,
                                    color: Colors.white.withOpacity(0.8),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _buildFilterRow(true),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Divider(color: Colors.white12, height: 1),
                      const SizedBox(height: 10),
                      infoColumn,
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 8, child: infoColumn),
                      const SizedBox(width: 24),
                      Expanded(flex: 3, child: filterAndClockColumn),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemPill({
    required IconData icon,
    required String label,
    required String value,
    required Color statusColor,
    VoidCallback? onTap,
  }) {
    return MouseRegion(
      cursor: onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, size: 12, color: Colors.white.withOpacity(0.8)),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(
                  top: 1.0,
                ), // Optical baseline center adjustment for label
                child: Text(
                  '$label: ',
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withOpacity(0.6),
                    height: 1.1,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(
                  top: 1.5,
                ), // Optical baseline center adjustment
                child: SizedBox(
                  width: 8,
                  height: 8,
                  child: Center(
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: statusColor.withOpacity(0.4),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 5),
              Padding(
                padding: const EdgeInsets.only(
                  top: 1.0,
                ), // Optical baseline center adjustment for value
                child: Text(
                  value,
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterRow([bool isDarkBackground = false]) {
    final bool isMobile = Responsive.isMobile(context);

    final containerBg = isDarkBackground
        ? Colors.white.withOpacity(0.08)
        : AppTheme.backgroundColor;
    final borderColor = isDarkBackground
        ? Colors.white.withOpacity(0.12)
        : AppTheme.borderColor;
    final iconColor = isDarkBackground ? Colors.white : AppTheme.textSecondary;
    final textColor = isDarkBackground ? Colors.white : AppTheme.textBody;
    final dividerColor = isDarkBackground
        ? Colors.white.withOpacity(0.15)
        : AppTheme.borderColor;

    return Container(
      height: isMobile ? 38 : 46,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 14),
      decoration: BoxDecoration(
        color: containerBg,
        borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: InkWell(
              onTap: _showSyncfusionDatePicker,
              child: Icon(
                Icons.calendar_month_outlined,
                size: isMobile ? 16 : 18,
                color: iconColor,
              ),
            ),
          ),
          VerticalDivider(
            indent: isMobile ? 8 : 10,
            endIndent: isMobile ? 8 : 10,
            width: isMobile ? 12 : 20,
            color: dividerColor,
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              dropdownColor: isDarkBackground
                  ? const Color(0xFF0F2E1E)
                  : Colors.white,
              value: dropdownOptions.contains(selectedDropdown)
                  ? selectedDropdown
                  : null,
              isExpanded: false,
              hint: Text(
                _rangeDisplay,
                style: GoogleFonts.outfit(
                  fontSize: isMobile ? 11 : 12,
                  color: textColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              icon: Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Icon(
                  Icons.keyboard_arrow_down,
                  size: isMobile ? 14 : 16,
                  color: iconColor,
                ),
              ),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    selectedDropdown = newValue;
                    _selectedRange = null;
                    _refreshData(); // 🔄 Re-fetch stats for new period
                  });
                }
              },
              items: dropdownOptions.map<DropdownMenuItem<String>>((
                String value,
              ) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(
                    value,
                    style: GoogleFonts.outfit(
                      fontSize: isMobile ? 11 : 12,
                      color: isDarkBackground
                          ? Colors.white
                          : AppTheme.textPrimary,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisualStatsGrid(bool isDesktop) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double spacing = isDesktop ? 16.0 : 12.0;
        int columns = 4;
        if (constraints.maxWidth < 600) {
          columns = 1;
        } else if (constraints.maxWidth < 1150) {
          columns = 2;
        } else {
          columns = 4;
        }
        final double width =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            // 1. Total Sales Card
            FutureBuilder<String>(
              future: _totalSalesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return StatCardShimmer(isCompact: true, width: width);
                }
                return _buildAdvancedStatCard(
                  width: width,
                  title: 'Total Sales',
                  value: snapshot.data ?? '₹0',
                  color: AppTheme.success,
                  trendLabel: '+12.4% vs last month',
                  trendIcon: Icons.trending_up,
                  visualWidget: SizedBox(
                    width: 50,
                    height: 24,
                    child: CustomPaint(
                      painter: SparklinePainter([
                        10,
                        18,
                        12,
                        28,
                        20,
                        36,
                        40,
                      ], AppTheme.success),
                    ),
                  ),
                );
              },
            ),

            // 2. Total Orders Card
            FutureBuilder<String>(
              future: _totalOrdersFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return StatCardShimmer(isCompact: true, width: width);
                }
                return _buildAdvancedStatCard(
                  width: width,
                  title: 'Total Orders',
                  value: snapshot.data ?? '0',
                  color: AppTheme.lightGreen,
                  trendLabel: '85% Fulfilled',
                  trendIcon: Icons.check_circle_outline,
                  visualWidget: SizedBox(
                    width: 28,
                    height: 28,
                    child: CustomPaint(
                      painter: FulfillmentProgressPainter(
                        0.85,
                        AppTheme.lightGreen,
                      ),
                    ),
                  ),
                );
              },
            ),

            // 3. Total Dealers Card
            FutureBuilder<String>(
              future: _totalDealersFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return StatCardShimmer(isCompact: true, width: width);
                }
                return _buildAdvancedStatCard(
                  width: width,
                  title: 'Total Dealers',
                  value: snapshot.data ?? '0',
                  color: AppTheme.info,
                  trendLabel: '+42 new this week',
                  trendIcon: Icons.trending_up,
                  visualWidget: _buildAvatarCluster(),
                );
              },
            ),

            // 4. Total Leads Card
            FutureBuilder<String>(
              future: _totalLeadsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return StatCardShimmer(isCompact: true, width: width);
                }
                return _buildAdvancedStatCard(
                  width: width,
                  title: 'Total Leads',
                  value: snapshot.data ?? '0',
                  color: AppTheme.warning,
                  trendLabel: '5 high priority',
                  trendIcon: Icons.warning_amber_rounded,
                  visualWidget: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const LivePulsingBadge(),
                      const SizedBox(width: 5),
                      Text(
                        'Live',
                        style: GoogleFonts.outfit(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.warning,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildAdvancedStatCard({
    required double width,
    required String title,
    required String value,
    required Color color,
    required String trendLabel,
    required IconData trendIcon,
    required Widget visualWidget,
  }) {
    return Container(
      width: width,
      height: 96,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium + 2),
        boxShadow: AppTheme.cardShadow,
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 11.5,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(trendIcon, size: 10, color: color),
                      const SizedBox(width: 3),
                      Text(
                        trendLabel,
                        style: GoogleFonts.outfit(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          visualWidget,
        ],
      ),
    );
  }

  Widget _buildAvatarCluster() {
    return SizedBox(
      width: 72,
      height: 24,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            child: _buildAvatarCircle('KA', AppTheme.primaryColor),
          ),
          Positioned(
            left: 15,
            child: _buildAvatarCircle('GS', AppTheme.accentColor),
          ),
          Positioned(left: 30, child: _buildAvatarCircle('PA', AppTheme.info)),
          Positioned(
            left: 45,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: AppTheme.textSecondary.withOpacity(0.12),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              alignment: Alignment.center,
              child: Text(
                '+8',
                style: GoogleFonts.outfit(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textBody,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarCircle(String text, Color color) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
        gradient: LinearGradient(
          colors: [color.withOpacity(0.25), color.withOpacity(0.08)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: GoogleFonts.outfit(
          fontSize: 8.5,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }

  Widget _buildInteractiveBezierTrendCard() {
    final salesData = _getSalesData();
    final leadsData = _getLeadsData();
    final labels = _getLabels();

    final double maxVal = [
      ...salesData,
      ...leadsData,
    ].reduce((a, b) => a > b ? a : b);
    final double maxY = maxVal == 0 ? 1.0 : maxVal * 1.15;

    return Container(
      height: 350,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusXLarge),
        boxShadow: AppTheme.cardShadow,
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Revenue & Pipeline Trend',
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Interactive visualization of active conversion channels',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _buildTimeframeTabs(),
            ],
          ),
          const SizedBox(height: 25),
          Expanded(
            child: RepaintBoundary(
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: AppTheme.borderColor.withOpacity(0.35),
                      strokeWidth: 0.8,
                      dashArray: [5, 4],
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 38,
                        getTitlesWidget: (value, meta) {
                          if (value == meta.max || value == meta.min)
                            return const SizedBox.shrink();
                          final String valString = value >= 1000
                              ? '₹${(value / 1000).toStringAsFixed(1)}k'
                              : '₹${value.toStringAsFixed(0)}';
                          return Text(
                            valString,
                            style: GoogleFonts.outfit(
                              color: AppTheme.textSecondary,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        interval: 1.0,
                        getTitlesWidget: (value, meta) {
                          final int index = value.toInt();
                          if (index >= 0 && index < labels.length) {
                            return SideTitleWidget(
                              meta: meta,
                              space: 10,
                              child: Text(
                                labels[index],
                                style: GoogleFonts.outfit(
                                  color: AppTheme.textSecondary,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  minX: 0,
                  maxX: (salesData.length - 1).toDouble(),
                  minY: 0,
                  maxY: maxY,
                  lineTouchData: LineTouchData(
                    handleBuiltInTouches: true,
                    getTouchedSpotIndicator:
                        (LineChartBarData barData, List<int> spotIndexes) {
                          return spotIndexes.map((spotIndex) {
                            return TouchedSpotIndicatorData(
                              FlLine(
                                color: AppTheme.textSecondary.withOpacity(0.15),
                                strokeWidth: 2.0,
                              ),
                              FlDotData(
                                show: true,
                                getDotPainter: (spot, percent, barData, index) {
                                  return FlDotCirclePainter(
                                    radius: 6.0,
                                    color: Colors.white,
                                    strokeWidth: 3.0,
                                    strokeColor:
                                        barData.color ?? AppTheme.primaryColor,
                                  );
                                },
                              ),
                            );
                          }).toList();
                        },
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (touchedSpot) => AppTheme.cardColor,
                      tooltipBorder: BorderSide(
                        color: AppTheme.borderColor.withOpacity(0.8),
                        width: 0.8,
                      ),
                      tooltipPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      tooltipBorderRadius: BorderRadius.circular(8),
                      fitInsideHorizontally: true,
                      fitInsideVertically: true,
                      getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                        return touchedBarSpots.map((barSpot) {
                          final String bullet = '● ';
                          final String prefix = barSpot.barIndex == 0
                              ? 'Revenue: ₹'
                              : 'Leads: ';
                          return LineTooltipItem(
                            '$bullet$prefix${barSpot.y.toInt()}',
                            GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: barSpot.barIndex == 0
                                  ? AppTheme.primaryColor
                                  : AppTheme.accentColor,
                            ),
                          );
                        }).toList();
                      },
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: List.generate(
                        salesData.length,
                        (i) => FlSpot(i.toDouble(), salesData[i]),
                      ),
                      isCurved: true,
                      color: AppTheme.primaryColor,
                      barWidth: 3.0,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primaryColor.withOpacity(0.18),
                            AppTheme.primaryColor.withOpacity(0.0),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                    LineChartBarData(
                      spots: List.generate(
                        leadsData.length,
                        (i) => FlSpot(i.toDouble(), leadsData[i]),
                      ),
                      isCurved: true,
                      color: AppTheme.accentColor,
                      barWidth: 3.0,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.accentColor.withOpacity(0.15),
                            AppTheme.accentColor.withOpacity(0.0),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ],
                ),
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeInOutCubic,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildChartLegendIndicator('Revenue', AppTheme.primaryColor),
              const SizedBox(width: 24),
              _buildChartLegendIndicator(
                'Leads Generated',
                AppTheme.accentColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChartLegendIndicator(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppTheme.textBody,
          ),
        ),
      ],
    );
  }

  Widget _buildTimeframeTabs() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderColor),
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        children: ['1W', '1M', '3M'].map((t) {
          final isSelected = activeTimeframe == t;
          return MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  activeTimeframe = t;
                  hoveredChartIndex = null;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.cardColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 4,
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  t,
                  style: GoogleFonts.outfit(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: isSelected
                        ? AppTheme.primaryColor
                        : AppTheme.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLeadPipelineBreakdownCard() {
    // 24 total: 10 assigned, 10 unassigned, 4 pending
    final double assigned = 10;
    final double unassigned = 10;
    final double pending = 4;

    return Container(
      padding: const EdgeInsets.all(20),
      height: 350,
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusXLarge),
        boxShadow: AppTheme.cardShadow,
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Lead Pipeline Breakdown',
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Pipeline efficiency analysis',
            style: GoogleFonts.outfit(
              fontSize: 11,
              color: AppTheme.textSecondary,
            ),
          ),
          const Spacer(),
          Center(
            child: AnimatedDonutChart(
              values: [assigned, unassigned, pending],
              colors: [AppTheme.info, AppTheme.success, AppTheme.warning],
              labels: const ['Assigned', 'Unassigned', 'Pending'],
              hoveredIndex: _hoveredPipelineIndex,
              onHoverChanged: (idx) {
                if (idx != _hoveredPipelineIndex) {
                  setState(() {
                    _hoveredPipelineIndex = idx;
                  });
                }
              },
            ),
          ),
          const Spacer(),
          Column(
            children: [
              _buildPipelineLegendRow(
                0,
                'Assigned Leads',
                '10 (42%)',
                AppTheme.info,
              ),
              const SizedBox(height: 8),
              _buildPipelineLegendRow(
                1,
                'Unassigned Leads',
                '10 (42%)',
                AppTheme.success,
              ),
              const SizedBox(height: 8),
              _buildPipelineLegendRow(
                2,
                'KYC Pending',
                '4 (16%)',
                AppTheme.warning,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPipelineLegendRow(
    int index,
    String label,
    String value,
    Color color,
  ) {
    final isHovered = _hoveredPipelineIndex == index;

    return MouseRegion(
      onEnter: (_) {
        if (_hoveredPipelineIndex != index) {
          setState(() {
            _hoveredPipelineIndex = index;
          });
        }
      },
      onExit: (_) {
        if (_hoveredPipelineIndex == index) {
          setState(() {
            _hoveredPipelineIndex = -1;
          });
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isHovered ? color.withOpacity(0.06) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isHovered ? color.withOpacity(0.15) : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: isHovered ? 12 : 8,
                  height: isHovered ? 12 : 8,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isHovered ? color : AppTheme.textBody,
                  ),
                  child: Text(label),
                ),
              ],
            ),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isHovered ? color : AppTheme.textPrimary,
              ),
              child: Text(value),
            ),
          ],
        ),
      ),
    );
  }

  // ── Operations Terminal ────────────────────────────────────────────────────

  // Each tab's data schema: {columns, rows where each row is a map}
  static const List<Map<String, dynamic>> _ordersData = [
    {
      'dealer': 'King Agro',
      'product': 'Drip Irrigation Kit',
      'amount': '₹2,400',
      'date': '18 May 2025',
      'status': 'Completed',
      'agent': 'Vijay D.',
    },
    {
      'dealer': 'Gupta Seeds',
      'product': 'Hybrid Seed Pack',
      'amount': '₹650',
      'date': '18 May 2025',
      'status': 'Pending',
      'agent': 'Rajesh K.',
    },
    {
      'dealer': 'Patel Agro',
      'product': 'Water Pump 5HP',
      'amount': '₹1,150',
      'date': '17 May 2025',
      'status': 'Completed',
      'agent': 'Suresh P.',
    },
    {
      'dealer': 'Shiva Enterprises',
      'product': 'Fertilizer Blend X',
      'amount': '₹980',
      'date': '17 May 2025',
      'status': 'Pending',
      'agent': 'Nirmal R.',
    },
    {
      'dealer': 'Greenway Agro',
      'product': 'Micro Sprinkler Set',
      'amount': '₹3,200',
      'date': '16 May 2025',
      'status': 'Completed',
      'agent': 'Priya S.',
    },
  ];

  static const List<Map<String, dynamic>> _leadsData = [
    {
      'dealer': 'Choudhary Krishi',
      'contact': 'Nirmal Choudhary',
      'phone': '+91 98765 43210',
      'state': 'Rajasthan',
      'created': '2h ago',
      'status': 'Completed',
    },
    {
      'dealer': 'Greenway Agro',
      'contact': 'Priya Sharma',
      'phone': '+91 87654 32109',
      'state': 'Gujarat',
      'created': '5h ago',
      'status': 'Pending',
    },
    {
      'dealer': 'Shiva Enterprises',
      'contact': 'Ravi Kumar',
      'phone': '+91 76543 21098',
      'state': 'UP',
      'created': '3d ago',
      'status': 'Completed',
    },
    {
      'dealer': 'AgroVision Ltd.',
      'contact': 'Sunita Patel',
      'phone': '+91 65432 10987',
      'state': 'MP',
      'created': '1d ago',
      'status': 'Pending',
    },
    {
      'dealer': 'Krishi Bazaar',
      'contact': 'Anil Verma',
      'phone': '+91 54321 09876',
      'state': 'Maharashtra',
      'created': '4h ago',
      'status': 'Pending',
    },
  ];

  static const List<Map<String, dynamic>> _dealersData = [
    {
      'dealer': 'King Agro',
      'state': 'Maharashtra',
      'agent': 'Vijay Deshmukh',
      'gst': 'Verified',
      'orders': '14',
      'revenue': '₹28,400',
    },
    {
      'dealer': 'Gupta Seeds',
      'state': 'Gujarat',
      'agent': 'Rajesh Kumar',
      'gst': 'Verified',
      'orders': '9',
      'revenue': '₹15,200',
    },
    {
      'dealer': 'Patel Agro',
      'state': 'Madhya Pradesh',
      'agent': 'Suresh Patil',
      'gst': 'Verified',
      'orders': '6',
      'revenue': '₹9,800',
    },
    {
      'dealer': 'AgroVision Ltd.',
      'state': 'Rajasthan',
      'agent': 'Nirmal Rathore',
      'gst': 'Pending',
      'orders': '2',
      'revenue': '₹3,100',
    },
    {
      'dealer': 'Krishi Bazaar',
      'state': 'UP',
      'agent': 'Priya Singh',
      'gst': 'Verified',
      'orders': '11',
      'revenue': '₹21,750',
    },
  ];

  String _terminalSearch = '';

  Widget _buildInteractiveOperationsTable() {
    final tabs = [
      {
        'label': 'Orders',
        'icon': Icons.receipt_long_outlined,
        'count': '${_ordersData.length}',
      },
      {
        'label': 'Leads',
        'icon': Icons.person_search_outlined,
        'count': '${_leadsData.length}',
      },
      {
        'label': 'Dealers',
        'icon': Icons.storefront_outlined,
        'count': '${_dealersData.length}',
      },
    ];

    final bool isMobile = Responsive.isMobile(context);

    // Dynamic Title + Live Badge
    final Widget titleAndBadge = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text('Operations Terminal', style: AppTheme.headingMD),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: AppTheme.success.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.success.withOpacity(0.25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 5,
                height: 5,
                decoration: const BoxDecoration(
                  color: AppTheme.success,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'Live',
                style: AppTheme.labelSM.copyWith(
                  color: AppTheme.success,
                  fontSize: 9.5,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    // Dynamic Search Field
    final Widget searchField = Container(
      height: 34,
      width: isMobile ? null : 200,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.search, size: 16, color: AppTheme.textSecondary),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              onChanged: (v) =>
                  setState(() => _terminalSearch = v.toLowerCase()),
              style: AppTheme.bodyMD,
              decoration: InputDecoration(
                hintText: 'Search records…',
                hintStyle: AppTheme.hint,
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );

    // Dynamic View All Button
    final Widget viewAllButton = Tooltip(
      message:
          'View all ${activeTableTab == 0
              ? "orders"
              : activeTableTab == 1
              ? "leads"
              : "dealers"}',
      child: InkWell(
        onTap: () {
          final route = activeTableTab == 0
              ? '/orders'
              : activeTableTab == 1
              ? '/leads'
              : '/dealers';
          Navigator.pushNamed(context, route);
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.08),
            border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'View All',
                style: AppTheme.labelMD.copyWith(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w700,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 5),
              const Icon(
                Icons.arrow_forward_rounded,
                size: 15,
                color: AppTheme.primaryColor,
              ),
            ],
          ),
        ),
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusXLarge),
        boxShadow: AppTheme.cardShadow,
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header bar ────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: isMobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      titleAndBadge,
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: searchField),
                          const SizedBox(width: 8),
                          viewAllButton,
                        ],
                      ),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      titleAndBadge,
                      const Spacer(),
                      searchField,
                      const SizedBox(width: 10),
                      viewAllButton,
                    ],
                  ),
          ),

          // ── Tab row ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: List.generate(tabs.length, (idx) {
                        final isSelected = activeTableTab == idx;
                        final tabColor = [
                          AppTheme.primaryColor,
                          AppTheme.info,
                          AppTheme.accentColor,
                        ][idx];
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: GestureDetector(
                              onTap: () => setState(() {
                                activeTableTab = idx;
                                _terminalSearch = '';
                              }),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? tabColor.withOpacity(0.08)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSelected
                                        ? tabColor.withOpacity(0.3)
                                        : AppTheme.borderColor,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      tabs[idx]['icon'] as IconData,
                                      size: 14,
                                      color: isSelected
                                          ? tabColor
                                          : AppTheme.textSecondary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      tabs[idx]['label'] as String,
                                      style: AppTheme.labelMD.copyWith(
                                        color: isSelected
                                            ? tabColor
                                            : AppTheme.textSecondary,
                                        fontWeight: isSelected
                                            ? FontWeight.w700
                                            : FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 1,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? tabColor.withOpacity(0.15)
                                            : AppTheme.backgroundColor,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        tabs[idx]['count'] as String,
                                        style: AppTheme.labelSM.copyWith(
                                          color: isSelected
                                              ? tabColor
                                              : AppTheme.textSecondary,
                                          fontSize: 9.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
                if (!isMobile) ...[
                  const SizedBox(width: 10),
                  Text(
                    '${_getFilteredRows().length} records',
                    style: AppTheme.hint,
                  ),
                ],
              ],
            ),
          ),

          // ── Divider ──────────────────────────────────────────────────────
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Divider(height: 1, color: AppTheme.lightBorderColor),
          ),

          // ── Table ────────────────────────────────────────────────────────
          _buildTerminalTable(),

          // ── Summary metric bar ────────────────────────────────────────────
          _buildSummaryBar(),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _getFilteredRows() {
    final List<Map<String, dynamic>> source = activeTableTab == 0
        ? _ordersData
        : activeTableTab == 1
        ? _leadsData
        : _dealersData;
    if (_terminalSearch.isEmpty) return source;
    return source
        .where(
          (row) => row.values.any(
            (v) => v.toString().toLowerCase().contains(_terminalSearch),
          ),
        )
        .toList();
  }

  Widget _buildTerminalTable() {
    final rows = _getFilteredRows();
    if (rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.search_off_rounded,
                size: 36,
                color: AppTheme.textSecondary.withOpacity(0.4),
              ),
              const SizedBox(height: 8),
              Text('No records match "$_terminalSearch"', style: AppTheme.hint),
            ],
          ),
        ),
      );
    }

    final bool isMobile = Responsive.isMobile(context);

    if (isMobile) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: rows
              .asMap()
              .entries
              .map((entry) => _buildMobileRecordCard(entry.key, entry.value))
              .toList(),
        ),
      );
    }

    final headers = activeTableTab == 0
        ? ['Dealer', 'Product', 'Amount', 'Agent', 'Date', 'Status', '']
        : activeTableTab == 1
        ? ['Dealer', 'Contact', 'Phone', 'State', 'Created', 'Status', '']
        : ['Dealer', 'State', 'Agent', 'Orders', 'Revenue', 'GST', ''];

    return Column(
      children: [
        // Column headers
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: headers.map((h) {
              final isAction = h == '';
              return Expanded(
                flex: isAction ? 0 : 1,
                child: isAction
                    ? const SizedBox(width: 60)
                    : Text(h.toUpperCase(), style: AppTheme.tableHeader),
              );
            }).toList(),
          ),
        ),
        const Divider(height: 1, color: AppTheme.lightBorderColor),
        // Data rows
        ...rows.asMap().entries.map(
          (entry) => _buildTerminalRow(entry.key, entry.value),
        ),
      ],
    );
  }

  Widget _buildTerminalRow(int index, Map<String, dynamic> row) {
    final isEven = index % 2 == 0;
    final cells = activeTableTab == 0
        ? [
            row['dealer'],
            row['product'],
            row['amount'],
            row['agent'],
            row['date'],
            row['status'],
          ]
        : activeTableTab == 1
        ? [
            row['dealer'],
            row['contact'],
            row['phone'],
            row['state'],
            row['created'],
            row['status'],
          ]
        : [
            row['dealer'],
            row['state'],
            row['agent'],
            row['orders'],
            row['revenue'],
            row['gst'],
          ];

    final statusStr = (row['status'] ?? row['gst'] ?? '') as String;
    final isPositive = statusStr == 'Completed' || statusStr == 'Verified';

    return _HoverableRow(
      index: index,
      isEven: isEven,
      cells: cells.cast<String>(),
      statusStr: statusStr,
      isPositive: isPositive,
      tabIndex: activeTableTab,
    );
  }

  Widget _buildSummaryBar() {
    final metrics = activeTableTab == 0
        ? [
            {
              'label': 'Total Orders',
              'value': '${_ordersData.length}',
              'icon': Icons.receipt_long_outlined,
              'color': AppTheme.primaryColor,
            },
            {
              'label': 'Completed',
              'value':
                  '${_ordersData.where((r) => r['status'] == 'Completed').length}',
              'icon': Icons.check_circle_outline,
              'color': AppTheme.success,
            },
            {
              'label': 'Pending',
              'value':
                  '${_ordersData.where((r) => r['status'] == 'Pending').length}',
              'icon': Icons.hourglass_empty_outlined,
              'color': AppTheme.warning,
            },
            {
              'label': 'Total Revenue',
              'value': '₹8,380',
              'icon': Icons.currency_rupee,
              'color': AppTheme.info,
            },
          ]
        : activeTableTab == 1
        ? [
            {
              'label': 'Total Leads',
              'value': '${_leadsData.length}',
              'icon': Icons.person_search_outlined,
              'color': AppTheme.info,
            },
            {
              'label': 'Converted',
              'value':
                  '${_leadsData.where((r) => r['status'] == 'Completed').length}',
              'icon': Icons.how_to_reg_outlined,
              'color': AppTheme.success,
            },
            {
              'label': 'In Pipeline',
              'value':
                  '${_leadsData.where((r) => r['status'] == 'Pending').length}',
              'icon': Icons.timelapse_outlined,
              'color': AppTheme.warning,
            },
            {
              'label': 'States',
              'value': '${_leadsData.map((r) => r['state']).toSet().length}',
              'icon': Icons.map_outlined,
              'color': AppTheme.accentColor,
            },
          ]
        : [
            {
              'label': 'Active Dealers',
              'value': '${_dealersData.length}',
              'icon': Icons.storefront_outlined,
              'color': AppTheme.accentColor,
            },
            {
              'label': 'GST Verified',
              'value':
                  '${_dealersData.where((r) => r['gst'] == 'Verified').length}',
              'icon': Icons.verified_outlined,
              'color': AppTheme.success,
            },
            {
              'label': 'Total Orders',
              'value': _dealersData
                  .fold(0, (s, r) => s + int.parse(r['orders'] as String))
                  .toString(),
              'icon': Icons.receipt_long_outlined,
              'color': AppTheme.primaryColor,
            },
            {
              'label': 'Total Revenue',
              'value': '₹78,250',
              'icon': Icons.currency_rupee,
              'color': AppTheme.info,
            },
          ];

    final bool isMobile = Responsive.isMobile(context);

    if (isMobile) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.backgroundColor.withOpacity(0.6),
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(AppTheme.borderRadiusXLarge),
            bottomRight: Radius.circular(AppTheme.borderRadiusXLarge),
          ),
          border: const Border(
            top: BorderSide(color: AppTheme.lightBorderColor),
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double itemWidth = (constraints.maxWidth - 12) / 2;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: metrics.map((m) {
                final color = m['color'] as Color;
                return Container(
                  width: itemWidth,
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          m['icon'] as IconData,
                          size: 15,
                          color: color,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              m['value'] as String,
                              style: AppTheme.headingSM.copyWith(
                                fontSize: 13.5,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              m['label'] as String,
                              style: AppTheme.labelSM.copyWith(fontSize: 10),
                              overflow: TextOverflow.ellipsis,
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
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(0, 0, 0, 0),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor.withOpacity(0.6),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(AppTheme.borderRadiusXLarge),
          bottomRight: Radius.circular(AppTheme.borderRadiusXLarge),
        ),
        border: const Border(top: BorderSide(color: AppTheme.lightBorderColor)),
      ),
      child: Row(
        children: metrics.map((m) {
          final color = m['color'] as Color;
          return Expanded(
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(m['icon'] as IconData, size: 15, color: color),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m['value'] as String,
                        style: AppTheme.headingSM.copyWith(fontSize: 14),
                      ),
                      Text(m['label'] as String, style: AppTheme.labelSM),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMobileRecordCard(int index, Map<String, dynamic> row) {
    final isEven = index % 2 == 0;
    final statusStr = (row['status'] ?? row['gst'] ?? '') as String;
    final isPositive = statusStr == 'Completed' || statusStr == 'Verified';

    Widget detailsWidget;
    if (activeTableTab == 0) {
      detailsWidget = Column(
        children: [
          _buildCardDetailRow('Product', row['product'] ?? ''),
          const SizedBox(height: 6),
          _buildCardDetailRow(
            'Amount',
            row['amount'] ?? '',
            isBoldValue: true,
            valueColor: AppTheme.success,
          ),
          const SizedBox(height: 6),
          _buildCardDetailRow('Agent', row['agent'] ?? ''),
          const SizedBox(height: 6),
          _buildCardDetailRow('Date', row['date'] ?? ''),
        ],
      );
    } else if (activeTableTab == 1) {
      detailsWidget = Column(
        children: [
          _buildCardDetailRow('Contact', row['contact'] ?? ''),
          const SizedBox(height: 6),
          _buildCardDetailRow('Phone', row['phone'] ?? ''),
          const SizedBox(height: 6),
          _buildCardDetailRow('State', row['state'] ?? ''),
          const SizedBox(height: 6),
          _buildCardDetailRow('Created', row['created'] ?? ''),
        ],
      );
    } else {
      detailsWidget = Column(
        children: [
          _buildCardDetailRow('State', row['state'] ?? ''),
          const SizedBox(height: 6),
          _buildCardDetailRow('Agent', row['agent'] ?? ''),
          const SizedBox(height: 6),
          _buildCardDetailRow('Orders', row['orders'] ?? ''),
          const SizedBox(height: 6),
          _buildCardDetailRow(
            'Revenue',
            row['revenue'] ?? '',
            isBoldValue: true,
            valueColor: AppTheme.primaryColor,
          ),
        ],
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isEven
            ? AppTheme.cardColor
            : AppTheme.backgroundColor.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  row['dealer'] ?? '',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              _StatusBadge(label: statusStr, isPositive: isPositive),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1, color: AppTheme.lightBorderColor),
          ),
          detailsWidget,
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1, color: AppTheme.lightBorderColor),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _ActionIconBtn(
                icon: Icons.open_in_new_rounded,
                tooltip: 'View details',
                onTap: () {},
              ),
              const SizedBox(width: 8),
              _ActionIconBtn(
                icon: Icons.more_horiz_rounded,
                tooltip: 'More actions',
                onTap: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCardDetailRow(
    String label,
    String value, {
    bool isBoldValue = false,
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 12,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 12,
            color: valueColor ?? AppTheme.textPrimary,
            fontWeight: isBoldValue ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // Keep legacy stubs so the call-sites in build() resolve
  Widget _buildTableTabs() => const SizedBox.shrink();
  Widget _buildTerminalContent() => const SizedBox.shrink();
}

// ── Hoverable table row — isolated StatefulWidget for per-row hover state ──
class _HoverableRow extends StatefulWidget {
  final int index;
  final bool isEven;
  final List<String> cells;
  final String statusStr;
  final bool isPositive;
  final int tabIndex;

  const _HoverableRow({
    required this.index,
    required this.isEven,
    required this.cells,
    required this.statusStr,
    required this.isPositive,
    required this.tabIndex,
  });

  @override
  State<_HoverableRow> createState() => _HoverableRowState();
}

class _HoverableRowState extends State<_HoverableRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final statusCell = widget.cells.last;
    final isStatus =
        statusCell == 'Completed' ||
        statusCell == 'Pending' ||
        statusCell == 'Verified';

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: _hovered
              ? AppTheme.primaryColor.withOpacity(0.03)
              : widget.isEven
              ? Colors.transparent
              : AppTheme.backgroundColor.withOpacity(0.4),
          border: const Border(
            bottom: BorderSide(color: AppTheme.lightBorderColor),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              // Data cells (all except last = status)
              ...widget.cells.sublist(0, widget.cells.length - 1).map((cell) {
                return Expanded(
                  child: Text(
                    cell,
                    style: AppTheme.tableCell,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }),
              // Status / GST badge
              Expanded(
                child: isStatus
                    ? Align(
                        alignment: Alignment.centerLeft,
                        child: _StatusBadge(
                          label: statusCell,
                          isPositive: widget.isPositive,
                        ),
                      )
                    : Text(statusCell, style: AppTheme.tableCell),
              ),
              // Action column
              SizedBox(
                width: 60,
                child: AnimatedOpacity(
                  opacity: _hovered ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 150),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _ActionIconBtn(
                        icon: Icons.open_in_new_rounded,
                        tooltip: 'View details',
                        onTap: () {},
                      ),
                      const SizedBox(width: 4),
                      _ActionIconBtn(
                        icon: Icons.more_horiz_rounded,
                        tooltip: 'More actions',
                        onTap: () {},
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final bool isPositive;
  const _StatusBadge({required this.label, required this.isPositive});

  @override
  Widget build(BuildContext context) {
    final color = isPositive ? AppTheme.success : AppTheme.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTheme.labelSM.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionIconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _ActionIconBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: AppTheme.backgroundColor,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Icon(icon, size: 13, color: AppTheme.textSecondary),
        ),
      ),
    );
  }
}

class AnimatedDonutChart extends StatefulWidget {
  final List<double> values;
  final List<Color> colors;
  final List<String> labels;
  final int hoveredIndex;
  final ValueChanged<int> onHoverChanged;

  const AnimatedDonutChart({
    super.key,
    required this.values,
    required this.colors,
    required this.labels,
    this.hoveredIndex = -1,
    required this.onHoverChanged,
  });

  @override
  State<AnimatedDonutChart> createState() => _AnimatedDonutChartState();
}

class _AnimatedDonutChartState extends State<AnimatedDonutChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _entryController;
  late Animation<double> _entryAnimation;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _entryAnimation = CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeOutBack,
    );
    _entryController.forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double total = widget.values.fold(0.0, (sum, val) => sum + val);

    final int activeIndex = widget.hoveredIndex;
    final isTouchActive =
        activeIndex >= 0 && activeIndex < widget.values.length;

    final String centerValue = isTouchActive
        ? widget.values[activeIndex].toInt().toString()
        : total.toInt().toString();

    final String centerLabel = isTouchActive
        ? widget.labels[activeIndex]
        : 'Active Leads';

    final Color centerColor = isTouchActive
        ? widget.colors[activeIndex]
        : AppTheme.textSecondary;

    return SizedBox(
      width: 140,
      height: 140,
      child: GestureDetector(
        onPanUpdate: (details) => _handleTouch(details.localPosition),
        onTapDown: (details) => _handleTouch(details.localPosition),
        onTapUp: (_) => widget.onHoverChanged(-1),
        child: MouseRegion(
          onHover: (event) => _handleTouch(event.localPosition),
          onExit: (_) => widget.onHoverChanged(-1),
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: _entryAnimation,
                builder: (context, child) {
                  return TweenAnimationBuilder<double>(
                    tween: Tween<double>(
                      begin: 0.0,
                      end: activeIndex == 0 ? 1.0 : 0.0,
                    ),
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutQuint,
                    builder: (context, val0, _) {
                      return TweenAnimationBuilder<double>(
                        tween: Tween<double>(
                          begin: 0.0,
                          end: activeIndex == 1 ? 1.0 : 0.0,
                        ),
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutQuint,
                        builder: (context, val1, _) {
                          return TweenAnimationBuilder<double>(
                            tween: Tween<double>(
                              begin: 0.0,
                              end: activeIndex == 2 ? 1.0 : 0.0,
                            ),
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOutQuint,
                            builder: (context, val2, _) {
                              return CustomPaint(
                                size: const Size(140, 140),
                                painter: CustomDonutPainter(
                                  values: widget.values,
                                  colors: widget.colors,
                                  entryProgress: _entryAnimation.value,
                                  hoverProgressions: [val0, val1, val2],
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  );
                },
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 150),
                    transitionBuilder: (child, anim) => ScaleTransition(
                      scale: anim,
                      child: FadeTransition(opacity: anim, child: child),
                    ),
                    child: Text(
                      centerValue,
                      key: ValueKey<String>(centerValue),
                      style: GoogleFonts.outfit(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 1),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 150),
                    transitionBuilder: (child, anim) =>
                        FadeTransition(opacity: anim, child: child),
                    child: Text(
                      centerLabel,
                      key: ValueKey<String>(centerLabel),
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        color: centerColor,
                        fontWeight: FontWeight.w800,
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

  void _handleTouch(Offset localPosition) {
    const double radius = 70.0;
    const Offset center = Offset(radius, radius);
    final double distance = (localPosition - center).distance;

    // Detect touch within the circular ring boundary (radius 32 to 68)
    if (distance >= 30.0 && distance <= 72.0) {
      final double angle = (localPosition - center).direction; // -pi to pi
      // Normalize angle to start from top (-pi/2) going clockwise
      double normalizedAngle = angle + (math.pi / 2);
      if (normalizedAngle < 0) normalizedAngle += 2 * math.pi;

      final double total = widget.values.fold(0.0, (sum, val) => sum + val);
      double currentSum = 0.0;

      for (int i = 0; i < widget.values.length; i++) {
        final double startAngle = (currentSum / total) * 2 * math.pi;
        currentSum += widget.values[i];
        final double endAngle = (currentSum / total) * 2 * math.pi;

        if (normalizedAngle >= startAngle && normalizedAngle <= endAngle) {
          widget.onHoverChanged(i);
          return;
        }
      }
    } else {
      widget.onHoverChanged(-1);
    }
  }
}

class CustomDonutPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;
  final double entryProgress;
  final List<double> hoverProgressions;

  CustomDonutPainter({
    required this.values,
    required this.colors,
    required this.entryProgress,
    required this.hoverProgressions,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double total = values.fold(0.0, (sum, val) => sum + val);
    if (total == 0 || entryProgress == 0) return;

    final Offset center = Offset(size.width / 2, size.height / 2);
    const double baseRadius = 48.0;

    double currentSum = 0.0;
    final bool anyHovered = hoverProgressions.any((v) => v > 0.05);

    for (int i = 0; i < values.length; i++) {
      final double hoverFactor = hoverProgressions[i];

      // Keep ALL segments on the SAME radius to prevent overlap.
      // Only stroke thickness grows on hover — radius stays constant.
      const double radius = baseRadius;
      final double strokeWidth = 11.0 + (hoverFactor * 5.0);

      // Dim non-hovered slices smoothly for rich visual contrast
      double opacity = 1.0;
      if (anyHovered) {
        opacity = 0.35 + (hoverFactor * 0.65);
      }

      final Paint paint = Paint()
        ..color = colors[i].withOpacity(opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt; // butt caps = no bleed past arc endpoints

      // Calculate angles based on entry progress
      final double startAngle =
          (currentSum / total) * 2 * math.pi * entryProgress - (math.pi / 2);
      final double sweepAngle =
          (values[i] / total) * 2 * math.pi * entryProgress;

      currentSum += values[i];

      // Angular gap (in radians) keeps segments visually separated regardless
      // of stroke width — proportional to a fixed angular size so it always
      // looks like clean floating capsules even at max hover thickness.
      const double gap = 0.07;
      if (sweepAngle > gap * 2) {
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          startAngle + (gap / 2),
          sweepAngle - gap,
          false,
          paint,
        );
      } else if (sweepAngle > 0) {
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          startAngle,
          sweepAngle,
          false,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomDonutPainter oldDelegate) {
    return oldDelegate.entryProgress != entryProgress ||
        oldDelegate.hoverProgressions[0] != hoverProgressions[0] ||
        oldDelegate.hoverProgressions[1] != hoverProgressions[1] ||
        oldDelegate.hoverProgressions[2] != hoverProgressions[2];
  }
}

// --- Custom Painters for Advanced Widgets ---

class SparklinePainter extends CustomPainter {
  final List<double> data;
  final Color color;

  SparklinePainter(this.data, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final double stepX = size.width / (data.length - 1);
    final double minVal = data.reduce((a, b) => a < b ? a : b);
    final double maxVal = data.reduce((a, b) => a > b ? a : b);
    final double range = maxVal - minVal == 0 ? 1.0 : maxVal - minVal;

    final points = <Offset>[];
    for (int i = 0; i < data.length; i++) {
      final double x = i * stepX;
      final double y = size.height - ((data[i] - minVal) / range) * size.height;
      points.add(Offset(x, y));
    }

    if (points.isNotEmpty) {
      path.moveTo(points[0].dx, points[0].dy);
      for (int i = 0; i < points.length - 1; i++) {
        final p0 = points[i];
        final p1 = points[i + 1];
        final controlX = p0.dx + (p1.dx - p0.dx) / 2;
        path.cubicTo(controlX, p0.dy, controlX, p1.dy, p1.dx, p1.dy);
      }
    }

    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withOpacity(0.18), color.withOpacity(0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant SparklinePainter oldDelegate) => false;
}

class FulfillmentProgressPainter extends CustomPainter {
  final double percent;
  final Color color;

  FulfillmentProgressPainter(this.percent, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final double strokeWidth = 3.5;
    final double radius = (size.width - strokeWidth) / 2;
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..color = color.withOpacity(0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    final arcPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * percent, false, arcPaint);
  }

  @override
  bool shouldRepaint(covariant FulfillmentProgressPainter oldDelegate) => false;
}

// --- End of fl_chart Integrations ---

class LivePulsingBadge extends StatefulWidget {
  final Color? color;
  const LivePulsingBadge({super.key, this.color});

  @override
  State<LivePulsingBadge> createState() => _LivePulsingBadgeState();
}

class _LivePulsingBadgeState extends State<LivePulsingBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _pulseAnimation = Tween<double>(begin: 1.0, end: 2.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final badgeColor = widget.color ?? AppTheme.warning;
    return SizedBox(
      width: 24,
      height: 24,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Container(
                width: 10 * _pulseAnimation.value,
                height: 10 * _pulseAnimation.value,
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(
                    0.35 * (2.2 - _pulseAnimation.value),
                  ),
                  shape: BoxShape.circle,
                ),
              );
            },
          ),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: badgeColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: badgeColor.withOpacity(0.4),
                  blurRadius: 4,
                  spreadRadius: 1.5,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class WelcomeHeaderBackgroundPainter extends CustomPainter {
  final Color primaryColor;
  final Color accentColor;

  WelcomeHeaderBackgroundPainter({
    required this.primaryColor,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Ambient glowing orb 1 (brand green glow on the left)
    paint.color = primaryColor.withOpacity(0.18);
    canvas.drawCircle(
      Offset(size.width * 0.15, size.height * 0.25),
      size.height * 0.7,
      paint,
    );

    // Ambient glowing orb 2 (accent orange glow on the right)
    paint.color = accentColor.withOpacity(0.12);
    canvas.drawCircle(
      Offset(size.width * 0.8, size.height * 0.75),
      size.height * 0.6,
      paint,
    );

    // Draw a sleek tech-grid pattern overlay
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.03)
      ..strokeWidth = 1.0;

    const double gap = 20.0;
    for (double x = 0; x < size.width; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class WelcomeAnimation extends StatelessWidget {
  final double size;
  const WelcomeAnimation({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.waving_hand_rounded,
      size: size,
      color: const Color(0xFFFFD54F), // Premium warm yellow/amber emoji color
    );
  }
}

class _AnnouncementDialog extends StatefulWidget {
  const _AnnouncementDialog();

  @override
  State<_AnnouncementDialog> createState() => _AnnouncementDialogState();
}

class _AnnouncementDialogState extends State<_AnnouncementDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
      ),
      title: Text(
        'Broadcast Platform Announcement',
        style: GoogleFonts.outfit(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppTheme.textPrimary,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This alert will display on all dealer portals immediately.',
            style: GoogleFonts.outfit(
              fontSize: 13,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.backgroundColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: TextField(
              controller: _controller,
              maxLines: 3,
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: AppTheme.textBody,
              ),
              decoration: const InputDecoration(
                hintText: 'Type announcement content here...',
                hintStyle: TextStyle(color: Colors.grey, fontSize: 13),
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(12),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: GoogleFonts.outfit(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: _isSending
              ? null
              : () async {
                  if (_controller.text.trim().isEmpty) return;
                  setState(() => _isSending = true);

                  // Simulate latency for API broadcast
                  await Future.delayed(const Duration(milliseconds: 1500));

                  if (mounted) {
                    setState(() => _isSending = false);
                    Navigator.pop(context);

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: AppTheme.success,
                        behavior: SnackBarBehavior.floating,
                        content: Row(
                          children: [
                            const Icon(
                              Icons.check_circle,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Broadcast dispatched successfully!',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: _isSending
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  'Broadcast Alert',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
        ),
      ],
    );
  }
}
