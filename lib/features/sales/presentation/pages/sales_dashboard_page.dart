import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:kd_pannel/app_theme.dart';
import 'package:kd_pannel/core/responsive/responsive.dart';
import 'package:kd_pannel/features/shared/widgets/advanced_stat_card_widget.dart';
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
import 'package:kd_pannel/util/dealers.dart';
import 'package:kd_pannel/core/auth/auth_service.dart';
import 'package:kd_pannel/core/network/websocket_service.dart';

class SalesDashboardPage extends StatefulWidget {
  const SalesDashboardPage({super.key});

  @override
  State<SalesDashboardPage> createState() => _SalesDashboardPageState();
}

class _SalesDashboardPageState extends State<SalesDashboardPage> {
  final AuthService _auth = AuthService();
  StreamSubscription? _leadsSubscription;
  StreamSubscription? _dealersSubscription;
  StreamSubscription? _ordersSubscription;

  int _activeTerminalTab = 0; // 0: Orders, 1: Leads, 2: Dealers
  String _terminalSearch = '';
  String _statusFilter = 'All';
  final TextEditingController _terminalSearchController = TextEditingController();

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
    DateTime? lastLeadsFetch;
    _leadsSubscription = WebSocketService().leadsUpdates.listen((_) {
      if (mounted) {
        final now = DateTime.now();
        if (lastLeadsFetch == null || now.difference(lastLeadsFetch!) > const Duration(seconds: 5)) {
          lastLeadsFetch = now;
          context.read<LeadsBloc>().add(const FetchLeadsDataEvent(forceRefresh: true));
        }
      }
    });
    DateTime? lastDealersFetch;
    _dealersSubscription = WebSocketService().dealersUpdates.listen((_) {
      if (mounted) {
        final now = DateTime.now();
        if (lastDealersFetch == null || now.difference(lastDealersFetch!) > const Duration(seconds: 5)) {
          lastDealersFetch = now;
          context.read<DealersBloc>().add(const FetchDealersDataEvent(forceRefresh: true));
        }
      }
    });
    DateTime? lastOrdersFetch;
    _ordersSubscription = WebSocketService().ordersUpdates.listen((_) {
      if (mounted) {
        final now = DateTime.now();
        if (lastOrdersFetch == null || now.difference(lastOrdersFetch!) > const Duration(seconds: 5)) {
          lastOrdersFetch = now;
          context.read<OrdersBloc>().add(const FetchOrdersEvent(forceRefresh: true));
        }
      }
    });
  }

  @override
  void dispose() {
    _leadsSubscription?.cancel();
    _dealersSubscription?.cancel();
    _ordersSubscription?.cancel();
    _terminalSearchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _getFilteredLeads(List<Map<String, dynamic>> rawUsers) {
    var filtered = rawUsers.where((u) {
      final role = u['role'] ?? 'user';
      final kycStatus = u['kycStatus'] ?? 'pending';
      return role == 'user' && kycStatus != 'verified';
    });

    if (_statusFilter != 'All') {
      filtered = filtered.where((u) {
        final status = (u['kycStatus'] ?? u['status'] ?? u['leadStatus'] ?? 'pending').toString().toLowerCase();
        return status == _statusFilter.toLowerCase();
      });
    }

    if (_terminalSearch.isNotEmpty) {
      final query = _terminalSearch.toLowerCase();
      filtered = filtered.where((u) {
        final name = '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'.toLowerCase();
        final phone = u['phoneNumber']?.toString().toLowerCase() ?? '';
        final city = u['address']?['cityTehsil'] ?? '';
        final shop = u['shopName']?.toString().toLowerCase() ?? '';
        return name.contains(query) || phone.contains(query) || city.toLowerCase().contains(query) || shop.contains(query);
      });
    }

    return filtered.map((u) {
      return {
        'id': u['_id'],
        'name': (u['firstName'] != null && u['firstName'].toString().trim().isNotEmpty)
            ? '${u['firstName']} ${u['lastName'] ?? ''}'.trim()
            : (u['phoneNumber'] ?? 'Unnamed Lead'),
        'phone': u['phoneNumber'] ?? '-',
        'city': u['address']?['cityTehsil'] ?? '-',
        'source': u['source'] ?? 'App',
        'status': u['kycStatus'] ?? 'pending',
        '_raw': u,
        'type': 'lead',
      };
    }).toList();
  }

  List<Map<String, dynamic>> _getFilteredDealers(List<Map<String, dynamic>> rawUsers) {
    var filtered = rawUsers.where((u) {
      final role = u['role'] ?? 'user';
      final kycStatus = u['kycStatus'] ?? 'pending';
      return role == 'user' && kycStatus == 'verified';
    });

    if (_statusFilter != 'All') {
      filtered = filtered.where((u) {
        final isBlocked = u['isBlocked'] == true;
        if (_statusFilter == 'Blocked') return isBlocked;
        if (_statusFilter == 'Active') return !isBlocked;
        return true;
      });
    }

    if (_terminalSearch.isNotEmpty) {
      final query = _terminalSearch.toLowerCase();
      filtered = filtered.where((u) {
        final shop = u['shopName']?.toString().toLowerCase() ?? '';
        final name = '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'.toLowerCase();
        final phone = u['phoneNumber']?.toString().toLowerCase() ?? '';
        final city = u['address']?['cityTehsil'] ?? '';
        return shop.contains(query) || name.contains(query) || phone.contains(query) || city.toLowerCase().contains(query);
      });
    }

    return filtered.map((u) {
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
        'status': u['isBlocked'] == true ? 'Blocked' : 'Verified',
        '_raw': u,
        'type': 'dealer',
      };
    }).toList();
  }

  List<OrderModel> _getFilteredOrders(List<OrderModel> allOrders) {
    Iterable<OrderModel> filtered = allOrders;

    if (_statusFilter != 'All') {
      filtered = filtered.where((o) => o.orderStatus.toLowerCase() == _statusFilter.toLowerCase());
    }

    if (_terminalSearch.isNotEmpty) {
      final query = _terminalSearch.toLowerCase();
      filtered = filtered.where((o) {
        return o.orderId.toLowerCase().contains(query) ||
            o.customerName.toLowerCase().contains(query) ||
            o.customerPhone.contains(query);
      });
    }

    return filtered.toList();
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
                final leads = _getFilteredLeads(leadsState.allRawUsers);
                final dealers = _getFilteredDealers(dealersState.allRawUsers);
                final orders = _getFilteredOrders(ordersState.orders);

                final bool isLoading = leadsState.status == LeadsStatus.loading ||
                    dealersState.status == DealersStatus.loading ||
                    ordersState.status == OrdersStatus.loading;

                return SingleChildScrollView(
                  padding: AppTheme.getResponsivePadding(context),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // High Impact Hero Header - Full Width & Compact
                      _AgentProfileHero(
                        ordersCount: orders.length,
                        isLoading: isLoading,
                      ),
                      
                      SizedBox(height: gap * 2),

                      // Sales Stats Grid - No Revenue
                      _SalesStatsGrid(
                        leadsCount: leads.length,
                        dealersCount: dealers.length,
                        ordersCount: orders.length,
                      ),
                      SizedBox(height: gap * 2),

                      // Operations Terminal
                      _buildOperationsTerminal(
                        context,
                        isDesktop,
                        orders,
                        leads,
                        dealers,
                      ),
                      const SizedBox(height: 40),
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

  Widget _buildOperationsTerminal(
    BuildContext context,
    bool isDesktop,
    List<OrderModel> orders,
    List<Map<String, dynamic>> leads,
    List<Map<String, dynamic>> dealers,
  ) {
    final bool isMobile = Responsive.isMobile(context);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusXLarge),
        boxShadow: AppTheme.cardShadow,
        border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Terminal Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: isMobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTerminalTitle(),
                      const SizedBox(height: 16),
                      _buildTerminalSearchField(isMobile),
                      const SizedBox(height: 12),
                      _buildTerminalStatusFilter(isMobile),
                      const SizedBox(height: 12),
                      _buildViewAllButton(context),
                    ],
                  )
                : Row(
                    children: [
                      _buildTerminalTitle(),
                      const Spacer(),
                      _buildTerminalSearchField(isMobile),
                      const SizedBox(width: 12),
                      _buildTerminalStatusFilter(isMobile),
                      const SizedBox(width: 12),
                      _buildViewAllButton(context),
                    ],
                  ),
          ),

          // Tabs Row
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _buildTab(0, 'Orders', Icons.shopping_bag_outlined, orders.length, AppTheme.primaryColor),
                  const SizedBox(width: 10),
                  _buildTab(1, 'Leads', Icons.person_add_outlined, leads.length, AppTheme.info),
                  const SizedBox(width: 10),
                  _buildTab(2, 'Dealers', Icons.storefront_outlined, dealers.length, AppTheme.accentColor),
                ],
              ),
            ),
          ),

          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Divider(height: 1, color: AppTheme.lightBorderColor),
          ),

          // Table Content
          _buildActiveTable(orders, leads, dealers),

          // Footer Metrics
          _buildTerminalFooter(orders, leads, dealers),
        ],
      ),
    );
  }

  Widget _buildTerminalTitle() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.analytics_outlined, color: AppTheme.primaryColor, size: 20),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Operations Terminal',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            _buildLiveBadge(),
          ],
        ),
      ],
    );
  }

  Widget _buildTerminalSearchField(bool isMobile) {
    return Container(
      height: 40,
      width: isMobile ? double.infinity : 280,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, size: 18, color: AppTheme.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _terminalSearchController,
              onChanged: (v) => setState(() => _terminalSearch = v),
              style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: _activeTerminalTab == 0 ? 'Search Order ID...' : 'Search Name/Phone...',
                hintStyle: GoogleFonts.outfit(fontSize: 13, color: AppTheme.textSecondary),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (_terminalSearch.isNotEmpty)
            GestureDetector(
              onTap: () {
                _terminalSearchController.clear();
                setState(() => _terminalSearch = '');
              },
              child: const Icon(Icons.close_rounded, size: 16, color: AppTheme.textSecondary),
            ),
        ],
      ),
    );
  }

  Widget _buildViewAllButton(BuildContext context) {
    return TextButton(
      onPressed: () {
        final route = _activeTerminalTab == 0 ? '/orders' : (_activeTerminalTab == 1 ? '/leads' : '/dealers');
        Navigator.pushReplacementNamed(context, route);
      },
      style: TextButton.styleFrom(
        foregroundColor: AppTheme.primaryColor,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 13),
      ),
      child: const Row(
        children: [
          Text('View Full List'),
          SizedBox(width: 6),
          Icon(Icons.arrow_forward_rounded, size: 15),
        ],
      ),
    );
  }

  Widget _buildTerminalStatusFilter(bool isMobile) {
    List<String> options = ['All'];
    if (_activeTerminalTab == 0) {
      options.addAll(['Pending', 'Processing', 'Shipped', 'Out for Delivery', 'Delivered', 'Cancelled', 'RTO']);
    } else if (_activeTerminalTab == 1) {
      options.addAll(['Pending', 'Interested', 'Follow-up', 'Quotation Sent', 'Negotiation', 'Lost']);
    } else {
      options.addAll(['Active', 'Blocked']);
    }

    return Container(
      height: 40,
      width: isMobile ? double.infinity : 160,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _statusFilter,
          isExpanded: true,
          icon: const Icon(Icons.filter_list_rounded, size: 18, color: AppTheme.textSecondary),
          style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
          onChanged: (v) => setState(() => _statusFilter = v!),
          items: options.map((o) => DropdownMenuItem(
            value: o,
            child: Text(o),
          )).toList(),
        ),
      ),
    );
  }

  Widget _buildTab(int index, String label, IconData icon, int count, Color color) {
    final isSelected = _activeTerminalTab == index;
    return GestureDetector(
      onTap: () => setState(() {
        _activeTerminalTab = index;
        _statusFilter = 'All'; // Reset filter on tab change
        _terminalSearch = '';
        _terminalSearchController.clear();
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? color.withValues(alpha: 0.4) : AppTheme.borderColor),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: isSelected ? color : AppTheme.textSecondary),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? color : AppTheme.textSecondary,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? color.withValues(alpha: 0.25) : AppTheme.backgroundColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? color : AppTheme.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveTable(List<OrderModel> orders, List<Map<String, dynamic>> leads, List<Map<String, dynamic>> dealers) {
    if (_activeTerminalTab == 0) {
      return _buildTable(
        columns: const ['Order ID', 'Customer', 'Amount', 'Status'],
        data: orders.take(10).map((o) => {
          'cell1': o.orderId,
          'cell2': o.customerName,
          'cell3': '₹${o.totalAmount.toStringAsFixed(0)}',
          'cell4': o.orderStatus,
          '_raw': o,
          'type': 'order'
        }).toList(),
        emptyText: 'No matching orders found',
      );
    } else if (_activeTerminalTab == 1) {
      return _buildTable(
        columns: const ['Lead Name', 'Phone', 'City', 'Source', 'Status'],
        data: leads.take(10).map((l) => {
          'cell1': l['name'] as String,
          'cell2': l['phone'] as String,
          'cell3': l['city'] as String,
          'cell4': l['source'] as String,
          'cell5': l['status'] as String,
          '_raw': l['_raw'],
          'type': 'lead'
        }).toList(),
        emptyText: 'No matching leads found',
      );
    } else {
      // Calculate order counts for dealers
      final Map<String, int> orderCounts = {};
      for (var o in orders) {
        if (o.userId != null) {
          orderCounts[o.userId!] = (orderCounts[o.userId!] ?? 0) + 1;
        }
      }

      return _buildTable(
        columns: const ['Dealer Name', 'Phone', 'City', 'Orders', 'Status'],
        data: dealers.take(10).map((d) {
          final userId = d['id'];
          final count = orderCounts[userId] ?? 0;
          return {
            'cell1': d['name'] as String,
            'cell2': d['phone'] as String,
            'cell3': d['city'] as String,
            'cell4': '$count',
            'cell5': d['status'] ?? 'Verified',
            '_raw': d['_raw'],
            'type': 'dealer'
          };
        }).toList(),
        emptyText: 'No matching dealers found',
      );
    }
  }

  Widget _buildTable({
    required List<String> columns,
    required List<Map<String, dynamic>> data,
    required String emptyText,
  }) {
    if (data.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.layers_clear_outlined, size: 48, color: AppTheme.textSecondary.withValues(alpha: 0.2)),
              const SizedBox(height: 16),
              Text(
                emptyText,
                style: GoogleFonts.outfit(color: AppTheme.textSecondary, fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Row(
            children: columns.map((c) => Expanded(
              child: Text(c.toUpperCase(), style: AppTheme.tableHeader),
            )).toList(),
          ),
        ),
        const Divider(height: 1, color: AppTheme.lightBorderColor),
        ...data.asMap().entries.map((entry) => _InteractiveRow(
          index: entry.key,
          data: entry.value,
        )).toList(),
      ],
    );
  }

  Widget _buildTerminalFooter(List<OrderModel> orders, List<Map<String, dynamic>> leads, List<Map<String, dynamic>> dealers) {
    List<Map<String, dynamic>> metrics = [];
    if (_activeTerminalTab == 0) {
      metrics = [
        {'label': 'Total Orders', 'value': '${orders.length}', 'icon': Icons.shopping_bag_outlined, 'color': AppTheme.primaryColor},
        {'label': 'Pending Action', 'value': '${orders.where((o) => o.orderStatus.toLowerCase() == 'pending').length}', 'icon': Icons.hourglass_top_rounded, 'color': AppTheme.warning},
      ];
    } else if (_activeTerminalTab == 1) {
      metrics = [
        {'label': 'Total Leads', 'value': '${leads.length}', 'icon': Icons.person_add_outlined, 'color': AppTheme.info},
        {'label': 'KYC Pending', 'value': '${leads.where((l) => l['status'] == 'pending').length}', 'icon': Icons.hourglass_bottom_rounded, 'color': AppTheme.warning},
      ];
    } else {
      metrics = [
        {'label': 'Total Dealers', 'value': '${dealers.length}', 'icon': Icons.storefront_outlined, 'color': AppTheme.accentColor},
        {'label': 'Active Accounts', 'value': '${dealers.length}', 'icon': Icons.verified_user_outlined, 'color': AppTheme.success},
      ];
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor.withValues(alpha: 0.4),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(AppTheme.borderRadiusXLarge)),
      ),
      child: Wrap(
        spacing: 24,
        runSpacing: 10,
        alignment: WrapAlignment.center,
        children: metrics.map((m) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(m['icon'] as IconData, size: 14, color: (m['color'] as Color).withValues(alpha: 0.8)),
            const SizedBox(width: 8),
            Text(
              '${m['label']}: ',
              style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
            ),
            Text(
              m['value'] as String,
              style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textPrimary, fontWeight: FontWeight.w800),
            ),
          ],
        )).toList(),
      ),
    );
  }

  Widget _buildLiveBadge() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: AppTheme.success,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          'LIVE TELEMETRY ACTIVE',
          style: GoogleFonts.outfit(
            fontSize: 9,
            fontWeight: FontWeight.w900,
            color: AppTheme.success,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}

