import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kd_pannel/app_theme.dart';
import 'package:kd_pannel/core/responsive/responsive.dart';
import 'package:kd_pannel/features/shared/widgets/stat_card_widget.dart';
import 'package:kd_pannel/features/shared/widgets/table_widget.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/leads_bloc.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/leads_event.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/leads_state.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/dealers_bloc.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/dealers_event.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/dealers_state.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/orders_bloc.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/orders_event.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/orders_state.dart';
import 'package:kd_pannel/features/admin/data/models/order_model.dart';
import 'package:kd_pannel/core/auth/auth_service.dart';
import 'package:kd_pannel/core/network/websocket_service.dart';

class SalesDashboardPage extends StatefulWidget {
  const SalesDashboardPage({super.key});

  @override
  State<SalesDashboardPage> createState() => _SalesDashboardPageState();
}

class _SalesDashboardPageState extends State<SalesDashboardPage> {
  StreamSubscription? _leadsSubscription;
  StreamSubscription? _dealersSubscription;
  StreamSubscription? _ordersSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final leadsBloc = context.read<LeadsBloc>();
      leadsBloc.add(const FetchLeadsDataEvent(forceRefresh: true));

      final dealersBloc = context.read<DealersBloc>();
      dealersBloc.add(const FetchDealersDataEvent(forceRefresh: true));

