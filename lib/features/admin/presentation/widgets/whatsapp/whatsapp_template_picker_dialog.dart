import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kd_pannel/app_theme.dart';
import 'package:kd_pannel/core/auth/auth_service.dart';
import 'package:kd_pannel/core/network/api_client.dart';
import 'package:kd_pannel/core/services/telephony_audio_service.dart';

/// Compact modal dialog for browsing, searching, previewing, and sending Meta-approved WhatsApp templates
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
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'ALL';
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _initSelectedTemplate();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mediaUrlController.dispose();
    for (final ctrl in _variableControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
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
    for (final ctrl in _variableControllers.values) {
      ctrl.dispose();
    }
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
      final ctrl = idx == 1
          ? TextEditingController(text: widget.initialParam ?? widget.customerName)
          : TextEditingController();
      ctrl.addListener(() {
        if (mounted) setState(() {});
      });
      _variableControllers[idx] = ctrl;
    }
  }

  List<dynamic> get _filteredTemplates {
    return widget.approvedTemplates.where((t) {
      final name = (t['name'] ?? t['elementName'] ?? '').toString().toLowerCase();
      final body = (t['body'] ?? t['data']?['body'] ?? '').toString().toLowerCase();
      final cat = (t['category'] ?? '').toString().toUpperCase();
      final lang = (t['language'] ?? t['languageCode'] ?? '').toString().toLowerCase();

      final matchesSearch = _searchQuery.isEmpty ||
          name.contains(_searchQuery) ||
          body.contains(_searchQuery) ||
          lang.contains(_searchQuery) ||
          cat.toLowerCase().contains(_searchQuery);

      final matchesCat = _selectedCategory == 'ALL' || cat == _selectedCategory;
      return matchesSearch && matchesCat;
    }).toList();
  }

  String _getReplacedBody(String rawBody) {
    String res = rawBody;
    for (final entry in _variableControllers.entries) {
      final val = entry.value.text.trim();
      final replacement = val.isNotEmpty ? val : '{{${entry.key}}}';
      res = res.replaceAll('{{${entry.key}}}', replacement);
    }
    return res;
  }

  @override
  Widget build(BuildContext context) {
    final bool hasTemplates = widget.approvedTemplates.isNotEmpty;
    final filtered = _filteredTemplates;

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
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Container(
        width: 820,
        height: 540,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          children: [
            // Compact Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF008069).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.quickreply_rounded,
                        color: Color(0xFF008069),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'WhatsApp Business Templates',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: const Color(0xFF111B21),
                          ),
                        ),
                        Text(
                          'Send official Meta-approved templates to initiate or re-engage leads',
                          style: GoogleFonts.outfit(fontSize: 11.5, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ],
                ),
                Row(
                  children: [
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: const Icon(Icons.tune_rounded, size: 14, color: Color(0xFF008069)),
                      label: Text(
                        'Manage / Sync',
                        style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.bold, color: const Color(0xFF008069)),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        WhatsAppTemplatePickerDialog.showManager(
                          context,
                          approvedTemplates: widget.approvedTemplates,
                          selectedConversationId: widget.conversationId,
                          onRefreshTemplates: widget.onRefreshTemplates,
                        );
                      },
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 19, color: Color(0xFF64748B)),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFE9EDEF)),
            const SizedBox(height: 12),

            // Two-Column Main Content
            Expanded(
              child: !hasTemplates
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.assignment_late_outlined, size: 40, color: Color(0xFF94A3B8)),
                          const SizedBox(height: 8),
                          Text(
                            'No Templates Loaded',
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: const Color(0xFF1E293B)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Sync approved templates from MyOperator in the Manager.',
                            style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF008069),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            icon: const Icon(Icons.sync_rounded, size: 15),
                            label: Text('Sync Templates Now', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold)),
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
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Column: Search Bar & Template Selector List
                        SizedBox(
                          width: 310,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Compact Search Input (Order Screen Style)
                              Container(
                                height: 40,
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppTheme.borderColor),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.02),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.search_rounded,
                                      size: 18,
                                      color: AppTheme.textSecondary,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextField(
                                        controller: _searchController,
                                        style: GoogleFonts.outfit(
                                          fontSize: 13,
                                          color: AppTheme.textPrimary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        decoration: InputDecoration(
                                          hintText: 'Search template name or text...',
                                          hintStyle: GoogleFonts.outfit(
                                            fontSize: 13,
                                            color: AppTheme.textSecondary.withValues(alpha: 0.7),
                                            fontWeight: FontWeight.w500,
                                          ),
                                          border: InputBorder.none,
                                          isDense: true,
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                      ),
                                    ),
                                    if (_searchQuery.isNotEmpty)
                                      InkWell(
                                        onTap: () => _searchController.clear(),
                                        borderRadius: BorderRadius.circular(10),
                                        child: const Padding(
                                          padding: EdgeInsets.all(3.0),
                                          child: Icon(Icons.close_rounded, size: 15, color: AppTheme.textSecondary),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 6),

                              // Category Filter Pills
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    _buildCategoryPill('ALL', 'All (${widget.approvedTemplates.length})'),
                                    const SizedBox(width: 4),
                                    _buildCategoryPill('UTILITY', 'Utility'),
                                    const SizedBox(width: 4),
                                    _buildCategoryPill('MARKETING', 'Marketing'),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 6),

                              // Filtered List of Templates
                              Expanded(
                                child: filtered.isEmpty
                                    ? Center(
                                        child: Text(
                                          'No templates match "$_searchQuery"',
                                          style: GoogleFonts.outfit(fontSize: 11.5, color: const Color(0xFF94A3B8)),
                                        ),
                                      )
                                    : ListView.separated(
                                        itemCount: filtered.length,
                                        separatorBuilder: (_, __) => const SizedBox(height: 5),
                                        itemBuilder: (context, idx) {
                                          final t = filtered[idx];
                                          final name = (t['name'] ?? t['elementName'] ?? '').toString();
                                          final cat = (t['category'] ?? 'UTILITY').toString();
                                          final lang = (t['language'] ?? t['languageCode'] ?? 'en').toString();
                                          final status = (t['status'] ?? 'APPROVED').toString().toUpperCase();
                                          final isSelected = tplName == name;
                                          final isItemApproved = status == 'APPROVED';
                                          final isItemRejected = status.contains('REJECT');

                                          return InkWell(
                                            onTap: () {
                                              setState(() {
                                                _currentTpl = t as Map<String, dynamic>?;
                                                _initVariableControllers(_currentTpl);
                                              });
                                            },
                                            borderRadius: BorderRadius.circular(8),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                              decoration: BoxDecoration(
                                                color: isSelected
                                                    ? const Color(0xFF008069).withValues(alpha: 0.08)
                                                    : const Color(0xFFF8FAFC),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: isSelected
                                                      ? const Color(0xFF008069)
                                                      : const Color(0xFFE2E8F0),
                                                  width: isSelected ? 1.4 : 1.0,
                                                ),
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    isItemApproved
                                                        ? Icons.check_circle_rounded
                                                        : (isItemRejected ? Icons.cancel_rounded : Icons.hourglass_top_rounded),
                                                    size: 14,
                                                    color: isItemApproved
                                                        ? const Color(0xFF16A34A)
                                                        : (isItemRejected ? const Color(0xFFDC2626) : const Color(0xFFD97706)),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          name,
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                          style: GoogleFonts.outfit(
                                                            fontSize: 12,
                                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                                            color: isSelected ? const Color(0xFF008069) : const Color(0xFF1E293B),
                                                          ),
                                                        ),
                                                        const SizedBox(height: 2),
                                                        Row(
                                                          children: [
                                                            Container(
                                                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                              decoration: BoxDecoration(
                                                                color: const Color(0xFFE2E8F0),
                                                                borderRadius: BorderRadius.circular(3),
                                                              ),
                                                              child: Text(
                                                                '$cat • $lang',
                                                                style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  if (isSelected)
                                                    const Icon(Icons.arrow_forward_ios_rounded, size: 11, color: Color(0xFF008069)),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 12),
                        const VerticalDivider(width: 1, color: Color(0xFFE9EDEF)),
                        const SizedBox(width: 12),

                        // Right Column: Preview, Dynamic Variable Inputs, and Send Action
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Selected Template Badge Header
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        tplName.isNotEmpty ? tplName : 'Select a Template',
                                        style: GoogleFonts.outfit(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF0F172A),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isApproved
                                            ? const Color(0xFFE8F5E9)
                                            : (isRejected ? const Color(0xFFFFEBEE) : const Color(0xFFFFF8E1)),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        isApproved ? '🟢 Meta Approved' : (isRejected ? '❌ Meta Rejected' : '⏳ In Review'),
                                        style: GoogleFonts.outfit(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: isApproved
                                              ? const Color(0xFF2E7D32)
                                              : (isRejected ? const Color(0xFFC62828) : const Color(0xFFF57F17)),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),

                                // Live Simulated WhatsApp Chat Bubble
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE7FCE8),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFFA7F3D0)),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.03),
                                        blurRadius: 3,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.visibility_rounded, size: 12, color: Color(0xFF047857)),
                                          const SizedBox(width: 4),
                                          Text(
                                            'WhatsApp Live Preview',
                                            style: GoogleFonts.outfit(fontSize: 10.5, fontWeight: FontWeight.bold, color: const Color(0xFF047857)),
                                          ),
                                        ],
                                      ),
                                      if (tplHeader.isNotEmpty) ...[
                                        const SizedBox(height: 5),
                                        Text(tplHeader, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF111B21))),
                                      ],
                                      const SizedBox(height: 4),
                                      Text(
                                        tplBody.isNotEmpty ? _getReplacedBody(tplBody) : '(Empty Template Content)',
                                        style: GoogleFonts.outfit(
                                          fontSize: 11.5,
                                          color: const Color(0xFF1E293B),
                                          height: 1.35,
                                        ),
                                      ),
                                      if (tplFooter.isNotEmpty) ...[
                                        const SizedBox(height: 5),
                                        Text(tplFooter, style: GoogleFonts.outfit(fontSize: 9.5, color: const Color(0xFF64748B), fontStyle: FontStyle.italic)),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // Variable Inputs (Compact Form)
                                if (_variableControllers.isNotEmpty) ...[
                                  Text(
                                    'Template Variables:',
                                    style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.bold, color: const Color(0xFF334155)),
                                  ),
                                  const SizedBox(height: 6),
                                  ..._variableControllers.entries.map((entry) {
                                    final varIdx = entry.key;
                                    final ctrl = entry.value;
                                    final isLeadName = varIdx == 1;
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 6.0),
                                      child: TextField(
                                        controller: ctrl,
                                        style: GoogleFonts.outfit(fontSize: 12),
                                        decoration: InputDecoration(
                                          labelText: '{{$varIdx}} ${isLeadName ? "(Recipient Name)" : ""}',
                                          labelStyle: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF008069)),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFF008069), width: 1.4)),
                                          isDense: true,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        ),
                                      ),
                                    );
                                  }),
                                ],

                                // Media Header URL (if required by template)
                                if (headerType == 'IMAGE' || headerType == 'DOCUMENT') ...[
                                  const SizedBox(height: 4),
                                  TextField(
                                    controller: _mediaUrlController,
                                    style: GoogleFonts.outfit(fontSize: 12),
                                    decoration: InputDecoration(
                                      labelText: 'Header Media URL ($headerType)',
                                      hintText: 'https://storage.googleapis.com/...',
                                      labelStyle: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF64748B)),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    ),
                                  ),
                                ],

                                if (!isApproved) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isRejected ? const Color(0xFFFEF2F2) : const Color(0xFFFFFBEB),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: isRejected ? const Color(0xFFFECACA) : const Color(0xFFFDE68A)),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          isRejected ? Icons.error_outline_rounded : Icons.hourglass_empty_rounded,
                                          size: 15,
                                          color: isRejected ? const Color(0xFFDC2626) : const Color(0xFFD97706),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            isRejected
                                                ? 'Template was rejected by Meta policy.'
                                                : 'Template is in review.',
                                            style: GoogleFonts.outfit(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                              color: isRejected ? const Color(0xFF991B1B) : const Color(0xFF92400E),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFE9EDEF)),
            const SizedBox(height: 10),

            // Bottom Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                  onPressed: _isSending ? null : () => Navigator.pop(context),
                  child: Text('Cancel', style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B), fontWeight: FontWeight.w600)),
                ),
                if (hasTemplates) ...[
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isApproved ? const Color(0xFF008069) : const Color(0xFF94A3B8),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    icon: _isSending
                        ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Icon(isApproved ? Icons.send_rounded : Icons.lock_outline_rounded, size: 13),
                    label: Text(
                      _isSending
                          ? 'Sending...'
                          : (isApproved
                              ? 'Send Template'
                              : (isRejected ? 'Template Rejected' : 'Awaiting Meta Approval')),
                      style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold),
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

  Widget _buildCategoryPill(String catKey, String label) {
    final bool isSelected = _selectedCategory == catKey;
    return InkWell(
      onTap: () => setState(() => _selectedCategory = catKey),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF008069) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF64748B),
          ),
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
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _localTemplates = List<dynamic>.from(widget.approvedTemplates);
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<dynamic> get _filteredList {
    if (_searchQuery.isEmpty) return _localTemplates;
    return _localTemplates.where((t) {
      final name = (t['name'] ?? t['elementName'] ?? '').toString().toLowerCase();
      final body = (t['body'] ?? t['data']?['body'] ?? '').toString().toLowerCase();
      final cat = (t['category'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery) || body.contains(_searchQuery) || cat.contains(_searchQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final bool isAdmin = AuthService().currentUserRole == UserRole.admin;
    final list = _filteredList;

    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Container(
        width: 780,
        height: 620,
        padding: const EdgeInsets.all(20),
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
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: const Color(0xFF008069).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.assignment_outlined, color: Color(0xFF008069), size: 20),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'WhatsApp Business Templates Manager',
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF111B21),
                          ),
                        ),
                        Text(
                          'Synced Meta approved templates from MyOperator',
                          style: GoogleFonts.outfit(fontSize: 11.5, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 19, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Search Bar and Sync Button (Order Screen Style)
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.borderColor),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.search_rounded,
                          size: 20,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Search templates by name, body, or category...',
                              hintStyle: GoogleFonts.outfit(
                                fontSize: 14,
                                color: AppTheme.textSecondary.withValues(alpha: 0.7),
                                fontWeight: FontWeight.w500,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                        if (_searchQuery.isNotEmpty)
                          InkWell(
                            onTap: () => _searchController.clear(),
                            borderRadius: BorderRadius.circular(12),
                            child: const Padding(
                              padding: EdgeInsets.all(4.0),
                              child: Icon(Icons.close_rounded, size: 16, color: AppTheme.textSecondary),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF008069),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: _isSyncing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.sync_rounded, size: 18),
                  label: Text(
                    _isSyncing ? 'Syncing...' : 'Sync MyOperator',
                    style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold),
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
                                final resList = List<dynamic>.from(body['data']);
                                setState(() {
                                  _localTemplates = resList.where((t) {
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
            const SizedBox(height: 10),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            const SizedBox(height: 10),

            // Template List
            Expanded(
              child: _isSyncing
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF008069)))
                  : list.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.description_outlined, size: 36, color: Color(0xFF94A3B8)),
                              const SizedBox(height: 8),
                              Text(
                                _searchQuery.isNotEmpty ? 'No templates match "$_searchQuery"' : 'No templates loaded.',
                                style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: list.length,
                          separatorBuilder: (context, idx) => const SizedBox(height: 8),
                          itemBuilder: (context, idx) {
                            final t = list[idx];
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
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(8),
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
                                          spacing: 6,
                                          runSpacing: 3,
                                          children: [
                                            Text(
                                              title.isNotEmpty ? title : name,
                                              style: GoogleFonts.outfit(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: const Color(0xFF0F172A),
                                              ),
                                            ),
                                            if (title.isNotEmpty)
                                              Text(
                                                '($name)',
                                                style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF64748B)),
                                              ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFE2E8F0),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                '$category • $language',
                                                style: GoogleFonts.outfit(fontSize: 9.5, fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: statusColor.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          statusText,
                                          style: GoogleFonts.outfit(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: statusColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    body,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.outfit(
                                      fontSize: 11.5,
                                      color: const Color(0xFF334155),
                                      height: 1.35,
                                    ),
                                  ),
                                  if (footer.isNotEmpty) ...[
                                    const SizedBox(height: 3),
                                    Text(
                                      'Footer: $footer',
                                      style: GoogleFonts.outfit(fontSize: 10, color: const Color(0xFF94A3B8), fontStyle: FontStyle.italic),
                                    ),
                                  ],
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      if (isAdmin && templateId != null)
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.redAccent),
                                          tooltip: 'Delete Template',
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onPressed: () async {
                                            final bool? confirm = await showDialog<bool>(
                                              context: context,
                                              builder: (confirmCtx) => AlertDialog(
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                title: Text('Delete WhatsApp Template?', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14)),
                                                content: Text(
                                                  'Delete "$name" from your database?',
                                                  style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF475569)),
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () => Navigator.pop(confirmCtx, false),
                                                    child: Text('Cancel', style: GoogleFonts.outfit(color: const Color(0xFF64748B), fontSize: 12)),
                                                  ),
                                                  ElevatedButton(
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: const Color(0xFFDC2626),
                                                      foregroundColor: Colors.white,
                                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                                    ),
                                                    onPressed: () => Navigator.pop(confirmCtx, true),
                                                    child: Text('Delete', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12)),
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
                                        const SizedBox(width: 8),
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF008069),
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                          ),
                                          icon: const Icon(Icons.send_rounded, size: 11),
                                          label: Text('Send', style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.bold)),
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
