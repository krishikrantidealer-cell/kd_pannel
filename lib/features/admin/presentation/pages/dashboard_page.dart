import 'package:flutter/material.dart';
import 'package:kd_pannel/app_theme.dart';
import 'package:kd_pannel/core/responsive/responsive.dart';
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

  final List<String> dropdownOptions = [
    'Last 1 Week',
    'Last 2 Weeks',
    'Last 3 Weeks',
    'Last 1 Month',
    'Last 3 Months',
    'Last 6 Months',
    'This Month',
  ];

  String get _rangeDisplay {
    if (_selectedRange != null && _selectedRange!.startDate != null && _selectedRange!.endDate != null) {
      final start = _selectedRange!.startDate!;
      final end = _selectedRange!.endDate!;
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
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
              if (val is PickerDateRange && val.startDate != null && val.endDate != null) {
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
  //

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = Responsive.isDesktop(context);
    return Material(
      color: Colors.white,
      child: SingleChildScrollView(
        child: Padding(
          padding: AppTheme.getResponsivePadding(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              isDesktop 
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'KrishiDealer Admin Dashboard',
                        style: TextStyle(
                          fontSize: 22, 
                          fontWeight: FontWeight.w500, 
                          color: Color(0xFF4B5563),
                        ),
                      ),
                      _buildFilterRow(),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          'Dashboard',
                          style: TextStyle(
                            fontSize: 16, 
                            fontWeight: FontWeight.w700, 
                            color: Color(0xFF1F2937),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildFilterRow(),
                    ],
                  ),
              const SizedBox(height: 28),

              _StatGridRow(
                count: isDesktop ? 4 : 2,
                items: [
                  {'title': 'Total Sales', 'value': '\$2,450', 'image': 'assets/images/Revenue.png', 'color': AppTheme.success},
                  {'title': 'Total Order', 'value': '32', 'image': 'assets/images/order today.png', 'color': AppTheme.lightGreen},
                  {'title': 'Total Dealers', 'value': '920', 'image': 'assets/images/Total dealer.png', 'color': AppTheme.info},
                  {'title': 'Total Leads', 'value': '24', 'image': 'assets/images/New leads.png', 'color': AppTheme.warning},
                ],
              ),
              const SizedBox(height: 32),

              if (isDesktop)
                LayoutBuilder(
                  builder: (context, constraints) {
                    final double totalWidth = constraints.maxWidth - 24;
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: totalWidth * 0.6,
                          child: const _SmallTableCard(
                            title: 'Recent Orders',
                            columns: ['Dealer', 'Product', 'Amount', 'Date', 'Status'],
                            rows: [
                              ['King Agro', 'Drip Irrigation', '\$2,400', '2023-10-24', 'Completed'],
                              ['Gupta Seeds', 'Hybrid Seeds', '\$650', '2023-10-24', 'Pending'],
                              ['Patel Agro', 'Pump', '\$1,150', '2023-10-23', 'Completed'],
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),
                        SizedBox(
                          width: totalWidth * 0.4,
                          child: const _SmallTableCard(
                            title: 'Recent Leads',
                            columns: ['Dealer Name', 'Contact Person', 'Created Time'],
                            rows: [
                              ['Choudhary Krishi', 'Nirmal', '2 hours ago'],
                              ['Greenway Agro', 'Priya', '5 hours ago'],
                              ['Shiva Ent.', 'Ravi', '3 days ago'],
                            ],
                          ),
                        ),
                      ],
                    );
                  }
                )
              else
                Column(
                  children: [
                    const _SmallTableCard(
                      title: 'Recent Orders',
                      columns: ['Dealer', 'Product', 'Amount', 'Date', 'Status'],
                      rows: [
                        ['King Agro', 'Drip Irrigation', '\$2,400', '2023-10-24', 'Completed'],
                        ['Gupta Seeds', 'Hybrid Seeds', '\$650', '2023-10-24', 'Pending'],
                        ['Patel Agro', 'Pump', '\$1,150', '2023-10-23', 'Completed'],
                      ],
                    ),
                    const SizedBox(height: 24),
                    const _SmallTableCard(
                      title: 'Recent Leads',
                      columns: ['Dealer Name', 'Contact Person', 'Created Time'],
                      rows: [
                        ['Choudhary Krishi', 'Nirmal', '2 hours ago'],
                        ['Greenway Agro', 'Priya', '5 hours ago'],
                        ['Shiva Ent.', 'Ravi', '3 days ago'],
                      ],
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterRow() {
    final bool isMobile = Responsive.isMobile(context);

    return Container(
      height: isMobile ? 38 : 48,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isMobile ? 10 : 14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: isMobile ? 8 : 14,
            spreadRadius: 1,
            offset: Offset(0, isMobile ? 2 : 4),
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
              child: Icon(Icons.calendar_month_outlined, size: isMobile ? 16 : 20, color: AppTheme.textSecondary),
            ),
          ),
          VerticalDivider(
            indent: isMobile ? 8 : 12,
            endIndent: isMobile ? 8 : 12,
            width: isMobile ? 16 : 24,
            color: const Color(0xFFE5E7EB),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: dropdownOptions.contains(selectedDropdown) ? selectedDropdown : null,
              isExpanded: false,
              hint: Text(_rangeDisplay, style: TextStyle(fontSize: isMobile ? 12 : 13, color: AppTheme.textBody, fontWeight: FontWeight.w500)),
              icon: Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Icon(Icons.keyboard_arrow_down, size: isMobile ? 16 : 18, color: AppTheme.textSecondary),
              ),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    selectedDropdown = newValue;
                    _selectedRange = null; // Dropdown selection overrides custom range
                  });
                }
              },
              items: dropdownOptions.map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value, style: TextStyle(fontSize: isMobile ? 12 : 13)),
                );
              }).toList(),
            ),
          ),
        ],
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
        final spacing = 16.0;

        if (isDesktop) {
          return Row(
            children: items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: index == items.length - 1 ? 0 : spacing),
                  child: StatCardWidget(
                    width: double.infinity,
                    title: item['title'],
                    value: item['value'],
                    subtext: item['subtext'],
                    imagePath: item['image'],
                    color: item['color'],
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
          children: items.map((item) => StatCardWidget(
            width: width.clamp(140.0, double.infinity),
            title: item['title'],
            value: item['value'],
            subtext: item['subtext'],
            imagePath: item['image'],
            color: item['color'],
          )).toList(),
        );
      },
    );
  }
}


