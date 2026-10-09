import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kd_pannel/core/auth/auth_service.dart';
import 'package:kd_pannel/core/network/api_client.dart';
import 'package:kd_pannel/core/services/telephony_audio_service.dart';

/// Modal dialog for browsing, managing, and sending Meta-approved WhatsApp templates
class WhatsAppTemplatePickerDialog extends StatefulWidget {
  final String conversationId;
  final String customerName;
  final List<dynamic> approvedTemplates;
  final String? initialTemplateName;
  final String? initialParam;
  final VoidCallback? onTemplateSent;
  final VoidCallback? onRefreshTemplates;

  const WhatsAppTemplatePickerDialog({
    super.key,
    required this.conversationId,
    required this.customerName,
    required this.approvedTemplates,
    this.initialTemplateName,
    this.initialParam,
    this.onTemplateSent,
    this.onRefreshTemplates,
  });

  static void show(
    BuildContext context, {
    required String conversationId,
    required String customerName,
    required List<dynamic> approvedTemplates,
    String? initialTemplateName,
    String? initialParam,
    VoidCallback? onTemplateSent,
    VoidCallback? onRefreshTemplates,
  }) {
    showDialog(
      context: context,
      builder: (context) => WhatsAppTemplatePickerDialog(
        conversationId: conversationId,
        customerName: customerName,
        approvedTemplates: approvedTemplates,
        initialTemplateName: initialTemplateName,
        initialParam: initialParam,
        onTemplateSent: onTemplateSent,
        onRefreshTemplates: onRefreshTemplates,
      ),
    );
  }

  static void showManager(
    BuildContext context, {
    required List<dynamic> approvedTemplates,
    String? selectedConversationId,
    VoidCallback? onRefreshTemplates,
  }) {
    showDialog(
      context: context,
      builder: (context) => WhatsAppTemplateManagerDialog(
        approvedTemplates: approvedTemplates,
        selectedConversationId: selectedConversationId,
        onRefreshTemplates: onRefreshTemplates,
      ),
    );
  }

  @override
  State<WhatsAppTemplatePickerDialog> createState() => _WhatsAppTemplatePickerDialogState();
}

