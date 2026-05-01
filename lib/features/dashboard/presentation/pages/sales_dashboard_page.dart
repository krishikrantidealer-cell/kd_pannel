import 'package:flutter/material.dart';
import '../widgets/sidebar_widget.dart';
import '../widgets/topbar_widget.dart';
import '../widgets/table_widget.dart';

class SalesDashboardPage extends StatelessWidget {
  const SalesDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Column(
        children: [
          const TopbarWidget(),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SidebarWidget(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
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
                                color: Color(0xFF111827),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFE5E7EB)),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.calendar_today_outlined, size: 14, color: Color(0xFF6B7280)),
                                  SizedBox(width: 8),
                                  Text(
                                    'This Month',
                                    style: TextStyle(fontSize: 12, color: Color(0xFF374151), fontWeight: FontWeight.w500),
                                  ),
                                  SizedBox(width: 4),
                                  Icon(Icons.keyboard_arrow_down, size: 14, color: Color(0xFF6B7280)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        const _SalesStatsGrid(),
                        const SizedBox(height: 24),
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

class _SalesStatsGrid extends StatelessWidget {
  const _SalesStatsGrid();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double spacing = 16;
        final double width = (constraints.maxWidth - (spacing * 4)) / 5;
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _SalesStatCard(width: width, title: 'My Leads', value: '1,240', icon: Icons.person_add_outlined, color: Colors.blue),
            _SalesStatCard(width: width, title: 'New Leads Today', value: '24', icon: Icons.campaign_outlined, color: Colors.orange),
            _SalesStatCard(width: width, title: 'My Dealers', value: '850', icon: Icons.storefront_outlined, color: Colors.green),
            _SalesStatCard(width: width, title: 'Orders Created Today', value: '12', icon: Icons.shopping_bag_outlined, color: Colors.purple),
            _SalesStatCard(width: width, title: 'Pending KYC', value: '45', icon: Icons.verified_user_outlined, color: Colors.red),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
                border: Border.all(color: Colors.white, width: 2),
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
                  style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280), fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
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
