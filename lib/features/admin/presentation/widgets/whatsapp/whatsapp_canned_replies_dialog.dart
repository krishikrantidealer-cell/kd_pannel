import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kd_pannel/core/auth/auth_service.dart';
import 'package:kd_pannel/core/network/api_client.dart';

/// Modal dialog for browsing, inserting, and creating canned quick-replies
class WhatsAppCannedRepliesDialog extends StatefulWidget {
  final List<dynamic> cannedResponses;
  final Function(String selectedMessage) onSelectMessage;
  final VoidCallback? onRefresh;

  const WhatsAppCannedRepliesDialog({
    super.key,
    required this.cannedResponses,
    required this.onSelectMessage,
    this.onRefresh,
  });

  static void show(
    BuildContext context, {
    required List<dynamic> cannedResponses,
    required Function(String selectedMessage) onSelectMessage,
    VoidCallback? onRefresh,
  }) {
    showDialog(
      context: context,
      builder: (context) => WhatsAppCannedRepliesDialog(
        cannedResponses: cannedResponses,
        onSelectMessage: onSelectMessage,
        onRefresh: onRefresh,
      ),
    );
  }

  @override
  State<WhatsAppCannedRepliesDialog> createState() => _WhatsAppCannedRepliesDialogState();
}

class _WhatsAppCannedRepliesDialogState extends State<WhatsAppCannedRepliesDialog> {
  String _searchQuery = '';
  late List<dynamic> _localResponses;

  @override
  void initState() {
    super.initState();
    _localResponses = List<dynamic>.from(widget.cannedResponses);
  }