      final ordersBloc = context.read<OrdersBloc>();
      if (ordersBloc.state.status == OrdersStatus.initial) {
        ordersBloc.add(const FetchOrdersEvent(forceRefresh: true));
      }
    });

    WebSocketService().connect();

    _leadsSubscription = WebSocketService().leadsUpdates.listen((_) {
      if (mounted) {
        context.read<LeadsBloc>().add(const FetchLeadsDataEvent(forceRefresh: true));
      }
    });

    _dealersSubscription = WebSocketService().dealersUpdates.listen((_) {
      if (mounted) {
        context.read<DealersBloc>().add(const FetchDealersDataEvent(forceRefresh: true));
      }
    });

    _ordersSubscription = WebSocketService().ordersUpdates.listen((_) {
      if (mounted) {
        context.read<OrdersBloc>().add(const FetchOrdersEvent(forceRefresh: true));
      }
    });
  }

  @override
  void dispose() {
    _leadsSubscription?.cancel();
    _dealersSubscription?.cancel();
    _ordersSubscription?.cancel();
    super.dispose();
  }

  List<Map<String, dynamic>> _getLeadsList(List<Map<String, dynamic>> rawUsers) {
    final agentId = AuthService().currentUserId;
    return rawUsers
        .where((u) {
          final role = u['role'] ?? 'user';
          final kycStatus = u['kycStatus'] ?? 'pending';
          final isLead = role == 'user' && kycStatus != 'verified';
          if (!isLead) return false;

          final assignedAgentId = u['assignedAgent']?['_id'];
          return assignedAgentId == agentId;
        })
        .map((u) {
          return {
            'id': u['_id'],
            'name': (u['firstName'] != null && u['firstName'].toString().trim().isNotEmpty)
                ? '${u['firstName']} ${u['lastName'] ?? ''}'.trim()
                : (u['phoneNumber'] ?? 'Unnamed Lead'),
            'phone': u['phoneNumber'] ?? '-',
            'source': u['source'] ?? 'App',
            'status': u['kycStatus'] ?? 'pending',
          };
        })
        .toList();
  }

  List<Map<String, dynamic>> _getDealersList(List<Map<String, dynamic>> rawUsers) {
    final agentId = AuthService().currentUserId;
    return rawUsers
        .where((u) {
          final role = u['role'] ?? 'user';
          final kycStatus = u['kycStatus'] ?? 'pending';
          final isDealer = role == 'user' && kycStatus == 'verified';
          if (!isDealer) return false;

          final assignedAgentId = u['assignedAgent']?['_id'];
          return assignedAgentId == agentId;
        })
        .map((u) {
          return {
            'id': u['_id'],
            'name': (u['shopName'] != null &&
                    u['shopName'].toString().trim().isNotEmpty &&
                    u['shopName'].toString().trim().toLowerCase() != 'my store')
                ? u['shopName']
                : ((u['firstName'] != null && u['firstName'].toString().trim().isNotEmpty)
                    ? '${u['firstName']} ${u['lastName'] ?? ''}'.trim()
                    : (u['phoneNumber'] ?? 'Unnamed Dealer')),
            'phone': u['phoneNumber'] ?? '-',
            'city': u['address']?['cityTehsil'] ?? '-',
            'state': u['address']?['state'] ?? '-',
          };
        })
        .toList();
  }

  List<OrderModel> _getOrdersList(List<OrderModel> allOrders) {
    final currentAgentId = AuthService().currentUserId;
    final currentAgentName = AuthService().currentUserName?.toLowerCase().trim();

    return allOrders.where((o) {
      // 1. Try matching by ID first (Reliable)
      if (currentAgentId != null && o.assignedAgentId == currentAgentId) {
        return true;
      }
      // 2. Fallback to name matching
      if (currentAgentName != null) {
        final assignedAgent = o.assignedAgent?.toLowerCase().trim();
        return assignedAgent == currentAgentName;
      }
      return false;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = Responsive.isDesktop(context);
    final double gap = AppTheme.getResponsiveGap(context);

    return BlocBuilder<LeadsBloc, LeadsState>(
      builder: (context, leadsState) {
        return BlocBuilder<DealersBloc, DealersState>(
          builder: (context, dealersState) {
            return BlocBuilder<OrdersBloc, OrdersState>(
              builder: (context, ordersState) {
                final leads = _getLeadsList(leadsState.allRawUsers);
                final dealers = _getDealersList(dealersState.allRawUsers);
                final orders = _getOrdersList(ordersState.orders);

                final bool isLoading = leadsState.status == LeadsStatus.loading ||
                    dealersState.status == DealersStatus.loading ||
                    ordersState.status == OrdersStatus.loading;

                // Prepare tables rows: only show up to 5 elements on dashboard for clarity
                final leadRows = leads.take(5).map((l) => [
                      l['name'] as String,
                      l['phone'] as String,
                      l['source'] as String,
                      l['status'] as String,
                    ]).toList();

                final dealerRows = dealers.take(5).map((d) => [
                      d['name'] as String,
                      d['phone'] as String,
                      d['city'] as String,
                      d['state'] as String,
                    ]).toList();

                final orderRows = orders.take(5).map((o) => [
                      o.orderId,
                      o.customerName,
                      '₹${o.totalAmount.toStringAsFixed(0)}',
                      o.orderStatus,
                    ]).toList();

                return SingleChildScrollView(
                  padding: AppTheme.getResponsivePadding(context),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              isDesktop
                                  ? 'KrishiDealer Sales Dashboard'
                                  : 'Sales Dashboard',
                              style: TextStyle(
                                fontSize: isDesktop ? 22 : 18,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isLoading)
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: gap),
                      _SalesStatsGrid(
                        leadsCount: leads.length,
                        dealersCount: dealers.length,
                        ordersCount: orders.length,
                      ),
                      SizedBox(height: gap),
                      TableWidget(
                        title: "My Recent Orders",
                        columns: const ['Order ID', 'Customer', 'Amount', 'Status'],
                        rows: orderRows.isNotEmpty
                            ? orderRows
                            : [
                                const ['No orders found', '-', '-', '-']
                              ],
                      ),
                      SizedBox(height: gap),
                      TableWidget(
                        title: "My Assigned Leads (Recent)",
                        columns: const ['Name', 'Phone', 'Source', 'KYC Status'],
                        rows: leadRows.isNotEmpty
                            ? leadRows
                            : [
                                const ['No assigned leads found', '-', '-', '-']
                              ],
                      ),
                      SizedBox(height: gap),
                      TableWidget(
                        title: "My Assigned Dealers (Recent)",
                        columns: const ['Dealer Name', 'Phone', 'City', 'State'],
                        rows: dealerRows.isNotEmpty
                            ? dealerRows
                            : [
                                const ['No assigned dealers found', '-', '-', '-']
                              ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _SalesStatsGrid extends StatelessWidget {
  final int leadsCount;
  final int dealersCount;
  final int ordersCount;

  const _SalesStatsGrid({
    required this.leadsCount,
    required this.dealersCount,
    required this.ordersCount,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double spacing = AppTheme.spacingMedium;
        int columns = 1;
        if (constraints.maxWidth >= 950) {
          columns = 3;
        } else if (constraints.maxWidth >= 600) {
          columns = 2;
        }
        final double width =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            StatCardWidget(
              width: width,
              title: 'My Orders',
              value: '$ordersCount',
              icon: Icons.shopping_bag_outlined,
              color: AppTheme.accentColor,
            ),
            StatCardWidget(
              width: width,
              title: 'My Leads',
              value: '$leadsCount',
              icon: Icons.person_add_outlined,
              color: AppTheme.info,
            ),
            StatCardWidget(
              width: width,
              title: 'My Dealers',
              value: '$dealersCount',
              icon: Icons.storefront_outlined,
              color: AppTheme.primaryColor,
            ),
          ],
        );
      },
    );
  }
}
