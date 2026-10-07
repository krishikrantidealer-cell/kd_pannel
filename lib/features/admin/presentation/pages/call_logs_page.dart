import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:web/web.dart' as web;
import 'package:kd_pannel/app_theme.dart';
import 'package:kd_pannel/core/auth/auth_service.dart';
import 'package:kd_pannel/core/network/api_client.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/call_logs_bloc.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/call_logs_event.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/call_logs_state.dart';
import 'package:kd_pannel/features/admin/presentation/widgets/call_disposition_dialog.dart';
import 'package:kd_pannel/features/admin/presentation/widgets/telephony_leaderboard_widget.dart';

class CallLogsPage extends StatefulWidget {
  const CallLogsPage({super.key});

  @override
  State<CallLogsPage> createState() => _CallLogsPageState();
}

class _CallLogsPageState extends State<CallLogsPage> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  final Set<String> _selectedLogIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CallLogsBloc>().add(const FetchCallLogsEvent(page: 1));
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _exportToCsv(List<dynamic> logs) async {
    if (logs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No call logs available to export')),
      );
      return;
    }

    final StringBuffer csv = StringBuffer();
    csv.writeln('Date,Direction,Customer Name,Customer Phone,Sales Agent,Status,Duration (Seconds),Disposition,Follow Up Date,ACW Notes,Recording URL');

    for (final log in logs) {
      final contact = log['contactId'];
      final contactName = (contact is Map ? contact['name'] : '')?.toString().replaceAll(',', ' ') ?? '';
      final customerPhone = (log['customerPhone'] ?? '').toString();
      final agent = log['agentId'];
      final agentName = (agent is Map ? '${agent['firstName'] ?? ''} ${agent['lastName'] ?? ''}'.trim() : '').replaceAll(',', ' ');
      final direction = (log['direction'] ?? log['type'] ?? 'outbound').toString();
      final status = (log['status'] ?? '').toString();
      final duration = (log['durationSeconds'] ?? 0).toString();
      final userDisposition = (log['userDisposition'] ?? '').toString().replaceAll(',', ' ');
      final followUpDate = (log['followUpDate'] ?? '').toString();
      final notes = (log['notes'] ?? '').toString().replaceAll('\n', ' ').replaceAll(',', ' ');
      final recordingUrl = (log['recordingUrl'] ?? '').toString();
      final createdAt = (log['createdAt'] ?? '').toString();

      csv.writeln('"$createdAt","$direction","$contactName","$customerPhone","$agentName","$status","$duration","$userDisposition","$followUpDate","$notes","$recordingUrl"');
    }

    try {
      if (kIsWeb) {
        final blob = web.Blob([csv.toString().toJS].toJS, web.BlobPropertyBag(type: 'text/csv;charset=utf-8'));
        final url = web.URL.createObjectURL(blob);
        final anchor = web.HTMLAnchorElement()
          ..href = url
          ..download = 'call_logs_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
        web.document.body?.appendChild(anchor);
        anchor.click();
        anchor.remove();
        web.URL.revokeObjectURL(url);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Call logs CSV downloaded successfully!'), backgroundColor: Color(0xFF008069)),
          );
        }
      } else {
        final bytes = utf8.encode(csv.toString());
        final base64Csv = base64Encode(bytes);
        final uri = Uri.parse('data:text/csv;base64,$base64Csv');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Call logs exported successfully!'), backgroundColor: Color(0xFF008069)),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export CSV: $e')),
        );
      }
    }
  }

  void _openMyOperatorRecording(dynamic log) async {
    String recordingUrl = (log['recordingUrl'] ?? '').toString().trim();
    final logId = log['_id']?.toString() ?? log['callId']?.toString() ?? '';
    final phone = (log['customerPhone'] ?? '').toString().replaceAll(RegExp(r'\D'), '').replaceFirst(RegExp(r'^91'), '');

    if (!recordingUrl.startsWith('http://') && !recordingUrl.startsWith('https://') && logId.isNotEmpty) {
      try {
        final res = await ApiClient().get('/calls/recordings/$logId/url');
        if (res.statusCode == 200) {
          final body = jsonDecode(res.body);
          if (body['success'] == true && body['data']?['recordingUrl'] != null) {
            recordingUrl = body['data']['recordingUrl'].toString();
          }
        }
      } catch (_) {}
    }

    String targetUrl = 'https://myoperator.com/app/call-logs';
    if (recordingUrl.startsWith('http://') || recordingUrl.startsWith('https://')) {
      targetUrl = recordingUrl;
    } else if (phone.isNotEmpty) {
      targetUrl = 'https://myoperator.com/app/call-logs?search=$phone';
    }

    try {
      final uri = Uri.parse(targetUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (kIsWeb) {
          web.window.open(targetUrl, '_blank');
        }
      }
    } catch (_) {
      if (kIsWeb) {
        web.window.open(targetUrl, '_blank');
      }
    }
  }

  void _openDispositionDialog(dynamic callLog) {
    final logId = callLog['_id']?.toString() ?? '';
    final phone = callLog['customerPhone']?.toString() ?? '';
    final contact = callLog['contactId'];
    final name = contact is Map ? contact['name']?.toString() : null;
    final initialDisposition = callLog['userDisposition']?.toString();
    final initialNotes = callLog['notes']?.toString();
    final initialFollowUpNote = callLog['followUpNote']?.toString();
    DateTime? initialFollowUpDate;
    if (callLog['followUpDate'] != null) {
      try {
        initialFollowUpDate = DateTime.tryParse(callLog['followUpDate'].toString())?.toLocal();
      } catch (_) {}
    }

    showDialog(
      context: context,
      builder: (dialogCtx) => CallDispositionDialog(
        callLogId: logId,
        customerPhone: phone,
        customerName: name,
        initialDisposition: initialDisposition,
        initialFollowUpDate: initialFollowUpDate,
        initialFollowUpNote: initialFollowUpNote,
        initialNotes: initialNotes,
        onSave: (disposition, followUpDate, followUpNote, notes) {
          context.read<CallLogsBloc>().add(SaveCallDispositionEvent(
            callLogId: logId,
            userDisposition: disposition,
            followUpDate: followUpDate,
            followUpNote: followUpNote,
            notes: notes,
          ));
        },
        onOpenEstimate: () {
          Navigator.pushNamed(context, '/sales/estimates');
        },
        onOpenWhatsApp: () {
          Navigator.pushNamed(context, '/support', arguments: {
            'phone': phone,
            'name': name ?? 'Customer',
          });
        },
      ),
    );
  }

  void _confirmDeleteLog(BuildContext context, String callLogId, String displayName) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Delete Call Record', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete the call record for $displayName? This will remove it from your active dashboard.', style: GoogleFonts.outfit(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text('Cancel', style: GoogleFonts.outfit(color: const Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              context.read<CallLogsBloc>().add(DeleteCallLogEvent(callLogId));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Call log deleted successfully'), backgroundColor: Color(0xFF008069), duration: Duration(seconds: 2)),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Delete', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _confirmBulkDelete(BuildContext context) {
    if (_selectedLogIds.isEmpty) return;
    final count = _selectedLogIds.length;
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Delete $count Selected Records', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete $count selected call record(s)? This will remove them from your active dashboard.', style: GoogleFonts.outfit(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text('Cancel', style: GoogleFonts.outfit(color: const Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              final ids = _selectedLogIds.toList();
              setState(() {
                _selectedLogIds.clear();
              });
              context.read<CallLogsBloc>().add(BulkDeleteCallLogsEvent(ids));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$count call log(s) deleted successfully'), backgroundColor: const Color(0xFF008069), duration: const Duration(seconds: 2)),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Delete Selected', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _confirmClearAllLogs(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 24),
            const SizedBox(width: 8),
            Text('Clear All Call Logs', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text('Are you sure you want to clear all call history from the CRM? This will remove all active call logs from the dashboard view.', style: GoogleFonts.outfit(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text('Cancel', style: GoogleFonts.outfit(color: const Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              context.read<CallLogsBloc>().add(const ClearAllCallLogsEvent());
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('All call logs cleared successfully'), backgroundColor: Color(0xFF008069), duration: Duration(seconds: 2)),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Clear All', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '0s';
    final int mins = seconds ~/ 60;
    final int secs = seconds % 60;
    if (mins > 0) {
      return '${mins}m ${secs.toString().padLeft(2, '0')}s';
    }
    return '${secs}s';
  }

  String _getInitials(String name) {
    final clean = name.trim();
    if (clean.isEmpty) return 'CL';
    final parts = clean.split(RegExp(r'\s+'));
    if (parts.length > 1) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return clean.length >= 2 ? clean.substring(0, 2).toUpperCase() : clean[0].toUpperCase();
  }

  Widget _buildSegmentTab({
    required String label,
    IconData? icon,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6.5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF008069) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: isSelected ? Colors.white : const Color(0xFF64748B)),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFF475569),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withValues(alpha: 0.25) : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : const Color(0xFF475569),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonRows() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 6,
      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 180,
                    height: 14,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 280,
                    height: 10,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 84,
              height: 28,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final role = AuthService().currentUserRole ?? UserRole.admin;
    final bool isAdmin = role == UserRole.admin;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: BlocConsumer<CallLogsBloc, CallLogsState>(
        listener: (context, state) {
          if (state.errorMessage != null && state.errorMessage!.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage!),
                backgroundColor: AppTheme.error,
              ),
            );
            context.read<CallLogsBloc>().add(const ClearCallLogsMessageEvent());
          }
          if (state.successMessage != null && state.successMessage!.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.successMessage!),
                backgroundColor: const Color(0xFF008069),
              ),
            );
            context.read<CallLogsBloc>().add(const ClearCallLogsMessageEvent());
          }
        },
        builder: (context, state) {
          return Column(
            children: [
              // Modern Hero Header Bar
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF008069), Color(0xFF059669)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF008069).withValues(alpha: 0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.phone_in_talk_rounded, color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  isAdmin ? 'Call History & Recordings Hub' : 'My Sales Call History',
                                  style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                                ),
                                const SizedBox(width: 10),
                                // Pulsing Live Auto-Sync Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFECFDF5),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: const Color(0xFFA7F3D0)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 6.5,
                                        height: 6.5,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF10B981),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        'LIVE AUTO-SYNC',
                                        style: GoogleFonts.outfit(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.5,
                                          color: const Color(0xFF047857),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Real-time MyOperator telephony sync, recording links, leaderboards & CRM dispositions',
                              style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () async {
                            if (isAdmin) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('🔄 Syncing call logs from MyOperator across all accounts...'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                              try {
                                final res = await ApiClient().post('/calls/sync', {});
                                if (res.statusCode == 200) {
                                  final body = jsonDecode(res.body);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(body['message'] ?? 'Calls synced successfully!'),
                                        backgroundColor: const Color(0xFF008069),
                                      ),
                                    );
                                  }
                                }
                              } catch (_) {}
                            }
                            if (context.mounted) {
                              context.read<CallLogsBloc>().add(FetchCallLogsEvent(
                                page: 1,
                                type: state.selectedType,
                                status: state.selectedStatus,
                                agentId: state.selectedAgentId,
                                search: state.searchQuery,
                              ));
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF008069),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 0,
                          ),
                          icon: Icon(isAdmin ? Icons.sync_rounded : Icons.refresh_rounded, size: 16),
                          label: Text(
                            isAdmin ? 'Sync MyOperator' : 'Refresh',
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                        const SizedBox(width: 10),
                        if (isAdmin && _selectedLogIds.isNotEmpty) ...[
                          ElevatedButton.icon(
                            onPressed: () => _confirmBulkDelete(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFDC2626),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.delete_outline_rounded, size: 16),
                            label: Text(
                              'Delete Selected (${_selectedLogIds.length})',
                              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        if (AuthService().currentUserRole == UserRole.admin) ...[
                          OutlinedButton.icon(
                            onPressed: () => _confirmClearAllLogs(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFDC2626),
                              side: const BorderSide(color: Color(0xFFFCA5A5)),
                              backgroundColor: const Color(0xFFFEF2F2),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.delete_sweep_outlined, size: 16, color: Color(0xFFDC2626)),
                            label: Text(
                              'Clear All Logs',
                              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13, color: const Color(0xFFDC2626)),
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        OutlinedButton.icon(
                          onPressed: () => _exportToCsv(state.callLogs),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF008069),
                            side: const BorderSide(color: Color(0xFF008069)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.file_download_outlined, size: 16),
                          label: Text(
                            'Export CSV',
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Scheduled Follow-ups Alert Ribbon
                      Builder(
                        builder: (context) {
                          final pendingFollowUps = state.callLogs.where((l) => l['followUpDate'] != null).toList();
                          if (pendingFollowUps.isEmpty) return const SizedBox.shrink();

                          return Container(
                            margin: const EdgeInsets.only(bottom: 20),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFFDE68A)),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFD97706).withValues(alpha: 0.08),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.alarm_on_rounded, color: Color(0xFFD97706), size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    '${pendingFollowUps.length} Scheduled Follow-up callback(s) pending in this view. Check ACW notes and re-connect with leads.',
                                    style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF92400E)),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                      // Telephony Leaderboard & KPI Summary Ribbon (with 1-click agent filter)
                      TelephonyLeaderboardWidget(
                        totalCalls: state.totalCalls,
                        inboundCount: state.inboundCount,
                        outboundCount: state.outboundCount,
                        missedCount: state.missedCount,
                        totalTalkTimeSeconds: state.totalTalkTimeSeconds,
                        leaderboard: state.leaderboard,
                        selectedAgentId: state.selectedAgentId,
                        onAgentSelected: (agentId) {
                          context.read<CallLogsBloc>().add(FetchCallLogsEvent(
                            agentId: agentId,
                            type: state.selectedType,
                            status: state.selectedStatus,
                            search: state.searchQuery,
                          ));
                        },
                      ),
                      const SizedBox(height: 20),

                      // Unified SaaS Telephony Table Card
                      Container(
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
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // 1. Top Direction Tabs & Status Counter
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                              decoration: const BoxDecoration(
                                color: Color(0xFFFAFAFA),
                                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                                border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  // Segmented Pills
                                  Row(
                                    children: [
                                      _buildSegmentTab(
                                        label: 'All Calls',
                                        count: state.totalCalls,
                                        isSelected: state.selectedType == 'all',
                                        onTap: () => context.read<CallLogsBloc>().add(FetchCallLogsEvent(
                                          type: 'all',
                                          status: state.selectedStatus,
                                          agentId: state.selectedAgentId,
                                          search: state.searchQuery,
                                        )),
                                      ),
                                      const SizedBox(width: 6),
                                      _buildSegmentTab(
                                        label: 'Inbound',
                                        icon: Icons.arrow_downward_rounded,
                                        count: state.inboundCount,
                                        isSelected: state.selectedType == 'inbound',
                                        onTap: () => context.read<CallLogsBloc>().add(FetchCallLogsEvent(
                                          type: 'inbound',
                                          status: state.selectedStatus,
                                          agentId: state.selectedAgentId,
                                          search: state.searchQuery,
                                        )),
                                      ),
                                      const SizedBox(width: 6),
                                      _buildSegmentTab(
                                        label: 'Outbound',
                                        icon: Icons.arrow_outward_rounded,
                                        count: state.outboundCount,
                                        isSelected: state.selectedType == 'outbound',
                                        onTap: () => context.read<CallLogsBloc>().add(FetchCallLogsEvent(
                                          type: 'outbound',
                                          status: state.selectedStatus,
                                          agentId: state.selectedAgentId,
                                          search: state.searchQuery,
                                        )),
                                      ),
                                    ],
                                  ),
                                  // Records Count
                                  Text(
                                    '${state.totalCount} call records',
                                    style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B), fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),

                            // 2. Integrated Filter & Search Toolbar
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Row(
                                children: [
                                  // Search Field
                                  Expanded(
                                    child: Container(
                                      height: 38,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: const Color(0xFFE2E8F0)),
                                      ),
                                      child: TextField(
                                        controller: _searchController,
                                        style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF0F172A)),
                                        decoration: InputDecoration(
                                          hintText: 'Search lead name, phone number, disposition or notes...',
                                          hintStyle: GoogleFonts.outfit(fontSize: 12.5, color: const Color(0xFF94A3B8)),
                                          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF008069), size: 17),
                                          suffixIcon: _searchController.text.isNotEmpty
                                              ? IconButton(
                                                  icon: const Icon(Icons.close_rounded, size: 15, color: Color(0xFF64748B)),
                                                  onPressed: () {
                                                    _searchController.clear();
                                                    setState(() {});
                                                    context.read<CallLogsBloc>().add(FetchCallLogsEvent(
                                                      search: '',
                                                      type: state.selectedType,
                                                      status: state.selectedStatus,
                                                      agentId: state.selectedAgentId,
                                                    ));
                                                  },
                                                )
                                              : null,
                                          border: InputBorder.none,
                                          isDense: true,
                                          contentPadding: const EdgeInsets.symmetric(vertical: 9),
                                        ),
                                        onChanged: (val) {
                                          _searchDebounce?.cancel();
                                          _searchDebounce = Timer(const Duration(milliseconds: 300), () {
                                            context.read<CallLogsBloc>().add(FetchCallLogsEvent(
                                              search: val.trim(),
                                              type: state.selectedType,
                                              status: state.selectedStatus,
                                              agentId: state.selectedAgentId,
                                            ));
                                          });
                                          setState(() {});
                                        },
                                        onSubmitted: (val) {
                                          _searchDebounce?.cancel();
                                          context.read<CallLogsBloc>().add(FetchCallLogsEvent(
                                            search: val.trim(),
                                            type: state.selectedType,
                                            status: state.selectedStatus,
                                            agentId: state.selectedAgentId,
                                          ));
                                        },
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),

                                   // Status Filter
                                   Container(
                                     height: 38,
                                     padding: const EdgeInsets.symmetric(horizontal: 10),
                                     decoration: BoxDecoration(
                                       color: state.selectedStatus != 'all' ? const Color(0xFF008069).withValues(alpha: 0.08) : const Color(0xFFF8FAFC),
                                       borderRadius: BorderRadius.circular(8),
                                       border: Border.all(color: state.selectedStatus != 'all' ? const Color(0xFF008069).withValues(alpha: 0.4) : const Color(0xFFE2E8F0)),
                                     ),
                                     child: DropdownButtonHideUnderline(
                                       child: DropdownButton<String>(
                                         value: state.selectedStatus,
                                         icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF64748B)),
                                         style: GoogleFonts.outfit(fontSize: 12.5, color: const Color(0xFF1E293B), fontWeight: FontWeight.w600),
                                         items: const [
                                           DropdownMenuItem(
                                             value: 'all',
                                             child: Row(
                                               mainAxisSize: MainAxisSize.min,
                                               children: [
                                                 Icon(Icons.tune_rounded, size: 14, color: Color(0xFF64748B)),
                                                 SizedBox(width: 6),
                                                 Text('All Statuses'),
                                               ],
                                             ),
                                           ),
                                           DropdownMenuItem(value: 'answered', child: Text('✅ Answered')),
                                           DropdownMenuItem(value: 'missed', child: Text('❌ Missed / No Answer')),
                                           DropdownMenuItem(value: 'busy', child: Text('⏳ Busy Line')),
                                           DropdownMenuItem(value: 'failed', child: Text('⚠️ Failed')),
                                         ],
                                         onChanged: (val) {
                                           if (val != null) {
                                             context.read<CallLogsBloc>().add(FetchCallLogsEvent(
                                               status: val,
                                               type: state.selectedType,
                                               agentId: state.selectedAgentId,
                                               search: state.searchQuery,
                                             ));
                                           }
                                         },
                                       ),
                                     ),
                                   ),

                                   // Sales Agent Filter (For Admin)
                                   if (isAdmin) ...[
                                     const SizedBox(width: 10),
                                     Container(
                                       height: 38,
                                       padding: const EdgeInsets.symmetric(horizontal: 10),
                                       decoration: BoxDecoration(
                                         color: state.selectedAgentId != null ? const Color(0xFF008069).withValues(alpha: 0.08) : const Color(0xFFF8FAFC),
                                         borderRadius: BorderRadius.circular(8),
                                         border: Border.all(color: state.selectedAgentId != null ? const Color(0xFF008069).withValues(alpha: 0.4) : const Color(0xFFE2E8F0)),
                                       ),
                                       child: DropdownButtonHideUnderline(
                                         child: DropdownButton<String>(
                                           value: state.selectedAgentId ?? 'all',
                                           icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF64748B)),
                                           style: GoogleFonts.outfit(fontSize: 12.5, color: const Color(0xFF1E293B), fontWeight: FontWeight.w600),
                                           items: [
                                             DropdownMenuItem<String>(
                                               value: 'all',
                                               child: Row(
                                                 mainAxisSize: MainAxisSize.min,
                                                 children: [
                                                   const Icon(Icons.people_alt_rounded, size: 14, color: Color(0xFF008069)),
                                                   const SizedBox(width: 6),
                                                   Text(
                                                     'All Agents (${state.salesAgents.length})',
                                                     style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                                                   ),
                                                 ],
                                               ),
                                             ),
                                             ...state.salesAgents.map((agent) {
                                               final name = agent['name'] ?? '${agent['firstName'] ?? ''} ${agent['lastName'] ?? ''}'.trim();
                                               final phone = agent['phoneNumber'] ?? agent['mobileNumber'] ?? '';
                                               final displayName = name.isNotEmpty ? name : (agent['email'] ?? 'Agent');
                                               final shortPhone = phone.toString().replaceAll(RegExp(r'\D'), '').replaceFirst(RegExp(r'^91'), '');

                                               return DropdownMenuItem<String>(
                                                 value: agent['_id']?.toString() ?? '',
                                                 child: Row(
                                                   mainAxisSize: MainAxisSize.min,
                                                   children: [
                                                     Container(
                                                       width: 20,
                                                       height: 20,
                                                       decoration: BoxDecoration(
                                                         color: const Color(0xFF008069).withValues(alpha: 0.12),
                                                         shape: BoxShape.circle,
                                                       ),
                                                       alignment: Alignment.center,
                                                       child: Text(
                                                         _getInitials(displayName),
                                                         style: GoogleFonts.outfit(fontSize: 8, fontWeight: FontWeight.w800, color: const Color(0xFF008069)),
                                                       ),
                                                     ),
                                                     const SizedBox(width: 8),
                                                     Text(
                                                       displayName,
                                                       style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)),
                                                     ),
                                                     if (shortPhone.isNotEmpty) ...[
                                                       const SizedBox(width: 6),
                                                       Text(
                                                         '($shortPhone)',
                                                         style: GoogleFonts.jetBrainsMono(fontSize: 11, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
                                                       ),
                                                     ],
                                                   ],
                                                 ),
                                               );
                                             }),
                                           ],
                                           onChanged: (val) {
                                             context.read<CallLogsBloc>().add(FetchCallLogsEvent(
                                               agentId: (val == null || val == 'all' || val.isEmpty) ? null : val,
                                               type: state.selectedType,
                                               status: state.selectedStatus,
                                               search: state.searchQuery,
                                             ));
                                           },
                                         ),
                                       ),
                                     ),
                                   ],
                                  // Reset Filter Button
                                  if (state.selectedType != 'all' || state.selectedStatus != 'all' || state.selectedAgentId != null || state.searchQuery.isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    IconButton(
                                      tooltip: 'Reset All Filters',
                                      style: IconButton.styleFrom(
                                        backgroundColor: const Color(0xFFFEF2F2),
                                        foregroundColor: const Color(0xFFDC2626),
                                        padding: const EdgeInsets.all(8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: Color(0xFFFECACA))),
                                        minimumSize: Size.zero,
                                      ),
                                      icon: const Icon(Icons.filter_alt_off_rounded, size: 16),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() {});
                                        context.read<CallLogsBloc>().add(const FetchCallLogsEvent(
                                          page: 1,
                                          type: 'all',
                                          status: 'all',
                                          agentId: null,
                                          search: '',
                                        ));
                                      },
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            // 3. Table Column Header Bar
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                              decoration: const BoxDecoration(
                                color: Color(0xFFF8FAFC),
                                border: Border.symmetric(horizontal: BorderSide(color: Color(0xFFE2E8F0))),
                              ),
                              child: Row(
                                children: [
                                  const SizedBox(width: 48), // Align with avatar
                                  Expanded(
                                    child: Text(
                                      'CALL DETAILS, LEAD & NOTES',
                                      style: GoogleFonts.outfit(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: const Color(0xFF64748B)),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'ACW & RECORDING',
                                    style: GoogleFonts.outfit(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: const Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                            if (state.isLoading && state.callLogs.isNotEmpty)
                              const LinearProgressIndicator(
                                minHeight: 2.5,
                                color: Color(0xFF008069),
                                backgroundColor: Color(0xFFE2E8F0),
                              ),
                            if (state.isLoading && state.callLogs.isEmpty)
                              _buildSkeletonRows()
                            else if (state.callLogs.isEmpty)
                              Padding(
                                padding: const EdgeInsets.all(50),
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.phone_missed_rounded, size: 36, color: Color(0xFF94A3B8)),
                                    ),
                                    const SizedBox(height: 14),
                                    Text('No call records found', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
                                    const SizedBox(height: 4),
                                    Text('Calls made on the MyOperator mobile app will automatically appear here in real-time.', style: GoogleFonts.outfit(fontSize: 12.5, color: const Color(0xFF64748B))),
                                  ],
                                ),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: state.callLogs.length,
                                separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                itemBuilder: (context, index) {
                                  final log = state.callLogs[index];
                                  final String dirStr = (log['direction'] ?? log['type'] ?? 'outbound').toString().toLowerCase();
                                  final bool isOutbound = dirStr == 'outbound' || dirStr == 'out' || dirStr == '2' || dirStr == 'obd' || dirStr == 'click2call';
                                  final rawStatus = (log['status'] ?? 'initiated').toString().toLowerCase();
                                  final String customerPhone = (log['customerPhone'] ?? 'Unknown').toString();
                                  final contact = log['contactId'] is Map ? log['contactId'] : null;
                                  final String contactName = (contact?['name'] ?? '').toString().trim();
                                  final agent = log['agentId'] is Map ? log['agentId'] : {};
                                  final String agentName = '${agent['firstName'] ?? ''} ${agent['lastName'] ?? ''}'.trim();
                                  final String recordingUrl = log['recordingUrl'] ?? '';
                                  final int seconds = int.tryParse(log['durationSeconds']?.toString() ?? '0') ?? 0;
                                  final String userDisposition = log['userDisposition'] ?? '';
                                  final String notesText = (log['notes'] ?? log['followUpNote'] ?? '').toString().trim();

                                  Color statusBg = const Color(0xFFECFDF5);
                                  Color statusFg = const Color(0xFF047857);
                                  String statusLabel = 'ANSWERED';

                                  if (rawStatus == 'missed') {
                                    statusBg = const Color(0xFFFEF2F2);
                                    statusFg = const Color(0xFFDC2626);
                                    statusLabel = 'MISSED';
                                  } else if (rawStatus == 'busy') {
                                    statusBg = const Color(0xFFFFFBEB);
                                    statusFg = const Color(0xFFD97706);
                                    statusLabel = 'BUSY';
                                  } else if (rawStatus == 'no-answer') {
                                    statusBg = const Color(0xFFFFEDD5);
                                    statusFg = const Color(0xFFEA580C);
                                    statusLabel = 'NO ANSWER';
                                  } else if (rawStatus == 'failed') {
                                    statusBg = const Color(0xFFFEF2F2);
                                    statusFg = const Color(0xFFDC2626);
                                    statusLabel = 'FAILED';
                                  } else if (rawStatus != 'answered') {
                                    statusBg = const Color(0xFFF1F5F9);
                                    statusFg = const Color(0xFF475569);
                                    statusLabel = rawStatus.toUpperCase();
                                  }

                                  String formattedDate = '';
                                  if (log['createdAt'] != null) {
                                    final date = DateTime.tryParse(log['createdAt'].toString())?.toLocal();
                                    if (date != null) {
                                      formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(date);
                                    }
                                  }

                                  final displayName = contactName.isNotEmpty ? contactName : 'Customer (+$customerPhone)';
                                  final initials = _getInitials(displayName);
                                  final rowLogId = log['_id']?.toString() ?? log['callId']?.toString() ?? log['providerCallId']?.toString() ?? '';
                                  final bool isRowSelected = rowLogId.isNotEmpty && _selectedLogIds.contains(rowLogId);

                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: isRowSelected ? const Color(0xFFF0FDF4) : Colors.transparent,
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        // Row Selection Checkbox (Admin Only)
                                        if (isAdmin && rowLogId.isNotEmpty) ...[
                                          SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: Checkbox(
                                              value: isRowSelected,
                                              activeColor: const Color(0xFF008069),
                                              side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                              onChanged: (val) {
                                                setState(() {
                                                  if (val == true) {
                                                    _selectedLogIds.add(rowLogId);
                                                  } else {
                                                    _selectedLogIds.remove(rowLogId);
                                                  }
                                                });
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                        ],

                                        // Caller Initials Avatar with Direction Icon
                                        Stack(
                                          children: [
                                            Container(
                                              width: 38,
                                              height: 38,
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: isOutbound
                                                      ? [const Color(0xFF2563EB), const Color(0xFF1D4ED8)]
                                                      : [const Color(0xFF008069), const Color(0xFF047857)],
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                ),
                                                shape: BoxShape.circle,
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: (isOutbound ? const Color(0xFF2563EB) : const Color(0xFF008069)).withValues(alpha: 0.2),
                                                    blurRadius: 6,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                              child: Center(
                                                child: Text(
                                                  initials,
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Positioned(
                                              right: -1,
                                              bottom: -1,
                                              child: Container(
                                                padding: const EdgeInsets.all(2),
                                                decoration: const BoxDecoration(
                                                  color: Colors.white,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Icon(
                                                  isOutbound ? Icons.arrow_outward_rounded : Icons.arrow_downward_rounded,
                                                  size: 10,
                                                  color: isOutbound ? const Color(0xFF2563EB) : const Color(0xFF008069),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(width: 12),

                                        // Customer Info & Metadata
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              // Top Row: Name, Phone, Status Pill, Disposition Tag
                                              Wrap(
                                                crossAxisAlignment: WrapCrossAlignment.center,
                                                spacing: 6,
                                                runSpacing: 4,
                                                children: [
                                                  Text(
                                                    displayName,
                                                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13.5, color: const Color(0xFF0F172A)),
                                                  ),
                                                  if (customerPhone.isNotEmpty && customerPhone != 'Unknown') ...[
                                                    InkWell(
                                                      onTap: () {
                                                        Clipboard.setData(ClipboardData(text: customerPhone));
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          SnackBar(content: Text('Copied $customerPhone to clipboard'), duration: const Duration(seconds: 1)),
                                                        );
                                                      },
                                                      borderRadius: BorderRadius.circular(4),
                                                      child: Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                        decoration: BoxDecoration(
                                                          color: const Color(0xFFF1F5F9),
                                                          borderRadius: BorderRadius.circular(4),
                                                        ),
                                                        child: Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            Text(
                                                              '+91 $customerPhone',
                                                              style: GoogleFonts.jetBrainsMono(fontSize: 11, color: const Color(0xFF475569), fontWeight: FontWeight.w600),
                                                            ),
                                                            const SizedBox(width: 3),
                                                            const Icon(Icons.copy_rounded, size: 10, color: Color(0xFF94A3B8)),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                  // Call Status Pill
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6.5, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: statusBg,
                                                      borderRadius: BorderRadius.circular(5),
                                                      border: Border.all(color: statusFg.withValues(alpha: 0.2)),
                                                    ),
                                                    child: Text(
                                                      seconds > 0 ? '$statusLabel • ${_formatDuration(seconds)}' : statusLabel,
                                                      style: GoogleFonts.outfit(
                                                        fontSize: 9.5,
                                                        fontWeight: FontWeight.w700,
                                                        color: statusFg,
                                                      ),
                                                    ),
                                                  ),
                                                  // ACW Disposition Badge
                                                  if (userDisposition.isNotEmpty)
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6.5, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFFFAF5FF),
                                                        borderRadius: BorderRadius.circular(5),
                                                        border: Border.all(color: const Color(0xFFD8B4FE)),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          const Icon(Icons.bookmark_added_rounded, size: 10, color: Color(0xFF9333EA)),
                                                          const SizedBox(width: 3),
                                                          Text(
                                                            userDisposition,
                                                            style: GoogleFonts.outfit(
                                                              fontSize: 10,
                                                              fontWeight: FontWeight.bold,
                                                              color: const Color(0xFF7E22CE),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              const SizedBox(height: 3),

                                              // Bottom Row: Line/Agent, Direction, Timestamp
                                              Wrap(
                                                crossAxisAlignment: WrapCrossAlignment.center,
                                                spacing: 8,
                                                runSpacing: 2,
                                                children: [
                                                  Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        isOutbound ? Icons.arrow_outward_rounded : Icons.call_received_rounded,
                                                        size: 12,
                                                        color: isOutbound ? const Color(0xFF2563EB) : const Color(0xFF047857),
                                                      ),
                                                      const SizedBox(width: 3),
                                                      Text(
                                                        isOutbound
                                                            ? (agentName.isNotEmpty ? 'Outgoing call • Initiated by $agentName' : 'Outgoing call')
                                                            : (agentName.isNotEmpty
                                                                ? (rawStatus == 'missed' ? 'Missed call • For $agentName' : 'Incoming call • Received by $agentName')
                                                                : (rawStatus == 'missed' ? 'Missed incoming call' : 'Incoming call')),
                                                        style: GoogleFonts.outfit(
                                                          fontSize: 11.5,
                                                          color: isOutbound ? const Color(0xFF1E40AF) : const Color(0xFF065F46),
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  if (formattedDate.isNotEmpty)
                                                    Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        const Text('•', style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 10)),
                                                        const SizedBox(width: 4),
                                                        const Icon(Icons.schedule_rounded, size: 11, color: Color(0xFF94A3B8)),
                                                        const SizedBox(width: 3),
                                                        Text(formattedDate, style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF64748B))),
                                                      ],
                                                    ),
                                                ],
                                              ),

                                              // ACW Notes Bubble Preview (Compact)
                                              if (notesText.isNotEmpty) ...[
                                                const SizedBox(height: 4),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFF8FAFC),
                                                    borderRadius: BorderRadius.circular(6),
                                                    border: const Border(
                                                      left: BorderSide(color: Color(0xFF008069), width: 2.5),
                                                    ),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      const Icon(Icons.chat_bubble_outline_rounded, size: 11, color: Color(0xFF64748B)),
                                                      const SizedBox(width: 5),
                                                      Expanded(
                                                        child: Text(
                                                          notesText,
                                                          style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF334155), fontStyle: FontStyle.italic),
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 12),

                                         // Action Buttons (ACW & MyOperator Recording)
                                         Row(
                                           mainAxisSize: MainAxisSize.min,
                                           children: [
                                             // Disposition / ACW Notes Button
                                             Tooltip(
                                               message: userDisposition.isNotEmpty ? 'Edit saved ACW disposition & notes' : 'Log call disposition & reminder notes',
                                               child: Material(
                                                 color: Colors.transparent,
                                                 child: InkWell(
                                                   onTap: () => _openDispositionDialog(log),
                                                   borderRadius: BorderRadius.circular(8),
                                                   child: AnimatedContainer(
                                                     duration: const Duration(milliseconds: 150),
                                                     padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                     decoration: BoxDecoration(
                                                       color: userDisposition.isNotEmpty ? const Color(0xFFFAF5FF) : const Color(0xFFF0FDF4),
                                                       borderRadius: BorderRadius.circular(8),
                                                       border: Border.all(
                                                         color: userDisposition.isNotEmpty ? const Color(0xFFD8B4FE) : const Color(0xFF86EFAC),
                                                         width: 1.1,
                                                       ),
                                                     ),
                                                     child: Row(
                                                       mainAxisSize: MainAxisSize.min,
                                                       children: [
                                                         Icon(
                                                           userDisposition.isNotEmpty ? Icons.assignment_turned_in_rounded : Icons.post_add_rounded,
                                                           size: 13,
                                                           color: userDisposition.isNotEmpty ? const Color(0xFF9333EA) : const Color(0xFF16A34A),
                                                         ),
                                                         const SizedBox(width: 5),
                                                         Text(
                                                           userDisposition.isNotEmpty ? 'Edit ACW' : '+ Log ACW',
                                                           style: GoogleFonts.outfit(
                                                             fontSize: 11.5,
                                                             fontWeight: FontWeight.w700,
                                                             color: userDisposition.isNotEmpty ? const Color(0xFF7E22CE) : const Color(0xFF15803D),
                                                           ),
                                                         ),
                                                       ],
                                                     ),
                                                   ),
                                                 ),
                                               ),
                                             ),
                                             const SizedBox(width: 8),

                                             // MyOperator Recording Button
                                             if (recordingUrl.isNotEmpty || rawStatus == 'answered' || seconds > 0)
                                               Tooltip(
                                                 message: 'Open call recording in MyOperator portal',
                                                 child: Material(
                                                   color: Colors.transparent,
                                                   child: InkWell(
                                                     onTap: () => _openMyOperatorRecording(log),
                                                     borderRadius: BorderRadius.circular(8),
                                                     child: Container(
                                                       padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                                                       decoration: BoxDecoration(
                                                         color: const Color(0xFF0F172A),
                                                         borderRadius: BorderRadius.circular(8),
                                                         boxShadow: [
                                                           BoxShadow(
                                                             color: Colors.black.withValues(alpha: 0.08),
                                                             blurRadius: 4,
                                                             offset: const Offset(0, 2),
                                                           ),
                                                         ],
                                                       ),
                                                       child: Row(
                                                         mainAxisSize: MainAxisSize.min,
                                                         children: [
                                                           const Icon(Icons.graphic_eq_rounded, size: 14, color: Color(0xFF34D399)),
                                                           const SizedBox(width: 5),
                                                           Text(
                                                             'Recording',
                                                             style: GoogleFonts.outfit(
                                                               fontSize: 11.5,
                                                               fontWeight: FontWeight.w700,
                                                               color: Colors.white,
                                                               letterSpacing: 0.2,
                                                             ),
                                                           ),
                                                         ],
                                                       ),
                                                     ),
                                                   ),
                                                 ),
                                               )
                                             else
                                               Container(
                                                 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                                 decoration: BoxDecoration(
                                                   color: const Color(0xFFF1F5F9),
                                                   borderRadius: BorderRadius.circular(6),
                                                   border: Border.all(color: const Color(0xFFE2E8F0)),
                                                 ),
                                                 child: Row(
                                                   mainAxisSize: MainAxisSize.min,
                                                   children: [
                                                     const Icon(Icons.mic_off_rounded, size: 11, color: Color(0xFF94A3B8)),
                                                     const SizedBox(width: 4),
                                                     Text(
                                                       'No Audio',
                                                       style: GoogleFonts.outfit(fontSize: 10.5, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
                                                     ),
                                                   ],
                                                 ),
                                               ),

                                             // Delete Call Record Button (Admin Only)
                                             if (isAdmin)
                                               Builder(
                                               builder: (context) {
                                                 final logId = log['_id']?.toString() ?? log['callId']?.toString() ?? '';
                                                 if (logId.isEmpty) return const SizedBox.shrink();
                                                 return Padding(
                                                   padding: const EdgeInsets.only(left: 6),
                                                   child: Tooltip(
                                                     message: 'Delete this call record',
                                                     child: Material(
                                                       color: Colors.transparent,
                                                       child: InkWell(
                                                         onTap: () => _confirmDeleteLog(context, logId, displayName),
                                                         borderRadius: BorderRadius.circular(6),
                                                         child: Container(
                                                           padding: const EdgeInsets.all(5.5),
                                                           decoration: BoxDecoration(
                                                             color: const Color(0xFFFEF2F2),
                                                             borderRadius: BorderRadius.circular(6),
                                                             border: Border.all(color: const Color(0xFFFECACA), width: 1.0),
                                                           ),
                                                           child: const Icon(
                                                             Icons.delete_outline_rounded,
                                                             size: 14,
                                                             color: Color(0xFFDC2626),
                                                           ),
                                                         ),
                                                       ),
                                                     ),
                                                   ),
                                                 );
                                               },
                                             ),
                                           ],
                                         ),
                                       ],
                                     ),
                                   );
                                 },
                               ),
                            // Modern Pagination Footer
                            if (state.totalPages > 1 || state.totalCount > 0) ...[
                              const Divider(height: 1, color: Color(0xFFE2E8F0)),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Showing ${state.callLogs.length} of ${state.totalCount} call records',
                                      style: GoogleFonts.outfit(
                                        fontSize: 13,
                                        color: const Color(0xFF64748B),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: const Color(0xFF1E293B),
                                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          ),
                                          icon: const Icon(Icons.chevron_left_rounded, size: 18),
                                          label: Text('Prev', style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.w600)),
                                          onPressed: state.page > 1
                                              ? () {
                                                  context.read<CallLogsBloc>().add(FetchCallLogsEvent(
                                                    page: state.page - 1,
                                                    type: state.selectedType,
                                                    status: state.selectedStatus,
                                                    agentId: state.selectedAgentId,
                                                    search: state.searchQuery,
                                                  ));
                                                }
                                              : null,
                                        ),
                                        const SizedBox(width: 10),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF008069).withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            'Page ${state.page} of ${state.totalPages > 0 ? state.totalPages : 1}',
                                            style: GoogleFonts.outfit(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.bold,
                                              color: const Color(0xFF008069),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: const Color(0xFF1E293B),
                                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          ),
                                          icon: const Icon(Icons.chevron_right_rounded, size: 18),
                                          label: Text('Next', style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.w600)),
                                          onPressed: state.page < state.totalPages
                                              ? () {
                                                  context.read<CallLogsBloc>().add(FetchCallLogsEvent(
                                                    page: state.page + 1,
                                                    type: state.selectedType,
                                                    status: state.selectedStatus,
                                                    agentId: state.selectedAgentId,
                                                    search: state.searchQuery,
                                                  ));
                                                }
                                              : null,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
