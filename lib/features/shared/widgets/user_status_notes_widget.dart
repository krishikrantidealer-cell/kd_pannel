import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kd_pannel/app_theme.dart';
import 'package:kd_pannel/core/responsive/responsive.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';

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
  late TextEditingController _notesSearchController;
  final FocusNode _notesFocusNode = FocusNode();
  bool _hasChanges = false;
  PickerDateRange? _selectedDateRange;

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
    _notesSearchController = TextEditingController();
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
    _notesSearchController.dispose();
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

  void _showDatePicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        content: SizedBox(
          height: 400,
          width: 350,
          child: SfDateRangePicker(
            backgroundColor: Colors.white,
            selectionMode: DateRangePickerSelectionMode.range,
            showActionButtons: true,
            confirmText: 'Apply',
            cancelText: 'Cancel',
            selectionShape: DateRangePickerSelectionShape.rectangle,
            rangeSelectionColor: AppTheme.primaryColor.withValues(alpha: 0.12),
            startRangeSelectionColor: AppTheme.primaryColor,
            endRangeSelectionColor: AppTheme.primaryColor,
            initialSelectedRange: _selectedDateRange,
            onSubmit: (Object? val) {
              if (val is PickerDateRange) {
                setState(() {
                  _selectedDateRange = val;
                });
                Navigator.pop(context);
              }
            },
            onCancel: () => Navigator.pop(context),
          ),
        ),
      ),
    );
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.history_rounded,
                        size: 16, color: AppTheme.textSecondary),
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
                Row(
                  children: [
                    if (_selectedDateRange != null)
                      TextButton(
                        onPressed: () => setState(() => _selectedDateRange = null),
                        child: Text(
                          'Clear Filter',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.error,
                          ),
                        ),
                      ),
                    InkWell(
                      onTap: _showDatePicker,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: _selectedDateRange != null
                              ? AppTheme.primaryColor.withValues(alpha: 0.08)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _selectedDateRange != null
                                ? AppTheme.primaryColor
                                : AppTheme.borderColor,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_month_outlined,
                              size: 14,
                              color: _selectedDateRange != null
                                  ? AppTheme.primaryColor
                                  : AppTheme.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _selectedDateRange == null
                                  ? 'Filter Date'
                                  : '${_selectedDateRange!.startDate!.day}/${_selectedDateRange!.startDate!.month} - ${_selectedDateRange!.endDate?.day ?? _selectedDateRange!.startDate!.day}/${_selectedDateRange!.endDate?.month ?? _selectedDateRange!.startDate!.month}',
                              style: GoogleFonts.outfit(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: _selectedDateRange != null
                                    ? AppTheme.primaryColor
                                    : AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            // History Search Bar
            Container(
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.8)),
              ),
              child: TextField(
                controller: _notesSearchController,
                onChanged: (val) => setState(() {}),
                style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Search in notes history...',
                  hintStyle: GoogleFonts.outfit(
                    fontSize: 12.5,
                    color: AppTheme.textSecondary.withValues(alpha: 0.6),
                  ),
                  prefixIcon: const Icon(Icons.search_rounded, size: 16, color: AppTheme.textSecondary),
                  suffixIcon: _notesSearchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 16),
                          onPressed: () {
                            _notesSearchController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              child: Builder(
                builder: (context) {
                  var filteredNotes = widget.notesHistory!.reversed.toList();

                  // 1. Date Filtering
                  if (_selectedDateRange != null &&
                      _selectedDateRange!.startDate != null) {
                    final start = _selectedDateRange!.startDate!;
                    final end = _selectedDateRange!.endDate ?? start;
                    final endOfRange =
                        DateTime(end.year, end.month, end.day, 23, 59, 59);

                    filteredNotes = filteredNotes.where((note) {
                      final String dateStr = note['createdAt'] ?? '';
                      try {
                        final dt = DateTime.parse(dateStr).toLocal();
                        return dt.isAfter(start) && dt.isBefore(endOfRange);
                      } catch (_) {
                        return false;
                      }
                    }).toList();
                  }

                  // 2. Text Search Filtering
                  final searchQuery = _notesSearchController.text.trim().toLowerCase();
                  if (searchQuery.isNotEmpty) {
                    filteredNotes = filteredNotes.where((note) {
                      final String text = (note['note'] ?? '').toString().toLowerCase();
                      final String admin = (note['adminName'] ?? '').toString().toLowerCase();
                      return text.contains(searchQuery) || admin.contains(searchQuery);
                    }).toList();
                  }

                  if (filteredNotes.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Text(
                          searchQuery.isNotEmpty 
                            ? 'No matches found for "$searchQuery"'
                            : 'No notes found for this date range.',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: filteredNotes.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = filteredNotes[index];
                      final String note = item['note'] ?? '';
                      final String dateStr = item['createdAt'] ?? '';
                      final String adminName = item['adminName'] ?? 'Admin';

                      String formattedDate = '';
                      try {
                        final dt = DateTime.parse(dateStr).toLocal();
                        formattedDate =
                            '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
                      } catch (_) {
                        formattedDate = dateStr;
                      }

                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: AppTheme.borderColor
                                  .withValues(alpha: 0.8)),
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
                                color:
                                    AppTheme.primaryColor.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
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
