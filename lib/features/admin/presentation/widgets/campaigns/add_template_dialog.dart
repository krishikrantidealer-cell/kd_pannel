import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/push_campaigns_bloc.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/push_campaigns_event.dart';
import 'package:kd_pannel/features/admin/presentation/widgets/campaigns/campaign_constants.dart';

class AddTemplateDialog extends StatefulWidget {
  final String segmentKey;

  const AddTemplateDialog({
    super.key,
    required this.segmentKey,
  });

  static Future<void> show(BuildContext context, String segmentKey) {
    return showDialog(
      context: context,
      builder: (_) => AddTemplateDialog(segmentKey: segmentKey),
    );
  }

  @override
  State<AddTemplateDialog> createState() => _AddTemplateDialogState();
}

class _AddTemplateDialogState extends State<AddTemplateDialog> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _imgCtrl = TextEditingController();
  final _btn1Ctrl = TextEditingController(text: '⚡ Open Offer');
  final _btn2Ctrl = TextEditingController(text: '📞 Call Support');
  String _actionRoute = '/dashboard';

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _imgCtrl.dispose();
    _btn1Ctrl.dispose();
    _btn2Ctrl.dispose();
    super.dispose();
  }

  Widget _buildVariableChip(String tag, TextEditingController controller) {
    return ActionChip(
      avatar: const Icon(Icons.code_rounded, size: 14),
      label: Text(tag),
      labelStyle: GoogleFonts.outfit(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: const Color(0xFF16A34A),
      ),
      backgroundColor: const Color(0xFFF0FDF4),
      side: const BorderSide(color: Color(0xFFBBF7D0)),
      onPressed: () {
        setState(() {
          controller.text += ' $tag';
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final previewTitle = CampaignConstants.replaceVariables(
      _titleCtrl.text.trim().isEmpty
          ? '🌾 {{name}} जी, आज का स्पेशल ऑफर!'
          : _titleCtrl.text.trim(),
    );
    final previewBody = CampaignConstants.replaceVariables(
      _bodyCtrl.text.trim().isEmpty
          ? '{{shopName}} के लिए चुनिंदा एग्रोकेमिकल्स पर स्पेशल डीलर मार्जिन उपलब्ध है।'
          : _bodyCtrl.text.trim(),
    );

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      contentPadding: EdgeInsets.zero,
      content: Container(
        width: 620,
        constraints: const BoxConstraints(maxHeight: 740),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Gradient Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF16A34A).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF16A34A).withValues(alpha: 0.4),
                      ),
                    ),
                    child: const Icon(
                      Icons.add_comment_rounded,
                      color: Color(0xFF4ADE80),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Add Notification Copy',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w800,
                                fontSize: 17,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF16A34A),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'SEGMENT ${widget.segmentKey}',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Design copy, personalization tags & click destination screen',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white70,
                      size: 20,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Modal Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Quick Presets Bar
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.bolt_rounded,
                                color: Color(0xFFD97706),
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '1-Click Copywriting Presets (Auto-fill):',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF334155),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: CampaignConstants.quickCopyPresets.map((p) {
                              return ActionChip(
                                avatar: const Icon(
                                  Icons.auto_awesome_rounded,
                                  size: 13,
                                  color: Color(0xFF2563EB),
                                ),
                                label: Text(p['category']!),
                                labelStyle: GoogleFonts.outfit(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF1E293B),
                                ),
                                backgroundColor: Colors.white,
                                side: const BorderSide(
                                  color: Color(0xFFCBD5E1),
                                ),
                                onPressed: () {
                                  setState(() {
                                    _titleCtrl.text = p['title']!;
                                    _bodyCtrl.text = p['body']!;
                                    _actionRoute = p['route']!;
                                    _btn1Ctrl.text = p['btn1']!;
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 2. Personalization Variable Chips
                    Row(
                      children: [
                        Text(
                          'Personalization Tags:',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF475569),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              _buildVariableChip('{{name}}', _titleCtrl),
                              _buildVariableChip('{{shopName}}', _bodyCtrl),
                              _buildVariableChip('{{city}}', _bodyCtrl),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // 3. Notification Title / Headline
                    Text(
                      'Headline / Title *',
                      style: GoogleFonts.outfit(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _titleCtrl,
                      onChanged: (_) => setState(() {}),
                      style: GoogleFonts.outfit(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0F172A),
                      ),
                      decoration: InputDecoration(
                        hintText: 'e.g. 🌧️ {{name}} जी, आज का स्पेशल ऑफर!',
                        hintStyle: GoogleFonts.outfit(
                          fontSize: 13,
                          color: const Color(0xFF94A3B8),
                        ),
                        prefixIcon: const Icon(
                          Icons.title_rounded,
                          size: 18,
                          color: Color(0xFF64748B),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0xFFCBD5E1),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0xFFCBD5E1),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0xFF16A34A),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 4. Notification Body
                    Text(
                      'Message Body *',
                      style: GoogleFonts.outfit(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _bodyCtrl,
                      maxLines: 3,
                      onChanged: (_) => setState(() {}),
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: const Color(0xFF0F172A),
                      ),
                      decoration: InputDecoration(
                        hintText:
                            'e.g. {{shopName}} के लिए चुनिंदा एग्रोकेमिकल्स पर भारी छूट और एक्स्ट्रा मार्जिन...',
                        hintStyle: GoogleFonts.outfit(
                          fontSize: 13,
                          color: const Color(0xFF94A3B8),
                        ),
                        prefixIcon: const Padding(
                          padding: EdgeInsets.only(bottom: 36),
                          child: Icon(
                            Icons.notes_rounded,
                            size: 18,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0xFFCBD5E1),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0xFFCBD5E1),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0xFF16A34A),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 5. Target Landing Screen / Action Deep Link
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFBBF7D0),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.ads_click_rounded,
                                color: Color(0xFF16A34A),
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Target Landing Screen (When user clicks notification):',
                                style: GoogleFonts.outfit(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF14532D),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Dealer will land directly on this in-app page when tapping the notification banner or CTA button.',
                            style: GoogleFonts.outfit(
                              fontSize: 11.5,
                              color: const Color(0xFF15803D),
                            ),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue: _actionRoute,
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF0F172A),
                            ),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                  color: Color(0xFF86EFAC),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                  color: Color(0xFF86EFAC),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                  color: Color(0xFF16A34A),
                                  width: 1.5,
                                ),
                              ),
                            ),
                            items: CampaignConstants.defaultDeepLinkRoutes.map((r) {
                              return DropdownMenuItem(
                                value: r['route'],
                                child: Text(
                                  r['label']!,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (v) {
                              if (v != null) {
                                setState(() {
                                  _actionRoute = v;
                                  final matched = CampaignConstants.defaultDeepLinkRoutes.firstWhere(
                                    (r) => r['route'] == v,
                                    orElse: () => {},
                                  );
                                  if (matched['defaultBtn'] != null &&
                                      _btn1Ctrl.text.trim().isEmpty) {
                                    _btn1Ctrl.text = matched['defaultBtn']!;
                                  }
                                });
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 6. Banner Image & Primary Button Label Row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 6,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Banner Image URL (Optional)',
                                style: GoogleFonts.outfit(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF334155),
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                controller: _imgCtrl,
                                onChanged: (_) => setState(() {}),
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  color: const Color(0xFF0F172A),
                                ),
                                decoration: InputDecoration(
                                  hintText: 'https://... image banner url',
                                  hintStyle: GoogleFonts.outfit(
                                    fontSize: 12.5,
                                    color: const Color(0xFF94A3B8),
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.image_outlined,
                                    size: 18,
                                    color: Color(0xFF64748B),
                                  ),
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFCBD5E1),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFCBD5E1),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                      color: Color(0xFF16A34A),
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Primary CTA Button',
                                style: GoogleFonts.outfit(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF334155),
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                controller: _btn1Ctrl,
                                onChanged: (_) => setState(() {}),
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF0F172A),
                                ),
                                decoration: InputDecoration(
                                  hintText: '⚡ Open Offer',
                                  hintStyle: GoogleFonts.outfit(
                                    fontSize: 12.5,
                                    color: const Color(0xFF94A3B8),
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.touch_app_rounded,
                                    size: 18,
                                    color: Color(0xFF64748B),
                                  ),
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFCBD5E1),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFCBD5E1),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                      color: Color(0xFF16A34A),
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 7. Live Smartphone Push Notification Card Preview
                    Text(
                      '📱 Live Notification Preview:',
                      style: GoogleFonts.outfit(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF16A34A),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(
                                  Icons.agriculture_rounded,
                                  color: Colors.white,
                                  size: 13,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'KRISHI KRANTI DEALER',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF64748B),
                                  letterSpacing: 0.6,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                'Just now',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  color: const Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            previewTitle,
                            style: GoogleFonts.outfit(
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            previewBody,
                            style: GoogleFonts.outfit(
                              fontSize: 12.5,
                              color: const Color(0xFF475569),
                              height: 1.35,
                            ),
                          ),
                          if (_imgCtrl.text.trim().isNotEmpty) ...[
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                _imgCtrl.text.trim(),
                                height: 110,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  height: 50,
                                  color: const Color(0xFFE2E8F0),
                                  child: Center(
                                    child: Text(
                                      '⚠️ Invalid Image URL',
                                      style: GoogleFonts.outfit(
                                        fontSize: 11,
                                        color: const Color(0xFF94A3B8),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF16A34A),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  _btn1Ctrl.text.trim().isEmpty
                                      ? '⚡ Open Offer'
                                      : _btn1Ctrl.text.trim(),
                                  style: GoogleFonts.outfit(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE2E8F0),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.link_rounded,
                                      size: 13,
                                      color: Color(0xFF475569),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Lands on: $_actionRoute',
                                      style: GoogleFonts.outfit(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF475569),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Modal Actions Footer
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 14,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(
                  top: BorderSide(color: Color(0xFFE2E8F0)),
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF64748B),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    icon: const Icon(
                      Icons.check_circle_outline_rounded,
                      size: 17,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () {
                      if (_titleCtrl.text.trim().isEmpty ||
                          _bodyCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Please provide both a Title and Message Body',
                            ),
                            backgroundColor: Color(0xFFDC2626),
                          ),
                        );
                        return;
                      }

                      Navigator.pop(context);
                      context.read<PushCampaignsBloc>().add(
                        AddCampaignTemplateEvent(
                          segmentKey: widget.segmentKey,
                          templateData: {
                            'title': _titleCtrl.text.trim(),
                            'body': _bodyCtrl.text.trim(),
                            'imageUrl': _imgCtrl.text.trim(),
                            'actionRoute': _actionRoute,
                            'button1': _btn1Ctrl.text.trim(),
                            'button2': _btn2Ctrl.text.trim(),
                          },
                        ),
                      );
                    },
                    label: Text(
                      'Add to Rotation',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
