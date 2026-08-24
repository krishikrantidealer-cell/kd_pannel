import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kd_pannel/app_theme.dart';
import 'package:kd_pannel/features/shared/widgets/advanced_stat_card_widget.dart';

/// Reusable responsive Sales Stats Grid displaying orders, leads, and dealers.
class SalesStatsGrid extends StatelessWidget {
  final int leadsCount;
  final int dealersCount;
  final int ordersCount;
  final List<double>? leadsSparklineData;
  final double fulfillmentPercent;

  const SalesStatsGrid({
    super.key,
    required this.leadsCount,
    required this.dealersCount,
    required this.ordersCount,
    this.leadsSparklineData,
    this.fulfillmentPercent = 0.75,
  });

  @override
  Widget build(BuildContext context) {
    final sparkline = (leadsSparklineData != null && leadsSparklineData!.length >= 2)
        ? leadsSparklineData!
        : [20.0, 18.0, 25.0, 22.0, 30.0, 28.0, (leadsCount > 0 ? leadsCount.toDouble() : 35.0)];

    return LayoutBuilder(
      builder: (context, constraints) {
        int columns = 1;
        if (constraints.maxWidth > 900) {
          columns = 3;
        } else if (constraints.maxWidth > 600) {
          columns = 2;
        }

        const double spacing = 16.0;
        final double width =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            AdvancedStatCardWidget(
              width: width,
              title: 'Active Orders',
              value: '$ordersCount',
              color: AppTheme.accentColor,
              trendLabel: 'Assigned to you',
              trendIcon: Icons.shopping_bag_outlined,
              visualWidget: SizedBox(
                width: 24,
                height: 24,
                child: CustomPaint(
                  painter: FulfillmentProgressPainter(
                    fulfillmentPercent,
                    AppTheme.accentColor,
                  ),
                ),
              ),
            ),
            AdvancedStatCardWidget(
              width: width,
              title: 'Qualified Leads',
              value: '$leadsCount',
              color: AppTheme.info,
              trendLabel: 'Prospect pipeline',
              trendIcon: Icons.person_add_outlined,
              visualWidget: SizedBox(
                width: 50,
                height: 24,
                child: CustomPaint(
                  painter: SparklinePainter(
                    sparkline,
                    AppTheme.info,
                  ),
                ),
              ),
            ),
            AdvancedStatCardWidget(
              width: width,
              title: 'Your Dealers',
              value: '$dealersCount',
              color: AppTheme.primaryColor,
              trendLabel: 'Verified accounts',
              trendIcon: Icons.verified_user_outlined,
              visualWidget: _buildAvatarCluster(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAvatarCluster() {
    return SizedBox(
      width: 72,
      height: 24,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          _buildAvatarCircle('AD', AppTheme.primaryColor, 0),
          _buildAvatarCircle('PK', AppTheme.accentColor, 15),
          _buildAvatarCircle('RK', AppTheme.info, 30),
        ],
      ),
    );
  }

  Widget _buildAvatarCircle(String text, Color color, double left) {
    return Positioned(
      left: left,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.5),
          color: color.withValues(alpha: 0.1),
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: GoogleFonts.outfit(
            fontSize: 8,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ),
    );
  }
}
