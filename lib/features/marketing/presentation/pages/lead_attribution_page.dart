import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:kd_pannel/app_theme.dart';
import 'package:kd_pannel/core/responsive/responsive.dart';
import 'package:kd_pannel/features/marketing/presentation/bloc/attribution_bloc.dart';
import 'package:kd_pannel/features/marketing/presentation/bloc/attribution_event.dart';
import 'package:kd_pannel/features/marketing/presentation/bloc/attribution_state.dart';
import 'package:kd_pannel/util/export_helper.dart';

class LeadAttributionPage extends StatefulWidget {
  const LeadAttributionPage({super.key});

  @override
  State<LeadAttributionPage> createState() => _LeadAttributionPageState();
}

class _LeadAttributionPageState extends State<LeadAttributionPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  final _inrFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final bloc = context.read<AttributionBloc>();
      if (bloc.state.status == AttributionStatus.initial) {
        bloc.add(const LoadAttributionEvent());
      } else {
        bloc.add(const LoadAttributionEvent(silent: true));
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _formatInr(dynamic value) {
    final numVal = num.tryParse('${value ?? 0}') ?? 0;
    return _inrFormat.format(numVal);
  }

  String _formatSyncedAgo(String? iso) {
    if (iso == null || iso.isEmpty) return 'Live';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Synced just now';
      if (diff.inMinutes < 60) return 'Synced ${diff.inMinutes}m ago';
      if (diff.inHours < 24) return 'Synced ${diff.inHours}h ago';
      return 'Synced ${DateFormat('d MMM, h:mm a').format(dt)}';
    } catch (_) {
      return 'Live';
    }
  }

  Future<void> _pickCustomDateRange(AttributionState state) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024, 1, 1),
      lastDate: now,
      initialDateRange: state.customDateRange ??
          DateTimeRange(
            start: now.subtract(const Duration(days: 30)),
            end: now,
          ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primaryColor,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      context.read<AttributionBloc>().add(
            ChangeAttributionDatePresetEvent('custom', customRange: picked),
          );
    }
  }

  String _csvCell(dynamic v) {
    final s = (v ?? '').toString().replaceAll('"', '""');
    return '"$s"';
  }

  void _exportCsv(AttributionState state) {
    final rows = state.visibleCampaigns;
    if (rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No campaign rows to export.')),
      );
      return;
    }

    final (startStr, endStr) = context.read<AttributionBloc>().resolveDateStrings();
    final buf = StringBuffer();
    buf.writeln(
      'Campaign,Channel,Spend,Unique Leads,CPL,KYC Dealers,Lead to Dealer %,Cost per Dealer,Ordering Dealers,Dealer to Order %,Orders,Cost per Buyer,Total GMV,Delivered GMV,Delivered ROAS,RTO %',
    );

    for (final c in rows) {
      buf.writeln([
        _csvCell(c['campaignName'] ?? c['campaignId']),
        _csvCell(c['channel']),
        c['spend'] ?? 0,
        c['uniqueLeads'] ?? 0,
        c['cpl'] ?? 0,
        c['qualifiedDealers'] ?? 0,
        c['leadToDealerPct'] ?? 0,
        c['costPerQualifiedDealer'] ?? 0,
        c['orderingDealers'] ?? 0,
        c['dealerToOrderPct'] ?? 0,
        c['ordersCount'] ?? 0,
        c['costPerOrderingDealer'] ?? 0,
        c['totalGmv'] ?? 0,
        c['deliveredGmv'] ?? 0,
        c['deliveredRoas'] ?? 0,
        c['rtoPct'] ?? 0,
      ].join(','));
    }

    final t = state.totals;
    buf.writeln([
      _csvCell('TOTAL ($startStr to $endStr)'),
      _csvCell(state.channel),
      t['spend'] ?? 0,
      t['uniqueLeads'] ?? 0,
      t['cpl'] ?? 0,
      t['qualifiedDealers'] ?? 0,
      t['leadToDealerPct'] ?? 0,
      t['costPerQualifiedDealer'] ?? 0,
      t['orderingDealers'] ?? 0,
      t['dealerToOrderPct'] ?? 0,
      t['ordersCount'] ?? 0,
      t['costPerOrderingDealer'] ?? 0,
      t['totalGmv'] ?? 0,
      t['deliveredGmv'] ?? 0,
      t['deliveredRoas'] ?? 0,
      t['rtoPct'] ?? 0,
    ].join(','));

    downloadCsv(buf.toString(), 'lead_attribution_${startStr}_to_$endStr.csv');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Campaign attribution CSV downloaded!'),
        backgroundColor: AppTheme.primaryColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);

    return BlocConsumer<AttributionBloc, AttributionState>(
      listenWhen: (prev, curr) =>
          curr.syncMessage != null && curr.syncMessage != prev.syncMessage,
      listener: (context, state) {
        if (state.syncMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.syncMessage!),
              backgroundColor: state.syncWarning ? Colors.orange : AppTheme.primaryColor,
            ),
          );
        }
      },
      builder: (context, state) {
        final visibleCampaigns = state.visibleCampaigns;

        return Scaffold(
          backgroundColor: const Color(0xFFF4F7F5),
          body: Column(
            children: [
              _buildHeader(context, state, isDesktop),
              if (state.isRefreshing || state.isSyncing)
                const LinearProgressIndicator(
                  minHeight: 2.5,
                  color: AppTheme.primaryColor,
                  backgroundColor: Color(0xFFE2E8F0),
                ),
              Expanded(
                child: state.status == AttributionStatus.loading &&
                        state.campaigns.isEmpty
                    ? const Center(
                        child: CircularProgressIndicator(color: AppTheme.primaryColor),
                      )
                    : state.status == AttributionStatus.error &&
                            state.campaigns.isEmpty
                        ? _buildErrorState(context, state.errorMessage)
                        : RefreshIndicator(
                            onRefresh: () async => context
                                .read<AttributionBloc>()
                                .add(const LoadAttributionEvent()),
                            color: AppTheme.primaryColor,
                            child: SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: EdgeInsets.all(isDesktop ? 24 : 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildFilterToolbar(context, state, isDesktop),
                                  const SizedBox(height: 18),
                                  _buildKpiStrip(state.totals, isDesktop),
                                  const SizedBox(height: 18),
                                  _buildAnalyticsRow(state.totals, isDesktop),
                                  const SizedBox(height: 18),
                                  _buildCampaignTable(
                                    context,
                                    state,
                                    visibleCampaigns,
                                  ),
                                ],
                              ),
                            ),
                          ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(
    BuildContext context,
    AttributionState state,
    bool isDesktop,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 24 : 16,
        vertical: 14,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF166534), Color(0xFF16A34A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF16A34A).withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.query_stats_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Lead Attribution & ROAS',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w800,
                          fontSize: 19,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFF10B981),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'LIVE WS',
                              style: GoogleFonts.outfit(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF047857),
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'First-touch attribution across Meta Lead Forms & Dealer App Installs • ${_formatSyncedAgo(state.lastSyncedAt)}',
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
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton.icon(
                onPressed: state.visibleCampaigns.isEmpty ? null : () => _exportCsv(state),
                icon: const Icon(Icons.download_rounded, size: 16),
                label: Text(
                  'Export CSV',
                  style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0284C7),
                  side: const BorderSide(color: Color(0xFFBAE6FD)),
                  backgroundColor: const Color(0xFFF0F9FF),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: state.isSyncing
                    ? null
                    : () => context.read<AttributionBloc>().add(const SyncMetaSpendEvent()),
                icon: state.isSyncing
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.sync_rounded, size: 16),
                label: Text(
                  state.isSyncing ? 'Syncing...' : 'Sync Meta Spend',
                  style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                onPressed: () =>
                    context.read<AttributionBloc>().add(const LoadAttributionEvent()),
                icon: const Icon(Icons.refresh_rounded, color: AppTheme.textSecondary),
                tooltip: 'Refresh Report',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterToolbar(
    BuildContext context,
    AttributionState state,
    bool isDesktop,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final ch in const [
                  {'id': 'all', 'label': 'All Channels'},
                  {'id': 'lead_form', 'label': 'Lead Forms'},
                  {'id': 'app_install', 'label': 'App Installs'},
                ])
                  GestureDetector(
                    onTap: () => context
                        .read<AttributionBloc>()
                        .add(ChangeAttributionChannelEvent(ch['id']!)),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: state.channel == ch['id'] ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: state.channel == ch['id']
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ]
                            : null,
                      ),
                      child: Text(
                        ch['label']!,
                        style: GoogleFonts.outfit(
                          fontSize: 12.5,
                          fontWeight:
                              state.channel == ch['id'] ? FontWeight.w700 : FontWeight.w600,
                          color: state.channel == ch['id']
                              ? AppTheme.primaryColor
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          FilterChip(
            label: Text(
              'Live Campaigns Only',
              style: GoogleFonts.outfit(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: state.liveOnly ? Colors.white : AppTheme.textPrimary,
              ),
            ),
            selected: state.liveOnly,
            selectedColor: const Color(0xFF059669),
            checkmarkColor: Colors.white,
            backgroundColor: const Color(0xFFF8FAFC),
            side: BorderSide(
              color: state.liveOnly ? const Color(0xFF059669) : const Color(0xFFE2E8F0),
            ),
            onSelected: (val) =>
                context.read<AttributionBloc>().add(ToggleLiveCampaignsEvent(val)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: DropdownButton<String>(
              value: state.datePreset,
              underline: const SizedBox.shrink(),
              isDense: true,
              style: GoogleFonts.outfit(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
              items: [
                const DropdownMenuItem(value: 'today', child: Text('Today')),
                const DropdownMenuItem(value: 'yesterday', child: Text('Yesterday')),
                const DropdownMenuItem(value: '7d', child: Text('Last 7 Days')),
                const DropdownMenuItem(value: '30d', child: Text('Last 30 Days')),
                const DropdownMenuItem(value: 'all', child: Text('All Time')),
                DropdownMenuItem(
                  value: 'custom',
                  child: Text(
                    state.customDateRange != null
                        ? '${DateFormat('d MMM').format(state.customDateRange!.start)} – ${DateFormat('d MMM').format(state.customDateRange!.end)}'
                        : 'Custom Range...',
                  ),
                ),
              ],
              onChanged: (val) async {
                if (val == 'custom') {
                  await _pickCustomDateRange(state);
                } else if (val != null) {
                  context
                      .read<AttributionBloc>()
                      .add(ChangeAttributionDatePresetEvent(val));
                }
              },
            ),
          ),
          if (state.datePreset == 'custom')
            TextButton.icon(
              onPressed: () => _pickCustomDateRange(state),
              icon: const Icon(Icons.date_range_rounded, size: 16),
              label: const Text('Change'),
            ),
          SizedBox(
            width: isDesktop ? 240 : double.infinity,
            height: 36,
            child: TextField(
              controller: _searchCtrl,
              onChanged: (val) => context
                  .read<AttributionBloc>()
                  .add(AttributionSearchChangedEvent(val)),
              style: GoogleFonts.outfit(fontSize: 12.5),
              decoration: InputDecoration(
                hintText: 'Search campaign...',
                hintStyle: GoogleFonts.outfit(fontSize: 12.5, color: const Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search_rounded, size: 17, color: Color(0xFF64748B)),
                suffixIcon: state.searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 15),
                        onPressed: () {
                          _searchCtrl.clear();
                          context
                              .read<AttributionBloc>()
                              .add(const AttributionSearchChangedEvent(''));
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiStrip(Map<String, dynamic> t, bool isDesktop) {
    final cards = [
      {
        'label': 'Total Ad Spend',
        'value': _formatInr(t['spend'] ?? 0),
        'sub': 'CPL: ${_formatInr(t['cpl'] ?? 0)} per lead',
        'icon': Icons.account_balance_wallet_rounded,
        'color': const Color(0xFF334155),
        'bg': const Color(0xFFF1F5F9),
      },
      {
        'label': 'Unique Leads',
        'value': NumberFormat('#,##,###').format(num.tryParse('${t['uniqueLeads'] ?? 0}') ?? 0),
        'sub': 'Raw submissions: ${t['rawLeads'] ?? 0}',
        'icon': Icons.group_add_rounded,
        'color': const Color(0xFF0284C7),
        'bg': const Color(0xFFE0F2FE),
      },
      {
        'label': 'Qualified Dealers (KYC)',
        'value': '${t['qualifiedDealers'] ?? 0}',
        'sub': '${t['leadToDealerPct'] ?? 0}% conv • ${_formatInr(t['costPerQualifiedDealer'] ?? 0)}/dealer',
        'icon': Icons.verified_user_rounded,
        'color': const Color(0xFF059669),
        'bg': const Color(0xFFD1FAE5),
      },
      {
        'label': 'Ordering Dealers',
        'value': '${t['orderingDealers'] ?? 0}',
        'sub': '${t['dealerToOrderPct'] ?? 0}% of KYC • ${_formatInr(t['costPerOrderingDealer'] ?? 0)}/buyer',
        'icon': Icons.shopping_bag_rounded,
        'color': const Color(0xFF7C3AED),
        'bg': const Color(0xFFF3E8FF),
      },
      {
        'label': 'Delivered GMV & ROAS',
        'value': _formatInr(t['deliveredGmv'] ?? 0),
        'sub': '${t['deliveredRoas'] ?? 0}x ROAS • RTO: ${t['rtoPct'] ?? 0}%',
        'icon': Icons.trending_up_rounded,
        'color': const Color(0xFFD97706),
        'bg': const Color(0xFFFEF3C7),
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isDesktop ? 5 : 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: isDesktop ? 1.85 : 1.55,
      ),
      itemCount: cards.length,
      itemBuilder: (_, idx) {
        final c = cards[idx];
        final color = c['color'] as Color;
        final bg = c['bg'] as Color;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.025),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      c['label'] as String,
                      style: GoogleFonts.outfit(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(c['icon'] as IconData, size: 15, color: color),
                  ),
                ],
              ),
              Text(
                c['value'] as String,
                style: GoogleFonts.outfit(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              Text(
                c['sub'] as String,
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAnalyticsRow(Map<String, dynamic> t, bool isDesktop) {
    final funnelCard = _buildFunnelCard(t);
    final qualityCard = _buildQualityCard(t);

    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 5, child: funnelCard),
          const SizedBox(width: 16),
          Expanded(flex: 5, child: qualityCard),
        ],
      );
    }
    return Column(
      children: [
        funnelCard,
        const SizedBox(height: 16),
        qualityCard,
      ],
    );
  }

  Widget _buildFunnelCard(Map<String, dynamic> t) {
    final leads = (num.tryParse('${t['uniqueLeads'] ?? 0}') ?? 0).toInt();
    final kyc = (num.tryParse('${t['qualifiedDealers'] ?? 0}') ?? 0).toInt();
    final buyers = (num.tryParse('${t['orderingDealers'] ?? 0}') ?? 0).toInt();
    final maxVal = leads > 0 ? leads : 1;

    Widget stageBar(String title, int count, String pctLabel, Color color) {
      final ratio = (count / maxVal).clamp(0.03, 1.0);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                '$count ($pctLabel)',
                style: GoogleFonts.outfit(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: count == 0 ? 0 : ratio,
              minHeight: 10,
              color: color,
              backgroundColor: const Color(0xFFF1F5F9),
            ),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.filter_alt_rounded, size: 18, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              Text(
                'Acquisition Funnel Waterfall',
                style: GoogleFonts.outfit(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          stageBar('1. Unique Leads Captured', leads, '100%', const Color(0xFF0284C7)),
          const SizedBox(height: 12),
          stageBar(
            '2. KYC-Verified Dealers',
            kyc,
            '${t['leadToDealerPct'] ?? 0}% of leads',
            const Color(0xFF059669),
          ),
          const SizedBox(height: 12),
          stageBar(
            '3. Ordering Dealers (Buyers)',
            buyers,
            '${t['dealerToOrderPct'] ?? 0}% of KYC',
            const Color(0xFF7C3AED),
          ),
        ],
      ),
    );
  }

  Widget _buildQualityCard(Map<String, dynamic> t) {
    final qb = (t['qualityBreakdown'] is Map)
        ? Map<String, dynamic>.from(t['qualityBreakdown'] as Map)
        : <String, dynamic>{};
    final qualified = (num.tryParse('${qb['qualified'] ?? 0}') ?? 0).toInt();
    final lowIntent = (num.tryParse('${qb['low_intent'] ?? 0}') ?? 0).toInt();
    final unqualified = (num.tryParse('${qb['unqualified'] ?? 0}') ?? 0).toInt();
    final unknown = (num.tryParse('${qb['unknown'] ?? 0}') ?? 0).toInt();
    final total = qualified + lowIntent + unqualified + unknown;

    Widget chipStat(String label, int val, Color color) {
      final pct = total > 0 ? ((val / total) * 100).toStringAsFixed(0) : '0';
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF475569),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                '$val ($pct%)',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.fact_check_rounded, size: 18, color: Color(0xFF7C3AED)),
              const SizedBox(width: 8),
              Text(
                'Lead Form Intent & Quality Breakdown',
                style: GoogleFonts.outfit(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (total > 0)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 12,
                child: Row(
                  children: [
                    if (qualified > 0)
                      Expanded(flex: qualified, child: Container(color: const Color(0xFF10B981))),
                    if (lowIntent > 0)
                      Expanded(flex: lowIntent, child: Container(color: const Color(0xFFF59E0B))),
                    if (unqualified > 0)
                      Expanded(flex: unqualified, child: Container(color: const Color(0xFFEF4444))),
                    if (unknown > 0)
                      Expanded(flex: unknown, child: Container(color: const Color(0xFFCBD5E1))),
                  ],
                ),
              ),
            )
          else
            Container(
              height: 12,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          const SizedBox(height: 14),
          Row(
            children: [
              chipStat('Has Shop', qualified, const Color(0xFF059669)),
              const SizedBox(width: 8),
              chipStat('Planning', lowIntent, const Color(0xFFD97706)),
              const SizedBox(width: 8),
              chipStat('Farmer / Junk', unqualified, const Color(0xFFDC2626)),
              const SizedBox(width: 8),
              chipStat('Unclassified', unknown, const Color(0xFF64748B)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCampaignTable(
    BuildContext context,
    AttributionState state,
    List<Map<String, dynamic>> rows,
  ) {
    final t = state.totals;

    DataColumn sortableCol(String label, String key, {bool numeric = true}) {
      final isSorted = state.sortBy == key;
      return DataColumn(
        numeric: numeric,
        onSort: (_, asc) => context
            .read<AttributionBloc>()
            .add(AttributionSortChangedEvent(key, isSorted ? !state.sortAscending : false)),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: isSorted ? AppTheme.primaryColor : AppTheme.textPrimary,
              ),
            ),
            if (isSorted)
              Icon(
                state.sortAscending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                size: 13,
                color: AppTheme.primaryColor,
              ),
          ],
        ),
      );
    }

    Widget channelBadge(String ch) {
      final upper = ch.toUpperCase();
      Color color = const Color(0xFF0284C7);
      Color bg = const Color(0xFFE0F2FE);
      if (upper == 'APP_INSTALL') {
        color = const Color(0xFF7C3AED);
        bg = const Color(0xFFF3E8FF);
      } else if (upper == 'ORGANIC' || upper == 'REFERRAL') {
        color = const Color(0xFF475569);
        bg = const Color(0xFFF1F5F9);
      }
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
        child: Text(
          upper.replaceAll('_', ' '),
          style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w700, color: color),
        ),
      );
    }

    Widget roasBadge(dynamic roasRaw) {
      final roas = num.tryParse('$roasRaw') ?? 0;
      final color = roas >= 2
          ? const Color(0xFF059669)
          : (roas >= 0.5 ? const Color(0xFFD97706) : const Color(0xFF64748B));
      final bg = roas >= 2
          ? const Color(0xFFD1FAE5)
          : (roas >= 0.5 ? const Color(0xFFFEF3C7) : const Color(0xFFF1F5F9));
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
        child: Text(
          '${roas}x',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 12, color: color),
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Campaign Performance & Unit Economics',
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  '${rows.length} campaigns',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: Text(
                  'No campaigns match the current filter.',
                  style: GoogleFonts.outfit(color: AppTheme.textSecondary, fontSize: 13.5),
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                return Scrollbar(
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minWidth: constraints.maxWidth),
                      child: DataTable(
                        columnSpacing: 16,
                        horizontalMargin: 16,
                        headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                        columns: [
                          sortableCol('Campaign', 'campaignName', numeric: false),
                          const DataColumn(label: Text('Channel')),
                          sortableCol('Spend', 'spend'),
                          sortableCol('Leads', 'uniqueLeads'),
                          sortableCol('CPL', 'cpl'),
                          sortableCol('KYC', 'qualifiedDealers'),
                          sortableCol('L→D %', 'leadToDealerPct'),
                          sortableCol('₹/Dealer', 'costPerQualifiedDealer'),
                          sortableCol('Buyers', 'orderingDealers'),
                          sortableCol('D→O %', 'dealerToOrderPct'),
                          sortableCol('₹/Buyer', 'costPerOrderingDealer'),
                          sortableCol('Total GMV', 'totalGmv'),
                          sortableCol('Del. GMV', 'deliveredGmv'),
                          sortableCol('ROAS', 'deliveredRoas'),
                        ],
                        rows: [
                          ...rows.map((c) {
                            return DataRow(
                              cells: [
                                DataCell(
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 210),
                                    child: Text(
                                      (c['campaignName'] ?? c['campaignId'] ?? '-').toString(),
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.outfit(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12.5,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(channelBadge((c['channel'] ?? '-').toString())),
                                DataCell(Text(_formatInr(c['spend']), style: const TextStyle(fontSize: 12.5))),
                                DataCell(Text('${c['uniqueLeads'] ?? 0}', style: const TextStyle(fontSize: 12.5))),
                                DataCell(Text(_formatInr(c['cpl']), style: const TextStyle(fontSize: 12.5))),
                                DataCell(Text('${c['qualifiedDealers'] ?? 0}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
                                DataCell(Text('${c['leadToDealerPct'] ?? 0}%', style: const TextStyle(fontSize: 12.5))),
                                DataCell(Text(_formatInr(c['costPerQualifiedDealer']), style: const TextStyle(fontSize: 12.5))),
                                DataCell(Text('${c['orderingDealers'] ?? 0}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
                                DataCell(Text('${c['dealerToOrderPct'] ?? 0}%', style: const TextStyle(fontSize: 12.5))),
                                DataCell(Text(_formatInr(c['costPerOrderingDealer']), style: const TextStyle(fontSize: 12.5))),
                                DataCell(Text(_formatInr(c['totalGmv']), style: const TextStyle(fontSize: 12.5))),
                                DataCell(Text(_formatInr(c['deliveredGmv']), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
                                DataCell(roasBadge(c['deliveredRoas'] ?? 0)),
                              ],
                            );
                          }),
                          DataRow(
                            color: WidgetStateProperty.all(const Color(0xFFF0FDF4)),
                            cells: [
                              DataCell(Text('TOTAL', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 12.5, color: const Color(0xFF166534)))),
                              const DataCell(Text('—')),
                              DataCell(Text(_formatInr(t['spend']), style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 12.5))),
                              DataCell(Text('${t['uniqueLeads'] ?? 0}', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 12.5))),
                              DataCell(Text(_formatInr(t['cpl']), style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 12.5))),
                              DataCell(Text('${t['qualifiedDealers'] ?? 0}', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 12.5))),
                              DataCell(Text('${t['leadToDealerPct'] ?? 0}%', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 12.5))),
                              DataCell(Text(_formatInr(t['costPerQualifiedDealer']), style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 12.5))),
                              DataCell(Text('${t['orderingDealers'] ?? 0}', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 12.5))),
                              DataCell(Text('${t['dealerToOrderPct'] ?? 0}%', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 12.5))),
                              DataCell(Text(_formatInr(t['costPerOrderingDealer']), style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 12.5))),
                              DataCell(Text(_formatInr(t['totalGmv']), style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 12.5))),
                              DataCell(Text(_formatInr(t['deliveredGmv']), style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 12.5))),
                              DataCell(roasBadge(t['deliveredRoas'] ?? 0)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String? msg) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, size: 42, color: AppTheme.error),
          const SizedBox(height: 10),
          Text(
            msg ?? 'Failed to load attribution data.',
            style: GoogleFonts.outfit(color: AppTheme.error, fontSize: 13.5),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: () =>
                context.read<AttributionBloc>().add(const LoadAttributionEvent()),
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
