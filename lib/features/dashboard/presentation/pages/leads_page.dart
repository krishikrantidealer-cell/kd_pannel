import 'package:flutter/material.dart';
import 'package:kd_pannel/app_theme.dart';
import 'package:kd_pannel/core/responsive/responsive.dart';
import 'package:kd_pannel/util/leads.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';

class LeadsPage extends StatefulWidget {
  const LeadsPage({super.key});

  @override
  State<LeadsPage> createState() => _LeadsPageState();
}

class _LeadsPageState extends State<LeadsPage> {
  String selectedDropdown = 'This Month';
  PickerDateRange? _selectedRange;
  String selectedFilterChip = 'All';
  int currentPage = 1;
  final TextEditingController _searchController = TextEditingController();

  final List<String> dropdownOptions = [
    'Last 1 Week',
    'Last 2 Weeks',
    'Last 3 Weeks',
    'Last 1 Month',
    'Last 3 Months',
    'Last 6 Months',
    'This Month',
  ];

  final List<String> filterChips = [
    'All',
    'Order Pending',
    'Order Confirm',
    'Assigned',
    'Unassigned',
    'KYC Confirm',
    'KYC Pending',
  ];

  final Map<String, String> statusMapping = {
    'Order Pending': 'Order Pending',
    'Order Confirm': 'Order Confirm',
    'Assigned': 'Assigned',
    'Unassigned': 'Unassigned',
    'KYC Confirm': 'KYC Confirm',
    'KYC Pending': 'KYC Pending',
  };

