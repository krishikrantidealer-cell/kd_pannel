import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kd_pannel/app_theme.dart';
import 'package:kd_pannel/core/responsive/responsive.dart';

class UserActivityAuditTab extends StatefulWidget {
  final List<String> userIdentifiers;
  final List<Map<String, dynamic>> events;
  final bool isLoading;
  final VoidCallback onRefresh;
  final bool isLoadingMore;
  final bool hasReachedMax;
  final VoidCallback? onLoadMore;

  const UserActivityAuditTab({
    super.key,
    required this.userIdentifiers,
    required this.events,
    required this.isLoading,
    required this.onRefresh,
    this.isLoadingMore = false,
    this.hasReachedMax = false,
    this.onLoadMore,
  });

  @override
  State<UserActivityAuditTab> createState() => _UserActivityAuditTabState();
}

class _UserActivityAuditTabState extends State<UserActivityAuditTab> {
  int currentPage = 1;
  static const int pageSize = 5;
  final Set<int> _expandedIndices = {};
  String _selectedCategory = 'all';
  String _selectedActorScope = 'all'; // 'all', 'user', 'sales'

  bool _isSalesActorEvent(Map<String, dynamic> e) {
    final payload = e['payload'] is Map
        ? Map<String, dynamic>.from(e['payload'])
        : <String, dynamic>{};
    final eventType =
        (e['eventType'] ?? e['event'] ?? '').toString().toLowerCase();

    // 1. Explicit Staff / CRM action types are ALWAYS Sales/Staff actions
    const staffEventTypes = {
      'assign_agent',
      'bulk_assign_agent',
      'update_dealer_status',
      'update_lead_status',
      'add_dealer_note',
      'add_lead_note',
      'note_added',
      'toggle_block',
      'edit_dealer',
      'edit_lead',
      'delete_lead',
      'delete_dealer',
      'kyc_verified',
      'kyc_rejected',
      'kyc_status_updated',
      'lead_converted',
      'call_logged',
      'whatsapp_message_sent',
      'order_created_by_agent',
      'estimate_created',
      'estimate_shared',
      'create_sales_agent',
      'status_changed',
      'lead_status_changed',
      'dealer_status_changed',
    };
    if (staffEventTypes.contains(eventType)) return true;

    // 2. Check actorRole or role in root or payload
    final actorRole = (e['actorRole'] ??
            e['role'] ??
            payload['actorRole'] ??
            payload['role'] ??
            '')
        .toString()
        .toLowerCase();
    if (actorRole == 'sales' ||
        actorRole == 'admin' ||
        actorRole == 'manager' ||
        actorRole == 'telecaller' ||
        actorRole == 'agent') {
      return true;
    }

    // 3. Check performedBy (e.g. "Ankita", "Admin User", "Rajesh")
    final performedBy =
        (e['performedBy'] ?? payload['performedBy'] ?? '').toString().trim();
    if (performedBy.isNotEmpty) {
      final pLower = performedBy.toLowerCase();
      if (pLower.contains('admin') ||
          pLower.contains('sales') ||
          pLower.contains('staff') ||
          pLower.contains('agent')) {
        return true;
      }
      final isCustomerThemself = widget.userIdentifiers.any((id) {
        final idClean = id.trim().toLowerCase();
        return idClean.isNotEmpty &&
            (idClean == pLower || pLower.contains(idClean));
      });
      if (!isCustomerThemself &&
          pLower != 'guest' &&
          pLower != 'anonymous' &&
          pLower != 'customer') {
        return true;
      }
    }

    // 4. Check actor / agentId / adminId in root or payload
    final actor = (e['actor'] ??
            payload['actor'] ??
            payload['agentId'] ??
            payload['adminId'] ??
            payload['assignedBy'] ??
            '')
        .toString()
        .trim();
    if (actor.isNotEmpty) {
      final aLower = actor.toLowerCase();
      final isCustomerThemself = widget.userIdentifiers.any((id) {
        final idClean = id.trim().toLowerCase();
        return idClean.isNotEmpty &&
            (idClean == aLower || aLower.contains(idClean));
      });
      if (!isCustomerThemself &&
          aLower != 'guest' &&
          aLower != 'anonymous' &&
          aLower != 'customer') {
        return true;
      }
    }

    // 5. Default to customer app action
    return false;
  }

