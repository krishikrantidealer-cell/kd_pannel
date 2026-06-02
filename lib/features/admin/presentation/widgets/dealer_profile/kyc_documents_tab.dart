import 'package:flutter/material.dart';
import 'package:kd_pannel/core/responsive/responsive.dart';
import 'package:kd_pannel/core/theme/app_colors.dart';
import 'package:kd_pannel/core/theme/app_typography.dart';
import 'package:kd_pannel/features/admin/presentation/widgets/shared_crm/document_card.dart';

class KycDocumentsTab extends StatelessWidget {
  const KycDocumentsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Registration Vault',
          style: AppTypography.h2,
        ),
        const SizedBox(height: 8),
        const Text(
          'Manage dealer KYC and business verification documents',
          style: AppTypography.body,
        ),
        const SizedBox(height: 32),
        if (isMobile)
          Column(
            children: [
              const DocumentCard(
                title: 'GST Certificate',
                subtext: '27ABCDE1234F1Z5',
                icon: Icons.description_rounded,
                accent: AppColors.success,
              ),
              const SizedBox(height: 16),
              const DocumentCard(
                title: 'PAN Card',
                subtext: 'ABCDE1234F',
                icon: Icons.badge_rounded,
                accent: AppColors.primary,
              ),
              const SizedBox(height: 16),
              const DocumentCard(
                title: 'Dealer Photo',
                subtext: 'verified_profile.jpg',
                icon: Icons.face_rounded,
                accent: AppColors.warning,
              ),
            ],
          )
        else
          Row(
            children: [
              const Expanded(
                child: DocumentCard(
                  title: 'GST Certificate',
                  subtext: '27ABCDE1234F1Z5',
                  icon: Icons.description_rounded,
                  accent: AppColors.success,
                ),
              ),
              const SizedBox(width: 20),
              const Expanded(
                child: DocumentCard(
                  title: 'PAN Card',
                  subtext: 'ABCDE1234F',
                  icon: Icons.badge_rounded,
                  accent: AppColors.primary,
                ),
              ),
              const SizedBox(width: 20),
              const Expanded(
                child: DocumentCard(
                  title: 'Dealer Photo',
                  subtext: 'verified_profile.jpg',
                  icon: Icons.face_rounded,
                  accent: AppColors.warning,
                ),
              ),
            ],
          ),
      ],
    );
  }
}
