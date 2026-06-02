import 'package:flutter/material.dart';
import 'package:kd_pannel/core/theme/app_colors.dart';
import 'package:kd_pannel/core/theme/app_typography.dart';
import 'package:kd_pannel/features/admin/presentation/widgets/shared_crm/timeline_stream_item.dart';
import 'package:kd_pannel/features/admin/presentation/widgets/shared_crm/interactive_item.dart';

class ActivityTimelineTab extends StatelessWidget {
  const ActivityTimelineTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Interaction Log',
          style: AppTypography.h3,
        ),
        const SizedBox(height: 6),
        const Text(
          'Chronological audit trail of all lead interactions',
          style: AppTypography.body,
        ),
        const SizedBox(height: 32),
        const TimelineStreamItem(
          icon: Icons.rocket_launch_rounded,
          color: AppColors.primary,
          title: 'Lead Captured',
          time: '10:30 AM',
          desc: 'System identified via CTWA',
        ),
        const TimelineStreamItem(
          icon: Icons.chat_bubble_rounded,
          color: Color(0xFF128C7E),
          title: 'WhatsApp Started',
          time: '11:15 AM',
          desc: 'Initiated discovery workflow',
        ),
        const TimelineStreamItem(
          icon: Icons.phone_in_talk_rounded,
          color: Colors.purple,
          title: 'Sales Contacted',
          time: '09:30 AM',
          desc: 'Pricing call by Rajesh Sharma',
        ),
        const TimelineStreamItem(
          icon: Icons.assignment_ind_rounded,
          color: AppColors.warning,
          title: 'KYC Submitted',
          time: '02:15 PM',
          desc: 'Identity documents uploaded',
        ),
        const TimelineStreamItem(
          icon: Icons.verified_user_rounded,
          color: Colors.teal,
          title: 'GST Verified',
          time: '10:00 AM',
          desc: 'Cleared compliance check',
        ),
        const TimelineStreamItem(
          icon: Icons.person_add_alt_1_rounded,
          color: Color(0xFF2E7D32),
          title: 'Dealer Converted',
          time: '04:30 PM',
          desc: 'Converted to Active Dealer',
        ),
        const TimelineStreamItem(
          icon: Icons.shopping_bag_rounded,
          color: Color(0xFFF57C00),
          title: 'Order Placed',
          time: '11:20 AM',
          desc: 'Stock replenishment order',
          isLast: true,
        ),
        const SizedBox(height: 32),
        Center(
          child: InteractiveItem(
            onTap: () {},
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.lightBorder, width: 1.0),
              ),
              child: const Text(
                'Load Older Activity',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: AppColors.slate500,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
