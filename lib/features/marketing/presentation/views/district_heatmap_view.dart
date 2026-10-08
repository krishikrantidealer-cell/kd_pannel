import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kd_pannel/app_theme.dart';
import 'package:kd_pannel/core/responsive/responsive.dart';
import 'package:kd_pannel/features/marketing/domain/models/district_demand_data.dart';
import 'package:kd_pannel/features/marketing/presentation/widgets/agri_heatmap_widget.dart';

class DistrictHeatmapView extends StatelessWidget {
  final Future<List<Map<String, dynamic>>>? districtFuture;
  final String dateLabel;
  final VoidCallback onRefresh;

  const DistrictHeatmapView({
    super.key,
    required this.districtFuture,
    required this.dateLabel,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);

    return RepaintBoundary(
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: districtFuture,
        builder: (context, snapshot) {
          final isLoading = snapshot.connectionState == ConnectionState.waiting;
          final rawList = snapshot.data ?? [];

          final List<DistrictDemandData> districtData = rawList.map((d) {
            final int dealers = (d['registeredDealers'] is num)
                ? (d['registeredDealers'] as num).toInt()
                : ((d['activeDealers'] is num)
                    ? (d['activeDealers'] as num).toInt()
                    : ((d['uniqueUsers'] is num) ? (d['uniqueUsers'] as num).toInt() : 0));
            final int buyers = (d['activeBuyers'] is num)
                ? (d['activeBuyers'] as num).toInt()
                : ((d['ordersPlaced'] is num) ? (d['ordersPlaced'] as num).toInt() : 0);
            final double rev = (d['grossRevenueRupees'] is num)
                ? (d['grossRevenueRupees'] as num).toDouble()
                : ((d['totalRevenue'] is num) ? (d['totalRevenue'] as num).toDouble() : 0.0);
            final double rate = (d['conversionRate'] is num)
                ? (d['conversionRate'] as num).toDouble()
                : 0.0;
            final double sIndex = (d['searchVolumeIndex'] is num)
                ? (d['searchVolumeIndex'] as num).toDouble()
                : 50.0;
            final int orders = (d['orderCount'] is num)
                ? (d['orderCount'] as num).toInt()
                : buyers;

            return DistrictDemandData(
              stateName: (d['stateName'] ?? d['state'] ?? 'Madhya Pradesh').toString(),
              districtName: (d['districtName'] ?? d['district'] ?? d['name'] ?? 'Unknown').toString(),
              primaryCrop: (d['primaryCrop'] ?? d['topCategory'] ?? 'General Products').toString(),
              category: (d['category'] ?? 'General Products').toString(),
              subCategory: (d['subCategory'] ?? '').toString(),
              registeredDealers: dealers,
              activeBuyers: buyers,
              activeDealers: dealers > 0 ? dealers : buyers,
              searchVolumeIndex: sIndex,
              conversionRate: rate,
              grossRevenueRupees: rev,
              orderCount: orders,
            );
          }).toList();

          return Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 24 : 12,
              vertical: 12,
            ),
            child: AgriHeatmapWidget(
              districts: districtData,
              isLoading: isLoading,
            ),
          );
        },
      ),
    );
  }
}
