import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:kd_pannel/app_theme.dart';
import 'package:kd_pannel/core/network/websocket_service.dart';
import 'package:kd_pannel/core/responsive/responsive.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/audit_logs_bloc.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/audit_logs_event.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/audit_logs_state.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/leads_bloc.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/leads_state.dart';
import 'package:shimmer/shimmer.dart';

class AdminAuditLogsPage extends StatefulWidget {
  final String? roleFilter;
  const AdminAuditLogsPage({super.key, this.roleFilter});

  @override
  State<AdminAuditLogsPage> createState() => _AdminAuditLogsPageState();
}

class _AdminAuditLogsPageState extends State<AdminAuditLogsPage> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  StreamSubscription? _auditSubscription;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    
    // Listen for real-time audit log creations
    _auditSubscription = WebSocketService().auditLogUpdates.listen((log) {
      if (mounted) {
        context.read<AuditLogsBloc>().add(NewAuditLogReceived(log));
      }
    });
    
    // Ensure logs are loaded when page is mounted
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<AuditLogsBloc>().add(FetchAuditLogsInitial(role: widget.roleFilter, forceRefresh: true));
      }
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _auditSubscription?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_isBottom) {
      context.read<AuditLogsBloc>().add(FetchAuditLogsMore());
    }
  }

  bool get _isBottom {
    if (!_scrollController.hasClients) return false;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    return currentScroll >= (maxScroll * 0.9);
  }

  String _formatTimeAgo(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays == 1) return 'Yesterday';
      return '${diff.inDays}d ago';
    } catch (e) {
      return '-';
    }
  }

  String _getGroupHeader(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final dateToCheck = DateTime(dt.year, dt.month, dt.day);

      if (dateToCheck == today) return 'Today';
      if (dateToCheck == yesterday) return 'Yesterday';
      return DateFormat('MMMM d, yyyy').format(dt);
    } catch (_) {
      return 'Earlier';
    }
  }

  void _onSearchChanged(String val) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        context.read<AuditLogsBloc>().add(SearchAuditLogs(val));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: BlocConsumer<AuditLogsBloc, AuditLogsState>(
        listener: (context, state) {
          if (state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.errorMessage!), backgroundColor: AppTheme.error),
            );
            context.read<AuditLogsBloc>().add(ClearAuditLogsMessage());
          }
        },
        builder: (context, state) {
          return Padding(
            padding: EdgeInsets.all(isDesktop ? 24 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context, state),
                const SizedBox(height: 20),
                _buildSearchAndFilters(context, state, isDesktop),
                const SizedBox(height: 12),
                _buildActionAndModuleChips(state),
                const SizedBox(height: 16),
                Expanded(
                  child: _buildLogsList(context, state, state.logs),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AuditLogsState state) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  widget.roleFilter == 'sales' ? 'Sales Audit Trail' : 'Admin Audit Trail',
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(width: 10),
                const _LivePulsingBadge(color: AppTheme.success),
                const SizedBox(width: 6),
                Text(
                  'LIVE MONITOR',
                  style: GoogleFonts.outfit(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.success,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
            Text(
              widget.roleFilter == 'sales' 
                ? 'Security ledger of all sales agent data modifications.'
                : 'Security ledger of all administrative data modifications.',
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        Row(
          children: [
            if (state.status == AuditLogsStatus.loadingMore || state.status == AuditLogsStatus.loading)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor),
              ),
            const SizedBox(width: 12),
            IconButton(
              onPressed: () => context.read<AuditLogsBloc>().add(const FetchAuditLogsInitial(forceRefresh: true)),
              icon: const Icon(Icons.refresh_rounded, color: AppTheme.primaryColor, size: 22),
              tooltip: 'Refresh Ledger',
              style: IconButton.styleFrom(
                backgroundColor: AppTheme.primaryColor.withOpacity(0.05),
                padding: const EdgeInsets.all(8),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchAndFilters(BuildContext context, AuditLogsState state, bool isDesktop) {
    final searchBar = Container(
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: AppTheme.textSecondary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                hintText: 'Search by admin, action, target or changes...',
                border: InputBorder.none,
                hintStyle: GoogleFonts.outfit(fontSize: 13, color: AppTheme.textSecondary.withValues(alpha: 0.6)),
                isDense: true,
              ),
            ),
          ),
          if (state.searchQuery.isNotEmpty)
            GestureDetector(
              onTap: () {
                _searchController.clear();
                context.read<AuditLogsBloc>().add(const SearchAuditLogs(''));
              },
              child: const Icon(Icons.close_rounded, size: 16, color: AppTheme.textSecondary),
            ),
        ],
      ),
    );

    final dateRangeButton = _buildDateRangeButton(context, state);

    if (isDesktop) {
      return Row(
        children: [
          Expanded(child: searchBar),
          const SizedBox(width: 12),
          dateRangeButton,
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          searchBar,
          const SizedBox(height: 12),
          SizedBox(
            height: 44,
            child: dateRangeButton,
          ),
        ],
      );
    }
  }

  Widget _buildDateRangeButton(BuildContext context, AuditLogsState state) {
    final bool hasRange = state.selectedDateRange != null;
    final String label = hasRange
        ? '${DateFormat('dd MMM').format(state.selectedDateRange!.start)} - ${DateFormat('dd MMM').format(state.selectedDateRange!.end)}'
        : 'Select Date Range';

    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: hasRange ? AppTheme.primaryColor.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: hasRange ? AppTheme.primaryColor : AppTheme.borderColor.withValues(alpha: 0.8),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            final picked = await showDateRangePicker(
              context: context,
              firstDate: DateTime(2025),
              lastDate: DateTime.now().add(const Duration(days: 1)),
              initialDateRange: state.selectedDateRange,
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: const ColorScheme.light(
                      primary: AppTheme.primaryColor,
                      onPrimary: Colors.white,
                      onSurface: AppTheme.textPrimary,
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (picked != null) {
              context.read<AuditLogsBloc>().add(ChangeAuditLogsFilters(
                selectedDateRange: () => picked,
              ));
            }
          },
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.calendar_month_rounded,
                  size: 18,
                  color: hasRange ? AppTheme.primaryColor : AppTheme.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: hasRange ? AppTheme.primaryColor : AppTheme.textPrimary,
                  ),
                ),
                if (hasRange) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      context.read<AuditLogsBloc>().add(ChangeAuditLogsFilters(
                        selectedDateRange: () => null,
                      ));
                    },
                    child: const Icon(
                      Icons.cancel_rounded,
                      size: 16,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionAndModuleChips(AuditLogsState state) {
    final actions = ['All', 'Create', 'Update', 'Delete', 'Security'];
    final modules = ['All', 'Order', 'Product', 'User', 'KYC'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.5)),
      ),
      child: BlocBuilder<LeadsBloc, LeadsState>(
        builder: (context, leadsState) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            child: Row(
              children: [
                _buildLabel('Action'),
                const SizedBox(width: 10),
                ...actions.map((f) => _buildFilterChip(
                  label: f,
                  isSelected: state.actionFilter == f,
                  onSelected: (selected) {
                    context.read<AuditLogsBloc>().add(ChangeAuditLogsFilters(
                      actionFilter: f,
                    ));
                  },
                )),
                const SizedBox(width: 16),
                Container(width: 1, height: 24, color: AppTheme.borderColor.withValues(alpha: 0.5)),
                const SizedBox(width: 16),
                _buildLabel('Module'),
                const SizedBox(width: 10),
                ...modules.map((f) => _buildFilterChip(
                  label: f,
                  isSelected: state.moduleFilter == f,
                  onSelected: (selected) {
                    context.read<AuditLogsBloc>().add(ChangeAuditLogsFilters(
                      moduleFilter: f,
                    ));
                  },
                )),
                if (widget.roleFilter == 'sales' && leadsState.salesAgents.isNotEmpty) ...[
                  const SizedBox(width: 16),
                  Container(width: 1, height: 24, color: AppTheme.borderColor.withValues(alpha: 0.5)),
                  const SizedBox(width: 16),
                  _buildLabel('Agent'),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 250,
                    child: Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.3)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: state.agentEmail,
                          icon: const Icon(Icons.unfold_more_rounded, size: 16, color: AppTheme.textSecondary),
                          isExpanded: true,
                          elevation: 2,
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                          dropdownColor: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              context.read<AuditLogsBloc>().add(ChangeAuditLogsFilters(
                                agentEmail: newValue,
                              ));
                            }
                          },
                          items: [
                            const DropdownMenuItem(
                              value: 'All',
                              child: Text('All Registered Agents'),
                            ),
                            ...leadsState.salesAgents.map((agent) {
                              final email = agent['email'] ?? '';
                              final name = '${agent['firstName'] ?? ''} ${agent['lastName'] ?? ''}'.trim();
                              final displayName = name.isNotEmpty ? name : email;
                              return DropdownMenuItem(
                                value: email,
                                child: Text(displayName),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (state.agentEmail != 'All') ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        context.read<AuditLogsBloc>().add(const ChangeAuditLogsFilters(
                          agentEmail: 'All',
                        ));
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppTheme.error.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close_rounded, size: 14, color: AppTheme.error),
                      ),
                    ),
                  ],
                ],
                if (state.actionFilter != 'All' || state.moduleFilter != 'All' || state.agentEmail != 'All' || state.selectedDateRange != null || state.searchQuery.isNotEmpty) ...[
                  const SizedBox(width: 16),
                  TextButton.icon(
                    onPressed: () {
                      _searchController.clear();
                      context.read<AuditLogsBloc>().add(ChangeAuditLogsFilters(
                        actionFilter: 'All',
                        moduleFilter: 'All',
                        agentEmail: 'All',
                        selectedDateRange: () => null,
                        searchQuery: '',
                      ));
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 14, color: AppTheme.error),
                    label: Text(
                      'Reset All',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.error,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      backgroundColor: AppTheme.error.withValues(alpha: 0.05),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
                const SizedBox(width: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.outfit(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: AppTheme.textSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required Function(bool) onSelected,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: onSelected,
        selectedColor: AppTheme.primaryColor,
        backgroundColor: const Color(0xFFF8FAFC),
        labelStyle: GoogleFonts.outfit(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isSelected ? Colors.white : AppTheme.textSecondary,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        showCheckmark: false,
      ),
    );
  }

  Widget _buildLogsList(BuildContext context, AuditLogsState state, List<Map<String, dynamic>> filteredLogs) {
    if (state.status == AuditLogsStatus.loading && state.logs.isEmpty) {
      return _buildShimmerLogs();
    }

    if (state.logs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_toggle_off_rounded, size: 48, color: AppTheme.textSecondary.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text('No audit entries found.', style: GoogleFonts.outfit(color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    if (filteredLogs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.filter_list_off_rounded, size: 48, color: AppTheme.textSecondary.withOpacity(0.2)),
            const SizedBox(height: 16),
            Text(
              'No ${widget.roleFilter ?? "matching"} activity logs found.',
              style: GoogleFonts.outfit(color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Try switching tabs or adjusting your search.',
              style: GoogleFonts.outfit(color: AppTheme.textSecondary.withOpacity(0.7), fontSize: 12),
            ),
          ],
        ),
      );
    }

    // Group logs by date
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var log in filteredLogs) {
      final header = _getGroupHeader(log['timestamp'] ?? '');
      if (!grouped.containsKey(header)) grouped[header] = [];
      grouped[header]!.add(log);
    }

    final List<String> groupHeaders = grouped.keys.toList();

    return ListView.builder(
      controller: _scrollController,
      itemCount: groupHeaders.length + (state.hasReachedMax ? 0 : 1),
      padding: const EdgeInsets.only(top: 8, bottom: 60),
      itemBuilder: (context, index) {
        if (index >= groupHeaders.length) {
          if (state.hasReachedMax) return const SizedBox.shrink();
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: state.status == AuditLogsStatus.loadingMore
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor),
                  )
                : OutlinedButton.icon(
                    onPressed: () => context.read<AuditLogsBloc>().add(FetchAuditLogsMore()),
                    icon: const Icon(Icons.arrow_downward_rounded, size: 14),
                    label: Text(
                      'Load More History',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                      side: const BorderSide(color: AppTheme.primaryColor),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                  ),
            ),
          );
        }

        final header = groupHeaders[index];
        final logsInGroup = grouped[header]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 16,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    header.toUpperCase(),
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.textSecondary.withValues(alpha: 0.6),
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Divider(color: AppTheme.borderColor.withValues(alpha: 0.3))),
                ],
              ),
            ),
            ...logsInGroup.map((log) => _AuditLogRow(
              log: log, 
              onTap: () => _showLogDetails(context, log),
              timeAgo: _formatTimeAgo(log['timestamp'] ?? ''),
            )),
          ],
        );
      },
    );
  }

  TextStyle get _headerStyle => GoogleFonts.outfit(
    fontSize: 10,
    fontWeight: FontWeight.w800,
    color: AppTheme.textSecondary.withOpacity(0.7),
    letterSpacing: 1.0,
  );

  void _showLogDetails(BuildContext context, Map<String, dynamic> log) {
    showDialog(
      context: context,
      builder: (context) => _LogDetailDialog(log: log),
    );
  }

  Widget _buildShimmerLogs() {
    return ListView.builder(
      itemCount: 10,
      padding: const EdgeInsets.only(top: 8),
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Shimmer.fromColors(
                baseColor: Colors.grey[200]!,
                highlightColor: Colors.white,
                child: Container(width: 32, height: 32, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Shimmer.fromColors(
                      baseColor: Colors.grey[200]!,
                      highlightColor: Colors.white,
                      child: Container(width: 140, height: 14, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
                    ),
                    const SizedBox(height: 6),
                    Shimmer.fromColors(
                      baseColor: Colors.grey[200]!,
                      highlightColor: Colors.white,
                      child: Container(width: 100, height: 10, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Shimmer.fromColors(
                  baseColor: Colors.grey[200]!,
                  highlightColor: Colors.white,
                  child: Container(width: 120, height: 12, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
                ),
              ),
              Expanded(
                flex: 1,
                child: Shimmer.fromColors(
                  baseColor: Colors.grey[200]!,
                  highlightColor: Colors.white,
                  child: Container(width: 60, height: 10, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AuditLogRow extends StatelessWidget {
  final Map<String, dynamic> log;
  final VoidCallback onTap;
  final String timeAgo;

  const _AuditLogRow({required this.log, required this.onTap, required this.timeAgo});

  @override
  Widget build(BuildContext context) {
    final String action = (log['action'] ?? 'UNKNOWN').toString();
    final String targetModel = (log['targetModel'] ?? 'System').toString();
    final String email = (log['adminEmail'] ?? 'System').toString();
    final String? role = log['adminRole'] ?? log['role'];
    
    final Color color = _getActionColor(action);
    final IconData icon = _getActionIcon(action);

    // Extract target identifier (Name, Phone, Email, etc.)
    String targetIdentifier = '';
    final changes = log['changes'];
    if (changes != null && changes is Map) {
      final data = changes['after'] ?? changes['before'];
      if (data != null && data is Map) {
        final name = data['name'];
        final firstName = data['firstName'];
        final lastName = data['lastName'];
        final shopName = data['shopName'];
        final email = data['email'];
        final phoneNumber = data['phoneNumber'] ?? data['phone'];
        final title = data['title'];

        String fullName = '';
        if (name != null && name.toString().isNotEmpty) {
          fullName = name.toString();
        } else if ((firstName != null && firstName.toString().isNotEmpty) || (lastName != null && lastName.toString().isNotEmpty)) {
          fullName = '${firstName ?? ''} ${lastName ?? ''}'.trim();
        }

        if (fullName.isNotEmpty) {
          targetIdentifier = fullName;
        } else if (shopName != null && shopName.toString().isNotEmpty) {
          targetIdentifier = shopName.toString();
        } else if (phoneNumber != null && phoneNumber.toString().isNotEmpty) {
          targetIdentifier = phoneNumber.toString();
        } else if (email != null && email.toString().isNotEmpty) {
          targetIdentifier = email.toString();
        } else if (title != null && title.toString().isNotEmpty) {
          targetIdentifier = title.toString();
        }
      }
    }
    final String displayTarget = targetIdentifier.isNotEmpty ? '$targetModel: $targetIdentifier' : targetModel;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline Node (Left side)
          SizedBox(
            width: 48,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                // Line connecting nodes
                Positioned(
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 2,
                    color: Colors.grey.shade200,
                  ),
                ),
                // Glowing Node Circle
                Positioned(
                  top: 14,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: color, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.15),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Log Card (Right side)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12, right: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade100),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onTap,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          // Action Icon & Details
                          Expanded(
                            flex: 3,
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: color.withValues(alpha: 0.1), width: 1),
                                  ),
                                  child: Icon(icon, color: color, size: 18),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _formatActionText(action),
                                        style: GoogleFonts.outfit(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF1F5F9),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              displayTarget.toUpperCase(),
                                              style: GoogleFonts.outfit(
                                                fontSize: 9,
                                                fontWeight: FontWeight.w800,
                                                color: AppTheme.textSecondary,
                                                letterSpacing: 0.5,
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
                          
                          // Performed By Email
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  email,
                                  style: GoogleFonts.outfit(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (role != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    role.toUpperCase(),
                                    style: GoogleFonts.outfit(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: role.toLowerCase() == 'admin' ? AppTheme.primaryColor : Colors.orange,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          
                          // Time
                          Text(
                            timeAgo,
                            style: GoogleFonts.outfit(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.chevron_right_rounded, size: 20, color: AppTheme.textSecondary.withValues(alpha: 0.3)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatActionText(String action) {
    return action.split('_').map((word) {
      if (word.isEmpty) return "";
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  IconData _getActionIcon(String action) {
    action = action.toLowerCase();
    if (action.contains('delete') || action.contains('remove')) return Icons.delete_forever_rounded;
    if (action.contains('create') || action.contains('add')) return Icons.add_task_rounded;
    if (action.contains('update') || action.contains('edit')) return Icons.app_registration_rounded;
    if (action.contains('login')) return Icons.login_rounded;
    if (action.contains('security')) return Icons.security_rounded;
    return Icons.radio_button_checked_rounded;
  }

  Color _getActionColor(String action) {
    action = action.toLowerCase();
    if (action.contains('delete') || action.contains('remove')) return AppTheme.error;
    if (action.contains('create') || action.contains('add')) return AppTheme.success;
    if (action.contains('update') || action.contains('edit')) return AppTheme.warning;
    return AppTheme.info;
  }
}

class _LogDetailDialog extends StatelessWidget {
  final Map<String, dynamic> log;
  const _LogDetailDialog({required this.log});

  @override
  Widget build(BuildContext context) {
    final String action = (log['action'] ?? 'UNKNOWN').toString();
    final String target = (log['targetModel'] ?? 'System').toString();
    final String email = (log['adminEmail'] ?? 'System').toString();
    final String? role = log['adminRole'] ?? log['role'];
    final Color actionColor = _getActionColor(action);

    // Extract target identifier (Name, Phone, Email, etc.)
    String targetIdentifier = '';
    final changes = log['changes'];
    if (changes != null && changes is Map) {
      final data = changes['after'] ?? changes['before'];
      if (data != null && data is Map) {
        final name = data['name'];
        final firstName = data['firstName'];
        final lastName = data['lastName'];
        final shopName = data['shopName'];
        final email = data['email'];
        final phoneNumber = data['phoneNumber'] ?? data['phone'];
        final title = data['title'];

        String fullName = '';
        if (name != null && name.toString().isNotEmpty) {
          fullName = name.toString();
        } else if ((firstName != null && firstName.toString().isNotEmpty) || (lastName != null && lastName.toString().isNotEmpty)) {
          fullName = '${firstName ?? ''} ${lastName ?? ''}'.trim();
        }

        if (fullName.isNotEmpty) {
          targetIdentifier = fullName;
        } else if (shopName != null && shopName.toString().isNotEmpty) {
          targetIdentifier = shopName.toString();
        } else if (phoneNumber != null && phoneNumber.toString().isNotEmpty) {
          targetIdentifier = phoneNumber.toString();
        } else if (email != null && email.toString().isNotEmpty) {
          targetIdentifier = email.toString();
        } else if (title != null && title.toString().isNotEmpty) {
          targetIdentifier = title.toString();
        }
      }
    }

    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: EdgeInsets.zero,
      title: Container(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
        decoration: BoxDecoration(
          color: actionColor.withValues(alpha: 0.04),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(bottom: BorderSide(color: AppTheme.borderColor.withValues(alpha: 0.5))),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: actionColor.withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: Icon(_getActionIcon(action), color: actionColor, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            _formatActionText(action),
                            style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                          ),
                          const SizedBox(width: 8),
                          if (role != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: (role.toLowerCase() == 'admin' ? AppTheme.primaryColor : Colors.orange).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                role.toUpperCase(),
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: role.toLowerCase() == 'admin' ? AppTheme.primaryColor : Colors.orange,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _buildNarrativeSummary(email, action, target, targetIdentifier),
                        style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: AppTheme.textSecondary, size: 24),
                  style: IconButton.styleFrom(backgroundColor: Colors.white, elevation: 1),
                ),
              ],
            ),
          ],
        ),
      ),
      content: SizedBox(
        width: 700,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSectionTitle('LOG INFORMATION'),
              _buildMetaGrid(targetIdentifier),
              const SizedBox(height: 28),
              _buildChangesSection(),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  String _buildNarrativeSummary(String email, String action, String target, String targetId) {
    final actionText = _formatActionText(action).toLowerCase();
    final displayTarget = targetId.isNotEmpty ? '$target ($targetId)' : target;
    return '$email $actionText $displayTarget'.trim();
  }

  String _formatDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      return DateFormat('MMMM d, yyyy • hh:mm a').format(dt);
    } catch (_) {
      return dateStr;
    }
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title,
        style: GoogleFonts.outfit(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: AppTheme.textSecondary.withValues(alpha: 0.6),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildMetaGrid(String targetIdentifier) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.5)),
      ),
      child: Wrap(
        spacing: 32,
        runSpacing: 20,
        children: [
          _metaItem('Performed By', log['adminEmail'], Icons.person_rounded),
          if (targetIdentifier.isNotEmpty)
            _metaItem('Affected Entity', targetIdentifier, Icons.adjust_rounded),
          _metaItem('Resource Type', log['targetModel'], Icons.category_rounded),
          _metaItem('Resource ID', log['targetId'], Icons.fingerprint_rounded),
          _metaItem('Event Time', _formatDate(log['timestamp'] ?? ''), Icons.access_time_filled_rounded),
          _metaItem('Network IP', log['ipAddress'] ?? 'System Process', Icons.lan_rounded),
          _metaItem('User Agent', log['userAgent'] ?? 'N/A', Icons.devices_rounded),
        ],
      ),
    );
  }

  Widget _metaItem(String label, dynamic value, IconData icon) {
    return SizedBox(
      width: 180,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: AppTheme.textSecondary),
              const SizedBox(width: 4),
              Text(
                label.toUpperCase(),
                style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w800, color: AppTheme.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value?.toString() ?? '-',
            style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildChangesSection() {
    final changes = log['changes'];
    if (changes == null) return const SizedBox.shrink();

    final List<Widget> changeWidgets = [];
    
    // CASE 1: Update (Before and After exists)
    if (changes['before'] != null && changes['after'] != null) {
      try {
        final Map<String, dynamic> before = Map<String, dynamic>.from(changes['before'] as Map);
        final Map<String, dynamic> after = Map<String, dynamic>.from(changes['after'] as Map);
        
        final diff = _computeDiff(before, after);
        if (diff.isNotEmpty) {
          changeWidgets.add(_buildSectionTitle('MODIFICATIONS MADE'));
          changeWidgets.add(_buildDiffTable(diff));
        }
      } catch (_) {}
    } 
    // CASE 2: Create or Single State (Only After or Before exists)
    else if (changes['after'] != null || changes['before'] != null) {
      final Map<String, dynamic> data = Map<String, dynamic>.from((changes['after'] ?? changes['before']) as Map);
      final filteredData = _filterTechnicalKeys(data);
      
      if (filteredData.isNotEmpty) {
        changeWidgets.add(_buildSectionTitle(changes['after'] != null ? 'NEW ENTITY DETAILS' : 'DELETED ENTITY DATA'));
        changeWidgets.add(_buildFriendlyDataGrid(filteredData));
      }
    }

    if (changeWidgets.isEmpty) {
      changeWidgets.add(_buildSectionTitle('ADDITIONAL METADATA'));
      changeWidgets.add(_codeBlock(changes, AppTheme.primaryColor));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: changeWidgets);
  }

  Map<String, dynamic> _filterTechnicalKeys(Map<String, dynamic> data) {
    final Map<String, dynamic> filtered = {};
    final technicalKeys = {'updatedAt', 'createdAt', '__v', '_id', 'id', 'password', 'salt', 'fcmToken'};
    
    data.forEach((key, value) {
      if (!technicalKeys.contains(key) && value != null && value.toString().isNotEmpty) {
        filtered[key] = value;
      }
    });
    return filtered;
  }

  Widget _buildFriendlyDataGrid(Map<String, dynamic> data) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.6)),
      ),
      child: Wrap(
        spacing: 40,
        runSpacing: 20,
        children: data.entries.map((e) => _friendlyItem(e.key, e.value)).toList(),
      ),
    );
  }

  Widget _friendlyItem(String key, dynamic value) {
    final friendlyKey = key.replaceAll(RegExp(r'(?=[A-Z])'), ' ').trim().toUpperCase();
    String displayValue = value.toString();
    
    // Handle nested maps/lists briefly
    if (value is Map || value is List) {
      displayValue = 'Contains multiple items';
    }

    return SizedBox(
      width: 180,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            friendlyKey,
            style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w800, color: AppTheme.textSecondary.withValues(alpha: 0.6)),
          ),
          const SizedBox(height: 4),
          Text(
            displayValue,
            style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _computeDiff(Map<String, dynamic> before, Map<String, dynamic> after) {
    final Map<String, dynamic> diff = {};
    final keys = {...before.keys, ...after.keys};
    final technicalKeys = {'updatedAt', 'createdAt', '__v', '_id', 'id', 'password', 'fcmToken'};
    
    for (final key in keys) {
      if (technicalKeys.contains(key)) continue;
      
      final valBefore = before[key];
      final valAfter = after[key];
      
      if (valBefore.toString() != valAfter.toString()) {
        diff[key] = {'old': valBefore, 'new': valAfter};
      }
    }
    return diff;
  }

  Widget _buildDiffTable(Map<String, dynamic> diff) {
    return Column(
      children: diff.entries.map((entry) {
        final key = entry.key.replaceAll(RegExp(r'(?=[A-Z])'), ' ').trim().toUpperCase();
        final oldValue = entry.value['old'];
        final newValue = entry.value['new'];

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.01),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Diff Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.edit_note_rounded, size: 16, color: AppTheme.textSecondary),
                    const SizedBox(width: 8),
                    Text(
                      key,
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Diff Body (Before / After cards)
              Padding(
                padding: const EdgeInsets.all(16),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Old Value Card
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade100),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '- REMOVED',
                                      style: GoogleFonts.outfit(
                                        fontSize: 8,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.red.shade800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Expanded(
                                child: Text(
                                  oldValue?.toString() ?? '(Empty)',
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    color: Colors.red.shade900,
                                    fontWeight: FontWeight.w500,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      // Connector Arrow
                      Container(
                        width: 40,
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          color: AppTheme.primaryColor.withValues(alpha: 0.4),
                          size: 20,
                        ),
                      ),
                      
                      // New Value Card
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.shade100),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '+ ADDED',
                                      style: GoogleFonts.outfit(
                                        fontSize: 8,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.green.shade800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Expanded(
                                child: Text(
                                  newValue?.toString() ?? '(Removed)',
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    color: Colors.green.shade900,
                                    fontWeight: FontWeight.bold,
                                  ),
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
            ],
          ),
        );
      }).toList(),
    );
  }

  TextStyle get _diffLabelStyle => GoogleFonts.outfit(
    fontSize: 9,
    fontWeight: FontWeight.w800,
    color: AppTheme.textSecondary.withValues(alpha: 0.5),
    letterSpacing: 0.8,
  );

  Widget _codeBlock(dynamic data, Color accent) {
    String content = '';
    try {
      content = const JsonEncoder.withIndent('  ').convert(data);
    } catch (_) {
      content = data.toString();
    }

    return Container(
      padding: const EdgeInsets.all(12),
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: accent, width: 4)),
      ),
      child: Text(
        content,
        style: GoogleFonts.firaCode(fontSize: 10.5, color: const Color(0xFFE2E8F0), height: 1.4),
      ),
    );
  }

  String _formatActionText(String action) {
    return action.split('_').map((word) {
      if (word.isEmpty) return "";
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  IconData _getActionIcon(String action) {
    action = action.toLowerCase();
    if (action.contains('delete') || action.contains('remove')) return Icons.delete_forever_rounded;
    if (action.contains('create') || action.contains('add')) return Icons.add_task_rounded;
    if (action.contains('update') || action.contains('edit')) return Icons.app_registration_rounded;
    if (action.contains('login')) return Icons.login_rounded;
    if (action.contains('security')) return Icons.security_rounded;
    return Icons.radio_button_checked_rounded;
  }

  Color _getActionColor(String action) {
    action = action.toLowerCase();
    if (action.contains('delete') || action.contains('remove')) return AppTheme.error;
    if (action.contains('create') || action.contains('add')) return AppTheme.success;
    if (action.contains('update') || action.contains('edit')) return AppTheme.warning;
    return AppTheme.info;
  }
}

class _LivePulsingBadge extends StatefulWidget {
  final Color? color;
  const _LivePulsingBadge({this.color});

  @override
  State<_LivePulsingBadge> createState() => _LivePulsingBadgeState();
}

class _LivePulsingBadgeState extends State<_LivePulsingBadge> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _pulseAnimation = Tween<double>(begin: 1.0, end: 2.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final badgeColor = widget.color ?? AppTheme.warning;
    return SizedBox(
      width: 14,
      height: 14,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Container(
                width: 6 * _pulseAnimation.value,
                height: 6 * _pulseAnimation.value,
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: (1.0 - (_pulseController.value)).clamp(0.0, 1.0) * 0.5),
                  shape: BoxShape.circle,
                ),
              );
            },
          ),
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: badgeColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: badgeColor.withValues(alpha: 0.4),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
