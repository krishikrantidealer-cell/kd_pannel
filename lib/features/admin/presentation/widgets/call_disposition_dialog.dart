import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:kd_pannel/app_theme.dart';

class CallDispositionDialog extends StatefulWidget {
  final String callLogId;
  final String customerPhone;
  final String? customerName;
  final Function(String disposition, DateTime? followUpDate, String? followUpNote, String? notes) onSave;
  final VoidCallback? onOpenEstimate;
  final VoidCallback? onOpenWhatsApp;

  const CallDispositionDialog({
    super.key,
    required this.callLogId,
    required this.customerPhone,
    this.customerName,
    required this.onSave,
    this.onOpenEstimate,
    this.onOpenWhatsApp,
  });

  @override
  State<CallDispositionDialog> createState() => _CallDispositionDialogState();
}

class _CallDispositionDialogState extends State<CallDispositionDialog> {
  String _selectedDisposition = 'Interested';
  DateTime? _selectedFollowUpDate;
  TimeOfDay? _selectedFollowUpTime;
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _followUpNoteController = TextEditingController();

  final List<Map<String, dynamic>> _dispositionOptions = [
    {
      'label': 'Interested',
      'icon': Icons.thumb_up_alt_rounded,
      'color': const Color(0xFF10B981),
      'description': 'Customer expressed interest in catalog or products'
    },
    {
      'label': 'Order Ready',
      'icon': Icons.shopping_bag_rounded,
      'color': const Color(0xFF2563EB),
      'description': 'Customer wants to place order / create estimate'
    },
    {
      'label': 'Callback Requested',
      'icon': Icons.alarm_rounded,
      'color': const Color(0xFFF59E0B),
      'description': 'Requested a callback at a specific date & time'
    },
    {
      'label': 'Price Objection',
      'icon': Icons.price_change_rounded,
      'color': const Color(0xFF8B5CF6),
      'description': 'Price too high / negotiating discount coupon'
    },
    {
      'label': 'Busy / No Answer',
      'icon': Icons.phone_missed_rounded,
      'color': const Color(0xFF64748B),
      'description': 'Customer did not pick up or was busy'
    },
    {
      'label': 'Wrong Number',
      'icon': Icons.cancel_rounded,
      'color': const Color(0xFFEF4444),
      'description': 'Invalid phone or unreachable'
    },
  ];

  final List<String> _quickNotesChips = [
    'Wants Fertilizer Bulk Deal',
    'Needs 5% Discount Coupon',
    'GST Invoice Required',
    'Quotation PDF Requested',
    'Call back after 4 PM',
    'Stock Inquiry: Urea & Sprayer',
  ];