  bool _matchesCategory(String eventType, String category, bool isSalesEvent) {
    if (category == 'all') return true;
    if (category == 'shopping') {
      return eventType == 'add_to_cart' ||
          eventType == 'checkout_started' ||
          eventType == 'apply_coupon' ||
          eventType == 'product_search';
    }
    if (category == 'payments') {
      return eventType == 'payment_initiated' ||
          eventType == 'payment_success' ||
          eventType == 'payment_failed';
    }
    if (category == 'marketing') {
      return eventType == 'deep_link_open' ||
          eventType == 'banner_click' ||
          eventType == 'notification_open' ||
          eventType == 'app_launch';
    }
    if (category == 'crm') {
      return isSalesEvent ||
          eventType == 'assign_agent' ||
          eventType == 'update_lead_status' ||
          eventType == 'add_lead_note' ||
          eventType == 'edit_lead' ||
          eventType == 'toggle_block' ||
          eventType == 'lead_converted';
    }
    if (category == 'system') {
      return eventType == 'login_success' ||
          eventType == 'app_error' ||
          eventType == 'profile_view';
    }
    return true;
  }

  Map<String, dynamic> _getEventVisuals(String eventType) {
    switch (eventType) {
      case 'login_success':
        return {
          'icon': Icons.login_rounded,
          'color': Colors.green,
          'label': 'Login Success',
        };
      case 'app_launch':
        return {
          'icon': Icons.launch_rounded,
          'color': Colors.blue,
          'label': 'App Launched',
        };
      case 'deep_link_open':
        return {
          'icon': Icons.link_rounded,
          'color': Colors.purple,
          'label': 'Deep Link Visit',
        };
      case 'banner_click':
        return {
          'icon': Icons.ads_click_rounded,
          'color': Colors.orange,
          'label': 'Marketing Banner Click',
        };
      case 'notification_open':
        return {
          'icon': Icons.notification_important_rounded,
          'color': Colors.redAccent,
          'label': 'Notification Interaction',
        };
      case 'profile_view':
        return {
          'icon': Icons.visibility_rounded,
          'color': Colors.blue,
          'label': 'Profile View',
        };
      case 'product_search':
        return {
          'icon': Icons.search_rounded,
          'color': Colors.teal,
          'label': 'Product Search',
        };
      case 'add_to_cart':
        return {
          'icon': Icons.add_shopping_cart_rounded,
          'color': Colors.orange,
          'label': 'Add to Cart',
        };
      case 'checkout_started':
        return {
          'icon': Icons.shopping_bag_rounded,
          'color': Colors.purple,
          'label': 'Checkout Started',
        };
      case 'apply_coupon':
        return {
          'icon': Icons.local_offer_rounded,
          'color': Colors.indigo,
          'label': 'Apply Coupon',
        };
      case 'payment_initiated':
        return {
          'icon': Icons.payment_rounded,
          'color': Colors.cyan,
          'label': 'Payment Initiated',
        };
      case 'payment_failed':
        return {
          'icon': Icons.error_outline_rounded,
          'color': Colors.red,
          'label': 'Payment Failed',
        };
      case 'payment_success':
        return {
          'icon': Icons.check_circle_outline_rounded,
          'color': const Color(0xFF10B981),
          'label': 'Payment Success',
        };
      case 'coupon_created':
        return {
          'icon': Icons.add_circle_outline_rounded,
          'color': Colors.indigo,
          'label': 'Coupon Created',
        };
      case 'coupon_deleted':
        return {
          'icon': Icons.delete_outline_rounded,
          'color': Colors.redAccent,
          'label': 'Coupon Deleted',
        };
      case 'app_error':
        return {
          'icon': Icons.warning_amber_rounded,
          'color': Colors.deepOrange,
          'label': 'Application Error',
        };
      case 'assign_agent':
      case 'bulk_assign_agent':
        return {
          'icon': Icons.badge_outlined,
          'color': Colors.indigo,
          'label': 'Agent Assignment',
        };
      case 'toggle_block':
        return {
          'icon': Icons.block_flipped,
          'color': Colors.red,
          'label': 'Account Status Change',
        };
      case 'update_lead_status':
      case 'update_dealer_status':
        return {
          'icon': Icons.flag_outlined,
          'color': Colors.blue,
          'label': 'Status Update',
        };
      case 'add_lead_note':
      case 'add_dealer_note':
        return {
          'icon': Icons.note_add_outlined,
          'color': Colors.amber,
          'label': 'Follow-Up Note Added',
        };
      case 'edit_lead':
      case 'edit_dealer':
        return {
          'icon': Icons.edit_note_rounded,
          'color': Colors.blueGrey,
          'label': 'Profile Details Edited',
        };
      case 'lead_converted':
        return {
          'icon': Icons.verified_rounded,
          'color': const Color(0xFF10B981),
          'label': 'Converted to Dealer',
        };
      default:
        return {
          'icon': Icons.info_outline_rounded,
          'color': Colors.grey,
          'label': eventType.replaceAll('_', ' ').toUpperCase(),
        };
    }
  }

