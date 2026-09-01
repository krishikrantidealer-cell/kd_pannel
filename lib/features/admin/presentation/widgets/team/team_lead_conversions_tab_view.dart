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
    } else if (dateVal is Map) {
      final d = dateVal['\$date'] ?? dateVal['date'];
      if (d is String) dt = DateTime.tryParse(d);
    }

    if (dt == null) return false;

    final start = DateTime(
      _conversionDateRange!.start.year,
      _conversionDateRange!.start.month,
      _conversionDateRange!.start.day,
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

    return dt.isAfter(start.subtract(const Duration(milliseconds: 1))) &&
        dt.isBefore(end.add(const Duration(milliseconds: 1)));
  }

  Widget _buildDateFilterRow() {
    String selectedPreset = 'All Time';
    if (_conversionDateRange != null) {
      final now = DateTime.now();
      final start = _conversionDateRange!.start;
      final end = _conversionDateRange!.end;
      final diffDays = end.difference(start).inDays;

      if (start.year == now.year &&
          start.month == now.month &&
          start.day == now.day &&
          end.year == now.year &&
          end.month == now.month &&
          end.day == now.day) {
        selectedPreset = 'Today';
      } else if (diffDays >= 6 && diffDays <= 7) {
        selectedPreset = 'Last 7 Days';
      } else if (diffDays >= 29 && diffDays <= 31) {
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
                      () => _conversionDateRange =
                          DateTimeRange(start: now, end: now),
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
                        start: now.subtract(const Duration(days: 7)),
                        end: now,
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
                        start: now.subtract(const Duration(days: 30)),
                        end: now,
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
                              const Duration(days: 30),
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

  Widget _buildStatPill(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            '$label: ',
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgentConversionCard(
    BuildContext context, {
    required Map<String, dynamic> agent,
    required String name,
    required List<Map<String, dynamic>> convertedDealers,
    required int activeLeadsCount,
    required List<Map<String, dynamic>> deletedLeads,
    required int totalAssigned,
    required double conversionRate,
    required int dealersWithOrdersCount,
    required int totalDealerOrders,
    required double totalSalesAmount,
    required Map<String, double> dealerSalesAmountMap,
    required Map<String, int> dealerOrdersCountMap,
    required double ordersPerDealer,
    required double dealerOrderActivationRate,
    required List<Map<String, dynamic>> allOrders,
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

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: SelectionContainer.disabled(
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
              childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              leading: CircleAvatar(
                backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
                radius: 24,
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'S',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                    fontSize: 16,
                  ),
                ),
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFFA7F3D0),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.payments_outlined,
                                  size: 14,
                                  color: Color(0xFF059669),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${CurrencyUtils.formatInr(totalSalesAmount)} Total Sales',
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF059669),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: rateBgColor,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: rateBadgeColor.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.trending_up_rounded,
                                  size: 14,
                                  color: rateBadgeColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${convertedDealers.length} Converted Dealers',
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: rateBadgeColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3E8FF),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFD8B4FE)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.shopping_cart_checkout_rounded,
                              size: 13,
                              color: Color(0xFF7E22CE),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$dealersWithOrdersCount of ${convertedDealers.length} Dealers Ordered ($totalDealerOrders Orders)',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF7E22CE),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Builder(
                  builder: (context) {
                    final int directOnboardedCount = convertedDealers.where((d) {
                      final via =
                          (d['createdVia'] ?? '').toString().toLowerCase();
                      final src = (d['source'] ?? '').toString().toLowerCase();
                      return via == 'panel' ||
                          (src == 'kd panel' && via != 'lead_conversion');
                    }).length;
                    final int leadUpgradeCount = convertedDealers.where((d) {
                      final via =
                          (d['createdVia'] ?? '').toString().toLowerCase();
                      return via == 'lead_conversion';
                    }).length;

                    return Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        _buildStatPill(
                          'Total Sales',
                          CurrencyUtils.formatInr(totalSalesAmount),
                          Icons.currency_rupee_rounded,
                          const Color(0xFF059669),
                        ),
                        _buildStatPill(
                          'Converted Dealers',
                          '${convertedDealers.length}',
                          Icons.check_circle_rounded,
                          const Color(0xFF10B981),
                        ),
                        if (directOnboardedCount > 0)
                          _buildStatPill(
                            'Direct Onboarded',
                            '$directOnboardedCount',
                            Icons.person_add_alt_1_rounded,
                            const Color(0xFF0284C7),
                          ),
                        if (leadUpgradeCount > 0)
                          _buildStatPill(
                            'Lead Upgrades',
                            '$leadUpgradeCount',
                            Icons.published_with_changes_rounded,
                            const Color(0xFF059669),
                          ),
                        _buildStatPill(
                          'Active Leads',
                          '$activeLeadsCount',
                          Icons.campaign_rounded,
                          const Color(0xFF0284C7),
                        ),
                        _buildStatPill(
                          'Dealers Who Ordered',
                          '$dealersWithOrdersCount of ${convertedDealers.length}',
                          Icons.shopping_cart_checkout_rounded,
                          const Color(0xFF8B5CF6),
                        ),
                        _buildStatPill(
                          'Total Orders',
                          '$totalDealerOrders Orders',
                          Icons.shopping_bag_rounded,
                          const Color(0xFF7E22CE),
                        ),
                        if (totalDealerOrders > 0)
                          _buildStatPill(
                            'Avg Order Value',
                            CurrencyUtils.formatInr(
                              totalSalesAmount / totalDealerOrders,
                            ),
                            Icons.auto_graph_rounded,
                            const Color(0xFFD97706),
                          ),
                        _buildStatPill(
                          'Deleted Leads',
                          '${deletedLeads.length}',
                          Icons.delete_outline_rounded,
                          const Color(0xFFF43F5E),
                        ),
                      ],
                    );
                  },
                ),
              ),
              children: [
                const Divider(height: 1, color: AppTheme.borderColor),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Converted Dealers (${convertedDealers.length})',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      '$dealersWithOrdersCount of ${convertedDealers.length} Dealers Placed Orders ($totalDealerOrders Orders Total · ${CurrencyUtils.formatInr(totalSalesAmount)})',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: const Color(0xFF7E22CE),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (convertedDealers.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Center(
                      child: Text(
                        'No lead-to-dealer conversions recorded yet for this sales agent.',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: convertedDealers.length,
                    separatorBuilder: (context, idx) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, idx) {
                      final dealer = convertedDealers[idx];
                      final dId =
                          (dealer['_id'] ?? dealer['\$oid'] ?? dealer['id'])
                              ?.toString();
                      final dFirstName = dealer['firstName'] ?? '';
                      final dLastName = dealer['lastName'] ?? '';
                      final dPersonName = '$dFirstName $dLastName'.trim();
                      final dShop = (dealer['shopName'] ?? '').toString();
                      final dPhone =
                          (dealer['phoneNumber'] ?? dealer['phone'] ?? '')
                              .toString();
                      final dTitle = dPersonName.isNotEmpty
                          ? dPersonName
                          : (dShop.isNotEmpty
                              ? dShop
                              : (dPhone.isNotEmpty
                                  ? dPhone
                                  : 'Verified Dealer'));

                      final String createdVia =
                          (dealer['createdVia'] ?? '').toString().toLowerCase();
                      final String source =
                          (dealer['source'] ?? '').toString();
                      final bool isDirectOnboard = createdVia == 'panel' ||
                          (source == 'KD Panel' &&
                              createdVia != 'lead_conversion');
                      final bool isLeadUpgrade =
                          createdVia == 'lead_conversion';

                      final int dealerOrdersCount =
                          (dId != null) ? (dealerOrdersCountMap[dId] ?? 0) : 0;

                      final double dealerSales = (dId != null)
                          ? (dealerSalesAmountMap[dId] ?? 0.0)
                          : 0.0;

                      final address =
                          dealer['address'] as Map<String, dynamic>?;
                      final city =
                          address?['cityTehsil'] ?? dealer['city'] ?? '';
                      final stateStr =
                          address?['state'] ?? dealer['state'] ?? '';
                      final location = [
                        city,
                        stateStr,
                      ].where((s) => s.toString().isNotEmpty).join(', ');

                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
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
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          dTitle,
                                          style: GoogleFonts.outfit(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.textPrimary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isDirectOnboard
                                              ? const Color(0xFFE0F2FE)
                                              : (isLeadUpgrade
                                                  ? const Color(0xFFDCFCE7)
                                                  : const Color(0xFFF1F5F9)),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                          border: Border.all(
                                            color: isDirectOnboard
                                                ? const Color(0xFFBAE6FD)
                                                : (isLeadUpgrade
                                                    ? const Color(0xFFBBF7D0)
                                                    : const Color(
                                                        0xFFE2E8F0,
                                                      )),
                                          ),
                                        ),
                                        child: Text(
                                          isDirectOnboard
                                              ? 'Direct Onboard'
                                              : (isLeadUpgrade
                                                  ? 'Lead Upgraded'
                                                  : 'App Verified'),
                                          style: GoogleFonts.outfit(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: isDirectOnboard
                                                ? const Color(0xFF0369A1)
                                                : (isLeadUpgrade
                                                    ? const Color(0xFF15803D)
                                                    : const Color(
                                                        0xFF475569,
                                                      )),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (dShop.isNotEmpty && dShop != dTitle)
                                    Text(
                                      dShop,
                                      style: GoogleFonts.outfit(
                                        fontSize: 11,
                                        color: AppTheme.textSecondary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: dealerOrdersCount > 0
                                    ? const Color(0xFFF3E8FF)
                                    : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: dealerOrdersCount > 0
                                      ? const Color(0xFFD8B4FE)
                                      : const Color(0xFFCBD5E1),
                                ),
                              ),
                              child: Text(
                                dealerOrdersCount > 0
                                    ? '$dealerOrdersCount Orders'
                                    : 'No Orders',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: dealerOrdersCount > 0
                                      ? const Color(0xFF7E22CE)
                                      : AppTheme.textSecondary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: dealerSales > 0
                                    ? const Color(0xFFECFDF5)
                                    : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: dealerSales > 0
                                      ? const Color(0xFFA7F3D0)
                                      : const Color(0xFFCBD5E1),
                                ),
                              ),
                              child: Text(
                                dealerSales > 0
                                    ? CurrencyUtils.formatInr(dealerSales)
                                    : '₹0 Sales',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: dealerSales > 0
                                      ? const Color(0xFF059669)
                                      : AppTheme.textSecondary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            if (dPhone.isNotEmpty) ...[
                              Text(
                                dPhone,
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                            if (location.isNotEmpty) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: const Color(0xFFCBD5E1),
                                  ),
                                ),
                                child: Text(
                                  location,
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                if (deletedLeads.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      const Icon(
                        Icons.delete_outline_rounded,
                        size: 16,
                        color: Color(0xFFF43F5E),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Deleted Leads (${deletedLeads.length})',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFF43F5E),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: deletedLeads.length,
                    separatorBuilder: (context, idx) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, idx) {
                      final dLead = deletedLeads[idx];
                      final lFirstName = dLead['firstName'] ?? '';
                      final lLastName = dLead['lastName'] ?? '';
                      final lPersonName = '$lFirstName $lLastName'.trim();
                      final lPhone =
                          (dLead['phoneNumber'] ?? dLead['phone'] ?? '')
                              .toString();
                      final lTitle = lPersonName.isNotEmpty
                          ? lPersonName
                          : (lPhone.isNotEmpty ? lPhone : 'Deleted Lead');

                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
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
                                lTitle,
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFFBE123C),
                                ),
                              ),
                            ),
                            if (lPhone.isNotEmpty)
                              Text(
                                lPhone,
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
                  ),
                ],
              ],
            ),
          ),
        ),
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

    final Map<String, List<Map<String, dynamic>>> convertedDealersMap = {};
    final Map<String, List<Map<String, dynamic>>> activeLeadsMap = {};
    final Map<String, List<Map<String, dynamic>>> deletedLeadsMap = {};
    final Map<String, Set<String>> dealersWithOrdersMap = {};
    final Map<String, int> agentOrdersCountMap = {};
    final Map<String, double> agentSalesAmountMap = {};
    final Map<String, double> dealerSalesAmountMap = {};

    int totalTeamConversions = 0;
    int totalTeamDeletedLeads = 0;
    int totalTeamOrders = 0;
    double totalTeamSalesAmount = 0.0;

    final List<Map<String, dynamic>> combinedUsers = [
      ...widget.state.allRawUsers,
      ...widget.deletedUsersList,
    ];
    final Set<String> processedUserIds = {};

    for (final user in combinedUsers) {
      final uid = (user['_id'] ?? user['\$oid'] ?? user['id'])?.toString();
      if (uid != null && processedUserIds.contains(uid)) continue;
      if (uid != null) processedUserIds.add(uid);

      final isDeleted = user['isDeleted'] == true ||
          user['status'] == 'deleted' ||
          user['trash'] == true;
      final agentIdObj = user['assignedAgent'];
      String? agentId;
      if (agentIdObj is Map) {
        agentId = (agentIdObj['_id'] ?? agentIdObj['\$oid'] ?? agentIdObj['id'])
            ?.toString();
      } else if (agentIdObj is String) {
        agentId = agentIdObj;
      }

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
            final approvedDate =
                user['kycApprovedAt'] ?? user['updatedAt'] ?? user['createdAt'];
            if (_isWithinDateRange(approvedDate)) {
              convertedDealersMap.putIfAbsent(agentId, () => []).add(user);
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

    final Map<String, String> dealerIdToAgentIdMap = {};
    for (final entry in convertedDealersMap.entries) {
      for (final dealer in entry.value) {
        final dId =
            (dealer['_id'] ?? dealer['\$oid'] ?? dealer['id'])?.toString();
        if (dId != null && dId.isNotEmpty) {
          dealerIdToAgentIdMap[dId] = entry.key;
        }
      }
    }

    final Map<String, int> dealerOrdersCountMap = {};

    for (final order in allOrders) {
      if (order['orderStatus'] == 'Cancelled') continue;
      final orderDate = order['createdAt'] ?? order['orderDate'];
      if (!_isWithinDateRange(orderDate)) continue;

      final userObj = order['user'];
      if (userObj == null) continue;

      String? userId;
      if (userObj is Map) {
        userId = (userObj['_id'] ?? userObj['\$oid'] ?? userObj['id'])
            ?.toString();
      } else if (userObj is String) {
        userId = userObj;
      }

      if (userId == null || userId.isEmpty) continue;

      final double orderAmount = CurrencyUtils.parse(
        order['totalAmount'] ?? order['grandTotal'] ?? 0,
      );

      final agentId = dealerIdToAgentIdMap[userId];
      if (agentId != null) {
        dealersWithOrdersMap.putIfAbsent(agentId, () => {}).add(userId);
        agentOrdersCountMap[agentId] =
            (agentOrdersCountMap[agentId] ?? 0) + 1;
        agentSalesAmountMap[agentId] =
            (agentSalesAmountMap[agentId] ?? 0.0) + orderAmount;
        dealerSalesAmountMap[userId] =
            (dealerSalesAmountMap[userId] ?? 0.0) + orderAmount;
        dealerOrdersCountMap[userId] =
            (dealerOrdersCountMap[userId] ?? 0) + 1;
        totalTeamOrders++;
        totalTeamSalesAmount += orderAmount;
      }
    }

    int totalDealersWithOrdersCount = dealersWithOrdersMap.values
        .fold<Set<String>>({}, (prev, set) => prev..addAll(set))
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.isDesktop)
          Row(
            children: [
              Expanded(
                child: buildSummaryCard(
                  'Converted Dealers',
                  totalTeamConversions.toString(),
                  Icons.verified_rounded,
                  const Color(0xFF10B981),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: buildSummaryCard(
                  'Dealers Ordered',
                  '$totalDealersWithOrdersCount of $totalTeamConversions',
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
                  'Converted Dealers',
                  totalTeamConversions.toString(),
                  Icons.verified_rounded,
                  const Color(0xFF10B981),
                ),
              ),
              SizedBox(
                width: (MediaQuery.of(context).size.width - 48) / 2,
                child: buildSummaryCard(
                  'Dealers Ordered',
                  '$totalDealersWithOrdersCount of $totalTeamConversions',
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
                                'Search conversion stats & ratios by sales agent...',
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
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final agent = filteredAgents[index];
              final agentId = agent['_id']?.toString() ?? '';
              final convertedDealers = convertedDealersMap[agentId] ?? [];
              final activeLeads = activeLeadsMap[agentId] ?? [];
              final deletedLeads = deletedLeadsMap[agentId] ?? [];
              final totalAssigned =
                  convertedDealers.length + activeLeads.length;
              final double conversionRate = totalAssigned > 0
                  ? (convertedDealers.length / totalAssigned) * 100
                  : 0.0;

              final dealersWithOrdersSet = dealersWithOrdersMap[agentId] ?? {};
              final agentOrdersCount = agentOrdersCountMap[agentId] ?? 0;
              final double ordersPerDealer = convertedDealers.isNotEmpty
                  ? (agentOrdersCount / convertedDealers.length)
                  : 0.0;
              final double dealerOrderActivationRate =
                  convertedDealers.isNotEmpty
                      ? (dealersWithOrdersSet.length /
                              convertedDealers.length) *
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

              return _buildAgentConversionCard(
                context,
                agent: agent,
                name: name,
                convertedDealers: convertedDealers,
                activeLeadsCount: activeLeads.length,
                deletedLeads: deletedLeads,
                totalAssigned: totalAssigned,
                conversionRate: conversionRate,
                dealersWithOrdersCount: dealersWithOrdersSet.length,
                totalDealerOrders: agentOrdersCount,
                totalSalesAmount: agentSalesAmount,
                dealerSalesAmountMap: dealerSalesAmountMap,
                dealerOrdersCountMap: dealerOrdersCountMap,
                ordersPerDealer: ordersPerDealer,
                dealerOrderActivationRate: dealerOrderActivationRate,
                allOrders: allOrders,
              );
            },
          ),
      ],
    );
  }
}
