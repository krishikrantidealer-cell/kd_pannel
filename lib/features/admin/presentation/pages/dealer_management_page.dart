import 'package:flutter/material.dart';
import 'package:flutter_switch/flutter_switch.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kd_pannel/app_theme.dart';
import 'package:kd_pannel/core/responsive/responsive.dart';
import 'package:kd_pannel/core/services/dashboard_service.dart';
import 'package:kd_pannel/features/admin/presentation/pages/dealer_details_page.dart';
import 'package:kd_pannel/features/shared/widgets/stat_card_widget.dart';
import 'package:kd_pannel/util/dealers.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';

class DealerManagementPage extends StatefulWidget {
  final bool isStandalone;
  const DealerManagementPage({super.key, this.isStandalone = false});

  @override
  State<DealerManagementPage> createState() => _DealerManagementPageState();
}

class _DealerManagementPageState extends State<DealerManagementPage> {
  String selectedTimeframe = 'This Week';
  PickerDateRange? _selectedRange;
  int currentPage = 1;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _tableHorizontalController = ScrollController();
  String? _hoveredDealerKey;

  @override
  void dispose() {
    _searchController.dispose();
    _tableHorizontalController.dispose();
    super.dispose();
  }

  // Filter states
  String selectedAgent = 'All Sales Agents';
  String selectedState = 'All States';
  bool showHighValueOnly = false;
  bool showInactiveOnly = false;

  final List<String> timeframeOptions = [
    'Today',
    'Yesterday',
    'This Week',
    'Last Week',
    'This Month',
    'Last Month',
    'Custom Range',
  ];

  final List<String> agentOptions = [
    'All Sales Agents',
    'Rajesh Kumar',
    'Suresh Patil',
    'Amit Shah',
    'Vijay Deshmukh',
  ];

  final List<String> stateOptions = [
    'All States',
    'Maharashtra',
    'Gujarat',
    'Madhya Pradesh',
  ];

  List<Dealer> get filteredDealers {
    return allDealers.where((dealer) {
      final query = _searchController.text.toLowerCase();
      bool matchesSearch =
          dealer.name.toLowerCase().contains(query) ||
          dealer.phone.toLowerCase().contains(query) ||
          dealer.city.toLowerCase().contains(query) ||
          dealer.agent.toLowerCase().contains(query);
      bool matchesAgent =
          selectedAgent == 'All Sales Agents' || dealer.agent == selectedAgent;
      bool matchesState =
          selectedState == 'All States' || dealer.state == selectedState;
      bool matchesHighValue = !showHighValueOnly || dealer.isHighValue;
      bool matchesInactive = !showInactiveOnly || dealer.isInactive;
      return matchesSearch &&
          matchesAgent &&
          matchesState &&
          matchesHighValue &&
          matchesInactive;
    }).toList();
  }

