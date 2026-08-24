import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kd_pannel/app_theme.dart';
import 'package:kd_pannel/features/shared/widgets/whatsapp_chat_dialog.dart';
import 'package:kd_pannel/features/shared/widgets/events/events_helper.dart';
import 'package:url_launcher/url_launcher.dart';

class EventLogCard extends StatefulWidget {
  final String user;
  final String? userPhone;
  final String? rawUser;
  final String time;
  final String device;
  final String details;
  final Map<String, dynamic> payload;
  final Color accentColor;

  const EventLogCard({
    super.key,
    required this.user,
    this.userPhone,
    this.rawUser,
    required this.time,
    required this.device,
    required this.details,
    required this.payload,
    required this.accentColor,
  });

  @override
  State<EventLogCard> createState() => _EventLogCardState();
}

class _EventLogCardState extends State<EventLogCard> {
  bool _expanded = false;
  bool _hovered = false;
  bool _showRawJson = false;

  Future<void> _makePhoneCall(String phoneNumber) async {
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleanPhone.isEmpty) return;
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _openWhatsApp(BuildContext context, String phoneNumber, String name) {
    showDialog(
      context: context,
      builder: (context) => WhatsAppChatDialog(phone: phoneNumber, name: name),
    );
  }

  Map<String, dynamic> _getEventTheme() {
    final payload = widget.payload;
    final action = (payload['action'] ?? payload['eventType'] ?? '')
        .toString()
        .toLowerCase();

    if (action.contains('payment_failed') || action == 'payment_fail') {
      return {
        'color': const Color(0xFFEF4444),
        'bgColor': const Color(0xFFFEF2F2),
        'borderColor': const Color(0xFFFCA5A5),
        'tag': 'FAILED PAYMENT',
        'icon': Icons.error_rounded,
      };
    } else if (action.contains('payment_success') || action.contains('order')) {
      return {
        'color': const Color(0xFF10B981),
        'bgColor': const Color(0xFFECFDF5),
        'borderColor': const Color(0xFF6EE7B7),
        'tag': 'SUCCESS',
        'icon': Icons.check_circle_rounded,
      };
    } else if (action == 'cart_add' ||
        action == 'add_to_cart' ||
        action.contains('checkout')) {
      return {
        'color': const Color(0xFFF59E0B),
        'bgColor': const Color(0xFFFFFBEB),
        'borderColor': const Color(0xFFFDE68A),
        'tag': 'HIGH INTENT',
        'icon': Icons.shopping_cart_rounded,
      };
    } else if (action.contains('search') || action.contains('view')) {
      return {
        'color': const Color(0xFF0284C7),
        'bgColor': const Color(0xFFF0F9FF),
        'borderColor': const Color(0xFFBAE6FD),
        'tag': 'BROWSING',
        'icon': Icons.visibility_rounded,
      };
    }
    return {
      'color': AppTheme.primaryColor,
      'bgColor': AppTheme.primaryColor.withValues(alpha: 0.06),
      'borderColor': AppTheme.primaryColor.withValues(alpha: 0.2),
      'tag': 'ACTIVITY',
      'icon': Icons.bolt_rounded,
    };
  }

