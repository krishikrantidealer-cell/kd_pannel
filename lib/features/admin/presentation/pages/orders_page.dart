import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kd_pannel/app_theme.dart';
import 'package:kd_pannel/core/responsive/responsive.dart';
import 'package:kd_pannel/features/shared/widgets/advanced_stat_card_widget.dart';
import 'package:kd_pannel/features/admin/data/models/order_model.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/orders_bloc.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/orders_event.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/orders_state.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/dealers_bloc.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/dealers_state.dart';
import 'package:kd_pannel/core/network/websocket_service.dart';
import 'package:kd_pannel/core/auth/auth_service.dart';
import 'dart:async';

export 'package:kd_pannel/features/admin/data/models/order_model.dart';

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
  final TextEditingController _searchController = TextEditingController();

  String? _hoveredOrderId;
  StreamSubscription? _ordersWsSubscription;

  @override
  void initState() {
    super.initState();
    final bloc = context.read<OrdersBloc>();
    _searchController.text = bloc.state.searchQuery;
    if (bloc.state.status == OrdersStatus.initial) {
      bloc.add(const FetchOrdersEvent());
    }

    WebSocketService().connect();
    _ordersWsSubscription = WebSocketService().ordersUpdates.listen((_) {
      if (mounted) {
        context.read<OrdersBloc>().add(const FetchOrdersEvent(forceRefresh: true));
      }
    });
  }

  @override
  void dispose() {
    _ordersWsSubscription?.cancel();
    _scrollController.dispose();
    _tableHorizontalController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // --- QUERY FILTERING MECHANICS ---
  List<OrderModel> _getFilteredOrders(
    List<OrderModel> orders,
    OrdersState state,
  ) {
    final role = AuthService().currentUserRole ?? UserRole.admin;
    final String? currentAgentId = AuthService().currentUserId;
    final String? currentAgentName = AuthService().currentUserName?.toLowerCase().trim();

    // 1. First, apply Role-based base filtering (Agent Assignment)
    Iterable<OrderModel> baseOrders = orders;
    if (role == UserRole.sales) {
      baseOrders = orders.where((order) {
        // Match by ID first (most reliable)
        if (currentAgentId != null && order.assignedAgentId == currentAgentId) {
          return true;
        }
        // Fallback to name match (for legacy or inconsistent data)
        if (currentAgentName != null) {
          final assigned = order.assignedAgent?.toLowerCase().trim() ?? '';
          return assigned == currentAgentName;
        }
        return false;
      });
    }

    // 2. Then apply UI filters (Search, Status, etc)
    return baseOrders.where((order) {
      final query = state.searchQuery.toLowerCase().trim();
      final matchesSearch =
          order.orderId.toLowerCase().contains(query) ||
          order.customerName.toLowerCase().contains(query) ||
          order.customerPhone.contains(query) ||
          (order.awbNumber ?? '').toLowerCase().contains(query);

      final matchesOrderStatus =
          state.selectedOrderStatus == 'All Statuses' ||
          order.orderStatus.toLowerCase().trim() == state.selectedOrderStatus.toLowerCase().trim();

      final matchesPaymentStatus =
          state.selectedPaymentStatus == 'All Payments' ||
          order.paymentStatus.toLowerCase().trim() == state.selectedPaymentStatus.toLowerCase().trim();

      final matchesPaymentMethod =
          state.selectedPaymentMethod == 'All Methods' ||
          order.paymentMethod.toLowerCase().trim() == state.selectedPaymentMethod.toLowerCase().trim();

      return matchesSearch &&
          matchesOrderStatus &&
          matchesPaymentStatus &&
          matchesPaymentMethod;
    }).toList();
  }

  // --- WIDGET BUILDER ---
  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      child: BlocBuilder<DealersBloc, DealersState>(
        builder: (context, dealersState) {
          final allUsers = dealersState.allRawUsers;

          return BlocConsumer<OrdersBloc, OrdersState>(
            listener: (context, state) {
              if (_searchController.text != state.searchQuery) {
                _searchController.text = state.searchQuery;
              }
              if (state.errorMessage != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(state.errorMessage!),
                    backgroundColor: AppTheme.error,
                  ),
                );
                context.read<OrdersBloc>().add(const ClearOrdersMessageEvent());
              }
            },
            builder: (context, state) {
              final bool isMobile = Responsive.isMobile(context);
              final filtered = _getFilteredOrders(state.orders, state);
              final EdgeInsets screenPadding =
                  AppTheme.getResponsivePadding(context);

              final int total = filtered.length;
              final int totalPages = (total / state.pageSize).ceil();
              final int currentPage = state.currentPage.clamp(
                1,
                totalPages > 0 ? totalPages : 1,
              );

              final int startIndex = (currentPage - 1) * state.pageSize;
              final int endIndex = (startIndex + state.pageSize) > total
                  ? total
                  : (startIndex + state.pageSize);
              final paginatedOrders = total == 0
                  ? <OrderModel>[]
                  : filtered.sublist(startIndex, endIndex);

              if (state.status == OrdersStatus.loading && state.orders.isEmpty) {
                return const SizedBox.expand(
                  child: Center(
                    child: CircularProgressIndicator(color: AppTheme.primaryColor),
                  ),
                );
              }

              if (state.status == OrdersStatus.failure && state.orders.isEmpty) {
                return SizedBox.expand(
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
                          state.errorMessage ?? 'Failed to load orders.',
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
                            onTap: () {
                              context.read<OrdersBloc>().add(
                                const FetchOrdersEvent(forceRefresh: true),
                              );
                            },
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
                );
              }

              final Widget bodyContent = Builder(
                builder: (context) => SizedBox.expand(
                  child: RefreshIndicator(
                    color: AppTheme.primaryColor,
                    onRefresh: () async {
                      context.read<OrdersBloc>().add(
                        const FetchOrdersEvent(forceRefresh: true),
                      );
                    },
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.symmetric(vertical: screenPadding.top),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header
                          if (!widget.isStandalone) ...[
                            Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: screenPadding.left,
                              ),
                              child: _buildHeader(),
                            ),
                            const SizedBox(height: 24),
                          ],

                          // Statistics Grid
                          Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: screenPadding.left,
                            ),
                            child: _buildStatsGrid(state, filtered),
                          ),
                          const SizedBox(height: 24),

                          // Search & Filter controls
                          Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: screenPadding.left,
                            ),
                            child: _buildFilterControls(isMobile, state),
                          ),
                          const SizedBox(height: 16),

                          // Orders Table
                          _buildOrdersTable(
                            paginatedOrders,
                            filtered.length,
                            isMobile,
                            screenPadding,
                            state,
                            currentPage,
                            allUsers,
                          ),
                        ],
                      ),
                    ),
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
                  body: bodyContent,
                );
              }

              return bodyContent;
            },
          );
        },
      ),
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

  Widget _buildStatsGrid(OrdersState state, List<OrderModel> filteredOrders) {
    final bool isDesktop = Responsive.isDesktop(context);

    // Dynamic counts from filtered orders (which are already agent-filtered if sales)
    final int totalOrders = filteredOrders.length;
    final int processingOrders = filteredOrders
        .where((o) => o.orderStatus.toLowerCase() == 'processing')
        .length;
    final int shippedOrders = filteredOrders
        .where((o) => o.orderStatus.toLowerCase() == 'shipped')
        .length;
    final int deliveredOrders = filteredOrders
        .where((o) => o.orderStatus.toLowerCase() == 'delivered')
        .length;

    // Today's orders
    final now = DateTime.now();
    final placedToday = filteredOrders
        .where(
          (o) =>
              o.placedAt.year == now.year &&
              o.placedAt.month == now.month &&
              o.placedAt.day == now.day,
        )
        .length;

    // Shipped / Out for delivery in transit
    final outForDeliveryOrders = filteredOrders
        .where((o) => o.orderStatus.toLowerCase() == 'out for delivery')
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
                context.read<OrdersBloc>().add(
                  const UpdateOrdersFilterEvent(
                    selectedOrderStatus: 'All Statuses',
                    currentPage: 1,
                  ),
                );
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
                context.read<OrdersBloc>().add(
                  const UpdateOrdersFilterEvent(
                    selectedOrderStatus: 'Processing',
                    currentPage: 1,
                  ),
                );
              },
              visualWidget: SizedBox(
                width: 28,
                height: 28,
                child: CustomPaint(
                  painter: FulfillmentProgressPainter(
                    totalOrders > 0 ? processingOrders / totalOrders : 0.0,
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
                context.read<OrdersBloc>().add(
                  const UpdateOrdersFilterEvent(
                    selectedOrderStatus: 'Shipped',
                    currentPage: 1,
                  ),
                );
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
                context.read<OrdersBloc>().add(
                  const UpdateOrdersFilterEvent(
                    selectedOrderStatus: 'Delivered',
                    currentPage: 1,
                  ),
                );
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

  Widget _buildFilterControls(bool isMobile, OrdersState state) {
    final Widget searchField = Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.search_rounded,
            color: AppTheme.textSecondary,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                context.read<OrdersBloc>().add(
                  UpdateOrdersFilterEvent(searchQuery: val, currentPage: 1),
                );
              },
              textAlignVertical: TextAlignVertical.center,
              style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search order ID, client name, phone...',
                hintStyle: GoogleFonts.outfit(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );

    final List<String> orderStatusOptions = [
      'All Statuses',
      'Pending',
      'Processing',
      'Shipped',
      'Out for Delivery',
      'Delivered',
      'Cancelled',
      'RTO',
    ];

    final List<String> paymentStatusOptions = [
      'All Payments',
      'Pending',
      'Paid',
      'Partially Paid',
      'Failed',
    ];

    final List<String> paymentMethodOptions = ['All Methods', 'Online', 'COD'];

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          searchField,
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildDropdown(
                  orderStatusOptions,
                  state.selectedOrderStatus,
                  (val) {
                    context.read<OrdersBloc>().add(
                      UpdateOrdersFilterEvent(
                        selectedOrderStatus: val!,
                        currentPage: 1,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildDropdown(
                  paymentStatusOptions,
                  state.selectedPaymentStatus,
                  (val) {
                    context.read<OrdersBloc>().add(
                      UpdateOrdersFilterEvent(
                        selectedPaymentStatus: val!,
                        currentPage: 1,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildDropdown(paymentMethodOptions, state.selectedPaymentMethod, (
            val,
          ) {
            context.read<OrdersBloc>().add(
              UpdateOrdersFilterEvent(
                selectedPaymentMethod: val!,
                currentPage: 1,
              ),
            );
          }),
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: searchField),
        const SizedBox(width: 12),
        _buildDropdown(orderStatusOptions, state.selectedOrderStatus, (val) {
          context.read<OrdersBloc>().add(
            UpdateOrdersFilterEvent(selectedOrderStatus: val!, currentPage: 1),
          );
        }, width: 150),
        const SizedBox(width: 12),
        _buildDropdown(paymentStatusOptions, state.selectedPaymentStatus, (
          val,
        ) {
          context.read<OrdersBloc>().add(
            UpdateOrdersFilterEvent(selectedPaymentStatus: val!, currentPage: 1),
          );
        }, width: 150),
        const SizedBox(width: 12),
        _buildDropdown(paymentMethodOptions, state.selectedPaymentMethod, (
          val,
        ) {
          context.read<OrdersBloc>().add(
            UpdateOrdersFilterEvent(selectedPaymentMethod: val!, currentPage: 1),
          );
        }, width: 130),
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
          isExpanded: true,
          padding: EdgeInsets.zero,
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
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
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
    int totalFiltered,
    bool isMobile,
    EdgeInsets screenPadding,
    OrdersState state,
    int currentPage,
    List<Map<String, dynamic>> allUsers,
  ) {
    final header = Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      color: const Color(0xFFF9FAFB),
      child: Row(
        children: const [
          Expanded(flex: 6, child: _TableHeaderText('ORDER ID')),
          Expanded(flex: 6, child: _TableHeaderText('DATE & TIME')),
          Expanded(flex: 12, child: _TableHeaderText('CUSTOMER')),
          Expanded(flex: 6, child: _TableHeaderText('ASSIGNED AGENT')),
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

          // Resolve LATEST assigned agent from current dealer state
          final user = allUsers.firstWhere(
            (u) => u['_id'] == order.userId,
            orElse: () => {},
          );
          String? latestAgent;
          if (user.isNotEmpty && user['assignedAgent'] != null) {
            final a = user['assignedAgent'];
            latestAgent =
                '${a['firstName'] ?? ''} ${a['lastName'] ?? ''}'.trim();
          }

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
                  context.read<OrdersBloc>().add(
                    const FetchOrdersEvent(forceRefresh: true),
                  );
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
                        (latestAgent != null && latestAgent.isNotEmpty)
                            ? latestAgent
                            : (order.assignedAgent ?? '-'),
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
          _buildTableFooter(totalFiltered, isMobile, state, currentPage),
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

  Widget _buildPageSizeSelector(OrdersState state) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Show',
          style: GoogleFonts.outfit(
            fontSize: 12,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: state.pageSize,
              icon: const Icon(
                Icons.arrow_drop_down,
                size: 18,
                color: AppTheme.textSecondary,
              ),
              style: GoogleFonts.outfit(
                fontSize: 11,
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
              ),
              dropdownColor: Colors.white,
              items: [10, 20, 30, 40, 50]
                  .map<DropdownMenuItem<int>>(
                    (int val) =>
                        DropdownMenuItem<int>(value: val, child: Text('$val')),
                  )
                  .toList(),
              onChanged: (int? newValue) {
                if (newValue != null) {
                  context.read<OrdersBloc>().add(
                    UpdateOrdersFilterEvent(pageSize: newValue, currentPage: 1),
                  );
                }
              },
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'entries',
          style: GoogleFonts.outfit(
            fontSize: 12,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildTableFooter(
    int total,
    bool isMobile,
    OrdersState state,
    int currentPage,
  ) {
    final start = total == 0 ? 0 : (currentPage - 1) * state.pageSize + 1;
    final end = (currentPage * state.pageSize) > total
        ? total
        : (currentPage * state.pageSize);

    final footerPadding = isMobile
        ? const EdgeInsets.symmetric(horizontal: 16, vertical: 12)
        : const EdgeInsets.symmetric(horizontal: 12, vertical: 12);

    return Container(
      padding: footerPadding,
      decoration: const BoxDecoration(
        color: Color(0xFFF9FAFB),
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(AppTheme.borderRadiusLarge),
        ),
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    Text(
                      'Showing $start to $end of $total entries',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    _buildPageSizeSelector(state),
                  ],
                ),
                const SizedBox(height: 12),
                _buildPaginationControls(total, state, currentPage),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Showing $start to $end of $total entries',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 20),
                    _buildPageSizeSelector(state),
                  ],
                ),
                _buildPaginationControls(total, state, currentPage),
              ],
            ),
    );
  }

  Widget _buildPaginationControls(
    int total,
    OrdersState state,
    int currentPage,
  ) {
    final int totalPages = (total / state.pageSize).ceil();
    final int displayPages = totalPages > 0 ? totalPages : 1;

    List<Widget> pageButtons = [];

    if (displayPages <= 5) {
      for (int i = 1; i <= displayPages; i++) {
        pageButtons.add(
          _PageNumberButton(
            page: i,
            isActive: currentPage == i,
            onTap: () {
              context.read<OrdersBloc>().add(
                UpdateOrdersFilterEvent(currentPage: i),
              );
            },
          ),
        );
        if (i < displayPages) {
          pageButtons.add(const SizedBox(width: 8));
        }
      }
    } else {
      pageButtons.add(
        _PageNumberButton(
          page: 1,
          isActive: currentPage == 1,
          onTap: () {
            context.read<OrdersBloc>().add(
              const UpdateOrdersFilterEvent(currentPage: 1),
            );
          },
        ),
      );
      pageButtons.add(const SizedBox(width: 8));

      if (currentPage > 3) {
        pageButtons.add(
          Text(
            '...',
            style: GoogleFonts.outfit(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
        pageButtons.add(const SizedBox(width: 8));
      }

      final start = (currentPage - 1).clamp(2, displayPages - 1);
      final end = (currentPage + 1).clamp(2, displayPages - 1);

      for (int i = start; i <= end; i++) {
        if (i > 1 && i < displayPages) {
          pageButtons.add(
            _PageNumberButton(
              page: i,
              isActive: currentPage == i,
              onTap: () {
                context.read<OrdersBloc>().add(
                  UpdateOrdersFilterEvent(currentPage: i),
                );
              },
            ),
          );
          pageButtons.add(const SizedBox(width: 8));
        }
      }

      if (currentPage < displayPages - 2) {
        pageButtons.add(
          Text(
            '...',
            style: GoogleFonts.outfit(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
        pageButtons.add(const SizedBox(width: 8));
      }

      pageButtons.add(
        _PageNumberButton(
          page: displayPages,
          isActive: currentPage == displayPages,
          onTap: () {
            context.read<OrdersBloc>().add(
              UpdateOrdersFilterEvent(currentPage: displayPages),
            );
          },
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PaginationButton(
          onTap: currentPage > 1
              ? () {
                  context.read<OrdersBloc>().add(
                    UpdateOrdersFilterEvent(currentPage: currentPage - 1),
                  );
                }
              : null,
          icon: Icons.chevron_left,
          isDisabled: currentPage <= 1,
        ),
        const SizedBox(width: 12),
        ...pageButtons,
        const SizedBox(width: 12),
        _PaginationButton(
          onTap: currentPage < displayPages
              ? () {
                  context.read<OrdersBloc>().add(
                    UpdateOrdersFilterEvent(currentPage: currentPage + 1),
                  );
                }
              : null,
          icon: Icons.chevron_right,
          isDisabled: currentPage >= displayPages,
        ),
      ],
    );
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

class _PageNumberButton extends StatefulWidget {
  final int page;
  final bool isActive;
  final VoidCallback? onTap;

  const _PageNumberButton({
    required this.page,
    required this.isActive,
    this.onTap,
  });

  @override
  State<_PageNumberButton> createState() => _PageNumberButtonState();
}

class _PageNumberButtonState extends State<_PageNumberButton> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: widget.isActive
                ? AppTheme.primaryColor
                : (isHovered ? const Color(0xFFF3F4F6) : Colors.white),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: widget.isActive
                  ? AppTheme.primaryColor
                  : AppTheme.borderColor,
            ),
          ),
          child: Text(
            '${widget.page}',
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: widget.isActive ? Colors.white : AppTheme.textBody,
            ),
          ),
        ),
      ),
    );
  }
}

class _PaginationButton extends StatefulWidget {
  final VoidCallback? onTap;
  final IconData icon;
  final bool isDisabled;

  const _PaginationButton({
    required this.onTap,
    required this.icon,
    this.isDisabled = false,
  });

  @override
  State<_PaginationButton> createState() => _PaginationButtonState();
}

class _PaginationButtonState extends State<_PaginationButton> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.isDisabled
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      child: GestureDetector(
        onTap: widget.isDisabled ? null : widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: widget.isDisabled
                ? Colors.white
                : (isHovered ? const Color(0xFFF3F4F6) : Colors.white),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Icon(
            widget.icon,
            size: 18,
            color: widget.isDisabled
                ? const Color(0xFFD1D5DB)
                : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}
