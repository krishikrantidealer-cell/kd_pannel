import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kd_pannel/app_theme.dart';
import 'package:kd_pannel/features/marketing/domain/models/district_demand_data.dart';

class DistrictIntelligenceCard extends StatelessWidget {
  final DistrictDemandData district;
  final double width;
  final String breakdownMode;
  final String selectedProduct;
  final String selectedCategory;
  final String selectedActivityFilter;
  final Map<String, double> Function(DistrictDemandData) getEffectiveProductBreakdown;
  final Map<String, double> Function(DistrictDemandData) getEffectiveCategoryBreakdown;
  final Map<String, double> Function(DistrictDemandData) getEffectiveSubCategoryBreakdown;

  const DistrictIntelligenceCard({
    super.key,
    required this.district,
    required this.width,
    required this.breakdownMode,
    required this.selectedProduct,
    required this.selectedCategory,
    required this.selectedActivityFilter,
    required this.getEffectiveProductBreakdown,
    required this.getEffectiveCategoryBreakdown,
    required this.getEffectiveSubCategoryBreakdown,
  });

  @override
  Widget build(BuildContext context) {
    final bool isHighDemand = district.searchVolumeIndex > 75;
    final bool isMedDemand = district.searchVolumeIndex > 50;

    final List<Color> topGradient = isHighDemand
        ? [const Color(0xFFFF5722), const Color(0xFFF4511E)]
        : (isMedDemand
            ? [const Color(0xFFFF9800), const Color(0xFFFB8C00)]
            : [const Color(0xFF2E7D32), const Color(0xFF43A047)]);

    final Color convColor = district.conversionRate >= 50.0
        ? const Color(0xFF2E7D32)
        : (district.conversionRate >= 25.0
            ? const Color(0xFF0288D1)
            : const Color(0xFFE65100));

    final Map<String, double> activeBreakdownMap = breakdownMode == 'Product'
        ? getEffectiveProductBreakdown(district)
        : (breakdownMode == 'SubCategory'
            ? getEffectiveSubCategoryBreakdown(district)
            : getEffectiveCategoryBreakdown(district));

    return Container(
      width: width,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // High-Impact Demand Gradient Strip
          Container(
            height: 4,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: topGradient),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. District Name & Volume Index Pill
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        district.districtName,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: topGradient.first.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: topGradient.first.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isHighDemand
                                ? Icons.local_fire_department_rounded
                                : (isMedDemand
                                    ? Icons.trending_up_rounded
                                    : Icons.check_circle_rounded),
                            size: 13,
                            color: topGradient.first,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${district.searchVolumeIndex.toInt()} Index',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: topGradient.first,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // 2. State & Category Badge
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_rounded,
                      size: 13,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      district.stateName,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '•',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          district.category,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // 3. Breakdown View Mode or Standard Metrics
                if (breakdownMode != 'None') ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.cardColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              breakdownMode == 'Product'
                                  ? Icons.inventory_2_rounded
                                  : (breakdownMode == 'SubCategory'
                                      ? Icons.folder_rounded
                                      : Icons.label_rounded),
                              size: 13,
                              color: AppTheme.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              breakdownMode == 'Product'
                                  ? 'TOP PRODUCT DEMAND SHARE'
                                  : (breakdownMode == 'SubCategory'
                                      ? 'SUBCATEGORY REVENUE SHARE'
                                      : 'CATEGORY REVENUE SHARE'),
                              style: GoogleFonts.outfit(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textSecondary,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...activeBreakdownMap.entries.map((entry) {
                          final total = district.grossRevenueRupees > 0
                              ? district.grossRevenueRupees
                              : 1;
                          final pct = ((entry.value / total) * 100).clamp(5.0, 100.0);
                          final color = breakdownMode == 'Product'
                              ? const Color(0xFFE65100)
                              : (breakdownMode == 'SubCategory'
                                  ? const Color(0xFF7B1FA2)
                                  : AppTheme.primaryColor);

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        entry.key,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.outfit(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.textPrimary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      formatHeatmapCurrency(entry.value),
                                      style: GoogleFonts.outfit(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w800,
                                        color: color,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(3),
                                  child: LinearProgressIndicator(
                                    value: pct / 100,
                                    minHeight: 5,
                                    backgroundColor: color.withValues(alpha: 0.12),
                                    valueColor: AlwaysStoppedAnimation<Color>(color),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ] else ...[
                  // Standard Overview Metrics Block
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.cardColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              selectedProduct != 'All'
                                  ? 'PRODUCT REVENUE'
                                  : (selectedCategory == 'All'
                                      ? 'TOTAL REVENUE'
                                      : 'CATEGORY REVENUE'),
                              style: GoogleFonts.outfit(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textSecondary,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              formatHeatmapCurrency(
                                selectedProduct != 'All'
                                    ? (getEffectiveProductBreakdown(district)[selectedProduct] ??
                                        district.grossRevenueRupees)
                                    : (selectedCategory == 'All'
                                        ? district.grossRevenueRupees
                                        : (getEffectiveCategoryBreakdown(district)[selectedCategory] ??
                                            district.grossRevenueRupees)),
                              ),
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE65100).withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFFE65100).withValues(alpha: 0.2),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'ORDERS',
                                    style: GoogleFonts.outfit(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFFE65100),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.shopping_cart_rounded,
                                        size: 13,
                                        color: Color(0xFFE65100),
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        '${district.orderCount}',
                                        style: GoogleFonts.outfit(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFFE65100),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.blue.withValues(alpha: 0.2),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    selectedActivityFilter.startsWith('Untapped Only')
                                        ? 'UNTAPPED'
                                        : 'DEALERS',
                                    style: GoogleFonts.outfit(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.blue.shade800,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.storefront_rounded,
                                        size: 13,
                                        color: Colors.blue,
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        selectedActivityFilter.startsWith('Untapped Only')
                                            ? '${(district.registeredDealers - district.activeBuyers).clamp(0, 9999)} / ${district.registeredDealers}'
                                            : '${district.activeBuyers > 0 ? district.activeBuyers : district.activeDealers} / ${district.registeredDealers > 0 ? district.registeredDealers : (district.activeBuyers > 0 ? district.activeBuyers : district.activeDealers)}',
                                        style: GoogleFonts.outfit(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.blue.shade900,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 10),

                // 4. Dealer Conversion Rate Gauge Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: convColor.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: convColor.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.stars_rounded,
                                size: 14,
                                color: convColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Dealer Order Conversion',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '${district.conversionRate.toStringAsFixed(1)}%',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: convColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: (district.conversionRate / 100).clamp(0.02, 1.0),
                          minHeight: 4,
                          backgroundColor: convColor.withValues(alpha: 0.12),
                          valueColor: AlwaysStoppedAnimation<Color>(convColor),
                        ),
                      ),
                    ],
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