  List<Map<String, dynamic>> get filteredLeads {
    List<Map<String, dynamic>> leads = List.from(allLeads);

    if (selectedFilterChip != 'All') {
      final targetStatus = statusMapping[selectedFilterChip];
      leads = leads.where((l) => l['status'] == targetStatus).toList();
    }

    final query = _searchController.text.toLowerCase();
    if (query.isNotEmpty) {
      leads = leads.where((l) {
        return l['name'].toString().toLowerCase().contains(query) ||
            l['phone'].toString().toLowerCase().contains(query) ||
            l['city'].toString().toLowerCase().contains(query) ||
            l['source'].toString().toLowerCase().contains(query) ||
            l['agent'].toString().toLowerCase().contains(query);
      }).toList();
    }

    if (selectedFilterChip == 'All' && query.isEmpty) {
      final List<Map<String, dynamic>> mixed = [];
      final categories = statusMapping.values.toList();
      for (int i = 0; i < 10; i++) {
        final targetStatus = categories[i % categories.length];
        final leadInStatus = allLeads.firstWhere(
          (l) => l['status'] == targetStatus,
          orElse: () => allLeads[i % allLeads.length],
        );
        mixed.add(leadInStatus);
      }
      return mixed;
    }

    return leads.take(10).toList();
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
                  selectedDropdown = '';
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
    final bool isDesktop = Responsive.isDesktop(context);
    final bool isMobile = Responsive.isMobile(context);

    return Material(
      color: Colors.white,
      child: Padding(
        padding: EdgeInsets.only(
          left: isMobile ? 16 : 24,
          right: isMobile ? 16 : 24,
          top: 0,
          bottom: 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isMobile ? 'Leads' : 'Leads Management',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF4B5563),
                    ),
                  ),
                  _buildTimeframeRow(isMobile),
                ],
              ),
              const SizedBox(height: 20),
              _StatGridRow(
                count: isDesktop ? 6 : 2,
                items: [
                  {
                    'title': 'Unassigned Lead',
                    'value': '10',
                    'image': 'assets/images/New leads.png',
                    'color': AppTheme.warning,
                  },
                  {
                    'title': 'Assigned Lead',
                    'value': '10',
                    'image': 'assets/images/Total dealer.png',
                    'color': AppTheme.info,
                  },
                  {
                    'title': 'KYC Pending',
                    'value': '10',
                    'image': 'assets/images/order today.png',
                    'color': AppTheme.error,
                  },
                  {
                    'title': 'KYC Confirm',
                    'value': '10',
                    'image': 'assets/images/Revenue.png',
                    'color': AppTheme.success,
                  },
                  {
                    'title': 'Order Pending',
                    'value': '10',
                    'image': 'assets/images/order today.png',
                    'color': AppTheme.warning,
                  },
                  {
                    'title': 'Order Confirm',
                    'value': '10',
                    'image': 'assets/images/Revenue.png',
                    'color': AppTheme.lightGreen,
                  },
                ],
              ),
              const SizedBox(height: 24),
              _buildFilterChips(isMobile),
              const SizedBox(height: 16),
              _LeadsTableCard(
                leads: filteredLeads,
                totalEntries: filteredLeads.length,
                isMobile: isMobile,
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeframeRow(bool isMobile) {
    return Container(
      height: isMobile ? 40 : 48,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isMobile ? 10 : 14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
        ],
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
                size: isMobile ? 18 : 20,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          VerticalDivider(
            indent: isMobile ? 10 : 12,
            endIndent: isMobile ? 10 : 12,
            width: isMobile ? 16 : 24,
            color: const Color(0xFFE5E7EB),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: dropdownOptions.contains(selectedDropdown)
                  ? selectedDropdown
                  : null,
              isExpanded: false,
              hint: Text(
                _rangeDisplay,
                style: TextStyle(
                  fontSize: isMobile ? 12 : 13,
                  color: AppTheme.textBody,
                  fontWeight: FontWeight.w500,
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
                    selectedDropdown = newValue;
                    _selectedRange = null;
                  });
                }
              },
              items: dropdownOptions
                  .map<DropdownMenuItem<String>>(
                    (String value) => DropdownMenuItem<String>(
                      value: value,
                      child: Text(
                        value,
                        style: TextStyle(fontSize: isMobile ? 12 : 13),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(bool isMobile) {
    if (!isMobile) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: filterChips
                .map(
                  (chip) => Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: _FilterChipItem(
                      label: chip,
                      isSelected: selectedFilterChip == chip,
                      onTap: () => setState(() {
                        selectedFilterChip = chip;
                        currentPage = 1;
                      }),
                    ),
                  ),
                )
                .toList(),
          ),
          Row(
            children: [
              _buildSearchField(250),
              const SizedBox(width: 12),
              _HoverIconContainer(icon: Icons.filter_list, onTap: () {}),
            ],
          ),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: filterChips
                  .map(
                    (chip) => Padding(
                      padding: const EdgeInsets.only(right: 14),
                      child: _FilterChipItem(
                        label: chip,
                        isSelected: selectedFilterChip == chip,
                        onTap: () => setState(() {
                          selectedFilterChip = chip;
                          currentPage = 1;
                        }),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildSearchField(null)),
              const SizedBox(width: 12),
              _HoverIconContainer(icon: Icons.filter_list, onTap: () {}),
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
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (val) => setState(() {}),
        textAlignVertical: TextAlignVertical.center,
        style: const TextStyle(fontSize: 13, color: Color(0xFF1F2937)),
        decoration: const InputDecoration(
          hintText: 'Search leads...',
          hintStyle: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
          prefixIcon: Icon(Icons.search, size: 18, color: Color(0xFF9CA3AF)),
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }
}

class _FilterChipItem extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChipItem({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_FilterChipItem> createState() => _FilterChipItemState();
}

class _FilterChipItemState extends State<_FilterChipItem> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    final bool isMobile = Responsive.isMobile(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 12 : 18,
            vertical: isMobile ? 6 : 9,
          ),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? const Color(0xFFE8F5E9)
                : (isHovered ? const Color(0xFFF9FAFB) : Colors.white),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.isSelected
                  ? const Color(0xFFA5D6A7)
                  : const Color(0xFFE5E7EB),
              width: 1,
            ),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              color: widget.isSelected
                  ? const Color(0xFF2E7D32)
                  : const Color(0xFF6B7280),
              fontWeight: widget.isSelected ? FontWeight.bold : FontWeight.w500,
              fontSize: isMobile ? 12 : 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _HoverIconContainer extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HoverIconContainer({required this.icon, required this.onTap});

  @override
  State<_HoverIconContainer> createState() => _HoverIconContainerState();
}

class _HoverIconContainerState extends State<_HoverIconContainer> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 38,
          width: 38,
          decoration: BoxDecoration(
            color: isHovered ? const Color(0xFFF9FAFB) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Icon(widget.icon, size: 20, color: const Color(0xFF6B7280)),
        ),
      ),
    );
  }
}

