import 'package:flutter/material.dart';
import 'package:kd_pannel/app_theme.dart';
import '../widgets/table_widget.dart';

class SalesDashboardPage extends StatelessWidget {
  const SalesDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingLarge),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'KrishiDealer Sales Dashboard',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.cardColor,
                  borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.calendar_today_outlined, size: 14, color: AppTheme.textSecondary),
                    SizedBox(width: AppTheme.spacingSmall),
                    Text(
                      'This Month',
                      style: TextStyle(fontSize: 12, color: AppTheme.textBody, fontWeight: FontWeight.w500),
                    ),
                    SizedBox(width: AppTheme.spacingXSmall),
                    Icon(Icons.keyboard_arrow_down, size: 14, color: AppTheme.textSecondary),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingLarge),
          const _SalesStatsGrid(),
          const SizedBox(height: AppTheme.spacingLarge),
          const TableWidget(
            title: "Today's Follow Ups",
            columns: ['Dealer Name', 'Phone', 'Last Contact', 'Next Follow Up'],
            rows: [
              ['Anil Kumar', '+91 9876543210', '24 Oct, 2023', 'FOLLOW_UP_BTN'],
              ['Sunil Sharma', '+91 8765432109', '23 Oct, 2023', 'FOLLOW_UP_BTN'],
              ['Rajesh Gupta', '+91 7654321098', '22 Oct, 2023', 'FOLLOW_UP_BTN'],
            ],
          ),
          const SizedBox(height: 20),
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
        final double width = (constraints.maxWidth - (spacing * 4)) / 5;
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _SalesStatCard(width: width, title: 'My Leads', value: '1,240', icon: Icons.person_add_outlined, color: AppTheme.info),
            _SalesStatCard(width: width, title: 'New Leads Today', value: '24', icon: Icons.campaign_outlined, color: AppTheme.warning),
            _SalesStatCard(width: width, title: 'My Dealers', value: '850', icon: Icons.storefront_outlined, color: AppTheme.primaryColor),
            _SalesStatCard(width: width, title: 'Orders Created Today', value: '12', icon: Icons.shopping_bag_outlined, color: Colors.purple),
            _SalesStatCard(width: width, title: 'Pending KYC', value: '45', icon: Icons.verified_user_outlined, color: AppTheme.error),
          ],
        );
      },
    );
  }
}

class _SalesStatCard extends StatelessWidget {
  final double width;
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _SalesStatCard({
    required this.width,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 180,
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusXLarge),
        boxShadow: AppTheme.softShadow,
      ),
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppTheme.borderRadiusXLarge)),
            child: Container(
              width: double.infinity,
              height: 95,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    color.withOpacity(0.25),
                    color.withOpacity(0.05),
                  ],
                ),
                borderRadius: const BorderRadius.vertical(bottom: Radius.elliptical(150, 40)),
              ),
            ),
          ),
          Positioned(
            top: 25,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.cardColor, width: 2),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
          ),
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
