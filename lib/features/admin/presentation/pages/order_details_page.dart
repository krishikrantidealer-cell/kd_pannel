import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kd_pannel/app_theme.dart';
import 'package:kd_pannel/core/network/api_client.dart';
import 'package:kd_pannel/core/responsive/responsive.dart';
import 'package:kd_pannel/features/admin/presentation/pages/orders_page.dart';
import 'package:url_launcher/url_launcher.dart';

class OrderDetailsPage extends StatefulWidget {
  const OrderDetailsPage({super.key});

  @override
  State<OrderDetailsPage> createState() => _OrderDetailsPageState();
}

class _OrderDetailsPageState extends State<OrderDetailsPage> {
  OrderModel? _orderRaw;
  OrderModel get _order => _orderRaw!;
  bool _isInitialized = false;
  bool _isPrintHovered = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is OrderModel) {
        _orderRaw = args;
      } else {
        // Automatically redirect to the Orders list page if no order data is present
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/orders');
          }
        });
      }
      _isInitialized = true;
    }
  }

  // --- LOGISTICS URL LAUNCHER ---
  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open link: $urlString'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  // --- CLIPBOARD ACTION ---
  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard!'),
        backgroundColor: AppTheme.success,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  // --- HELPERS ---
  String _formatDateTime(DateTime dt) {
    return '${_formatDate(dt)}, ${_formatTime(dt)}';
  }

  String _formatDate(DateTime dt) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  String _formatTime(DateTime dt) {
    final hr = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final min = dt.minute < 10 ? '0${dt.minute}' : '${dt.minute}';
    return '$hr:$min $ampm';
  }

  String _getCustomerInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts.isNotEmpty && parts[0].isNotEmpty
        ? parts[0][0].toUpperCase()
        : '?';
  }

  Map<String, String> _parseProductTitle(String title) {
    final regExp = RegExp(r'\(([^)]+)\)$');
    final match = regExp.firstMatch(title.trim());
    if (match != null) {
      final packing = match.group(1) ?? '';
      final name = title.substring(0, match.start).trim();
      return {'name': name, 'packing': packing};
    }

    final hyphenIndex = title.lastIndexOf(' - ');
    if (hyphenIndex != -1) {
      final name = title.substring(0, hyphenIndex).trim();
      final packing = title.substring(hyphenIndex + 3).trim();
      return {'name': name, 'packing': packing};
    }

    return {'name': title, 'packing': 'Standard'};
  }

  // --- STAT BADGES ---
  Widget _buildPaymentBadge(String status) {
    Color color;
    switch (status) {
      case 'Paid':
        color = AppTheme.success;
        break;
      case 'Partially Paid':
        color = AppTheme.teal;
        break;
      case 'Pending':
        color = AppTheme.warning;
        break;
      case 'Failed':
        color = AppTheme.error;
        break;
      default:
        color = AppTheme.textSecondary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        status.toUpperCase(),
        style: GoogleFonts.outfit(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildFulfillmentBadge(String status) {
    Color color;
    IconData icon;
    switch (status) {
      case 'Delivered':
        color = AppTheme.success;
        icon = Icons.check_circle_outline_rounded;
        break;
      case 'Shipped':
        color = AppTheme.info;
        icon = Icons.local_shipping_outlined;
        break;
      case 'Out for Delivery':
        color = AppTheme.teal;
        icon = Icons.directions_run_outlined;
        break;
      case 'Processing':
        color = Colors.indigo;
        icon = Icons.sync_rounded;
        break;
      case 'Pending':
        color = AppTheme.warning;
        icon = Icons.hourglass_empty_rounded;
        break;
      case 'Cancelled':
        color = AppTheme.error;
        icon = Icons.cancel_outlined;
        break;
      case 'RTO':
        color = Colors.brown;
        icon = Icons.assignment_return_outlined;
        break;
      default:
        color = AppTheme.textSecondary;
        icon = Icons.help_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(
            status.toUpperCase(),
            style: GoogleFonts.outfit(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  // --- RENDER MAIN LAYOUT ---
  @override
  Widget build(BuildContext context) {
    if (_orderRaw == null) {
      return const Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.primaryColor),
        ),
      );
    }

    final bool isMobile = Responsive.isMobile(context);
    final double gapHeight = isMobile ? 12.0 : 16.0;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Premium Header Appbar
            _buildAppBar(),
            const Divider(height: 1, color: AppTheme.lightBorderColor),

            // Scrollable Layout
            Expanded(
              child: SingleChildScrollView(
                padding: AppTheme.getResponsivePadding(
                  context,
                ).copyWith(top: gapHeight, bottom: gapHeight),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    _buildOrderHeroCard(),
                    SizedBox(height: gapHeight),
                    _buildCustomerAndShippingCard(),
                    SizedBox(height: gapHeight),
                    _buildItemsOrderedCard(),
                    SizedBox(height: gapHeight),
                    _buildFinancialSummaryCard(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              // Premium styled circular back button
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.lightBorderColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppTheme.borderColor.withOpacity(0.5),
                      ),
                    ),
                    child: const Icon(
                      Icons.arrow_back_rounded,
                      color: AppTheme.textPrimary,
                      size: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        _order.orderId,
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(width: 10),
                      _buildPaymentBadge(_order.paymentStatus),
                      const SizedBox(width: 6),
                      _buildFulfillmentBadge(_order.orderStatus),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Placed on ${_formatDateTime(_order.placedAt)}',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- HERO OVERVIEW BLOCK ---
  Widget _buildOrderHeroCard() {
    final totalQty = _order.items.fold(0, (sum, i) => sum + i.quantity);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withOpacity(0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TOTAL SALE VALUE',
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.white70,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₹${_order.totalAmount.toStringAsFixed(2)}',
                    style: GoogleFonts.outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.shopping_bag_outlined,
                      color: Colors.white,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$totalQty Units',
                      style: GoogleFonts.outfit(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: Colors.white24, height: 1),
          ),
          Row(
            children: [
              _buildHeroMetaInfo(
                title: 'PAYMENT METHOD',
                value: _order.paymentMethod.toUpperCase(),
                icon: Icons.payments_outlined,
              ),
              const SizedBox(width: 24),
              _buildHeroMetaInfo(
                title: 'CHANNEL',
                value: 'ADMIN',
                icon: Icons.hub_outlined,
              ),
              if (_order.razorpayPaymentId != null &&
                  _order.razorpayPaymentId!.isNotEmpty) ...[
                const SizedBox(width: 24),
                _buildHeroMetaInfo(
                  title: 'PAYMENT ID',
                  value: _order.razorpayPaymentId!,
                  icon: Icons.receipt_long_rounded,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroMetaInfo({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 14),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: Colors.white70,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 2),
            Theme(
              data: Theme.of(context).copyWith(
                textSelectionTheme: TextSelectionThemeData(
                  selectionColor: Colors.white.withOpacity(0.3),
                  selectionHandleColor: Colors.white,
                ),
              ),
              child: SelectableText(
                value,
                style: GoogleFonts.outfit(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // --- ITEMS SUMMARY CARD ---
  Widget _buildItemsOrderedCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Items Summary',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${_order.items.length} Products',
                  style: GoogleFonts.outfit(
                    color: AppTheme.primaryColor,
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Items Table Structure
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.borderColor),
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                // Table Header
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  color: AppTheme.lightBorderColor,
                  child: Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: Text(
                          'PRODUCT NAME',
                          style: AppTheme.tableHeader,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text('PACKING', style: AppTheme.tableHeader),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          'QUANTITY',
                          style: AppTheme.tableHeader,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          'AMOUNT',
                          style: AppTheme.tableHeader,
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                ),
                // Table Rows
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _order.items.length,
                  separatorBuilder: (_, __) => const Divider(
                    color: AppTheme.lightBorderColor,
                    height: 1,
                  ),
                  itemBuilder: (context, idx) {
                    final item = _order.items[idx];
                    final parsed = _parseProductTitle(item.title);
                    final productName = parsed['name'] ?? item.title;
                    final packing =
                        (item.variantSize != null &&
                            item.variantSize!.isNotEmpty)
                        ? item.variantSize!
                        : (parsed['packing'] ?? 'Standard');

                    return _ItemTableRow(
                      productName: productName,
                      technicalName: item.technicalName,
                      packing: packing,
                      quantity: item.quantity,
                      amount: item.price * item.quantity,
                    );
                  },
                ),
              ],
            ),
          ),

          // Free promo items
          if (_order.freeItems.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Divider(color: AppTheme.borderColor, height: 1),
            ),
            Row(
              children: [
                const Icon(
                  Icons.card_giftcard_rounded,
                  color: AppTheme.accentColor,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  'Complimentary Gifts Offered',
                  style: GoogleFonts.outfit(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ..._order.freeItems.map(
              (gift) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.accentColor.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppTheme.accentColor.withOpacity(0.15),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: const BoxDecoration(
                        color: AppTheme.accentColor,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 10,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            gift.name,
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'PROMOTIONAL FREE ITEM',
                            style: GoogleFonts.outfit(
                              fontSize: 8.5,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.accentColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'QTY: ${gift.quantity}',
                      style: GoogleFonts.outfit(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.accentColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- INTEGRATED CUSTOMER & SHIPPING CARD ---
  Widget _buildCustomerAndShippingCard() {
    final bool isMobile = Responsive.isMobile(context);
    final hasAwb = _order.awbNumber != null && _order.awbNumber!.isNotEmpty;
    final hasCourier =
        _order.courierName != null && _order.courierName!.isNotEmpty;

    // customer content
    final Widget customerContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Customer & Representative',
          style: GoogleFonts.outfit(
            fontSize: 13.5,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
              child: Text(
                _getCustomerInitials(_order.customerName),
                style: GoogleFonts.outfit(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _order.customerName,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  if (_order.shopName != null &&
                      _order.shopName!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      _order.shopName!,
                      style: GoogleFonts.outfit(
                        fontSize: 11.5,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Divider(color: AppTheme.lightBorderColor, height: 1),
        ),
        _buildMetaRowWithIcon(
          icon: Icons.phone_iphone_rounded,
          label: 'MOBILE NUMBER',
          value: _order.customerPhone,
          action: IconButton(
            icon: const Icon(
              Icons.copy_rounded,
              size: 12,
              color: AppTheme.textSecondary,
            ),
            onPressed: () =>
                _copyToClipboard(_order.customerPhone, 'Phone number'),
            splashRadius: 14,
            constraints: const BoxConstraints(),
            padding: EdgeInsets.zero,
          ),
        ),
        const SizedBox(height: 10),
        _buildMetaRowWithIcon(
          icon: Icons.support_agent_rounded,
          label: 'SALES AGENT',
          value: 'Admin',
        ),
      ],
    );

    // shipping content
    final Widget shippingContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Shipping & Logistics',
          style: GoogleFonts.outfit(
            fontSize: 13.5,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: AppTheme.lightBorderColor,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.location_on_outlined,
                color: AppTheme.textSecondary,
                size: 16,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SHIPPING ADDRESS',
                    style: GoogleFonts.outfit(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _order.shippingAddress.villageArea,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: AppTheme.textBody,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    _order.shippingAddress.state != null &&
                            _order.shippingAddress.state!.isNotEmpty
                        ? '${_order.shippingAddress.cityTehsil}, ${_order.shippingAddress.state}'
                        : _order.shippingAddress.cityTehsil,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: AppTheme.textBody,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'PIN Code: ${_order.shippingAddress.pincode}',
                    style: GoogleFonts.outfit(
                      fontSize: 11.5,
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Divider(color: AppTheme.lightBorderColor, height: 1),
        ),
        if (hasAwb || hasCourier) ...[
          _buildMetaRowWithIcon(
            icon: Icons.local_shipping_outlined,
            label: 'COURIER PARTNER',
            value: hasCourier ? _order.courierName! : 'Standard Shipping',
          ),
          const SizedBox(height: 10),
          _buildMetaRowWithIcon(
            icon: Icons.tag_rounded,
            label: 'AWB / TRACKING NUMBER',
            value: hasAwb ? _order.awbNumber! : 'Pending Assignment',
            action: hasAwb
                ? IconButton(
                    icon: const Icon(
                      Icons.copy_rounded,
                      size: 12,
                      color: AppTheme.textSecondary,
                    ),
                    onPressed: () =>
                        _copyToClipboard(_order.awbNumber!, 'Tracking ID'),
                    splashRadius: 14,
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  )
                : null,
          ),
          if (_order.trackingUrl != null && _order.trackingUrl!.isNotEmpty) ...[
            const SizedBox(height: 12),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => _launchUrl(_order.trackingUrl!),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppTheme.primaryColor.withOpacity(0.2),
                    ),
                  ),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.explore_outlined,
                          color: AppTheme.primaryColor,
                          size: 13,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Track Order Package',
                          style: GoogleFonts.outfit(
                            fontSize: 11.5,
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ] else ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.lightBorderColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.pending_actions_rounded,
                  color: AppTheme.textSecondary,
                  size: 14,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Logistics partner & AWB number pending assignment.',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: AppTheme.cardShadow,
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                customerContent,
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(color: AppTheme.borderColor, height: 1),
                ),
                shippingContent,
              ],
            )
          : IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: customerContent),
                  const SizedBox(width: 24),
                  const VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: AppTheme.lightBorderColor,
                  ),
                  const SizedBox(width: 24),
                  Expanded(child: shippingContent),
                ],
              ),
            ),
    );
  }

  // --- FINANCIAL BREAKDOWN CARD ---
  Widget _buildFinancialSummaryCard() {
    final double subtotal = _order.items.fold(
      0.0,
      (sum, i) => sum + (i.price * i.quantity),
    );
    final hasPartial = _order.paymentMethod == 'Partial';
    final progressVal = _order.totalAmount > 0
        ? (_order.advanceAmount / _order.totalAmount)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payment Summary',
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),

          _buildSummaryRow(
            'Subtotal Cost',
            '₹${subtotal.toStringAsFixed(2)}',
            fontSize: 12,
          ),
          if (_order.discountAmount > 0) ...[
            const SizedBox(height: 6),
            _buildSummaryRow(
              'Campaign Coupon (${_order.couponCode ?? "APPLIED"})',
              '-₹${_order.discountAmount.toStringAsFixed(2)}',
              fontSize: 12,
              valueColor: AppTheme.error,
            ),
          ],
          const SizedBox(height: 6),
          _buildSummaryRow(
            'Fulfillment Delivery Fee',
            'FREE',
            fontSize: 12,
            valueColor: AppTheme.success,
          ),
          const Divider(height: 16, color: AppTheme.lightBorderColor),

          // Total Net Receivable Block
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.backgroundColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
            ),
            child: _buildSummaryRow(
              'Total Net Receivable',
              '₹${_order.totalAmount.toStringAsFixed(2)}',
              isBold: true,
              fontSize: 13.5,
              valueColor: AppTheme.primaryColor,
            ),
          ),

          // Advanced Partial Payment Visualizer
          if (hasPartial) ...[
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'PARTIAL PAYMENT SPLIT',
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  '${(progressVal * 100).toStringAsFixed(0)}% Received',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.success,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progressVal,
                minHeight: 6,
                backgroundColor: AppTheme.lightBorderColor,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppTheme.success,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ADVANCE PAID',
                      style: GoogleFonts.outfit(
                        fontSize: 9.5,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₹${_order.advanceAmount.toStringAsFixed(2)}',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: AppTheme.success,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'DUE BALANCE (COD)',
                      style: GoogleFonts.outfit(
                        fontSize: 9.5,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₹${_order.remainingAmount.toStringAsFixed(2)}',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: AppTheme.warning,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    bool isBold = false,
    double fontSize = 12.5,
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: fontSize,
            color: isBold ? AppTheme.textPrimary : AppTheme.textSecondary,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: fontSize,
            color: valueColor ?? AppTheme.textPrimary,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w700,
          ),
        ),
      ],
    );
  }

  // --- REUSABLE CARD META ROW ---
  Widget _buildMetaRowWithIcon({
    required IconData icon,
    required String label,
    required String value,
    Widget? action,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppTheme.lightBorderColor,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppTheme.textSecondary, size: 14),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      value,
                      style: GoogleFonts.outfit(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (action != null) ...[const SizedBox(width: 6), action],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// --- ITEM TABLE ROW WITH HOVER EFFECT ---
class _ItemTableRow extends StatefulWidget {
  final String productName;
  final String? technicalName;
  final String packing;
  final int quantity;
  final double amount;

  const _ItemTableRow({
    required this.productName,
    this.technicalName,
    required this.packing,
    required this.quantity,
    required this.amount,
  });

  @override
  State<_ItemTableRow> createState() => _ItemTableRowState();
}

class _ItemTableRowState extends State<_ItemTableRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        color: _isHovered
            ? AppTheme.primaryColor.withOpacity(0.03)
            : Colors.transparent,
        child: Row(
          children: [
            // Product Name & Technical Name
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.productName,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (widget.technicalName != null &&
                      widget.technicalName!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      widget.technicalName!,
                      style: GoogleFonts.outfit(
                        fontSize: 10.5,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Packing
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.lightBorderColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    widget.packing,
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textBody,
                    ),
                  ),
                ),
              ),
            ),
            // Quantity
            Expanded(
              flex: 2,
              child: Text(
                'x${widget.quantity}',
                style: GoogleFonts.outfit(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            // Amount
            Expanded(
              flex: 2,
              child: Text(
                '₹${widget.amount.toStringAsFixed(2)}',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
