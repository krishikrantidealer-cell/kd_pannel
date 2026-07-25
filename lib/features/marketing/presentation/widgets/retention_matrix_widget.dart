import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kd_pannel/app_theme.dart';

class CohortRetentionRow {
  final String cohortName; // e.g. "Kharif Jun 2026", "Rabi Oct 2025"
  final int totalUsers;
  final List<double> retentionPercentages; // e.g. [100.0, 64.2, 48.1, 35.0, 28.4]

  const CohortRetentionRow({
    required this.cohortName,
    required this.totalUsers,
    required this.retentionPercentages,
  });
}

class RetentionMatrixWidget extends StatelessWidget {
  final List<CohortRetentionRow> cohorts;
  final List<String> periodLabels; // e.g. ["Day 0", "Week 1", "Week 2", "Month 1", "Month 2"]
  final bool isLoading;

  const RetentionMatrixWidget({
    super.key,
    required this.cohorts,
    required this.periodLabels,
    this.isLoading = false,
  });

  Color _getRetentionColor(double percentage) {
    if (percentage >= 80) return const Color(0xFF1B5E20);
    if (percentage >= 60) return const Color(0xFF2E7D32);
    if (percentage >= 40) return const Color(0xFF4CAF50);
    if (percentage >= 20) return const Color(0xFF81C784);
    if (percentage > 0) return const Color(0xFFC8E6C9);
    return Colors.grey.shade100;
  }

  Color _getRetentionTextColor(double percentage) {
    return percentage >= 40 ? Colors.white : Colors.black87;
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Container(
        height: 280,
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
          border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryColor),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        boxShadow: AppTheme.cardShadow,
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cohort Retention Heatmap Matrix',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Farmer & Dealer Repeat Ordering Behavior Over Time',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Seasonal Cohort Tracking',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.purple.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 16,
              horizontalMargin: 8,
              headingRowHeight: 36,
              dataRowMinHeight: 40,
              dataRowMaxHeight: 44,
              columns: [
                DataColumn(
                  label: Text(
                    'Cohort',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Size',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                ...periodLabels.map(
                  (label) => DataColumn(
                    label: Text(
                      label,
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                ),
              ],
              rows: cohorts.map((cohort) {
                return DataRow(
                  cells: [
                    DataCell(
                      Text(
                        cohort.cohortName,
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        '${cohort.totalUsers}',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                    ...List.generate(periodLabels.length, (idx) {
                      final p = idx < cohort.retentionPercentages.length
                          ? cohort.retentionPercentages[idx]
                          : 0.0;
                      final bgColor = _getRetentionColor(p);
                      final textColor = _getRetentionTextColor(p);

                      return DataCell(
                        Container(
                          width: 54,
                          height: 32,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: bgColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            p > 0 ? '${p.toStringAsFixed(0)}%' : '-',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
