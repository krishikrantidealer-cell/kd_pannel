import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kd_pannel/core/network/api_client.dart';
import 'package:kd_pannel/core/responsive/responsive.dart';
import 'package:kd_pannel/features/admin/presentation/widgets/call_disposition_dialog.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/call_logs_bloc.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/call_logs_event.dart';

class CustomerCallLogsTab extends StatefulWidget {
  final String? phone;
  final String? customerName;
  final String? userId;
  final VoidCallback? onRefresh;

  const CustomerCallLogsTab({
    super.key,
    required this.phone,
    this.customerName,
    this.userId,
    this.onRefresh,
  });

  @override
  State<CustomerCallLogsTab> createState() => _CustomerCallLogsTabState();
}

class _CustomerCallLogsTabState extends State<CustomerCallLogsTab> {
  bool _isLoading = true;
  List<dynamic> _callLogs = [];
  String _selectedFilter = 'all'; // all, outbound, inbound, answered, missed
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  static String normalizePhone(String rawPhone) {
    String p = rawPhone.replaceAll(RegExp(r'[^0-9]'), '');
    if (p.length == 12 && p.startsWith('91')) {
      p = p.substring(2);
    } else if (p.length == 11 && p.startsWith('0')) {
      p = p.substring(1);
    }
    return p;
  }

  @override
  void initState() {
    super.initState();
    _fetchCallLogs();
  }

