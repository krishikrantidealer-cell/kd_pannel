import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kd_pannel/app_theme.dart';
import 'package:kd_pannel/core/responsive/responsive.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';

// ─── Note Type ───────────────────────────────────────────────────────────────

enum NoteType { general, call, meeting, followup, quote, issue }

extension NoteTypeX on NoteType {
  String get key {
    switch (this) {
      case NoteType.general:
        return 'general';
      case NoteType.call:
        return 'call';
      case NoteType.meeting:
        return 'meeting';
      case NoteType.followup:
        return 'followup';
      case NoteType.quote:
        return 'quote';
      case NoteType.issue:
        return 'issue';
    }
  }

  String get label {
    switch (this) {
      case NoteType.general:
        return 'General';
      case NoteType.call:
        return 'Call';
      case NoteType.meeting:
        return 'Meeting';
      case NoteType.followup:
        return 'Follow-up';
      case NoteType.quote:
        return 'Quote';
      case NoteType.issue:
        return 'Issue';
    }
  }

  IconData get icon {
    switch (this) {
      case NoteType.general:
        return Icons.sticky_note_2_outlined;
      case NoteType.call:
        return Icons.phone_outlined;
      case NoteType.meeting:
        return Icons.groups_outlined;
      case NoteType.followup:
        return Icons.replay_outlined;
      case NoteType.quote:
        return Icons.request_quote_outlined;
      case NoteType.issue:
        return Icons.warning_amber_outlined;
    }
  }

  Color get color {
    switch (this) {
      case NoteType.general:
        return const Color(0xFF6B7280);
      case NoteType.call:
        return const Color(0xFF3B82F6);
      case NoteType.meeting:
        return const Color(0xFF8B5CF6);
      case NoteType.followup:
        return const Color(0xFFF59E0B);
      case NoteType.quote:
        return const Color(0xFF10B981);
      case NoteType.issue:
        return const Color(0xFFEF4444);
    }
  }

  Color get bg => color.withValues(alpha: 0.08);

  static NoteType fromKey(String? key) {
    switch (key?.toLowerCase()) {
      case 'call':
        return NoteType.call;
      case 'meeting':
        return NoteType.meeting;
      case 'followup':
        return NoteType.followup;
      case 'quote':
        return NoteType.quote;
      case 'issue':
        return NoteType.issue;
      default:
        return NoteType.general;
    }
  }
}

// ─── Note Priority ───────────────────────────────────────────────────────────

enum NotePriority { low, medium, high }

extension NotePriorityX on NotePriority {
  String get key {
    switch (this) {
      case NotePriority.low:
        return 'low';
      case NotePriority.medium:
        return 'medium';
      case NotePriority.high:
        return 'high';
    }
  }

  String get label {
    switch (this) {
      case NotePriority.low:
        return 'Low';
      case NotePriority.medium:
        return 'Medium';
      case NotePriority.high:
        return 'High';
    }
  }

  Color get color {
    switch (this) {
      case NotePriority.low:
        return const Color(0xFF10B981);
      case NotePriority.medium:
        return const Color(0xFFF59E0B);
      case NotePriority.high:
        return const Color(0xFFEF4444);
    }
  }

  IconData get icon {
    switch (this) {
      case NotePriority.low:
        return Icons.arrow_downward_rounded;
      case NotePriority.medium:
        return Icons.remove_rounded;
      case NotePriority.high:
        return Icons.arrow_upward_rounded;
    }
  }

  static NotePriority fromKey(String? key) {
    switch (key?.toLowerCase()) {
      case 'low':
        return NotePriority.low;
      case 'high':
        return NotePriority.high;
      default:
        return NotePriority.medium;
    }
  }
}

// ─── Widget ──────────────────────────────────────────────────────────────────

