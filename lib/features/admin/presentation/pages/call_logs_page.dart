import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:kd_pannel/app_theme.dart';
import 'package:kd_pannel/core/auth/auth_service.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CallLogsBloc>().add(const FetchCallLogsEvent(page: 1));
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _playRecording(String recordingUrl) async {
    if (recordingUrl.isEmpty) return;
    final url = Uri.tryParse(recordingUrl);
    if (url != null && await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open call recording link')),
        );
      }
    }
  }

  void _openDispositionDialog(dynamic callLog) {
    final logId = callLog['_id']?.toString() ?? '';
    final phone = callLog['customerPhone']?.toString() ?? '';
    final contact = callLog['contactId'];
    final name = contact is Map ? contact['name']?.toString() : null;

    showDialog(
      context: context,
      builder: (dialogCtx) => CallDispositionDialog(
        callLogId: logId,
        customerPhone: phone,
        customerName: name,
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
            'name': name,
          });
        },
      ),
    );
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '0s';
    final int mins = seconds ~/ 60;
    final int secs = seconds % 60;
    if (mins > 0) {
      return '${mins}m ${secs}s';
    }
    return '${secs}s';
  }

  @override
  Widget build(BuildContext context) {
    final role = AuthService().currentUserRole ?? UserRole.admin;

    return BlocConsumer<CallLogsBloc, CallLogsState>(
      listener: (context, state) {
        if (state.errorMessage != null && state.errorMessage!.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: AppTheme.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
          context.read<CallLogsBloc>().add(const ClearCallLogsMessageEvent());
        }
        if (state.successMessage != null && state.successMessage!.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.successMessage!),
              backgroundColor: const Color(0xFF008069),
              behavior: SnackBarBehavior.floating,
            ),
          );
          context.read<CallLogsBloc>().add(const ClearCallLogsMessageEvent());
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          body: Column(
            children: [
              // Header Bar
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
                            color: const Color(0xFF008069).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.phone_in_talk_rounded, color: Color(0xFF008069), size: 22),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              role == UserRole.admin ? 'Call Recordings & Telephony Hub' : 'My Sales Call History',
                              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF111B21)),
                            ),
                            Text(
                              'Real-time OBD calling, audio playback from MyOperator CDN & smart dispositions',
                              style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.refresh_rounded, color: Color(0xFF008069)),
                          onPressed: () => context.read<CallLogsBloc>().add(FetchCallLogsEvent(
                            page: state.page,
                            type: state.selectedType,
                            status: state.selectedStatus,
                            agentId: state.selectedAgentId,
                            search: state.searchQuery,
                          )),
                          tooltip: 'Refresh Call Logs',
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
                      // Telephony Leaderboard & KPI Summary Ribbon (Feature #6)
                      TelephonyLeaderboardWidget(
                        totalCalls: state.totalCalls,
                        inboundCount: state.inboundCount,
                        outboundCount: state.outboundCount,
                        missedCount: state.missedCount,
                        totalTalkTimeSeconds: state.totalTalkTimeSeconds,
                        leaderboard: state.leaderboard,
                      ),
                      const SizedBox(height: 20),

                      // Filter & Search Controls Bar
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                decoration: InputDecoration(
                                  hintText: 'Search customer phone number...',
                                  hintStyle: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF94A3B8)),
                                  prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF008069), size: 18),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                                onSubmitted: (val) {
                                  context.read<CallLogsBloc>().add(FetchCallLogsEvent(
                                    search: val.trim(),
                                    type: state.selectedType,
                                    status: state.selectedStatus,
                                    agentId: state.selectedAgentId,
                                  ));
                                },
                              ),
                            ),
                            const SizedBox(width: 16),

                            // Call Type Filter
                            DropdownButton<String>(
                              value: state.selectedType,
                              underline: const SizedBox(),
                              style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF111B21), fontWeight: FontWeight.w600),
                              items: const [
                                DropdownMenuItem(value: 'all', child: Text('Type: All')),
                                DropdownMenuItem(value: 'inbound', child: Text('📥 Inbound')),
                                DropdownMenuItem(value: 'outbound', child: Text('📤 Outbound')),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  context.read<CallLogsBloc>().add(FetchCallLogsEvent(
                                    type: val,
                                    status: state.selectedStatus,
                                    agentId: state.selectedAgentId,
                                    search: state.searchQuery,
                                  ));
                                }
                              },
                            ),
                            const SizedBox(width: 16),

                            // Call Status Filter
                            DropdownButton<String>(
                              value: state.selectedStatus,
                              underline: const SizedBox(),
                              style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF111B21), fontWeight: FontWeight.w600),
                              items: const [
                                DropdownMenuItem(value: 'all', child: Text('Status: All')),
                                DropdownMenuItem(value: 'answered', child: Text('✅ Answered')),
                                DropdownMenuItem(value: 'missed', child: Text('❌ Missed')),
                                DropdownMenuItem(value: 'busy', child: Text('⏳ Busy')),
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

                            if (role == UserRole.admin && state.salesAgents.isNotEmpty) ...[
                              const SizedBox(width: 16),
                              DropdownButton<String?>(
                                value: state.selectedAgentId,
                                hint: Text('Agent: All', style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF111B21), fontWeight: FontWeight.w600)),
                                underline: const SizedBox(),
                                items: [
                                  const DropdownMenuItem<String?>(value: null, child: Text('Agent: All')),
                                  ...state.salesAgents.map((agent) {
                                    return DropdownMenuItem<String?>(
                                      value: agent['_id']?.toString(),
                                      child: Text('${agent['firstName'] ?? ''} ${agent['lastName'] ?? ''}'.trim()),
                                    );
                                  }),
                                ],
                                onChanged: (val) {
                                  context.read<CallLogsBloc>().add(FetchCallLogsEvent(
                                    agentId: val,
                                    type: state.selectedType,
                                    status: state.selectedStatus,
                                    search: state.searchQuery,
                                  ));
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Call Logs Table
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: state.isLoading && state.callLogs.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.all(40),
                                child: Center(child: CircularProgressIndicator(color: Color(0xFF008069))),
                              )
                            : state.callLogs.isEmpty
                                ? Padding(
                                    padding: const EdgeInsets.all(40),
                                    child: Center(
                                      child: Text('No call logs found', style: GoogleFonts.outfit(fontSize: 14, color: const Color(0xFF64748B))),
                                    ),
                                  )
                                : ListView.separated(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: state.callLogs.length,
                                    separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                    itemBuilder: (context, index) {
                                      final log = state.callLogs[index];
                                      final isOutbound = (log['direction'] ?? log['type']) == 'outbound';
                                      final isAnswered = log['status'] == 'answered';
                                      final String customerPhone = log['customerPhone'] ?? 'Unknown';
                                      final agent = log['agentId'] ?? {};
                                      final String agentName = '${agent['firstName'] ?? ''} ${agent['lastName'] ?? ''}'.trim();
                                      final String recordingUrl = log['recordingUrl'] ?? '';
                                      final int seconds = int.tryParse(log['durationSeconds']?.toString() ?? '0') ?? 0;
                                      final String userDisposition = log['userDisposition'] ?? '';

                                      String formattedDate = '';
                                      if (log['createdAt'] != null) {
                                        final date = DateTime.tryParse(log['createdAt'].toString())?.toLocal();
                                        if (date != null) {
                                          formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(date);
                                        }
                                      }

                                      return ListTile(
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                        leading: CircleAvatar(
                                          backgroundColor: isOutbound
                                              ? Colors.blue.withValues(alpha: 0.1)
                                              : Colors.green.withValues(alpha: 0.1),
                                          child: Icon(
                                            isOutbound ? Icons.call_made_rounded : Icons.call_received_rounded,
                                            color: isOutbound ? Colors.blue : Colors.green,
                                            size: 18,
                                          ),
                                        ),
                                        title: Row(
                                          children: [
                                            Text(
                                              '+$customerPhone',
                                              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: const Color(0xFF111B21)),
                                            ),
                                            const SizedBox(width: 10),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: isAnswered
                                                    ? const Color(0xFF008069).withValues(alpha: 0.1)
                                                    : Colors.red.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                isAnswered ? 'ANSWERED' : 'MISSED',
                                                style: GoogleFonts.outfit(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: isAnswered ? const Color(0xFF008069) : Colors.red,
                                                ),
                                              ),
                                            ),
                                            if (userDisposition.isNotEmpty) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  '📌 $userDisposition',
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: const Color(0xFF8B5CF6),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        subtitle: Padding(
                                          padding: const EdgeInsets.only(top: 4.0),
                                          child: Row(
                                            children: [
                                              if (agentName.isNotEmpty) ...[
                                                Icon(Icons.support_agent_rounded, size: 13, color: Colors.grey.shade600),
                                                const SizedBox(width: 4),
                                                Text('Agent: $agentName', style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF475569))),
                                                const SizedBox(width: 12),
                                              ],
                                              Icon(Icons.timer_outlined, size: 13, color: Colors.grey.shade600),
                                              const SizedBox(width: 4),
                                              Text(_formatDuration(seconds), style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF475569))),
                                              const SizedBox(width: 12),
                                              Icon(Icons.calendar_today_outlined, size: 13, color: Colors.grey.shade600),
                                              const SizedBox(width: 4),
                                              Text(formattedDate, style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF475569))),
                                            ],
                                          ),
                                        ),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            // Disposition Button
                                            OutlinedButton.icon(
                                              onPressed: () => _openDispositionDialog(log),
                                              style: OutlinedButton.styleFrom(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              ),
                                              icon: const Icon(Icons.assignment_turned_in_rounded, size: 14),
                                              label: Text(
                                                userDisposition.isEmpty ? 'Log ACW' : 'Edit ACW',
                                                style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                            const SizedBox(width: 8),

                                            if (recordingUrl.isNotEmpty)
                                              ElevatedButton.icon(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: const Color(0xFF008069).withValues(alpha: 0.1),
                                                  foregroundColor: const Color(0xFF008069),
                                                  elevation: 0,
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                ),
                                                icon: const Icon(Icons.play_arrow_rounded, size: 16),
                                                label: Text('Listen Audio', style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.bold)),
                                                onPressed: () => _playRecording(recordingUrl),
                                              ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
