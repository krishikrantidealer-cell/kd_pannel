import 'package:flutter/material.dart';
import 'package:kd_pannel/app_theme.dart';
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
    return Material(
      color: Colors.white,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'KrishiDealer Admin Dashboard',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w500, color: Color(0xFF4B5563)),
                  ),
                  _buildFilterRow(),
                ],
              ),
              const SizedBox(height: 28),

              _StatGridRow(
                count: 5,
                items: [
                  {'title': 'Revenue Today', 'value': '\$2,450', 'image': 'assets/images/Revenue.png', 'color': AppTheme.success},
                  {'title': 'Orders Today', 'value': '32', 'image': 'assets/images/order today.png', 'color': AppTheme.lightGreen},
                  {'title': 'Total Dealers', 'value': '920', 'image': 'assets/images/Total dealer.png', 'color': AppTheme.info},
                  {'title': 'Active Dealers', 'value': '550', 'image': 'assets/images/Active dealer .png', 'color': AppTheme.teal},
                  {'title': 'New Leads', 'value': '24', 'image': 'assets/images/New leads.png', 'color': AppTheme.warning},
                ],
              ),
              const SizedBox(height: 20),
              const _StatGridRow(
                count: 4,
                items: [
                  {'title': 'Sales Performance', 'value': '74,200', 'subtext': 'Orders', 'image': 'assets/images/sales perfrom.png', 'color': AppTheme.success},
                  {'title': 'Dealer Onboarding', 'value': '320', 'subtext': 'Dealers Joined', 'image': 'assets/images/dealer onbord.png', 'color': AppTheme.lightGreen},
                  {'title': 'Order Status', 'value': '2,450', 'subtext': 'Total Orders', 'image': 'assets/images/order status.png', 'color': AppTheme.warning},
                  {'title': 'Pending Orders', 'value': '140', 'subtext': 'Orders Pending', 'image': 'assets/images/order pending.png', 'color': AppTheme.error},
                ],
              ),
              const SizedBox(height: 32),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(
                    flex: 3,
                    child: _SmallTableCard(
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
                  const Expanded(
                    flex: 2,
                    child: _SmallTableCard(
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterRow() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
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
              child: const Icon(Icons.calendar_month_outlined, size: 20, color: AppTheme.textSecondary),
            ),
          ),
          const VerticalDivider(
            indent: 12,
            endIndent: 12,
            width: 24,
            color: Color(0xFFE5E7EB),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: dropdownOptions.contains(selectedDropdown) ? selectedDropdown : null,
              hint: Text(_rangeDisplay, style: const TextStyle(fontSize: 13, color: AppTheme.textBody, fontWeight: FontWeight.w500)),
              icon: const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.keyboard_arrow_down, size: 18, color: AppTheme.textSecondary),
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
                  child: Text(value, style: const TextStyle(fontSize: 13)),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = 16.0;
        final width = (constraints.maxWidth - (spacing * (count - 1))) / count;
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: items.map((item) => _StatCard(
            width: width,
            title: item['title'],
            value: item['value'],
            subtext: item['subtext'],
            image: item['image'],
            color: item['color'],
          )).toList(),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final double width;
  final String title;
  final String value;
  final String? subtext;
  final String image;
  final Color color;

  const _StatCard({required this.width, required this.title, required this.value, this.subtext, required this.image, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width, height: 170,
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: Container(
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [color.withOpacity(0.15), color.withOpacity(0.01)]),
                borderRadius: const BorderRadius.vertical(bottom: Radius.elliptical(120, 35)),
              ),
            ),
          ),
          Positioned(
            top: 20,
            child: SizedBox(
              width: 42, height: 42,
              child: Image.asset(
                image,
                color: color,
                fit: BoxFit.contain,
              )
            )
          ),
          Positioned(
            bottom: 16,
            child: Column(
              children: [
                Text(title, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                if (subtext != null) Text(subtext!, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
              ],
            ),
          ),
        ],
      ),
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFF3F4F6))),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
              const _ActionButton(text: 'View All', icon: Icons.chevron_right),
            ],
          ),
          const SizedBox(height: 20),
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
    return Table(
      children: [
        TableRow(
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6), width: 1))),
          children: columns.map((c) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(c, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF9CA3AF))))).toList(),
        ),
        ...rows.map((r) => TableRow(children: r.map((cell) => Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: _buildCell(cell))).toList())),
      ],
    );
  }

  Widget _buildCell(String text) {
    if (text == 'Completed' || text == 'Pending') {
      bool isComp = text == 'Completed';
      return Align(alignment: Alignment.centerLeft, child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: isComp ? const Color(0xFFECFDF5) : const Color(0xFFFFF7ED), borderRadius: BorderRadius.circular(20)), child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: isComp ? const Color(0xFF10B981) : const Color(0xFFF59E0B)))));
    }
    return Text(text, style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563), fontWeight: FontWeight.w500));
  }
}