class _LeadsTableCard extends StatefulWidget {
  final List<Map<String, dynamic>> leads;
  final int totalEntries;
  final bool isMobile;

  const _LeadsTableCard({
    required this.leads,
    required this.totalEntries,
    required this.isMobile,
  });

  @override
  State<_LeadsTableCard> createState() => _LeadsTableCardState();
}

class _LeadsTableCardState extends State<_LeadsTableCard> {
  String selectedSource = 'Lead Source';
  String selectedAssign = 'Assign';
  String selectedDate = 'Date';

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = Responsive.isDesktop(context);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: widget.isMobile
                ? const EdgeInsets.all(16)
                : const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: isDesktop
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Leads Management',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF374151),
                        ),
                      ),
                      Row(
                        children: [
                          _buildTableDropdown(
                            'Lead Source',
                            selectedSource,
                            ['All', 'Facebook', 'Google', 'Website', 'Direct'],
                            (val) => setState(() => selectedSource = val!),
                          ),
                          const SizedBox(width: 8),
                          _buildTableDropdown(
                            'Assign',
                            selectedAssign,
                            ['All', 'Amit Patel', 'Priya Singh', 'Unassigned'],
                            (val) => setState(() => selectedAssign = val!),
                          ),
                          const SizedBox(width: 8),
                          _buildTableDropdown(
                            'Date',
                            selectedDate,
                            [
                              'Today',
                              'Yesterday',
                              'Last 7 Days',
                              'Last 30 Days',
                            ],
                            (val) => setState(() => selectedDate = val!),
                          ),
                        ],
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Leads Management',
                        style: TextStyle(
                          fontSize: widget.isMobile ? 15 : 16,
                          fontWeight: widget.isMobile
                              ? FontWeight.w700
                              : FontWeight.w600,
                          color: widget.isMobile
                              ? const Color(0xFF1F2937)
                              : const Color(0xFF374151),
                          letterSpacing: widget.isMobile ? 0.4 : 0.0,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildTableDropdown(
                              'Lead Source',
                              selectedSource,
                              [
                                'All',
                                'Facebook',
                                'Google',
                                'Website',
                                'Direct',
                              ],
                              (val) => setState(() => selectedSource = val!),
                            ),
                            const SizedBox(width: 8),
                            _buildTableDropdown(
                              'Assign',
                              selectedAssign,
                              [
                                'All',
                                'Amit Patel',
                                'Priya Singh',
                                'Unassigned',
                              ],
                              (val) => setState(() => selectedAssign = val!),
                            ),
                            const SizedBox(width: 8),
                            _buildTableDropdown(
                              'Date',
                              selectedDate,
                              [
                                'Today',
                                'Yesterday',
                                'Last 7 Days',
                                'Last 30 Days',
                              ],
                              (val) => setState(() => selectedDate = val!),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
          _LeadsTable(leads: widget.leads, isMobile: widget.isMobile),
          _buildTableFooter(widget.isMobile),
        ],
      ),
    );
  }

  Widget _buildTableDropdown(
    String hint,
    String current,
    List<String> options,
    ValueChanged<String?> onChanged,
  ) {
    return Container(
      height: widget.isMobile ? 32 : 34,
      padding: EdgeInsets.symmetric(horizontal: widget.isMobile ? 8 : 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          hint: Text(
            hint,
            style: TextStyle(
              fontSize: widget.isMobile ? 11 : 12,
              color: const Color(0xFF6B7280),
              fontWeight: FontWeight.w600,
            ),
          ),
          value: options.contains(current) ? current : null,
          icon: Icon(
            Icons.keyboard_arrow_down,
            size: widget.isMobile ? 14 : 16,
            color: const Color(0xFF9CA3AF),
          ),
          items: options
              .map(
                (e) => DropdownMenuItem(
                  value: e,
                  child: Text(
                    e,
                    style: TextStyle(
                      fontSize: widget.isMobile ? 11 : 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildTableFooter(bool isMobile) {
    if (isMobile) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: const BoxDecoration(
          color: Color(0xFFF9FAFB),
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
        ),
        child: Column(
          children: [
            Text(
              'Showing 1 to ${widget.leads.length} of ${widget.totalEntries} entries',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            _buildPaginationControls(),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFF9FAFB),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing 1 to ${widget.leads.length} of ${widget.totalEntries} entries',
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w500,
            ),
          ),
          _buildPaginationControls(),
        ],
      ),
    );
  }

  Widget _buildPaginationControls() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PaginationButton(
          onTap: () {},
          icon: Icons.chevron_left,
          isDisabled: true,
        ),
        const SizedBox(width: 8),
        const _PageNumberButton(page: 1, isActive: true, onTap: null),
        const _PageNumberButton(page: 2, isActive: false, onTap: null),
        const _PageNumberButton(page: 3, isActive: false, onTap: null),
        const SizedBox(width: 8),
        _PaginationButton(
          onTap: () {},
          icon: Icons.chevron_right,
          isDisabled: false,
        ),
      ],
    );
  }
}

