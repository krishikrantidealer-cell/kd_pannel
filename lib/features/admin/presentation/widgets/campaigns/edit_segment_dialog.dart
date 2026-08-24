import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/push_campaigns_bloc.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/push_campaigns_event.dart';
import 'package:kd_pannel/features/admin/presentation/widgets/campaigns/campaign_constants.dart';

class EditSegmentDialog extends StatefulWidget {
  final Map<String, dynamic> campaign;

  const EditSegmentDialog({
    super.key,
    required this.campaign,
  });

  static Future<void> show(BuildContext context, Map<String, dynamic> campaign) {
    return showDialog(
      context: context,
      builder: (_) => EditSegmentDialog(campaign: campaign),
    );
  }

  @override
  State<EditSegmentDialog> createState() => _EditSegmentDialogState();
}

class _EditSegmentDialogState extends State<EditSegmentDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late String _selectedCategory;
  late String _targetRoute;
  late String _scheduledTime;
  late final String _segKey;

  @override
  void initState() {
    super.initState();
    _segKey = widget.campaign['segmentKey'] ?? '';
    _nameCtrl = TextEditingController(text: widget.campaign['name'] ?? '');
    _descCtrl = TextEditingController(text: widget.campaign['description'] ?? '');
    _selectedCategory = widget.campaign['category'] ?? 'marketing';
    _targetRoute = widget.campaign['targetRoute'] ?? '/dashboard';
    _scheduledTime = widget.campaign['scheduledTime'] ?? '09:30';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Color _getCategoryColor(String cat) {
    switch (cat.toLowerCase()) {
      case 'kyc':
        return const Color(0xFF8B5CF6);
      case 'cart':
        return const Color(0xFFF59E0B);
      case 'orders':
        return const Color(0xFF10B981);
      case 'seasonal':
        return const Color(0xFF0EA5E9);
      case 'promotional':
        return const Color(0xFFEC4899);
      case 're-engagement':
        return const Color(0xFF6366F1);
      default:
        return const Color(0xFF16A34A);
    }
  }

  @override
  Widget build(BuildContext context) {
    final catColor = _getCategoryColor(_selectedCategory);

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      contentPadding: EdgeInsets.zero,
      content: Container(
        width: 560,
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: catColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'SEGMENT $_segKey',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Edit Segment Configuration',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Update lifecycle criteria, schedule & deep link',
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

            // Modal Body Form
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Audience Engine Rule (System Managed Banner)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFFCBD5E1),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.lock_outline_rounded,
                            size: 18,
                            color: Color(0xFF64748B),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'Audience Targeting Logic',
                                      style: GoogleFonts.outfit(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF1E293B),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 1,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE2E8F0),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'ENGINE MANAGED',
                                        style: GoogleFonts.outfit(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFF475569),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _descCtrl.text.isNotEmpty
                                      ? _descCtrl.text
                                      : 'Automatic database audience filter mapped to Segment $_segKey criteria.',
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    color: const Color(0xFF475569),
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 2. Campaign Display Name
                    TextField(
                      controller: _nameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Campaign Display Name',
                        hintText: 'e.g. KYC Onboarding Series',
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
                              labelText: 'Default Action Route',
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
                    const SizedBox(height: 14),

                    // Schedule Time Pill Inside Edit Modal
                    InkWell(
                      onTap: () async {
                        final parts = _scheduledTime.split(':');
                        final initialHour = parts.isNotEmpty
                            ? int.tryParse(parts[0]) ?? 9
                            : 9;
                        final initialMin = parts.length > 1
                            ? int.tryParse(parts[1]) ?? 30
                            : 30;

                        final picked = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay(
                            hour: initialHour,
                            minute: initialMin,
                          ),
                          helpText:
                              'Select Daily Dispatch Time (Kolkata IST)',
                        );
                        if (picked != null) {
                          final formatted =
                              '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                          setState(() => _scheduledTime = formatted);
                        }
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFFCBD5E1),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.access_time_filled_rounded,
                              size: 18,
                              color: Color(0xFF16A34A),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Daily Scheduled Dispatch: ',
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF334155),
                              ),
                            ),
                            Text(
                              '$_scheduledTime IST',
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF16A34A),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              'Change',
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF2563EB),
                              ),
                            ),
                          ],
                        ),
                      ),
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
                    icon: const Icon(Icons.save_rounded, size: 18),
                    label: Text(
                      'Save Changes',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      context.read<PushCampaignsBloc>().add(
                        UpdateCampaignConfigEvent(
                          segmentKey: _segKey,
                          updates: {
                            'name': _nameCtrl.text.trim(),
                            'description': _descCtrl.text.trim(),
                            'category': _selectedCategory,
                            'targetRoute': _targetRoute,
                            'scheduledTime': _scheduledTime,
                          },
                        ),
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
