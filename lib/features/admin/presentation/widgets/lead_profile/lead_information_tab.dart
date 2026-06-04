import 'package:flutter/material.dart';
import 'package:kd_pannel/core/responsive/responsive.dart';
import 'package:kd_pannel/core/theme/app_colors.dart';
import 'package:kd_pannel/core/theme/app_typography.dart';
import 'package:kd_pannel/features/admin/presentation/widgets/shared_crm/interactive_item.dart';
import 'package:kd_pannel/features/admin/presentation/widgets/shared_crm/info_block.dart';

class LeadInformationTab extends StatelessWidget {
  final String name;
  final String phone;
  final String city;
  final String stateName;
  final String source;
  final String agent;
  final VoidCallback onEdit;

  const LeadInformationTab({
    super.key,
    required this.name,
    required this.phone,
    required this.city,
    required this.stateName,
    required this.source,
    required this.agent,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Business Identity',
                  style: AppTypography.h1,
                ),
                SizedBox(height: 6),
                Text(
                  'Lead contact and profile details',
                  style: AppTypography.body,
                ),
              ],
            ),
            InteractiveItem(
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
            ),
          ],
        ),
        const SizedBox(height: 24),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: Responsive.isMobile(context) ? 1 : 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: Responsive.isMobile(context) ? 3.0 : 2.5,
          children: [
            InfoBlock(
              icon: Icons.person_rounded,
              label: 'Lead Name',
              value: name,
              accent: AppColors.primary,
            ),
            InfoBlock(
              icon: Icons.phone_android_rounded,
              label: 'Phone Number',
              value: phone,
              accent: AppColors.success,
            ),
            InfoBlock(
              icon: Icons.location_city_rounded,
              label: 'City',
              value: city,
              accent: AppColors.warning,
            ),
            InfoBlock(
              icon: Icons.map_rounded,
              label: 'State',
              value: stateName,
              accent: AppColors.danger,
            ),
            InfoBlock(
              icon: Icons.hub_rounded,
              label: 'Lead Source',
              value: source,
              accent: AppColors.secondary,
            ),
            InfoBlock(
              icon: Icons.badge_rounded,
              label: 'Assigned Sales',
              value: agent,
              accent: AppColors.info,
            ),
            InfoBlock(
              icon: Icons.calendar_month_rounded,
              label: 'Created Date',
              value: '24 Oct 2023',
              accent: AppColors.slate500,
            ),
            InfoBlock(
              icon: Icons.update_rounded,
              label: 'Last Activity',
              value: '2 minutes ago',
              accent: const Color(0xFFEC4899),
            ),
          ],
        ),
      ],
    );
  }
}