class _LeadsTable extends StatefulWidget {
  final List<Map<String, dynamic>> leads;
  final bool isMobile;

  const _LeadsTable({required this.leads, required this.isMobile});

  @override
  State<_LeadsTable> createState() => _LeadsTableState();
}

class _LeadsTableState extends State<_LeadsTable> {
  int? hoveredIndex;

  @override
  Widget build(BuildContext context) {
    final columns = [
      'Lead Name',
      'Phone Number',
      'City',
      'Source',
      'Assigned Agent',
      'Lead Status',
      'Last Activity',
      'Actions',
    ];

    Widget table = Table(
      columnWidths: const {
        0: FlexColumnWidth(1.5),
        1: FlexColumnWidth(1.2),
        7: FlexColumnWidth(1.3),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Color(0xFFF3F4F6), width: 1.5),
            ),
            color: Color(0xFFF9FAFB),
          ),
          children: columns.asMap().entries.map((entry) {
            final i = entry.key;
            final c = entry.value;
            final bool isCentered = i == 5 || i == 7;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
              child: isCentered
                  ? Center(child: _HeaderText(c))
                  : _HeaderText(c),
            );
          }).toList(),
        ),
        ...widget.leads.asMap().entries.map((entry) {
          final index = entry.key;
          final lead = entry.value;
          final bool isAlternate = index % 2 == 1;
          return TableRow(
            decoration: BoxDecoration(
              border: const Border(
                bottom: BorderSide(color: Color(0xFFF3F4F6)),
              ),
              color: isAlternate ? const Color(0xFFF9FAFB) : Colors.white,
            ),
            children: [
              _buildClickableCell(lead['name'], context, isBold: true),
              _buildClickableCell(lead['phone'], context),
              _buildClickableCell(lead['city'], context),
              _buildClickableCell(lead['source'], context),
              _buildClickableCell(lead['agent'], context),
              InkWell(
                onTap: () => Navigator.pushNamed(context, '/leads/profile'),
                child: Center(child: _StatusBadge(status: lead['status'])),
              ),
              _buildClickableCell(lead['activity'], context),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildCallButton(),
                      const SizedBox(width: 4),
                      _buildViewButton(context),
                    ],
                  ),
                ),
              ),
            ],
          );
        }),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final double minTableWidth = widget.isMobile ? 1000.0 : 800.0;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: constraints.maxWidth > minTableWidth
                ? constraints.maxWidth
                : minTableWidth,
            child: table,
          ),
        );
      },
    );
  }

  Widget _buildClickableCell(
    String text,
    BuildContext context, {
    bool isBold = false,
  }) {
    return InkWell(
      onTap: () => Navigator.pushNamed(context, '/leads/profile'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: isBold ? const Color(0xFF111827) : const Color(0xFF4B5563),
            fontWeight: isBold ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildCallButton() {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF2E7D32),
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.phone, size: 12, color: Colors.white),
          SizedBox(width: 4),
          Text(
            'Call',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewButton(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => Navigator.pushNamed(context, '/leads/profile'),
        child: Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F8E9),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFE5E7EB), width: 0.5),
          ),
          alignment: Alignment.center,
          child: const Text(
            'View',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Color(0xFF4B5563),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    switch (status) {
      case 'Order Pending':
        bgColor = const Color(0xFFF59E0B);
        break;
      case 'Order Confirm':
        bgColor = const Color(0xFF10B981);
        break;
      case 'Assigned':
        bgColor = const Color(0xFF3B82F6);
        break;
      case 'Unassigned':
        bgColor = const Color(0xFF8B5CF6);
        break;
      case 'KYC Confirm':
        bgColor = const Color(0xFF06B6D4);
        break;
      case 'KYC Pending':
        bgColor = const Color(0xFFEF4444);
        break;
      default:
        bgColor = const Color(0xFF3B82F6);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status,
        style: const TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}

class _HeaderText extends StatelessWidget {
  final String text;

  const _HeaderText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: Color(0xFF374151),
        letterSpacing: 0.2,
      ),
    );
  }
}