  Future<void> _pickFollowUpDate() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
    );

    if (pickedDate != null) {
      if (!mounted) return;
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: const TimeOfDay(hour: 11, minute: 0),
      );

      setState(() {
        _selectedFollowUpDate = pickedDate;
        _selectedFollowUpTime = pickedTime ?? const TimeOfDay(hour: 11, minute: 0);
      });
    }
  }

  void _submit() {
    DateTime? combinedDate;
    if (_selectedFollowUpDate != null && _selectedFollowUpTime != null) {
      combinedDate = DateTime(
        _selectedFollowUpDate!.year,
        _selectedFollowUpDate!.month,
        _selectedFollowUpDate!.day,
        _selectedFollowUpTime!.hour,
        _selectedFollowUpTime!.minute,
      );
    }

    widget.onSave(
      _selectedDisposition,
      combinedDate,
      _followUpNoteController.text.trim().isNotEmpty ? _followUpNoteController.text.trim() : null,
      _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isCallback = _selectedDisposition == 'Callback Requested';
    final isOrderReady = _selectedDisposition == 'Order Ready';

    return Dialog(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        width: 580,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Header
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 20, 16),
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF008069).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF008069).withValues(alpha: 0.4)),
                        ),
                        child: const Icon(Icons.phone_callback_rounded, color: Color(0xFF4ADE80), size: 22),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Smart Call Disposition (ACW)',
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${widget.customerName ?? 'Customer'} • +${widget.customerPhone}',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Dialog Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SELECT CALL OUTCOME',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Disposition Grid
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 2.8,
                      ),
                      itemCount: _dispositionOptions.length,
                      itemBuilder: (context, index) {
                        final item = _dispositionOptions[index];
                        final isSelected = _selectedDisposition == item['label'];
                        final Color itemColor = item['color'];

                        return InkWell(
                          onTap: () => setState(() => _selectedDisposition = item['label']),
                          borderRadius: BorderRadius.circular(12),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? itemColor.withValues(alpha: 0.1) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? itemColor : const Color(0xFFE2E8F0),
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: itemColor.withValues(alpha: isSelected ? 0.2 : 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(item['icon'], color: itemColor, size: 16),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        item['label'],
                                        style: GoogleFonts.outfit(
                                          fontSize: 12.5,
                                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                          color: isSelected ? itemColor : const Color(0xFF1E293B),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 18),

                    // Conditional Callback Date Picker
                    if (isCallback) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.calendar_month_rounded, color: Color(0xFFD97706), size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'SCHEDULE FOLLOW-UP CALLBACK',
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFFB45309),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _pickFollowUpDate,
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    icon: const Icon(Icons.event, size: 16),
                                    label: Text(
                                      _selectedFollowUpDate == null
                                          ? 'Pick Date & Time'
                                          : '${DateFormat('dd MMM yyyy').format(_selectedFollowUpDate!)} at ${_selectedFollowUpTime?.format(context) ?? '11:00 AM'}',
                                      style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _followUpNoteController,
                              style: GoogleFonts.outfit(fontSize: 12.5),
                              decoration: InputDecoration(
                                hintText: 'Reminder note (e.g. Call regarding quotation discount)...',
                                hintStyle: GoogleFonts.outfit(fontSize: 12, color: Colors.grey),
                                filled: true,
                                fillColor: Colors.white,
                                isDense: true,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Smart 1-Click Action Hooks
                    if (isOrderReady || _selectedDisposition == 'Interested') ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFBBF7D0)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.bolt_rounded, color: Color(0xFF16A34A), size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Quick Action:',
                              style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF15803D)),
                            ),
                            const Spacer(),
                            if (widget.onOpenEstimate != null)
                              ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  widget.onOpenEstimate!();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF16A34A),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  elevation: 0,
                                ),
                                icon: const Icon(Icons.description_rounded, size: 14),
                                label: Text('Create Estimate', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                            const SizedBox(width: 8),
                            if (widget.onOpenWhatsApp != null)
                              OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  widget.onOpenWhatsApp!();
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF008069),
                                  side: const BorderSide(color: Color(0xFF008069)),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                ),
                                icon: const Icon(Icons.chat_rounded, size: 14),
                                label: Text('WhatsApp Chat', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Quick Chips
                    Text(
                      'QUICK NOTES',
                      style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: const Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _quickNotesChips.map((chip) {
                        return ActionChip(
                          label: Text(chip, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600)),
                          backgroundColor: const Color(0xFFF1F5F9),
                          onPressed: () {
                            if (_notesController.text.isEmpty) {
                              _notesController.text = chip;
                            } else {
                              _notesController.text += ', $chip';
                            }
                            setState(() {});
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),

                    // Notes Text Field
                    TextField(
                      controller: _notesController,
                      maxLines: 3,
                      style: GoogleFonts.outfit(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Enter detailed post-call notes or objections...',
                        hintStyle: GoogleFonts.outfit(fontSize: 12.5, color: const Color(0xFF94A3B8)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Footer Actions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('Cancel', style: GoogleFonts.outfit(color: const Color(0xFF64748B), fontWeight: FontWeight.bold)),
                  ),
                  ElevatedButton.icon(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF008069),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 2,
                    ),
                    icon: const Icon(Icons.check_circle_rounded, size: 18),
                    label: Text('Save Disposition & Log ACW', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold)),
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
