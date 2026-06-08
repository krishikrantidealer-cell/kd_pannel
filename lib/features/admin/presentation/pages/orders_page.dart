import 'dart:ui' as ui;
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kd_pannel/app_theme.dart';
import 'package:kd_pannel/core/responsive/responsive.dart';
import 'package:kd_pannel/features/shared/widgets/advanced_stat_card_widget.dart';
import 'package:kd_pannel/core/network/api_client.dart';

// --- MODELS ALIGNED WITH BACKEND SCHEMA (Order.js) ---

class OrderItem {
  final String productId;
  final String variantId;
  final String title;
  final String? vendor;
  final String? technicalName;
  final String? image;
  final int quantity;
  final double price;
  final String? variantSize;

  OrderItem({
    required this.productId,
    required this.variantId,
    required this.title,
    this.vendor,
    this.technicalName,
    this.image,
    required this.quantity,
    required this.price,
    this.variantSize,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    final productMap = json['product'] as Map<String, dynamic>?;
    String? sizeVal;
    if (productMap != null && productMap['variants'] is List) {
      final variantsList = productMap['variants'] as List;
      final matchingVariant = variantsList.firstWhere(
        (v) => v is Map && v['_id']?.toString() == json['variantId']?.toString(),
        orElse: () => null,
      );
      if (matchingVariant != null && matchingVariant is Map) {
        sizeVal = matchingVariant['size']?.toString();
      }
    }

    return OrderItem(
      productId: json['product'] is Map ? (json['product']['_id'] ?? '') : (json['product'] ?? ''),
      variantId: json['variantId'] ?? '',
      title: json['title'] ?? '',
      vendor: json['vendor'],
      technicalName: json['technicalName'],
      image: json['image'],
      quantity: json['quantity'] ?? 0,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      variantSize: sizeVal,
    );
  }
}

class FreeItem {
  final String name;
  final String? imageUrl;
  final int quantity;
  final bool isFree;

  FreeItem({
    required this.name,
    this.imageUrl,
    required this.quantity,
    this.isFree = true,
  });

  factory FreeItem.fromJson(Map<String, dynamic> json) {
    return FreeItem(
      name: json['name'] ?? '',
      imageUrl: json['imageUrl'],
      quantity: json['quantity'] ?? 1,
      isFree: json['isFree'] ?? true,
    );
  }
}

class ShippingAddress {
  final String? name;
  final String? phoneNumber;
  final String villageArea;
  final String cityTehsil;
  final String? state;
  final String pincode;

  ShippingAddress({
    this.name,
    this.phoneNumber,
    required this.villageArea,
    required this.cityTehsil,
    this.state,
    required this.pincode,
  });

  factory ShippingAddress.fromJson(Map<String, dynamic> json) {
    return ShippingAddress(
      name: json['name'],
      phoneNumber: json['phoneNumber'],
      villageArea: json['villageArea'] ?? '',
      cityTehsil: json['cityTehsil'] ?? '',
      state: json['state'],
      pincode: json['pincode'] ?? '',
    );
  }
}

class OrderModel {
  final String id;
  final String orderId;
  final String customerName;
  final String? shopName;
  final String customerPhone;
  final String customerRole; // 'Dealer' or 'Lead'
  final List<OrderItem> items;
  final double totalAmount;
  final double discountAmount;
  final String? couponCode;
  final List<FreeItem> freeItems;
  final ShippingAddress shippingAddress;
  final String paymentMethod; // 'Online', 'Partial'
  String paymentStatus; // 'Pending', 'Paid', 'Failed', 'Partially Paid'
  final String? razorpayPaymentId;
  final double advanceAmount;
  final double remainingAmount;
  String orderStatus; // 'Processing', 'Shipped', 'Out for Delivery', 'Delivered', 'Cancelled', 'RTO'
  String? courierStatus;
  String? awbNumber;
  String? courierName;
  String? trackingUrl;
  final DateTime placedAt;
  DateTime? processingAt;
  DateTime? shippedAt;
  DateTime? outForDeliveryAt;
  DateTime? deliveredAt;
  DateTime? cancelledAt;
  DateTime? rtoAt;
  final String? assignedAgent;

