import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:kd_pannel/app_theme.dart';
import 'package:kd_pannel/core/auth/auth_service.dart';

class TelephonyLeaderboardWidget extends StatefulWidget {
  final int totalCalls;
  final int inboundCount;
  final int outboundCount;
  final int missedCount;
  final int totalTalkTimeSeconds;
  final int uniqueCustomersCount;
  final num answerRatePercent;
  final String timeframe;
  final List<dynamic> leaderboard;
  final String? selectedAgentId;
  final ValueChanged<String?>? onAgentSelected;
  final VoidCallback? onExportSummary;

  const TelephonyLeaderboardWidget({
    super.key,
    required this.totalCalls,
    required this.inboundCount,
    required this.outboundCount,
    required this.missedCount,
    required this.totalTalkTimeSeconds,
    this.uniqueCustomersCount = 0,
    this.answerRatePercent = 0,
    this.timeframe = 'Today',
    required this.leaderboard,
    this.selectedAgentId,
    this.onAgentSelected,
    this.onExportSummary,
  });

  @override
  State<TelephonyLeaderboardWidget> createState() => _TelephonyLeaderboardWidgetState();
}

class _TelephonyLeaderboardWidgetState extends State<TelephonyLeaderboardWidget> {
  // 'matrix' for full daily shift report table, 'leaderboard' for compact cards
  String _activeTab = 'matrix';

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '0s';
    final int hrs = seconds ~/ 3600;
    final int mins = (seconds % 3600) ~/ 60;
    final int secs = seconds % 60;
    if (hrs > 0) {
      return '${hrs}h ${mins}m';
    } else if (mins > 0) {
      return '${mins}m ${secs}s';
    }
    return '${secs}s';
  }

  String _formatTime(dynamic dateVal) {
    if (dateVal == null) return '--';
    try {
      final d = DateTime.tryParse(dateVal.toString());
      if (d == null) return '--';
      return DateFormat('hh:mm a').format(d.toLocal());
    } catch (_) {
      return '--';
    }
  }

  String _getInitials(String name) {
    final clean = name.replaceAll(RegExp(r'[^a-zA-Z\s]'), '').trim();
    if (clean.isEmpty) return 'AG';
    final parts = clean.split(RegExp(r'\s+'));
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return clean.substring(0, clean.length >= 2 ? 2 : 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final bool isAdmin = AuthService().currentUserRole == UserRole.admin;
    final String currentUserId = AuthService().currentUserId ?? '';

    final dynamic myStats = widget.leaderboard.firstWhere(
      (a) => a['agentId']?.toString() == currentUserId,
      orElse: () => null,
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 1. Executive KPI Metrics Ribbon ───────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 950;
                final tiles = [
                  _buildMetricTile(
                    title: 'Total Dials',
                    value: '${widget.totalCalls}',
                    icon: Icons.phone_rounded,
                    color: const Color(0xFF2563EB),
                    bgColor: const Color(0xFFEFF6FF),
                  ),
                  _buildMetricTile(
                    title: 'Outbound OBD',
                    value: '${widget.outboundCount}',
                    icon: Icons.call_made_rounded,
                    color: const Color(0xFF008069),
                    bgColor: const Color(0xFFF0FDF4),
                  ),
                  _buildMetricTile(
                    title: 'Inbound Calls',
                    value: '${widget.inboundCount}',
                    icon: Icons.call_received_rounded,
                    color: const Color(0xFF059669),
                    bgColor: const Color(0xFFECFDF5),
                  ),
                  _buildMetricTile(
                    title: 'Connect Rate',
                    value: widget.totalCalls > 0
                        ? '${widget.answerRatePercent.toStringAsFixed(1)}%'
                        : '0.0%',
                    icon: Icons.check_circle_outline_rounded,
                    color: const Color(0xFF0284C7),
                    bgColor: const Color(0xFFF0F9FF),
                  ),
                  _buildMetricTile(
                    title: 'Total Talk Time',
                    value: _formatDuration(widget.totalTalkTimeSeconds),
                    icon: Icons.timer_rounded,
                    color: const Color(0xFF7C3AED),
                    bgColor: const Color(0xFFF5F3FF),
                  ),
                  _buildMetricTile(
                    title: 'Unique Leads',
                    value: '${widget.uniqueCustomersCount}',
                    icon: Icons.people_alt_outlined,
                    color: const Color(0xFFD97706),
                    bgColor: const Color(0xFFFEF3C7),
                  ),
                  _buildMetricTile(
                    title: 'Missed Calls',
                    value: '${widget.missedCount}',
                    icon: Icons.phone_missed_rounded,
                    color: const Color(0xFFDC2626),
                    bgColor: const Color(0xFFFEF2F2),
                  ),
                ];

                if (isWide) {
                  return Row(
                    children: tiles
                        .map((t) => Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                child: t,
                              ),
                            ))
                        .toList(),
                  );
                } else {
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: tiles
                        .map((t) => SizedBox(
                              width: (constraints.maxWidth - 24) / 3,
                              child: t,
                            ))
                        .toList(),
                  );
                }
              },
            ),
          ),

          // ── 2. Report Controls Bar ─────────────────────────────────────────
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            color: const Color(0xFFF8FAFC),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.assessment_rounded, color: Color(0xFFD97706), size: 16),
                ),
                const SizedBox(width: 8),
                Text(
                  isAdmin
                      ? 'SALES TEAM SHIFT PERFORMANCE'
                      : 'MY TELEPHONY PERFORMANCE SCORECARD',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: const Color(0xFF334155),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF008069).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    widget.timeframe.isNotEmpty ? widget.timeframe : 'Selected Range',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF008069),
                    ),
                  ),
                ),

                const Spacer(),

                // Toggle View for Admin
                if (isAdmin) ...[
                  Container(
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    padding: const EdgeInsets.all(2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildTabButton(
                          title: 'Shift Matrix',
                          icon: Icons.table_chart_outlined,
                          isSelected: _activeTab == 'matrix',
                          onTap: () => setState(() => _activeTab = 'matrix'),
                        ),
                        _buildTabButton(
                          title: 'Podium Rank',
                          icon: Icons.emoji_events_outlined,
                          isSelected: _activeTab == 'leaderboard',
                          onTap: () => setState(() => _activeTab = 'leaderboard'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (widget.onExportSummary != null)
                    OutlinedButton.icon(
                      onPressed: widget.onExportSummary,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF008069),
                        side: const BorderSide(color: Color(0xFF008069)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.file_download_outlined, size: 14),
                      label: Text(
                        'Export Shift Report',
                        style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // ── 3. Content View: Shift Matrix Table or Leaderboard List ───────
          if (widget.leaderboard.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.phone_paused_outlined, size: 36, color: Color(0xFF94A3B8)),
                    const SizedBox(height: 8),
                    Text(
                      'No call activity recorded for ${widget.timeframe.isNotEmpty ? widget.timeframe : 'the selected date'}',
                      style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            )
          else if (_activeTab == 'matrix' && isAdmin)
            _buildShiftMatrixTable()
          else
            _buildLeaderboardList(isAdmin, myStats),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected ? const Color(0xFF008069) : const Color(0xFF64748B),
            ),
            const SizedBox(width: 5),
            Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Industrial Full Daily Shift Matrix Table ─────────────────────────────
  Widget _buildShiftMatrixTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 1050),
        child: DataTable(
          headingRowHeight: 40,
          dataRowMinHeight: 48,
          dataRowMaxHeight: 52,
          horizontalMargin: 20,
          columnSpacing: 20,
          headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
          columns: [
            DataColumn(
              label: SizedBox(
                width: 150,
                child: Text(
                  'SALES AGENT',
                  style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF475569)),
                ),
              ),
            ),
            DataColumn(
              label: SizedBox(
                width: 130,
                child: Text(
                  'DIALS (OBD / IN)',
                  style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF475569)),
                ),
              ),
            ),
            DataColumn(
              label: SizedBox(
                width: 120,
                child: Text(
                  'CONNECT RATE',
                  style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF475569)),
                ),
              ),
            ),
            DataColumn(
              label: SizedBox(
                width: 80,
                child: Text(
                  'TALK TIME',
                  style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF475569)),
                ),
              ),
            ),
            DataColumn(
              label: SizedBox(
                width: 120,
                child: Text(
                  'AVG DURATION (AHT)',
                  style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF475569)),
                ),
              ),
            ),
            DataColumn(
              label: SizedBox(
                width: 95,
                child: Text(
                  'SHIFT WINDOW',
                  style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF475569)),
                ),
              ),
            ),
            DataColumn(
              label: SizedBox(
                width: 105,
                child: Text(
                  'LEADS REACHED',
                  style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF475569)),
                ),
              ),
            ),
            DataColumn(
              label: SizedBox(
                width: 95,
                child: Text(
                  'ACTION',
                  style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF475569)),
                ),
              ),
            ),
          ],
          rows: widget.leaderboard.map((agent) {
            final String name = agent['agentName'] ?? 'Agent';
            final String phone = agent['agentPhone'] ?? '';
            final String? agentId = agent['agentId']?.toString();
            final int total = agent['totalCalls'] ?? 0;
            final int outbound = agent['outboundCalls'] ?? 0;
            final int inbound = agent['inboundCalls'] ?? 0;
            final int answered = agent['answeredCalls'] ?? 0;
            final num answerRate = agent['answerRatePercent'] ?? (total > 0 ? (answered / total * 100) : 0);
            final int talkSecs = agent['talkTimeSeconds'] ?? 0;
            final int ahtSecs = agent['avgHandleTimeSeconds'] ?? (answered > 0 ? (talkSecs ~/ answered) : 0);
            final int uniqueLeads = agent['uniqueCustomersCount'] ?? 0;
            final String firstCall = _formatTime(agent['firstCallAt']);
            final String lastCall = _formatTime(agent['lastCallAt']);
            final bool isSelected = widget.selectedAgentId != null && widget.selectedAgentId == agentId;

            return DataRow(
              color: isSelected
                  ? WidgetStateProperty.all(const Color(0xFF008069).withValues(alpha: 0.08))
                  : null,
              cells: [
                // 1. Agent Name & Phone
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: const Color(0xFF008069).withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _getInitials(name),
                          style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF008069)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            name,
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isSelected ? const Color(0xFF008069) : const Color(0xFF0F172A),
                            ),
                          ),
                          if (phone.isNotEmpty)
                            Text(
                              phone,
                              style: GoogleFonts.jetBrainsMono(fontSize: 11, color: const Color(0xFF64748B)),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 2. Dials
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$total',
                        style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '($outbound OBD • $inbound IN)',
                        style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),

                // 3. Connect Rate
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: answerRate >= 60
                          ? const Color(0xFFECFDF5)
                          : (answerRate >= 30 ? const Color(0xFFFEF3C7) : const Color(0xFFFEF2F2)),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: answerRate >= 60
                            ? const Color(0xFFA7F3D0)
                            : (answerRate >= 30 ? const Color(0xFFFDE68A) : const Color(0xFFFECACA)),
                      ),
                    ),
                    child: Text(
                      '${answered}/$total (${answerRate.toStringAsFixed(1)}%)',
                      style: GoogleFonts.outfit(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: answerRate >= 60
                            ? const Color(0xFF065F46)
                            : (answerRate >= 30 ? const Color(0xFF92400E) : const Color(0xFF991B1B)),
                      ),
                    ),
                  ),
                ),

                // 4. Talk Time
                DataCell(
                  Text(
                    _formatDuration(talkSecs),
                    style: GoogleFonts.outfit(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF15803D),
                    ),
                  ),
                ),

                // 5. Avg Call Duration (AHT)
                DataCell(
                  Text(
                    _formatDuration(ahtSecs),
                    style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
                  ),
                ),

                // 6. Shift Window (First & Last Call) — stacked to avoid horizontal overflow
                DataCell(
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.play_arrow_rounded, size: 12, color: Color(0xFF16A34A)),
                          const SizedBox(width: 3),
                          Text(
                            firstCall,
                            style: GoogleFonts.jetBrainsMono(fontSize: 10.5, color: const Color(0xFF334155), fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.stop_rounded, size: 12, color: Color(0xFFDC2626)),
                          const SizedBox(width: 3),
                          Text(
                            lastCall,
                            style: GoogleFonts.jetBrainsMono(fontSize: 10.5, color: const Color(0xFF334155), fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 7. Unique Leads Contacted
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.person_pin_circle_outlined, size: 14, color: Color(0xFFD97706)),
                      const SizedBox(width: 4),
                      Text(
                        '$uniqueLeads leads',
                        style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFFB45309)),
                      ),
                    ],
                  ),
                ),

                // 8. Action (1-Click Filter)
                DataCell(
                  SizedBox(
                    width: 95,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () {
                          if (widget.onAgentSelected != null) {
                            widget.onAgentSelected!(isSelected ? null : agentId);
                          }
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          backgroundColor: isSelected ? const Color(0xFF008069) : const Color(0xFFF1F5F9),
                          foregroundColor: isSelected ? Colors.white : const Color(0xFF334155),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        icon: Icon(
                          isSelected ? Icons.check_circle_rounded : Icons.filter_alt_outlined,
                          size: 13,
                        ),
                        label: Text(
                          isSelected ? 'Filtered' : 'Filter Calls',
                          style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── Compact Leaderboard List View ─────────────────────────────────────────
  Widget _buildLeaderboardList(bool isAdmin, dynamic myStats) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: isAdmin ? widget.leaderboard.take(6).length : (myStats != null ? 1 : 0),
      separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
      itemBuilder: (context, index) {
        final agent = isAdmin ? widget.leaderboard[index] : myStats;
        final rank = index + 1;
        final String name = agent['agentName'] ?? 'Agent';
        final String? agentId = agent['agentId']?.toString();
        final int calls = agent['totalCalls'] ?? 0;
        final int duration = agent['talkTimeSeconds'] ?? 0;
        final int answered = agent['answeredCalls'] ?? 0;
        final double answeredPercent = calls > 0 ? (answered / calls * 100) : 0;
        final bool isSelected = widget.selectedAgentId != null && widget.selectedAgentId == agentId;

        return InkWell(
          onTap: () {
            if (widget.onAgentSelected != null) {
              widget.onAgentSelected!(isSelected ? null : agentId);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            color: isSelected ? const Color(0xFF008069).withValues(alpha: 0.06) : Colors.transparent,
            child: Row(
              children: [
                // Rank Badge
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: rank == 1
                        ? const Color(0xFFFEF3C7)
                        : (rank == 2
                            ? const Color(0xFFF1F5F9)
                            : (rank == 3 ? const Color(0xFFFFEDD5) : Colors.transparent)),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: rank <= 3 ? const Color(0xFFD97706) : const Color(0xFFCBD5E1),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '#$rank',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: rank <= 3 ? const Color(0xFFB45309) : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Name & Stats
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            name,
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? const Color(0xFF008069) : const Color(0xFF0F172A),
                            ),
                          ),
                          if (isSelected) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFF008069),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'FILTERED',
                                style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$answered answered • $calls total calls (${answeredPercent.toStringAsFixed(0)}% pickup rate)',
                        style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),

                // Talk Time
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.timer_outlined, size: 13, color: Color(0xFF16A34A)),
                      const SizedBox(width: 4),
                      Text(
                        _formatDuration(duration),
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF15803D),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF64748B), fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  value,
                  style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
