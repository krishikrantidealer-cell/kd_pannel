import 'package:flutter/material.dart';
import 'package:kd_pannel/core/responsive/responsive.dart';
import 'package:kd_pannel/core/theme/app_colors.dart';
import 'package:kd_pannel/core/theme/app_typography.dart';
import 'package:kd_pannel/core/theme/app_shadows.dart';

class DealerMetricsSection extends StatelessWidget {
  const DealerMetricsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);
    final isMobile = Responsive.isMobile(context);

    final items = [
      {
        'title': 'Total Orders',
        'value': '156',
        'icon': Icons.shopping_cart_rounded,
        'color': AppColors.primary,
      },
      {
        'title': 'Purchase Value',
        'value': '₹ 12.5L',
        'icon': Icons.account_balance_wallet_rounded,
        'color': AppColors.success,
      },
      {
        'title': 'Last Order',
        'value': '24 Oct 2023',
        'icon': Icons.event_available_rounded,
        'color': AppColors.secondary,
      },
      {
        'title': 'Active Since',
        'value': '2 Years',
        'icon': Icons.verified_user_rounded,
        'color': AppColors.warning,
      },
    ];

    if (isDesktop) {
      return Row(
        children: items
            .map(
              (item) => Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: item == items.last ? 0 : 20,
                  ),
                  child: _MetricCard(
                    title: item['title'] as String,
                    value: item['value'] as String,
                    icon: item['icon'] as IconData,
                    color: item['color'] as Color,
                  ),
                ),
              ),
            )
            .toList(),
      );
    }

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: isMobile ? 2 : 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: isMobile ? 0.85 : 1.6,
      children: items
          .map(
            (item) => _MetricCard(
              title: item['title'] as String,
              value: item['value'] as String,
              icon: item['icon'] as IconData,
              color: item['color'] as Color,
            ),
          )
          .toList(),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final padding = isMobile ? 14.0 : 20.0;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.lightBorder, width: 1.0),
        boxShadow: AppShadows.card,
      ),
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(isMobile ? 8 : 10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: isMobile ? 18 : 20, color: color),
          ),
          SizedBox(height: isMobile ? 12 : 16),
          Text(
            title,
            style: AppTypography.label.copyWith(
              fontSize: isMobile ? 7 : 7.5,
              letterSpacing: 0.5,
              color: AppColors.slate500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTypography.h3.copyWith(
              fontSize: isMobile ? 16 : 20,
              color: AppColors.slate900,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
