import 'package:flutter/material.dart';
import 'package:kd_pannel/core/responsive/responsive.dart';
import 'package:kd_pannel/core/theme/app_colors.dart';
import 'package:kd_pannel/core/theme/app_typography.dart';

class OrderHistoryTable extends StatelessWidget {
  const OrderHistoryTable({super.key});

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.lightBorder, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(28),
            child: isMobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTitleSection(),
                      const SizedBox(height: 16),
                      _buildExportButton(),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: _buildTitleSection()),
                      const SizedBox(width: 16),
                      _buildExportButton(),
                    ],
                  ),
          ),
          _buildOrderTable(context, isMobile),
          const SizedBox(height: 24),
          _buildPagination(isMobile),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildTitleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text(
          'Order History',
          style: AppTypography.h3,
        ),
        SizedBox(height: 4),
        Text(
          'Complete record of dealer purchases',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.slate500,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildExportButton() {
    return OutlinedButton(
      onPressed: () {},
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: const BorderSide(color: AppColors.border),
      ),
      child: const Text(
        'Export CSV',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.slate700),
      ),
    );
  }

  Widget _buildOrderTable(BuildContext context, bool isMobile) {
    final table = Table(
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      columnWidths: const {
        0: FlexColumnWidth(1.2),
        1: FlexColumnWidth(2),
        2: FlexColumnWidth(1.2),
        3: FlexColumnWidth(1.2),
        4: FlexColumnWidth(1.5),
      },
      children: [
        TableRow(
          decoration: const BoxDecoration(
            color: AppColors.slate50,
            border: Border(
              bottom: BorderSide(color: AppColors.lightBorder, width: 1.0),
            ),
          ),
          children: [
            _headerCell('Order ID'),
            _headerCell('Products'),
            _headerCell('Date'),
            _headerCell('Amount'),
            _headerCell('Status', isCenter: true),
          ],
        ),
        _orderRow('#ORD-1024', 'NPK 19:19:19, Urea', '24 Oct 2023', '₹ 24,500', 'Completed', AppColors.success),
        _orderRow('#ORD-1021', 'Hybrid Seeds, Potash', '20 Oct 2023', '₹ 12,200', 'Pending', AppColors.warning),
        _orderRow('#ORD-1018', 'Drip Pipes, Filters', '15 Oct 2023', '₹ 45,000', 'Completed', AppColors.success),
        _orderRow('#ORD-1015', 'Water Soluble Fert.', '10 Oct 2023', '₹ 8,400', 'Cancelled', AppColors.danger),
        _orderRow('#ORD-1012', 'Pesticides, Spray', '05 Oct 2023', '₹ 15,600', 'Completed', AppColors.success),
      ],
    );

    if (!isMobile) return table;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: SizedBox(width: 700, child: table),
    );
  }

  Widget _headerCell(String text, {bool isCenter = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      child: isCenter
          ? Center(child: Text(text, style: _headerStyle))
          : Text(text, style: _headerStyle),
    );
  }

  static const _headerStyle = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w900,
    color: AppColors.slate500,
    letterSpacing: 0.5,
  );

  TableRow _orderRow(String id, String prod, String date, String amt, String status, Color statusColor) {
    return TableRow(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.lightBorder)),
      ),
      children: [
        _cell(id, isBold: true),
        _cell(prod),
        _cell(date),
        _cell(amt, isBold: true),
        Center(child: _statusBadge(status, statusColor)),
      ],
    );
  }

  Widget _cell(String text, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          color: isBold ? AppColors.slate900 : AppColors.slate700,
          fontWeight: isBold ? FontWeight.w800 : FontWeight.w500,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _statusBadge(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }

  Widget _buildPagination(bool isMobile) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: isMobile
          ? Column(
              children: [
                const Text(
                  'Showing 1 to 5 of 156 entries',
                  style: TextStyle(fontSize: 12, color: AppColors.slate500, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 16),
                _buildPaginationControls(),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Showing 1 to 5 of 156 entries',
                  style: TextStyle(fontSize: 13, color: AppColors.slate500, fontWeight: FontWeight.w500),
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
        _pbtn(Icons.chevron_left_rounded, false),
        const SizedBox(width: 8),
        _pnum(1, true),
        _pnum(2, false),
        _pnum(3, false),
        const SizedBox(width: 8),
        _pbtn(Icons.chevron_right_rounded, true),
      ],
    );
  }

  Widget _pbtn(IconData icon, bool enabled) => Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: enabled ? AppColors.slate700 : AppColors.slate300),
      );

  Widget _pnum(int n, bool active) => Container(
        width: 36,
        height: 36,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? AppColors.slate900 : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: active ? null : Border.all(color: AppColors.border),
        ),
        child: Text(
          '$n',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: active ? Colors.white : AppColors.slate700,
          ),
        ),
      );
}
