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
          'Dealer Interaction Log',
          style: AppTypography.h3,
        ),
        const SizedBox(height: 6),
        const Text(
          'Chronological audit trail of all business activities',
          style: AppTypography.body,
        ),
        const SizedBox(height: 32),
        const TimelineStreamItem(
          icon: Icons.person_add_alt_1_rounded,
          color: AppColors.primary,
          title: 'Dealer Registered',
          time: '12 Jan 2022',
          desc: 'Onboarded into the system as new partner',
        ),
        const TimelineStreamItem(
          icon: Icons.verified_user_rounded,
          color: Colors.teal,
          title: 'GST Verified',
          time: '14 Jan 2022',
          desc: 'Compliance documents verified successfully',
        ),
        const TimelineStreamItem(
          icon: Icons.support_agent_rounded,
          color: Colors.purple,
          title: 'Sales Agent Assigned',
          time: '15 Jan 2022',
          desc: 'Rajesh Kumar assigned as primary contact',
        ),
        const TimelineStreamItem(
          icon: Icons.shopping_bag_rounded,
          color: AppColors.warning,
          title: 'First Order Created',
          time: '20 Jan 2022',
          desc: 'Initial inventory purchase completed',
        ),
        const TimelineStreamItem(
          icon: Icons.check_circle_rounded,
          color: AppColors.success,
          title: 'Purchase Completed',
          time: '24 Oct 2023',
          desc: 'Bulk replenishment order delivered',
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
                'View Audit History',
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
