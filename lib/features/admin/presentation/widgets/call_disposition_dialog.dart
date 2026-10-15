import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class AcwDraft {
  String disposition;
  DateTime? followUpDate;
  TimeOfDay? followUpTime;
  String followUpNote;
  String notes;
  DateTime? taskReminderDate;
  TimeOfDay? taskReminderTime;
  String taskReminderTitle;
  String taskReminderNote;

  AcwDraft({
    this.disposition = 'Interested',
    this.followUpDate,
    this.followUpTime,
    this.followUpNote = '',
    this.notes = '',
    this.taskReminderDate,
    this.taskReminderTime,
    this.taskReminderTitle = '',
    this.taskReminderNote = '',
  });
}

class CallDispositionDialog extends StatefulWidget {
  final String callLogId;
  final String customerPhone;
  final String? customerName;
  final String? initialDisposition;
  final DateTime? initialFollowUpDate;
  final String? initialFollowUpNote;
  final String? initialNotes;
  final DateTime? initialTaskReminderDate;
  final String? initialTaskReminderTitle;
  final String? initialTaskReminderNote;
  final Function(
    String disposition,
    DateTime? followUpDate,
    String? followUpNote,
    String? notes, {
    DateTime? taskReminderDate,
    String? taskReminderTitle,
    String? taskReminderNote,
  }) onSave;
  final VoidCallback? onOpenEstimate;
  final VoidCallback? onOpenWhatsApp;

  const CallDispositionDialog({
    super.key,
    required this.callLogId,
    required this.customerPhone,
    this.customerName,
    this.initialDisposition,
    this.initialFollowUpDate,
    this.initialFollowUpNote,
    this.initialNotes,
    this.initialTaskReminderDate,
    this.initialTaskReminderTitle,
    this.initialTaskReminderNote,
    required this.onSave,
    this.onOpenEstimate,
    this.onOpenWhatsApp,
  });

  @override
  State<CallDispositionDialog> createState() => _CallDispositionDialogState();
}

class _CallDispositionDialogState extends State<CallDispositionDialog> {
  // In-memory static cache keyed by customer phone / call log ID
  static final Map<String, AcwDraft> _draftCache = {};

  String get _draftKey {
    final cleanPhone = widget.customerPhone.replaceAll(RegExp(r'\D'), '').replaceFirst(RegExp(r'^91'), '');
    if (cleanPhone.isNotEmpty) return cleanPhone;
    if (widget.callLogId.isNotEmpty) return widget.callLogId;
    return 'active_call_draft';
  }

  String _selectedDisposition = 'Interested';
  DateTime? _selectedFollowUpDate;
  TimeOfDay? _selectedFollowUpTime;
  DateTime? _selectedTaskReminderDate;
  TimeOfDay? _selectedTaskReminderTime;

  late final TextEditingController _notesController;
  late final TextEditingController _followUpNoteController;
  late final TextEditingController _taskReminderTitleController;
  late final TextEditingController _taskReminderNoteController;

  @override
  void initState() {
    super.initState();
    final draft = _draftCache[_draftKey];
    
    // Prioritize draft, then widget initial values, then fallback
    _selectedDisposition = draft?.disposition ?? 
        ((widget.initialDisposition != null && widget.initialDisposition!.trim().isNotEmpty) 
            ? widget.initialDisposition!.trim() 
            : 'Interested');

    _selectedFollowUpDate = draft?.followUpDate ?? widget.initialFollowUpDate;
    if (_selectedFollowUpDate != null) {
      _selectedFollowUpTime = draft?.followUpTime ?? TimeOfDay(hour: _selectedFollowUpDate!.hour, minute: _selectedFollowUpDate!.minute);
    } else {
      _selectedFollowUpTime = draft?.followUpTime;
    }

    _selectedTaskReminderDate = draft?.taskReminderDate ?? widget.initialTaskReminderDate;
    if (_selectedTaskReminderDate != null) {
      _selectedTaskReminderTime = draft?.taskReminderTime ?? TimeOfDay(hour: _selectedTaskReminderDate!.hour, minute: _selectedTaskReminderDate!.minute);
    } else {
      _selectedTaskReminderTime = draft?.taskReminderTime;
    }

    final initNotes = draft?.notes ?? widget.initialNotes ?? '';
    final initFollowNote = draft?.followUpNote ?? widget.initialFollowUpNote ?? '';
    final initTaskTitle = draft?.taskReminderTitle ?? widget.initialTaskReminderTitle ?? '';
    final initTaskNote = draft?.taskReminderNote ?? widget.initialTaskReminderNote ?? '';

    _notesController = TextEditingController(text: initNotes);
    _followUpNoteController = TextEditingController(text: initFollowNote);
    _taskReminderTitleController = TextEditingController(text: initTaskTitle);
    _taskReminderNoteController = TextEditingController(text: initTaskNote);

    _notesController.addListener(_persistDraft);
    _followUpNoteController.addListener(_persistDraft);
    _taskReminderTitleController.addListener(_persistDraft);
    _taskReminderNoteController.addListener(_persistDraft);
  }

