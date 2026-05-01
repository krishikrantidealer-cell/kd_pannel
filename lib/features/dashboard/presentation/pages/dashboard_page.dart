import 'package:flutter/material.dart';
import '../widgets/sidebar_widget.dart';
import '../widgets/topbar_widget.dart';
import '../widgets/stat_card_widget.dart';
import '../widgets/table_widget.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

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
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'KrishiDealer Admin Dashboard',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF111827),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFE5E7EB)),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.calendar_today_outlined, size: 14, color: Color(0xFF6B7280)),
                                  SizedBox(width: 8),
                                  Text(
                                    'This Month',
                                    style: TextStyle(fontSize: 13, color: Color(0xFF374151), fontWeight: FontWeight.w500),
                                  ),
                                  SizedBox(width: 4),
                                  Icon(Icons.keyboard_arrow_down, size: 16, color: Color(0xFF6B7280)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        // FIRST ROW: 5 Cards
                        const _StatRow1(),
                        const SizedBox(height: 20),
                        // SECOND ROW: 4 Cards
                        const _StatRow2(),
                        const SizedBox(height: 32),
                        // Bottom Section
                        const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: TableWidget(
                                title: 'Recent Orders',
                                columns: ['Dealer', 'Product', 'Amount', 'Date', 'Status'],
                                rows: [
                                  ['King Agro', 'Drip Irrigation', '\$2,400', '2023-10-24', 'Completed'],
                                  ['Gupta Seeds', 'Hybrid Seeds', '\$650', '2023-10-24', 'Pending'],
                                  ['Patel Agro Supplies', 'Irrigation Pump', '\$1,150', '2023-10-23', 'Completed'],
                                ],
                              ),
                            ),
                            SizedBox(width: 24),
                            Expanded(
                              flex: 2,
                              child: TableWidget(
                                title: 'Recent Leads',
                                columns: ['Dealer Name', 'Contact Person', 'Created Time'],
                                rows: [
                                  ['Choudhary Krishi', 'Nirmal Choudhary', '2 hours ago'],
                                  ['Greenway Agro', 'Priya Joshi', '5 hours ago'],
                                  ['Shiva Enterprises', 'Ravi Singh', '3 days ago'],
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

class _StatRow1 extends StatelessWidget {
  const _StatRow1();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(
          child: StatCardWidget(
            title: 'Revenue Today',
            value: '\$2,450',
            color: Color(0xFF10B981),
            icon: Icons.account_balance_wallet_outlined,
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          child: StatCardWidget(
            title: 'Orders Today',
            value: '32',
            color: Color(0xFF8BC34A),
            icon: Icons.shopping_bag_outlined,
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          child: StatCardWidget(
            title: 'Total Dealers',
            value: '920',
            color: Color(0xFF3B82F6),
            icon: Icons.people_outline,
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          child: StatCardWidget(
            title: 'Active Dealers',
            value: '550',
            color: Color(0xFF06B6D4),
            icon: Icons.how_to_reg_outlined,
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          child: StatCardWidget(
            title: 'New Leads',
            value: '24',
            color: Color(0xFFF59E0B),
            icon: Icons.campaign_outlined,
          ),
        ),
      ],
    );
  }
}

class _StatRow2 extends StatelessWidget {
  const _StatRow2();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(
          child: StatCardWidget(
            title: 'Sales Performance',
            value: '74,200 Orders',
            color: Color(0xFF10B981),
            icon: Icons.trending_up,
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          child: StatCardWidget(
            title: 'Dealer Onboarding',
            value: '320 Dealers Joined',
            color: Color(0xFF8BC34A),
            icon: Icons.person_add_alt_1_outlined,
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          child: StatCardWidget(
            title: 'Order Status',
            value: '2,450',
            subtext: 'Total Orders',
            color: Color(0xFFF59E0B),
            icon: Icons.shopping_cart_outlined,
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          child: StatCardWidget(
            title: 'Pending Orders',
            value: '140',
            subtext: 'Orders Pending',
            color: Color(0xFFEF4444),
            icon: Icons.hourglass_empty,
          ),
        ),
      ],
    );
  }
}
