import 'package:flutter/material.dart';

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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
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
                  color: Color(0xFF111827),
                ),
              ),
              InkWell(
                onTap: () {},
                child: const Row(
                  children: [
                    Text(
                      'View All',
                      style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
                    ),
                    Icon(Icons.chevron_right, size: 16, color: Colors.grey),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Table(
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              // Header Row
              TableRow(
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
                ),
                children: columns.map((col) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                  child: Text(
                    col,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                )).toList(),
              ),
              // Data Rows
              ...rows.map((row) => TableRow(
                children: row.asMap().entries.map((entry) {
                  final index = entry.key;
                  final cell = entry.value;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                    child: _buildCell(index, cell),
                  );
                }).toList(),
              )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCell(int index, String cell) {
    if (cell == 'FOLLOW_UP_BTN') {
      return UnconstrainedBox(
        alignment: Alignment.centerLeft,
        child: ElevatedButton(
          onPressed: () {},
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
          child: const Text('Follow Up', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        ),
      );
    }

    if (cell == 'Completed' || cell == 'Pending') {
      final isCompleted = cell == 'Completed';
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isCompleted ? const Color(0xFFECFDF5) : const Color(0xFFFFF7ED),
          borderRadius: BorderRadius.circular(12),
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
      style: const TextStyle(fontSize: 13, color: Color(0xFF374151)),
    );
  }
}
