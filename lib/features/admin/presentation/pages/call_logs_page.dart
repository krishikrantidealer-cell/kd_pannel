import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
import 'package:kd_pannel/features/shared/widgets/telephony_call_button.dart';

class CallLogsPage extends StatefulWidget {
  const CallLogsPage({super.key});

  @override
  State<CallLogsPage> createState() => _CallLogsPageState();
}

class _CallLogsPageState extends State<CallLogsPage> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

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
      final agentName = (agent is Map ? '${agent['firstName'] ?? ''} ${agent['lastName'] ?? ''}'.trim() : '')?.replaceAll(',', ' ') ?? '';
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

  void _openAudioPlayer(dynamic log) async {
    String recordingUrl = (log['recordingUrl'] ?? '').toString();
    
    if (recordingUrl.isEmpty) {
      final callId = log['_id']?.toString() ?? '';
      if (callId.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                  SizedBox(width: 12),
                  Text('Fetching audio recording from MyOperator...'),
                ],
              ),
              duration: Duration(seconds: 2),
            ),
          );
        }
        try {
          final res = await ApiClient().get('/call/recordings/$callId/url');
          if (res.statusCode == 200) {
            final decoded = jsonDecode(res.body);
            if (decoded is Map && decoded['data'] is Map && decoded['data']['recordingUrl'] != null) {
              recordingUrl = decoded['data']['recordingUrl'].toString();
              log['recordingUrl'] = recordingUrl;
            }
          }
        } catch (_) {}
      }
    }

    if (recordingUrl.isEmpty) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: Color(0xFF008069), size: 24),
                const SizedBox(width: 8),
                Text('Recording Not Synced Yet', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'The recording URL for this call has not been pushed by MyOperator Webhook yet, or the API token does not have direct pull permissions enabled.',
                  style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF475569)),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('To enable automatic in-panel audio sync:', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12, color: const Color(0xFF1E293B))),
                      const SizedBox(height: 4),
                      Text('1. Go to MyOperator Dashboard → APIs & Webhooks', style: GoogleFonts.outfit(fontSize: 11.5, color: const Color(0xFF64748B))),
                      Text('2. Set Webhook URL to your backend webhook endpoint', style: GoogleFonts.outfit(fontSize: 11.5, color: const Color(0xFF64748B))),
                      Text('3. Check "Call Ended" and "Recordings"', style: GoogleFonts.outfit(fontSize: 11.5, color: const Color(0xFF64748B))),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Close', style: GoogleFonts.outfit(color: const Color(0xFF64748B))),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF008069),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: Text('Open MyOperator Portal', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                onPressed: () {
                  Navigator.pop(ctx);
                  launchUrl(Uri.parse('https://myoperator.com/app/call-logs'), mode: LaunchMode.externalApplication);
                },
              ),
            ],
          ),
        );
      }
      return;
    }

    final phone = (log['customerPhone'] ?? '').toString();
    final contact = log['contactId'];
    final name = (contact is Map ? contact['name']?.toString() : null) ?? 'Customer (+$phone)';
    final duration = int.tryParse((log['durationSeconds'] ?? 0).toString()) ?? 0;

    web.HTMLAudioElement? audioEl;
    if (kIsWeb) {
      try {
        audioEl = web.HTMLAudioElement();
        audioEl.src = recordingUrl;
      } catch (_) {}
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        bool isPlaying = false;
        double currentPosition = 0;
        double playbackSpeed = 1.0;
        Timer? ticker;

        return StatefulBuilder(
          builder: (context, setModalState) {
            void togglePlay() {
              if (audioEl != null) {
                if (isPlaying) {
                  audioEl.pause();
                  ticker?.cancel();
                  setModalState(() => isPlaying = false);
                } else {
                  audioEl.play();
                  ticker?.cancel();
                  ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
                    if (context.mounted && audioEl != null) {
                      final el = audioEl;
                      if (el != null) {
                        setModalState(() {
                          currentPosition = el.currentTime.toDouble();
                          if (el.ended) {
                            isPlaying = false;
                            currentPosition = 0;
                            ticker?.cancel();
                          }
                        });
                      }
                    }
                  });
                  setModalState(() => isPlaying = true);
                }
              } else {
                _playRecording(recordingUrl);
              }
            }

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF008069).withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.graphic_eq_rounded, color: Color(0xFF008069), size: 20),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15, color: const Color(0xFF111B21))),
                              Text('Duration: ${_formatDuration(duration)} • In-Panel Player', style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B))),
                            ],
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                        onPressed: () {
                          ticker?.cancel();
                          audioEl?.pause();
                          Navigator.pop(ctx);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Progress & Playback Controls
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        // Slider / Progress bar
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: const Color(0xFF008069),
                            inactiveTrackColor: const Color(0xFFCBD5E1),
                            thumbColor: const Color(0xFF008069),
                            trackHeight: 4,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                          ),
                          child: Slider(
                            value: currentPosition.clamp(0.0, duration > 0 ? duration.toDouble() : 1.0),
                            min: 0.0,
                            max: duration > 0 ? duration.toDouble() : 1.0,
                            onChanged: (val) {
                              if (audioEl != null) {
                                audioEl.currentTime = val;
                              }
                              setModalState(() => currentPosition = val);
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_formatDuration(currentPosition.toInt()), style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B))),
                              Text(_formatDuration(duration), style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B))),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Speed selection
                            Row(
                              children: [
                                Text('Speed: ', style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B))),
                                DropdownButton<double>(
                                  value: playbackSpeed,
                                  underline: const SizedBox(),
                                  items: const [
                                    DropdownMenuItem(value: 0.75, child: Text('0.75x')),
                                    DropdownMenuItem(value: 1.0, child: Text('1.0x')),
                                    DropdownMenuItem(value: 1.25, child: Text('1.25x')),
                                    DropdownMenuItem(value: 1.5, child: Text('1.5x')),
                                    DropdownMenuItem(value: 2.0, child: Text('2.0x')),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) {
                                      if (audioEl != null) {
                                        audioEl.playbackRate = val;
                                      }
                                      setModalState(() => playbackSpeed = val);
                                    }
                                  },
                                ),
                              ],
                            ),
                            // In-Panel Play/Pause Button
                            ElevatedButton.icon(
                              onPressed: togglePlay,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF008069),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 18),
                              label: Text(isPlaying ? 'Pause' : 'Play Audio', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).then((_) {
      audioEl?.pause();
    });
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
                        ElevatedButton.icon(
                          onPressed: () => TelephonyHelper.showDialpad(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF008069),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.dialpad_rounded, size: 16),
                          label: Text(
                            'Dial Number',
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                        const SizedBox(width: 8),
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
                        const SizedBox(width: 8),
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
                      // ── Scheduled Follow-ups Alert Ribbon ─────────────
                      Builder(
                        builder: (context) {
                          final pendingFollowUps = state.callLogs.where((l) => l['followUpDate'] != null).toList();
                          if (pendingFollowUps.isEmpty) return const SizedBox.shrink();

                          return Container(
                            margin: const EdgeInsets.only(bottom: 20),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFFDE68A)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.alarm_on_rounded, color: Color(0xFFD97706), size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    '${pendingFollowUps.length} Scheduled Follow-up callback(s) pending in this view. Review ACW notes and re-connect with leads.',
                                    style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF92400E)),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),

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
                                  suffixIcon: _searchController.text.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF64748B)),
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
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                                DropdownMenuItem(value: 'no-answer', child: Text('📵 No Answer')),
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
                        child: Column(
                          children: [
                            if (state.isLoading && state.callLogs.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(40),
                                child: Center(child: CircularProgressIndicator(color: Color(0xFF008069))),
                              )
                            else if (state.callLogs.isEmpty)
                              Padding(
                                padding: const EdgeInsets.all(40),
                                child: Center(
                                  child: Text('No call logs found', style: GoogleFonts.outfit(fontSize: 14, color: const Color(0xFF64748B))),
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
                                  final isOutbound = (log['direction'] ?? log['type']) == 'outbound';
                                  final rawStatus = (log['status'] ?? 'initiated').toString().toLowerCase();
                                  final String customerPhone = log['customerPhone'] ?? 'Unknown';
                                  final contact = log['contactId'] is Map ? log['contactId'] : null;
                                  final String contactName = (contact?['name'] ?? '').toString().trim();
                                  final agent = log['agentId'] is Map ? log['agentId'] : {};
                                  final String agentName = '${agent['firstName'] ?? ''} ${agent['lastName'] ?? ''}'.trim();
                                  final String recordingUrl = log['recordingUrl'] ?? '';
                                  final int seconds = int.tryParse(log['durationSeconds']?.toString() ?? '0') ?? 0;
                                  final String userDisposition = log['userDisposition'] ?? '';
                                  final String notesText = (log['notes'] ?? log['followUpNote'] ?? '').toString().trim();

                                  Color statusBg = const Color(0xFF008069).withValues(alpha: 0.1);
                                  Color statusFg = const Color(0xFF008069);
                                  String statusLabel = 'ANSWERED';

                                  if (rawStatus == 'missed') {
                                    statusBg = Colors.red.withValues(alpha: 0.1);
                                    statusFg = Colors.red;
                                    statusLabel = 'MISSED';
                                  } else if (rawStatus == 'busy') {
                                    statusBg = Colors.amber.withValues(alpha: 0.15);
                                    statusFg = Colors.orange[800]!;
                                    statusLabel = 'BUSY';
                                  } else if (rawStatus == 'no-answer') {
                                    statusBg = Colors.orange.withValues(alpha: 0.12);
                                    statusFg = Colors.deepOrange;
                                    statusLabel = 'NO ANSWER';
                                  } else if (rawStatus == 'failed') {
                                    statusBg = Colors.red.withValues(alpha: 0.1);
                                    statusFg = Colors.redAccent;
                                    statusLabel = 'FAILED';
                                  } else if (rawStatus != 'answered') {
                                    statusBg = Colors.grey.withValues(alpha: 0.12);
                                    statusFg = Colors.grey[700]!;
                                    statusLabel = rawStatus.toUpperCase();
                                  }

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
                                          contactName.isNotEmpty ? contactName : '+$customerPhone',
                                          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: const Color(0xFF111B21)),
                                        ),
                                        if (contactName.isNotEmpty) ...[
                                          const SizedBox(width: 6),
                                          Text(
                                            '(+$customerPhone)',
                                            style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B)),
                                          ),
                                        ],
                                        const SizedBox(width: 10),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: statusBg,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            statusLabel,
                                            style: GoogleFonts.outfit(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: statusFg,
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
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFF1F5F9),
                                                  borderRadius: BorderRadius.circular(3),
                                                ),
                                                child: Text(
                                                  isOutbound ? 'Outbound' : 'Inbound',
                                                  style: GoogleFonts.outfit(fontSize: 10.5, fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
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
                                          if (notesText.isNotEmpty) ...[
                                            const SizedBox(height: 3),
                                            Text(
                                              '💬 ACW Notes: $notesText',
                                              style: GoogleFonts.outfit(fontSize: 11.5, color: const Color(0xFF64748B), fontStyle: FontStyle.italic),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
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

                                        if (recordingUrl.isNotEmpty || rawStatus == 'answered' || seconds > 0)
                                          ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFF008069).withValues(alpha: 0.1),
                                              foregroundColor: const Color(0xFF008069),
                                              elevation: 0,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            ),
                                            icon: const Icon(Icons.headphones_rounded, size: 16),
                                            label: Text(recordingUrl.isNotEmpty ? 'Listen Audio' : 'Fetch Audio', style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.bold)),
                                            onPressed: () => _openAudioPlayer(log),
                                          )
                                        else
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF1F5F9),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.mic_off_outlined, size: 13, color: Colors.grey.shade500),
                                                const SizedBox(width: 4),
                                                Text('No Audio', style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  );
                                },
                              ),

                            // ── Pagination Footer ──────────────────────────────
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
                                        // Previous Page
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
                                            border: Border.all(color: const Color(0xFF008069).withValues(alpha: 0.2)),
                                          ),
                                          child: Text(
                                            'Page ${state.page} of ${state.totalPages}',
                                            style: GoogleFonts.outfit(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.bold,
                                              color: const Color(0xFF008069),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        // Next Page
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
          ),
        );
      },
    );
  }
}
