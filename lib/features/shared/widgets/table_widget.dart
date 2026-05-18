import 'package:flutter/material.dart';
import 'package:kd_pannel/app_theme.dart';

class TableWidget extends StatelessWidget {
  final String title;
  final List<String> columns;
  final List<List<String>> rows;

  const TableWidget({
    super.key,
    required this.title,
    required this.columns,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppTheme.spacingXLarge - 12), // 20
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              InkWell(
                onTap: () {},
                child: const Row(
                  children: [
                    Text(
                      'View All',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Icon(Icons.chevron_right, size: 16, color: Colors.grey),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: AppTheme.spacingMedium),
          _buildTable(context),
        ],
      ),
    );
  }

  Widget _buildTable(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width >= 1200;

    Widget table = Table(
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        // Header Row
        TableRow(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppTheme.lightBorderColor)),
          ),
          children: columns
              .map((col) => Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: AppTheme.spacingXSmall,
                    ),
                    child: Text(
                      col,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ))
              .toList(),
        ),
        // Data Rows
        ...rows.map((row) => TableRow(
              children: row.asMap().entries.map((entry) {
                final index = entry.key;
                final cell = entry.value;

                return Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: AppTheme.spacingXSmall,
                  ),
                  child: _buildCell(index, cell),
                );
              }).toList(),
            )),
      ],
    );

    if (isDesktop) {
      return table;
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 500),
        child: table,
      ),
    );
  }

  Widget _buildCell(int index, String cell) {
    if (cell == 'FOLLOW_UP_BTN') {
      return ElevatedButton(
        onPressed: () {},
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.warning,
          foregroundColor: AppTheme.cardColor,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        child: const Text(
          'Follow Up',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
        ),
      );
    }

    if (cell == 'Completed' || cell == 'Pending') {
      final isCompleted = cell == 'Completed';
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isCompleted ? const Color(0xFFECFDF5) : const Color(0xFFFFF7ED),
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
        ),
        child: Text(
          cell,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: isCompleted ? const Color(0xFF059669) : const Color(0xFFD97706),
          ),
        ),
      );
    }

    return Text(
      cell,
      style: TextStyle(fontSize: 13, color: AppTheme.textBody),
    );
  }
}
