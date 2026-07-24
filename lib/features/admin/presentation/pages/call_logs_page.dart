import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:kd_pannel/core/auth/auth_service.dart';
import 'package:kd_pannel/core/network/api_client.dart';

class CallLogsPage extends StatefulWidget {
  const CallLogsPage({super.key});

  @override
  State<CallLogsPage> createState() => _CallLogsPageState();
}

class _CallLogsPageState extends State<CallLogsPage> {
  List<dynamic> _callLogs = [];
  List<dynamic> _salesAgents = [];
  bool _isLoading = true;

  // Filters
  String _selectedType = 'all'; // all, inbound, outbound
  String _selectedStatus = 'all'; // all, answered, missed, busy
  String? _selectedAgentId;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  int _totalCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchSalesAgents();
    _fetchCallLogs();
  }

  Future<void> _fetchSalesAgents() async {
    try {
      final res = await ApiClient().get('/users?role=sales');
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true) {
          setState(() {
            _salesAgents = body['data'] ?? [];
          });
        }
      }
    } catch (e) {
      debugPrint('[Call Logs] Error fetching agents: $e');
    }
  }

  Future<void> _fetchCallLogs({int page = 1}) async {
    setState(() {
      _isLoading = true;
    });

    try {
      String endpoint = '/calls/logs?page=$page&limit=25';
      if (_searchQuery.isNotEmpty) {
        endpoint += '&customerPhone=${Uri.encodeComponent(_searchQuery)}';
      }
      if (_selectedAgentId != null) {
        endpoint += '&agentId=$_selectedAgentId';
      }

      final res = await ApiClient().get(endpoint);
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true) {
          List<dynamic> logs = body['data'] ?? [];

          // Local Filter application for type & status
          if (_selectedType != 'all') {
            logs = logs.where((l) => l['type'] == _selectedType).toList();
          }
          if (_selectedStatus != 'all') {
            logs = logs.where((l) => l['status'] == _selectedStatus).toList();
          }

          setState(() {
            _callLogs = logs;
            _totalCount = body['pagination']?['total'] ?? logs.length;
          });
        }
      }
    } catch (e) {
      debugPrint('[Call Logs] Error fetching call logs: $e');
    } finally {
      setState(() => _isLoading = false);
    }
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

  @override
  Widget build(BuildContext context) {
    final role = AuthService().currentUserRole ?? UserRole.admin;
    final int inboundCount = _callLogs.where((l) => l['type'] == 'inbound').length;
    final int outboundCount = _callLogs.where((l) => l['type'] == 'outbound').length;
    final int missedCount = _callLogs.where((l) => l['status'] == 'missed').length;
    final int totalSeconds = _callLogs.fold(0, (sum, item) => sum + (int.tryParse(item['durationSeconds']?.toString() ?? '0') ?? 0));

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
                          role == UserRole.admin ? 'Call Recordings & Analytics' : 'Sales Call History',
                          style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF111B21)),
                        ),
                        Text(
                          'Monitor inbound/outbound calls, talk time, and audio recordings',
                          style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: Color(0xFF008069)),
                  onPressed: () => _fetchCallLogs(),
                  tooltip: 'Refresh Call Logs',
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
                  // KPI Metric Cards
                  Row(
                    children: [
                      Expanded(child: _buildMetricCard('Total Calls', '$_totalCount', Icons.phone_rounded, Colors.blue)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildMetricCard('Inbound Calls', '$inboundCount', Icons.call_received_rounded, Colors.green)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildMetricCard('Outbound Calls', '$outboundCount', Icons.call_made_rounded, Colors.teal)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildMetricCard('Total Talk Time', _formatDuration(totalSeconds), Icons.timer_rounded, Colors.purple)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildMetricCard('Missed Calls', '$missedCount', Icons.phone_missed_rounded, Colors.red)),
                    ],
                  ),
                  const SizedBox(height: 24),

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
                              hintText: 'Search customer phone or agent name...',
                              hintStyle: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF94A3B8)),
                              prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF008069), size: 18),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            onSubmitted: (val) {
                              _searchQuery = val.trim();
                              _fetchCallLogs();
                            },
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Call Type Filter
                        DropdownButton<String>(
                          value: _selectedType,
                          underline: const SizedBox(),
                          style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF111B21), fontWeight: FontWeight.w600),
                          items: const [
                            DropdownMenuItem(value: 'all', child: Text('Type: All')),
                            DropdownMenuItem(value: 'inbound', child: Text('📥 Inbound')),
                            DropdownMenuItem(value: 'outbound', child: Text('📤 Outbound')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedType = val);
                              _fetchCallLogs();
                            }
                          },
                        ),
                        const SizedBox(width: 16),

                        // Call Status Filter
                        DropdownButton<String>(
                          value: _selectedStatus,
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
                              setState(() => _selectedStatus = val);
                              _fetchCallLogs();
                            }
                          },
                        ),

                        if (role == UserRole.admin && _salesAgents.isNotEmpty) ...[
                          const SizedBox(width: 16),
                          DropdownButton<String?>(
                            value: _selectedAgentId,
                            hint: Text('Filter Agent: All', style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF111B21), fontWeight: FontWeight.w600)),
                            underline: const SizedBox(),
                            items: [
                              const DropdownMenuItem<String?>(value: null, child: Text('Filter Agent: All')),
                              ..._salesAgents.map((agent) {
                                return DropdownMenuItem<String?>(
                                  value: agent['_id'],
                                  child: Text('${agent['firstName'] ?? ''} ${agent['lastName'] ?? ''}'.trim()),
                                );
                              }),
                            ],
                            onChanged: (val) {
                              setState(() => _selectedAgentId = val);
                              _fetchCallLogs();
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
                    child: _isLoading
                        ? const Padding(
                            padding: EdgeInsets.all(40),
                            child: Center(child: CircularProgressIndicator(color: Color(0xFF008069))),
                          )
                        : _callLogs.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.all(40),
                                child: Center(
                                  child: Text('No call logs found', style: GoogleFonts.outfit(fontSize: 14, color: const Color(0xFF64748B))),
                                ),
                              )
                            : ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _callLogs.length,
                                separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                itemBuilder: (context, index) {
                                  final log = _callLogs[index];
                                  final isOutbound = log['type'] == 'outbound';
                                  final isAnswered = log['status'] == 'answered';
                                  final String customerPhone = log['customerPhone'] ?? 'Unknown';
                                  final agent = log['agentId'] ?? {};
                                  final String agentName = '${agent['firstName'] ?? ''} ${agent['lastName'] ?? ''}'.trim();
                                  final String recordingUrl = log['recordingUrl'] ?? '';
                                  final int seconds = int.tryParse(log['durationSeconds']?.toString() ?? '0') ?? 0;

                                  String formattedDate = '';
                                  if (log['createdAt'] != null) {
                                    final date = DateTime.parse(log['createdAt']).toLocal();
                                    formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(date);
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
                                                ? Colors.green.withValues(alpha: 0.1)
                                                : Colors.red.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            log['status']?.toString().toUpperCase() ?? 'UNANSWERED',
                                            style: GoogleFonts.outfit(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: isAnswered ? Colors.green[800] : Colors.red[800],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 4),
                                        Text(
                                          'Sales Rep: ${agentName.isNotEmpty ? agentName : "System"}  •  Time: $formattedDate  •  Duration: ${_formatDuration(seconds)}',
                                          style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B)),
                                        ),
                                        if (log['callSummary'] != null && log['callSummary'].toString().isNotEmpty)
                                          Text(
                                            'Summary: ${log['callSummary']}',
                                            style: GoogleFonts.outfit(fontSize: 11.5, color: const Color(0xFF008069), fontWeight: FontWeight.w500),
                                          ),
                                      ],
                                    ),
                                    trailing: recordingUrl.isNotEmpty
                                        ? ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFF008069).withValues(alpha: 0.1),
                                              foregroundColor: const Color(0xFF008069),
                                              elevation: 0,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            ),
                                            icon: const Icon(Icons.play_arrow_rounded, size: 16),
                                            label: Text('Listen Recording', style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.bold)),
                                            onPressed: () => _playRecording(recordingUrl),
                                          )
                                        : Text(
                                            'No Recording',
                                            style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF94A3B8)),
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
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.outfit(fontSize: 11.5, color: const Color(0xFF64748B))),
              const SizedBox(height: 2),
              Text(value, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF111B21))),
            ],
          ),
        ],
      ),
    );
  }
}