  void _showCreateDialog() {
    final titleController = TextEditingController();
    final shortcutController = TextEditingController();
    final messageController = TextEditingController();
    String category = 'Sales';
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (innerCtx, setDialogState) => Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: 480,
            padding: const EdgeInsets.all(24),
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
                          decoration: const BoxDecoration(
                            color: Color(0xFFFEF3C7),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.bolt_rounded, color: Color(0xFFD97706), size: 20),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'New Canned Response',
                          style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF111B21)),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                      onPressed: () => Navigator.pop(innerCtx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: shortcutController,
                  decoration: InputDecoration(
                    labelText: 'Shortcut (e.g. /pricing or /bank)',
                    labelStyle: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFFD97706), fontWeight: FontWeight.w600),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    isDense: true,
                  ),
                  style: GoogleFonts.outfit(fontSize: 13.5),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: 'Title / Label',
                    labelStyle: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF64748B)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    isDense: true,
                  ),
                  style: GoogleFonts.outfit(fontSize: 13.5),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: InputDecoration(
                    labelText: 'Category',
                    labelStyle: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF64748B)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    isDense: true,
                  ),
                  items: ['Sales', 'Pricing', 'Bank Details', 'Support', 'Order Status', 'Greeting']
                      .map((cat) => DropdownMenuItem(value: cat, child: Text(cat, style: GoogleFonts.outfit(fontSize: 13))))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => category = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: messageController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: 'Message Body',
                    hintText: 'Use {{name}}, {{phone}}, {{agent_name}} for dynamic variables',
                    labelStyle: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF64748B)),
                    hintStyle: GoogleFonts.outfit(fontSize: 11.5, color: const Color(0xFF94A3B8)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  style: GoogleFonts.outfit(fontSize: 13),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => Navigator.pop(innerCtx),
                      child: Text('Cancel', style: GoogleFonts.outfit(color: const Color(0xFF64748B))),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD97706),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () async {
                        final title = titleController.text.trim();
                        final shortcut = shortcutController.text.trim();
                        final msg = messageController.text.trim();
                        if (title.isEmpty || shortcut.isEmpty || msg.isEmpty) return;

                        Navigator.pop(innerCtx);
                        try {
                          final res = await ApiClient().post('/canned-responses', {
                            'title': title,
                            'shortcut': shortcut,
                            'message': msg,
                            'category': category,
                          });
                          if (res.statusCode == 200 || res.statusCode == 201) {
                            widget.onRefresh?.call();
                            scaffoldMessenger.showSnackBar(
                              const SnackBar(
                                content: Text('Canned response created successfully!'),
                                backgroundColor: Color(0xFFD97706),
                              ),
                            );
                          }
                        } catch (e) {
                          debugPrint('[Create Canned Response] Error: $e');
                        }
                      },
                      child: Text('Save Canned Reply', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _localResponses.where((c) {
      final title = (c['title'] ?? '').toString().toLowerCase();
      final shortcut = (c['shortcut'] ?? '').toString().toLowerCase();
      final msg = (c['message'] ?? '').toString().toLowerCase();
      final q = _searchQuery.toLowerCase();
      return title.contains(q) || shortcut.contains(q) || msg.contains(q);
    }).toList();

    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 580,
        height: 600,
        padding: const EdgeInsets.all(24),
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
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFEF3C7),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.bolt_rounded, color: Color(0xFFD97706), size: 24),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Quick Canned Replies',
                          style: GoogleFonts.outfit(
                            fontSize: 16.5,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF111B21),
                          ),
                        ),
                        Text(
                          'Standardized message scripts • Type / in chat to trigger',
                          style: GoogleFonts.outfit(fontSize: 11.5, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Search & Add Bar
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    alignment: Alignment.centerLeft,
                    child: TextField(
                      onChanged: (val) => setState(() => _searchQuery = val),
                      style: GoogleFonts.outfit(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Search by shortcut (/bank) or keyword...',
                        hintStyle: GoogleFonts.outfit(fontSize: 12.5, color: const Color(0xFF94A3B8)),
                        prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFFD97706)),
                        prefixIconConstraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD97706),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: Text(
                    'New Canned Reply',
                    style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.bold),
                  ),
                  onPressed: _showCreateDialog,
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            const SizedBox(height: 12),

            // List of canned messages
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        _searchQuery.isEmpty ? 'No canned responses yet. Click "+ New Canned Reply" to add one.' : 'No canned replies match "$_searchQuery"',
                        style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF64748B)),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (context, idx) => const Divider(height: 12, color: Color(0xFFF1F5F9)),
                      itemBuilder: (context, idx) {
                        final item = filtered[idx];
                        final shortcut = item['shortcut'] ?? '';
                        final title = item['title'] ?? 'Quick Reply';
                        final message = item['message'] ?? '';
                        final category = item['category'] ?? 'General';
                        final itemId = item['_id']?.toString();
                        final bool isGlobal = item['isGlobal'] == true;
                        final creator = item['createdBy'] is Map ? item['createdBy'] as Map<String, dynamic> : null;
                        final bool isAdminCreator = creator?['role'] == 'admin' || isGlobal;
                        String authorTag = isAdminCreator ? '👑 Team Standard' : '👤 Private Reply';
                        if (AuthService().currentUserRole == UserRole.admin && !isAdminCreator && creator != null) {
                          final aName = '${creator['firstName'] ?? ''} ${creator['lastName'] ?? ''}'.trim();
                          authorTag = '👤 ${aName.isNotEmpty ? aName : (creator['email'] ?? 'Agent')}';
                        }

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB).withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFEF3C7),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: const Color(0xFFFCD34D)),
                                        ),
                                        child: Text(
                                          shortcut,
                                          style: GoogleFonts.outfit(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFFB45309),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        title,
                                        style: GoogleFonts.outfit(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF1E293B),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isAdminCreator ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: isAdminCreator ? const Color(0xFFBFDBFE) : const Color(0xFFE2E8F0)),
                                        ),
                                        child: Text(
                                          authorTag,
                                          style: GoogleFonts.outfit(
                                            fontSize: 10,
                                            color: isAdminCreator ? const Color(0xFF1D4ED8) : const Color(0xFF475569),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: const Color(0xFFCBD5E1)),
                                        ),
                                        child: Text(
                                          category,
                                          style: GoogleFonts.outfit(fontSize: 10.5, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                message,
                                style: GoogleFonts.outfit(
                                  fontSize: 12.5,
                                  color: const Color(0xFF334155),
                                  height: 1.35,
                                ),
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  if (itemId != null)
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                                      tooltip: 'Delete Canned Reply',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () async {
                                        try {
                                          final res = await ApiClient().delete('/canned-responses/$itemId');
                                          if (res.statusCode == 200) {
                                            setState(() {
                                              _localResponses.removeWhere((c) => c['_id'] == itemId);
                                            });
                                            widget.onRefresh?.call();
                                          }
                                        } catch (_) {}
                                      },
                                    ),
                                  const SizedBox(width: 14),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFD97706),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                    ),
                                    icon: const Icon(Icons.bolt_rounded, size: 14),
                                    label: Text('Insert into Chat', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold)),
                                    onPressed: () {
                                      Navigator.pop(context);
                                      widget.onSelectMessage(message);
                                    },
                                  ),
                                ],
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
