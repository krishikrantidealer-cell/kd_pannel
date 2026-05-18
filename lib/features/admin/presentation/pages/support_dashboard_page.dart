import 'package:flutter/material.dart';
import 'package:kd_pannel/app_theme.dart';
import 'package:kd_pannel/core/responsive/responsive.dart';
import 'package:kd_pannel/features/shared/widgets/table_widget.dart';

class SupportDashboardPage extends StatelessWidget {
  const SupportDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = Responsive.isDesktop(context);

    return SingleChildScrollView(
      padding: AppTheme.getResponsivePadding(context),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double halfWidth = (constraints.maxWidth - 20) / 2;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Support Dashboard',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              SizedBox(height: AppTheme.spacingLarge),
              const _SupportStatsGrid(),
              SizedBox(height: AppTheme.spacingLarge),
              if (isDesktop)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: halfWidth,
                      child: const TableWidget(
                        title: "Dealer Support Requests",
                        columns: ['Dealer Name', 'Issue Type', 'Status', 'Date'],
                        rows: [
                          ['Anil Kumar', 'KYC Pending', 'Pending', '24 Oct'],
                          ['Sunil Sharma', 'Payment Issue', 'Completed', '23 Oct'],
                          ['Rajesh Gupta', 'Account Access', 'Pending', '22 Oct'],
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    SizedBox(
                      width: halfWidth,
                      child: const TableWidget(
                        title: "Order Support Requests",
                        columns: ['Order ID', 'Issue', 'Status', 'Date'],
                        rows: [
                          ['#ORD-7890', 'Delivery Delayed', 'Pending', '24 Oct'],
                          ['#ORD-7891', 'Wrong Product', 'Completed', '23 Oct'],
                          ['#ORD-7892', 'Refund Request', 'Pending', '22 Oct'],
                        ],
                      ),
                    ),
                  ],
                )
              else
                const Column(
                  children: [
                    TableWidget(
                      title: "Dealer Support Requests",
                      columns: ['Dealer Name', 'Issue Type', 'Status', 'Date'],
                      rows: [
                        ['Anil Kumar', 'KYC Pending', 'Pending', '24 Oct'],
                        ['Sunil Sharma', 'Payment Issue', 'Completed', '23 Oct'],
                        ['Rajesh Gupta', 'Account Access', 'Pending', '22 Oct'],
                      ],
                    ),
                    SizedBox(height: 20),
                    TableWidget(
                      title: "Order Support Requests",
                      columns: ['Order ID', 'Issue', 'Status', 'Date'],
                      rows: [
                        ['#ORD-7890', 'Delivery Delayed', 'Pending', '24 Oct'],
                        ['#ORD-7891', 'Wrong Product', 'Completed', '23 Oct'],
                        ['#ORD-7892', 'Refund Request', 'Pending', '22 Oct'],
                      ],
                    ),
                  ],
                ),
            ],
          );
        }
      ),
    );
  }
}

class _SupportStatsGrid extends StatelessWidget {
  const _SupportStatsGrid();

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = Responsive.isDesktop(context);
    final bool isMobile = Responsive.isMobile(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final double spacing = AppTheme.spacingMedium;

        if (isDesktop) {
          final double cardWidth = (constraints.maxWidth - (spacing * 3)) / 4;
          return Row(
            children: [
              _SupportStatCard(width: cardWidth, title: 'Open Tickets', value: '42', icon: Icons.confirmation_number_outlined, color: AppTheme.info),
              SizedBox(width: spacing),
              _SupportStatCard(width: cardWidth, title: 'Tickets Resolved', value: '128', icon: Icons.check_circle_outline, color: AppTheme.success),
              SizedBox(width: spacing),
              _SupportStatCard(width: cardWidth, title: 'Pending Dealer', value: '15', icon: Icons.hourglass_empty, color: AppTheme.warning),
              SizedBox(width: spacing),
              _SupportStatCard(width: cardWidth, title: 'Active Chats', value: '8', icon: Icons.chat_bubble_outline, color: Colors.purple),
            ],
          );
        }

        final int count = isMobile ? 1 : 2;
        final double width = (constraints.maxWidth - (spacing * (count - 1))) / count;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            _SupportStatCard(width: width.clamp(200.0, double.infinity), title: 'Open Tickets', value: '42', icon: Icons.confirmation_number_outlined, color: AppTheme.info),
            _SupportStatCard(width: width.clamp(200.0, double.infinity), title: 'Tickets Resolved', value: '128', icon: Icons.check_circle_outline, color: AppTheme.success),
            _SupportStatCard(width: width.clamp(200.0, double.infinity), title: 'Pending Dealer', value: '15', icon: Icons.hourglass_empty, color: AppTheme.warning),
            _SupportStatCard(width: width.clamp(200.0, double.infinity), title: 'Active Chats', value: '8', icon: Icons.chat_bubble_outline, color: Colors.purple),
          ],
        );
      },
    );
  }
}

class _SupportStatCard extends StatelessWidget {
  final double width;
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _SupportStatCard({
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
            borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.borderRadiusXLarge)),
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
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
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