  OrderModel({
    required this.id,
    required this.orderId,
    required this.customerName,
    this.shopName,
    required this.customerPhone,
    required this.customerRole,
    required this.items,
    required this.totalAmount,
    this.discountAmount = 0.0,
    this.couponCode,
    this.freeItems = const [],
    required this.shippingAddress,
    required this.paymentMethod,
    required this.paymentStatus,
    this.razorpayPaymentId,
    this.advanceAmount = 0.0,
    this.remainingAmount = 0.0,
    required this.orderStatus,
    this.courierStatus,
    this.awbNumber,
    this.courierName,
    this.trackingUrl,
    required this.placedAt,
    this.processingAt,
    this.shippedAt,
    this.outForDeliveryAt,
    this.deliveredAt,
    this.cancelledAt,
    this.rtoAt,
    this.assignedAgent,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    final userJson = json['user'] as Map<String, dynamic>?;
    String customerName = 'Unknown Customer';
    String? shopName;
    String customerPhone = '';
    String customerRole = 'Lead';
    if (userJson != null) {
      final firstName = userJson['firstName'] ?? '';
      final lastName = userJson['lastName'] ?? '';
      shopName = userJson['shopName']?.toString();
      final fullName = '$firstName $lastName'.trim();
      if (fullName.isNotEmpty) {
        customerName = fullName;
      } else if (shopName != null && shopName.isNotEmpty) {
        customerName = shopName;
      }
      customerPhone = userJson['phoneNumber'] ?? '';
      final isKycVerified = userJson['kycStatus'] == 'verified' || (userJson['isKycComplete'] == true);
      customerRole = isKycVerified ? 'Dealer' : 'Lead';
    }

    final itemsList = (json['items'] as List?)
            ?.map((i) => OrderItem.fromJson(i))
            .toList() ??
        [];
    final freeItemsList = (json['freeItems'] as List?)
            ?.map((f) => FreeItem.fromJson(f))
            .toList() ??
        [];

    final placedAtRaw = json['placedAt'] ?? json['createdAt'];

    return OrderModel(
      id: json['_id'] ?? '',
      orderId: json['orderId'] ?? '',
      customerName: customerName,
      shopName: shopName,
      customerPhone: customerPhone,
      customerRole: customerRole,
      items: itemsList,
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
      discountAmount: (json['discountAmount'] as num?)?.toDouble() ?? 0.0,
      couponCode: json['couponCode'],
      freeItems: freeItemsList,
      shippingAddress: ShippingAddress.fromJson(json['shippingAddress'] ?? {}),
      paymentMethod: json['paymentMethod'] ?? 'Online',
      paymentStatus: json['paymentStatus'] ?? 'Pending',
      razorpayPaymentId: json['razorpayPaymentId'],
      advanceAmount: (json['advanceAmount'] as num?)?.toDouble() ?? 0.0,
      remainingAmount: (json['remainingAmount'] as num?)?.toDouble() ?? 0.0,
      orderStatus: json['orderStatus'] ?? 'Processing',
      courierStatus: json['courierStatus'],
      awbNumber: json['awbNumber'],
      courierName: json['courierName'],
      trackingUrl: json['trackingUrl'],
      placedAt: placedAtRaw != null ? DateTime.parse(placedAtRaw) : DateTime.now(),
      processingAt: json['processingAt'] != null ? DateTime.parse(json['processingAt']) : null,
      shippedAt: json['shippedAt'] != null ? DateTime.parse(json['shippedAt']) : null,
      outForDeliveryAt: json['outForDeliveryAt'] != null ? DateTime.parse(json['outForDeliveryAt']) : null,
      deliveredAt: json['deliveredAt'] != null ? DateTime.parse(json['deliveredAt']) : null,
      cancelledAt: json['cancelledAt'] != null ? DateTime.parse(json['cancelledAt']) : null,
      rtoAt: json['rtoAt'] != null ? DateTime.parse(json['rtoAt']) : null,
      assignedAgent: json['assignedAgent'],
    );
  }
}

// --- ORDERS PAGE ---

class OrdersPage extends StatefulWidget {
  final bool isStandalone;
  const OrdersPage({super.key, this.isStandalone = false});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  final ScrollController _scrollController = ScrollController();
  final ScrollController _tableHorizontalController = ScrollController();
  String _searchQuery = '';
  String _selectedOrderStatus = 'All Statuses';
  String _selectedPaymentStatus = 'All Payments';
  String _selectedPaymentMethod = 'All Methods';