class _StatGridRow extends StatelessWidget {
  final int count;
  final List<Map<String, dynamic>> items;

  const _StatGridRow({required this.count, required this.items});

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = Responsive.isDesktop(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = isDesktop ? 16.0 : 12.0;
        if (isDesktop) {
          return Row(
            children: items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: index == items.length - 1 ? 0 : spacing,
                  ),
                  child: _StatCard(
                    title: item['title'] as String,
                    value: item['value'] as String,
                    image: item['image'] as String,
                    color: item['color'] as Color,
                  ),
                ),
              );
            }).toList(),
          );
        }
        final width = (constraints.maxWidth - (spacing * (count - 1))) / count;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: items
              .map(
                (item) => _StatCard(
                  width: width.clamp(140.0, double.infinity),
                  title: item['title'] as String,
                  value: item['value'] as String,
                  image: item['image'] as String,
                  color: item['color'] as Color,
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final double? width;
  final String title;
  final String value;
  final String image;
  final Color color;

  const _StatCard({
    this.width,
    required this.title,
    required this.value,
    required this.image,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final bool isMobile = Responsive.isMobile(context);
    return Container(
      width: width,
      height: isMobile ? 140 : 150,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isMobile ? 18 : 20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: isMobile ? 14 : 20,
            spreadRadius: isMobile ? 1 : 2,
            offset: Offset(0, isMobile ? 4 : 8),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(isMobile ? 18 : 20),
            ),
            child: Container(
              height: isMobile ? 65 : 70,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [color.withOpacity(0.15), color.withOpacity(0.01)],
                ),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.elliptical(
                    isMobile ? 100 : 120,
                    isMobile ? 25 : 35,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: isMobile ? 16 : 18,
            child: SizedBox(
              width: isMobile ? 32 : 36,
              height: isMobile ? 32 : 36,
              child: Image.asset(
                image,
                color: color,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Icon(
                  Icons.leaderboard,
                  color: color,
                  size: isMobile ? 24 : 28,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: isMobile ? 12 : 14,
            child: Column(
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: isMobile ? 10 : 11,
                    color: const Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: isMobile ? 2 : 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: isMobile ? 18 : 20,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1F2937),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PageNumberButton extends StatefulWidget {
  final int page;
  final bool isActive;
  final VoidCallback? onTap;

  const _PageNumberButton({
    required this.page,
    required this.isActive,
    this.onTap,
  });

  @override
  State<_PageNumberButton> createState() => _PageNumberButtonState();
}

class _PageNumberButtonState extends State<_PageNumberButton> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: widget.isActive
                ? AppTheme.primaryColor
                : (isHovered ? const Color(0xFFF3F4F6) : Colors.white),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: widget.isActive
                  ? AppTheme.primaryColor
                  : const Color(0xFFE5E7EB),
            ),
          ),
          child: Text(
            '${widget.page}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: widget.isActive ? Colors.white : const Color(0xFF4B5563),
            ),
          ),
        ),
      ),
    );
  }
}

class _PaginationButton extends StatefulWidget {
  final VoidCallback? onTap;
  final IconData icon;
  final bool isDisabled;

  const _PaginationButton({
    required this.onTap,
    required this.icon,
    this.isDisabled = false,
  });

  @override
  State<_PaginationButton> createState() => _PaginationButtonState();
}

class _PaginationButtonState extends State<_PaginationButton> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.isDisabled
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      child: GestureDetector(
        onTap: widget.isDisabled ? null : widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: widget.isDisabled
                ? Colors.white
                : (isHovered ? const Color(0xFFF3F4F6) : Colors.white),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Icon(
            widget.icon,
            size: 18,
            color: widget.isDisabled
                ? const Color(0xFFD1D5DB)
                : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }
}
