import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/push_campaigns_bloc.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/push_campaigns_event.dart';
import 'package:kd_pannel/features/admin/presentation/widgets/campaigns/campaign_constants.dart';

class CreateSegmentDialog extends StatefulWidget {
  const CreateSegmentDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => const CreateSegmentDialog(),
    );
  }

  @override
  State<CreateSegmentDialog> createState() => _CreateSegmentDialogState();
}

class _CreateSegmentDialogState extends State<CreateSegmentDialog> {
  final _keyCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _selectedCategory = 'marketing';
  final String _scheduledTime = '09:30';
  String _targetRoute = '/dashboard';

  @override
  void dispose() {
    _keyCtrl.dispose();
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      contentPadding: EdgeInsets.zero,
      content: Container(
        width: 580,
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
                      Icons.add_to_photos_rounded,
                      color: Color(0xFF4ADE80),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Create Lifecycle Campaign Segment',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Define audience criteria, automated trigger rules & route',
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

            // Modal Body Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Quick Presets Bar
                    Text(
                      '⚡ Quick Targeting Presets (1-Click Fill):',
                      style: GoogleFonts.outfit(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: CampaignConstants.targetingPresets.map((p) {
                        return InkWell(
                          onTap: () {
                            setState(() {
                              _keyCtrl.text = p['key'] as String;
                              _nameCtrl.text = p['name'] as String;
                              _descCtrl.text = p['desc'] as String;
                              _selectedCategory = p['cat'] as String;
                              _targetRoute = p['route'] as String;
                            });
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  p['icon'] as IconData,
                                  size: 14,
                                  color: p['color'] as Color,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  p['name'] as String,
                                  style: GoogleFonts.outfit(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF334155),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // 2. Segment Key & Display Name Inputs
                    Row(
                      children: [
                        SizedBox(
                          width: 160,
                          child: TextField(
                            controller: _keyCtrl,
                            decoration: InputDecoration(
                              labelText: 'Segment Key',
                              hintText: 'e.g. K, FLASH_DEALS',
                              isDense: true,
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
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
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _nameCtrl,
                            decoration: InputDecoration(
                              labelText: 'Segment Display Name',
                              hintText: 'e.g. Top Wholesale Agrochemical Buyers',
                              isDense: true,
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
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
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // 3. Campaign Purpose / Notes
                    TextField(
                      controller: _descCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Campaign Goal / Audience Notes',
                        hintText:
                            'e.g. Target pre-KYC dealers to motivate license and shop photo upload',
                        isDense: true,
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
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

                    // 4. Category & Destination Route Selectors
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue: _selectedCategory,
                            decoration: InputDecoration(
                              labelText: 'Lifecycle Category',
                              isDense: true,
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
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
                            items: const [
                              DropdownMenuItem(
                                value: 'marketing',
                                child: Text('🌾 Marketing & Deals'),
                              ),
                              DropdownMenuItem(
                                value: 'kyc',
                                child: Text('📋 KYC & Leads'),
                              ),
                              DropdownMenuItem(
                                value: 'cart',
                                child: Text('🛒 Cart Recovery'),
                              ),
                              DropdownMenuItem(
                                value: 'orders',
                                child: Text('📦 Orders & Retention'),
                              ),
                              DropdownMenuItem(
                                value: 'seasonal',
                                child: Text('🌧️ Seasonal'),
                              ),
                              DropdownMenuItem(
                                value: 'promotional',
                                child: Text('🔥 Flash Discount'),
                              ),
                              DropdownMenuItem(
                                value: 're-engagement',
                                child: Text('🔄 Win-Back Dormant'),
                              ),
                            ],
                            onChanged: (v) => setState(() => _selectedCategory = v!),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue: _targetRoute,
                            decoration: InputDecoration(
                              labelText: 'Target App Screen',
                              isDense: true,
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
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
                            items: CampaignConstants.defaultDeepLinkRoutes.map((r) {
                              return DropdownMenuItem(
                                value: r['route'],
                                child: Text(
                                  r['label']!,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (v) => setState(() => _targetRoute = v!),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Modal Footer Actions
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 14,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF475569),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: Text(
                      'Create Segment',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () {
                      final k = _keyCtrl.text.trim().toUpperCase();
                      final n = _nameCtrl.text.trim();
                      if (k.isEmpty || n.isEmpty) return;

                      Navigator.pop(context);
                      context.read<PushCampaignsBloc>().add(
                        CreateCampaignSegmentEvent({
                          'segmentKey': k,
                          'name': n,
                          'description': _descCtrl.text.trim(),
                          'category': _selectedCategory,
                          'targetRoute': _targetRoute,
                          'scheduledTime': _scheduledTime,
                          'isEnabled': true,
                          'mode': 'rotating',
                          'templates': [],
                        }),
                      );
                    },
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