  String? _hoveredOrderId;

  bool _isLoading = true;
  String? _errorMessage;
  List<OrderModel> _orders = [];

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _fetchOrders({bool isSilent = false}) async {
    if (!mounted) return;
    if (!isSilent) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }
    try {
      final response = await ApiClient().get('/orders/admin/all');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final List rawOrders = data['orders'] ?? [];
          if (mounted) {
            setState(() {
              _orders = rawOrders.map((o) => OrderModel.fromJson(o)).toList();
              _isLoading = false;
            });
          }
          return;
        }
      }
      if (!isSilent && mounted) {
        setState(() {
          _errorMessage = 'Failed to load orders. Please check your credentials.';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!isSilent && mounted) {
        setState(() {
          _errorMessage = 'Connection error: $e';
          _isLoading = false;
        });
      }
    }
  }



  @override
  void dispose() {
    _scrollController.dispose();
    _tableHorizontalController.dispose();
    super.dispose();
  }

  // --- QUERY FILTERING MECHANICS ---
  List<OrderModel> get _filteredOrders {
    return _orders.where((order) {
      final query = _searchQuery.toLowerCase();
      final matchesSearch =
          order.orderId.toLowerCase().contains(query) ||
          order.customerName.toLowerCase().contains(query) ||
          order.customerPhone.contains(query) ||
          (order.awbNumber ?? '').toLowerCase().contains(query);

      final matchesOrderStatus =
          _selectedOrderStatus == 'All Statuses' ||
          order.orderStatus == _selectedOrderStatus;

      final matchesPaymentStatus =
          _selectedPaymentStatus == 'All Payments' ||
          order.paymentStatus == _selectedPaymentStatus;

      final matchesPaymentMethod =
          _selectedPaymentMethod == 'All Methods' ||
          order.paymentMethod == _selectedPaymentMethod;

      return matchesSearch &&
          matchesOrderStatus &&
          matchesPaymentStatus &&
          matchesPaymentMethod;
    }).toList();
  }

  // --- ANALYTICS CALCULATIONS ---
  double get _totalRevenue {
    return _orders
        .where(
          (o) =>
              o.paymentStatus == 'Paid' || o.paymentStatus == 'Partially Paid',
        )
        .fold(0.0, (sum, o) {
          // If paid online, we got the full amount. If partially paid, we received the advanceAmount so far.
          return sum +
              (o.paymentStatus == 'Paid' ? o.totalAmount : o.advanceAmount);
        });
  }

  int get _pendingFulfillments {
    return _orders
        .where(
          (o) => [
            'Processing',
            'Shipped',
            'Out for Delivery',
          ].contains(o.orderStatus),
        )
        .length;
  }

  int get _pendingPayments {
    return _orders
        .where(
          (o) =>
              o.paymentStatus == 'Pending' ||
              o.paymentStatus == 'Partially Paid',
        )
        .length;
  }

  // --- SIDEBAR TABS INTEGRATION HELPER ---

  // --- WIDGET BUILDER ---
  @override
  Widget build(BuildContext context) {
    final bool isMobile = Responsive.isMobile(context);
    final filtered = _filteredOrders;
    final EdgeInsets screenPadding = AppTheme.getResponsivePadding(context);

    final Widget body = _isLoading
        ? const SizedBox.expand(
            child: Center(
              child: CircularProgressIndicator(
                color: AppTheme.primaryColor,
              ),
            ),
          )
        : (_errorMessage != null
            ? SizedBox.expand(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: AppTheme.error,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: _fetchOrders,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'Retry Connection',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : SizedBox.expand(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.symmetric(vertical: screenPadding.top),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      if (!widget.isStandalone) ...[
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: screenPadding.left),
                          child: _buildHeader(),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Statistics Grid
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: screenPadding.left),
                        child: _buildStatsGrid(),
                      ),
                      const SizedBox(height: 24),

                      // Search & Filter controls
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: screenPadding.left),
                        child: _buildFilterControls(isMobile),
                      ),
                      const SizedBox(height: 16),

