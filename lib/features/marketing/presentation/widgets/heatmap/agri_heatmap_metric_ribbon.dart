import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kd_pannel/app_theme.dart';
import 'package:kd_pannel/features/marketing/domain/models/district_demand_data.dart';

class AgriHeatmapMetricRibbon extends StatelessWidget {
  final int displayedDistrictsCount;
  final int totalDistrictsCount;
  final String selectedProduct;
  final String selectedCategory;
  final double totalRevenue;
  final int totalDealers;
  final int totalRegisteredDealers;
  final int totalOrders;
  final double avgConversionRate;
  final String selectedActivityFilter;

  const AgriHeatmapMetricRibbon({
    super.key,
    required this.displayedDistrictsCount,
    required this.totalDistrictsCount,
    required this.selectedProduct,
    required this.selectedCategory,
    required this.totalRevenue,
    required this.totalDealers,
    required this.totalRegisteredDealers,
    required this.totalOrders,
    required this.avgConversionRate,
    required this.selectedActivityFilter,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor.withValues(alpha: 0.08),
            const Color(0xFF0288D1).withValues(alpha: 0.08),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.2),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Row(
              children: [
                Text(
                  'Districts Displayed: ',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textSecondary,
                  ),
                ),
                Text(
                  '$displayedDistrictsCount',
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryColor,
                  ),
                ),
                Text(
                  ' / $totalDistrictsCount',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textSecondary,
                  ),
                ),
                if (selectedProduct != 'All') ...[
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE65100),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.inventory_2_rounded,
                          size: 12,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          selectedProduct,
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (selectedCategory != 'All') ...[
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0288D1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.label_rounded,
                          size: 12,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          selectedCategory,
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(width: 24),
            Container(width: 1, height: 20, color: AppTheme.borderColor),
            const SizedBox(width: 18),
            Row(
              children: [
                Text(
                  selectedProduct != 'All'
                      ? 'PRODUCT REVENUE: '
                      : (selectedCategory == 'All'
                          ? 'TOTAL REVENUE: '
                          : 'CATEGORY REVENUE: '),
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  formatHeatmapCurrency(totalRevenue),
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.success,
                  ),
                ),
                const SizedBox(width: 18),
                Container(width: 1, height: 20, color: AppTheme.borderColor),
                const SizedBox(width: 18),
                Text(
                  selectedActivityFilter.startsWith('Untapped Only')
                      ? 'UNTAPPED DEALERS: '
                      : (selectedActivityFilter.startsWith('Active Only')
                          ? 'ACTIVE BUYERS: '
                          : 'ACTIVE DEALERS: '),
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  '$totalDealers',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(width: 18),
                Container(width: 1, height: 20, color: AppTheme.borderColor),
                const SizedBox(width: 18),
                Text(
                  'REGISTERED DEALERS: ',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  '$totalRegisteredDealers',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(width: 18),
                Container(width: 1, height: 20, color: AppTheme.borderColor),
                const SizedBox(width: 18),
                Text(
                  'TOTAL ORDERS: ',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  '$totalOrders',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFE65100),
                  ),
                ),
                const SizedBox(width: 18),
                Container(width: 1, height: 20, color: AppTheme.borderColor),
                const SizedBox(width: 18),
                Text(
                  'AVG CONVERSION: ',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  '${avgConversionRate.toStringAsFixed(1)}%',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF7B1FA2),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
