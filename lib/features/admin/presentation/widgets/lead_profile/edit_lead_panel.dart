import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:kd_pannel/core/theme/app_colors.dart';
import 'package:kd_pannel/core/theme/app_typography.dart';
import 'package:kd_pannel/core/theme/app_shadows.dart';
import 'package:kd_pannel/core/theme/app_gradients.dart';

class EditLeadPanel extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final TextEditingController cityController;
  final TextEditingController stateController;
  final TextEditingController sourceController;
  final TextEditingController agentController;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  const EditLeadPanel({
    super.key,
    required this.nameController,
    required this.phoneController,
    required this.cityController,
    required this.stateController,
    required this.sourceController,
    required this.agentController,
    required this.onSave,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.98),
        boxShadow: AppShadows.panel,
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Column(
            children: [
              // Panel Header
              Container(
                padding: const EdgeInsets.fromLTRB(28, 28, 20, 20),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.lightBorder)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Edit Lead Profile',
                            style: AppTypography.h3,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Update business contact information',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.slate500,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: onCancel,
                      icon: const Icon(Icons.close_rounded, color: AppColors.slate500),
                    ),
                  ],
                ),
              ),

              // Panel Content
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    children: [
                      _EditField(
                        label: 'Lead Name',
                        controller: nameController,
                        icon: Icons.business_rounded,
                      ),
                      const SizedBox(height: 24),
                      _EditField(
                        label: 'Phone Number',
                        controller: phoneController,
                        icon: Icons.phone_rounded,
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: _EditField(
                              label: 'City',
                              controller: cityController,
                              icon: Icons.location_city_rounded,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _EditField(
                              label: 'State',
                              controller: stateController,
                              icon: Icons.map_rounded,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _EditField(
                        label: 'Lead Source',
                        controller: sourceController,
                        icon: Icons.hub_rounded,
                      ),
                      const SizedBox(height: 24),
                      _EditField(
                        label: 'Assigned Sales',
                        controller: agentController,
                        icon: Icons.badge_rounded,
                      ),
                    ],
                  ),
                ),
              ),

              // Panel Footer
              Container(
                padding: const EdgeInsets.all(28),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.lightBorder)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: onCancel,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          height: 52,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.slate200),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppColors.slate500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: InkWell(
                        onTap: onSave,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          height: 52,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            gradient: AppGradients.primaryButton,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: AppShadows.button,
                          ),
                          child: const Text(
                            'Save Changes',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final IconData icon;

  const _EditField({
    required this.label,
    required this.controller,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            color: AppColors.slate400,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: controller,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.slate900,
          ),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 20, color: AppColors.slate500),
            filled: true,
            fillColor: AppColors.slate50,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.slate200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.slate200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
