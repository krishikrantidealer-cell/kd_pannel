import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kd_pannel/app_theme.dart';
import 'package:kd_pannel/core/responsive/responsive.dart';
import 'package:kd_pannel/features/marketing/presentation/widgets/funnel_chart_widget.dart';
import 'package:kd_pannel/features/shared/widgets/events/event_metric_cards.dart';

class TelemetryOverviewView extends StatelessWidget {
  final Future<List<Map<String, dynamic>>>? funnelFuture;
  final int liveUsersCount;
  final int abandonedCartsCount;
  final int failedPaymentsCount;
  final int highPriorityCount;
  final String activeTimeRange;
  final String dateLabel;
  final VoidCallback onRefresh;
  final ValueChanged<String>? onFilterSelected;

  const TelemetryOverviewView({
    super.key,
    required this.funnelFuture,
    required this.liveUsersCount,
    required this.abandonedCartsCount,
    required this.failedPaymentsCount,
    required this.highPriorityCount,
    required this.activeTimeRange,
    required this.dateLabel,
    required this.onRefresh,
    this.onFilterSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);

    return RepaintBoundary(
      child: ListView(
        padding: EdgeInsets.symmetric(
          horizontal: isDesktop ? 28 : 16,
          vertical: 16,
        ),
        physics: const BouncingScrollPhysics(),
        children: [
          // 1. High Priority Metric Cards
          EventMetricCards(
            liveUsers: liveUsersCount,
            abandonedCarts: abandonedCartsCount,
            failedPayments: failedPaymentsCount,
            highPriorityCount: highPriorityCount,
            selectedFilter: 'All',
            onFilterChanged: (filter) => onFilterSelected?.call(filter),
          ),
          const SizedBox(height: 24),

          // 2. Funnel Analysis Section
          FutureBuilder<List<Map<String, dynamic>>>(
            future: funnelFuture,
            builder: (context, snapshot) {
              final isLoading = snapshot.connectionState == ConnectionState.waiting;
              final data = snapshot.data ?? [];

              final steps = data.map((d) {
                final name = (d['stepName'] ?? d['name'] ?? 'Step').toString();
                final userCount = (d['userCount'] ?? d['count'] ?? 0) as int;
                final eventCount = (d['eventCount'] ?? userCount) as int;
                final rate = (d['conversionRate'] ?? d['rate'] ?? 100.0) as num;

                return FunnelStepData(
                  stepName: name,
                  userCount: userCount,
                  eventCount: eventCount,
                  conversionRate: rate.toDouble(),
                  stepColor: _getStepColor(name),
                );
              }).toList();

              return Container(
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
                            Icons.filter_alt_rounded,
                            color: AppTheme.primaryColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Customer Journey Conversion Funnel',
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            Text(
                              'Visualizing user progression and drop-offs across funnel stages ($dateLabel)',
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
                          tooltip: 'Reload Funnel Data',
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    FunnelChartWidget(
                      steps: steps.isNotEmpty ? steps : _getDefaultFunnelSteps(),
                      isLoading: isLoading,
                      onStepSelected: (stepName) => onFilterSelected?.call(stepName),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 28),
        ],
      ),
    );
  }

  Color _getStepColor(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('launch') || lower.contains('visit')) return const Color(0xFF3B82F6);
    if (lower.contains('search') || lower.contains('view')) return const Color(0xFF06B6D4);
    if (lower.contains('cart')) return const Color(0xFFF59E0B);
    if (lower.contains('checkout')) return const Color(0xFF8B5CF6);
    if (lower.contains('order') || lower.contains('pay')) return const Color(0xFF10B981);
    return AppTheme.primaryColor;
  }

  List<FunnelStepData> _getDefaultFunnelSteps() {
    return const [
      FunnelStepData(
        stepName: 'App Launch / Visit',
        userCount: 1240,
        eventCount: 3890,
        conversionRate: 100.0,
        stepColor: Color(0xFF3B82F6),
      ),
      FunnelStepData(
        stepName: 'Product Search & Browse',
        userCount: 860,
        eventCount: 2450,
        conversionRate: 69.3,
        stepColor: Color(0xFF06B6D4),
      ),
      FunnelStepData(
        stepName: 'Added to Cart',
        userCount: 420,
        eventCount: 980,
        conversionRate: 33.8,
        stepColor: Color(0xFFF59E0B),
      ),
      FunnelStepData(
        stepName: 'Initiated Checkout',
        userCount: 290,
        eventCount: 410,
        conversionRate: 23.4,
        stepColor: Color(0xFF8B5CF6),
      ),
      FunnelStepData(
        stepName: 'Completed Order',
        userCount: 185,
        eventCount: 205,
        conversionRate: 14.9,
        stepColor: Color(0xFF10B981),
      ),
    ];
  }
}
