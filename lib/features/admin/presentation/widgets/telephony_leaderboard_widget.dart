import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kd_pannel/app_theme.dart';
import 'package:kd_pannel/core/auth/auth_service.dart';

class TelephonyLeaderboardWidget extends StatelessWidget {
  final int totalCalls;
  final int inboundCount;
  final int outboundCount;
  final int missedCount;
  final int totalTalkTimeSeconds;
  final List<dynamic> leaderboard;

  const TelephonyLeaderboardWidget({
    super.key,
    required this.totalCalls,
    required this.inboundCount,
    required this.outboundCount,
    required this.missedCount,
    required this.totalTalkTimeSeconds,
    required this.leaderboard,
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
    final bool isAdmin = !AuthService().isSales;
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
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // KPI Metric Ribbon
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    title: 'Total Calls',
                    value: '$totalCalls',
                    icon: Icons.phone_rounded,
                    color: const Color(0xFF2563EB),
                    bgColor: const Color(0xFFEFF6FF),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMetricTile(
                    title: 'Inbound Calls',
                    value: '$inboundCount',
                    icon: Icons.call_received_rounded,
                    color: const Color(0xFF10B981),
                    bgColor: const Color(0xFFECFDF5),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMetricTile(
                    title: 'Outbound OBD',
                    value: '$outboundCount',
                    icon: Icons.call_made_rounded,
                    color: const Color(0xFF008069),
                    bgColor: const Color(0xFFF0FDF4),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMetricTile(
                    title: 'Total Talk Time',
                    value: _formatDuration(totalTalkTimeSeconds),
                    icon: Icons.timer_rounded,
                    color: const Color(0xFF8B5CF6),
                    bgColor: const Color(0xFFFAF5FF),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMetricTile(
                    title: 'Missed Calls',
                    value: '$missedCount',
                    icon: Icons.phone_missed_rounded,
                    color: const Color(0xFFEF4444),
                    bgColor: const Color(0xFFFEF2F2),
                  ),
                ),
              ],
            ),
          ),

          // Leaderboard Table for Admin / Scorecard for Sales
          if (leaderboard.isNotEmpty) ...[
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              color: const Color(0xFFF8FAFC),
              child: Row(
                children: [
                  const Icon(Icons.emoji_events_rounded, color: Color(0xFFD97706), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    isAdmin ? 'TELEPHONY TEAM LEADERBOARD' : 'MY TELEPHONY PERFORMANCE SCORECARD',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      color: const Color(0xFF1E293B),
                    ),
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
                final int calls = agent['totalCalls'] ?? 0;
                final int duration = agent['talkTimeSeconds'] ?? 0;
                final int answered = agent['answeredCalls'] ?? 0;
                final double answeredPercent = calls > 0 ? (answered / calls * 100) : 0;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      // Rank Badge
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: rank == 1
                              ? const Color(0xFFFEF3C7)
                              : (rank == 2
                                  ? const Color(0xFFF1F5F9)
                                  : (rank == 3 ? const Color(0xFFFFEDD5) : Colors.transparent)),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: rank <= 3 ? const Color(0xFFD97706) : Colors.grey.shade300,
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

                      // Name
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              '$answered answered of $calls calls (${answeredPercent.toStringAsFixed(0)}% pickup rate)',
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
                            const Icon(Icons.timer_outlined, size: 14, color: Color(0xFF16A34A)),
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
