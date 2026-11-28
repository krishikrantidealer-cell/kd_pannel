import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:kd_pannel/app_theme.dart';
import 'package:kd_pannel/core/network/api_client.dart';
import 'package:kd_pannel/core/responsive/responsive.dart';
import 'package:kd_pannel/util/export_helper.dart';

class LeadAttributionPage extends StatefulWidget {
  const LeadAttributionPage({super.key});

  @override
  State<LeadAttributionPage> createState() => _LeadAttributionPageState();
}

class _LeadAttributionPageState extends State<LeadAttributionPage> {
  bool _isLoading = true;
  bool _isSyncing = false;
  String? _error;
  String _selectedChannel = 'all';
  String _selectedDatePreset = '90d'; // 'today', 'yesterday', '7d', '30d', '90d', '365d', 'custom'
  DateTimeRange? _customDateRange;
  bool _liveOnly = true;

  Map<String, dynamic> _totals = {};
  List<Map<String, dynamic>> _campaigns = [];

  final _inrFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _fetchReport();
  }

  (String, String) _resolveDateStrings() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTime start;
    DateTime end = today;

    switch (_selectedDatePreset) {
      case 'today':
        start = today;
        break;
      case 'yesterday':
        start = today.subtract(const Duration(days: 1));
        end = start;
        break;
      case '7d':
        start = today.subtract(const Duration(days: 6));
        break;
      case '30d':
        start = today.subtract(const Duration(days: 29));
        break;
      case '365d':
        start = today.subtract(const Duration(days: 364));
        break;
      case 'all':
        start = DateTime(2024, 1, 1);
        break;
      case 'custom':
        if (_customDateRange != null) {
          start = _customDateRange!.start;
          end = _customDateRange!.end;
        } else {
          start = today.subtract(const Duration(days: 89));
        }
        break;
      case '90d':
      default:
        start = today.subtract(const Duration(days: 89));
        break;
    }

    return (
      DateFormat('yyyy-MM-dd').format(start),
      DateFormat('yyyy-MM-dd').format(end),
    );
  }

  Future<void> _pickCustomDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024, 1, 1),
      lastDate: now,
      initialDateRange: _customDateRange ??
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
    if (picked != null) {
      setState(() {
        _customDateRange = picked;
        _selectedDatePreset = 'custom';
      });
      await _fetchReport();
    }
  }

  Future<void> _fetchReport() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final (startStr, endStr) = _resolveDateStrings();

      final res = await ApiClient().get(
        '/attribution/report?startDate=$startStr&endDate=$endStr&channel=$_selectedChannel&liveOnly=$_liveOnly',
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && mounted) {
          setState(() {
            _totals = Map<String, dynamic>.from(data['totals'] ?? {});
            _campaigns = List<Map<String, dynamic>>.from(
              data['campaigns'] ?? [],
            );
            _isLoading = false;
          });
          return;
        }
      }
      throw Exception('Failed to load attribution report (${res.statusCode})');
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _syncMetaSpend() async {
    setState(() => _isSyncing = true);
    try {
      final (startStr, endStr) = _resolveDateStrings();
      final res = await ApiClient().post('/attribution/sync-spend', {
        'startDate': startStr,
        'endDate': endStr,
      });

      final data = jsonDecode(res.body);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              data['skipped'] == true
                  ? (data['message'] ?? 'Meta Marketing API token not configured.')
                  : 'Synced ${data['synced'] ?? 0} daily ad spend records from Meta.',
            ),
            backgroundColor:
                data['skipped'] == true ? Colors.orange : AppTheme.primaryColor,
          ),
        );
      }
      if (data['skipped'] != true) {
        await _fetchReport();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync error: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  String _csvCell(dynamic v) {
    final s = (v ?? '').toString().replaceAll('"', '""');
    return '"$s"';
  }

  void _exportCsv() {
    if (_campaigns.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No campaign rows to export.')),
      );
      return;
    }

    final (startStr, endStr) = _resolveDateStrings();
    final buf = StringBuffer();
    buf.writeln(
      'Campaign,Channel,Spend,Unique Leads,CPL,KYC Dealers,Lead to Dealer %,Cost per Dealer,Ordering Dealers,Dealer to Order %,Orders,Cost per Buyer,Total GMV,Delivered GMV,Delivered ROAS,RTO %',
    );

    for (final c in _campaigns) {
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

    buf.writeln([
      _csvCell('TOTAL ($startStr to $endStr)'),
      _csvCell(_selectedChannel),
      _totals['spend'] ?? 0,
      _totals['uniqueLeads'] ?? 0,
      _totals['cpl'] ?? 0,
      _totals['qualifiedDealers'] ?? 0,
      _totals['leadToDealerPct'] ?? 0,
      _totals['costPerQualifiedDealer'] ?? 0,
      _totals['orderingDealers'] ?? 0,
      _totals['dealerToOrderPct'] ?? 0,
      _totals['ordersCount'] ?? 0,
      _totals['costPerOrderingDealer'] ?? 0,
      _totals['totalGmv'] ?? 0,
      _totals['deliveredGmv'] ?? 0,
      _totals['deliveredRoas'] ?? 0,
      _totals['rtoPct'] ?? 0,
    ].join(','));

    downloadCsv(
      buf.toString(),
      'lead_attribution_${startStr}_to_$endStr.csv',
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Campaign attribution CSV downloaded!'),
        backgroundColor: AppTheme.primaryColor,
      ),
    );
  }

  String _formatInr(dynamic value) {
    final numVal = num.tryParse(value?.toString() ?? '0') ?? 0;
    return _inrFormat.format(numVal);
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Lead Attribution & ROAS',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: AppTheme.textPrimary,
              ),
            ),
            Text(
              'First-touch attribution across Meta Lead Forms & Dealer App Installs',
              style: GoogleFonts.outfit(
                fontSize: 11.5,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: OutlinedButton.icon(
              onPressed: _campaigns.isEmpty ? null : _exportCsv,
              icon: const Icon(Icons.download_rounded, size: 16),
              label: Text(
                'Export CSV',
                style: GoogleFonts.outfit(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0284C7),
                side: const BorderSide(color: Color(0xFF0284C7)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: OutlinedButton.icon(
              onPressed: _isSyncing ? null : _syncMetaSpend,
              icon: _isSyncing
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync_rounded, size: 16),
              label: Text(
                'Sync Meta Spend',
                style: GoogleFonts.outfit(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryColor,
                side: const BorderSide(color: AppTheme.primaryColor),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _fetchReport,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Report',
          ),
          const SizedBox(width: 8),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppTheme.lightBorderColor),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            )
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _error!,
                    style: GoogleFonts.outfit(color: AppTheme.error),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _fetchReport,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _fetchReport,
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isDesktop ? 24 : 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFiltersBar(),
                    const SizedBox(height: 20),
                    _buildKpiStrip(isDesktop),
                    const SizedBox(height: 20),
                    _buildCampaignTable(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildFiltersBar() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final ch in const [
          {'id': 'all', 'label': 'All Channels'},
          {'id': 'lead_form', 'label': 'Lead Forms'},
          {'id': 'app_install', 'label': 'App Installs'},
        ])
          ChoiceChip(
            label: Text(
              ch['label']!,
              style: GoogleFonts.outfit(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: _selectedChannel == ch['id']
                    ? Colors.white
                    : AppTheme.textPrimary,
              ),
            ),
            selected: _selectedChannel == ch['id'],
            selectedColor: AppTheme.primaryColor,
            backgroundColor: Colors.white,
            onSelected: (_) {
              setState(() => _selectedChannel = ch['id']!);
              _fetchReport();
            },
          ),
        const SizedBox(width: 8),
        FilterChip(
          label: Text(
            'Live Campaigns Only',
            style: GoogleFonts.outfit(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: _liveOnly ? Colors.white : AppTheme.textPrimary,
            ),
          ),
          selected: _liveOnly,
          selectedColor: const Color(0xFF059669),
          checkmarkColor: Colors.white,
          backgroundColor: Colors.white,
          onSelected: (val) {
            setState(() => _liveOnly = val);
            _fetchReport();
          },
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: DropdownButton<String>(
            value: _selectedDatePreset,
            underline: const SizedBox.shrink(),
            isDense: true,
            items: [
              const DropdownMenuItem(value: 'today', child: Text('Today')),
              const DropdownMenuItem(value: 'yesterday', child: Text('Yesterday')),
              const DropdownMenuItem(value: '7d', child: Text('Last 7 Days')),
              const DropdownMenuItem(value: '30d', child: Text('Last 30 Days')),
              const DropdownMenuItem(value: '90d', child: Text('Last 90 Days')),
              const DropdownMenuItem(value: '365d', child: Text('Last 12 Months')),
              const DropdownMenuItem(value: 'all', child: Text('All Time')),
              DropdownMenuItem(
                value: 'custom',
                child: Text(
                  _customDateRange != null
                      ? '${DateFormat('d MMM').format(_customDateRange!.start)} – ${DateFormat('d MMM').format(_customDateRange!.end)}'
                      : 'Custom Range...',
                ),
              ),
            ],
            onChanged: (val) async {
              if (val == 'custom') {
                await _pickCustomDateRange();
              } else if (val != null) {
                setState(() => _selectedDatePreset = val);
                await _fetchReport();
              }
            },
          ),
        ),
        if (_selectedDatePreset == 'custom')
          TextButton.icon(
            onPressed: _pickCustomDateRange,
            icon: const Icon(Icons.date_range_rounded, size: 16),
            label: const Text('Change'),
          ),
      ],
    );
  }

  Widget _buildKpiStrip(bool isDesktop) {
    final cards = [
      {
        'label': 'Total Spend',
        'value': _formatInr(_totals['spend'] ?? 0),
        'sub': 'CPL: ${_formatInr(_totals['cpl'] ?? 0)}',
        'color': const Color(0xFF475569),
      },
      {
        'label': 'Unique Leads',
        'value': '${_totals['uniqueLeads'] ?? 0}',
        'sub': 'Raw: ${_totals['rawLeads'] ?? 0}',
        'color': const Color(0xFF0284C7),
      },
      {
        'label': 'Qualified Dealers (KYC)',
        'value': '${_totals['qualifiedDealers'] ?? 0}',
        'sub': '${_totals['leadToDealerPct'] ?? 0}% conv • ${_formatInr(_totals['costPerQualifiedDealer'] ?? 0)}/dealer',
        'color': const Color(0xFF059669),
      },
      {
        'label': 'Ordering Dealers',
        'value': '${_totals['orderingDealers'] ?? 0}',
        'sub': '${_totals['dealerToOrderPct'] ?? 0}% of KYC • ${_formatInr(_totals['costPerOrderingDealer'] ?? 0)}/buyer',
        'color': const Color(0xFF7C3AED),
      },
      {
        'label': 'Delivered GMV & ROAS',
        'value': _formatInr(_totals['deliveredGmv'] ?? 0),
        'sub': '${_totals['deliveredRoas'] ?? 0}x ROAS • RTO: ${_totals['rtoPct'] ?? 0}%',
        'color': const Color(0xFFD97706),
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isDesktop ? 5 : 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: isDesktop ? 1.85 : 1.6,
      ),
      itemCount: cards.length,
      itemBuilder: (_, idx) {
        final c = cards[idx];
        final color = c['color'] as Color;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                c['label'] as String,
                style: GoogleFonts.outfit(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(
                c['value'] as String,
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                c['sub'] as String,
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  color: const Color(0xFF64748B),
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

  Widget _buildCampaignTable() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Funnel by Campaign & Channel',
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          if (_campaigns.isEmpty)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: Text(
                  'No attributed touches or ad spend recorded in this date window yet.\nNew Meta Lead Form & CTWA touches will appear here automatically.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    color: AppTheme.textSecondary,
                    fontSize: 13.5,
                  ),
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
                        columnSpacing: 18,
                        horizontalMargin: 16,
                        headingRowColor: WidgetStateProperty.all(
                          const Color(0xFFF8FAFC),
                        ),
                        columns: const [
                          DataColumn(label: Text('Campaign')),
                          DataColumn(label: Text('Channel')),
                          DataColumn(label: Text('Spend'), numeric: true),
                          DataColumn(label: Text('Leads'), numeric: true),
                          DataColumn(label: Text('CPL'), numeric: true),
                          DataColumn(label: Text('KYC'), numeric: true),
                          DataColumn(label: Text('L→D %'), numeric: true),
                          DataColumn(label: Text('₹/Dealer'), numeric: true),
                          DataColumn(label: Text('Buyers'), numeric: true),
                          DataColumn(label: Text('D→O %'), numeric: true),
                          DataColumn(label: Text('₹/Buyer'), numeric: true),
                          DataColumn(label: Text('Total GMV'), numeric: true),
                          DataColumn(label: Text('Del. GMV'), numeric: true),
                          DataColumn(label: Text('ROAS'), numeric: true),
                        ],
                        rows: _campaigns.map((c) {
                          return DataRow(
                            cells: [
                              DataCell(
                                ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 220),
                                  child: Text(
                                    (c['campaignName'] ?? c['campaignId'] ?? '-').toString(),
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 12.5),
                                  ),
                                ),
                              ),
                              DataCell(Text((c['channel'] ?? '-').toString().toUpperCase(), style: const TextStyle(fontSize: 11.5))),
                              DataCell(Text(_formatInr(c['spend']), style: const TextStyle(fontSize: 12.5))),
                              DataCell(Text('${c['uniqueLeads'] ?? 0}', style: const TextStyle(fontSize: 12.5))),
                              DataCell(Text(_formatInr(c['cpl']), style: const TextStyle(fontSize: 12.5))),
                              DataCell(Text('${c['qualifiedDealers'] ?? 0}', style: const TextStyle(fontSize: 12.5))),
                              DataCell(Text('${c['leadToDealerPct'] ?? 0}%', style: const TextStyle(fontSize: 12.5))),
                              DataCell(Text(_formatInr(c['costPerQualifiedDealer']), style: const TextStyle(fontSize: 12.5))),
                              DataCell(Text('${c['orderingDealers'] ?? 0}', style: const TextStyle(fontSize: 12.5))),
                              DataCell(Text('${c['dealerToOrderPct'] ?? 0}%', style: const TextStyle(fontSize: 12.5))),
                              DataCell(Text(_formatInr(c['costPerOrderingDealer']), style: const TextStyle(fontSize: 12.5))),
                              DataCell(Text(_formatInr(c['totalGmv']), style: const TextStyle(fontSize: 12.5))),
                              DataCell(Text(_formatInr(c['deliveredGmv']), style: const TextStyle(fontSize: 12.5))),
                              DataCell(
                                Text(
                                  '${c['deliveredRoas'] ?? 0}x',
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12.5,
                                    color: (num.tryParse('${c['deliveredRoas']}') ?? 0) >= 2
                                        ? const Color(0xFF059669)
                                        : AppTheme.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
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
}
