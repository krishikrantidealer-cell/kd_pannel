import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/call_logs_bloc.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/call_logs_event.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/call_logs_state.dart';

class FollowUpsAttentionBanner extends StatelessWidget {
  const FollowUpsAttentionBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CallLogsBloc, CallLogsState>(
      buildWhen: (previous, current) =>
          previous.followUpsSummary != current.followUpsSummary ||
          previous.isLoadingFollowUps != current.isLoadingFollowUps ||
          previous.selectedFollowUpBucket != current.selectedFollowUpBucket,
      builder: (context, state) {
        final summary = state.followUpsSummary;
        final int overdue = summary['overdue'] ?? 0;
        final int today = summary['today'] ?? 0;
        final int upcoming = summary['upcoming'] ?? 0;
        final int totalPending = summary['totalPending'] ?? (overdue + today + upcoming);

        if (totalPending == 0) {
          return const SizedBox.shrink();
        }

        final bool hasOverdue = overdue > 0;

        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: hasOverdue ? const Color(0xFFFFF1F2) : const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: hasOverdue ? const Color(0xFFFECDD3) : const Color(0xFFFDE68A),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: (hasOverdue ? const Color(0xFFE11D48) : const Color(0xFFD97706)).withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              children: [
                // Glowing notification icon
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (hasOverdue ? const Color(0xFFE11D48) : const Color(0xFFD97706)).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    hasOverdue ? Icons.notification_important_rounded : Icons.alarm_on_rounded,
                    color: hasOverdue ? const Color(0xFFE11D48) : const Color(0xFFD97706),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),

                // Main Info Text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            hasOverdue
                                ? 'Urgent: $overdue Overdue Callback${overdue > 1 ? 's' : ''} Pending'
                                : '$totalPending Scheduled Callback${totalPending > 1 ? 's' : ''} Pending',
                            style: GoogleFonts.outfit(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: hasOverdue ? const Color(0xFF9F1239) : const Color(0xFF92400E),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: (hasOverdue ? const Color(0xFFE11D48) : const Color(0xFFD97706)).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Auto-Resolves On Dial',
                              style: GoogleFonts.outfit(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: hasOverdue ? const Color(0xFFBE123C) : const Color(0xFFB45309),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Customer callbacks scheduled during call disposition. Calls answered later resolve automatically.',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: hasOverdue ? const Color(0xFFBE123C) : const Color(0xFFB45309),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),

                // Interactive Metric Chips
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (overdue > 0)
                      _buildChip(
                        label: '$overdue Overdue',
                        icon: Icons.error_outline_rounded,
                        color: const Color(0xFFE11D48),
                        bgColor: const Color(0xFFFFE4E6),
                        onTap: () => _showFollowUpsDialog(context, initialBucket: 'overdue'),
                      ),
                    if (today > 0)
                      _buildChip(
                        label: '$today Today',
                        icon: Icons.today_rounded,
                        color: const Color(0xFFD97706),
                        bgColor: const Color(0xFFFEF3C7),
                        onTap: () => _showFollowUpsDialog(context, initialBucket: 'today'),
                      ),
                    if (upcoming > 0)
                      _buildChip(
                        label: '$upcoming Upcoming',
                        icon: Icons.calendar_month_outlined,
                        color: const Color(0xFF2563EB),
                        bgColor: const Color(0xFFDBEAFE),
                        onTap: () => _showFollowUpsDialog(context, initialBucket: 'upcoming'),
                      ),
                  ],
                ),
                const SizedBox(width: 14),

                // Review & Action Button
                ElevatedButton.icon(
                  onPressed: () => _showFollowUpsDialog(context, initialBucket: hasOverdue ? 'overdue' : 'all'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: hasOverdue ? const Color(0xFFBE123C) : const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.phone_callback_rounded, size: 15),
                  label: Text(
                    'Review Callbacks',
                    style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildChip({
    required String label,
    required IconData icon,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void _showFollowUpsDialog(BuildContext context, {String initialBucket = 'all'}) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) => _FollowUpsQueueModal(initialBucket: initialBucket),
    );
  }
}

class _FollowUpsQueueModal extends StatefulWidget {
  final String initialBucket;
  const _FollowUpsQueueModal({required this.initialBucket});

  @override
  State<_FollowUpsQueueModal> createState() => _FollowUpsQueueModalState();
}

class _FollowUpsQueueModalState extends State<_FollowUpsQueueModal> {
  late String _currentBucket;

  @override
  void initState() {
    super.initState();
    _currentBucket = widget.initialBucket;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bloc = context.read<CallLogsBloc>();
      bloc.add(FetchFollowUpsEvent(bucket: _currentBucket, agentId: bloc.state.selectedAgentId));
    });
  }

  void _switchBucket(String bucket) {
    if (_currentBucket == bucket) return;
    setState(() => _currentBucket = bucket);
    final bloc = context.read<CallLogsBloc>();
    bloc.add(FetchFollowUpsEvent(bucket: bucket, agentId: bloc.state.selectedAgentId));
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CallLogsBloc, CallLogsState>(
      builder: (context, state) {
        final summary = state.followUpsSummary;
        final int overdue = summary['overdue'] ?? 0;
        final int today = summary['today'] ?? 0;
        final int upcoming = summary['upcoming'] ?? 0;
        final int totalPending = summary['totalPending'] ?? (overdue + today + upcoming);

        final items = state.followUpItems;
        final isLoading = state.isLoadingFollowUps;

        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: Colors.white,
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820, maxHeight: 680),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Modal Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                  decoration: const BoxDecoration(
                    color: Color(0xFF0F172A),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF008069).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.headset_mic_rounded, color: Color(0xFF2DD4BF), size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Scheduled Follow-ups & Callbacks Queue',
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Prioritized callbacks with 1-click dialer and auto-resolution',
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                color: const Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                        tooltip: 'Close',
                      ),
                    ],
                  ),
                ),

                // Filter Tabs Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Row(
                    children: [
                      _buildTabChip('all', 'All ($totalPending)', null),
                      const SizedBox(width: 8),
                      _buildTabChip('overdue', 'Overdue ($overdue)', const Color(0xFFE11D48)),
                      const SizedBox(width: 8),
                      _buildTabChip('today', 'Today ($today)', const Color(0xFFD97706)),
                      const SizedBox(width: 8),
                      _buildTabChip('upcoming', 'Upcoming ($upcoming)', const Color(0xFF2563EB)),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded, size: 18, color: Color(0xFF64748B)),
                        tooltip: 'Refresh queue',
                        onPressed: () {
                          context.read<CallLogsBloc>().add(
                            FetchFollowUpsEvent(bucket: _currentBucket, agentId: state.selectedAgentId),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                // Content Area
                Expanded(
                  child: isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF008069)),
                          ),
                        )
                      : items.isEmpty
                          ? _buildEmptyState()
                          : ListView.separated(
                              padding: const EdgeInsets.all(20),
                              itemCount: items.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final item = items[index];
                                return _buildFollowUpCard(context, item);
                              },
                            ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTabChip(String bucketKey, String label, Color? accentColor) {
    final isSelected = _currentBucket == bucketKey;
    return InkWell(
      onTap: () => _switchBucket(bucketKey),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? (accentColor != null ? accentColor.withValues(alpha: 0.12) : const Color(0xFF0F172A))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? (accentColor ?? const Color(0xFF0F172A))
                : const Color(0xFFCBD5E1),
            width: isSelected ? 1.4 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? (accentColor ?? Colors.white)
                : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFECFDF5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_outline_rounded, size: 40, color: Color(0xFF10B981)),
            ),
            const SizedBox(height: 14),
            Text(
              'All Caught Up!',
              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
            ),
            const SizedBox(height: 6),
            Text(
              'No pending callbacks in this category. Great job keeping in sync with your leads!',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFollowUpCard(BuildContext context, dynamic item) {
    if (item is! Map) return const SizedBox.shrink();
    final map = Map<String, dynamic>.from(item);

    final String customerName = (map['customerName'] ?? '').toString().trim();
    final String customerPhone = (map['customerPhone'] ?? '').toString().trim();
    final String agentName = (map['agentName'] ?? 'Unassigned').toString();
    final String bucket = (map['bucket'] ?? 'upcoming').toString().toLowerCase();
    final String notes = (map['followUpNote'] ?? map['notes'] ?? '').toString().trim();
    final String disposition = (map['userDisposition'] ?? '').toString().trim();
    final String logId = (map['_id'] ?? map['callLogId'] ?? '').toString();

    // Parse scheduled date
    DateTime? dueDate;
    final rawDate = map['followUpDate'];
    if (rawDate != null) {
      dueDate = DateTime.tryParse(rawDate.toString());
    }

    final Color badgeColor;
    final Color badgeBg;
    final String statusLabel;

    if (bucket == 'overdue') {
      badgeColor = const Color(0xFFE11D48);
      badgeBg = const Color(0xFFFFE4E6);
      statusLabel = '🔴 OVERDUE';
    } else if (bucket == 'today') {
      badgeColor = const Color(0xFFD97706);
      badgeBg = const Color(0xFFFEF3C7);
      statusLabel = '🟠 DUE TODAY';
    } else {
      badgeColor = const Color(0xFF2563EB);
      badgeBg = const Color(0xFFDBEAFE);
      statusLabel = '🔵 UPCOMING';
    }

    String formattedDue = 'Due date not set';
    if (dueDate != null) {
      formattedDue = DateFormat('MMM dd, yyyy • hh:mm a').format(dueDate.toLocal());
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: bucket == 'overdue' ? const Color(0xFFFECDD3) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Customer Info & Status Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFF008069).withValues(alpha: 0.1),
                child: Text(
                  customerName.isNotEmpty
                      ? customerName[0].toUpperCase()
                      : (customerPhone.isNotEmpty ? customerPhone.substring(customerPhone.length - 1) : '?'),
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF008069),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            customerName.isNotEmpty ? customerName : 'Lead ($customerPhone)',
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF0F172A),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: badgeBg,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            statusLabel,
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: badgeColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.phone_outlined, size: 12, color: Color(0xFF64748B)),
                        const SizedBox(width: 4),
                        SelectableText(
                          customerPhone,
                          style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF475569)),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: customerPhone));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Phone number copied to clipboard'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          },
                          child: const Icon(Icons.copy_rounded, size: 12, color: Color(0xFF94A3B8)),
                        ),
                        const SizedBox(width: 14),
                        const Icon(Icons.person_outline_rounded, size: 12, color: Color(0xFF64748B)),
                        const SizedBox(width: 4),
                        Text(
                          'Agent: $agentName',
                          style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF475569)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Action Buttons
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Mark Completed Button
                  OutlinedButton.icon(
                    onPressed: () {
                      context.read<CallLogsBloc>().add(CompleteFollowUpEvent(logId));
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF059669),
                      side: const BorderSide(color: Color(0xFFA7F3D0)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.check_circle_outline_rounded, size: 15),
                    label: Text(
                      'Mark Done',
                      style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // 1-Click Dial Button
                  ElevatedButton.icon(
                    onPressed: customerPhone.isEmpty
                        ? null
                        : () {
                            context.read<CallLogsBloc>().add(
                              TriggerOutboundCallEvent(
                                customerPhone: customerPhone,
                                customerName: customerName,
                                callMode: 'call',
                              ),
                            );
                            Navigator.of(context).pop();
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF008069),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.call_rounded, size: 15),
                    label: Text(
                      'Call Now',
                      style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 8),

          // Bottom Meta Row: Due Date & Notes
          Row(
            children: [
              Icon(Icons.schedule_rounded, size: 13, color: badgeColor),
              const SizedBox(width: 5),
              Text(
                formattedDue,
                style: GoogleFonts.outfit(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: badgeColor,
                ),
              ),
              if (disposition.isNotEmpty) ...[
                const SizedBox(width: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Disposition: $disposition',
                    style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF475569)),
                  ),
                ),
              ],
              if (notes.isNotEmpty) ...[
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Note: "$notes"',
                    style: GoogleFonts.outfit(
                      fontSize: 11.5,
                      fontStyle: FontStyle.italic,
                      color: const Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
