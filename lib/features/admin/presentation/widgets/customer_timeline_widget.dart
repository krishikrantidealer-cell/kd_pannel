import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:kd_pannel/app_theme.dart';
import 'package:kd_pannel/core/network/api_client.dart';

class CustomerTimelineWidget extends StatefulWidget {
  final String? phone;
  final String? userId;
  final String? customerName;
  final VoidCallback? onTriggerCall;
  final VoidCallback? onOpenWhatsApp;

  const CustomerTimelineWidget({
    super.key,
    this.phone,
    this.userId,
    this.customerName,
    this.onTriggerCall,
    this.onOpenWhatsApp,
  });

  @override
  State<CustomerTimelineWidget> createState() => _CustomerTimelineWidgetState();
}

class _CustomerTimelineWidgetState extends State<CustomerTimelineWidget> {
  bool _isLoading = true;
  List<dynamic> _timelineItems = [];
  String _selectedFilter = 'all'; // all, call, whatsapp, order, note, telemetry

  @override
  void initState() {
    super.initState();
    _fetchTimeline();
  }

  @override
  void didUpdateWidget(covariant CustomerTimelineWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.phone != widget.phone || oldWidget.userId != widget.userId) {
      _fetchTimeline();
    }
  }

  Future<void> _fetchTimeline() async {
    setState(() => _isLoading = true);
    try {
      String endpoint = '/timeline?';
      if (widget.phone != null && widget.phone!.isNotEmpty) {
        endpoint += 'phone=${Uri.encodeComponent(widget.phone!)}';
      }
      if (widget.userId != null && widget.userId!.isNotEmpty) {
        endpoint += '${endpoint.endsWith('?') ? '' : '&'}userId=${widget.userId}';
      }

      final res = await ApiClient().get(endpoint);
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true) {
          setState(() {
            _timelineItems = body['data']?['timeline'] ?? [];
          });
        }
      }
    } catch (e) {
      debugPrint('[CustomerTimelineWidget] Error fetching timeline: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openRecordingUrl(String url) async {
    if (url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Color _getItemColor(String type) {
    switch (type) {
      case 'call':
        return const Color(0xFF2563EB); // Blue
      case 'whatsapp':
        return const Color(0xFF008069); // WhatsApp Green
      case 'order':
        return const Color(0xFF9333EA); // Purple
      case 'note':
        return const Color(0xFFF59E0B); // Amber
      case 'telemetry':
        return const Color(0xFF06B6D4); // Cyan
      default:
        return const Color(0xFF64748B);
    }
  }

  IconData _getItemIcon(String type) {
    switch (type) {
      case 'call':
        return Icons.phone_in_talk_rounded;
      case 'whatsapp':
        return Icons.chat_rounded;
      case 'order':
        return Icons.shopping_bag_rounded;
      case 'note':
        return Icons.edit_note_rounded;
      case 'telemetry':
        return Icons.touch_app_rounded;
      default:
        return Icons.event_note_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = _selectedFilter == 'all'
        ? _timelineItems
        : _timelineItems.where((i) => i['type'] == _selectedFilter).toList();

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
          // Header
          Container(
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.history_toggle_off_rounded, color: Color(0xFF0F172A), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Customer 360° Activity Timeline',
                          style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                        ),
                        Text(
                          'Omnichannel stream: Calls, WhatsApp, Notes, Orders & App Events',
                          style: GoogleFonts.outfit(fontSize: 11.5, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ],
                ),
                Row(
                  children: [
                    if (widget.onTriggerCall != null)
                      ElevatedButton.icon(
                        onPressed: widget.onTriggerCall,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF008069),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.call_rounded, size: 15),
                        label: Text('1-Click Call', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    const SizedBox(width: 8),
                    if (widget.onOpenWhatsApp != null)
                      OutlinedButton.icon(
                        onPressed: widget.onOpenWhatsApp,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF008069),
                          side: const BorderSide(color: Color(0xFF008069)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.chat_rounded, size: 15),
                        label: Text('WhatsApp CRM', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, size: 20, color: Color(0xFF64748B)),
                      onPressed: _fetchTimeline,
                      tooltip: 'Refresh Timeline',
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Filters Chip Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            color: const Color(0xFFF8FAFC),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _buildFilterChip('all', 'All Activity (${_timelineItems.length})', Icons.auto_awesome_rounded),
                  const SizedBox(width: 6),
                  _buildFilterChip('call', 'Calls (${_timelineItems.where((i) => i['type'] == 'call').length})', Icons.phone_in_talk_rounded),
                  const SizedBox(width: 6),
                  _buildFilterChip('whatsapp', 'WhatsApp (${_timelineItems.where((i) => i['type'] == 'whatsapp').length})', Icons.chat_rounded),
                  const SizedBox(width: 6),
                  _buildFilterChip('order', 'Orders (${_timelineItems.where((i) => i['type'] == 'order').length})', Icons.shopping_bag_rounded),
                  const SizedBox(width: 6),
                  _buildFilterChip('note', 'Notes (${_timelineItems.where((i) => i['type'] == 'note').length})', Icons.edit_note_rounded),
                  const SizedBox(width: 6),
                  _buildFilterChip('telemetry', 'App Events (${_timelineItems.where((i) => i['type'] == 'telemetry').length})', Icons.touch_app_rounded),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Timeline Stream
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator(color: Color(0xFF008069))),
            )
          else if (filteredItems.isEmpty)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.history_edu_rounded, size: 40, color: Colors.grey.shade400),
                    const SizedBox(height: 10),
                    Text(
                      'No timeline activities found for this filter.',
                      style: GoogleFonts.outfit(color: const Color(0xFF64748B), fontSize: 13),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              itemCount: filteredItems.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = filteredItems[index];
                final String type = item['type'] ?? 'general';
                final Color color = _getItemColor(type);
                final IconData icon = _getItemIcon(type);

                String formattedDate = '';
                if (item['timestamp'] != null) {
                  final dt = DateTime.tryParse(item['timestamp'].toString())?.toLocal();
                  if (dt != null) {
                    formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(dt);
                  }
                }

                final String recordingUrl = item['recordingUrl'] ?? '';

                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon, color: color, size: 18),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    item['title'] ?? '',
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13.5,
                                      color: const Color(0xFF0F172A),
                                    ),
                                  ),
                                ),
                                Text(
                                  formattedDate,
                                  style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF94A3B8)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item['subtitle'] ?? '',
                              style: GoogleFonts.outfit(fontSize: 12.5, color: const Color(0xFF475569)),
                            ),
                            if (item['agentName'] != null && item['agentName'].toString().isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(Icons.person_pin_circle_rounded, size: 13, color: Colors.grey.shade600),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Logged by: ${item['agentName']}',
                                    style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF64748B), fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ],
                            if (recordingUrl.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              InkWell(
                                onTap: () => _openRecordingUrl(recordingUrl),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.2)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.play_circle_filled_rounded, color: Color(0xFF2563EB), size: 16),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Listen Call Recording (MyOperator CDN)',
                                        style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.bold, color: const Color(0xFF2563EB)),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label, IconData icon) {
    final isSelected = _selectedFilter == value;
    return InkWell(
      onTap: () => setState(() => _selectedFilter = value),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFCBD5E1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: isSelected ? const Color(0xFF4ADE80) : const Color(0xFF64748B)),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