class UserStatusNotesWidget extends StatefulWidget {
  final String userId;
  final String initialStatus;
  final String initialNotes;
  final bool isSubmitting;
  final Function(
    String status,
    String notes,
    String noteType,
    String notePriority,
  )
  onSave;
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

class _UserStatusNotesWidgetState extends State<UserStatusNotesWidget>
    with TickerProviderStateMixin {
  late String _selectedStatus;
  late final List<String> _statusOptions;

  late TextEditingController _notesController;
  final FocusNode _notesFocusNode = FocusNode();
  NoteType _selectedType = NoteType.general;
  NotePriority _selectedPriority = NotePriority.medium;
  bool _composerExpanded = false;

  late TextEditingController _searchController;
  PickerDateRange? _selectedDateRange;
  NoteType? _filterType;
  NotePriority? _filterPriority;
  String _sortOrder = 'newest';

  late AnimationController _composerAnim;
  late Animation<double> _composerFade;

  bool get _hasContent => _notesController.text.trim().isNotEmpty;
  bool get _statusChanged =>
      _selectedStatus != widget.initialStatus.toLowerCase();

  @override
  void initState() {
    super.initState();
    _statusOptions =
        widget.statusOptions ??
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
          'prospect',
        ];
    _selectedStatus = widget.initialStatus.toLowerCase();
    if (!_statusOptions.contains(_selectedStatus)) {
      _selectedStatus = _statusOptions.contains('prospect')
          ? 'prospect'
          : _statusOptions.first;
    }
    _notesController = TextEditingController();
    _notesController.addListener(() => setState(() {}));
    _searchController = TextEditingController();
    _searchController.addListener(() => setState(() {}));
    _composerAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _composerFade = CurvedAnimation(
      parent: _composerAnim,
      curve: Curves.easeInOut,
    );
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
      _notesController.clear();
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    _searchController.dispose();
    _notesFocusNode.dispose();
    _composerAnim.dispose();
    super.dispose();
  }

  void _save() {
    if (!_hasContent && !_statusChanged) return;
    _notesFocusNode.unfocus();
    widget.onSave(
      _selectedStatus,
      _notesController.text.trim(),
      _selectedType.key,
      _selectedPriority.key,
    );
    setState(() {
      _notesController.clear();
      _selectedType = NoteType.general;
      _selectedPriority = NotePriority.medium;
      _composerExpanded = false;
    });
    _composerAnim.reverse();
  }

  void _expandComposer() {
    if (_composerExpanded) return;
    setState(() => _composerExpanded = true);
    _composerAnim.forward();
  }

  void _showDatePicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                setState(() => _selectedDateRange = val);
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
        return 'Not Interested';
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