class _AgentProfileHero extends StatefulWidget {
  final int ordersCount;
  final bool isLoading;

  const _AgentProfileHero({
    required this.ordersCount,
    required this.isLoading,
  });

  @override
  State<_AgentProfileHero> createState() => _AgentProfileHeroState();
}

class _AgentProfileHeroState extends State<_AgentProfileHero> {
  late Timer _timer;
  late DateTime _currentTime;

  @override
  void initState() {
    super.initState();
    _currentTime = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _getTimeBasedGreeting() {
    final hour = _currentTime.hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    final AuthService auth = AuthService();
    final String name = auth.currentUserName ?? 'Sales Agent';
    final String email = auth.currentUserEmail ?? '-';
    final String initials = name.isNotEmpty
        ? name.split(' ').map((e) => e[0]).take(2).join().toUpperCase()
        : 'SA';
    
    final greeting = _getTimeBasedGreeting();
    final bool isMobile = Responsive.isMobile(context);
    
    final dateStr = DateFormat('EEEE, MMMM d, y').format(_currentTime);
    final timeStr = DateFormat('hh:mm:ss a').format(_currentTime);

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor,
            const Color(0xFF0D3E12),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusXLarge),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.25),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background Decorative Elements - Large circles bleeding out
          Positioned(
            right: -80,
            top: -80,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            left: -60,
            bottom: -60,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.02),
                shape: BoxShape.circle,
              ),
            ),
          ),
          
          // Main Content
          Padding(
            padding: EdgeInsets.all(isMobile ? 16 : 24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Avatar
                Container(
                  width: isMobile ? 52 : 64,
                  height: isMobile ? 52 : 64,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 2),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initials,
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: isMobile ? 18 : 22,
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                
                // Greeting & Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$greeting, $name',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: isMobile ? 20 : 24,
                          letterSpacing: -0.5,
                          height: 1.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.accentColor.withValues(alpha: 0.95),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'OFFICIAL SALES',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          if (!isMobile)
                            Expanded(
                              child: Text(
                                email,
                                style: GoogleFonts.outfit(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(width: 20),
                
                // Clock Section
                if (!isMobile) ...[
                  const SizedBox(width: 32),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        timeStr,
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 26,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dateStr,
                        style: GoogleFonts.outfit(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}


class _InteractiveRow extends StatefulWidget {
  final int index;
  final Map<String, dynamic> data;

  const _InteractiveRow({required this.index, required this.data});

  @override
  State<_InteractiveRow> createState() => _InteractiveRowState();
}

class _InteractiveRowState extends State<_InteractiveRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isEven = widget.index % 2 == 0;
    final row = widget.data;
    final type = row['type'] as String;
    final raw = row['_raw'];

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () {
          if (type == 'lead') {
            final rawLead = raw as Map<String, dynamic>;
            // Construct a comprehensive map for the profile page
            final leadMap = {
              ...rawLead,
              'id': rawLead['_id'],
              'name': '${rawLead['firstName'] ?? ''} ${rawLead['lastName'] ?? ''}'.trim().isNotEmpty 
                  ? '${rawLead['firstName'] ?? ''} ${rawLead['lastName'] ?? ''}'.trim()
                  : (rawLead['phoneNumber'] ?? 'Unnamed Lead'),
              'phone': rawLead['phoneNumber'] ?? '',
              'kycStatus': rawLead['kycStatus'] ?? 'pending',
              'status': rawLead['status'] ?? rawLead['leadStatus'] ?? 'prospect',
              'agent': AuthService().currentUserName,
              'agentId': AuthService().currentUserId,
            };
            Navigator.pushNamed(context, '/leads/profile', arguments: leadMap);
          } else if (type == 'dealer') {
            final rawDealer = raw as Map<String, dynamic>;
            final dealer = Dealer.fromMap({
              ...rawDealer,
              'id': rawDealer['_id'],
              'name': '${rawDealer['firstName'] ?? ''} ${rawDealer['lastName'] ?? ''}'.trim().isNotEmpty 
                  ? '${rawDealer['firstName'] ?? ''} ${rawDealer['lastName'] ?? ''}'.trim()
                  : (rawDealer['phoneNumber'] ?? 'Unnamed Dealer'),
              'agent': AuthService().currentUserName ?? '-',
              'agentId': AuthService().currentUserId,
              'totalOrders': 0, // Placeholder
              'purchaseValue': '₹0', // Placeholder
              'gstStatus': 'Verified',
            });
            Navigator.pushNamed(context, '/dealers/profile', arguments: dealer);
          } else if (type == 'order') {
            Navigator.pushNamed(context, '/orders/details', arguments: raw as OrderModel);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: _isHovered
                ? AppTheme.primaryColor.withValues(alpha: 0.04)
                : (isEven ? Colors.transparent : AppTheme.backgroundColor.withValues(alpha: 0.3)),
            border: const Border(bottom: BorderSide(color: AppTheme.lightBorderColor)),
          ),
          child: Row(
            children: [
              Expanded(child: _buildCell(row['cell1'])),
              Expanded(child: _buildCell(row['cell2'])),
              Expanded(child: _buildCell(row['cell3'])),
              if (row.containsKey('cell4') && !row.containsKey('cell5'))
                 Expanded(child: _buildStatusCell(row['cell4'], type)),
              if (row.containsKey('cell5')) ...[
                 Expanded(child: _buildCell(row['cell4'])),
                 Expanded(child: _buildStatusCell(row['cell5'], type)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCell(String text) {
    return Text(
      text,
      style: GoogleFonts.outfit(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppTheme.textPrimary,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildStatusCell(String status, String type) {
    Color color = AppTheme.primaryColor;
    final s = status.toLowerCase();
    if (s.contains('delivered') || s.contains('verified') || s.contains('success')) {
      color = AppTheme.success;
    } else if (s.contains('pending') || s.contains('processing') || s.contains('prospect')) {
      color = AppTheme.warning;
    } else if (s.contains('cancelled') || s.contains('lost') || s.contains('failed')) {
      color = AppTheme.error;
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Text(
          status.toUpperCase(),
          style: GoogleFonts.outfit(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: color,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

class _QuickActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Text(
              label,
              style: GoogleFonts.outfit(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
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
        final double spacing = 16.0;
        int columns = 1;
        if (constraints.maxWidth >= 1100) {
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
            AdvancedStatCardWidget(
              width: width,
              title: 'Active Orders',
              value: '$ordersCount',
              color: AppTheme.accentColor,
              trendLabel: 'Assigned to you',
              trendIcon: Icons.shopping_bag_outlined,
              visualWidget: SizedBox(
                width: 28,
                height: 28,
                child: CustomPaint(
                  painter: FulfillmentProgressPainter(0.75, AppTheme.accentColor),
                ),
              ),
            ),
            AdvancedStatCardWidget(
              width: width,
              title: 'Qualified Leads',
              value: '$leadsCount',
              color: AppTheme.info,
              trendLabel: 'Prospect pipeline',
              trendIcon: Icons.person_add_outlined,
              visualWidget: SizedBox(
                width: 50,
                height: 24,
                child: CustomPaint(
                  painter: SparklinePainter([20, 18, 25, 22, 30, 28, 35], AppTheme.info),
                ),
              ),
            ),
            AdvancedStatCardWidget(
              width: width,
              title: 'Your Dealers',
              value: '$dealersCount',
              color: AppTheme.primaryColor,
              trendLabel: 'Verified accounts',
              trendIcon: Icons.verified_user_outlined,
              visualWidget: _buildAvatarCluster(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAvatarCluster() {
    return SizedBox(
      width: 72,
      height: 24,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          _buildAvatarCircle('AD', AppTheme.primaryColor, 0),
          _buildAvatarCircle('PK', AppTheme.accentColor, 15),
          _buildAvatarCircle('RK', AppTheme.info, 30),
        ],
      ),
    );
  }

  Widget _buildAvatarCircle(String text, Color color, double left) {
    return Positioned(
      left: left,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.5),
          color: color.withValues(alpha: 0.1),
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: GoogleFonts.outfit(
            fontSize: 8,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ),
    );
  }
}

class SparklinePainter extends CustomPainter {
  final List<double> data;
  final Color color;

  SparklinePainter(this.data, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final double stepX = size.width / (data.length - 1);
    final double minVal = data.reduce((a, b) => a < b ? a : b);
    final double maxVal = data.reduce((a, b) => a > b ? a : b);
    final double range = maxVal - minVal == 0 ? 1.0 : maxVal - minVal;

    final points = <Offset>[];
    for (int i = 0; i < data.length; i++) {
      final double x = i * stepX;
      final double y = size.height - ((data[i] - minVal) / range) * size.height;
      points.add(Offset(x, y));
    }

    if (points.isNotEmpty) {
      path.moveTo(points[0].dx, points[0].dy);
      for (int i = 0; i < points.length - 1; i++) {
        final p0 = points[i];
        final p1 = points[i + 1];
        final controlX = p0.dx + (p1.dx - p0.dx) / 2;
        path.cubicTo(controlX, p0.dy, controlX, p1.dy, p1.dx, p1.dy);
      }
    }

    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.18), color.withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant SparklinePainter oldDelegate) => false;
}

class FulfillmentProgressPainter extends CustomPainter {
  final double percent;
  final Color color;

  FulfillmentProgressPainter(this.percent, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final double strokeWidth = 3.5;
    final double radius = (size.width - strokeWidth) / 2;
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..color = color.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    final arcPaint = Paint()
      ..color = color.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, -1.5708, 6.2831 * percent, false, arcPaint);
  }

  @override
  bool shouldRepaint(covariant FulfillmentProgressPainter oldDelegate) => false;
}