  String _getHumanHeadline() {
    final payload = widget.payload;
    final action = (payload['action'] ?? payload['eventType'] ?? '')
        .toString()
        .toLowerCase();
    final details = widget.details;

    if (action == 'cart_add' || action == 'add_to_cart') {
      final qty = payload['quantity'] ?? 1;
      final prodName = payload['product_name'] ?? 'Product';
      final price = payload['unit_price'] ?? payload['price'];
      final priceStr = price is num
          ? ' (₹${(price * qty).toStringAsFixed(0)})'
          : '';
      return '🛒 Added $qty' + 'x $prodName to Cart$priceStr';
    } else if (action.contains('payment_failed') || action == 'payment_fail') {
      final amt =
          payload['amount'] ?? payload['total_price'] ?? payload['grand_total'];
      final amtStr = amt is num ? ' ₹${amt.toStringAsFixed(0)}' : '';
      final gw =
          payload['payment_method'] ?? payload['gateway'] ?? 'Online Payment';
      final reason = payload['error_message'] ?? payload['reason'];
      final reasonStr = reason != null && reason.toString().isNotEmpty
          ? ' — Cause: $reason'
          : '';
      return '❌ Payment of$amtStr Failed via $gw$reasonStr';
    } else if (action.contains('payment_success') ||
        action.contains('payment_completed')) {
      final amt =
          payload['amount'] ?? payload['total_price'] ?? payload['grand_total'];
      final amtStr = amt is num ? ' ₹${amt.toStringAsFixed(0)}' : '';
      final gw =
          payload['payment_method'] ?? payload['gateway'] ?? 'Online Payment';
      return '🟢 Payment of$amtStr Received via $gw';
    } else if (action.contains('order') ||
        action.contains('checkout_completed')) {
      final orderId = payload['order_id'] ?? payload['orderId'] ?? '';
      final amt =
          payload['amount'] ?? payload['total_price'] ?? payload['total'];
      final amtStr = amt is num ? ' • Total: ₹${amt.toStringAsFixed(0)}' : '';
      return '📦 Order ${orderId.isNotEmpty ? "#$orderId" : ""} Placed Successfully$amtStr';
    } else if (action.contains('checkout')) {
      final items = payload['item_count'] ?? payload['items_count'];
      final itemsStr = items != null ? ' ($items items in cart)' : '';
      return '🛍️ Started Checkout Process$itemsStr';
    } else if (action.contains('search')) {
      final query = payload['query'] ?? payload['search_term'] ?? '';
      final results = payload['results_count'];
      final resultsStr = results != null ? ' ($results items found)' : '';
      return '🔍 Searched for "${query.isNotEmpty ? query : details}"$resultsStr';
    } else if (action.contains('login') || action.contains('auth')) {
      final method = payload['method'] ?? payload['auth_method'] ?? 'App OTP';
      return '🔑 Logged in via $method';
    } else if (action.contains('view') || action.contains('screen')) {
      final page = payload['screen_name'] ?? payload['product_name'] ?? details;
      return '👀 Viewed: ${page.isNotEmpty ? page : "App Screen"}';
    } else if (details.isNotEmpty) {
      return details;
    }
    return '⚡ Customer activity logged (${action.isNotEmpty ? action : "User Action"})';
  }

  String? _getSalesActionRecommendation() {
    final payload = widget.payload;
    final action = (payload['action'] ?? payload['eventType'] ?? '')
        .toString()
        .toLowerCase();

    if (action == 'cart_add' || action == 'add_to_cart') {
      return '💡 Sales Tip: High purchase intent! Call the customer to assist with ordering or offer special pricing.';
    } else if (action.contains('payment_failed') || action == 'payment_fail') {
      return '🚨 Sales Tip: Payment failed! Contact user now to help them finish order via manual UPI or Bank Deposit.';
    } else if (action.contains('checkout')) {
      return '⚡ Sales Tip: Customer is in checkout! Follow up on WhatsApp if they drop off without ordering.';
    } else if (action.contains('search') || action.contains('view')) {
      return '🔍 Sales Tip: Active browsing. Reach out to guide them on product choice.';
    }
    return null;
  }

  String _formatKey(String key) {
    final mappedKeys = {
      'unit_price': 'Unit Price (₹)',
      'product_name': 'Product Name',
      'variant_name': 'Variant',
      'quantity': 'Quantity',
      'total_price': 'Total Price (₹)',
      'grand_total': 'Grand Total (₹)',
      'amount': 'Amount (₹)',
      'payment_method': 'Payment Mode',
      'gateway': 'Payment Gateway',
      'screen_name': 'Page Viewed',
      'error_message': 'Failure Reason',
      'reason': 'Failure Reason',
      'user_phone': 'Customer Phone',
      'query': 'Search Query',
      'results_count': 'Results Found',
      'item_count': 'Total Items',
    };
    if (mappedKeys.containsKey(key)) return mappedKeys[key]!;

    final words = key.split('_');
    return words
        .map((w) {
          if (w.isEmpty) return '';
          final lower = w.toLowerCase();
          if (lower == 'sso') return 'SSO';
          if (lower == 'id') return 'ID';
          if (lower == 'txn') return 'TXN';
          if (lower == 'kyc') return 'KYC';
          if (lower == 'gst') return 'GST';
          if (lower == 'otp') return 'OTP';
          return w[0].toUpperCase() + w.substring(1);
        })
        .join(' ');
  }