class _WhatsAppTemplatePickerDialogState extends State<WhatsAppTemplatePickerDialog> {
  Map<String, dynamic>? _currentTpl;
  final Map<int, TextEditingController> _variableControllers = {};
  final TextEditingController _mediaUrlController = TextEditingController();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _initSelectedTemplate();
  }

  void _initSelectedTemplate() {
    if (widget.approvedTemplates.isNotEmpty) {
      if (widget.initialTemplateName != null && widget.initialTemplateName!.isNotEmpty) {
        _currentTpl = widget.approvedTemplates.firstWhere(
          (t) => (t['name'] ?? t['elementName'] ?? '').toString() == widget.initialTemplateName,
          orElse: () => widget.approvedTemplates.first as Map<String, dynamic>,
        ) as Map<String, dynamic>?;
      } else {
        _currentTpl = widget.approvedTemplates.firstWhere(
          (t) => (t['status'] ?? 'APPROVED').toString().toUpperCase() == 'APPROVED',
          orElse: () => widget.approvedTemplates.first as Map<String, dynamic>,
        ) as Map<String, dynamic>?;
      }
    }
    _initVariableControllers(_currentTpl);
  }

  void _initVariableControllers(Map<String, dynamic>? tpl) {
    _variableControllers.clear();
    if (tpl == null) return;
    final bodyText = (tpl['body'] ?? tpl['data']?['body'] ?? '').toString();
    final matches = RegExp(r'\{\{(\d+)\}\}').allMatches(bodyText);
    final Set<int> varIndices = {};
    for (final m in matches) {
      final idx = int.tryParse(m.group(1) ?? '1') ?? 1;
      varIndices.add(idx);
    }
    final sorted = varIndices.toList()..sort();
    for (final idx in sorted) {
      if (idx == 1) {
        _variableControllers[idx] = TextEditingController(text: widget.initialParam ?? widget.customerName);
      } else {
        _variableControllers[idx] = TextEditingController();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasTemplates = widget.approvedTemplates.isNotEmpty;
    final tplName = (_currentTpl?['name'] ?? _currentTpl?['elementName'] ?? '').toString();
    final tplBody = (_currentTpl?['body'] ?? _currentTpl?['data']?['body'] ?? '').toString();
    final tplCategory = (_currentTpl?['category'] ?? 'UTILITY').toString();
    final tplLanguage = (_currentTpl?['language'] ?? _currentTpl?['languageCode'] ?? 'en').toString();
    final tplFooter = (_currentTpl?['footer'] ?? '').toString();
    final tplHeader = (_currentTpl?['headerText'] ?? '').toString();
    final headerType = (_currentTpl?['headerType'] ?? 'NONE').toString().toUpperCase();
    final tplStatus = (_currentTpl?['status'] ?? 'APPROVED').toString().toUpperCase();
    final bool isApproved = tplStatus == 'APPROVED';
    final bool isRejected = tplStatus.contains('REJECT') || tplStatus.contains('FAIL');
    final bool isPending = !isApproved && !isRejected;

    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 540,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF008069).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.quickreply_rounded,
                        color: Color(0xFF008069),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Send WhatsApp Template',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: const Color(0xFF111B21),
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Choose an official Meta-approved template to message outside the 24-hour window.',
              style: GoogleFonts.outfit(fontSize: 12.5, color: const Color(0xFF64748B)),
            ),
            const SizedBox(height: 18),

            if (!hasTemplates) ...[
              Container(
                padding: const EdgeInsets.all(24),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.assignment_late_outlined, size: 44, color: Color(0xFF94A3B8)),
                    const SizedBox(height: 10),
                    Text(
                      'No Templates in Workspace',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14.5, color: const Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Sync approved templates from your MyOperator dashboard in Templates Manager.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF008069),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: Text('Open Templates Manager', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: () {
                        Navigator.pop(context);
                        WhatsAppTemplatePickerDialog.showManager(
                          context,
                          approvedTemplates: widget.approvedTemplates,
                          onRefreshTemplates: widget.onRefreshTemplates,
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ] else ...[
              // Template Picker Dropdown Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Select WhatsApp Template:', style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFF334155))),
                  InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () {
                      Navigator.pop(context);
                      WhatsAppTemplatePickerDialog.showManager(
                        context,
                        approvedTemplates: widget.approvedTemplates,
                        selectedConversationId: widget.conversationId,
                        onRefreshTemplates: widget.onRefreshTemplates,
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.settings_outlined, size: 13, color: Color(0xFF64748B)),
                          const SizedBox(width: 3),
                          Text(
                            'Manage',
                            style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: tplName.isNotEmpty ? tplName : null,
                isExpanded: true,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF008069), width: 1.6)),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                items: widget.approvedTemplates.map<DropdownMenuItem<String>>((t) {
                  final name = (t['name'] ?? t['elementName'] ?? '').toString();
                  final cat = (t['category'] ?? 'UTILITY').toString();
                  final l = (t['language'] ?? t['languageCode'] ?? 'en').toString();
                  final st = (t['status'] ?? 'APPROVED').toString().toUpperCase();
                  final bool itemAppr = st == 'APPROVED';
                  final bool itemRej = st.contains('REJECT') || st.contains('FAIL');

                  Color badgeBg = const Color(0xFFE8F5E9);
                  Color badgeText = const Color(0xFF2E7D32);
                  String badgeLabel = '🟢 Approved';

                  if (itemRej) {
                    badgeBg = const Color(0xFFFFEBEE);
                    badgeText = const Color(0xFFC62828);
                    badgeLabel = '❌ Rejected';
                  } else if (!itemAppr) {
                    badgeBg = const Color(0xFFFFF8E1);
                    badgeText = const Color(0xFFF57F17);
                    badgeLabel = '⏳ In Review';
                  }

                  return DropdownMenuItem<String>(
                    value: name,
                    child: Row(
                      children: [
                        Icon(
                          itemAppr ? Icons.check_circle_outline_rounded : (itemRej ? Icons.cancel_outlined : Icons.hourglass_top_rounded),
                          size: 15,
                          color: badgeText,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            name,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(4)),
                          child: Text(badgeLabel, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: badgeText)),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(4)),
                          child: Text('$cat • $l', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF475569))),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    final matched = widget.approvedTemplates.firstWhere(
                      (t) => (t['name'] ?? t['elementName'] ?? '').toString() == val,
                      orElse: () => widget.approvedTemplates.first,
                    );
                    setState(() {
                      _currentTpl = matched as Map<String, dynamic>?;
                      _initVariableControllers(_currentTpl);
                    });
                  }
                },
              ),

              if (!isApproved) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isRejected ? const Color(0xFFFEF2F2) : const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isRejected ? const Color(0xFFFECACA) : const Color(0xFFFDE68A),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isRejected ? Icons.error_outline_rounded : Icons.hourglass_empty_rounded,
                        size: 18,
                        color: isRejected ? const Color(0xFFDC2626) : const Color(0xFFD97706),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          isRejected
                              ? 'This template was rejected by Meta policy and cannot be sent.'
                              : 'Template is marked In Review. If it is already created in MyOperator, click "Activate" to unlock.',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isRejected ? const Color(0xFF991B1B) : const Color(0xFF92400E),
                          ),
                        ),
                      ),
                      if (isPending && _currentTpl?['_id'] != null) ...[
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF008069),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          onPressed: () async {
                            final tplId = _currentTpl?['_id']?.toString();
                            if (tplId != null) {
                              final res = await ApiClient().patch('/whatsapp/templates/$tplId', {'status': 'APPROVED'});
                              if (res.statusCode == 200) {
                                setState(() {
                                  _currentTpl?['status'] = 'APPROVED';
                                });
                              }
                            }
                          },
                          child: Text('Activate & Send', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),

              // Live Message Preview Box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE7FCE8),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.visibility_rounded, size: 13, color: Color(0xFF047857)),
                        const SizedBox(width: 4),
                        Text('Live Template Preview', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF047857))),
                      ],
                    ),
                    if (tplHeader.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(tplHeader, style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFF111B21))),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      tplBody.isNotEmpty ? tplBody : '(Empty Body)',
                      style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF1E293B), height: 1.35),
                    ),
                    if (tplFooter.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(tplFooter, style: GoogleFonts.outfit(fontSize: 10.5, color: const Color(0xFF64748B), fontStyle: FontStyle.italic)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Dynamic Variable Input Fields
              if (_variableControllers.isNotEmpty) ...[
                Text('Fill Template Variables:', style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFF334155))),
                const SizedBox(height: 8),
                ..._variableControllers.entries.map((entry) {
                  final varIdx = entry.key;
                  final ctrl = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: TextField(
                      controller: ctrl,
                      decoration: InputDecoration(
                        labelText: 'Variable {{$varIdx}} ${varIdx == 1 ? "(Customer Name)" : ""}',
                        labelStyle: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF008069)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF008069), width: 1.5)),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      ),
                      style: GoogleFonts.outfit(fontSize: 13),
                    ),
                  );
                }),
              ],

              if (headerType == 'IMAGE' || headerType == 'DOCUMENT') ...[
                TextField(
                  controller: _mediaUrlController,
                  decoration: InputDecoration(
                    labelText: 'Header Media URL ($headerType)',
                    hintText: 'https://example.com/catalog.pdf',
                    labelStyle: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  ),
                  style: GoogleFonts.outfit(fontSize: 13),
                ),
                const SizedBox(height: 10),
              ],
            ],

            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  onPressed: _isSending ? null : () => Navigator.pop(context),
                  child: Text('Cancel', style: GoogleFonts.outfit(color: const Color(0xFF64748B), fontWeight: FontWeight.w600)),
                ),
                if (hasTemplates) ...[
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isApproved ? const Color(0xFF008069) : const Color(0xFF94A3B8),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    ),
                    icon: Icon(isApproved ? Icons.send_rounded : Icons.lock_outline_rounded, size: 14),
                    label: Text(
                      isApproved
                          ? 'Send Template'
                          : (isRejected ? 'Template Rejected' : 'Awaiting Meta Approval'),
                      style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    onPressed: isApproved && !_isSending
                        ? () async {
                            final rawTemplateName = tplName;
                            final mediaUrl = _mediaUrlController.text.trim();

                            final List<String> paramsList = [];
                            final sortedKeys = _variableControllers.keys.toList()..sort();
                            for (final k in sortedKeys) {
                              paramsList.add(_variableControllers[k]!.text.trim());
                            }

                            setState(() => _isSending = true);

                            try {
                              final payload = {
                                'conversationId': widget.conversationId,
                                'templateName': rawTemplateName,
                                'language': tplLanguage.isNotEmpty ? tplLanguage : 'en',
                                if (paramsList.isNotEmpty) 'templateParams': paramsList,
                                if (mediaUrl.isNotEmpty) 'mediaUrl': mediaUrl,
                              };

                              final res = await ApiClient().post('/messages/send-template', payload);
                              if (res.statusCode == 200 || res.statusCode == 201) {
                                TelephonyAudioService().playOutgoingMessageSentTone();
                                if (context.mounted) {
                                  Navigator.pop(context);
                                  widget.onTemplateSent?.call();
                                }
                              } else {
                                final body = jsonDecode(res.body);
                                throw Exception(body['message'] ?? 'Failed to send template');
                              }
                            } catch (e) {
                              debugPrint('[WhatsApp CRM] Error sending template: $e');
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error: ${e.toString().replaceAll("Exception: ", "")}'),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                              }
                            } finally {
                              if (mounted) setState(() => _isSending = false);
                            }
                          }
                        : null,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Standalone dialog for managing and syncing WABA templates from MyOperator
class WhatsAppTemplateManagerDialog extends StatefulWidget {
  final List<dynamic> approvedTemplates;
  final String? selectedConversationId;
  final VoidCallback? onRefreshTemplates;

  const WhatsAppTemplateManagerDialog({
    super.key,
    required this.approvedTemplates,
    this.selectedConversationId,
    this.onRefreshTemplates,
  });

  @override
  State<WhatsAppTemplateManagerDialog> createState() => _WhatsAppTemplateManagerDialogState();
}

class _WhatsAppTemplateManagerDialogState extends State<WhatsAppTemplateManagerDialog> {
  late List<dynamic> _localTemplates;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _localTemplates = List<dynamic>.from(widget.approvedTemplates);
  }

  @override
  Widget build(BuildContext context) {
    final bool isAdmin = AuthService().currentUserRole == UserRole.admin;

    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 780,
        height: 680,
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
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF008069).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.assignment_outlined, color: Color(0xFF008069), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'WhatsApp Business Templates',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF111B21),
                          ),
                        ),
                        Text(
                          'Meta approved WhatsApp templates synced from MyOperator',
                          style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B)),
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

            // Filter & Action Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Approved Templates (${_localTemplates.length})',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF475569),
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF008069),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: _isSyncing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.sync_rounded, size: 16),
                  label: Text(
                    _isSyncing ? 'Syncing...' : 'Sync MyOperator',
                    style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.bold),
                  ),
                  onPressed: _isSyncing
                      ? null
                      : () async {
                          setState(() => _isSyncing = true);
                          try {
                            final res = await ApiClient().get('/whatsapp/templates?sync=true&status=APPROVED');
                            if (res.statusCode == 200) {
                              final body = jsonDecode(res.body);
                              if (body['success'] == true && body['data'] != null) {
                                final list = List<dynamic>.from(body['data']);
                                setState(() {
                                  _localTemplates = list.where((t) {
                                    final s = (t['status'] ?? t['waba_template_status'] ?? '').toString().toUpperCase();
                                    return s == 'APPROVED' || s == 'ACTIVE';
                                  }).toList();
                                });
                                widget.onRefreshTemplates?.call();
                              }
                            }
                          } catch (e) {
                            debugPrint('[Templates Manager] Error syncing templates: $e');
                          } finally {
                            if (mounted) setState(() => _isSyncing = false);
                          }
                        },
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            const SizedBox(height: 12),

            // Template List
            Expanded(
              child: _isSyncing
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF008069)))
                  : _localTemplates.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.description_outlined, size: 44, color: Color(0xFF94A3B8)),
                                const SizedBox(height: 10),
                                Text(
                                  'No approved templates found.',
                                  style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Create approved templates in your MyOperator Dashboard,\nthen click "Sync MyOperator" above to load them here.',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.outfit(fontSize: 12.5, color: const Color(0xFF64748B), height: 1.4),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          itemCount: _localTemplates.length,
                          separatorBuilder: (context, idx) => const SizedBox(height: 12),
                          itemBuilder: (context, idx) {
                            final t = _localTemplates[idx];
                            final name = (t['name'] ?? t['elementName'] ?? 'template').toString();
                            final title = (t['title'] ?? '').toString();
                            final category = (t['category'] ?? 'UTILITY').toString();
                            final language = (t['language'] ?? 'en').toString();
                            final body = (t['body'] ?? t['data']?['body'] ?? (t['components'] is List ? (t['components'] as List).firstWhere((c) => c['type'] == 'BODY', orElse: () => {})['text'] : null) ?? name).toString();
                            final status = (t['status'] ?? 'APPROVED').toString().toUpperCase();
                            final footer = (t['footer'] ?? '').toString();
                            final templateId = t['_id']?.toString();

                            Color statusColor = const Color(0xFF008069);
                            String statusText = '🟢 Approved';
                            if (status.contains('PENDING')) {
                              statusColor = Colors.orange[800]!;
                              statusText = '⏳ In Review (Meta)';
                            } else if (status.contains('REJECT')) {
                              statusColor = Colors.red[700]!;
                              statusText = '❌ Rejected';
                            }

                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Wrap(
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          spacing: 8,
                                          runSpacing: 4,
                                          children: [
                                            Text(
                                              title.isNotEmpty ? title : name,
                                              style: GoogleFonts.outfit(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: const Color(0xFF0F172A),
                                              ),
                                            ),
                                            if (title.isNotEmpty)
                                              Text(
                                                '($name)',
                                                style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B)),
                                              ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFE2E8F0),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                '$category • $language',
                                                style: GoogleFonts.outfit(fontSize: 10.5, fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: statusColor.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          statusText,
                                          style: GoogleFonts.outfit(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: statusColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    body,
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      color: const Color(0xFF334155),
                                      height: 1.4,
                                    ),
                                  ),
                                  if (footer.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      'Footer: $footer',
                                      style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF94A3B8), fontStyle: FontStyle.italic),
                                    ),
                                  ],
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      if (isAdmin && templateId != null)
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                                          tooltip: 'Delete Template',
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onPressed: () async {
                                            final bool? confirm = await showDialog<bool>(
                                              context: context,
                                              builder: (confirmCtx) => AlertDialog(
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                title: Text('Delete WhatsApp Template?', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
                                                content: Text(
                                                  'Are you sure you want to delete "$name"? This will remove it from Meta & MyOperator WABA registry.',
                                                  style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF475569)),
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () => Navigator.pop(confirmCtx, false),
                                                    child: Text('Cancel', style: GoogleFonts.outfit(color: const Color(0xFF64748B))),
                                                  ),
                                                  ElevatedButton(
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: const Color(0xFFDC2626),
                                                      foregroundColor: Colors.white,
                                                      elevation: 0,
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                    ),
                                                    onPressed: () => Navigator.pop(confirmCtx, true),
                                                    child: Text('Delete', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                                                  ),
                                                ],
                                              ),
                                            );

                                            if (confirm == true) {
                                              try {
                                                setState(() {
                                                  _localTemplates.removeWhere((tpl) => tpl['_id'] == templateId);
                                                });
                                                final res = await ApiClient().delete('/whatsapp/templates/$templateId');
                                                if (res.statusCode == 200) {
                                                  widget.onRefreshTemplates?.call();
                                                }
                                              } catch (e) {
                                                debugPrint('[Delete Template] Error: $e');
                                              }
                                            }
                                          },
                                        ),
                                      if (status.contains('APPROV') && widget.selectedConversationId != null) ...[
                                        const SizedBox(width: 12),
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF008069),
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                          ),
                                          icon: const Icon(Icons.send_rounded, size: 13),
                                          label: Text('Send to Contact', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold)),
                                          onPressed: () {
                                            Navigator.pop(context);
                                            WhatsAppTemplatePickerDialog.show(
                                              context,
                                              conversationId: widget.selectedConversationId!,
                                              customerName: 'Customer',
                                              approvedTemplates: _localTemplates,
                                              initialTemplateName: name,
                                              onRefreshTemplates: widget.onRefreshTemplates,
                                            );
                                          },
                                        ),
                                      ],
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