                      // Orders Table
                      _buildOrdersTable(filtered, isMobile, screenPadding),
                    ],
                  ),
                ),
              ));

    if (widget.isStandalone) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          title: Text(
            'Order Management',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          backgroundColor: Colors.white,
          foregroundColor: AppTheme.textPrimary,
          elevation: 0,
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1, color: AppTheme.lightBorderColor),
          ),
        ),
        body: body,
      );
    }

    return body;
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Order Management',
          style: GoogleFonts.outfit(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Track sales activity, fulfill packages, manage shipping partners, and issue order updates',
          style: GoogleFonts.outfit(
            fontSize: 13,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsGrid() {
    final bool isDesktop = Responsive.isDesktop(context);

    // Dynamic counts from all orders
    final int totalOrders = _orders.length;
    final int processingOrders = _orders
        .where((o) => o.orderStatus == 'Processing')
        .length;
    final int shippedOrders = _orders
        .where((o) => o.orderStatus == 'Shipped')
        .length;
    final int deliveredOrders = _orders
        .where((o) => o.orderStatus == 'Delivered')
        .length;

    // Today's orders
    final now = DateTime.now();
    final placedToday = _orders
        .where(
          (o) =>
              o.placedAt.year == now.year &&
              o.placedAt.month == now.month &&
              o.placedAt.day == now.day,
        )
        .length;


    // Shipped / Out for delivery in transit
    final outForDeliveryOrders = _orders
        .where((o) => o.orderStatus == 'Out for Delivery')
        .length;
    final totalInTransit = shippedOrders + outForDeliveryOrders;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double spacing = isDesktop ? 16.0 : 12.0;
        int columns = 4;
        if (constraints.maxWidth < 600) {
          columns = 1;
        } else if (constraints.maxWidth < 950) {
          columns = 2;
        } else {
          columns = 4;
        }
        final double width =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            // 1. Total Orders Card
            AdvancedStatCardWidget(
              width: width,
              title: 'Total Orders',
              value: '$totalOrders',
              color: AppTheme.primaryColor,
              trendLabel: '+$placedToday placed today',
              trendIcon: Icons.trending_up,
              onTap: () {
                setState(() {
                  _selectedOrderStatus = 'All Statuses';
                });
              },
              visualWidget: SizedBox(
                width: 50,
                height: 24,
                child: CustomPaint(
                  painter: SparklinePainter([
                    3,
                    5,
                    2,
                    8,
                    4,
                    7,
                    totalOrders.toDouble(),
                  ], AppTheme.primaryColor),
                ),
              ),
            ),

            // 2. Total Processing Card
            AdvancedStatCardWidget(
              width: width,
              title: 'Total Processing',
              value: '$processingOrders',
              color: AppTheme.warning,
              trendLabel: '$processingOrders awaiting dispatch',
              trendIcon: Icons.hourglass_empty_rounded,
              onTap: () {
                setState(() {
                  _selectedOrderStatus = 'Processing';
                });
              },
              visualWidget: SizedBox(
                width: 28,
                height: 28,
                child: CustomPaint(
                  painter: FulfillmentProgressPainter(
                    totalOrders > 0
                        ? processingOrders / totalOrders
                        : 0.0,
                    AppTheme.warning,
                  ),
                ),
              ),
            ),

            // 3. Order Shipped Card
            AdvancedStatCardWidget(
              width: width,
              title: 'Order Shipped',
              value: '$shippedOrders',
              color: AppTheme.info,
              trendLabel: '$outForDeliveryOrders out for delivery',
              trendIcon: Icons.local_shipping_outlined,
              onTap: () {
                setState(() {
                  _selectedOrderStatus = 'Shipped';
                });
              },
              visualWidget: SizedBox(
                width: 50,
                height: 24,
                child: CustomPaint(
                  painter: SparklinePainter([
                    2,
                    4,
                    3,
                    6,
                    5,
                    7,
                    totalInTransit.toDouble(),
                  ], AppTheme.info),
                ),
              ),
            ),

            // 4. Orders Delivered Card
            AdvancedStatCardWidget(
              width: width,
              title: 'Orders Delivered',
              value: '$deliveredOrders',
              color: AppTheme.success,
              trendLabel: 'Successful deliveries',
              trendIcon: Icons.check_circle_outline,
              onTap: () {
                setState(() {
                  _selectedOrderStatus = 'Delivered';
                });
              },
              visualWidget: SizedBox(
                width: 28,
                height: 28,
                child: CustomPaint(
                  painter: FulfillmentProgressPainter(
                    totalOrders > 0 ? deliveredOrders / totalOrders : 0.0,
                    AppTheme.success,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFilterControls(bool isMobile) {
    final Widget searchField = Container(
      height: 38,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: TextField(
        onChanged: (val) => setState(() => _searchQuery = val),
        textAlignVertical: TextAlignVertical.center,
        style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
        decoration: const InputDecoration(
          hintText: 'Search order ID, client name, phone...',
          hintStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          prefixIcon: Icon(
            Icons.search,
            size: 18,
            color: AppTheme.textSecondary,
          ),
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );

    final orderStatusOptions = [
      'All Statuses',
      'Processing',
      'Shipped',
      'Out for Delivery',
      'Delivered',
      'Cancelled',
      'RTO',
    ];
    final paymentStatusOptions = [
      'All Payments',
      'Pending',
      'Paid',
      'Failed',
      'Partially Paid',
    ];
    final paymentMethodOptions = ['All Methods', 'Online', 'Partial'];

    if (isMobile) {
      return Column(
        children: [
          searchField,
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildDropdown(
                  orderStatusOptions,
                  _selectedOrderStatus,
                  (val) => setState(() => _selectedOrderStatus = val!),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildDropdown(
                  paymentStatusOptions,
                  _selectedPaymentStatus,
                  (val) => setState(() => _selectedPaymentStatus = val!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildDropdown(
            paymentMethodOptions,
            _selectedPaymentMethod,
            (val) => setState(() => _selectedPaymentMethod = val!),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: searchField),
        const SizedBox(width: 12),
        _buildDropdown(
          orderStatusOptions,
          _selectedOrderStatus,
          (val) => setState(() => _selectedOrderStatus = val!),
          width: 150,
        ),
        const SizedBox(width: 12),
        _buildDropdown(
          paymentStatusOptions,
          _selectedPaymentStatus,
          (val) => setState(() => _selectedPaymentStatus = val!),
          width: 150,
        ),
        const SizedBox(width: 12),
        _buildDropdown(
          paymentMethodOptions,
          _selectedPaymentMethod,
          (val) => setState(() => _selectedPaymentMethod = val!),
          width: 130,
        ),
      ],
    );
  }

  Widget _buildDropdown(
    List<String> options,
    String currentValue,
    ValueChanged<String?> onChanged, {
    double? width,
  }) {
    return Container(
      height: 38,
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: currentValue,
          onChanged: onChanged,
          icon: const Icon(
            Icons.keyboard_arrow_down,
            size: 16,
            color: AppTheme.textSecondary,
          ),
          items: options
              .map<DropdownMenuItem<String>>(
                (val) => DropdownMenuItem<String>(
                  value: val,
                  child: Text(
                    val,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textBody,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _buildOrdersTable(
    List<OrderModel> orders,
    bool isMobile,
    EdgeInsets screenPadding,
  ) {
    final header = Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      color: const Color(0xFFF9FAFB),
      child: Row(
        children: const [
          Expanded(flex: 6, child: _TableHeaderText('ORDER ID')),
          Expanded(flex: 6, child: _TableHeaderText('DATE & TIME')),
          Expanded(flex: 12, child: _TableHeaderText('CUSTOMER')),
          Expanded(flex: 6, child: _TableHeaderText('AGENT')),
          Expanded(flex: 6, child: _TableHeaderText('ORDER VALUE')),
          Expanded(flex: 8, child: _TableHeaderText('PAYMENT STATUS')),
          Expanded(flex: 10, child: _TableHeaderText('FULFILLMENT')),
          Expanded(flex: 3, child: _TableHeaderText('ITEMS')),
        ],
      ),
    );

    Widget tableBody;
    if (orders.isEmpty) {
      tableBody = Container(
        padding: const EdgeInsets.all(30),
        child: Center(
          child: Text(
            'No orders match your filters',
            style: GoogleFonts.outfit(
              color: AppTheme.textSecondary,
              fontSize: 12,
            ),
          ),
        ),
      );
    } else {
      tableBody = Column(
        children: orders.asMap().entries.map((entry) {
          final isEven = entry.key % 2 == 0;
          final order = entry.value;

          return MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => _hoveredOrderId = order.id),
            onExit: (_) {
              if (_hoveredOrderId == order.id) {
                setState(() => _hoveredOrderId = null);
              }
            },
            child: GestureDetector(
              onTap: () {
                Navigator.pushNamed(
                  context,
                  '/orders/details',
                  arguments: order,
                ).then((_) {
                  _fetchOrders(isSilent: true);
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _hoveredOrderId == order.id
                      ? AppTheme.primaryColor.withOpacity(0.04)
                      : (isEven ? Colors.white : const Color(0xFFF9FAFB)),
                  border: Border(
                    bottom: BorderSide(color: AppTheme.lightBorderColor),
                    left: BorderSide(
                      color: _hoveredOrderId == order.id
                          ? AppTheme.primaryColor.withOpacity(0.5)
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    // ORDER ID
                    Expanded(
                      flex: 6,
                      child: Text(
                        order.orderId,
                        style: GoogleFonts.outfit(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),

                    // DATE
                    Expanded(
                      flex: 6,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _formatDate(order.placedAt),
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: AppTheme.textBody,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            _formatTime(order.placedAt),
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // CUSTOMER
                    Expanded(
                      flex: 12,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  order.customerName,
                                  style: GoogleFonts.outfit(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 1),
                          Text(
                            order.customerPhone,
                            style: GoogleFonts.outfit(
                              fontSize: 10.5,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ASSIGNED AGENT
                    Expanded(
                      flex: 6,
                      child: Text(
                        'Admin',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: AppTheme.textBody,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                    // ORDER VALUE (TOTAL AMOUNT)
                    Expanded(
                      flex: 6,
                      child: Text(
                        '₹${order.totalAmount.toStringAsFixed(2)}',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),

                    // PAYMENT
                    Expanded(
                      flex: 8,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: _buildPaymentBadge(order.paymentStatus),
                      ),
                    ),

                    // FULFILLMENT
                    Expanded(
                      flex: 10,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: _buildFulfillmentBadge(order.orderStatus),
                      ),
                    ),

                    // ITEMS COUNT
                    Expanded(
                      flex: 3,
                      child: Text(
                        '${order.items.fold(0, (sum, i) => sum + i.quantity)} unit(s)',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: AppTheme.textBody,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      );
    }

    final tableWidget = Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          header,
          const Divider(height: 1, color: AppTheme.lightBorderColor),
          tableBody,
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final double availableWidth = constraints.maxWidth;
        final double horizontalPadding =
            screenPadding.left + screenPadding.right;
        final double tableAvailableWidth = availableWidth - horizontalPadding;
        // Keep enough width so right-most columns never get clipped on smaller laptops.
        final double minTableWidth = isMobile ? 900 : 960;
        final bool needsHorizontalScroll = tableAvailableWidth < minTableWidth;
        final double tableWidth = needsHorizontalScroll
            ? minTableWidth
            : tableAvailableWidth;

        return Scrollbar(
          controller: _tableHorizontalController,
          thumbVisibility: needsHorizontalScroll,
          trackVisibility: needsHorizontalScroll,
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(
              dragDevices: {
                ui.PointerDeviceKind.touch,
                ui.PointerDeviceKind.mouse,
                ui.PointerDeviceKind.trackpad,
              },
            ),
            child: SingleChildScrollView(
              controller: _tableHorizontalController,
              scrollDirection: Axis.horizontal,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: screenPadding.left),
                child: SizedBox(width: tableWidth, child: tableWidget),
              ),
            ),
          ),
        );
      },
    );
  }

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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        status,
        style: GoogleFonts.outfit(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 11),
          const SizedBox(width: 4),
          Text(
            status,
            style: GoogleFonts.outfit(
              color: color,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
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
}

// --- SUB-WIDGET FOR TABLE HEADER ---
class _TableHeaderText extends StatelessWidget {
  final String text;
  const _TableHeaderText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: AppTheme.tableHeader);
  }
}
