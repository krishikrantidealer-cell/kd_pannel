import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kd_pannel/app_theme.dart';
import 'package:kd_pannel/core/responsive/responsive.dart';

class UserStatusNotesWidget extends StatefulWidget {
  final String userId;
  final String initialStatus;
  final String initialNotes;
  final bool isSubmitting;
  final Function(String status, String notes) onSave;
  final List<String>? statusOptions;
  final String? title;
  final String? statusLabel;
  final String? notesLabel;
  final List<Widget>? stats;
  final List<Map<String, dynamic>>? notesHistory;

  const UserStatusNotesWidget({
    super.key,
    required this.userId,
    required this.initialStatus,
    required this.initialNotes,
    required this.isSubmitting,
    required this.onSave,
    this.statusOptions,
    this.title,
    this.statusLabel,
    this.notesLabel,
    this.stats,
    this.notesHistory,
  });

  @override
  State<UserStatusNotesWidget> createState() => _UserStatusNotesWidgetState();
}

class _UserStatusNotesWidgetState extends State<UserStatusNotesWidget> {
  late String _selectedStatus;
  late TextEditingController _notesController;
  final FocusNode _notesFocusNode = FocusNode();
  bool _hasChanges = false;

  late final List<String> _statusOptions;

  @override
  void initState() {
    super.initState();
    _statusOptions = widget.statusOptions ??
        [
          'kyc pending',
          'call not picked',
          'connected but not intrested',
          'quotation sent',
          'negotiation',
          'follow-up',
          'lost',
          'intrested',
          'customer busy',
          'call switch off',
          'prospect'
        ];

    _selectedStatus = widget.initialStatus.toLowerCase();
    if (!_statusOptions.contains(_selectedStatus)) {
      _selectedStatus = _statusOptions.contains('prospect')
          ? 'prospect'
          : _statusOptions.first;
    }
    _notesController = TextEditingController(text: widget.initialNotes);
    _notesController.addListener(_checkForChanges);
  }

  @override
  void didUpdateWidget(UserStatusNotesWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _selectedStatus = widget.initialStatus.toLowerCase();
      if (!_statusOptions.contains(_selectedStatus)) {
        _selectedStatus = _statusOptions.contains('prospect')
            ? 'prospect'
            : _statusOptions.first;
      }
      _notesController.text = widget.initialNotes;
      _hasChanges = false;
    } else {
      if (oldWidget.initialStatus != widget.initialStatus &&
          !_notesFocusNode.hasFocus) {
        _selectedStatus = widget.initialStatus.toLowerCase();
        if (!_statusOptions.contains(_selectedStatus)) {
          _selectedStatus = _statusOptions.contains('prospect')
              ? 'prospect'
              : _statusOptions.first;
        }
      }
      if (oldWidget.initialNotes != widget.initialNotes &&
          !_notesFocusNode.hasFocus) {
        _notesController.text = widget.initialNotes;
        _hasChanges = false;
      }
    }
  }

  void _checkForChanges() {
    final bool changed =
        _selectedStatus != widget.initialStatus.toLowerCase() ||
            _notesController.text != widget.initialNotes;
    if (changed != _hasChanges) {
      setState(() {
        _hasChanges = changed;
      });
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    _notesFocusNode.dispose();
    super.dispose();
  }

  void _save() {
    _notesFocusNode.unfocus();
    widget.onSave(_selectedStatus, _notesController.text.trim());
    setState(() {
      _hasChanges = false;
    });
  }

  String _formatStatusName(String status) {
    switch (status.toLowerCase()) {
      case 'kyc pending':
        return 'KYC Pending';
      case 'call not picked':
        return 'Call Not Picked';
      case 'connected but not intrested':
        return 'Connected but not Interested';
      case 'quotation sent':
        return 'Quotation Sent';
      case 'negotiation':
        return 'Negotiation';
      case 'follow-up':
        return 'Follow-up';
      case 'lost':
        return 'Lost';
      case 'intrested':
        return 'Interested';
      case 'customer busy':
        return 'Customer Busy';
      case 'call switch off':
        return 'Call Switch Off';
      case 'prospect':
        return 'Prospect';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.title ?? 'User Status & Notes',
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF111827),
                ),
              ),
              if (_hasChanges)
                ElevatedButton.icon(
                  onPressed: widget.isSubmitting ? null : _save,
                  icon: widget.isSubmitting
                      ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_outlined, size: 14),
                  label: const Text('Save'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    textStyle: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
            ],
          ),
          if (widget.stats != null && widget.stats!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: widget.stats!,
            ),
          ],
          const SizedBox(height: 16),
          Text(
            widget.statusLabel ?? 'User Status',
            style: GoogleFonts.outfit(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedStatus,
                isExpanded: true,
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppTheme.textSecondary,
                  size: 20,
                ),
                dropdownColor: Colors.white,
                items: _statusOptions.map((status) {
                  return DropdownMenuItem<String>(
                    value: status,
                    child: Text(
                      _formatStatusName(status),
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: widget.isSubmitting
                    ? null
                    : (val) {
                        if (val != null) {
                          setState(() {
                            _selectedStatus = val;
                            _checkForChanges();
                          });
                        }
                      },
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.notesLabel ?? 'User Notes',
            style: GoogleFonts.outfit(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _notesController,
            focusNode: _notesFocusNode,
            maxLines: 4,
            minLines: 2,
            enabled: !widget.isSubmitting,
            style: GoogleFonts.outfit(
              fontSize: 13.5,
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: 'Enter detailed follow-up notes here...',
              hintStyle: GoogleFonts.outfit(
                fontSize: 13,
                color: AppTheme.textSecondary.withValues(alpha: 0.6),
                fontWeight: FontWeight.w500,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppTheme.borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppTheme.borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: AppTheme.primaryColor, width: 1.5),
              ),
            ),
          ),
          if (widget.notesHistory != null && widget.notesHistory!.isNotEmpty) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                const Icon(Icons.history_rounded, size: 16, color: AppTheme.textSecondary),
                const SizedBox(width: 8),
                Text(
                  'Notes History',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: widget.notesHistory!.length,
                separatorBuilder: (context, index) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final reversedList = widget.notesHistory!.reversed.toList();
                  final item = reversedList[index];
                  final String note = item['note'] ?? '';
                  final String dateStr = item['createdAt'] ?? '';
                  final String adminName = item['adminName'] ?? 'Admin';
                  
                  String formattedDate = '';
                  try {
                    final dt = DateTime.parse(dateStr).toLocal();
                    formattedDate = '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
                  } catch (_) {
                    formattedDate = dateStr;
                  }
 
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.8)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.015),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 3.5,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    adminName,
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                  Text(
                                    formattedDate,
                                    style: GoogleFonts.outfit(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w500,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                note,
                                style: GoogleFonts.outfit(
                                  fontSize: 12.5,
                                  color: AppTheme.textBody,
                                  height: 1.45,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