  dynamic _formatValue(String key, dynamic value) {
    if (value == null) return 'N/A';

    if (key.contains('amount') ||
        key.contains('total') ||
        key == 'subtotal' ||
        key == 'tax' ||
        key == 'shipping' ||
        key == 'grand_total' ||
        key == 'unit_price') {
      if (value is num) {
        return '₹${value.toStringAsFixed(2).replaceAll('.00', '')}';
      }
    }

    if (key.contains('at') && value is String && value.contains('T')) {
      try {
        final dt = DateTime.parse(value);
        return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      } catch (_) {}
    }

    if (value is List) {
      return Wrap(
        spacing: 4,
        runSpacing: 4,
        children: value
            .map<Widget>(
              (item) => Container(
                constraints: const BoxConstraints(maxWidth: 240),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.lightBorderColor,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.file_present_rounded,
                      size: 10,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        item.toString(),
                        style: GoogleFonts.outfit(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textBody,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      );
    }

    if (value is Map) {
      if (value.isEmpty) return 'None';
      return Wrap(
        spacing: 4,
        runSpacing: 4,
        children: value.entries
            .map<Widget>(
              (entry) => Container(
                constraints: const BoxConstraints(maxWidth: 240),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.lightBorderColor,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Text(
                  '${entry.key}: ${entry.value}',
                  style: GoogleFonts.outfit(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textBody,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
            .toList(),
      );
    }

    if (value is bool) {
      return value ? 'Yes' : 'No';
    }

    return value.toString();
  }

  Widget _buildStructuredPayload(Map<String, dynamic> payload) {
    final keys = payload.keys.where((k) {
      final lower = k.toLowerCase();
      return lower != 'action' &&
          lower != 'status' &&
          lower != 'items' &&
          lower != '_id' &&
          lower != '\$oid' &&
          lower != '__v' &&
          lower != 'schemaversion' &&
          lower != 'sessionid' &&
          lower != 'user_agent_raw' &&
          lower != 'sdk_version';
    }).toList();

    if (keys.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 450;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: keys.map((key) {
            final val = payload[key];
            final displayKey = _formatKey(key);
            final displayVal = _formatValue(key, val);

            final double itemWidth = isMobile
                ? constraints.maxWidth
                : (constraints.maxWidth - 10) / 2;

            return Container(
              width: itemWidth,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: AppTheme.borderColor.withValues(alpha: 0.6),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 4,
                    child: Text(
                      displayKey,
                      style: GoogleFonts.outfit(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    flex: 6,
                    child: displayVal is Widget
                        ? displayVal
                        : Text(
                            displayVal.toString(),
                            style: GoogleFonts.outfit(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildCartAddDetails(Map<String, dynamic> payload) {
    List<dynamic> items = [];
    if (payload['items'] != null && payload['items'] is List) {
      items = payload['items'] as List;
    } else if (payload['product_id'] != null) {
      items = [
        {
          'product_id': payload['product_id'],
          'product_name': payload['product_name'] ?? 'Unknown Product',
          'variant_id': payload['variant_id'] ?? '',
          'variant_name': payload['variant_name'] ?? '',
          'quantity': payload['quantity'] ?? 1,
          'price': payload['unit_price'] ?? 0.0,
        },
      ];
    }

    if (items.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.6)),
        ),
        child: Text(
          widget.details,
          style: GoogleFonts.outfit(
            fontSize: 13.5,
            color: AppTheme.textBody,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final item in items) {
      if (item is Map) {
        final map = Map<String, dynamic>.from(item);
        final prodId = map['product_id']?.toString() ?? 'unknown';
        grouped.putIfAbsent(prodId, () => []).add(map);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0, left: 2.0),
          child: Row(
            children: [
              const Icon(
                Icons.shopping_cart_outlined,
                size: 15,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(width: 6),
              Text(
                'Shopping Cart Items',
                style: GoogleFonts.outfit(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
        ),
        ...grouped.entries.map((entry) {
          final prodItems = entry.value;
          final prodName =
              prodItems.first['product_name']?.toString() ?? 'Unknown Product';

          return Container(
            margin: const EdgeInsets.only(bottom: 8.0),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.8)),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final bool isNarrow = constraints.maxWidth < 450;

                final productHeader = Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.inventory_2_outlined,
                        size: 14,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        prodName,
                        style: GoogleFonts.outfit(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                );

                final variantList = Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: prodItems.map<Widget>((item) {
                    final variantName = item['variant_name']?.toString() ?? '';
                    final qty = item['quantity'] ?? 1;
                    final price = item['price'] ?? 0.0;
                    final formattedPrice =
                        '₹${(price * qty).toStringAsFixed(2).replaceAll('.00', '')}';

                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.lightBorderColor,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: AppTheme.borderColor.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (variantName.isNotEmpty) ...[
                            Text(
                              variantName,
                              style: GoogleFonts.outfit(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textBody,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Container(
                              width: 1,
                              height: 10,
                              color: AppTheme.textSecondary.withValues(alpha: 0.3),
                            ),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            '${qty}x',
                            style: GoogleFonts.outfit(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '($formattedPrice)',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );

                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      productHeader,
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.only(left: 4.0),
                        child: variantList,
                      ),
                    ],
                  );
                } else {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(flex: 4, child: productHeader),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 6,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: variantList,
                        ),
                      ),
                    ],
                  );
                }
              },
            ),
          );
        }).toList(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final String fullInitials = widget.user
        .split(' ')
        .map((e) => e.isNotEmpty ? e[0] : '')
        .join()
        .toUpperCase();
    final String initials = fullInitials.length <= 2
        ? fullInitials
        : fullInitials.substring(0, 2);

    final theme = _getEventTheme();
    final Color severityColor = theme['color'] as Color;
    final Color severityBg = theme['bgColor'] as Color;
    final Color severityBorder = theme['borderColor'] as Color;
    final String tagLabel = theme['tag'] as String;
    final IconData severityIcon = theme['icon'] as IconData;

    final String headline = _getHumanHeadline();
    final String? salesTip = _getSalesActionRecommendation();
    final String? phone = widget.userPhone;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: _hovered
              ? AppTheme.backgroundColor.withValues(alpha: 0.7)
              : AppTheme.backgroundColor.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _hovered
                ? severityColor.withValues(alpha: 0.35)
                : AppTheme.borderColor,
            width: _hovered ? 1.5 : 1.0,
          ),
          boxShadow: _hovered
              ? [
                  BoxShadow(
                    color: severityColor.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Header Row with Avatar, Name, Phone & Quick Actions
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        severityColor.withValues(alpha: 0.15),
                        severityColor.withValues(alpha: 0.04),
                      ],
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(color: severityColor.withValues(alpha: 0.25)),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initials.isNotEmpty ? initials : 'U',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: severityColor,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: GestureDetector(
                                onTap: () => navigateToProfile(
                                  context,
                                  widget.rawUser ??
                                      widget.userPhone ??
                                      widget.user,
                                  phone: widget.userPhone,
                                  name: widget.user,
                                  userDetails:
                                      widget.payload['userDetails']
                                              is Map<String, dynamic>
                                          ? widget.payload['userDetails']
                                              as Map<String, dynamic>
                                          : null,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        widget.user,
                                        style: GoogleFonts.outfit(
                                          fontSize: 15.5,
                                          fontWeight: FontWeight.w800,
                                          color: AppTheme.textPrimary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.open_in_new_rounded,
                                      size: 12,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Event Severity Tag Pill
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: severityBg,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: severityBorder),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  severityIcon,
                                  size: 11,
                                  color: severityColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  tagLabel,
                                  style: GoogleFonts.outfit(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    color: severityColor,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (phone != null && phone.isNotEmpty) ...[
                            Text(
                              phone,
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Direct Sales Action Buttons: Call & WhatsApp
                            InkWell(
                              onTap: () => _makePhoneCall(phone),
                              borderRadius: BorderRadius.circular(4),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withValues(
                                    alpha: 0.08,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.phone,
                                      size: 11,
                                      color: AppTheme.primaryColor,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      'Call',
                                      style: GoogleFonts.outfit(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            InkWell(
                              onTap: () =>
                                   _openWhatsApp(context, phone, widget.user),
                              borderRadius: BorderRadius.circular(4),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF10B981,
                                  ).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.chat_bubble_outline_rounded,
                                      size: 11,
                                      color: Color(0xFF10B981),
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      'WhatsApp',
                                      style: GoogleFonts.outfit(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF10B981),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            '•  ${widget.time}',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Plain English Human-Readable Headline Container
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: severityBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: severityBorder.withValues(alpha: 0.7)),
              ),
              child: Text(
                headline,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),

            // Sales Action Recommendation Tip Box
            if (salesTip != null) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFCD34D)),
                ),
                child: Text(
                  salesTip,
                  style: GoogleFonts.outfit(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF92400E),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 10),

            // Payload or Cart Details Section
            widget.payload['action'] == 'cart_add'
                ? _buildCartAddDetails(widget.payload)
                : const SizedBox.shrink(),

            const SizedBox(height: 6),

            // View Details Toggle / Raw JSON Toggle
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkWell(
                  onTap: () {
                    setState(() {
                      _expanded = !_expanded;
                    });
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 4,
                      horizontal: 2,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _expanded
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          size: 15,
                          color: AppTheme.primaryColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _expanded
                              ? 'Hide Technical Details'
                              : 'View Key Data Fields',
                          style: GoogleFonts.outfit(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_expanded)
                  InkWell(
                    onTap: () {
                      setState(() {
                        _showRawJson = !_showRawJson;
                      });
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 4,
                        horizontal: 8,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _showRawJson
                                ? Icons.grid_view_rounded
                                : Icons.code_rounded,
                            size: 13,
                            color: AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _showRawJson
                                ? 'Structured View'
                                : 'Raw Developer JSON',
                            style: GoogleFonts.outfit(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            if (_expanded) ...[
              const SizedBox(height: 10),
              _showRawJson
                  ? Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        const JsonEncoder.withIndent(
                          '  ',
                        ).convert(widget.payload),
                        style: GoogleFonts.sourceCodePro(
                          fontSize: 11.5,
                          color: const Color(0xFF38BDF8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    )
                  : _buildStructuredPayload(widget.payload),
            ],
          ],
        ),
      ),
    );
  }
}
