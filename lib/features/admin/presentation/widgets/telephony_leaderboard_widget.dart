import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kd_pannel/core/auth/auth_service.dart';

class TelephonyLeaderboardWidget extends StatelessWidget {
  final int totalCalls;
  final int inboundCount;
  final int outboundCount;
  final int missedCount;
  final int totalTalkTimeSeconds;
  final List<dynamic> leaderboard;
  final String? selectedAgentId;
  final ValueChanged<String?>? onAgentSelected;

  const TelephonyLeaderboardWidget({
    super.key,
    required this.totalCalls,
    required this.inboundCount,
    required this.outboundCount,
    required this.missedCount,
    required this.totalTalkTimeSeconds,
    required this.leaderboard,
    this.selectedAgentId,
    this.onAgentSelected,
  });

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

  @override
  Widget build(BuildContext context) {
    final bool isAdmin = AuthService().currentUserRole == UserRole.admin;
    final String currentUserId = AuthService().currentUserId ?? '';

    final dynamic myStats = leaderboard.firstWhere(
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
          // KPI Metric Ribbon
          Padding(
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 700;
                final tiles = [
                  _buildMetricTile(
                    title: 'Total Calls',
                    value: '$totalCalls',
                    icon: Icons.phone_rounded,
                    color: const Color(0xFF2563EB),
                    bgColor: const Color(0xFFEFF6FF),
                  ),
                  _buildMetricTile(
                    title: 'Inbound Calls',
                    value: '$inboundCount',
                    icon: Icons.call_received_rounded,
                    color: const Color(0xFF059669),
                    bgColor: const Color(0xFFECFDF5),
                  ),
                  _buildMetricTile(
                    title: 'Outbound OBD',
                    value: '$outboundCount',
                    icon: Icons.call_made_rounded,
                    color: const Color(0xFF008069),
                    bgColor: const Color(0xFFF0FDF4),
                  ),
                  _buildMetricTile(
                    title: 'Total Talk Time',
                    value: _formatDuration(totalTalkTimeSeconds),
                    icon: Icons.timer_rounded,
                    color: const Color(0xFF7C3AED),
                    bgColor: const Color(0xFFF5F3FF),
                  ),
                  _buildMetricTile(
                    title: 'Missed Calls',
                    value: '$missedCount',
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
                              width: (constraints.maxWidth - 16) / 2,
                              child: t,
                            ))
                        .toList(),
                  );
                }
              },
            ),
          ),

          // Leaderboard Table for Admin / Scorecard for Sales
          if (leaderboard.isNotEmpty) ...[
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              color: const Color(0xFFF8FAFC),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.emoji_events_rounded, color: Color(0xFFD97706), size: 16),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isAdmin ? 'SALES TEAM TELEPHONY LEADERBOARD' : 'MY TELEPHONY PERFORMANCE SCORECARD',
                    style: GoogleFonts.outfit(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      color: const Color(0xFF334155),
                    ),
                  ),
                  const Spacer(),
                  if (isAdmin)
                    Text(
                      'Click an agent to filter',
                      style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                    ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),

            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: isAdmin ? leaderboard.take(5).length : (myStats != null ? 1 : 0),
              separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
              itemBuilder: (context, index) {
                final agent = isAdmin ? leaderboard[index] : myStats;
                final rank = index + 1;
                final String name = agent['agentName'] ?? 'Agent';
                final String? agentId = agent['agentId']?.toString();
                final int calls = agent['totalCalls'] ?? 0;
                final int duration = agent['talkTimeSeconds'] ?? 0;
                final int answered = agent['answeredCalls'] ?? 0;
                final double answeredPercent = calls > 0 ? (answered / calls * 100) : 0;
                final bool isSelected = selectedAgentId != null && selectedAgentId == agentId;

                return InkWell(
                  onTap: () {
                    if (onAgentSelected != null) {
                      onAgentSelected!(isSelected ? null : agentId);
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
            ),
          ],
        ],
      ),
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
