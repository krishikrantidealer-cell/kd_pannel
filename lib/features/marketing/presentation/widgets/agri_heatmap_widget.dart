import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kd_pannel/app_theme.dart';

class DistrictDemandData {
  final String districtName;
  final String stateName;
  final String primaryCrop;
  final int activeFarmers;
  final double searchVolumeIndex; // 0 - 100
  final double conversionRate; // %
  final double grossRevenueRupees;

  const DistrictDemandData({
    required this.districtName,
    required this.stateName,
    required this.primaryCrop,
    required this.activeFarmers,
    required this.searchVolumeIndex,
    required this.conversionRate,
    required this.grossRevenueRupees,
  });
}

String _formatCurrency(double rupees) {
  if (rupees >= 100000) {
    return '₹${(rupees / 100000).toStringAsFixed(2)}L';
  } else if (rupees >= 1000) {
    return '₹${(rupees / 1000).toStringAsFixed(1)}k';
  } else {
    return '₹${rupees.toStringAsFixed(0)}';
  }
}

class AgriHeatmapWidget extends StatelessWidget {
  final List<DistrictDemandData> districts;
  final bool isLoading;

  const AgriHeatmapWidget({
    super.key,
    required this.districts,
    this.isLoading = false,
  });

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

    if (districts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
          boxShadow: AppTheme.cardShadow,
          border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
        ),
        child: Column(
          children: [
            const Icon(Icons.location_off_rounded, size: 40, color: AppTheme.textSecondary),
            const SizedBox(height: 12),
            Text(
              'No Order Locations Recorded Yet',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'The regional heatmap populates automatically as orders are placed across districts.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
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
                    'Agricultural District & Crop Intelligence',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Regional Demand Concentration & Revenue Heatmap',
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
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on_rounded, size: 14, color: Colors.orange),
                    const SizedBox(width: 4),
                    Text(
                      'Geo-Targeting',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 600;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: districts.map((district) {
                  final double width = isWide
                      ? (constraints.maxWidth - 24) / 3
                      : (constraints.maxWidth - 12) / 2;

                  final Color intensityColor = district.searchVolumeIndex > 75
                      ? const Color(0xFFE65100)
                      : district.searchVolumeIndex > 50
                          ? const Color(0xFFF57C00)
                          : const Color(0xFFFFB74D);

                  return Container(
                    width: width,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              district.districtName,
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: intensityColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${district.searchVolumeIndex.toInt()} Index',
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: intensityColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${district.stateName} • ${district.primaryCrop}',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Revenue',
                                  style: GoogleFonts.outfit(
                                    fontSize: 10,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                                Text(
                                  _formatCurrency(district.grossRevenueRupees),
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Conversion',
                                  style: GoogleFonts.outfit(
                                    fontSize: 10,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                                Text(
                                  '${district.conversionRate.toStringAsFixed(1)}%',
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
