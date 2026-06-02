import 'package:flutter/material.dart';
import 'package:kd_pannel/core/theme/app_colors.dart';
import 'package:kd_pannel/core/theme/app_typography.dart';
import 'package:kd_pannel/core/theme/app_gradients.dart';
import 'package:kd_pannel/core/theme/app_shadows.dart';
import 'package:kd_pannel/features/admin/presentation/widgets/shared_crm/page_breadcrumb.dart';
import 'package:kd_pannel/features/admin/presentation/widgets/shared_crm/sidebar_info_item.dart';
import 'package:kd_pannel/features/admin/presentation/widgets/shared_crm/action_button.dart';

class IdentitySidebar extends StatelessWidget {
  final bool isEmbedded;
  final String name;
  final String phone;
  final String city;
  final String stateName;
  final String source;
  final String agent;
  final String statusLabel;

  const IdentitySidebar({
    super.key,
    this.isEmbedded = false,
    required this.name,
    required this.phone,
    required this.city,
    required this.stateName,
    required this.source,
    required this.agent,
    this.statusLabel = 'QUALIFIED LEAD',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: isEmbedded
          ? BoxDecoration(gradient: AppGradients.sidebar)
          : BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: AppColors.lightBorder, width: 1.0),
              boxShadow: AppShadows.sidebar,
            ),
      child: _IdentitySidebarContent(
        isEmbedded: isEmbedded,
        name: name,
        phone: phone,
        city: city,
        stateName: stateName,
        source: source,
        agent: agent,
        statusLabel: statusLabel,
      ),
    );
  }
}

class _IdentitySidebarContent extends StatelessWidget {
  final bool isEmbedded;
  final String name;
  final String phone;
  final String city;
  final String stateName;
  final String source;
  final String agent;
  final String statusLabel;

  const _IdentitySidebarContent({
    this.isEmbedded = false,
    required this.name,
    required this.phone,
    required this.city,
    required this.stateName,
    required this.source,
    required this.agent,
    required this.statusLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: -60,
          right: -60,
          child: Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppGradients.primaryAura,
            ),
          ),
        ),
        Positioned(
          top: 100,
          left: -40,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppGradients.secondaryAura,
            ),
          ),
        ),
        SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: EdgeInsets.fromLTRB(24, isEmbedded ? 12 : 16, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isEmbedded) ...[
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: PageBreadcrumb(),
                  ),
                  const SizedBox(height: 12),
                ],
                SizedBox(
                  width: double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppGradients.avatarRing,
                        ),
                        child: Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.surface,
                            boxShadow: AppShadows.avatar,
                          ),
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: CircleAvatar(
                              backgroundColor: AppColors.slate50,
                              backgroundImage: AssetImage('assets/images/admin.png'),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        name,
                        textAlign: TextAlign.center,
                        style: AppTypography.h3.copyWith(fontSize: 22, height: 1.1),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          gradient: AppGradients.statusBadge,
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: AppColors.success.withValues(alpha: 0.2),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.success.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          statusLabel,
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF15803D),
                            letterSpacing: 1.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                const Divider(
                  height: 1,
                  color: AppColors.lightBorder,
                  thickness: 1.0,
                ),
                const SizedBox(height: 28),
                SidebarInfoItem(
                  icon: Icons.phone_iphone_rounded,
                  label: 'Phone',
                  value: phone,
                  iconColor: AppColors.primary,
                ),
                SidebarInfoItem(
                  icon: Icons.location_on_rounded,
                  label: 'Location',
                  value: '$city, $stateName',
                  iconColor: AppColors.danger,
                ),
                SidebarInfoItem(
                  icon: Icons.campaign_rounded,
                  label: 'Source',
                  value: source,
                  iconColor: AppColors.warning,
                ),
                SidebarInfoItem(
                  icon: Icons.person_pin_rounded,
                  label: 'Agent',
                  value: agent,
                  iconColor: AppColors.secondary,
                ),
                const SizedBox(height: 4),
                const Divider(
                  height: 1,
                  color: AppColors.lightBorder,
                  thickness: 1.0,
                ),
                const SizedBox(height: 16),

                // Action buttons arranged in a compact 2x2 grid
                Row(
                  children: [
                    Expanded(
                      child: ActionButton(
                        icon: Icons.chat_bubble_rounded,
                        label: 'WhatsApp',
                        color: const Color(0xFF075E54),
                        isOutlined: true,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ActionButton(
                        icon: Icons.person_add_alt_1_rounded,
                        label: 'Convert Dealer',
                        color: AppColors.primary,
                        isOutlined: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ActionButton(
                        icon: Icons.call_rounded,
                        label: 'Call Lead',
                        color: AppColors.success,
                        isPrimary: true,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ActionButton(
                        icon: Icons.shopping_cart_rounded,
                        label: 'Draft Order',
                        color: AppColors.warning,
                        isSecondary: true,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
