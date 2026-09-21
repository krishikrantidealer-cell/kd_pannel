import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kd_pannel/app_theme.dart';
import 'package:kd_pannel/core/utils/currency_utils.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/dealers_bloc.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/leads_state.dart';
import 'package:kd_pannel/features/admin/presentation/widgets/team/team_shared_widgets.dart';

class TeamLeadConversionsTabView extends StatefulWidget {
  final LeadsState state;
  final bool isDesktop;
  final bool isMobile;
  final List<Map<String, dynamic>> deletedUsersList;

  const TeamLeadConversionsTabView({
    super.key,
    required this.state,
    required this.isDesktop,
    required this.isMobile,
    required this.deletedUsersList,
  });

  @override
  State<TeamLeadConversionsTabView> createState() =>
      _TeamLeadConversionsTabViewState();
}

class _TeamLeadConversionsTabViewState
    extends State<TeamLeadConversionsTabView> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  DateTimeRange? _conversionDateRange;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _isWithinDateRange(dynamic dateVal) {
    if (_conversionDateRange == null) return true;
    if (dateVal == null) return false;

    DateTime? dt;
    if (dateVal is DateTime) {
      dt = dateVal;
    } else if (dateVal is String) {
      dt = DateTime.tryParse(dateVal);
    } else if (dateVal is int) {
      dt = DateTime.fromMillisecondsSinceEpoch(dateVal);
    } else if (dateVal is Map) {
      final d = dateVal['\$date'] ?? dateVal['date'];
      if (d is String) {
        dt = DateTime.tryParse(d);
      } else if (d is int) {
        dt = DateTime.fromMillisecondsSinceEpoch(d);
      } else if (d is Map && d['\$numberLong'] != null) {
        final ms = int.tryParse(d['\$numberLong'].toString());
        if (ms != null) dt = DateTime.fromMillisecondsSinceEpoch(ms);
      }
    }

    if (dt == null) return false;

    final localDt = dt.toLocal();
    final start = DateTime(
      _conversionDateRange!.start.year,
      _conversionDateRange!.start.month,
      _conversionDateRange!.start.day,
      0,
      0,
      0,
      0,
    );
    final end = DateTime(
      _conversionDateRange!.end.year,
      _conversionDateRange!.end.month,
      _conversionDateRange!.end.day,
      23,
      59,
      59,
      999,
    );

    return !localDt.isBefore(start) && !localDt.isAfter(end);
  }

  Widget _buildDateFilterRow() {
    String selectedPreset = 'All Time';
    if (_conversionDateRange != null) {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final start = DateTime(
        _conversionDateRange!.start.year,
        _conversionDateRange!.start.month,
        _conversionDateRange!.start.day,
      );
      final end = DateTime(
        _conversionDateRange!.end.year,
        _conversionDateRange!.end.month,
        _conversionDateRange!.end.day,
      );
      final diffDays = end.difference(start).inDays;

      if (start == todayStart && end == todayStart) {
        selectedPreset = 'Today';
      } else if (end == todayStart && (diffDays == 6 || diffDays == 7)) {
        selectedPreset = 'Last 7 Days';
      } else if (end == todayStart &&
          (diffDays == 29 || diffDays == 30 || diffDays == 31)) {
        selectedPreset = 'Last 30 Days';
      } else {
        selectedPreset = 'Custom';
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.calendar_today_rounded,
            size: 16,
            color: AppTheme.primaryColor,
          ),
          const SizedBox(width: 8),
          Text(
            'Timeframe: ',
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildDateFilterPill(
                  'All Time',
                  selectedPreset == 'All Time',
                  () {
                    setState(() => _conversionDateRange = null);
                  },
                ),
                _buildDateFilterPill(
                  'Today',
                  selectedPreset == 'Today',
                  () {
                    final now = DateTime.now();
                    setState(
                      () => _conversionDateRange = DateTimeRange(
                        start: DateTime(now.year, now.month, now.day),
                        end: DateTime(now.year, now.month, now.day),
                      ),
                    );
                  },
                ),
                _buildDateFilterPill(
                  'Last 7 Days',
                  selectedPreset == 'Last 7 Days',
                  () {
                    final now = DateTime.now();
                    setState(
                      () => _conversionDateRange = DateTimeRange(
                        start: DateTime(
                          now.year,
                          now.month,
                          now.day,
                        ).subtract(const Duration(days: 6)),
                        end: DateTime(now.year, now.month, now.day),
                      ),
                    );
                  },
                ),
                _buildDateFilterPill(
                  'Last 30 Days',
                  selectedPreset == 'Last 30 Days',
                  () {
                    final now = DateTime.now();
                    setState(
                      () => _conversionDateRange = DateTimeRange(
                        start: DateTime(
                          now.year,
                          now.month,
                          now.day,
                        ).subtract(const Duration(days: 29)),
                        end: DateTime(now.year, now.month, now.day),
                      ),
                    );
                  },
                ),
                _buildDateFilterPill(
                  _conversionDateRange != null && selectedPreset == 'Custom'
                      ? '${_conversionDateRange!.start.day}/${_conversionDateRange!.start.month} - ${_conversionDateRange!.end.day}/${_conversionDateRange!.end.month}'
                      : 'Custom Range 📅',
                  selectedPreset == 'Custom',
                  () async {
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      initialDateRange: _conversionDateRange ??
                          DateTimeRange(
                            start: DateTime.now().subtract(
                              const Duration(days: 29),
                            ),
                            end: DateTime.now(),
                          ),
                    );
                    if (picked != null) {
                      setState(() => _conversionDateRange = picked);
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateFilterPill(
    String label,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color:
                isSelected ? AppTheme.primaryColor : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  void _showAgentBreakdownModal(
    BuildContext context, {
    required Map<String, dynamic> agent,
    required String name,
    required List<Map<String, dynamic>> convertedDealers,
    required List<Map<String, dynamic>> activeLeads,
    required List<Map<String, dynamic>> deletedLeads,
    required List<Map<String, dynamic>> agentOrders,
    required Map<String, double> dealerSalesAmountMap,
    required Map<String, int> dealerOrdersCountMap,
    required double totalSalesAmount,
    required double conversionRate,
    required int dealersWithOrdersCount,
    required int totalDealerOrders,
    required bool isTimeframeFiltered,
    required int? timeframeConversionsCount,
  }) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return _AgentBreakdownDialog(
          agent: agent,
          name: name,
          convertedDealers: convertedDealers,
          activeLeads: activeLeads,
          deletedLeads: deletedLeads,
          agentOrders: agentOrders,
          dealerSalesAmountMap: dealerSalesAmountMap,
          dealerOrdersCountMap: dealerOrdersCountMap,
          totalSalesAmount: totalSalesAmount,
          conversionRate: conversionRate,
          dealersWithOrdersCount: dealersWithOrdersCount,
          totalDealerOrders: totalDealerOrders,
          isTimeframeFiltered: isTimeframeFiltered,
          timeframeConversionsCount: timeframeConversionsCount,
        );
      },
    );
  }

  Widget _buildAgentConversionCard(
    BuildContext context, {
    required Map<String, dynamic> agent,
    required String name,
    required List<Map<String, dynamic>> convertedDealers,
    required List<Map<String, dynamic>> activeLeads,
    required List<Map<String, dynamic>> deletedLeads,
    required List<Map<String, dynamic>> agentOrders,
    required int totalAssigned,
    required double conversionRate,
    required int dealersWithOrdersCount,
    required int totalDealerOrders,
    required double totalSalesAmount,
    required Map<String, double> dealerSalesAmountMap,
    required Map<String, int> dealerOrdersCountMap,
    required double ordersPerDealer,
    required double dealerOrderActivationRate,
    int? timeframeConversionsCount,
    bool isTimeframeFiltered = false,
  }) {
    Color rateBadgeColor;
    Color rateBgColor;
    if (conversionRate >= 25.0) {
      rateBadgeColor = const Color(0xFF10B981);
      rateBgColor = const Color(0xFFECFDF5);
    } else if (conversionRate >= 10.0) {
      rateBadgeColor = const Color(0xFFF59E0B);
      rateBgColor = const Color(0xFFFFFBEB);
    } else {
      rateBadgeColor = const Color(0xFF64748B);
      rateBgColor = const Color(0xFFF8FAFC);
    }

    final email = agent['email'] ?? 'No email';
    final phone = agent['phoneNumber'] ?? 'No phone';
    final double avgOrderValue = totalDealerOrders > 0
        ? totalSalesAmount / totalDealerOrders
        : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            _showAgentBreakdownModal(
              context,
              agent: agent,
              name: name,
              convertedDealers: convertedDealers,
              activeLeads: activeLeads,
              deletedLeads: deletedLeads,
              agentOrders: agentOrders,
              dealerSalesAmountMap: dealerSalesAmountMap,
              dealerOrdersCountMap: dealerOrdersCountMap,
              totalSalesAmount: totalSalesAmount,
              conversionRate: conversionRate,
              dealersWithOrdersCount: dealersWithOrdersCount,
              totalDealerOrders: totalDealerOrders,
              isTimeframeFiltered: isTimeframeFiltered,
              timeframeConversionsCount: timeframeConversionsCount,
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      backgroundColor:
                          AppTheme.primaryColor.withValues(alpha: 0.12),
                      radius: 22,
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : 'S',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  name,
                                  style: GoogleFonts.outfit(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: const Color(0xFFBFDBFE),
                                  ),
                                ),
                                child: Text(
                                  'Sales Agent',
                                  style: GoogleFonts.outfit(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF1D4ED8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$email • $phone',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Action button
                    OutlinedButton.icon(
                      onPressed: () {
                        _showAgentBreakdownModal(
                          context,
                          agent: agent,
                          name: name,
                          convertedDealers: convertedDealers,
                          activeLeads: activeLeads,
                          deletedLeads: deletedLeads,
                          agentOrders: agentOrders,
                          dealerSalesAmountMap: dealerSalesAmountMap,
                          dealerOrdersCountMap: dealerOrdersCountMap,
                          totalSalesAmount: totalSalesAmount,
                          conversionRate: conversionRate,
                          dealersWithOrdersCount: dealersWithOrdersCount,
                          totalDealerOrders: totalDealerOrders,
                          isTimeframeFiltered: isTimeframeFiltered,
                          timeframeConversionsCount: timeframeConversionsCount,
                        );
                      },
                      icon: const Icon(Icons.tune_rounded, size: 14),
                      label: Text(
                        'View Breakdown',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryColor,
                        side: const BorderSide(color: AppTheme.borderColor),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // 3 Clean Sections Grid
                LayoutBuilder(
                  builder: (context, constraints) {
                    final bool isCompact = constraints.maxWidth < 700;
                    if (isCompact) {
                      return Column(
                        children: [
                          _buildSalesSection(
                            totalSalesAmount,
                            totalDealerOrders,
                            avgOrderValue,
                          ),
                          const SizedBox(height: 10),
                          _buildConversionFunnelSection(
                            conversionRate,
                            convertedDealers.length,
                            activeLeads.length,
                            deletedLeads.length,
                            rateBadgeColor,
                            rateBgColor,
                            isTimeframeFiltered,
                            timeframeConversionsCount,
                          ),
                          const SizedBox(height: 10),
                          _buildActivationSection(
                            dealersWithOrdersCount,
                            convertedDealers.length,
                            dealerOrderActivationRate,
                            ordersPerDealer,
                          ),
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Section 1: Sales & Revenue
                        Expanded(
                          child: _buildSalesSection(
                            totalSalesAmount,
                            totalDealerOrders,
                            avgOrderValue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Section 2: Conversion Funnel
                        Expanded(
                          child: _buildConversionFunnelSection(
                            conversionRate,
                            convertedDealers.length,
                            activeLeads.length,
                            deletedLeads.length,
                            rateBadgeColor,
                            rateBgColor,
                            isTimeframeFiltered,
                            timeframeConversionsCount,
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Section 3: Dealer Activation
                        Expanded(
                          child: _buildActivationSection(
                            dealersWithOrdersCount,
                            convertedDealers.length,
                            dealerOrderActivationRate,
                            ordersPerDealer,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSalesSection(
    double totalSales,
    int totalOrders,
    double avgOrderValue,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDCFCE7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.payments_outlined,
                size: 15,
                color: Color(0xFF059669),
              ),
              const SizedBox(width: 6),
              Text(
                'SALES & REVENUE',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: const Color(0xFF059669),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            CurrencyUtils.formatInr(totalSales),
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF047857),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$totalOrders Orders',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF065F46),
                ),
              ),
              Text(
                'Avg ${CurrencyUtils.formatInr(avgOrderValue)}',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF065F46),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConversionFunnelSection(
    double conversionRate,
    int totalConverted,
    int activeLeads,
    int deletedLeads,
    Color rateBadgeColor,
    Color rateBgColor,
    bool isTimeframeFiltered,
    int? timeframeConversionsCount,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F9FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0F2FE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.filter_alt_outlined,
                    size: 15,
                    color: Color(0xFF0284C7),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'CONVERSION FUNNEL',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: const Color(0xFF0284C7),
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: rateBgColor,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: rateBadgeColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  '${conversionRate.toStringAsFixed(1)}% Conv.',
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: rateBadgeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isTimeframeFiltered
                ? '${timeframeConversionsCount ?? 0} Converted'
                : '$totalConverted Converted',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0369A1),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$activeLeads Active Leads',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF075985),
                ),
              ),
              Text(
                '$deletedLeads Deleted',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFE11D48),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActivationSection(
    int dealersWithOrders,
    int totalDealers,
    double activationRate,
    double ordersPerDealer,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF5FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF3E8FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.shopping_cart_checkout_rounded,
                    size: 15,
                    color: Color(0xFF7E22CE),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'DEALER ACTIVATION',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: const Color(0xFF7E22CE),
                    ),
                  ),
                ],
              ),
              Text(
                '${activationRate.toStringAsFixed(1)}% Active',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF7E22CE),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$dealersWithOrders of $totalDealers Ordered',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF6B21A8),
            ),
          ),
          const SizedBox(height: 8),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: totalDealers > 0 ? (dealersWithOrders / totalDealers) : 0,
              minHeight: 5,
              backgroundColor: const Color(0xFFE9D5FF),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF9333EA),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dealersState = context.watch<DealersBloc>().state;
    final allOrders = dealersState.allRawOrders;

    final allSalesAgents = widget.state.allRawUsers
        .where((u) => u['role'] == 'sales')
        .toList();

    final Set<String> salesAgentIds = allSalesAgents
        .map((a) => (a['_id'] ?? a['\$oid'] ?? a['id'])?.toString())
        .whereType<String>()
        .toSet();

    final filteredAgents = allSalesAgents.where((agent) {
      final name = '${agent['firstName'] ?? ''} ${agent['lastName'] ?? ''}'
          .toLowerCase();
      final email = (agent['email'] ?? '').toLowerCase();
      final phone = (agent['phoneNumber'] ?? '').toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query) ||
          email.contains(query) ||
          phone.contains(query);
    }).toList();

    final Map<String, List<Map<String, dynamic>>> allConvertedDealersMap = {};
    final Map<String, List<Map<String, dynamic>>> timeframeConvertedDealersMap =
        {};
    final Map<String, List<Map<String, dynamic>>> activeLeadsMap = {};
    final Map<String, List<Map<String, dynamic>>> deletedLeadsMap = {};
    final Map<String, List<Map<String, dynamic>>> agentOrdersMap = {};
    final Map<String, Set<String>> dealersWithOrdersMap = {};
    final Map<String, int> agentOrdersCountMap = {};
    final Map<String, double> agentSalesAmountMap = {};
    final Map<String, double> dealerSalesAmountMap = {};
    final Map<String, int> dealerOrdersCountMap = {};
    final Map<String, String> userToAgentMap = {};

    int totalTeamConversions = 0;
    int totalTeamDeletedLeads = 0;
    int totalTeamOrders = 0;
    double totalTeamSalesAmount = 0.0;

    final List<Map<String, dynamic>> combinedUsers = [
      ...dealersState.allRawUsers,
      ...widget.state.allRawUsers,
      ...widget.deletedUsersList,
    ];
    final Set<String> processedUserIds = {};

    for (final user in combinedUsers) {
      final uid = (user['_id'] ?? user['\$oid'] ?? user['id'])?.toString();
      if (uid == null || uid.isEmpty) continue;

      final agentIdObj = user['assignedAgent'];
      String? agentId;
      if (agentIdObj is Map) {
        agentId =
            (agentIdObj['_id'] ?? agentIdObj['\$oid'] ?? agentIdObj['id'])
                ?.toString();
      } else if (agentIdObj is String) {
        agentId = agentIdObj;
      }

      if (agentId != null && agentId.isNotEmpty) {
        userToAgentMap[uid] = agentId;
      }

      if (processedUserIds.contains(uid)) continue;
      processedUserIds.add(uid);

      final isDeleted = user['isDeleted'] == true ||
          user['status'] == 'deleted' ||
          user['trash'] == true;

      if (agentId != null && agentId.isNotEmpty) {
        if (isDeleted) {
          final deletedDate =
              user['deletedAt'] ?? user['updatedAt'] ?? user['createdAt'];
          if (_isWithinDateRange(deletedDate)) {
            deletedLeadsMap.putIfAbsent(agentId, () => []).add(user);
            totalTeamDeletedLeads++;
          }
        } else if (user['role'] == 'user') {
          final isVerified = user['kycStatus'] == 'verified';
          if (isVerified) {
            allConvertedDealersMap.putIfAbsent(agentId, () => []).add(user);
            final approvedDate =
                user['kycApprovedAt'] ?? user['updatedAt'] ?? user['createdAt'];
            if (_isWithinDateRange(approvedDate)) {
              timeframeConvertedDealersMap
                  .putIfAbsent(agentId, () => [])
                  .add(user);
              totalTeamConversions++;
            }
          } else {
            final assignedDate = user['assignedAt'] ?? user['createdAt'];
            if (_isWithinDateRange(assignedDate)) {
              activeLeadsMap.putIfAbsent(agentId, () => []).add(user);
            }
          }
        }
      }
    }

    for (final order in allOrders) {
      final status = (order['orderStatus'] ?? '').toString().toLowerCase();
      if (status == 'cancelled') continue;

      final orderDate = order['createdAt'] ?? order['orderDate'];
      if (!_isWithinDateRange(orderDate)) continue;

      final userObj = order['user'];
      String? userId;
      String? agentId;

      if (userObj is Map) {
        userId =
            (userObj['_id'] ?? userObj['\$oid'] ?? userObj['id'])?.toString();
        final agentInUser = userObj['assignedAgent'];
        if (agentInUser is Map) {
          agentId = (agentInUser['_id'] ??
                  agentInUser['\$oid'] ??
                  agentInUser['id'])
              ?.toString();
        } else if (agentInUser is String) {
          agentId = agentInUser;
        }
      } else if (userObj is String) {
        userId = userObj;
      }

      if (agentId == null && userId != null) {
        agentId = userToAgentMap[userId];
      }

      if (agentId == null && order['createdBy'] != null) {
        final createdBy = order['createdBy'];
        String? creatorId;
        if (createdBy is Map) {
          creatorId = (createdBy['_id'] ??
                  createdBy['\$oid'] ??
                  createdBy['id'])
              ?.toString();
        } else if (createdBy is String) {
          creatorId = createdBy;
        }
        if (creatorId != null && salesAgentIds.contains(creatorId)) {
          agentId = creatorId;
        }
      }

      if (agentId != null && agentId.isNotEmpty) {
        final double orderAmount = CurrencyUtils.parse(
          order['totalAmount'] ??
              order['grandTotal'] ??
              order['total'] ??
              order['payableAmount'] ??
              0,
        );

        agentOrdersMap.putIfAbsent(agentId, () => []).add(order);

        if (userId != null && userId.isNotEmpty) {
          dealersWithOrdersMap.putIfAbsent(agentId, () => {}).add(userId);
          dealerSalesAmountMap[userId] =
              (dealerSalesAmountMap[userId] ?? 0.0) + orderAmount;
          dealerOrdersCountMap[userId] =
              (dealerOrdersCountMap[userId] ?? 0) + 1;
        }

        agentOrdersCountMap[agentId] =
            (agentOrdersCountMap[agentId] ?? 0) + 1;
        agentSalesAmountMap[agentId] =
            (agentSalesAmountMap[agentId] ?? 0.0) + orderAmount;
        totalTeamOrders++;
        totalTeamSalesAmount += orderAmount;
      }
    }

    int totalDealersWithOrdersCount = dealersWithOrdersMap.values
        .fold<Set<String>>({}, (prev, set) => prev..addAll(set))
        .length;

    final bool isFiltered = _conversionDateRange != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top 5 Summary Cards
        if (widget.isDesktop)
          Row(
            children: [
              Expanded(
                child: buildSummaryCard(
                  isFiltered ? 'Period Conversions' : 'Converted Dealers',
                  totalTeamConversions.toString(),
                  Icons.verified_rounded,
                  const Color(0xFF10B981),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: buildSummaryCard(
                  'Dealers Ordered',
                  isFiltered
                      ? '$totalDealersWithOrdersCount Dealers'
                      : '$totalDealersWithOrdersCount of $totalTeamConversions',
                  Icons.shopping_cart_checkout_rounded,
                  const Color(0xFF8B5CF6),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: buildSummaryCard(
                  'Total Orders',
                  '$totalTeamOrders Orders',
                  Icons.shopping_bag_rounded,
                  const Color(0xFF0284C7),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: buildSummaryCard(
                  'Total Sales Revenue',
                  CurrencyUtils.formatInr(totalTeamSalesAmount),
                  Icons.currency_rupee_rounded,
                  const Color(0xFF059669),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: buildSummaryCard(
                  'Deleted Leads',
                  totalTeamDeletedLeads.toString(),
                  Icons.delete_sweep_rounded,
                  const Color(0xFFF43F5E),
                ),
              ),
            ],
          )
        else
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: (MediaQuery.of(context).size.width - 48) / 2,
                child: buildSummaryCard(
                  isFiltered ? 'Period Conversions' : 'Converted Dealers',
                  totalTeamConversions.toString(),
                  Icons.verified_rounded,
                  const Color(0xFF10B981),
                ),
              ),
              SizedBox(
                width: (MediaQuery.of(context).size.width - 48) / 2,
                child: buildSummaryCard(
                  'Dealers Ordered',
                  isFiltered
                      ? '$totalDealersWithOrdersCount Dealers'
                      : '$totalDealersWithOrdersCount of $totalTeamConversions',
                  Icons.shopping_cart_checkout_rounded,
                  const Color(0xFF8B5CF6),
                ),
              ),
              SizedBox(
                width: (MediaQuery.of(context).size.width - 48) / 2,
                child: buildSummaryCard(
                  'Total Orders',
                  '$totalTeamOrders Orders',
                  Icons.shopping_bag_rounded,
                  const Color(0xFF0284C7),
                ),
              ),
              SizedBox(
                width: (MediaQuery.of(context).size.width - 48) / 2,
                child: buildSummaryCard(
                  'Total Sales Revenue',
                  CurrencyUtils.formatInr(totalTeamSalesAmount),
                  Icons.currency_rupee_rounded,
                  const Color(0xFF059669),
                ),
              ),
              SizedBox(
                width: (MediaQuery.of(context).size.width - 48) / 2,
                child: buildSummaryCard(
                  'Deleted Leads',
                  totalTeamDeletedLeads.toString(),
                  Icons.delete_sweep_rounded,
                  const Color(0xFFF43F5E),
                ),
              ),
            ],
          ),
        const SizedBox(height: 20),
        _buildDateFilterRow(),
        const SizedBox(height: 20),

        // Search Bar
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.search,
                        size: 18,
                        color: AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                          onChanged: (val) {
                            setState(() {
                              _searchQuery = val;
                            });
                          },
                          decoration: InputDecoration(
                            hintText:
                                'Search sales & conversion stats by sales agent...',
                            hintStyle: GoogleFonts.outfit(
                              fontSize: 14,
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w400,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      if (_searchQuery.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Agent Cards List
        if (filteredAgents.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.sentiment_dissatisfied_rounded,
                  size: 48,
                  color: AppTheme.textSecondary,
                ),
                const SizedBox(height: 12),
                Text(
                  'No sales agents found matching your query',
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredAgents.length,
            separatorBuilder: (context, index) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              final agent = filteredAgents[index];
              final agentId = agent['_id']?.toString() ?? '';
              final allConvertedDealers =
                  allConvertedDealersMap[agentId] ?? [];
              final timeframeConversions =
                  timeframeConvertedDealersMap[agentId] ?? [];
              final activeLeads = activeLeadsMap[agentId] ?? [];
              final deletedLeads = deletedLeadsMap[agentId] ?? [];
              final agentOrders = agentOrdersMap[agentId] ?? [];

              final totalAssigned = (isFiltered
                      ? timeframeConversions.length
                      : allConvertedDealers.length) +
                  activeLeads.length +
                  deletedLeads.length;
              final double conversionRate = totalAssigned > 0
                  ? ((isFiltered
                              ? timeframeConversions.length
                              : allConvertedDealers.length) /
                          totalAssigned) *
                      100
                  : 0.0;

              final dealersWithOrdersSet = dealersWithOrdersMap[agentId] ?? {};
              final agentOrdersCount = agentOrdersCountMap[agentId] ?? 0;
              final double ordersPerDealer = allConvertedDealers.isNotEmpty
                  ? (agentOrdersCount / allConvertedDealers.length)
                  : 0.0;
              final double dealerOrderActivationRate =
                  allConvertedDealers.isNotEmpty
                      ? (dealersWithOrdersSet.length /
                              allConvertedDealers.length) *
                          100
                      : 0.0;

              final agentName =
                  '${agent['firstName'] ?? ''} ${agent['lastName'] ?? ''}'
                      .trim();
              final name = agentName.isNotEmpty
                  ? agentName
                  : (agent['shopName'] ?? agent['email'] ?? 'Sales Agent');

              final double agentSalesAmount =
                  agentSalesAmountMap[agentId] ?? 0.0;

              // Sort dealers: ordering dealers first, then highest sales
              final sortedDealers =
                  List<Map<String, dynamic>>.from(allConvertedDealers)
                    ..sort((a, b) {
                      final aId =
                          (a['_id'] ?? a['\$oid'] ?? a['id'])?.toString() ??
                              '';
                      final bId =
                          (b['_id'] ?? b['\$oid'] ?? b['id'])?.toString() ??
                              '';
                      final aSales = dealerSalesAmountMap[aId] ?? 0.0;
                      final bSales = dealerSalesAmountMap[bId] ?? 0.0;
                      if (aSales != bSales) return bSales.compareTo(aSales);
                      final aOrders = dealerOrdersCountMap[aId] ?? 0;
                      final bOrders = dealerOrdersCountMap[bId] ?? 0;
                      if (aOrders != bOrders) return bOrders.compareTo(aOrders);
                      return 0;
                    });

              return _buildAgentConversionCard(
                context,
                agent: agent,
                name: name,
                convertedDealers: sortedDealers,
                activeLeads: activeLeads,
                deletedLeads: deletedLeads,
                agentOrders: agentOrders,
                totalAssigned: totalAssigned,
                conversionRate: conversionRate,
                dealersWithOrdersCount: dealersWithOrdersSet.length,
                totalDealerOrders: agentOrdersCount,
                totalSalesAmount: agentSalesAmount,
                dealerSalesAmountMap: dealerSalesAmountMap,
                dealerOrdersCountMap: dealerOrdersCountMap,
                ordersPerDealer: ordersPerDealer,
                dealerOrderActivationRate: dealerOrderActivationRate,
                timeframeConversionsCount: timeframeConversions.length,
                isTimeframeFiltered: isFiltered,
              );
            },
          ),
      ],
    );
  }
}

/// Detailed Breakdown Dialog with structured tabs
class _AgentBreakdownDialog extends StatefulWidget {
  final Map<String, dynamic> agent;
  final String name;
  final List<Map<String, dynamic>> convertedDealers;
  final List<Map<String, dynamic>> activeLeads;
  final List<Map<String, dynamic>> deletedLeads;
  final List<Map<String, dynamic>> agentOrders;
  final Map<String, double> dealerSalesAmountMap;
  final Map<String, int> dealerOrdersCountMap;
  final double totalSalesAmount;
  final double conversionRate;
  final int dealersWithOrdersCount;
  final int totalDealerOrders;
  final bool isTimeframeFiltered;
  final int? timeframeConversionsCount;

  const _AgentBreakdownDialog({
    required this.agent,
    required this.name,
    required this.convertedDealers,
    required this.activeLeads,
    required this.deletedLeads,
    required this.agentOrders,
    required this.dealerSalesAmountMap,
    required this.dealerOrdersCountMap,
    required this.totalSalesAmount,
    required this.conversionRate,
    required this.dealersWithOrdersCount,
    required this.totalDealerOrders,
    required this.isTimeframeFiltered,
    required this.timeframeConversionsCount,
  });

  @override
  State<_AgentBreakdownDialog> createState() => _AgentBreakdownDialogState();
}

class _AgentBreakdownDialogState extends State<_AgentBreakdownDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _itemSearchController = TextEditingController();
  String _itemSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _itemSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _itemSearchQuery.toLowerCase();

    final filteredDealers = widget.convertedDealers.where((d) {
      final name =
          '${d['firstName'] ?? ''} ${d['lastName'] ?? ''}'.toLowerCase();
      final shop = (d['shopName'] ?? '').toLowerCase();
      final phone = (d['phoneNumber'] ?? d['phone'] ?? '').toLowerCase();
      return name.contains(query) ||
          shop.contains(query) ||
          phone.contains(query);
    }).toList();

    final filteredLeads = widget.activeLeads.where((l) {
      final name =
          '${l['firstName'] ?? ''} ${l['lastName'] ?? ''}'.toLowerCase();
      final shop = (l['shopName'] ?? '').toLowerCase();
      final phone = (l['phoneNumber'] ?? l['phone'] ?? '').toLowerCase();
      return name.contains(query) ||
          shop.contains(query) ||
          phone.contains(query);
    }).toList();

    final filteredDeleted = widget.deletedLeads.where((l) {
      final name =
          '${l['firstName'] ?? ''} ${l['lastName'] ?? ''}'.toLowerCase();
      final phone = (l['phoneNumber'] ?? l['phone'] ?? '').toLowerCase();
      return name.contains(query) || phone.contains(query);
    }).toList();

    final filteredOrders = widget.agentOrders.where((o) {
      final orderId = (o['_id'] ?? o['id'] ?? '').toString().toLowerCase();
      final userObj = o['user'];
      final userName = (userObj is Map
              ? '${userObj['firstName'] ?? ''} ${userObj['lastName'] ?? ''}'
              : '')
          .toLowerCase();
      return orderId.contains(query) || userName.contains(query);
    }).toList();

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 850, maxHeight: 720),
        child: Column(
          children: [
            // Modal Header
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 20, 16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppTheme.borderColor)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor:
                        AppTheme.primaryColor.withValues(alpha: 0.12),
                    radius: 20,
                    child: Text(
                      widget.name.isNotEmpty
                          ? widget.name[0].toUpperCase()
                          : 'S',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${widget.name} • Detailed Breakdown',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          '${CurrencyUtils.formatInr(widget.totalSalesAmount)} Total Sales · ${widget.totalDealerOrders} Orders · ${widget.conversionRate.toStringAsFixed(1)}% Conversion Rate',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Tabs & Search Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              color: const Color(0xFFF8FAFC),
              child: Column(
                children: [
                  // Tab Bar
                  TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    labelColor: AppTheme.primaryColor,
                    unselectedLabelColor: AppTheme.textSecondary,
                    indicatorColor: AppTheme.primaryColor,
                    indicatorWeight: 3,
                    labelStyle: GoogleFonts.outfit(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                    unselectedLabelStyle: GoogleFonts.outfit(
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                    tabs: [
                      Tab(
                        text: 'Converted Dealers (${widget.convertedDealers.length})',
                      ),
                      Tab(
                        text: 'Active Leads (${widget.activeLeads.length})',
                      ),
                      Tab(
                        text: 'Deleted Leads (${widget.deletedLeads.length})',
                      ),
                      Tab(
                        text: 'Orders (${widget.agentOrders.length})',
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Search Box
                  Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.search,
                          size: 16,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _itemSearchController,
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            onChanged: (val) {
                              setState(() => _itemSearchQuery = val);
                            },
                            decoration: InputDecoration(
                              hintText: 'Filter current tab records...',
                              hintStyle: GoogleFonts.outfit(
                                fontSize: 13,
                                color: AppTheme.textSecondary,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                        if (_itemSearchQuery.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.clear, size: 14),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () {
                              _itemSearchController.clear();
                              setState(() => _itemSearchQuery = '');
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Converted Dealers
                  _buildDealersList(filteredDealers),

                  // Tab 2: Active Leads
                  _buildLeadsList(filteredLeads),

                  // Tab 3: Deleted Leads
                  _buildDeletedList(filteredDeleted),

                  // Tab 4: Orders
                  _buildOrdersList(filteredOrders),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDealersList(List<Map<String, dynamic>> dealers) {
    if (dealers.isEmpty) {
      return Center(
        child: Text(
          'No converted dealers found',
          style: GoogleFonts.outfit(color: AppTheme.textSecondary),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: dealers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final d = dealers[index];
        final dId = (d['_id'] ?? d['\$oid'] ?? d['id'])?.toString() ?? '';
        final firstName = d['firstName'] ?? '';
        final lastName = d['lastName'] ?? '';
        final personName = '$firstName $lastName'.trim();
        final shop = (d['shopName'] ?? '').toString();
        final phone = (d['phoneNumber'] ?? d['phone'] ?? '').toString();
        final title = personName.isNotEmpty
            ? personName
            : (shop.isNotEmpty ? shop : phone);

        final sales = widget.dealerSalesAmountMap[dId] ?? 0.0;
        final ordersCount = widget.dealerOrdersCountMap[dId] ?? 0;

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.verified_rounded,
                size: 18,
                color: Color(0xFF10B981),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    if (shop.isNotEmpty && shop != title)
                      Text(
                        shop,
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              if (phone.isNotEmpty) ...[
                Text(
                  phone,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: ordersCount > 0
                      ? const Color(0xFFF3E8FF)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  ordersCount > 0 ? '$ordersCount Orders' : '0 Orders',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: ordersCount > 0
                        ? const Color(0xFF7E22CE)
                        : AppTheme.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: sales > 0
                      ? const Color(0xFFECFDF5)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  sales > 0 ? CurrencyUtils.formatInr(sales) : '₹0 Sales',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: sales > 0
                        ? const Color(0xFF059669)
                        : AppTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLeadsList(List<Map<String, dynamic>> leads) {
    if (leads.isEmpty) {
      return Center(
        child: Text(
          'No active leads found',
          style: GoogleFonts.outfit(color: AppTheme.textSecondary),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: leads.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final l = leads[index];
        final firstName = l['firstName'] ?? '';
        final lastName = l['lastName'] ?? '';
        final personName = '$firstName $lastName'.trim();
        final shop = (l['shopName'] ?? '').toString();
        final phone = (l['phoneNumber'] ?? l['phone'] ?? '').toString();
        final title = personName.isNotEmpty
            ? personName
            : (shop.isNotEmpty ? shop : phone);

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.campaign_outlined,
                size: 18,
                color: Color(0xFF0284C7),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    if (shop.isNotEmpty && shop != title)
                      Text(
                        shop,
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              if (phone.isNotEmpty)
                Text(
                  phone,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Active Lead',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1D4ED8),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDeletedList(List<Map<String, dynamic>> deleted) {
    if (deleted.isEmpty) {
      return Center(
        child: Text(
          'No deleted leads found',
          style: GoogleFonts.outfit(color: AppTheme.textSecondary),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: deleted.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final d = deleted[index];
        final firstName = d['firstName'] ?? '';
        final lastName = d['lastName'] ?? '';
        final personName = '$firstName $lastName'.trim();
        final phone = (d['phoneNumber'] ?? d['phone'] ?? '').toString();
        final title = personName.isNotEmpty
            ? personName
            : (phone.isNotEmpty ? phone : 'Deleted Lead');

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF1F2),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFFECDD3)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.remove_circle_outline_rounded,
                size: 16,
                color: Color(0xFFE11D48),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFBE123C),
                  ),
                ),
              ),
              if (phone.isNotEmpty)
                Text(
                  phone,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFBE123C),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOrdersList(List<Map<String, dynamic>> orders) {
    if (orders.isEmpty) {
      return Center(
        child: Text(
          'No orders found for this sales agent',
          style: GoogleFonts.outfit(color: AppTheme.textSecondary),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final o = orders[index];
        final orderId = (o['_id'] ?? o['id'] ?? '').toString();
        final userObj = o['user'];
        String userName = 'Client';
        if (userObj is Map) {
          final fn = userObj['firstName'] ?? '';
          final ln = userObj['lastName'] ?? '';
          final name = '$fn $ln'.trim();
          if (name.isNotEmpty) userName = name;
        }

        final double amount = CurrencyUtils.parse(
          o['totalAmount'] ??
              o['grandTotal'] ??
              o['total'] ??
              o['payableAmount'] ??
              0,
        );
        final status = (o['orderStatus'] ?? 'Completed').toString();

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.shopping_bag_outlined,
                size: 18,
                color: Color(0xFF7E22CE),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      '#${orderId.length > 8 ? orderId.substring(orderId.length - 8) : orderId}',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3E8FF),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF7E22CE),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                CurrencyUtils.formatInr(amount),
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF059669),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
