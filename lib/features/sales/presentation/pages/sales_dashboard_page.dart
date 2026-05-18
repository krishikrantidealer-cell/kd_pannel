import 'package:flutter/material.dart';
import 'package:kd_pannel/app_theme.dart';
import 'package:kd_pannel/core/responsive/responsive.dart';
import 'package:kd_pannel/features/shared/widgets/stat_card_widget.dart';
import 'package:kd_pannel/features/shared/widgets/table_widget.dart';

class SalesDashboardPage extends StatelessWidget {
  const SalesDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = Responsive.isDesktop(context);
    final double gap = AppTheme.getResponsiveGap(context);

    return SingleChildScrollView(
      padding: AppTheme.getResponsivePadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  isDesktop
                      ? 'KrishiDealer Sales Dashboard'
                      : 'Sales Dashboard',
                  style: TextStyle(
                    fontSize: isDesktop ? 22 : 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.cardColor,
                  borderRadius: BorderRadius.circular(
                    AppTheme.borderRadiusSmall,
                  ),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 14,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(width: AppTheme.spacingSmall),
                    Text(
                      'This Month',
                      style: TextStyle(
                        fontSize: isDesktop ? 12 : 11,
                        color: AppTheme.textBody,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacingXSmall),
                    const Icon(
                      Icons.keyboard_arrow_down,
                      size: 14,
                      color: AppTheme.textSecondary,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: gap),
          const _SalesStatsGrid(),
          SizedBox(height: gap),
          const TableWidget(
            title: "Today's Follow Ups",
            columns: ['Dealer Name', 'Phone', 'Last Contact', 'Next Follow Up'],
            rows: [
              ['Anil Kumar', '+91 9876543210', '24 Oct, 2023', 'FOLLOW_UP_BTN'],
              [
                'Sunil Sharma',
                '+91 8765432109',
                '23 Oct, 2023',
                'FOLLOW_UP_BTN',
              ],
              [
                'Rajesh Gupta',
                '+91 7654321098',
                '22 Oct, 2023',
                'FOLLOW_UP_BTN',
              ],
            ],
          ),
          SizedBox(height: gap),
          if (isDesktop)
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TableWidget(
                    title: "Recent Leads (detailed)",
                    columns: ['Dealer Name', 'Contact', 'Status', 'Date'],
                    rows: [
                      ['Vikas Enterprises', 'Vikas Singh', 'Pending', '24 Oct'],
                      ['Agro World', 'Emily White', 'Completed', '23 Oct'],
                      ['Krishi Store', 'Rahul Dev', 'Pending', '22 Oct'],
                    ],
                  ),
                ),
                SizedBox(width: 20),
                Expanded(
                  child: TableWidget(
                    title: "Orders Created",
                    columns: ['Order ID', 'Product', 'Amount', 'Status'],
                    rows: [
                      ['#7890', 'Fertilizer', '\$450', 'Completed'],
                      ['#7891', 'Seeds', '\$120', 'Pending'],
                      ['#7892', 'Pumps', '\$800', 'Completed'],
                    ],
                  ),
                ),
              ],
            )
          else
            Column(
              children: [
                const TableWidget(
                  title: "Recent Leads (detailed)",
                  columns: ['Dealer Name', 'Contact', 'Status', 'Date'],
                  rows: [
                    ['Vikas Enterprises', 'Vikas Singh', 'Pending', '24 Oct'],
                    ['Agro World', 'Emily White', 'Completed', '23 Oct'],
                    ['Krishi Store', 'Rahul Dev', 'Pending', '22 Oct'],
                  ],
                ),
                SizedBox(height: gap),
                const TableWidget(
                  title: "Orders Created",
                  columns: ['Order ID', 'Product', 'Amount', 'Status'],
                  rows: [
                    ['#7890', 'Fertilizer', '\$450', 'Completed'],
                    ['#7891', 'Seeds', '\$120', 'Pending'],
                    ['#7892', 'Pumps', '\$800', 'Completed'],
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _SalesStatsGrid extends StatelessWidget {
  const _SalesStatsGrid();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double spacing = AppTheme.spacingMedium;
        final int columns;
        if (constraints.maxWidth >= 1200) {
          columns = 5;
        } else if (constraints.maxWidth >= 768) {
          columns = 3;
        } else {
          columns = 2; // Mobile
        }

        final double width =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            StatCardWidget(
              width: width,
              title: 'My Leads',
              value: '1,240',
              icon: Icons.person_add_outlined,
              color: AppTheme.info,
            ),
            StatCardWidget(
              width: width,
              title: 'New Leads Today',
              value: '24',
              icon: Icons.campaign_outlined,
              color: AppTheme.warning,
            ),
            StatCardWidget(
              width: width,
              title: 'My Dealers',
              value: '850',
              icon: Icons.storefront_outlined,
              color: AppTheme.primaryColor,
            ),
            StatCardWidget(
              width: width,
              title: 'Orders Created Today',
              value: '12',
              icon: Icons.shopping_bag_outlined,
              color: Colors.purple,
            ),
            StatCardWidget(
              width: width,
              title: 'Pending KYC',
              value: '45',
              icon: Icons.verified_user_outlined,
              color: AppTheme.error,
            ),
          ],
        );
      },
    );
  }
}
