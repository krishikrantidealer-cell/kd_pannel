import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:kd_pannel/core/network/api_client.dart';

/// Telephony timeline dialog showing MyOperator call logs and recording playback
class WhatsAppCallHistoryDialog extends StatefulWidget {
  final String rawPhone;
  final String customerName;

  const WhatsAppCallHistoryDialog({
    super.key,
    required this.rawPhone,
    required this.customerName,
  });

  static String normalizePhone(String phone) {
    String p = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (p.length == 12 && p.startsWith('91')) {
      p = p.substring(2);
    } else if (p.length == 11 && p.startsWith('0')) {
      p = p.substring(1);
    }
    return p;
  }

  static void show(BuildContext context, {required String rawPhone, required String customerName}) {
    final cleanPhone = normalizePhone(rawPhone);
    if (cleanPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No phone number available for $customerName', style: GoogleFonts.outfit()),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => WhatsAppCallHistoryDialog(
        rawPhone: rawPhone,
        customerName: customerName,
      ),
    );
  }

  @override
  State<WhatsAppCallHistoryDialog> createState() => _WhatsAppCallHistoryDialogState();
}

class _WhatsAppCallHistoryDialogState extends State<WhatsAppCallHistoryDialog> {
  List<dynamic> _customerCalls = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCalls();
  }

  Future<void> _fetchCalls() async {
    final cleanPhone = WhatsAppCallHistoryDialog.normalizePhone(widget.rawPhone);
    try {
      final res = await ApiClient().get(
        '/calls/logs?search=$cleanPhone&customerPhone=$cleanPhone&limit=50',
      );
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final List<dynamic> logs = body['data'] is List
            ? (body['data'] as List)
            : (body['data']?['callLogs'] ?? []);
        if (mounted) {
          setState(() {
            _customerCalls = List<dynamic>.from(logs);
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cleanPhone = WhatsAppCallHistoryDialog.normalizePhone(widget.rawPhone);
    final displayName = widget.customerName.isNotEmpty ? widget.customerName : 'Customer';

    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 620,
        height: 580,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFF008069).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.phone_in_talk_rounded, color: Color(0xFF008069), size: 18),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              displayName,
                              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15, color: const Color(0xFF0F172A)),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Text(
                                '+91 $cleanPhone',
                                style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Call History & Recordings Timeline',
                          style: GoogleFonts.outfit(fontSize: 11.5, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ],
                ),
                Row(
                  children: [
                    if (!_isLoading && _customerCalls.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: Text(
                          '${_customerCalls.length} calls',
                          style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF065F46)),
                        ),
                      ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF64748B)),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 10),

            // Call Log List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF008069), strokeWidth: 2.5))
                  : _customerCalls.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.phone_disabled_rounded, size: 40, color: Colors.grey.shade300),
                              const SizedBox(height: 8),
                              Text('No call records found for this contact', style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF64748B))),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: _customerCalls.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 6),
                          itemBuilder: (ctx, i) {
                            final call = _customerCalls[i];
                            final status = (call['status'] ?? 'initiated').toString().toLowerCase();
                            final duration = int.tryParse((call['durationSeconds'] ?? 0).toString()) ?? 0;
                            final mins = duration ~/ 60;
                            final secs = duration % 60;
                            final durText = duration > 0 ? '${mins}m ${secs}s' : '0s';
                            final isOutbound = (call['direction'] ?? call['type'] ?? 'outbound').toString().toLowerCase() == 'outbound';
                            final bool isSuccessful = status == 'answered' || status == 'completed';
                            final bool isMissed = status == 'missed' || status == 'failed' || status == 'no-answer' || status == 'rejected';

                            final agent = call['agentId'];
                            final agentName = agent is Map
                                ? '${agent['firstName'] ?? ''} ${agent['lastName'] ?? ''}'.trim()
                                : (call['agentName'] ?? 'Agent').toString();
                            final rawDate = call['createdAt'];
                            final dateText = rawDate != null
                                ? DateFormat('dd MMM, hh:mm a').format(DateTime.tryParse(rawDate.toString())?.toLocal() ?? DateTime.now())
                                : '';
                            final userDisp = (call['userDisposition'] ?? call['disposition'] ?? '').toString().trim();
                            final notes = (call['notes'] ?? '').toString().trim();
                            final rawRecordingUrl = (call['recordingUrl'] ?? '').toString().trim();
                            final hasRecording = rawRecordingUrl.isNotEmpty;

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

                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: iconBg,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      isMissed
                                          ? Icons.phone_missed_rounded
                                          : isOutbound
                                              ? Icons.call_made_rounded
                                              : Icons.call_received_rounded,
                                      size: 16,
                                      color: iconColor,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              isOutbound ? 'Outbound' : 'Inbound',
                                              style: GoogleFonts.outfit(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12.5,
                                                color: const Color(0xFF1E293B),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                              decoration: BoxDecoration(
                                                color: isSuccessful
                                                    ? const Color(0xFFDCFCE7)
                                                    : isMissed
                                                        ? const Color(0xFFFEE2E2)
                                                        : const Color(0xFFF1F5F9),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                status.toUpperCase(),
                                                style: GoogleFonts.outfit(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                  color: isSuccessful
                                                      ? const Color(0xFF15803D)
                                                      : isMissed
                                                          ? const Color(0xFFB91C1C)
                                                          : const Color(0xFF64748B),
                                                ),
                                              ),
                                            ),
                                            const Spacer(),
                                            Text(
                                              dateText,
                                              style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF94A3B8)),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Row(
                                          children: [
                                            Text(
                                              '⏱ $durText',
                                              style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
                                            ),
                                            const SizedBox(width: 10),
                                            Text(
                                              '👤 $agentName',
                                              style: GoogleFonts.outfit(fontSize: 11.5, color: const Color(0xFF64748B)),
                                            ),
                                            if (userDisp.isNotEmpty || notes.isNotEmpty) ...[
                                              const SizedBox(width: 8),
                                              Flexible(
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFFFFBEB),
                                                    borderRadius: BorderRadius.circular(4),
                                                    border: Border.all(color: const Color(0xFFFDE68A)),
                                                  ),
                                                  child: Text(
                                                    '📝 ${userDisp.isNotEmpty ? userDisp : notes}',
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: GoogleFonts.outfit(fontSize: 10.5, color: const Color(0xFF92400E), fontWeight: FontWeight.w500),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  InkWell(
                                    borderRadius: BorderRadius.circular(6),
                                    onTap: () async {
                                      String recordingUrl = rawRecordingUrl;
                                      final logId = call['_id']?.toString() ?? call['callId']?.toString() ?? '';

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
                                      } else if (cleanPhone.isNotEmpty) {
                                        targetUrl = 'https://myoperator.com/app/call-logs?search=$cleanPhone';
                                      }

                                      final uri = Uri.parse(targetUrl);
                                      if (await canLaunchUrl(uri)) {
                                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: hasRecording ? const Color(0xFF008069).withValues(alpha: 0.08) : const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: hasRecording ? const Color(0xFF008069).withValues(alpha: 0.25) : const Color(0xFFE2E8F0),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            hasRecording ? Icons.play_arrow_rounded : Icons.open_in_new_rounded,
                                            size: 14,
                                            color: hasRecording ? const Color(0xFF008069) : const Color(0xFF64748B),
                                          ),
                                          const SizedBox(width: 3),
                                          Text(
                                            hasRecording ? 'Play' : 'Logs',
                                            style: GoogleFonts.outfit(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: hasRecording ? const Color(0xFF008069) : const Color(0xFF64748B),
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
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
