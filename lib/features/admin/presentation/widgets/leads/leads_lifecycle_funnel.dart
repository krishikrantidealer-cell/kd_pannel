import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kd_pannel/app_theme.dart';
import 'package:kd_pannel/core/auth/auth_service.dart';

class LeadsLifecycleFunnel extends StatelessWidget {
  final String selectedFilterChip;
  final List<Map<String, dynamic>> dateFilteredLeads;
  final Function(String chip) onChipSelected;
  final Widget? searchField;
  final Widget? stateDropdown;
  final bool isMobile;

  const LeadsLifecycleFunnel({
    super.key,
    required this.selectedFilterChip,
    required this.dateFilteredLeads,
    required this.onChipSelected,
    this.searchField,
    this.stateDropdown,
    required this.isMobile,
  });

  List<String> get activeFilterChips {
    if (AuthService().isSales) {
      return [
        'All',
        'Assigned',
        'KYC Pending',
        'Deleted',
      ];
    }
    return [
      'All',
      'Assigned',
      'Unassigned',
      'KYC Pending',
      'Deleted',
    ];
  }

  int? _getCount(String chip) {
    switch (chip) {
      case 'All':
        return dateFilteredLeads.length;
      case 'Unassigned':
        return dateFilteredLeads
            .where((l) => l['agentId'] == null && l['kycStatus'] != 'verified')
            .length;
      case 'Assigned':
        return dateFilteredLeads
            .where((l) => l['agentId'] != null && l['kycStatus'] != 'verified')
            .length;
      case 'KYC Pending':
        return dateFilteredLeads
            .where((l) =>
                l['kycStatus'] == 'pending' || l['kycStatus'] == 'submitted')
            .length;
      case 'Deleted':
        return dateFilteredLeads.where((l) => l['isDeleted'] == true).length;
      default:
        return null;
    }
  }

  IconData _getChipIcon(String chip) {
    switch (chip) {
      case 'All':
        return Icons.grid_view_rounded;
      case 'Assigned':
        return Icons.person_pin_rounded;
      case 'Unassigned':
        return Icons.person_off_rounded;
      case 'KYC Pending':
        return Icons.pending_actions_rounded;
      case 'Deleted':
        return Icons.delete_outline_rounded;
      default:
        return Icons.filter_list_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final chips = activeFilterChips;

    if (!isMobile) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (searchField != null) searchField!,
          if (searchField != null && stateDropdown != null)
            const SizedBox(width: 12),
          if (stateDropdown != null) stateDropdown!,
          const SizedBox(width: 16),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: chips
                    .map(
                      (chip) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _FunnelChipItem(
                          label: chip,
                          count: _getCount(chip),
                          icon: _getChipIcon(chip),
                          isSelected: selectedFilterChip == chip,
                          onTap: () => onChipSelected(chip),
                          isMobile: isMobile,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (searchField != null) searchField!,
          if (stateDropdown != null) ...[
            const SizedBox(height: 12),
            stateDropdown!,
          ],
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: chips
                  .map(
                    (chip) => Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: _FunnelChipItem(
                        label: chip,
                        count: _getCount(chip),
                        icon: _getChipIcon(chip),
                        isSelected: selectedFilterChip == chip,
                        onTap: () => onChipSelected(chip),
                        isMobile: isMobile,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      );
    }
  }
}

class _FunnelChipItem extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final int? count;
  final VoidCallback onTap;
  final bool isMobile;

  const _FunnelChipItem({
    required this.label,
    required this.icon,
    required this.isSelected,
    this.count,
    required this.onTap,
    required this.isMobile,
  });

  @override
  State<_FunnelChipItem> createState() => _FunnelChipItemState();
}

class _FunnelChipItemState extends State<_FunnelChipItem> {
  bool isHovered = false;

  Color _getMutedIconColor(String chip) {
    switch (chip) {
      case 'All':
        return AppTheme.textSecondary;
      case 'Assigned':
        return AppTheme.info.withValues(alpha: 0.7);
      case 'Unassigned':
        return const Color(0xFF8B5CF6).withValues(alpha: 0.7);
      case 'KYC Pending':
        return AppTheme.warning.withValues(alpha: 0.7);
      case 'Deleted':
        return AppTheme.error.withValues(alpha: 0.7);
      default:
        return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color iconColor = widget.isSelected
        ? AppTheme.primaryColor
        : (isHovered ? AppTheme.textPrimary : _getMutedIconColor(widget.label));

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(
            horizontal: widget.isMobile ? 12 : 16,
            vertical: widget.isMobile ? 6 : 8,
          ),
          decoration: BoxDecoration(
            gradient: widget.isSelected
                ? LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppTheme.primaryColor.withValues(alpha: 0.12),
                      AppTheme.primaryColor.withValues(alpha: 0.08),
                    ],
                  )
                : (isHovered
                    ? LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppTheme.primaryColor.withValues(alpha: 0.06),
                          AppTheme.primaryColor.withValues(alpha: 0.04),
                        ],
                      )
                    : null),
            color: (widget.isSelected || isHovered) ? null : Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: widget.isSelected
                ? [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : (isHovered
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null),
            border: Border.all(
              color: widget.isSelected
                  ? AppTheme.primaryColor
                  : (isHovered
                      ? AppTheme.primaryColor.withValues(alpha: 0.4)
                      : AppTheme.borderColor),
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 16, color: iconColor),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: GoogleFonts.outfit(
                  color: widget.isSelected
                      ? AppTheme.primaryColor
                      : AppTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: widget.isMobile ? 12 : 13,
                ),
              ),
              if (widget.count != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: widget.isSelected
                        ? AppTheme.primaryColor.withValues(alpha: 0.18)
                        : (isHovered
                            ? AppTheme.primaryColor.withValues(alpha: 0.08)
                            : const Color(0xFFF1F5F9)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${widget.count}',
                    style: GoogleFonts.outfit(
                      fontSize: widget.isMobile ? 10.5 : 11.5,
                      fontWeight: FontWeight.w700,
                      color: widget.isSelected
                          ? AppTheme.primaryColor
                          : AppTheme.textSecondary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