  String _formatTime(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays == 1) return 'Yesterday';
      return '${diff.inDays} days ago';
    } catch (_) {
      return dateStr;
    }
  }

  String _getHumanReadableDetails(
    String eventType,
    String originalDetails,
    Map<String, dynamic> payload,
  ) {
    switch (eventType) {
      case 'add_to_cart':
        final prod =
            payload['productName'] ?? payload['productId'] ?? 'an item';
        final qty = payload['quantity'] ?? 1;
        final price = payload['price'] != null
            ? ' at ₹${payload['price']}'
            : '';
        return 'Added "$prod" (Qty: $qty)$price to the shopping cart.';
      case 'checkout_started':
        final val = payload['cartValue'] ?? '0';
        final items = payload['itemCount'] ?? '0';
        return 'Initiated checkout for $items items worth ₹$val.';
      case 'apply_coupon':
        final code = payload['couponCode'] ?? 'coupon';
        final success = payload['success'] == false
            ? 'unsuccessfully'
            : 'successfully';
        return 'Attempted to apply discount coupon "$code" $success.';
      case 'payment_success':
        final amt = payload['amount'] ?? '0';
        final id = payload['orderId'] ?? '-';
        return 'Successfully completed payment of ₹$amt for Order ID: $id.';
      case 'payment_failed':
        final reason = payload['reason'] ?? 'declined';
        final amt = payload['amount'] ?? '0';
        return 'Payment attempt of ₹$amt failed. Reason: $reason.';
      case 'payment_initiated':
        final amt = payload['amount'] ?? '0';
        return 'Initiated payment checkout for ₹$amt.';
      case 'banner_click':
        final banner =
            payload['bannerTitle'] ?? payload['bannerId'] ?? 'a promotion';
        return 'Clicked on marketing campaign "$banner".';
      case 'notification_open':
        final title = payload['title'] ?? 'notification';
        return 'Tapped on push notification: "$title".';
      case 'product_search':
        final query = payload['searchQuery'] ?? payload['query'] ?? '';
        return 'Searched for products matching: "$query".';
      case 'assign_agent':
        return 'A sales representative was assigned.';
      case 'update_lead_status':
      case 'update_dealer_status':
        final status = payload['newStatus'] ?? payload['status'] ?? 'updated';
        return 'Status was updated to "$status".';
      case 'add_lead_note':
      case 'add_dealer_note':
        return 'A follow-up note was added by the sales team.';
      case 'lead_converted':
        return 'Lead was successfully converted into a verified dealer.';
      default:
        return originalDetails.isNotEmpty
            ? originalDetails
            : eventType.replaceAll('_', ' ').toUpperCase();
    }
  }

  Widget _buildActorScopeSelector(int allCount, int userCount, int salesCount) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildScopeButton(
              id: 'all',
              label: 'All Activities',
              count: allCount,
              icon: Icons.layers_outlined,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildScopeButton(
              id: 'user',
              label: 'Customer App',
              count: userCount,
              icon: Icons.phone_android_rounded,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildScopeButton(
              id: 'sales',
              label: 'Staff Actions',
              count: salesCount,
              icon: Icons.badge_outlined,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScopeButton({
    required String id,
    required String label,
    required int count,
    required IconData icon,
  }) {
    final bool isSelected = _selectedActorScope == id;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedActorScope = id;
          currentPage = 1;
        });
      },
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected
                  ? AppTheme.primaryColor
                  : const Color(0xFF64748B),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                '$label ($count)',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? const Color(0xFF1F2937)
                      : const Color(0xFF64748B),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterTabs() {
    final List<Map<String, String>> tabs = [
      {'id': 'all', 'label': 'All Categories'},
      {'id': 'shopping', 'label': 'Cart & Store'},
      {'id': 'payments', 'label': 'Payments'},
      {'id': 'marketing', 'label': 'Marketing'},
      {'id': 'crm', 'label': 'Staff & CRM'},
      {'id': 'system', 'label': 'System Logs'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: tabs.map((tab) {
          final isSelected = _selectedCategory == tab['id'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedCategory = tab['id']!;
                  currentPage = 1;
                });
              },
              borderRadius: BorderRadius.circular(20),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primaryColor.withOpacity(0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.primaryColor.withOpacity(0.3)
                        : const Color(0xFFE2E8F0),
                    width: 1.5,
                  ),
                ),
                child: Text(
                  tab['label']!,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected
                        ? AppTheme.primaryColor
                        : const Color(0xFF6B7280),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPayloadChips(Map<String, dynamic> payload) {
    final List<Widget> chips = [];
    payload.forEach((key, value) {
      if (value == null || value.toString().isEmpty) return;
      if (key == 'details' ||
          key == 'dealerId' ||
          key == 'dealerName' ||
          key == 'leadId' ||
          key == 'leadName') {
        return;
      }

      String displayKey = key;
      if (key == 'productId') displayKey = 'Product';
      if (key == 'productName') displayKey = 'Product';
      if (key == 'couponCode') displayKey = 'Coupon';
      if (key == 'cartValue') displayKey = 'Value';
      if (key == 'itemCount') displayKey = 'Items';
      if (key == 'amount') displayKey = 'Amount';

      String displayVal = value.toString();
      if (key == 'amount' || key == 'cartValue' || key == 'price') {
        displayVal = '₹$value';
      }

      chips.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '$displayKey: $displayVal',
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF475569),
            ),
          ),
        ),
      );
    });

    if (chips.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(spacing: 6, runSpacing: 6, children: chips),
    );
  }

  Widget _buildExpandedPayloadList(Map<String, dynamic> payload) {
    final List<Widget> rows = [];

    payload.forEach((key, value) {
      if (value == null || value.toString().isEmpty) return;
      if (key == 'details' ||
          key == 'dealerId' ||
          key == 'dealerName' ||
          key == 'leadId' ||
          key == 'leadName') {
        return;
      }

      String displayKey = key;
      if (key == 'productId') displayKey = 'Product ID';
      if (key == 'productName') displayKey = 'Product Name';
      if (key == 'couponCode') displayKey = 'Coupon Code';
      if (key == 'cartValue') displayKey = 'Cart Total Value';
      if (key == 'itemCount') displayKey = 'Number of Items';
      if (key == 'amount') displayKey = 'Transaction Amount';
      if (key == 'price') displayKey = 'Price per Unit';
      if (key == 'quantity') displayKey = 'Quantity Purchased';
      if (key == 'orderId') displayKey = 'Order ID';
      if (key == 'gateway') displayKey = 'Payment Gateway';
      if (key == 'reason') displayKey = 'Failure Reason';
      if (key == 'ip') displayKey = 'IP Address';
      if (key == 'userAgent') displayKey = 'Browser Signature';

      if (displayKey == key) {
        displayKey = key
            .replaceAll(RegExp(r'(?<!^)(?=[A-Z])|_'), ' ')
            .toUpperCase();
      } else {
        displayKey = displayKey.toUpperCase();
      }

      String displayVal = value.toString();
      if (key == 'amount' || key == 'cartValue' || key == 'price') {
        displayVal = '₹$value';
      }

      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  displayKey,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: Text(
                  displayVal,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1F2937),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });

    if (rows.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DETAILED ACTIVITY METRICS',
            style: GoogleFonts.outfit(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: AppTheme.primaryColor,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          ...rows,
        ],
      ),
    );
  }

  Widget? _buildFollowUpTip(String eventType, Map<String, dynamic> payload) {
    String? tip;
    Color tipColor = Colors.orange;
    IconData tipIcon = Icons.lightbulb_outline_rounded;

    if (eventType == 'payment_failed') {
      tip =
          'Payment Failed: Customer experienced a transaction drop. Call them to assist with alternative options.';
      tipColor = Colors.red;
      tipIcon = Icons.contact_phone_outlined;
    } else if (eventType == 'checkout_started') {
      tip =
          'Checkout Abandoned: Cart is active. Follow up via WhatsApp to offer a discount code and finalize sale.';
      tipColor = Colors.amber.shade800;
      tipIcon = Icons.chat_bubble_outline_rounded;
    } else if (eventType == 'add_to_cart') {
      tip =
          'Cart Updated: Items added but not checked out yet. Monitor active status.';
      tipColor = Colors.blue;
      tipIcon = Icons.shopping_cart_outlined;
    }

    if (tip == null) return null;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: tipColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tipColor.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Icon(tipIcon, size: 14, color: tipColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              tip,
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: tipColor.withOpacity(0.9),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    final sortedEvents = List<Map<String, dynamic>>.from(widget.events)
      ..sort((a, b) {
        final aTs = a['timestamp']?.toString() ?? '';
        final bTs = b['timestamp']?.toString() ?? '';
        return bTs.compareTo(aTs);
      });

    // Compute scope counts
    int userEventsCount = 0;
    int salesEventsCount = 0;
    for (final e in sortedEvents) {
      if (_isSalesActorEvent(e)) {
        salesEventsCount++;
      } else {
        userEventsCount++;
      }
    }
    final int allEventsCount = sortedEvents.length;

    final filteredEvents = sortedEvents.where((e) {
      final type = e['eventType']?.toString() ?? '';
      final bool isSalesEvent = _isSalesActorEvent(e);

      // 1. Actor scope filter
      if (_selectedActorScope == 'user' && isSalesEvent) return false;
      if (_selectedActorScope == 'sales' && !isSalesEvent) return false;

      // 2. Category filter
      return _matchesCategory(type, _selectedCategory, isSalesEvent);
    }).toList();

    final totalEvents = filteredEvents.length;
    final int totalPages = (totalEvents / pageSize).ceil().clamp(1, 9999);

    if (currentPage > totalPages) {
      currentPage = totalPages;
    }

    final startIndex = (currentPage - 1) * pageSize;
    final endIndex = startIndex + pageSize;
    final currentPageEvents = filteredEvents.sublist(
      startIndex,
      endIndex > totalEvents ? totalEvents : endIndex,
    );

    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(
                      'Live Activity & Events Feed',
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (!widget.isLoading)
                      IconButton(
                        icon: const Icon(
                          Icons.refresh_rounded,
                          size: 18,
                          color: AppTheme.primaryColor,
                        ),
                        onPressed: widget.onRefresh,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: 'Refresh Activity Feed',
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$totalEvents ${totalEvents == 1 ? 'event' : 'events'}',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildActorScopeSelector(
            allEventsCount,
            userEventsCount,
            salesEventsCount,
          ),
          _buildFilterTabs(),
          const SizedBox(height: 16),
          if (widget.isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (currentPageEvents.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.history_toggle_off_rounded,
                    size: 36,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No activities found for this selection.',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: currentPageEvents.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final e = currentPageEvents[index];
                final type = e['eventType']?.toString() ?? 'event';
                final visuals = _getEventVisuals(type);
                final payload = e['payload'] is Map
                    ? Map<String, dynamic>.from(e['payload'])
                    : <String, dynamic>{};
                final isExpanded = _expandedIndices.contains(index);
                final followUpTip = _buildFollowUpTip(type, payload);
                final bool isSalesEvent = _isSalesActorEvent(e);

                String actorDisplayName = 'Customer';
                if (isSalesEvent) {
                  final pb = (e['performedBy'] ?? payload['performedBy'] ?? '')
                      .toString()
                      .trim();
                  if (pb.isNotEmpty) {
                    actorDisplayName = 'Staff: $pb';
                  } else {
                    actorDisplayName = 'Staff Action';
                  }
                }

                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSalesEvent
                          ? Colors.indigo.shade200
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: (visuals['color'] as Color).withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              visuals['icon'] as IconData,
                              size: 16,
                              color: visuals['color'] as Color,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      visuals['label'] as String,
                                      style: GoogleFonts.outfit(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF1F2937),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSalesEvent
                                            ? Colors.indigo.withOpacity(0.1)
                                            : Colors.blue.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        actorDisplayName,
                                        style: GoogleFonts.outfit(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: isSalesEvent
                                              ? Colors.indigo.shade700
                                              : Colors.blue.shade700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _formatTime(
                                    e['timestamp']?.toString() ??
                                        e['createdAt']?.toString() ??
                                        '',
                                  ),
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    color: const Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              isExpanded
                                  ? Icons.keyboard_arrow_up_rounded
                                  : Icons.keyboard_arrow_down_rounded,
                              size: 18,
                              color: const Color(0xFF64748B),
                            ),
                            onPressed: () {
                              setState(() {
                                if (isExpanded) {
                                  _expandedIndices.remove(index);
                                } else {
                                  _expandedIndices.add(index);
                                }
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _getHumanReadableDetails(
                          type,
                          e['details']?.toString() ?? '',
                          payload,
                        ),
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF334155),
                        ),
                      ),
                      _buildPayloadChips(payload),
                      if (followUpTip != null) followUpTip,
                      if (isExpanded) _buildExpandedPayloadList(payload),
                    ],
                  ),
                );
              },
            ),
            if (totalPages > 1) ...[
              const SizedBox(height: 16),
              _buildPagination(
                totalEvents,
                startIndex + 1,
                endIndex > totalEvents ? totalEvents : endIndex,
                totalPages,
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildPagination(int total, int start, int end, int totalPages) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Showing $start-$end of $total',
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF64748B),
          ),
        ),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded),
              iconSize: 20,
              onPressed: currentPage > 1
                  ? () => setState(() => currentPage--)
                  : null,
            ),
            Text(
              '$currentPage / $totalPages',
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1E293B),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right_rounded),
              iconSize: 20,
              onPressed: currentPage < totalPages
                  ? () => setState(() => currentPage++)
                  : null,
            ),
          ],
        ),
      ],
    );
  }
}
