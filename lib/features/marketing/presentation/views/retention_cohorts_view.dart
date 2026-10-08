import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kd_pannel/app_theme.dart';
import 'package:kd_pannel/core/responsive/responsive.dart';
import 'package:kd_pannel/features/marketing/presentation/widgets/retention_matrix_widget.dart';

class RetentionCohortsView extends StatelessWidget {
  final String dateLabel;
  final VoidCallback onRefresh;

  const RetentionCohortsView({
    super.key,
    required this.dateLabel,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);

    final sampleCohorts = [
      const CohortRetentionRow(
        cohortName: 'Kharif Jun 2026',
        totalUsers: 1420,
        retentionPercentages: [100.0, 72.4, 58.1, 44.2, 38.0],
      ),
      const CohortRetentionRow(
        cohortName: 'Monsoon Jul 2026',
        totalUsers: 1890,
        retentionPercentages: [100.0, 68.9, 52.3, 39.5, 31.2],
      ),
      const CohortRetentionRow(
        cohortName: 'Harvest Aug 2026',
        totalUsers: 1650,
        retentionPercentages: [100.0, 75.1, 61.4, 48.0, 41.5],
      ),
      const CohortRetentionRow(
        cohortName: 'Rabi Pre-Season Sep 2026',
        totalUsers: 2100,
        retentionPercentages: [100.0, 81.2, 69.8, 55.4, 47.9],
      ),
    ];

    const periodLabels = ['Day 0', 'Week 1', 'Week 2', 'Month 1', 'Month 2'];

    return RepaintBoundary(
      child: ListView(
        padding: EdgeInsets.symmetric(
          horizontal: isDesktop ? 28 : 16,
          vertical: 16,
        ),
        physics: const BouncingScrollPhysics(),
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.grid_on_rounded,
                        color: AppTheme.primaryColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Agri-Dealer & Farmer Retention Cohort Matrix',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          'Seasonal reorder and repeat buyer retention over time ($dateLabel)',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, size: 20),
                      onPressed: onRefresh,
                      tooltip: 'Refresh Cohorts',
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                RetentionMatrixWidget(
                  cohorts: sampleCohorts,
                  periodLabels: periodLabels,
                  isLoading: false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
