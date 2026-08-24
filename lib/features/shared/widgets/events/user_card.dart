import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kd_pannel/app_theme.dart';
import 'package:kd_pannel/core/utils/formatters.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/dealers_bloc.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/leads_bloc.dart';
import 'package:kd_pannel/features/shared/widgets/events/event_log_card.dart';
import 'package:kd_pannel/features/shared/widgets/events/event_metric_cards.dart';
import 'package:kd_pannel/features/shared/widgets/events/events_helper.dart';

class UserCard extends StatefulWidget {
  final String name;
  final String userType;
  final String? assignedAgent;
  final Map<String, List<Map<String, dynamic>>> groupedEvents;
  final bool isSelected;
  final String? selectedEventType;
  final List<Map<String, dynamic>> eventTypes;
  final Function(String categoryId) onCategorySelected;
  final VoidCallback onTap;
  final Function(String user) onViewProfile;
  final bool isOnline;
  final bool isHighPriority;
  final String priorityReason;
  final bool isLoadingEvents;

  const UserCard({
    super.key,
    required this.name,
    required this.userType,
    this.assignedAgent,
    required this.groupedEvents,
    required this.isSelected,
    required this.selectedEventType,
    required this.eventTypes,
    required this.onTap,
    required this.onCategorySelected,
    required this.onViewProfile,
    this.isOnline = false,
    this.isHighPriority = false,
    this.priorityReason = '',
    this.isLoadingEvents = false,
  });

  @override
  State<UserCard> createState() => _UserCardState();
}