  String _relativeTime(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return dateStr;
    }
  }

  String _absoluteTime(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      return '${dt.day}/${dt.month}/${dt.year}  ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateStr;
    }
  }

  List<Map<String, dynamic>> get _filteredNotes {
    if (widget.notesHistory == null) return [];
    var notes = widget.notesHistory!.toList();
    if (_selectedDateRange?.startDate != null) {
      final start = _selectedDateRange!.startDate!;
      final end = _selectedDateRange!.endDate ?? start;
      final endOfRange = DateTime(end.year, end.month, end.day, 23, 59, 59);
      notes = notes.where((n) {
        try {
          final dt = DateTime.parse(n['createdAt'] ?? '').toLocal();
          return dt.isAfter(start) && dt.isBefore(endOfRange);
        } catch (_) {
          return false;
        }
      }).toList();
    }
    if (_filterType != null) {
      notes = notes
          .where((n) => (n['type'] ?? 'general') == _filterType!.key)
          .toList();
    }
    if (_filterPriority != null) {
      notes = notes
          .where((n) => (n['priority'] ?? 'medium') == _filterPriority!.key)
          .toList();
    }
    final q = _searchController.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      notes = notes.where((n) {
        final note = (n['note'] ?? '').toString().toLowerCase();
        final admin = (n['adminName'] ?? '').toString().toLowerCase();
        return note.contains(q) || admin.contains(q);
      }).toList();
    }
    notes.sort((a, b) {
      try {
        final da = DateTime.parse(a['createdAt'] ?? '');
        final db = DateTime.parse(b['createdAt'] ?? '');
        return _sortOrder == 'newest' ? db.compareTo(da) : da.compareTo(db);
      } catch (_) {
        return 0;
      }
    });
    return notes;
  }

  Map<String, dynamic> get _statsData {
    final history = widget.notesHistory ?? [];
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    int thisWeek = 0;
    DateTime? newestDt;
    Map<String, int> authorCount = {};
    for (final n in history) {
      try {
        final dt = DateTime.parse(n['createdAt'] ?? '').toLocal();
        if (dt.isAfter(weekStart)) thisWeek++;
        if (newestDt == null || dt.isAfter(newestDt)) {
          newestDt = dt;
        }
      } catch (_) {}
      final admin = n['adminName'] ?? '';
      if (admin.isNotEmpty) authorCount[admin] = (authorCount[admin] ?? 0) + 1;
    }
    String topAuthor = '';
    if (authorCount.isNotEmpty) {
      topAuthor = authorCount.entries
          .reduce((a, b) => a.value >= b.value ? a : b)
          .key;
    }
    return {
      'total': history.length,
      'thisWeek': thisWeek,
      'lastDate': newestDt == null
          ? '—'
          : _relativeTime(newestDt.toIso8601String()),
      'topAuthor': topAuthor.isEmpty ? '—' : topAuthor,
    };
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'lost':
        return const Color(0xFFEF4444);
      case 'intrested':
      case 'quotation sent':
      case 'negotiation':
        return const Color(0xFF10B981);
      case 'follow-up':
      case 'followup':
        return const Color(0xFFF59E0B);
      case 'kyc pending':
        return const Color(0xFF8B5CF6);
      case 'call not picked':
      case 'call switch off':
      case 'customer busy':
        return const Color(0xFF6B7280);
      case 'connected but not intrested':
        return const Color(0xFFF97316);
      default:
        return AppTheme.primaryColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final s = _statsData;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectionContainer.disabled(child: _buildStatsStrip(s, isMobile)),
        const SizedBox(height: 16),
        SelectionContainer.disabled(child: _buildComposerCard(isMobile)),
        const SizedBox(height: 20),
        if (widget.notesHistory != null && widget.notesHistory!.isNotEmpty)
          _buildHistorySection(isMobile),
      ],
    );
  }

  // ── Stats Strip ──────────────────────────────────────────────────────────

  Widget _buildStatsStrip(Map<String, dynamic> s, bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 14 : 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor.withValues(alpha: 0.08),
            AppTheme.primaryColor.withValues(alpha: 0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.15),
        ),
      ),
      child: isMobile
          ? Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _statItem(
                        Icons.notes_rounded,
                        'Total Notes',
                        '${s['total']}',
                        AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _statItem(
                        Icons.calendar_today_outlined,
                        'This Week',
                        '${s['thisWeek']}',
                        const Color(0xFF8B5CF6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _statItem(
                        Icons.access_time_rounded,
                        'Last Note',
                        s['lastDate'],
                        AppTheme.accentColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _statItem(
                        Icons.person_outline_rounded,
                        'Top Author',
                        s['topAuthor'],
                        const Color(0xFF3B82F6),
                      ),
                    ),
                  ],
                ),
              ],
            )
          : Row(
              children: [
                Expanded(
                  child: _statItem(
                    Icons.notes_rounded,
                    'Total Notes',
                    '${s['total']}',
                    AppTheme.primaryColor,
                  ),
                ),
                _statDivider(),
                Expanded(
                  child: _statItem(
                    Icons.calendar_today_outlined,
                    'This Week',
                    '${s['thisWeek']}',
                    const Color(0xFF8B5CF6),
                  ),
                ),
                _statDivider(),
                Expanded(
                  child: _statItem(
                    Icons.access_time_rounded,
                    'Last Note',
                    s['lastDate'],
                    AppTheme.accentColor,
                  ),
                ),
                _statDivider(),
                Expanded(
                  child: _statItem(
                    Icons.person_outline_rounded,
                    'Top Author',
                    s['topAuthor'],
                    const Color(0xFF3B82F6),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _statDivider() => Container(
    width: 1,
    height: 40,
    margin: const EdgeInsets.symmetric(horizontal: 4),
    color: AppTheme.primaryColor.withValues(alpha: 0.12),
  );

  Widget _statItem(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Composer Card ────────────────────────────────────────────────────────

  Widget _buildComposerCard(bool isMobile) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _composerExpanded
              ? AppTheme.primaryColor.withValues(alpha: 0.35)
              : AppTheme.borderColor,
        ),
        boxShadow: [
          BoxShadow(
            color: _composerExpanded
                ? AppTheme.primaryColor.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header - Dark Gradient
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E293B), Color(0xFF334155)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.edit_note_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  widget.title ?? 'Activity & Notes',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                if (_statusChanged)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.5),
                      ),
                    ),
                    child: Text(
                      'Status changed',
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFFCD34D),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          Padding(
            padding: EdgeInsets.all(isMobile ? 14 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status
                Row(
                  children: [
                    Icon(
                      Icons.circle,
                      size: 8,
                      color: _getStatusColor(_selectedStatus),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      widget.statusLabel ?? 'Status',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textSecondary,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(9),
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
                      items: _statusOptions
                          .map(
                            (status) => DropdownMenuItem<String>(
                              value: status,
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.circle,
                                    size: 8,
                                    color: _getStatusColor(status),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _formatStatusName(status),
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: widget.isSubmitting
                          ? null
                          : (val) {
                              if (val != null)
                                setState(() => _selectedStatus = val);
                            },
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Compose area
                GestureDetector(
                  onTap: _expandComposer,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeInOut,
                    decoration: BoxDecoration(
                      color: _composerExpanded
                          ? Colors.white
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _composerExpanded
                            ? AppTheme.primaryColor.withValues(alpha: 0.4)
                            : AppTheme.borderColor,
                        width: _composerExpanded ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        TextField(
                          controller: _notesController,
                          focusNode: _notesFocusNode,
                          maxLines: _composerExpanded ? 5 : 2,
                          minLines: _composerExpanded ? 5 : 2,
                          enabled: !widget.isSubmitting,
                          onTap: _expandComposer,
                          style: GoogleFonts.outfit(
                            fontSize: 13.5,
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w500,
                            height: 1.5,
                          ),
                          decoration: InputDecoration(
                            hintText:
                                widget.notesLabel ??
                                'Add a note — call summary, follow-up details, quote discussion... (@admin to mention)',
                            hintStyle: GoogleFonts.outfit(
                              fontSize: 13,
                              color: AppTheme.textSecondary.withValues(
                                alpha: 0.55,
                              ),
                              fontWeight: FontWeight.w400,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                          ),
                        ),
                        if (_composerExpanded)
                          Padding(
                            padding: const EdgeInsets.only(
                              right: 12,
                              bottom: 8,
                            ),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                '${_notesController.text.length} chars',
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  color: AppTheme.textSecondary.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // Type + Priority + Actions (animated)
                SizeTransition(
                  sizeFactor: _composerFade,
                  child: FadeTransition(
                    opacity: _composerFade,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),
                        Text(
                          'TYPE',
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textSecondary,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: NoteType.values.map((t) {
                            final selected = _selectedType == t;
                            return GestureDetector(
                              onTap: () => setState(() => _selectedType = t),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: selected ? t.color : t.bg,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: selected
                                        ? t.color
                                        : t.color.withValues(alpha: 0.25),
                                    width: selected ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      t.icon,
                                      size: 12,
                                      color: selected ? Colors.white : t.color,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      t.label,
                                      style: GoogleFonts.outfit(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: selected
                                            ? Colors.white
                                            : t.color,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Text(
                              'PRIORITY:',
                              style: GoogleFonts.outfit(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textSecondary,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(width: 8),
                            ...NotePriority.values.map((p) {
                              final selected = _selectedPriority == p;
                              return GestureDetector(
                                onTap: () =>
                                    setState(() => _selectedPriority = p),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  margin: const EdgeInsets.only(right: 6),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? p.color
                                        : p.color.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: selected
                                          ? p.color
                                          : p.color.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        p.icon,
                                        size: 11,
                                        color: selected
                                            ? Colors.white
                                            : p.color,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        p.label,
                                        style: GoogleFonts.outfit(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: selected
                                              ? Colors.white
                                              : p.color,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                            const Spacer(),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _composerExpanded = false;
                                  _notesController.clear();
                                  _selectedType = NoteType.general;
                                  _selectedPriority = NotePriority.medium;
                                });
                                _composerAnim.reverse();
                                _notesFocusNode.unfocus();
                              },
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                foregroundColor: AppTheme.textSecondary,
                              ),
                              child: Text(
                                'Cancel',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            AnimatedOpacity(
                              duration: const Duration(milliseconds: 200),
                              opacity: (_hasContent || _statusChanged)
                                  ? 1.0
                                  : 0.45,
                              child: ElevatedButton.icon(
                                onPressed:
                                    widget.isSubmitting ||
                                        (!_hasContent && !_statusChanged)
                                    ? null
                                    : _save,
                                icon: widget.isSubmitting
                                    ? const SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 1.5,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.send_rounded, size: 13),
                                label: Text(
                                  widget.isSubmitting
                                      ? 'Saving...'
                                      : 'Post Note',
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryColor,
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor: AppTheme.primaryColor
                                      .withValues(alpha: 0.6),
                                  disabledForegroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                if (!_composerExpanded && _statusChanged)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ElevatedButton.icon(
                          onPressed: widget.isSubmitting ? null : _save,
                          icon: const Icon(Icons.save_outlined, size: 13),
                          label: Text(
                            'Save Status',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── History Section ──────────────────────────────────────────────────────

  Widget _buildHistorySection(bool isMobile) {
    final filtered = _filteredNotes;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor),
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
          // Header
          SelectionContainer.disabled(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(14),
                ),
                border: Border(
                  bottom: BorderSide(
                    color: AppTheme.borderColor.withValues(alpha: 0.6),
                  ),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.history_rounded,
                        size: 16,
                        color: AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Activity Feed',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${widget.notesHistory!.length}',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => setState(
                          () => _sortOrder = _sortOrder == 'newest'
                              ? 'oldest'
                              : 'newest',
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.borderColor),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _sortOrder == 'newest'
                                    ? Icons.arrow_downward_rounded
                                    : Icons.arrow_upward_rounded,
                                size: 12,
                                color: AppTheme.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _sortOrder == 'newest' ? 'Newest' : 'Oldest',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (isMobile) ...[
                    Container(
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
                                hintText: 'Search notes...',
                                hintStyle: GoogleFonts.outfit(
                                  fontSize: 14,
                                  color: AppTheme.textSecondary.withValues(
                                    alpha: 0.7,
                                  ),
                                  fontWeight: FontWeight.w500,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                          if (_searchController.text.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => _searchController.clear(),
                              child: const Icon(
                                Icons.clear_rounded,
                                size: 18,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _filterChipBtn(
                            label: _filterType?.label ?? 'Type',
                            icon:
                                _filterType?.icon ??
                                Icons.label_outline_rounded,
                            color: _filterType?.color ?? AppTheme.textSecondary,
                            active: _filterType != null,
                            onTap: _showTypeFilterSheet,
                          ),
                          const SizedBox(width: 8),
                          _filterChipBtn(
                            label: _filterPriority?.label ?? 'Priority',
                            icon: _filterPriority?.icon ?? Icons.flag_outlined,
                            color:
                                _filterPriority?.color ??
                                AppTheme.textSecondary,
                            active: _filterPriority != null,
                            onTap: _showPriorityFilterSheet,
                          ),
                          const SizedBox(width: 8),
                          _filterChipBtn(
                            label: _selectedDateRange == null
                                ? 'Date'
                                : '${_selectedDateRange!.startDate!.day}/${_selectedDateRange!.startDate!.month}',
                            icon: Icons.calendar_month_outlined,
                            color: _selectedDateRange != null
                                ? AppTheme.primaryColor
                                : AppTheme.textSecondary,
                            active: _selectedDateRange != null,
                            onTap: _showDatePicker,
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
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
                                      hintText: 'Search notes...',
                                      hintStyle: GoogleFonts.outfit(
                                        fontSize: 14,
                                        color: AppTheme.textSecondary
                                            .withValues(alpha: 0.7),
                                        fontWeight: FontWeight.w500,
                                      ),
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                ),
                                if (_searchController.text.isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () => _searchController.clear(),
                                    child: const Icon(
                                      Icons.clear_rounded,
                                      size: 18,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _filterChipBtn(
                          label: _filterType?.label ?? 'Type',
                          icon:
                              _filterType?.icon ?? Icons.label_outline_rounded,
                          color: _filterType?.color ?? AppTheme.textSecondary,
                          active: _filterType != null,
                          onTap: _showTypeFilterSheet,
                        ),
                        const SizedBox(width: 6),
                        _filterChipBtn(
                          label: _filterPriority?.label ?? 'Priority',
                          icon: _filterPriority?.icon ?? Icons.flag_outlined,
                          color:
                              _filterPriority?.color ?? AppTheme.textSecondary,
                          active: _filterPriority != null,
                          onTap: _showPriorityFilterSheet,
                        ),
                        const SizedBox(width: 6),
                        _filterChipBtn(
                          label: _selectedDateRange == null
                              ? 'Date'
                              : '${_selectedDateRange!.startDate!.day}/${_selectedDateRange!.startDate!.month}',
                          icon: Icons.calendar_month_outlined,
                          color: _selectedDateRange != null
                              ? AppTheme.primaryColor
                              : AppTheme.textSecondary,
                          active: _selectedDateRange != null,
                          onTap: _showDatePicker,
                        ),
                      ],
                    ),
                  ],
                  if (_filterType != null ||
                      _filterPriority != null ||
                      _selectedDateRange != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          Text(
                            'Filters:',
                            style: GoogleFonts.outfit(
                              fontSize: 10.5,
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 6),
                          if (_filterType != null)
                            _activeBadge(
                              _filterType!.label,
                              _filterType!.color,
                              () => setState(() => _filterType = null),
                            ),
                          if (_filterPriority != null)
                            _activeBadge(
                              _filterPriority!.label,
                              _filterPriority!.color,
                              () => setState(() => _filterPriority = null),
                            ),
                          if (_selectedDateRange != null)
                            _activeBadge(
                              'Date range',
                              AppTheme.primaryColor,
                              () => setState(() => _selectedDateRange = null),
                            ),
                          const Spacer(),
                          GestureDetector(
                            onTap: () => setState(() {
                              _filterType = null;
                              _filterPriority = null;
                              _selectedDateRange = null;
                              _searchController.clear();
                            }),
                            child: Text(
                              'Clear all',
                              style: GoogleFonts.outfit(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Timeline
          if (filtered.isEmpty)
            _buildEmptyState()
          else
            Padding(
              padding: const EdgeInsets.all(16),
              child: SelectionArea(
                child: Column(
                  children: [
                    for (int i = 0; i < filtered.length; i++)
                      _buildTimelineItem(filtered[i], i, filtered.length),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _filterChipBtn({
    required String label,
    required IconData icon,
    required Color color,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? color.withValues(alpha: 0.5) : AppTheme.borderColor,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: active ? color : AppTheme.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: active ? color : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _activeBadge(String label, Color color, VoidCallback onRemove) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: Icon(Icons.close_rounded, size: 11, color: color),
          ),
        ],
      ),
    );
  }

  // ── Timeline Item ────────────────────────────────────────────────────────

  Widget _buildTimelineItem(Map<String, dynamic> item, int index, int total) {
    final String noteText = item['note'] ?? '';
    final String dateStr = item['createdAt'] ?? '';
    final String adminName = item['adminName'] ?? 'Admin';
    final NoteType type = NoteTypeX.fromKey(item['type']);
    final NotePriority priority = NotePriorityX.fromKey(item['priority']);
    final String? statusSnap = item['status'] ?? item['statusSnapshot'];
    final String relative = _relativeTime(dateStr);
    final String absolute = _absoluteTime(dateStr);
    final bool isLast = index == total - 1;

    final parts = adminName.trim().split(' ');
    final initials = parts.length >= 2
        ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
        : adminName.isNotEmpty
        ? adminName[0].toUpperCase()
        : 'A';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timeline spine
        SizedBox(
          width: 36,
          child: Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: type.color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: type.color.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Text(
                    initials,
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: type.color,
                    ),
                  ),
                ),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 60,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.borderColor,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 12),

        // Note card
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.borderColor.withValues(alpha: 0.7),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: Container(width: 4, color: priority.color),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                adminName,
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: type.bg,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(type.icon, size: 10, color: type.color),
                                  const SizedBox(width: 4),
                                  Text(
                                    type.label.toUpperCase(),
                                    style: GoogleFonts.outfit(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: type.color,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: priority.color.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    priority.icon,
                                    size: 10,
                                    color: priority.color,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    priority.label.toUpperCase(),
                                    style: GoogleFonts.outfit(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: priority.color,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _NoteText(text: noteText),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              size: 11,
                              color: AppTheme.textSecondary.withValues(
                                alpha: 0.6,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Tooltip(
                              message: absolute,
                              child: Text(
                                relative,
                                style: GoogleFonts.outfit(
                                  fontSize: 10.5,
                                  color: AppTheme.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            if (statusSnap != null &&
                                statusSnap.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Container(
                                width: 3,
                                height: 3,
                                decoration: BoxDecoration(
                                  color: AppTheme.textSecondary.withValues(
                                    alpha: 0.4,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.circle,
                                size: 7,
                                color: _getStatusColor(statusSnap),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _formatStatusName(statusSnap),
                                style: GoogleFonts.outfit(
                                  fontSize: 10.5,
                                  color: AppTheme.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                            const Spacer(),
                            GestureDetector(
                              onTap: () {
                                Clipboard.setData(
                                  ClipboardData(text: noteText),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Note copied to clipboard',
                                      style: GoogleFonts.outfit(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    behavior: SnackBarBehavior.floating,
                                    backgroundColor: AppTheme.primaryColor,
                                    duration: const Duration(seconds: 2),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    margin: const EdgeInsets.all(12),
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: AppTheme.borderColor.withValues(
                                    alpha: 0.2,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Icon(
                                  Icons.copy_rounded,
                                  size: 12,
                                  color: AppTheme.textSecondary.withValues(
                                    alpha: 0.7,
                                  ),
                                ),
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
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    final hasFilters =
        _filterType != null ||
        _filterPriority != null ||
        _selectedDateRange != null ||
        _searchController.text.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 24),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasFilters ? Icons.search_off_rounded : Icons.note_alt_outlined,
                size: 30,
                color: AppTheme.primaryColor.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              hasFilters ? 'No matches found' : 'No activity logged',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              hasFilters
                  ? 'Try broadening your search or resetting filters'
                  : 'Start the conversation by adding your first interaction note above.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: AppTheme.textSecondary,
                height: 1.4,
              ),
            ),
            if (hasFilters)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: TextButton(
                  onPressed: () => setState(() {
                    _filterType = null;
                    _filterPriority = null;
                    _selectedDateRange = null;
                    _searchController.clear();
                  }),
                  child: Text(
                    'Reset all filters',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showTypeFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filter by Activity Type',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _sheetChip(
                  'All Activities',
                  _filterType == null,
                  AppTheme.textSecondary,
                  () => setState(() {
                    _filterType = null;
                    Navigator.pop(context);
                  }),
                ),
                ...NoteType.values.map(
                  (t) => _sheetChip(
                    t.label,
                    _filterType == t,
                    t.color,
                    () => setState(() {
                      _filterType = t;
                      Navigator.pop(context);
                    }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showPriorityFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Filter by Priority',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                if (_filterPriority != null)
                  TextButton(
                    onPressed: () => setState(() {
                      _filterPriority = null;
                      Navigator.pop(context);
                    }),
                    child: const Text('Clear'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                ...NotePriority.values.map(
                  (p) => _sheetChip(
                    p.label,
                    _filterPriority == p,
                    p.color,
                    () => setState(() {
                      _filterPriority = p;
                      Navigator.pop(context);
                    }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _sheetChip(
    String label,
    bool selected,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : color.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: selected ? Colors.white : color,
          ),
        ),
      ),
    );
  }
}

// ─── Note Text (expand/collapse) ─────────────────────────────────────────────

class _NoteText extends StatefulWidget {
  final String text;
  const _NoteText({required this.text});
  @override
  State<_NoteText> createState() => _NoteTextState();
}

class _NoteTextState extends State<_NoteText> {
  bool _expanded = false;
  static const int _maxLines = 4;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.text,
          maxLines: _expanded ? null : _maxLines,
          overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
          style: GoogleFonts.outfit(
            fontSize: 13.5,
            color: AppTheme.textBody,
            height: 1.6,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (widget.text.length > 200)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _expanded ? 'Show less' : 'Read more',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 14,
                    color: AppTheme.primaryColor,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
