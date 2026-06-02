import 'package:flutter/material.dart';
import 'package:kd_pannel/core/responsive/responsive.dart';
import 'package:kd_pannel/core/theme/app_colors.dart';
import 'package:kd_pannel/core/theme/app_typography.dart';
import 'package:kd_pannel/features/admin/presentation/widgets/shared_crm/interactive_item.dart';
import 'package:kd_pannel/features/admin/presentation/widgets/shared_crm/info_block.dart';

class DealerInformationTab extends StatelessWidget {
  final String name;
  final String phone;
  final String state;
  final String city;
  final String gst;
  final String type;
  final String agent;
  final VoidCallback onEdit;

  const DealerInformationTab({
    super.key,
    required this.name,
    required this.phone,
    required this.state,
    required this.city,
    required this.gst,
    required this.type,
    required this.agent,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isMobile)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Dealer Identity',
                style: AppTypography.h1,
              ),
              const SizedBox(height: 4),
              const Text(
                'Manage business registration and contact details',
                style: AppTypography.body,
              ),
              const SizedBox(height: 16),
              _buildEditButton(),
            ],
          )
        else
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Dealer Identity',
                      style: AppTypography.h1,
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Manage business registration and contact details',
                      style: AppTypography.body,
                    ),
                  ],
                ),
              ),
              _buildEditButton(),
            ],
          ),
        const SizedBox(height: 24),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: isMobile ? 1 : 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: isMobile ? 3.0 : 2.5,
          children: [
            InfoBlock(
              icon: Icons.business_rounded,
              label: 'Dealer Name',
              value: name,
              accent: AppColors.success,
            ),
            InfoBlock(
              icon: Icons.phone_android_rounded,
              label: 'Phone Number',
              value: phone,
              accent: AppColors.primary,
            ),
            InfoBlock(
              icon: Icons.map_rounded,
              label: 'State',
              value: state,
              accent: Colors.purple,
            ),
            InfoBlock(
              icon: Icons.location_city_rounded,
              label: 'City',
              value: city,
              accent: AppColors.warning,
            ),
            InfoBlock(
              icon: Icons.receipt_long_rounded,
              label: 'GST Number',
              value: gst,
              accent: AppColors.danger,
            ),
            InfoBlock(
              icon: Icons.category_rounded,
              label: 'Dealer Type',
              value: type,
              accent: Colors.teal,
            ),
            InfoBlock(
              icon: Icons.badge_rounded,
              label: 'Assigned Agent',
              value: agent,
              accent: Colors.indigo,
            ),
            InfoBlock(
              icon: Icons.verified_user_rounded,
              label: 'Verification',
              value: 'Fully Verified',
              accent: AppColors.success,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEditButton() {
    return InteractiveItem(
      onTap: onEdit,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppColors.lightBorder,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(
              Icons.edit_note_rounded,
              size: 18,
              color: AppColors.slate900,
            ),
            SizedBox(width: 6),
            Text(
              'Edit',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.slate900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

