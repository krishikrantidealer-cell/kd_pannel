import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kd_pannel/app_theme.dart';
import 'package:kd_pannel/core/responsive/responsive.dart';
import 'package:kd_pannel/features/shared/widgets/advanced_stat_card_widget.dart';

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

  OrderItem({
    required this.productId,
    required this.variantId,
    required this.title,
    this.vendor,
    this.technicalName,
    this.image,
    required this.quantity,
    required this.price,
  });
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
}

class ShippingAddress {
  final String villageArea;
  final String cityTehsil;
  final String pincode;

  ShippingAddress({
    required this.villageArea,
    required this.cityTehsil,
    required this.pincode,
  });
}

class OrderModel {
  final String id;
  final String orderId;
  final String customerName;
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
  String
  orderStatus; // 'Pending', 'Processing', 'Shipped', 'Out for Delivery', 'Delivered', 'Cancelled', 'RTO'
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

  // --- MOCK DATABASE (Aligend with Node.js seeds & schemas) ---
  late List<OrderModel> _orders;

  @override
  void initState() {
    super.initState();
    _initMockData();
  }

  void _initMockData() {
    final now = DateTime.now();
    _orders = [
      OrderModel(
        id: '652f10b7e4b0c28345678901',
        orderId: 'ORD-901456',
        customerName: 'Vijay Singh',
        customerPhone: '98765 43210',
        customerRole: 'Dealer',
        items: [
          OrderItem(
            productId: 'p1',
            variantId: 'v1',
            title: 'Drip Irrigation Kit (50m)',
            vendor: 'Jain Irrigation',
            technicalName: 'Drip Piping 16mm',
            image: null,
            quantity: 2,
            price: 2400.0,
          ),
          OrderItem(
            productId: 'p2',
            variantId: 'v3',
            title: 'Hybrid Seed Pack (250g)',
            vendor: 'Mahyco',
            technicalName: 'Bt Cotton Hybrid',
            image: null,
            quantity: 3,
            price: 1200.0,
          ),
        ],
        totalAmount: 7900.0, // (2*2400) + (3*1200) = 8400 - 500 discount
        discountAmount: 500.0,
        couponCode: 'KRAK500',
        freeItems: [
          FreeItem(
            name: 'Organic Fertilizer Blend 1kg',
            imageUrl: null,
            quantity: 1,
          ),
        ],
        shippingAddress: ShippingAddress(
          villageArea: 'Near Water Tank, Ward No. 4',
          cityTehsil: 'Chomu, Jaipur',
          pincode: '303702',
        ),
        paymentMethod: 'Partial',
        paymentStatus: 'Partially Paid',
        advanceAmount: 2000.0,
        remainingAmount: 5900.0,
        orderStatus: 'Processing',
        placedAt: now.subtract(const Duration(hours: 2)),
        processingAt: now.subtract(const Duration(hours: 1)),
        assignedAgent: 'Amit',
      ),
      OrderModel(
        id: '652f10b7e4b0c28345678902',
        orderId: 'ORD-891230',
        customerName: 'Mahipal Agro Agency',
        customerPhone: '99223 34455',
        customerRole: 'Dealer',
        items: [
          OrderItem(
            productId: 'p3',
            variantId: 'v4',
            title: 'Water Pump 5HP',
            vendor: 'Kirloskar',
            technicalName: 'Submersible Monoblock',
            image: null,
            quantity: 1,
            price: 11500.0,
          ),
        ],
        totalAmount: 11500.0,
        shippingAddress: ShippingAddress(
          villageArea: 'Krishi Mandi, Shop No. 12',
          cityTehsil: 'Merta City, Nagaur',
          pincode: '341510',
        ),
        paymentMethod: 'Online',
        paymentStatus: 'Paid',
        razorpayPaymentId: 'pay_Nsh928sJskw182',
        orderStatus: 'Delivered',
        placedAt: now.subtract(const Duration(days: 2)),
        processingAt: now.subtract(const Duration(days: 2, hours: 22)),
        shippedAt: now.subtract(const Duration(days: 1, hours: 18)),
        outForDeliveryAt: now.subtract(const Duration(days: 1, hours: 4)),
        deliveredAt: now.subtract(const Duration(hours: 20)),
        courierName: 'Delhivery',
        awbNumber: '456711289',
        trackingUrl:
            'https://track.delhivery.com/api/v1/packages/json/?waybill=456711289',
        courierStatus: 'Delivered successfully to consignee',
        assignedAgent: 'Anita',
      ),
      OrderModel(
        id: '652f10b7e4b0c28345678903',
        orderId: 'ORD-881224',
        customerName: 'Ramesh Kumar',
        customerPhone: '94140 12345',
        customerRole: 'Lead',
        items: [
          OrderItem(
            productId: 'p4',
            variantId: 'v5',
            title: 'Fertilizer Blend X (10kg)',
            vendor: 'IFFCO',
            technicalName: 'NPK 19:19:19',
            image: null,
            quantity: 5,
            price: 980.0,
          ),
        ],
        totalAmount: 4900.0,
        shippingAddress: ShippingAddress(
          villageArea: 'Main Market Road',
          cityTehsil: 'Bhinmal, Jalore',
          pincode: '343030',
        ),
        paymentMethod: 'Online',
        paymentStatus: 'Paid',
        razorpayPaymentId: 'pay_Nsh934hTshq891',
        orderStatus: 'Shipped',
        placedAt: now.subtract(const Duration(days: 3)),
        processingAt: now.subtract(const Duration(days: 2, hours: 20)),
        shippedAt: now.subtract(const Duration(days: 1, hours: 10)),
        courierName: 'Delhivery',
        awbNumber: '456711390',
        trackingUrl:
            'https://track.delhivery.com/api/v1/packages/json/?waybill=456711390',
        courierStatus: 'In Transit: Arrived at Jaipur Hub',
        assignedAgent: 'Rajesh',
      ),
      OrderModel(
        id: '652f10b7e4b0c28345678904',
        orderId: 'ORD-871109',
        customerName: 'Rajesh Seeds Store',
        customerPhone: '88990 01122',
        customerRole: 'Dealer',
        items: [
          OrderItem(
            productId: 'p2',
            variantId: 'v2',
            title: 'Hybrid Seed Pack (100g)',
            vendor: 'Mahyco',
            technicalName: 'Bt Cotton Hybrid',
            image: null,
            quantity: 10,
            price: 650.0,
          ),
        ],
        totalAmount: 6500.0,
        shippingAddress: ShippingAddress(
          villageArea: 'Opposite Government School',
          cityTehsil: 'Kotputli, Jaipur',
          pincode: '303108',
        ),
        paymentMethod: 'Partial',
        paymentStatus: 'Partially Paid',
        advanceAmount: 1500.0,
        remainingAmount: 5000.0,
        orderStatus: 'Out for Delivery',
        placedAt: now.subtract(const Duration(days: 4)),
        processingAt: now.subtract(const Duration(days: 3, hours: 21)),
        shippedAt: now.subtract(const Duration(days: 2, hours: 12)),
        outForDeliveryAt: now.subtract(const Duration(hours: 3)),
        courierName: 'Shiprocket',
        awbNumber: 'SR9982190',
        trackingUrl: 'https://shiprocket.co/track/SR9982190',
        courierStatus: 'Out for delivery with courier agent',
        assignedAgent: 'Sahil',
      ),
      OrderModel(
        id: '652f10b7e4b0c28345678905',
        orderId: 'ORD-861002',
        customerName: 'Jai Kisan Fertilizers',
        customerPhone: '96778 89900',
        customerRole: 'Dealer',
        items: [
          OrderItem(
            productId: 'p1',
            variantId: 'v1',
            title: 'Drip Irrigation Kit (50m)',
            vendor: 'Jain Irrigation',
            technicalName: 'Drip Piping 16mm',
            image: null,
            quantity: 1,
            price: 2400.0,
          ),
          OrderItem(
            productId: 'p4',
            variantId: 'v6',
            title: 'Fertilizer Blend X (20kg)',
            vendor: 'IFFCO',
            technicalName: 'NPK 19:19:19',
            image: null,
            quantity: 2,
            price: 1800.0,
          ),
        ],
        totalAmount: 6000.0,
        shippingAddress: ShippingAddress(
          villageArea: 'Agro Industrial Area',
          cityTehsil: 'Hanumangarh',
          pincode: '335513',
        ),
        paymentMethod: 'Online',
        paymentStatus: 'Pending',
        orderStatus: 'Pending',
        placedAt: now.subtract(const Duration(hours: 12)),
        assignedAgent: 'Amit',
      ),
      OrderModel(
        id: '652f10b7e4b0c28345678906',
        orderId: 'ORD-850987',
        customerName: 'Sompal Patel',
        customerPhone: '98290 55667',
        customerRole: 'Lead',
        items: [
          OrderItem(
            productId: 'p2',
            variantId: 'v2',
            title: 'Hybrid Seed Pack (100g)',
            vendor: 'Mahyco',
            technicalName: 'Bt Cotton Hybrid',
            image: null,
            quantity: 1,
            price: 650.0,
          ),
        ],
        totalAmount: 650.0,
        shippingAddress: ShippingAddress(
          villageArea: 'Kalyanpura Village',
          cityTehsil: 'Sanganer, Jaipur',
          pincode: '302029',
        ),
        paymentMethod: 'Online',
        paymentStatus: 'Failed',
        orderStatus: 'Cancelled',
        placedAt: now.subtract(const Duration(days: 5)),
        cancelledAt: now.subtract(const Duration(days: 5, hours: 23)),
        assignedAgent: null,
      ),
      OrderModel(
        id: '652f10b7e4b0c28345678907',
        orderId: 'ORD-840976',
        customerName: 'Harish Agro Tech',
        customerPhone: '98877 66554',
        customerRole: 'Dealer',
        items: [
          OrderItem(
            productId: 'p3',
            variantId: 'v4',
            title: 'Water Pump 5HP',
            vendor: 'Kirloskar',
            technicalName: 'Submersible Monoblock',
            image: null,
            quantity: 1,
            price: 11500.0,
          ),
        ],
        totalAmount: 10500.0, // 1000 coupon discount
        discountAmount: 1000.0,
        couponCode: 'AGRO1000',
        shippingAddress: ShippingAddress(
          villageArea: 'Tehsil Road, Shop 5',
          cityTehsil: 'Osian, Jodhpur',
          pincode: '342303',
        ),
        paymentMethod: 'Partial',
        paymentStatus: 'Partially Paid',
        advanceAmount: 3000.0,
        remainingAmount: 7500.0,
        orderStatus: 'RTO',
        placedAt: now.subtract(const Duration(days: 6)),
        processingAt: now.subtract(const Duration(days: 5, hours: 22)),
        shippedAt: now.subtract(const Duration(days: 4, hours: 14)),
        rtoAt: now.subtract(const Duration(days: 2)),
        courierName: 'Delhivery',
        awbNumber: '456711999',
        trackingUrl:
            'https://track.delhivery.com/api/v1/packages/json/?waybill=456711999',
        courierStatus: 'Returned to origin - Consignee refused delivery',
        assignedAgent: 'Rajesh',
      ),
    ];
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
            'Pending',
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

    final Widget body = SizedBox.expand(
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
    );

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

    // Pending approval orders
    final pendingOrders = _orders
        .where((o) => o.orderStatus == 'Pending')
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
              trendLabel: '$pendingOrders pending approval',
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
                        ? (processingOrders + pendingOrders) / totalOrders
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
      'Pending',
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
                  setState(() {});
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
                        order.assignedAgent == null ||
                                order.assignedAgent!.isEmpty
                            ? '-'
                            : order.assignedAgent!,
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