  @override
  void dispose() {
    _notesController.removeListener(_persistDraft);
    _followUpNoteController.removeListener(_persistDraft);
    _taskReminderTitleController.removeListener(_persistDraft);
    _taskReminderNoteController.removeListener(_persistDraft);
    _notesController.dispose();
    _followUpNoteController.dispose();
    _taskReminderTitleController.dispose();
    _taskReminderNoteController.dispose();
    super.dispose();
  }

  void _persistDraft() {
    _draftCache[_draftKey] = AcwDraft(
      disposition: _selectedDisposition,
      followUpDate: _selectedFollowUpDate,
      followUpTime: _selectedFollowUpTime,
      followUpNote: _followUpNoteController.text,
      notes: _notesController.text,
      taskReminderDate: _selectedTaskReminderDate,
      taskReminderTime: _selectedTaskReminderTime,
      taskReminderTitle: _taskReminderTitleController.text,
      taskReminderNote: _taskReminderNoteController.text,
    );
  }

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
      _persistDraft();
    }
  }

  Future<void> _pickTaskReminderDate() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedTaskReminderDate ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
    );

    if (pickedDate != null) {
      if (!mounted) return;
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: _selectedTaskReminderTime ?? TimeOfDay.now(),
      );

      setState(() {
        _selectedTaskReminderDate = pickedDate;
        _selectedTaskReminderTime = pickedTime ?? TimeOfDay.now();
      });
      _persistDraft();
    }
  }

  void _applyTaskPreset(Duration duration, {String? defaultTitle}) {
    final target = DateTime.now().add(duration);
    setState(() {
      _selectedTaskReminderDate = target;
      _selectedTaskReminderTime = TimeOfDay(hour: target.hour, minute: target.minute);
      if (_taskReminderTitleController.text.trim().isEmpty && defaultTitle != null) {
        _taskReminderTitleController.text = defaultTitle;
      }
    });
    _persistDraft();
  }

  void _applyTomorrowPreset({int hour = 10, int minute = 0, String? defaultTitle}) {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1, hour, minute);
    setState(() {
      _selectedTaskReminderDate = tomorrow;
      _selectedTaskReminderTime = TimeOfDay(hour: hour, minute: minute);
      if (_taskReminderTitleController.text.trim().isEmpty && defaultTitle != null) {
        _taskReminderTitleController.text = defaultTitle;
      }
    });
    _persistDraft();
  }

  Widget _buildTaskPresetChip(String label, VoidCallback onTap, {bool isCustom = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isCustom ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isCustom ? const Color(0xFFBFDBFE) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isCustom ? Icons.edit_calendar_rounded : Icons.schedule_rounded,
              size: 13,
              color: isCustom ? const Color(0xFF2563EB) : const Color(0xFF475569),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isCustom ? const Color(0xFF1D4ED8) : const Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
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

    DateTime? combinedTaskReminder;
    if (_selectedTaskReminderDate != null && _selectedTaskReminderTime != null) {
      combinedTaskReminder = DateTime(
        _selectedTaskReminderDate!.year,
        _selectedTaskReminderDate!.month,
        _selectedTaskReminderDate!.day,
        _selectedTaskReminderTime!.hour,
        _selectedTaskReminderTime!.minute,
      );
    }

    // Clear draft upon successful save
    _draftCache.remove(_draftKey);

    widget.onSave(
      _selectedDisposition,
      combinedDate,
      _followUpNoteController.text.trim().isNotEmpty ? _followUpNoteController.text.trim() : null,
      _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
      taskReminderDate: combinedTaskReminder,
      taskReminderTitle: _taskReminderTitleController.text.trim().isNotEmpty ? _taskReminderTitleController.text.trim() : null,
      taskReminderNote: _taskReminderNoteController.text.trim().isNotEmpty ? _taskReminderNoteController.text.trim() : null,
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
                          onTap: () {
                            setState(() => _selectedDisposition = item['label']);
                            _persistDraft();
                          },
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

                    // ── Task Reminder & 2-Tier Automated Notification Card ──
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _selectedTaskReminderDate != null ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _selectedTaskReminderDate != null ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.alarm_add_rounded,
                                    color: _selectedTaskReminderDate != null ? const Color(0xFF16A34A) : const Color(0xFF0284C7),
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'SCHEDULE TASK REMINDER',
                                    style: GoogleFonts.outfit(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                      color: _selectedTaskReminderDate != null ? const Color(0xFF15803D) : const Color(0xFF0369A1),
                                    ),
                                  ),
                                ],
                              ),
                              if (_selectedTaskReminderDate != null)
                                InkWell(
                                  onTap: () {
                                    setState(() {
                                      _selectedTaskReminderDate = null;
                                      _selectedTaskReminderTime = null;
                                    });
                                    _persistDraft();
                                  },
                                  borderRadius: BorderRadius.circular(4),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.close_rounded, size: 13, color: Color(0xFFEF4444)),
                                        const SizedBox(width: 3),
                                        Text(
                                          'Clear',
                                          style: GoogleFonts.outfit(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFFEF4444),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Sends 2 automated notifications: 30 minutes before & at the exact task time.',
                            style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 10),
                          // Quick preset chips
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _buildTaskPresetChip('In 30 Mins', () => _applyTaskPreset(const Duration(minutes: 30))),
                              _buildTaskPresetChip('In 1 Hour', () => _applyTaskPreset(const Duration(hours: 1))),
                              _buildTaskPresetChip('In 3 Hours', () => _applyTaskPreset(const Duration(hours: 3))),
                              _buildTaskPresetChip('Tomorrow 10 AM', () => _applyTomorrowPreset(hour: 10, minute: 0)),
                              _buildTaskPresetChip('Pick Date & Time', _pickTaskReminderDate, isCustom: true),
                            ],
                          ),
                          if (_selectedTaskReminderDate != null) ...[
                            const SizedBox(height: 10),
                            InkWell(
                              onTap: _pickTaskReminderDate,
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFF86EFAC)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.event_available_rounded, size: 15, color: Color(0xFF16A34A)),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Set for: ${DateFormat('dd MMM yyyy').format(_selectedTaskReminderDate!)} at ${_selectedTaskReminderTime?.format(context) ?? '10:00 AM'}',
                                      style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.bold, color: const Color(0xFF15803D)),
                                    ),
                                    const SizedBox(width: 6),
                                    const Icon(Icons.edit_calendar_rounded, size: 13, color: Color(0xFF16A34A)),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _taskReminderTitleController,
                              style: GoogleFonts.outfit(fontSize: 12.5),
                              decoration: InputDecoration(
                                hintText: 'Task Title (e.g. Call back for bulk discount / Payment update)',
                                hintStyle: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF94A3B8)),
                                filled: true,
                                fillColor: Colors.white,
                                isDense: true,
                                prefixIcon: const Icon(Icons.title_rounded, size: 16, color: Color(0xFF64748B)),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _taskReminderNoteController,
                              style: GoogleFonts.outfit(fontSize: 12.5),
                              decoration: InputDecoration(
                                hintText: 'Optional task notes or details...',
                                hintStyle: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF94A3B8)),
                                filled: true,
                                fillColor: Colors.white,
                                isDense: true,
                                prefixIcon: const Icon(Icons.notes_rounded, size: 16, color: Color(0xFF64748B)),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

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