  @override
  void didUpdateWidget(covariant CustomerCallLogsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.phone != widget.phone || oldWidget.userId != widget.userId) {
      _fetchCallLogs();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchCallLogs() async {
    final cleanPhone = normalizePhone(widget.phone ?? '');
    if (cleanPhone.isEmpty) {
      setState(() {
        _isLoading = false;
        _callLogs = [];
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      final res = await ApiClient().get(
        '/calls/logs?customerPhone=$cleanPhone&search=$cleanPhone&limit=100',
      );

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final List<dynamic> logs = body['data'] is List
            ? (body['data'] as List)
            : (body['data']?['callLogs'] ?? []);

        if (mounted) {
          setState(() {
            _callLogs = List<dynamic>.from(logs);
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('[CustomerCallLogsTab] Error fetching logs: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openRecordingUrl(String url) async {
    if (url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open audio recording: $url', style: GoogleFonts.outfit()),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  void _openDispositionDialog(Map<String, dynamic> callLog) {
    final logId = (callLog['_id'] ?? callLog['id'])?.toString() ?? '';
    final phone = (callLog['customerPhone'] ?? widget.phone ?? '').toString();
    final name = (callLog['customerName'] ?? widget.customerName ?? '').toString();
    final initialDisposition = (callLog['userDisposition'] ?? callLog['disposition'] ?? '').toString();
    final initialNotes = (callLog['notes'] ?? '').toString();
    final initialFollowUpNote = callLog['followUpNote']?.toString();
    DateTime? initialFollowUpDate;
    if (callLog['followUpDate'] != null) {
      try {
        initialFollowUpDate = DateTime.tryParse(callLog['followUpDate'].toString())?.toLocal();
      } catch (_) {}
    }

    final initialTaskReminderTitle = callLog['taskReminderTitle']?.toString();
    final initialTaskReminderNote = callLog['taskReminderNote']?.toString();
    DateTime? initialTaskReminderDate;
    if (callLog['taskReminderDate'] != null) {
      try {
        initialTaskReminderDate = DateTime.tryParse(callLog['taskReminderDate'].toString())?.toLocal();
      } catch (_) {}
    }

    showDialog(
      context: context,
      builder: (dialogCtx) => CallDispositionDialog(
        callLogId: logId,
        customerPhone: phone,
        customerName: name,
        initialDisposition: initialDisposition.isNotEmpty ? initialDisposition : 'Interested',
        initialFollowUpDate: initialFollowUpDate,
        initialFollowUpNote: initialFollowUpNote,
        initialNotes: initialNotes,
        initialTaskReminderDate: initialTaskReminderDate,
        initialTaskReminderTitle: initialTaskReminderTitle,
        initialTaskReminderNote: initialTaskReminderNote,
        onSave: (disposition, followUpDate, followUpNote, notes, {taskReminderDate, taskReminderTitle, taskReminderNote}) {
          context.read<CallLogsBloc>().add(SaveCallDispositionEvent(
            callLogId: logId,
            userDisposition: disposition,
            followUpDate: followUpDate,
            followUpNote: followUpNote,
            notes: notes,
            taskReminderDate: taskReminderDate,
            taskReminderTitle: taskReminderTitle,
            taskReminderNote: taskReminderNote,
          ));
          Future.delayed(const Duration(milliseconds: 600), () {
            if (mounted) _fetchCallLogs();
          });
        },
      ),
    );
  }

  List<dynamic> get _filteredLogs {
    return _callLogs.where((call) {
      final status = (call['status'] ?? '').toString().toLowerCase();
      final direction = (call['direction'] ?? call['type'] ?? '').toString().toLowerCase();
      final duration = int.tryParse((call['durationSeconds'] ?? 0).toString()) ?? 0;

      // Filter Tab
      if (_selectedFilter == 'outbound' && direction != 'outbound') return false;
      if (_selectedFilter == 'inbound' && direction != 'inbound') return false;
      if (_selectedFilter == 'answered' && !(status == 'answered' || duration > 0)) return false;
      if (_selectedFilter == 'missed' && !(status == 'missed' || status == 'no-answer' || status == 'failed')) return false;

      // Search Query
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final disp = (call['userDisposition'] ?? call['disposition'] ?? '').toString().toLowerCase();
        final notes = (call['notes'] ?? call['callSummary'] ?? '').toString().toLowerCase();
        final agent = call['agentId'];
        final agentName = agent is Map
            ? '${agent['firstName'] ?? ''} ${agent['lastName'] ?? ''}'.toLowerCase()
            : (call['agentName'] ?? '').toString().toLowerCase();
        final phone = (call['customerPhone'] ?? '').toString().toLowerCase();

        return disp.contains(q) || notes.contains(q) || agentName.contains(q) || phone.contains(q);
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final cleanPhone = normalizePhone(widget.phone ?? '');
    final isMobile = Responsive.isMobile(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── TOP METRICS & CALL BANNER ─────────────────────────────────────
        _buildHeaderBanner(context, isMobile, cleanPhone),
        const SizedBox(height: 16),

        // ── FILTER TABS & SEARCH BAR ──────────────────────────────────────
        _buildFilterBar(isMobile),
        const SizedBox(height: 16),

        // ── CALL LOGS FEED ───────────────────────────────────────────────
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: CircularProgressIndicator(
                color: Color(0xFF008069),
                strokeWidth: 2.5,
              ),
            ),
          )
        else if (_callLogs.isEmpty)
          _buildEmptyState(cleanPhone)
        else if (_filteredLogs.isEmpty)
          _buildNoMatchingFilterState()
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _filteredLogs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              return _buildCallLogCard(_filteredLogs[index], isMobile);
            },
          ),
      ],
    );
  }

  Widget _buildHeaderBanner(BuildContext context, bool isMobile, String cleanPhone) {
    final total = _callLogs.length;
    int inbound = 0;
    int outbound = 0;
    int answered = 0;
    int missed = 0;
    int totalDurationSecs = 0;

    for (final call in _callLogs) {
      final dir = (call['direction'] ?? call['type'] ?? '').toString().toLowerCase();
      final st = (call['status'] ?? '').toString().toLowerCase();
      final dur = int.tryParse((call['durationSeconds'] ?? 0).toString()) ?? 0;

      if (dir == 'inbound') inbound++;
      if (dir == 'outbound') outbound++;
      if (st == 'answered' || dur > 0) answered++;
      if (st == 'missed' || st == 'no-answer' || st == 'failed') missed++;
      totalDurationSecs += dur;
    }

    final totalMins = totalDurationSecs ~/ 60;
    final totalSecs = totalDurationSecs % 60;
    final talkTimeStr = totalMins > 0 ? '${totalMins}m ${totalSecs}s' : '${totalSecs}s';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 14 : 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF008069).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.phone_in_talk_rounded, color: Color(0xFF008069), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Telephony Call Records',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        SelectableText(
                          cleanPhone.isNotEmpty ? 'Connected Line: +91 $cleanPhone' : 'No phone linked',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: const Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (cleanPhone.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          InkWell(
                            borderRadius: BorderRadius.circular(4),
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: cleanPhone));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                                      const SizedBox(width: 8),
                                      Text('Phone number +91 $cleanPhone copied to clipboard!'),
                                    ],
                                  ),
                                  behavior: SnackBarBehavior.floating,
                                  backgroundColor: const Color(0xFF008069),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                            child: const Tooltip(
                              message: 'Copy phone number',
                              child: Padding(
                                padding: EdgeInsets.all(2.0),
                                child: Icon(Icons.copy_rounded, size: 13, color: Color(0xFF008069)),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _fetchCallLogs,
                tooltip: 'Refresh Call Records',
                icon: const Icon(Icons.refresh_rounded, size: 20, color: Color(0xFF64748B)),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFF1F5F9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 14),

          // Stat Chips Row
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildMiniMetric('Total Calls', '$total', const Color(0xFF475569), Icons.phone_outlined),
              _buildMiniMetric('Outbound', '$outbound', const Color(0xFF059669), Icons.call_made_rounded),
              _buildMiniMetric('Inbound', '$inbound', const Color(0xFF2563EB), Icons.call_received_rounded),
              _buildMiniMetric('Answered', '$answered', const Color(0xFF10B981), Icons.check_circle_outline_rounded),
              _buildMiniMetric('Missed', '$missed', const Color(0xFFE11D48), Icons.call_missed_rounded),
              _buildMiniMetric('Total Talk Time', talkTimeStr, const Color(0xFF7C3AED), Icons.timer_outlined),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniMetric(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label.toUpperCase(),
                style: GoogleFonts.outfit(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: color.withOpacity(0.85),
                  letterSpacing: 0.4,
                ),
              ),
              Text(
                value,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(bool isMobile) {
    final filters = [
      {'key': 'all', 'label': 'All Calls', 'icon': Icons.list_alt_rounded},
      {'key': 'outbound', 'label': 'Outbound', 'icon': Icons.call_made_rounded},
      {'key': 'inbound', 'label': 'Inbound', 'icon': Icons.call_received_rounded},
      {'key': 'answered', 'label': 'Answered', 'icon': Icons.check_circle_outline_rounded},
      {'key': 'missed', 'label': 'Missed', 'icon': Icons.call_missed_rounded},
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: filters.map((f) {
                      final isSelected = _selectedFilter == f['key'];
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: InkWell(
                          onTap: () => setState(() => _selectedFilter = f['key'] as String),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF008069) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected ? const Color(0xFF008069) : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  f['icon'] as IconData,
                                  size: 14,
                                  color: isSelected ? Colors.white : const Color(0xFF64748B),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  f['label'] as String,
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    color: isSelected ? Colors.white : const Color(0xFF475569),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Search input
          TextField(
            controller: _searchController,
            onChanged: (val) => setState(() => _searchQuery = val.trim()),
            style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF1E293B)),
            decoration: InputDecoration(
              hintText: 'Search by agent, disposition, notes...',
              hintStyle: GoogleFonts.outfit(fontSize: 12.5, color: const Color(0xFF94A3B8)),
              prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 16),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              isDense: true,
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF008069), width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCallLogCard(Map<String, dynamic> call, bool isMobile) {
    final status = (call['status'] ?? 'initiated').toString().toLowerCase();
    final direction = (call['direction'] ?? call['type'] ?? 'outbound').toString().toLowerCase();
    final duration = int.tryParse((call['durationSeconds'] ?? 0).toString()) ?? 0;
    final mins = duration ~/ 60;
    final secs = duration % 60;
    final durText = duration > 0 ? '${mins}m ${secs}s' : '0s';
    final isOutbound = direction == 'outbound';
    final bool isMissed = status == 'missed' || status == 'failed' || status == 'no-answer' || status == 'rejected';
    final bool isAnswered = status == 'answered' || status == 'completed' || duration > 0;

    final agent = call['agentId'];
    final agentName = agent is Map
        ? '${agent['firstName'] ?? ''} ${agent['lastName'] ?? ''}'.trim()
        : (call['agentName'] ?? 'Agent').toString();

    final rawDate = call['createdAt'];
    final DateTime? callTime = rawDate != null ? DateTime.tryParse(rawDate.toString())?.toLocal() : null;
    final String dateFormatted = callTime != null ? DateFormat('dd MMM yyyy, hh:mm a').format(callTime) : '';

    final userDisp = (call['userDisposition'] ?? call['disposition'] ?? '').toString().trim();
    final notes = (call['notes'] ?? call['callSummary'] ?? '').toString().trim();
    final rawRecordingUrl = (call['recordingUrl'] ?? '').toString().trim();
    final hasRecording = rawRecordingUrl.isNotEmpty;

    // Follow-up info
    final followUpDateRaw = call['followUpDate'];
    DateTime? followUpDate;
    if (followUpDateRaw != null) {
      try {
        followUpDate = DateTime.tryParse(followUpDateRaw.toString())?.toLocal();
      } catch (_) {}
    }
    final followUpNote = (call['followUpNote'] ?? '').toString().trim();

    // Task Reminder info
    final taskReminderDateRaw = call['taskReminderDate'];
    DateTime? taskReminderDate;
    if (taskReminderDateRaw != null) {
      try {
        taskReminderDate = DateTime.tryParse(taskReminderDateRaw.toString())?.toLocal();
      } catch (_) {}
    }
    final taskReminderTitle = (call['taskReminderTitle'] ?? '').toString().trim();
    final taskReminderNote = (call['taskReminderNote'] ?? '').toString().trim();

    final Color cardBorderColor = isMissed
        ? const Color(0xFFFECDD3)
        : isOutbound
            ? const Color(0xFFA7F3D0)
            : const Color(0xFFBFDBFE);

    final Color iconBg = isMissed
        ? const Color(0xFFFFF1F2)
        : isOutbound
            ? const Color(0xFFECFDF5)
            : const Color(0xFFEFF6FF);

    final Color iconColor = isMissed
        ? const Color(0xFFE11D48)
        : isOutbound
            ? const Color(0xFF059669)
            : const Color(0xFF2563EB);

    final IconData icon = isMissed
        ? Icons.call_missed_rounded
        : isOutbound
            ? Icons.call_made_rounded
            : Icons.call_received_rounded;

    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardBorderColor.withOpacity(0.7)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.015),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Direction Icon
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: iconColor.withOpacity(0.2)),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 12),
              // Call Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          isOutbound ? 'Outbound Call' : 'Inbound Call',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Status pill
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: (isAnswered ? const Color(0xFF10B981) : const Color(0xFFE11D48)).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: (isAnswered ? const Color(0xFF10B981) : const Color(0xFFE11D48)).withOpacity(0.2),
                            ),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: isAnswered ? const Color(0xFF065F46) : const Color(0xFF9F1239),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Duration pill
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.timer_outlined, size: 11, color: Color(0xFF64748B)),
                              const SizedBox(width: 3),
                              Text(
                                durText,
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF475569),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.person_outline_rounded, size: 12, color: Color(0xFF64748B)),
                        const SizedBox(width: 4),
                        Text(
                          'Agent: $agentName',
                          style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.access_time_rounded, size: 12, color: Color(0xFF94A3B8)),
                        const SizedBox(width: 4),
                        Text(
                          dateFormatted,
                          style: GoogleFonts.outfit(fontSize: 11.5, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Action Buttons: Recording + Disposition
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasRecording)
                    ElevatedButton.icon(
                      onPressed: () => _openRecordingUrl(rawRecordingUrl),
                      icon: const Icon(Icons.play_arrow_rounded, size: 15, color: Colors.white),
                      label: Text(
                        'Recording',
                        style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                    ),
                  const SizedBox(width: 6),
                  OutlinedButton.icon(
                    onPressed: () => _openDispositionDialog(call),
                    icon: Icon(
                      userDisp.isNotEmpty ? Icons.edit_note_rounded : Icons.add_comment_rounded,
                      size: 14,
                      color: const Color(0xFFD97706),
                    ),
                    label: Text(
                      userDisp.isNotEmpty ? 'Edit ACW' : 'Add ACW',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFD97706),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      side: const BorderSide(color: Color(0xFFFDE68A)),
                      backgroundColor: const Color(0xFFFEF3C7).withOpacity(0.4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Disposition & Notes section
          if (userDisp.isNotEmpty || notes.isNotEmpty || followUpDate != null || taskReminderDate != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (userDisp.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFFCD34D)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.bookmark_rounded, size: 10, color: Color(0xFFD97706)),
                              const SizedBox(width: 4),
                              Text(
                                userDisp,
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFFB45309),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (followUpDate != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEDE9FE),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFDDD6FE)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.calendar_today_rounded, size: 10, color: Color(0xFF6D28D9)),
                              const SizedBox(width: 4),
                              Text(
                                'Follow-up: ${DateFormat('dd MMM, hh:mm a').format(followUpDate)}',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF6D28D9),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (taskReminderDate != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.notifications_active_rounded, size: 10, color: Color(0xFF1D4ED8)),
                              const SizedBox(width: 4),
                              Text(
                                'Task Reminder: ${DateFormat('dd MMM, hh:mm a').format(taskReminderDate)}',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF1D4ED8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (notes.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      notes,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: const Color(0xFF334155),
                        height: 1.35,
                      ),
                    ),
                  ],
                  if (followUpNote.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Next Step: $followUpNote',
                      style: GoogleFonts.outfit(
                        fontSize: 11.5,
                        fontStyle: FontStyle.italic,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                  if (taskReminderTitle.isNotEmpty || taskReminderNote.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.alarm_rounded, size: 13, color: Color(0xFF1D4ED8)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Task: ${taskReminderTitle.isNotEmpty ? taskReminderTitle : 'Reminder'}${taskReminderNote.isNotEmpty ? ' — $taskReminderNote' : ''}',
                            style: GoogleFonts.outfit(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1E40AF),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState(String cleanPhone) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.phone_disabled_rounded, size: 28, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 14),
            Text(
              'No Call History Found',
              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
            ),
            const SizedBox(height: 6),
            Text(
              cleanPhone.isNotEmpty
                  ? 'No incoming or outgoing calls have been recorded for +91 $cleanPhone yet.'
                  : 'No phone number available to query call records.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoMatchingFilterState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.filter_list_off_rounded, size: 36, color: Color(0xFF94A3B8)),
            const SizedBox(height: 10),
            Text(
              'No calls matching the selected filter or search',
              style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _selectedFilter = 'all';
                  _searchQuery = '';
                });
              },
              child: Text('Reset Filters', style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF008069))),
            ),
          ],
        ),
      ),
    );
  }
}