  void _showDatePicker() {
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
            rangeSelectionColor: AppTheme.primaryColor.withValues(alpha: 0.12),
            startRangeSelectionColor: AppTheme.primaryColor,
            endRangeSelectionColor: AppTheme.primaryColor,
            initialSelectedRange: _selectedRange,
            onSubmit: (Object? val) {
              if (val is PickerDateRange &&
                  val.startDate != null &&
                  val.endDate != null) {
                setState(() {
                  _selectedRange = val;
                  selectedTimeframe = 'Custom Range';
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

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);
    final isMobile = Responsive.isMobile(context);

    final Widget body = ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 28 : 16,
            vertical: isDesktop ? 20 : 12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(isMobile),
              const SizedBox(height: 16),
              _buildStatsCards(context),
              const SizedBox(height: 24),
              _buildFiltersRow(isMobile, isDesktop),
              const SizedBox(height: 16),
              _buildDealerTable(isMobile),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );

    if (widget.isStandalone) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          title: Text(
            'Dealer Management',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          backgroundColor: Colors.white,
          foregroundColor: AppTheme.textPrimary,
          elevation: 0,
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1, color: AppTheme.lightBorderColor),
          ),
        ),
        body: body,
      );
    }

    return body;
  }

  Widget _buildHeader(bool isMobile) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (!widget.isStandalone)
          Text(
            isMobile ? 'Dealers' : 'Dealer Management',
            style: AppTheme.headingXL.copyWith(
              letterSpacing: -0.5,
              fontWeight: FontWeight.w800,
            ),
          )
        else
          const SizedBox.shrink(),
        _buildTimeframeFilter(isMobile),
      ],
    );
  }

  Widget _buildTimeframeFilter(bool isMobile) {
    return GestureDetector(
      onTap: () {}, // Swallows taps to prevent event bubbling to parent layout
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: isMobile ? 38 : 42,
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
          border: Border.all(color: AppTheme.borderColor),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: _showDatePicker,
                child: Icon(
                  Icons.calendar_month_outlined,
                  size: isMobile ? 16 : 18,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
            VerticalDivider(
              indent: isMobile ? 8 : 10,
              endIndent: isMobile ? 8 : 10,
              width: isMobile ? 16 : 24,
              color: AppTheme.borderColor,
            ),
            DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: timeframeOptions.contains(selectedTimeframe)
                    ? selectedTimeframe
                    : null,
                isExpanded: false,
                hint: Text(
                  'Timeframe',
                  style: GoogleFonts.outfit(
                    fontSize: isMobile ? 12 : 13,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                icon: Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Icon(
                    Icons.keyboard_arrow_down,
                    size: isMobile ? 16 : 18,
                    color: AppTheme.textSecondary,
                  ),
                ),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      selectedTimeframe = newValue;
                      if (newValue != 'Custom Range') {
                        _selectedRange = null;
                      } else {
                        _showDatePicker();
                      }
                    });
                  }
                },
                items: timeframeOptions
                    .map<DropdownMenuItem<String>>(
                      (String value) => DropdownMenuItem<String>(
                        value: value,
                        child: Text(
                          value,
                          style: GoogleFonts.outfit(
                            fontSize: isMobile ? 12 : 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCards(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);
    final service = DashboardService();

    return LayoutBuilder(
      builder: (context, constraints) {
        final double spacing = AppTheme.spacingSmall;
        final int columns = isDesktop ? 4 : 2;

        final double width =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            FutureBuilder<String>(
              future: service.getDealerTotalDealers(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return StatCardShimmer(isCompact: true, width: width);
                }
                return StatCardWidget(
                  width: width,
                  title: 'Total Dealers',
                  value: snapshot.data ?? '0',
                  imagePath: 'assets/images/Total dealer.png',
                  color: AppTheme.primaryColor,
                  isCompact: true,
                );
              },
            ),
            FutureBuilder<String>(
              future: service.getDealerActiveDealers(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return StatCardShimmer(isCompact: true, width: width);
                }
                return StatCardWidget(
                  width: width,
                  title: 'Active Dealers',
                  value: snapshot.data ?? '0',
                  imagePath: 'assets/images/Active dealer .png',
                  color: AppTheme.success,
                  isCompact: true,
                );
              },
            ),
            FutureBuilder<String>(
              future: service.getDealerHighValueDealers(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return StatCardShimmer(isCompact: true, width: width);
                }
                return StatCardWidget(
                  width: width,
                  title: 'High Value Dealers',
                  value: snapshot.data ?? '0',
                  imagePath: 'assets/images/sales perfrom.png',
                  color: AppTheme.warning,
                  isCompact: true,
                );
              },
            ),
            FutureBuilder<String>(
              future: service.getDealerInactiveDealers(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return StatCardShimmer(isCompact: true, width: width);
                }
                return StatCardWidget(
                  width: width,
                  title: 'Inactive Dealers',
                  value: snapshot.data ?? '0',
                  imagePath: 'assets/images/New leads.png',
                  color: AppTheme.error,
                  isCompact: true,
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildFiltersRow(bool isMobile, bool isDesktop) {
    if (!isMobile) {
      return Row(
        children: [
          _buildSearchField(300),
          const SizedBox(width: 12),
          _buildFilterDropdown(
            'All Sales Agents',
            180,
            agentOptions,
            selectedAgent,
            (val) => setState(() => selectedAgent = val!),
          ),
          const SizedBox(width: 12),
          _buildFilterDropdown(
            'All States',
            150,
            stateOptions,
            selectedState,
            (val) => setState(() => selectedState = val!),
          ),
          const Spacer(),
          _buildToggleFilter(
            'High Value',
            showHighValueOnly,
            (val) => setState(() => showHighValueOnly = val),
          ),
          const SizedBox(width: 12),
          _buildToggleFilter(
            'Inactive',
            showInactiveOnly,
            (val) => setState(() => showInactiveOnly = val),
          ),
        ],
      );
    } else {
      return Column(
        children: [
          _buildSearchField(double.infinity),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildFilterDropdown(
                  'Sales Agents',
                  null,
                  agentOptions,
                  selectedAgent,
                  (val) => setState(() => selectedAgent = val!),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildFilterDropdown(
                  'States',
                  null,
                  stateOptions,
                  selectedState,
                  (val) => setState(() => selectedState = val!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildToggleFilter(
                  'High Value',
                  showHighValueOnly,
                  (val) => setState(() => showHighValueOnly = val),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildToggleFilter(
                  'Inactive',
                  showInactiveOnly,
                  (val) => setState(() => showInactiveOnly = val),
                ),
              ),
            ],
          ),
        ],
      );
    }
  }

  Widget _buildSearchField(double? width) {
    return Container(
      width: width,
      height: 38,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (val) => setState(() {}),
        textAlignVertical: TextAlignVertical.center,
        style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.textPrimary),
        decoration: InputDecoration(
          hintText: 'Search dealers...',
          hintStyle: GoogleFonts.outfit(
            fontSize: 13,
            color: AppTheme.textSecondary,
          ),
          prefixIcon: const Icon(
            Icons.search,
            size: 18,
            color: AppTheme.textSecondary,
          ),
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }

  Widget _buildFilterDropdown(
    String hint,
    double? width,
    List<String> options,
    String currentValue,
    ValueChanged<String?> onChanged,
  ) {
    return Container(
      height: 38,
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: options.contains(currentValue) ? currentValue : null,
          hint: Text(
            hint,
            style: GoogleFonts.outfit(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          icon: const Icon(
            Icons.keyboard_arrow_down,
            size: 16,
            color: AppTheme.textSecondary,
          ),
          onChanged: onChanged,
          items: options
              .map<DropdownMenuItem<String>>(
                (String value) => DropdownMenuItem<String>(
                  value: value,
                  child: Text(
                    value,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _buildToggleFilter(
    String label,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: GoogleFonts.outfit(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          FlutterSwitch(
            width: 36.0,
            height: 18.0,
            toggleSize: 12.0,
            value: value,
            borderRadius: 20.0,
            padding: 3.0,
            activeColor: AppTheme.primaryColor,
            inactiveColor: AppTheme.borderColor,
            onToggle: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildDealerTable(bool isMobile) {
    final dealersToShow = filteredDealers;
    return LayoutBuilder(
      builder: (context, constraints) {
        // Ensure table never gets clipped on smaller laptop widths.
        const double minTableWidth = 980;
        final bool needsHorizontalScroll = constraints.maxWidth < minTableWidth;
        final double tableWidth = needsHorizontalScroll
            ? minTableWidth
            : constraints.maxWidth;

        final table = Container(
          width: tableWidth,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
            border: Border.all(
              color: AppTheme.borderColor.withValues(alpha: 0.5),
            ),
            boxShadow: AppTheme.softShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: isMobile
                    ? const EdgeInsets.all(16)
                    : const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                child: Text(
                  'Dealer Records',
                  style: GoogleFonts.outfit(
                    fontSize: isMobile ? 15 : 16,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                    letterSpacing: isMobile ? 0.2 : 0.0,
                  ),
                ),
              ),
              _buildTableHeader(),
              if (dealersToShow.isEmpty)
                Container(
                  padding: const EdgeInsets.all(40),
                  child: Center(
                    child: Text(
                      'No dealers found matching your criteria',
                      style: GoogleFonts.outfit(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ),
                )
              else
                ...dealersToShow.asMap().entries.map(
                  (entry) => _buildDealerRow(entry.value, entry.key % 2 == 1),
                ),
              _buildTableFooter(isMobile),
            ],
          ),
        );

        return Scrollbar(
          controller: _tableHorizontalController,
          thumbVisibility: needsHorizontalScroll,
          trackVisibility: needsHorizontalScroll,
          child: SingleChildScrollView(
            controller: _tableHorizontalController,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: table,
          ),
        );
      },
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      color: const Color(0xFFF9FAFB),
      child: const Row(
        children: [
          Expanded(flex: 2, child: _HeaderText('DEALER NAME')),
          Expanded(flex: 2, child: _HeaderText('PHONE NUMBER')),
          Expanded(flex: 1, child: _HeaderText('CITY')),
          Expanded(flex: 2, child: _HeaderText('ASSIGNED AGENT')),
          Expanded(flex: 1, child: Center(child: _HeaderText('GST STATUS'))),
          Expanded(flex: 1, child: Center(child: _HeaderText('ORDERS'))),
          Expanded(
            flex: 2,
            child: Center(child: _HeaderText('PURCHASE VALUE')),
          ),
        ],
      ),
    );
  }

  Widget _buildDealerRow(Dealer dealer, bool isAlternate) {
    return _DealerRow(
      dealer: dealer,
      isAlternate: isAlternate,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => DealerDetailsPage(dealer: dealer)),
      ),
      isHovered: _hoveredDealerKey == dealer.phone,
      onHoverChanged: (isHovered) {
        setState(() {
          _hoveredDealerKey = isHovered ? dealer.phone : null;
        });
      },
    );
  }

  Widget _buildTableFooter(bool isMobile) {
    final footerPadding = isMobile
        ? const EdgeInsets.symmetric(horizontal: 16, vertical: 12)
        : const EdgeInsets.symmetric(horizontal: 12, vertical: 12);

    return Container(
      padding: footerPadding,
      decoration: const BoxDecoration(
        color: Color(0xFFF9FAFB),
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(AppTheme.borderRadiusLarge),
        ),
      ),
      child: isMobile
          ? Column(
              children: [
                Text(
                  'Showing 1 to 10 of 1245 entries',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                _buildPaginationRow(isMobile),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Showing 1 to 10 of 1245 entries',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                _buildPaginationRow(isMobile),
              ],
            ),
    );
  }

  Widget _buildPaginationRow(bool isMobile) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildPaginationButton(Icons.chevron_left, false),
        const SizedBox(width: 8),
        _buildPaginationPage(1, true),
        _buildPaginationPage(2, false),
        _buildPaginationPage(3, false),
        if (!isMobile) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '...',
              style: GoogleFonts.outfit(color: AppTheme.textSecondary),
            ),
          ),
          _buildPaginationPage(125, false),
        ],
        const SizedBox(width: 8),
        _buildPaginationButton(Icons.chevron_right, true),
      ],
    );
  }

  Widget _buildPaginationButton(IconData icon, bool isEnabled) => Container(
    width: 32,
    height: 32,
    decoration: BoxDecoration(
      color: isEnabled ? Colors.white : Colors.white,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: AppTheme.borderColor),
    ),
    child: Icon(
      icon,
      size: 18,
      color: isEnabled ? AppTheme.textSecondary : const Color(0xFFD1D5DB),
    ),
  );

  Widget _buildPaginationPage(int page, bool isActive) => Container(
    width: 32,
    height: 32,
    margin: const EdgeInsets.symmetric(horizontal: 2),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: isActive ? AppTheme.primaryColor : Colors.white,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(
        color: isActive ? AppTheme.primaryColor : AppTheme.borderColor,
      ),
    ),
    child: Text(
      page.toString(),
      style: GoogleFonts.outfit(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: isActive ? Colors.white : AppTheme.textBody,
      ),
    ),
  );
}

class _HeaderText extends StatelessWidget {
  final String text;

  const _HeaderText(this.text);

  @override
  Widget build(BuildContext context) => Text(text, style: AppTheme.tableHeader);
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case 'Verified':
      case 'Completed':
      case 'Verified ✓':
        color = AppTheme.success;
        break;
      case 'Pending':
      case 'Order Pending':
        color = AppTheme.warning;
        break;
      case 'Rejected':
      case 'Cancelled':
        color = AppTheme.error;
        break;
      default:
        color = AppTheme.info;
    }
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
        ),
        child: Text(
          status,
          style: GoogleFonts.outfit(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ),
    );
  }
}

class _DealerRow extends StatefulWidget {
  final Dealer dealer;
  final bool isAlternate;
  final VoidCallback onTap;
  final bool isHovered;
  final ValueChanged<bool> onHoverChanged;

  const _DealerRow({
    required this.dealer,
    required this.isAlternate,
    required this.onTap,
    required this.isHovered,
    required this.onHoverChanged,
  });

  @override
  State<_DealerRow> createState() => _DealerRowState();
}

class _DealerRowState extends State<_DealerRow> {
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => widget.onHoverChanged(true),
      onExit: (_) => widget.onHoverChanged(false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: widget.isHovered
                ? AppTheme.primaryColor.withValues(alpha: 0.04)
                : (widget.isAlternate ? const Color(0xFFFAFBFC) : Colors.white),
            border: Border(
              bottom: const BorderSide(color: Color(0xFFF3F4F6), width: 0.5),
              left: BorderSide(
                color: widget.isHovered
                    ? AppTheme.primaryColor.withValues(alpha: 0.55)
                    : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  widget.dealer.name,
                  style: GoogleFonts.outfit(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  widget.dealer.phone,
                  style: GoogleFonts.outfit(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                flex: 1,
                child: Text(
                  widget.dealer.city,
                  style: GoogleFonts.outfit(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  widget.dealer.agent,
                  style: GoogleFonts.outfit(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                flex: 1,
                child: _StatusBadge(status: widget.dealer.gstStatus),
              ),
              Expanded(
                flex: 1,
                child: Center(
                  child: Text(
                    widget.dealer.totalOrders.toString(),
                    style: GoogleFonts.outfit(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Center(
                  child: Text(
                    widget.dealer.purchaseValue,
                    style: GoogleFonts.outfit(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              SizedBox(
                width: 22,
                child: Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: widget.isHovered
                      ? AppTheme.primaryColor.withValues(alpha: 0.9)
                      : AppTheme.textSecondary.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
