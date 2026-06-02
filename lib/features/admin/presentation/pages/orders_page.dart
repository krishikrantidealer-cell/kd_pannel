import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kd_pannel/app_theme.dart';
import 'package:kd_pannel/core/responsive/responsive.dart';
import 'package:kd_pannel/features/shared/widgets/stat_card_widget.dart';

// --- MODELS ALIGNED WITH BACKEND SCHEMA (Order.js) ---

class OrderItem {
  final String productId;
  final String variantId;
  final String title;
  final String? vendor;
  final String? image;
  final int quantity;
  final double price;

  OrderItem({
    required this.productId,
    required this.variantId,
    required this.title,
    this.vendor,
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
  });
}

// --- ORDERS PAGE ---

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

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

  // Selected Order for side-panel detail drawer
  OrderModel? _selectedOrder;
  String? _hoveredOrderId;
  bool _isDrawerOpen = false;

  // Controllers for updating tracking details inside the drawer
  final TextEditingController _awbController = TextEditingController();
  final TextEditingController _courierController = TextEditingController();
  final TextEditingController _trackingUrlController = TextEditingController();

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
            image: null,
            quantity: 2,
            price: 2400.0,
          ),
          OrderItem(
            productId: 'p2',
            variantId: 'v3',
            title: 'Hybrid Seed Pack (250g)',
            vendor: 'Mahyco',
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
            image: null,
            quantity: 1,
            price: 2400.0,
          ),
          OrderItem(
            productId: 'p4',
            variantId: 'v6',
            title: 'Fertilizer Blend X (20kg)',
            vendor: 'IFFCO',
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
      ),
    ];
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _tableHorizontalController.dispose();
    _awbController.dispose();
    _courierController.dispose();
    _trackingUrlController.dispose();
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
  void _openOrderDrawer(OrderModel order) {
    setState(() {
      _selectedOrder = order;
      _awbController.text = order.awbNumber ?? '';
      _courierController.text = order.courierName ?? '';
      _trackingUrlController.text = order.trackingUrl ?? '';
      _isDrawerOpen = true;
    });
  }

  void _closeOrderDrawer() {
    setState(() {
      _isDrawerOpen = false;
    });
  }

  void _updateSelectedOrderStatus(String newStatus) {
    if (_selectedOrder == null) return;
    setState(() {
      _selectedOrder!.orderStatus = newStatus;
      final now = DateTime.now();

      // Automatically sync milestones
      if (newStatus == 'Processing' && _selectedOrder!.processingAt == null) {
        _selectedOrder!.processingAt = now;
      } else if (newStatus == 'Shipped' && _selectedOrder!.shippedAt == null) {
        if (_selectedOrder!.processingAt == null)
          _selectedOrder!.processingAt = now;
        _selectedOrder!.shippedAt = now;
      } else if (newStatus == 'Out for Delivery' &&
          _selectedOrder!.outForDeliveryAt == null) {
        if (_selectedOrder!.processingAt == null)
          _selectedOrder!.processingAt = now;
        if (_selectedOrder!.shippedAt == null) _selectedOrder!.shippedAt = now;
        _selectedOrder!.outForDeliveryAt = now;
      } else if (newStatus == 'Delivered' &&
          _selectedOrder!.deliveredAt == null) {
        if (_selectedOrder!.processingAt == null)
          _selectedOrder!.processingAt = now;
        if (_selectedOrder!.shippedAt == null) _selectedOrder!.shippedAt = now;
        if (_selectedOrder!.outForDeliveryAt == null)
          _selectedOrder!.outForDeliveryAt = now;
        _selectedOrder!.deliveredAt = now;
        _selectedOrder!.paymentStatus =
            'Paid'; // Automatically marked paid when delivered
      } else if (newStatus == 'RTO' && _selectedOrder!.rtoAt == null) {
        _selectedOrder!.rtoAt = now;
      } else if (newStatus == 'Cancelled' &&
          _selectedOrder!.cancelledAt == null) {
        _selectedOrder!.cancelledAt = now;
      }
    });
  }

  void _saveTrackingDetails() {
    if (_selectedOrder == null) return;
    setState(() {
      _selectedOrder!.awbNumber = _awbController.text.trim();
      _selectedOrder!.courierName = _courierController.text.trim();
      _selectedOrder!.trackingUrl = _trackingUrlController.text.trim();

      if (_selectedOrder!.awbNumber!.isNotEmpty &&
          _selectedOrder!.orderStatus == 'Pending') {
        _selectedOrder!.orderStatus = 'Processing';
        _selectedOrder!.processingAt = DateTime.now();
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Tracking details saved for Order #${_selectedOrder!.orderId}',
        ),
        backgroundColor: AppTheme.success,
      ),
    );
  }

  void _cancelOrder() {
    if (_selectedOrder == null) return;
    setState(() {
      _selectedOrder!.orderStatus = 'Cancelled';
      _selectedOrder!.cancelledAt = DateTime.now();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Order #${_selectedOrder!.orderId} cancelled successfully',
        ),
        backgroundColor: AppTheme.error,
      ),
    );
  }

  // --- WIDGET BUILDER ---
  @override
  Widget build(BuildContext context) {
    final bool isMobile = Responsive.isMobile(context);
    final filtered = _filteredOrders;

    return Stack(
      children: [
        // Main Screen Scrollable content (Non-positioned child with expand constraints!)
        SizedBox.expand(
          child: SingleChildScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            padding: AppTheme.getResponsivePadding(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                _buildHeader(),
                const SizedBox(height: 24),

                // Statistics Grid
                _buildStatsGrid(),
                const SizedBox(height: 24),

                // Search & Filter controls
                _buildFilterControls(isMobile),
                const SizedBox(height: 16),

                // Orders Table
                _buildOrdersTable(filtered, isMobile),
              ],
            ),
          ),
        ),

        // Slide-over Shopify style Drawer Sheet
        _buildSlideDrawer(context),
      ],
    );
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
    final double spacing = AppTheme.spacingMedium;

    if (isDesktop) {
      return Row(
        children: [
          Expanded(
            child: StatCardWidget(
              title: 'Total Orders',
              value: '${_orders.length}',
              icon: Icons.shopping_bag_outlined,
              color: AppTheme.primaryColor,
              isCompact: true,
            ),
          ),
          SizedBox(width: spacing),
          Expanded(
            child: StatCardWidget(
              title: 'Realized Revenue',
              value: '₹${_totalRevenue.toStringAsFixed(0)}',
              icon: Icons.currency_rupee_rounded,
              color: AppTheme.accentColor,
              isCompact: true,
            ),
          ),
          SizedBox(width: spacing),
          Expanded(
            child: StatCardWidget(
              title: 'Fulfillments Pending',
              value: '$_pendingFulfillments',
              icon: Icons.local_shipping_outlined,
              color: AppTheme.info,
              isCompact: true,
            ),
          ),
          SizedBox(width: spacing),
          Expanded(
            child: StatCardWidget(
              title: 'Pending Payments',
              value: '$_pendingPayments',
              icon: Icons.hourglass_bottom_rounded,
              color: AppTheme.warning,
              isCompact: true,
            ),
          ),
        ],
      );
    }

    // For Mobile & Tablet: 2x2 grid using Column and Row
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: StatCardWidget(
                title: 'Total Orders',
                value: '${_orders.length}',
                icon: Icons.shopping_bag_outlined,
                color: AppTheme.primaryColor,
                isCompact: true,
              ),
            ),
            SizedBox(width: spacing),
            Expanded(
              child: StatCardWidget(
                title: 'Realized Revenue',
                value: '₹${_totalRevenue.toStringAsFixed(0)}',
                icon: Icons.currency_rupee_rounded,
                color: AppTheme.accentColor,
                isCompact: true,
              ),
            ),
          ],
        ),
        SizedBox(height: spacing),
        Row(
          children: [
            Expanded(
              child: StatCardWidget(
                title: 'Fulfillments Pending',
                value: '$_pendingFulfillments',
                icon: Icons.local_shipping_outlined,
                color: AppTheme.info,
                isCompact: true,
              ),
            ),
            SizedBox(width: spacing),
            Expanded(
              child: StatCardWidget(
                title: 'Pending Payments',
                value: '$_pendingPayments',
                icon: Icons.hourglass_bottom_rounded,
                color: AppTheme.warning,
                isCompact: true,
              ),
            ),
          ],
        ),
      ],
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

  Widget _buildOrdersTable(List<OrderModel> orders, bool isMobile) {
    final header = Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color: const Color(0xFFF9FAFB),
      child: Row(
        children: const [
          Expanded(flex: 2, child: _TableHeaderText('ORDER ID')),
          Expanded(flex: 3, child: _TableHeaderText('DATE & TIME')),
          Expanded(flex: 4, child: _TableHeaderText('CUSTOMER')),
          Expanded(flex: 3, child: _TableHeaderText('PAYMENT STATUS')),
          Expanded(flex: 3, child: _TableHeaderText('FULFILLMENT')),
          Expanded(flex: 2, child: _TableHeaderText('ITEMS')),
          Expanded(flex: 3, child: _TableHeaderText('TOTAL AMOUNT')),
        ],
      ),
    );

    Widget tableBody;
    if (orders.isEmpty) {
      tableBody = Container(
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Text(
            'No orders match your filters',
            style: GoogleFonts.outfit(
              color: AppTheme.textSecondary,
              fontSize: 13,
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
              onTap: () => _openOrderDrawer(order),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: _hoveredOrderId == order.id
                      ? AppTheme.primaryColor.withValues(alpha: 0.04)
                      : (isEven ? Colors.white : const Color(0xFFF9FAFB)),
                  border: Border(
                    bottom: BorderSide(color: AppTheme.lightBorderColor),
                    left: BorderSide(
                      color: _hoveredOrderId == order.id
                          ? AppTheme.primaryColor.withValues(alpha: 0.5)
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    // ORDER ID
                    Expanded(
                      flex: 2,
                      child: Text(
                        order.orderId,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),

                    // DATE
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _formatDate(order.placedAt),
                            style: GoogleFonts.outfit(
                              fontSize: 12.5,
                              color: AppTheme.textBody,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatTime(order.placedAt),
                            style: GoogleFonts.outfit(
                              fontSize: 11.5,
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // CUSTOMER
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  order.customerName,
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            order.customerPhone,
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // PAYMENT
                    Expanded(
                      flex: 3,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: _buildPaymentBadge(order.paymentStatus),
                      ),
                    ),

                    // FULFILLMENT
                    Expanded(
                      flex: 3,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: _buildFulfillmentBadge(order.orderStatus),
                      ),
                    ),

                    // ITEMS COUNT
                    Expanded(
                      flex: 2,
                      child: Text(
                        '${order.items.fold(0, (sum, i) => sum + i.quantity)} unit(s)',
                        style: GoogleFonts.outfit(
                          fontSize: 12.5,
                          color: AppTheme.textBody,
                        ),
                      ),
                    ),

                    // TOTAL AMOUNT
                    Expanded(
                      flex: 3,
                      child: Text(
                        '₹${order.totalAmount.toStringAsFixed(2)}',
                        style: GoogleFonts.outfit(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
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
        // Keep enough width so right-most columns never get clipped on smaller laptops.
        final double minTableWidth = isMobile ? 980 : 1180;
        final bool needsHorizontalScroll = availableWidth < minTableWidth;
        final double tableWidth = needsHorizontalScroll
            ? minTableWidth
            : availableWidth;

        return Scrollbar(
          controller: _tableHorizontalController,
          thumbVisibility: needsHorizontalScroll,
          trackVisibility: needsHorizontalScroll,
          child: SingleChildScrollView(
            controller: _tableHorizontalController,
            scrollDirection: Axis.horizontal,
            child: SizedBox(width: tableWidth, child: tableWidget),
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

  // --- SHOPIFY-STYLE SLIDE SHEET OVERLAY ---
  Widget _buildSlideDrawer(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = Responsive.isMobile(context);
    final double drawerWidth = isMobile ? screenWidth : 580.0;

    if (_selectedOrder == null) return const SizedBox.shrink();

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      right: _isDrawerOpen ? 0.0 : -drawerWidth,
      top: 0,
      bottom: 0,
      width: drawerWidth,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 30,
              offset: const Offset(-8, 0),
            ),
          ],
          border: const Border(left: BorderSide(color: AppTheme.borderColor)),
        ),
        child: Column(
          children: [
            // Drawer Header
            _buildDrawerHeader(),

            // Scrollable Content
            Expanded(
              child: SelectionArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Admin Management Tool Action Block
                      _buildAdminFulfillmentControls(),
                      const SizedBox(height: 20),

                      // Items Ordered Block
                      _buildDrawerItemsBlock(),
                      const SizedBox(height: 20),

                      // Financial summary
                      _buildDrawerFinancialSummary(),
                      const SizedBox(height: 20),

                      // Timeline
                      _buildDrawerTimeline(),
                      const SizedBox(height: 20),

                      // Address and customer details
                      _buildDrawerCustomerInfo(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: Color(0xFFF9FAFB),
        border: Border(bottom: BorderSide(color: AppTheme.borderColor)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    _selectedOrder!.orderId,
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildPaymentBadge(_selectedOrder!.paymentStatus),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Placed on ${_formatDateTime(_selectedOrder!.placedAt)}',
                style: GoogleFonts.outfit(
                  fontSize: 11.5,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          IconButton(
            onPressed: _closeOrderDrawer,
            icon: const Icon(Icons.close_rounded, size: 20),
            hoverColor: Colors.black.withValues(alpha: 0.05),
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(6),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminFulfillmentControls() {
    final bool canCancel = ![
      'Shipped',
      'Out for Delivery',
      'Delivered',
      'Cancelled',
      'RTO',
    ].contains(_selectedOrder!.orderStatus);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.security_update_good_rounded,
                color: AppTheme.primaryColor,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Fulfillment & Status Updates',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Order status dropdown
          Text(
            'Order Status',
            style: GoogleFonts.outfit(
              fontSize: 11.5,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: 38,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedOrder!.orderStatus,
                onChanged: (val) => _updateSelectedOrderStatus(val!),
                items:
                    [
                          'Pending',
                          'Processing',
                          'Shipped',
                          'Out for Delivery',
                          'Delivered',
                          'Cancelled',
                          'RTO',
                        ]
                        .map<DropdownMenuItem<String>>(
                          (val) => DropdownMenuItem<String>(
                            value: val,
                            child: Text(
                              val,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                        )
                        .toList(),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Carrier tracking inputs
          Text(
            'AWB/Tracking Number',
            style: GoogleFonts.outfit(
              fontSize: 11.5,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          _buildTrackingField(
            _awbController,
            'Enter AWB number (e.g. 456711289)',
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Courier Partner',
                      style: GoogleFonts.outfit(
                        fontSize: 11.5,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _buildTrackingField(_courierController, 'e.g. Delhivery'),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tracking URL',
                      style: GoogleFonts.outfit(
                        fontSize: 11.5,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _buildTrackingField(
                      _trackingUrlController,
                      'https://track.delhivery.com/...',
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _saveTrackingDetails,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    'Save Tracking Details',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              if (canCancel) ...[
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: _cancelOrder,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.error),
                    foregroundColor: AppTheme.error,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                  ),
                  child: Text(
                    'Cancel Order',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrackingField(TextEditingController controller, String hint) {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          isDense: true,
        ),
      ),
    );
  }

  Widget _buildDrawerItemsBlock() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Items Summary',
            style: GoogleFonts.outfit(
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),

          // Items List
          ..._selectedOrder!.items.map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  // Placeholder/Category thumbnail
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: const Icon(
                      Icons.eco_outlined,
                      color: AppTheme.primaryColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Vendor: ${item.vendor ?? 'Unknown'}',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₹${item.price.toStringAsFixed(0)} × ${item.quantity}',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: AppTheme.textBody,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '₹${(item.price * item.quantity).toStringAsFixed(2)}',
                        style: GoogleFonts.outfit(
                          fontSize: 12.5,
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),

          // Free items
          if (_selectedOrder!.freeItems.isNotEmpty) ...[
            const Divider(color: AppTheme.lightBorderColor),
            const SizedBox(height: 4),
            ..._selectedOrder!.freeItems.map((item) {
              return Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppTheme.accentColor.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: const Icon(
                      Icons.card_giftcard_rounded,
                      color: AppTheme.accentColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.accentColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'FREE PROMOTIONAL GIFT',
                            style: GoogleFonts.outfit(
                              fontSize: 8,
                              color: AppTheme.accentColor,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Qty: ${item.quantity}',
                    style: GoogleFonts.outfit(
                      fontSize: 12.5,
                      color: AppTheme.accentColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildDrawerFinancialSummary() {
    final double subtotal = _selectedOrder!.items.fold(
      0.0,
      (sum, i) => sum + (i.price * i.quantity),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Financial Summary',
            style: GoogleFonts.outfit(
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),

          _buildSummaryRow('Subtotal', '₹${subtotal.toStringAsFixed(2)}'),
          if (_selectedOrder!.discountAmount > 0) ...[
            const SizedBox(height: 8),
            _buildSummaryRow(
              'Coupon Applied (${_selectedOrder!.couponCode})',
              '-₹${_selectedOrder!.discountAmount.toStringAsFixed(2)}',
              valueColor: AppTheme.error,
            ),
          ],
          const SizedBox(height: 8),
          _buildSummaryRow(
            'Shipping / Delivery charges',
            'FREE',
            valueColor: AppTheme.success,
          ),
          const Divider(height: 24, color: AppTheme.lightBorderColor),

          _buildSummaryRow(
            'Total Amount',
            '₹${_selectedOrder!.totalAmount.toStringAsFixed(2)}',
            isBold: true,
            fontSize: 14.5,
          ),

          if (_selectedOrder!.paymentMethod == 'Partial') ...[
            const SizedBox(height: 8),
            _buildSummaryRow(
              'Advance Received (EMI Downpayment)',
              '₹${_selectedOrder!.advanceAmount.toStringAsFixed(2)}',
              valueColor: AppTheme.success,
            ),
            const SizedBox(height: 8),
            _buildSummaryRow(
              'Remaining Balance (COD)',
              '₹${_selectedOrder!.remainingAmount.toStringAsFixed(2)}',
              valueColor: AppTheme.warning,
              isBold: true,
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
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildDrawerTimeline() {
    final statusSteps = [
      {
        'title': 'Order Placed',
        'date': _selectedOrder!.placedAt,
        'isDone': true,
      },
      {
        'title': 'Processed',
        'date': _selectedOrder!.processingAt,
        'isDone': _selectedOrder!.processingAt != null,
      },
      {
        'title': 'Dispatched / Shipped',
        'date': _selectedOrder!.shippedAt,
        'isDone': _selectedOrder!.shippedAt != null,
      },
      {
        'title': 'Out for Delivery',
        'date': _selectedOrder!.outForDeliveryAt,
        'isDone': _selectedOrder!.outForDeliveryAt != null,
      },
      {
        'title': 'Delivered',
        'date': _selectedOrder!.deliveredAt,
        'isDone': _selectedOrder!.deliveredAt != null,
      },
    ];

    // Handle exceptions like Cancelled / RTO
    if (_selectedOrder!.orderStatus == 'Cancelled') {
      statusSteps.insert(
        statusSteps
            .indexWhere((step) => step['isDone'] != true)
            .clamp(0, statusSteps.length),
        {
          'title': 'Order Cancelled ❌',
          'date': _selectedOrder!.cancelledAt ?? DateTime.now(),
          'isDone': true,
        },
      );
    } else if (_selectedOrder!.orderStatus == 'RTO') {
      statusSteps.insert(
        statusSteps
            .indexWhere((step) => step['isDone'] != true)
            .clamp(0, statusSteps.length),
        {
          'title': 'Returned to Origin 📦',
          'date': _selectedOrder!.rtoAt ?? DateTime.now(),
          'isDone': true,
        },
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order Timeline & Courier Logs',
            style: GoogleFonts.outfit(
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),

          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: statusSteps.length,
            itemBuilder: (context, index) {
              final step = statusSteps[index];
              final bool isDone = step['isDone'] as bool;
              final DateTime? date = step['date'] as DateTime?;
              final bool isLast = index == statusSteps.length - 1;

              final Color bulletColor = isDone
                  ? (step['title'].toString().contains('Cancelled') ||
                            step['title'].toString().contains('Returned')
                        ? AppTheme.error
                        : AppTheme.success)
                  : AppTheme.borderColor;

              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: isDone ? bulletColor : Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDone
                                  ? Colors.transparent
                                  : AppTheme.borderColor,
                              width: 2,
                            ),
                          ),
                          child: isDone
                              ? const Center(
                                  child: Icon(
                                    Icons.check,
                                    size: 8,
                                    color: Colors.white,
                                  ),
                                )
                              : null,
                        ),
                        if (!isLast)
                          Expanded(
                            child: Container(
                              width: 2,
                              color: isDone
                                  ? AppTheme.success.withValues(alpha: 0.4)
                                  : AppTheme.borderColor,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              step['title'] as String,
                              style: GoogleFonts.outfit(
                                fontSize: 12.5,
                                fontWeight: isDone
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                color: isDone
                                    ? AppTheme.textPrimary
                                    : AppTheme.textSecondary,
                              ),
                            ),
                            if (date != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                _formatDateTime(date),
                                style: GoogleFonts.outfit(
                                  fontSize: 10.5,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          if (_selectedOrder!.courierStatus != null &&
              _selectedOrder!.courierStatus!.isNotEmpty) ...[
            const Divider(color: AppTheme.lightBorderColor),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  Icons.sync_alt_rounded,
                  color: AppTheme.primaryColor,
                  size: 14,
                ),
                const SizedBox(width: 6),
                Text(
                  'Latest Courier Logs (Synced):',
                  style: GoogleFonts.outfit(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _selectedOrder!.courierStatus!,
              style: GoogleFonts.outfit(
                fontSize: 11.5,
                color: AppTheme.textBody,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDrawerCustomerInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Customer & Shipping Details',
            style: GoogleFonts.outfit(
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              const Icon(
                Icons.person_outline_rounded,
                color: AppTheme.textSecondary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                _selectedOrder!.customerName,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(
                Icons.phone_iphone_rounded,
                color: AppTheme.textSecondary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                _selectedOrder!.customerPhone,
                style: GoogleFonts.outfit(
                  fontSize: 12.5,
                  color: AppTheme.textBody,
                ),
              ),
            ],
          ),
          const Divider(height: 20, color: AppTheme.lightBorderColor),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.location_on_outlined,
                color: AppTheme.textSecondary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Shipping Address',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _selectedOrder!.shippingAddress.villageArea,
                      style: GoogleFonts.outfit(
                        fontSize: 12.5,
                        color: AppTheme.textBody,
                      ),
                    ),
                    Text(
                      _selectedOrder!.shippingAddress.cityTehsil,
                      style: GoogleFonts.outfit(
                        fontSize: 12.5,
                        color: AppTheme.textBody,
                      ),
                    ),
                    Text(
                      'PIN Code: ${_selectedOrder!.shippingAddress.pincode}',
                      style: GoogleFonts.outfit(
                        fontSize: 12.5,
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