class _SmallTableCard extends StatelessWidget {
  final String title;
  final List<String> columns;
  final List<List<String>> rows;

  const _SmallTableCard({required this.title, required this.columns, required this.rows});

  @override
  Widget build(BuildContext context) {
    final bool isMobile = Responsive.isMobile(context);

    return Container(
      padding: isMobile 
          ? const EdgeInsets.symmetric(horizontal: 6, vertical: 12) 
          : const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title, 
                  style: TextStyle(
                    fontSize: isMobile ? 15 : 16, 
                    fontWeight: FontWeight.w600, 
                    color: const Color(0xFF374151),
                    letterSpacing: isMobile ? 0.4 : 0.0,
                  ),
                ),
                const _ActionButton(text: 'View All', icon: Icons.chevron_right),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _BaseTable(columns: columns, rows: rows),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String text;
  final IconData icon;
  const _ActionButton({required this.text, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
          const SizedBox(width: 4),
          Icon(icon, size: 14, color: const Color(0xFF6B7280)),
        ],
      ),
    );
  }
}

class _BaseTable extends StatelessWidget {
  final List<String> columns;
  final List<List<String>> rows;
  const _BaseTable({required this.columns, required this.rows});

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = Responsive.isDesktop(context);
    final bool isMobile = Responsive.isMobile(context);

    Widget table = Table(
      columnWidths: const {
        0: FlexColumnWidth(2),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6), width: 1.5)),
            color: Color(0xFFF9FAFB),
          ),
          children: columns.map((c) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            child: _HeaderText(c),
          )).toList(),
        ),
        ...rows.asMap().entries.map((entry) {
          final index = entry.key;
          final row = entry.value;
          return TableRow(
            decoration: BoxDecoration(
              color: index % 2 == 1 ? const Color(0xFFF9FAFB) : Colors.white,
              border: const Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
            ),
            children: row.map((cell) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              child: _buildCell(cell),
            )).toList(),
          );
        }),
      ],
    );

    if (isDesktop) {
      return table;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final double minTableWidth = columns.length * 120.0;
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

  Widget _buildCell(String text) {
    if (text == 'Completed' || text == 'Pending') {
      return Center(child: _StatusBadge(status: text));
    }
    return Text(
      text, 
      style: const TextStyle(
        fontSize: 12, 
        color: Color(0xFF4B5563), 
        fontWeight: FontWeight.w500
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
      case 'Completed': bgColor = const Color(0xFF10B981); break;
      case 'Pending': bgColor = const Color(0xFFF59E0B); break;
      default: bgColor = const Color(0xFF3B82F6);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
      child: Text(
        status, 
        style: const TextStyle(
          fontSize: 9.5, 
          fontWeight: FontWeight.w700, 
          color: Colors.white, 
          letterSpacing: 0.1
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
        letterSpacing: 0.2
      ),
    );
  }
}