class _UserCardState extends State<UserCard>
    with SingleTickerProviderStateMixin {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final bool isSelected = widget.isSelected;
    final bool isHovered = _hovered;

    // Calculate total events for this user
    int totalEvents = 0;
    widget.groupedEvents.forEach((_, logs) {
      totalEvents += logs.length;
    });

    // Extract phone number, intent label, and journey path from events if available
    String? userPhone;
    String? intentLabel;
    String? journeyPath;
    for (final logs in widget.groupedEvents.values) {
      for (final log in logs) {
        if ((userPhone == null || userPhone.isEmpty) &&
            log['userPhone'] != null) {
          final p = (log['userPhone'] as String?)?.trim();
          if (p != null && p.isNotEmpty) userPhone = p;
        }
        if (intentLabel == null && log['intentLabel'] != null) {
          intentLabel = log['intentLabel'] as String?;
        }
        if (journeyPath == null) {
          final props = log['properties'] ?? log['payload'];
          if (props is Map && props['journeyPath'] != null) {
            journeyPath = props['journeyPath'] as String?;
          }
        }
      }
    }

    // Check if widget.name itself is a phone number
    final cleanNameDigits = widget.name.replaceAll(RegExp(r'\D'), '');
    final bool nameIsPhone =
        cleanNameDigits.length >= 10 &&
        (widget.name.startsWith('+') ||
            RegExp(r'^\d+$').hasMatch(widget.name.trim()));

    if (userPhone == null || userPhone.isEmpty) {
      if (nameIsPhone) {
        userPhone = widget.name.trim();
      }
    }

    // Try finding phone and agent in Dealers or Leads
    Map<String, dynamic>? matchedUser;
    if (userPhone == null ||
        userPhone.isEmpty ||
        widget.assignedAgent == null ||
        widget.assignedAgent!.isEmpty) {
      try {
        final dealersState = context.read<DealersBloc>().state;
        final matchedDealer = dealersState.allRawUsers.firstWhere(
          (u) =>
              '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'.trim() ==
                  widget.name ||
              (u['shopName'] ?? '').toString().trim() == widget.name ||
              (u['_id'] ?? '').toString() == widget.name,
          orElse: () => <String, dynamic>{},
        );
        if (matchedDealer.isNotEmpty) {
          matchedUser = matchedDealer;
          final p =
              (matchedDealer['phoneNumber'] ?? matchedDealer['phone'] ?? '')
                  .toString()
                  .trim();
          if (p.isNotEmpty && (userPhone == null || userPhone.isEmpty)) {
            userPhone = p;
          }
        }
      } catch (_) {}
    }
    if (matchedUser == null || matchedUser.isEmpty) {
      try {
        final leadsState = context.read<LeadsBloc>().state;
        final matchedLead = leadsState.allRawUsers.firstWhere(
          (u) =>
              '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'.trim() ==
                  widget.name ||
              (u['shopName'] ?? '').toString().trim() == widget.name ||
              (u['_id'] ?? '').toString() == widget.name,
          orElse: () => <String, dynamic>{},
        );
        if (matchedLead.isNotEmpty) {
          matchedUser = matchedLead;
          final p = (matchedLead['phoneNumber'] ?? matchedLead['phone'] ?? '')
              .toString()
              .trim();
          if (p.isNotEmpty && (userPhone == null || userPhone.isEmpty)) {
            userPhone = p;
          }
        }
      } catch (_) {}
    }

    // Resolve assigned agent name
    String? assignedAgentName = widget.assignedAgent;
    if ((assignedAgentName == null || assignedAgentName.isEmpty) &&
        matchedUser != null &&
        matchedUser.isNotEmpty) {
      final assigned = matchedUser['assignedAgent'];
      if (assigned is Map) {
        final fn = (assigned['firstName'] ?? '').toString().trim();
        final ln = (assigned['lastName'] ?? '').toString().trim();
        final full = '$fn $ln'.trim();
        if (full.isNotEmpty) {
          assignedAgentName = full;
        } else if (assigned['name'] != null &&
            assigned['name'].toString().trim().isNotEmpty) {
          assignedAgentName = assigned['name'].toString().trim();
        } else if (assigned['phoneNumber'] != null &&
            assigned['phoneNumber'].toString().trim().isNotEmpty) {
          assignedAgentName = assigned['phoneNumber'].toString().trim();
        }
      } else if (assigned is String &&
          assigned.trim().isNotEmpty &&
          !RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(assigned)) {
        assignedAgentName = assigned.trim();
      }

      if (assignedAgentName == null || assignedAgentName.isEmpty) {
        final direct = (matchedUser['assignedAgentName'] ??
                matchedUser['agentName'] ??
                matchedUser['agent'])
            ?.toString()
            .trim();
        if (direct != null && direct.isNotEmpty) {
          assignedAgentName = direct;
        }
      }
    }

    if (assignedAgentName == null || assignedAgentName.isEmpty) {
      for (final logs in widget.groupedEvents.values) {
        for (final log in logs) {
          if (assignedAgentName != null && assignedAgentName.isNotEmpty) break;
          final direct = log['assignedAgentName'] ??
              log['agentName'] ??
              log['agent'];
          if (direct != null && direct.toString().trim().isNotEmpty) {
            assignedAgentName = direct.toString().trim();
            break;
          }
          final details = log['userDetails'];
          if (details is Map) {
            final agentObj = details['assignedAgent'];
            if (agentObj is Map) {
              final fn = (agentObj['firstName'] ?? '').toString().trim();
              final ln = (agentObj['lastName'] ?? '').toString().trim();
              final full = '$fn $ln'.trim();
              if (full.isNotEmpty) {
                assignedAgentName = full;
                break;
              }
            } else if (agentObj is String &&
                agentObj.trim().isNotEmpty &&
                !RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(agentObj)) {
              assignedAgentName = agentObj.trim();
              break;
            }
          }
        }
      }
    }

    final String? copyablePhone = (userPhone != null && userPhone.isNotEmpty)
        ? userPhone
        : (nameIsPhone ? widget.name : null);
    // Calculate journey milestone completion
    final bool hasSearch =
        widget.groupedEvents.containsKey('product_search') ||
        widget.groupedEvents.containsKey('product_view') ||
        widget.groupedEvents.containsKey('category_view') ||
        widget.groupedEvents.containsKey('login_success');
    final bool hasCart =
        widget.groupedEvents.containsKey('add_to_cart') ||
        widget.groupedEvents.containsKey('cart_add') ||
        widget.groupedEvents.containsKey('cart_view');
    final bool hasCheckout =
        widget.groupedEvents.containsKey('checkout_started') ||
        widget.groupedEvents.containsKey('checkout_init') ||
        widget.groupedEvents.containsKey('payment_initiated') ||
        widget.groupedEvents.containsKey('apply_coupon');
    final bool hasPaid =
        widget.groupedEvents.containsKey('payment_success') ||
        widget.groupedEvents.containsKey('order_placed') ||
        widget.groupedEvents.containsKey('order_completed') ||
        widget.groupedEvents.containsKey('order_created');
    final bool hasFailedPayment = widget.groupedEvents.containsKey(
      'payment_failed',
    );

    final String initials = widget.name.isNotEmpty
        ? widget.name
              .split(' ')
              .map((e) => e.isNotEmpty ? e[0] : '')
              .take(2)
              .join()
              .toUpperCase()
        : 'U';

    Color bg;
    Color border;
    Color titleColor;
    Color avatarBg;

    if (isSelected) {
      bg = AppTheme.primaryColor.withValues(alpha: 0.04);
      border = AppTheme.primaryColor.withValues(alpha: 0.35);
      titleColor = AppTheme.primaryColor;
      avatarBg = AppTheme.primaryColor.withValues(alpha: 0.12);
    } else if (isHovered) {
      bg = AppTheme.primaryColor.withValues(alpha: 0.015);
      border = AppTheme.borderColor.withValues(alpha: 0.8);
      titleColor = AppTheme.textPrimary;
      avatarBg = AppTheme.textSecondary.withValues(alpha: 0.1);
    } else {
      bg = Colors.transparent;
      border = AppTheme.borderColor.withValues(alpha: 0.45);
      titleColor = AppTheme.textPrimary;
      avatarBg = AppTheme.borderColor.withValues(alpha: 0.3);
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border, width: 1.1),
            boxShadow: isHovered
                ? [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: avatarBg,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          initials,
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? AppTheme.primaryColor
                                : AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      if (widget.isOnline)
                        const Positioned(
                          right: -1,
                          bottom: -1,
                          child: LivePulsingBadge(color: Color(0xFF10B981)),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              widget.name,
                              style: GoogleFonts.outfit(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: titleColor,
                              ),
                            ),
                            if (nameIsPhone && copyablePhone != null) ...[
                              Tooltip(
                                message: 'Copy Phone Number',
                                child: InkWell(
                                  onTap: () {
                                    Clipboard.setData(
                                      ClipboardData(text: copyablePhone),
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Row(
                                          children: [
                                            const Icon(
                                              Icons.check_circle_rounded,
                                              color: Colors.white,
                                              size: 15,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                'Phone number ($copyablePhone) copied to clipboard!',
                                                style: GoogleFonts.outfit(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        backgroundColor: const Color(
                                          0xFF0F172A,
                                        ),
                                        duration: const Duration(seconds: 2),
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        width: 360,
                                      ),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(4),
                                  child: Container(
                                    padding: const EdgeInsets.all(3.0),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor.withValues(
                                        alpha: 0.08,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Icon(
                                      Icons.copy_rounded,
                                      size: 12,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            _buildUserTypeBadge(context, widget.name),
                            if (assignedAgentName != null &&
                                assignedAgentName.isNotEmpty)
                              _buildAssignedAgentBadge(assignedAgentName),
                            if (intentLabel != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: intentLabel.contains('Hot')
                                      ? Colors.redAccent.withValues(alpha: 0.1)
                                      : intentLabel.contains('Warm')
                                          ? Colors.orange.withValues(alpha: 0.1)
                                          : Colors.blue.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: intentLabel.contains('Hot')
                                        ? Colors.redAccent.withValues(
                                            alpha: 0.3,
                                          )
                                        : intentLabel.contains('Warm')
                                            ? Colors.orange.withValues(alpha: 0.3)
                                            : Colors.blue.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Text(
                                  intentLabel,
                                  style: GoogleFonts.outfit(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                    color: intentLabel.contains('Hot')
                                        ? Colors.redAccent
                                        : intentLabel.contains('Warm')
                                            ? Colors.orange
                                            : Colors.blue,
                                  ),
                                ),
                              ),
                            ],
                            if (widget.isHighPriority) ...[
                              Builder(
                                builder: (context) {
                                  final bool isCartIssue =
                                      widget.priorityReason ==
                                              'Abandoned Cart' ||
                                          widget.priorityReason ==
                                              'Abandoned Checkout';
                                  final Color badgeColor = isCartIssue
                                      ? Colors.orange
                                      : AppTheme.error;
                                  final IconData badgeIcon = isCartIssue
                                      ? Icons.shopping_cart_outlined
                                      : Icons.priority_high_rounded;

                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: badgeColor.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: badgeColor.withValues(
                                          alpha: 0.25,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          badgeIcon,
                                          size: 10,
                                          color: badgeColor,
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          widget.priorityReason.isNotEmpty
                                              ? widget.priorityReason
                                              : 'High Priority',
                                          style: GoogleFonts.outfit(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w900,
                                            color: badgeColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ],
                        ),

                        if (copyablePhone != null && !nameIsPhone) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                copyablePhone,
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textSecondary.withValues(
                                    alpha: 0.85,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Tooltip(
                                message: 'Copy Phone Number',
                                child: InkWell(
                                  onTap: () {
                                    Clipboard.setData(
                                      ClipboardData(text: copyablePhone),
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Row(
                                          children: [
                                            const Icon(
                                              Icons.check_circle_rounded,
                                              color: Colors.white,
                                              size: 15,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                'Phone number ($copyablePhone) copied to clipboard!',
                                                style: GoogleFonts.outfit(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        backgroundColor: const Color(
                                          0xFF0F172A,
                                        ),
                                        duration: const Duration(seconds: 2),
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        width: 360,
                                      ),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(4),
                                  child: Container(
                                    padding: const EdgeInsets.all(3.0),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor.withValues(
                                        alpha: 0.08,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Icon(
                                      Icons.copy_rounded,
                                      size: 13,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '• ${formatUnits(totalEvents)} event${totalEvents == 1 ? "" : "s"}',
                                style: GoogleFonts.outfit(
                                  fontSize: 11.5,
                                  color: AppTheme.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ] else if (nameIsPhone) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${formatUnits(totalEvents)} event${totalEvents == 1 ? "" : "s"}',
                            style: GoogleFonts.outfit(
                              fontSize: 11.5,
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],

                        const SizedBox(height: 6),

                        // Mini Journey Funnel Milestone Tracker
                        _buildJourneyMilestonePipeline(
                          hasSearch: hasSearch,
                          hasCart: hasCart,
                          hasCheckout: hasCheckout,
                          hasPaid: hasPaid,
                          hasFailed: hasFailedPayment,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isSelected
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: isSelected
                        ? AppTheme.primaryColor
                        : AppTheme.textSecondary,
                  ),
                ],
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                child: isSelected
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Activity Categories',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              Row(
                                children: [
                                  TextButton.icon(
                                    onPressed: () {
                                      String? cardPhone;
                                      String? cardRawUser;
                                      Map<String, dynamic>? cardUserDetails;
                                      for (final logs
                                          in widget.groupedEvents.values) {
                                        for (final log in logs) {
                                          if (cardPhone == null &&
                                              log['userPhone'] != null &&
                                              (log['userPhone'] as String)
                                                  .isNotEmpty) {
                                            cardPhone =
                                                log['userPhone'] as String?;
                                          }
                                          if (cardRawUser == null &&
                                              log['rawUser'] != null &&
                                              (log['rawUser'] as String)
                                                  .isNotEmpty) {
                                            cardRawUser =
                                                log['rawUser'] as String?;
                                          }
                                          if (cardUserDetails == null &&
                                              log['userDetails']
                                                  is Map<String, dynamic>) {
                                            cardUserDetails =
                                                log['userDetails']
                                                    as Map<String, dynamic>;
                                          }
                                        }
                                      }
                                      navigateToProfile(
                                        context,
                                        cardRawUser ?? cardPhone ?? widget.name,
                                        phone: cardPhone,
                                        name: widget.name,
                                        userDetails: cardUserDetails,
                                      );
                                    },
                                    icon: const Icon(
                                      Icons.launch_rounded,
                                      size: 13,
                                    ),
                                    label: Text(
                                      'View CRM Profile',
                                      style: GoogleFonts.outfit(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    style: TextButton.styleFrom(
                                      foregroundColor: AppTheme.primaryColor,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          if (widget.isLoadingEvents) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withValues(
                                  alpha: 0.05,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Fetching latest customer events...',
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ] else if (widget.groupedEvents.isEmpty) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.backgroundColor,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppTheme.borderColor.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.info_outline_rounded,
                                    size: 16,
                                    color: AppTheme.textSecondary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'No recent events recorded for this customer.',
                                      style: GoogleFonts.outfit(
                                        fontSize: 12,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          _buildCategoriesWrap(context),
                          if (widget.selectedEventType != null &&
                              widget.groupedEvents.containsKey(
                                widget.selectedEventType,
                              )) ...[
                            const SizedBox(height: 16),
                            const Divider(
                              height: 1,
                              color: AppTheme.lightBorderColor,
                            ),
                            const SizedBox(height: 12),
                            _buildInlineFeed(context),
                          ],
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoriesWrap(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12.0),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: widget.groupedEvents.entries.map((entry) {
          final categoryId = entry.key;
          final logs = entry.value;
          final isCategorySelected =
              widget.isSelected && widget.selectedEventType == categoryId;

          // Find category styling info
          final catData = widget.eventTypes.firstWhere(
            (t) => t['id'] == categoryId,
            orElse: () => {
              'label': categoryId,
              'icon': Icons.info_outline,
              'color': Colors.grey,
            },
          );

          final String label = catData['label'] as String;
          final IconData icon = catData['icon'] as IconData;

          return InkWell(
            onTap: () => widget.onCategorySelected(categoryId),
            borderRadius: BorderRadius.circular(16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isCategorySelected
                    ? AppTheme.primaryColor
                    : AppTheme.backgroundColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isCategorySelected
                      ? AppTheme.primaryColor
                      : AppTheme.borderColor,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 13,
                    color: isCategorySelected
                        ? Colors.white
                        : AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isCategorySelected
                          ? Colors.white
                          : AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 0.5,
                    ),
                    decoration: BoxDecoration(
                      color: isCategorySelected
                          ? Colors.white.withValues(alpha: 0.2)
                          : AppTheme.lightBorderColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${logs.length}',
                      style: GoogleFonts.outfit(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: isCategorySelected
                            ? Colors.white
                            : AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildInlineFeed(BuildContext context) {
    final logs = widget.groupedEvents[widget.selectedEventType!] ?? [];

    final catData = widget.eventTypes.firstWhere(
      (t) => t['id'] == widget.selectedEventType,
      orElse: () => {'label': widget.selectedEventType, 'color': Colors.grey},
    );
    final String label = catData['label'] as String;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Active Feed: $label',
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${logs.length} event${logs.length == 1 ? "" : "s"}',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: logs.length,
          separatorBuilder: (context, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final log = logs[index];
            return EventLogCard(
              user: log['user'] as String,
              userPhone: log['userPhone'] as String?,
              rawUser: log['rawUser'] as String?,
              time: log['time'] as String,
              device: log['device'] as String,
              details: log['details'] as String,
              payload: log['payload'] as Map<String, dynamic>,
              accentColor: AppTheme.primaryColor,
            );
          },
        ),
      ],
    );
  }

  Widget _buildJourneyMilestonePipeline({
    required bool hasSearch,
    required bool hasCart,
    required bool hasCheckout,
    required bool hasPaid,
    required bool hasFailed,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildMilestoneDot('Search', hasSearch, const Color(0xFF0284C7)),
          _buildMilestoneConnector(hasCart),
          _buildMilestoneDot('Cart', hasCart, const Color(0xFFF59E0B)),
          _buildMilestoneConnector(hasCheckout),
          _buildMilestoneDot('Checkout', hasCheckout, const Color(0xFFFB923C)),
          _buildMilestoneConnector(hasPaid || hasFailed),
          _buildMilestoneDot(
            hasFailed ? 'Failed ❌' : 'Paid',
            hasPaid || hasFailed,
            hasFailed ? Colors.redAccent : const Color(0xFF10B981),
          ),
        ],
      ),
    );
  }

  Widget _buildMilestoneDot(String label, bool completed, Color activeColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: completed ? activeColor : AppTheme.borderColor,
            boxShadow: completed
                ? [
                    BoxShadow(
                      color: activeColor.withValues(alpha: 0.3),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
        ),
        const SizedBox(width: 3.5),
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 9,
            fontWeight: completed ? FontWeight.bold : FontWeight.w500,
            color: completed
                ? activeColor
                : AppTheme.textSecondary.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildMilestoneConnector(bool active) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Container(
        width: 12,
        height: 1.5,
        color: active
            ? AppTheme.primaryColor.withValues(alpha: 0.6)
            : AppTheme.borderColor.withValues(alpha: 0.6),
      ),
    );
  }

  Widget _buildUserTypeBadge(BuildContext context, String userName) {
    final type = widget.userType;
    if (type == 'Guest' || type == 'Admin' || type == 'Sales') {
      return const SizedBox.shrink();
    }

    final isDealer = type == 'Dealer';
    final bgColor = isDealer
        ? const Color(0xFF10B981).withValues(alpha: 0.08)
        : const Color(0xFFF59E0B).withValues(alpha: 0.08);
    final textColor = isDealer
        ? const Color(0xFF10B981)
        : const Color(0xFFF59E0B);
    final icon = isDealer ? Icons.verified_rounded : Icons.info_outline_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: textColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: textColor),
          const SizedBox(width: 2),
          Text(
            type,
            style: GoogleFonts.outfit(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignedAgentBadge(String? agentName) {
    if (agentName == null || agentName.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    final clean = agentName.trim();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6.5, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF6366F1).withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: const Color(0xFF6366F1).withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.support_agent_rounded,
            size: 11,
            color: Color(0xFF6366F1),
          ),
          const SizedBox(width: 3),
          Text(
            'Agent: $clean',
            style: GoogleFonts.outfit(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF4F46E5),
            ),
          ),
        ],
      ),
    );
  }
}
