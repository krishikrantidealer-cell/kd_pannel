import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:kd_pannel/app_theme.dart';
import 'package:kd_pannel/core/responsive/responsive.dart';
import 'package:kd_pannel/core/repositories/user_repository.dart';
import 'package:kd_pannel/core/utils/navigation_service.dart';
import 'package:intl/intl.dart';

import '../../../../core/services/analytics_service.dart';

class TrashPage extends StatefulWidget {
  const TrashPage({super.key});

  @override
  State<TrashPage> createState() => _TrashPageState();
}

class _TrashPageState extends State<TrashPage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounce;
  
  List<Map<String, dynamic>> _deletedUsers = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  int _page = 1;
  final int _limit = 20;
  bool _hasMore = true;
  int _totalCount = 0;
  String _selectedTab = 'Leads'; // 'Leads' or 'Dealers'
  String _searchQuery = '';
  int _currentRequestId = 0;
  DateTimeRange? _selectedDateRange;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _fetchTrashData(isFirstLoad: true);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_isBottom && !_isLoading && !_isLoadingMore && _hasMore) {
      _fetchTrashData(isFirstLoad: false);
    }
  }

  bool get _isBottom {
    if (!_scrollController.hasClients) return false;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    return currentScroll >= (maxScroll * 0.9);
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _searchQuery = query;
        });
        _fetchTrashData(isFirstLoad: true);
      }
    });
  }

  Future<void> _fetchTrashData({bool isFirstLoad = true}) async {
    final int requestId = ++_currentRequestId;

    if (isFirstLoad) {
      _debounce?.cancel();
      setState(() {
        _isLoading = true;
        _page = 1;
        _hasMore = true;
        _deletedUsers = [];
      });
    } else {
      setState(() {
        _isLoadingMore = true;
      });
    }

    try {
      final kycFilter = _selectedTab == 'Dealers' ? 'verified' : 'not_verified';

      String startDate = '';
      String endDate = '';
      if (_selectedDateRange != null) {
        startDate = DateFormat('yyyy-MM-dd').format(_selectedDateRange!.start);
        endDate = DateFormat('yyyy-MM-dd').format(_selectedDateRange!.end);
      }

      final data = await UserRepository().fetchTrashUsers(
        kycStatus: kycFilter,
        page: _page,
        limit: _limit,
        search: _searchQuery,
        startDate: startDate,
        endDate: endDate,
      );

      if (requestId != _currentRequestId || !mounted) return;

      final List<dynamic> usersList = data['users'] ?? [];
      setState(() {
        _totalCount = data['totalCount'] ?? 0;
        if (isFirstLoad) {
          _deletedUsers = List<Map<String, dynamic>>.from(usersList);
        } else {
          _deletedUsers.addAll(List<Map<String, dynamic>>.from(usersList));
        }
        _hasMore = data['hasMore'] ?? (usersList.length == _limit);
        if (usersList.isNotEmpty) {
          _page++;
        }
      });
    } catch (e) {
      if (requestId == _currentRequestId && mounted) {
        _showSnack(e.toString(), isError: true);
      }
    } finally {
      if (requestId == _currentRequestId && mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _restoreUser(String userId, String userName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Text(
          'Restore User?',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to restore "$userName"? They will be moved back to the active list.',
          style: GoogleFonts.outfit(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.outfit(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Restore', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final success = await UserRepository().restoreUser(userId);
        if (success) {
          AnalyticsService().logEvent('restore_user', properties: {
            'targetUserId': userId,
            'userName': userName,
            'details': 'Restored user account from trash: $userName',
          });
          _showSnack('"$userName" has been restored successfully!');
          _fetchTrashData(isFirstLoad: true);
        }
      } catch (e) {
        _showSnack(e.toString(), isError: true);
      }
    }
  }

  Future<void> _permanentlyDeleteUser(String userId, String userName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Text(
          'Permanently Delete?',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppTheme.error),
        ),
        content: Text(
          'Are you sure you want to permanently delete "$userName"? This action is irreversible, and all related carts, favourites, and notifications will be purged.',
          style: GoogleFonts.outfit(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.outfit(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Delete Permanently', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final success = await UserRepository().permanentlyDeleteUser(userId);
        if (success) {
          AnalyticsService().logEvent('permanent_delete_user', properties: {
            'targetUserId': userId,
            'userName': userName,
            'details': 'Permanently deleted user account: $userName',
          });
          _showSnack('"$userName" has been permanently deleted.');
          _fetchTrashData(isFirstLoad: true);
        }
      } catch (e) {
        _showSnack(e.toString(), isError: true);
      }
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    NavigationService.messengerKey.currentState?.showSnackBar(
      SnackBar(
        backgroundColor: isError ? AppTheme.error : AppTheme.success,
        behavior: SnackBarBehavior.floating,
        content: Text(
          message,
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
    );
  }

  String _cleanDeletedField(String? value) {
    if (value == null) return '-';
    if (value.contains('_deleted_')) {
      return value.split('_deleted_').first;
    }
    return value;
  }

  List<Map<String, dynamic>> get _filteredList {
    return _deletedUsers;
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = Responsive.isMobile(context);
    final items = _filteredList;

    return SelectionArea(
      child: RefreshIndicator(
        onRefresh: () => _fetchTrashData(isFirstLoad: true),
        color: AppTheme.primaryColor,
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: AppTheme.getResponsivePadding(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              isMobile
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTitle(),
                        const SizedBox(height: 16),
                        _buildSearchBar(),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: _buildTitle()),
                        const SizedBox(width: 24),
                        SizedBox(width: 320, child: _buildSearchBar()),
                      ],
                    ),
              const SizedBox(height: 24),

              // Tabs, Date Filter and count
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildSegmentButton('Leads', _selectedTab == 'Leads'),
                        _buildSegmentButton('Dealers', _selectedTab == 'Dealers'),
                      ],
                    ),
                  ),
                  _buildDateFilter(),
                  Text(
                    '$_totalCount item(s) in Trash',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Content Area
              _isLoading
                  ? _buildShimmerLoading(isMobile)
                  : items.isEmpty
                      ? _buildEmptyState()
                      : Column(
                          children: [
                            _buildTrashTable(items, isMobile),
                            if (_isLoadingMore)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 20),
                                child: Center(
                                  child: CircularProgressIndicator(color: AppTheme.primaryColor),
                                ),
                              ),
                          ],
                        ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: _selectedDateRange,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primaryColor,
              onPrimary: Colors.white,
              onSurface: AppTheme.textPrimary,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primaryColor,
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDateRange) {
      setState(() {
        _selectedDateRange = picked;
      });
      _fetchTrashData(isFirstLoad: true);
    }
  }

  Widget _buildDateFilter() {
    return InkWell(
      onTap: _selectDateRange,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _selectedDateRange != null ? AppTheme.primaryColor : Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: 16,
              color: _selectedDateRange != null ? AppTheme.primaryColor : AppTheme.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              _selectedDateRange == null
                  ? 'Filter by Date'
                  : '${DateFormat('dd MMM').format(_selectedDateRange!.start)} - ${DateFormat('dd MMM').format(_selectedDateRange!.end)}',
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: _selectedDateRange != null ? FontWeight.bold : FontWeight.w500,
                color: _selectedDateRange != null ? AppTheme.primaryColor : AppTheme.textSecondary,
              ),
            ),
            if (_selectedDateRange != null) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedDateRange = null;
                  });
                  _fetchTrashData(isFirstLoad: true);
                },
                child: const Icon(Icons.close_rounded, size: 16, color: AppTheme.primaryColor),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Trash Bin',
          style: GoogleFonts.outfit(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Manage soft-deleted Leads and Dealers. Restore them or delete them permanently.',
          style: GoogleFonts.outfit(
            fontSize: 13,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        style: GoogleFonts.outfit(fontSize: 14, color: AppTheme.textPrimary),
        decoration: InputDecoration(
          hintText: 'Search by name, phone or email...',
          hintStyle: GoogleFonts.outfit(fontSize: 13, color: AppTheme.textSecondary),
          prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppTheme.textSecondary),
          suffixIcon: _searchController.text.isNotEmpty
              ? GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                    _fetchTrashData(isFirstLoad: true);
                  },
                  child: const Icon(Icons.clear_rounded, size: 18, color: AppTheme.textSecondary),
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppTheme.primaryColor),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildSegmentButton(String tabName, bool isActive) {
    return InkWell(
      onTap: () {
        if (!isActive) {
          setState(() {
            _selectedTab = tabName;
          });
          _fetchTrashData(isFirstLoad: true);
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          tabName,
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            color: isActive ? AppTheme.primaryColor : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 80.0, horizontal: 24.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.delete_sweep_rounded, size: 48, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 16),
          Text(
            'Trash is Empty',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _searchQuery.isNotEmpty
                ? 'No deleted $_selectedTab match your search query.'
                : 'Great! There are no deleted $_selectedTab in the Trash bin.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 13,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrashTable(List<Map<String, dynamic>> items, bool isMobile) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.01),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: isMobile ? _buildMobileList(items) : _buildDesktopTable(items),
      ),
    );
  }

  Widget _buildDesktopTable(List<Map<String, dynamic>> items) {
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(3), // Name
        1: FlexColumnWidth(2), // Phone
        2: FlexColumnWidth(3), // Deleted By
        3: FlexColumnWidth(2.5), // Deleted Date
        4: FlexColumnWidth(2), // Actions
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        // Table Header
        TableRow(
          decoration: BoxDecoration(color: Colors.grey.shade50),
          children: [
            _buildTableHeaderCell('Name'),
            _buildTableHeaderCell('Phone'),
            _buildTableHeaderCell('Deleted By'),
            _buildTableHeaderCell('Deleted Date'),
            _buildTableHeaderCell('Actions', alignRight: true),
          ],
        ),
        // Table Rows
        ...items.map((u) {
          final String name = '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'.trim();
          final String displayName = name.isEmpty ? 'Unknown User' : name;
          final String displayPhoneStr = _cleanDeletedField(u['phoneNumber']);
          
          // Fallback logic for deletedBy: field -> assignedAgent -> '-'
          String deletedBy = u['deletedByAdminName'] ?? '';
          if (deletedBy.isEmpty && u['assignedAgent'] != null) {
            final agent = u['assignedAgent'];
            deletedBy = '${agent['firstName'] ?? ''} ${agent['lastName'] ?? ''}'.trim();
          }
          if (deletedBy.isEmpty) deletedBy = '-';

          final String deletedDateStr = u['deletedAt'] != null
              ? DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(u['deletedAt']).toLocal())
              : '-';

          return TableRow(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
            ),
            children: [
              _buildTableCell(
                GestureDetector(
                  onTap: () => _showTrashUserDetail(u),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Text(
                      displayName,
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryColor,
                        decoration: TextDecoration.underline,
                        decorationColor: AppTheme.primaryColor.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
              ),
              _buildTableCell(Text(displayPhoneStr, style: GoogleFonts.outfit(color: AppTheme.textPrimary))),
              _buildTableCell(
                Text(
                  deletedBy,
                  style: GoogleFonts.outfit(color: AppTheme.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _buildTableCell(Text(deletedDateStr, style: GoogleFonts.outfit(color: AppTheme.textSecondary))),
              _buildActionCell(u, displayName),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildMobileList(List<Map<String, dynamic>> items) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (context, index) => Divider(color: Colors.grey.shade100, height: 1),
      itemBuilder: (context, index) {
        final u = items[index];
        final String name = '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'.trim();
        final String displayName = name.isEmpty ? 'Unknown User' : name;
        final String displayPhoneStr = _cleanDeletedField(u['phoneNumber']);
        
        String deletedByMobile = u['deletedByAdminName'] ?? '';
        if (deletedByMobile.isEmpty && u['assignedAgent'] != null) {
          final agent = u['assignedAgent'];
          deletedByMobile = '${agent['firstName'] ?? ''} ${agent['lastName'] ?? ''}'.trim();
        }

        final String deletedDateStr = u['deletedAt'] != null
            ? DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(u['deletedAt']).toLocal())
            : '-';

        return GestureDetector(
          onTap: () => _showTrashUserDetail(u),
          child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      displayName,
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppTheme.primaryColor,
                        decoration: TextDecoration.underline,
                        decorationColor: AppTheme.primaryColor.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.restore_rounded, color: AppTheme.primaryColor),
                        tooltip: 'Restore',
                        onPressed: () => _restoreUser(u['_id'], displayName),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_forever_rounded, color: AppTheme.error),
                        tooltip: 'Delete Permanently',
                        onPressed: () => _permanentlyDeleteUser(u['_id'], displayName),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Phone: $displayPhoneStr',
                style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.textPrimary),
              ),
              if (deletedByMobile.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  'Deleted By: $deletedByMobile',
                  style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.textSecondary),
                ),
              ],
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.calendar_today_rounded, size: 12, color: Colors.grey.shade400),
                  const SizedBox(width: 4),
                  Text(
                    'Deleted: $deletedDateStr',
                    style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ],
          ),
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // SHIMMER SKELETON LOADING
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildShimmerLoading(bool isMobile) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.01),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Shimmer.fromColors(
          baseColor: Colors.grey.shade200,
          highlightColor: Colors.grey.shade50,
          child: isMobile
              ? _buildMobileShimmerList()
              : _buildDesktopShimmerTable(),
        ),
      ),
    );
  }

  Widget _buildDesktopShimmerTable() {
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(3), // Name
        1: FlexColumnWidth(2), // Phone
        2: FlexColumnWidth(3), // Deleted By
        3: FlexColumnWidth(2.5), // Deleted Date
        4: FlexColumnWidth(2), // Actions
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(
          decoration: BoxDecoration(color: Colors.grey.shade50),
          children: [
            _buildTableHeaderCell('Name'),
            _buildTableHeaderCell('Phone'),
            _buildTableHeaderCell('Deleted By'),
            _buildTableHeaderCell('Deleted Date'),
            _buildTableHeaderCell('Actions', alignRight: true),
          ],
        ),
        ...List.generate(7, (index) {
          return TableRow(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
            ),
            children: [
              _buildTableCell(
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      height: 14,
                      width: 110,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
              _buildTableCell(
                Container(
                  height: 14,
                  width: 90,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              _buildTableCell(
                Container(
                  height: 14,
                  width: 100,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              _buildTableCell(
                Container(
                  height: 14,
                  width: 120,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              _buildTableCell(
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildMobileShimmerList() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 6,
      separatorBuilder: (context, index) =>
          Divider(color: Colors.grey.shade100, height: 1),
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 15,
                          width: 140,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          height: 12,
                          width: 100,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    height: 11,
                    width: 110,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  Container(
                    height: 11,
                    width: 120,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // TRASH USER DETAIL BOTTOM SHEET
  // ─────────────────────────────────────────────────────────────────────────────

  Future<void> _showTrashUserDetail(Map<String, dynamic> userData) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _TrashUserDetailSheet(
        userData: userData,
        cleanDeletedField: _cleanDeletedField,
        onRestore: () {
          Navigator.pop(ctx);
          final name = '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'.trim();
          _restoreUser(userData['_id'], name.isEmpty ? 'Unknown User' : name);
        },
        onPurge: () {
          Navigator.pop(ctx);
          final name = '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'.trim();
          _permanentlyDeleteUser(userData['_id'], name.isEmpty ? 'Unknown User' : name);
        },
      ),
    );
  }

  Widget _buildTableHeaderCell(String label, {bool alignRight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: Align(
        alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildTableCell(Widget child) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: child,
    );
  }

  Widget _buildActionCell(Map<String, dynamic> u, String displayName) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Tooltip(
            message: 'Restore User',
            child: ElevatedButton.icon(
              onPressed: () => _restoreUser(u['_id'], displayName),
              icon: const Icon(Icons.restore_rounded, size: 14),
              label: Text('Restore', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                foregroundColor: AppTheme.primaryColor,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Tooltip(
            message: 'Permanently Delete',
            child: ElevatedButton.icon(
              onPressed: () => _permanentlyDeleteUser(u['_id'], displayName),
              icon: const Icon(Icons.delete_forever_rounded, size: 14),
              label: Text('Purge', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.error.withValues(alpha: 0.1),
                foregroundColor: AppTheme.error,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TRASH USER DETAIL SHEET
// ─────────────────────────────────────────────────────────────────────────────

class _TrashUserDetailSheet extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String Function(String?) cleanDeletedField;
  final VoidCallback onRestore;
  final VoidCallback onPurge;

  const _TrashUserDetailSheet({
    required this.userData,
    required this.cleanDeletedField,
    required this.onRestore,
    required this.onPurge,
  });

  @override
  State<_TrashUserDetailSheet> createState() => _TrashUserDetailSheetState();
}

class _TrashUserDetailSheetState extends State<_TrashUserDetailSheet> {
  List<Map<String, dynamic>> _auditLogs = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchActivity();
  }

  Future<void> _fetchActivity() async {
    try {
      final result = await AnalyticsService().fetchAuditLogs(
        targetId: widget.userData['_id'],
        limit: 100,
        sortOrder: 'asc',
      );
      if (mounted) {
        setState(() {
          _auditLogs = List<Map<String, dynamic>>.from(result['logs'] ?? []);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  IconData _getActivityIcon(String action) {
    final a = action.toUpperCase();
    if (a.contains('CREATE') || a.contains('REGISTER')) return Icons.person_add_rounded;
    if (a.contains('KYC') && a.contains('APPROVE')) return Icons.verified_rounded;
    if (a.contains('KYC') && a.contains('REJECT')) return Icons.cancel_rounded;
    if (a.contains('KYC')) return Icons.assignment_rounded;
    if (a.contains('BLOCK')) return Icons.block_rounded;
    if (a.contains('UNBLOCK')) return Icons.lock_open_rounded;
    if (a.contains('DELETE') || a.contains('REMOVE')) return Icons.delete_rounded;
    if (a.contains('RESTORE')) return Icons.restore_rounded;
    if (a.contains('UPDATE') || a.contains('EDIT')) return Icons.edit_rounded;
    if (a.contains('ASSIGN')) return Icons.person_pin_rounded;
    if (a.contains('LOGIN')) return Icons.login_rounded;
    return Icons.info_rounded;
  }

  Color _getActivityColor(String action) {
    final a = action.toUpperCase();
    if (a.contains('CREATE') || a.contains('REGISTER')) return Colors.teal;
    if (a.contains('KYC') && a.contains('APPROVE')) return Colors.green;
    if (a.contains('KYC') && a.contains('REJECT')) return AppTheme.error;
    if (a.contains('KYC')) return Colors.orange;
    if (a.contains('BLOCK')) return AppTheme.error;
    if (a.contains('UNBLOCK')) return Colors.green;
    if (a.contains('DELETE') || a.contains('REMOVE')) return const Color(0xFF7C2D12);
    if (a.contains('RESTORE')) return AppTheme.primaryColor;
    if (a.contains('UPDATE') || a.contains('EDIT')) return Colors.blueAccent;
    if (a.contains('ASSIGN')) return Colors.purple;
    return Colors.grey;
  }

  String _formatAction(String action) {
    return action
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.userData;
    final String name = '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'.trim();
    final String displayName = name.isEmpty ? 'Unknown User' : name;
    final String phone = widget.cleanDeletedField(u['phoneNumber']);
    
    String deletedBy = u['deletedByAdminName'] ?? '';
    if (deletedBy.isEmpty && u['assignedAgent'] != null) {
      final agent = u['assignedAgent'];
      deletedBy = '${agent['firstName'] ?? ''} ${agent['lastName'] ?? ''}'.trim();
    }
    if (deletedBy.isEmpty) deletedBy = 'System';

    final String kycStatus = u['kycStatus'] ?? 'pending';
    final String deletedDate = u['deletedAt'] != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(u['deletedAt']).toLocal())
        : '-';

    Color kycColor;
    String kycLabel;
    IconData kycIcon;
    switch (kycStatus) {
      case 'verified':
        kycColor = Colors.green;
        kycLabel = 'KYC Verified';
        kycIcon = Icons.verified_rounded;
        break;
      case 'rejected':
        kycColor = AppTheme.error;
        kycLabel = 'KYC Rejected';
        kycIcon = Icons.cancel_rounded;
        break;
      default:
        kycColor = Colors.orange;
        kycLabel = 'KYC Pending';
        kycIcon = Icons.hourglass_top_rounded;
    }

    final initials = displayName.split(' ').take(2).map((p) => p.isEmpty ? '' : p[0].toUpperCase()).join();

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (ctx, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SelectionArea(
            child: Column(
              children: [
                // Handle
                Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),

              // ── Profile Header ──────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.red.shade300, Colors.red.shade600],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          initials.isEmpty ? '?' : initials,
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(displayName,
                              style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary)),
                          const SizedBox(height: 2),
                          Text(phone,
                              style: GoogleFonts.outfit(
                                  fontSize: 13, color: AppTheme.textSecondary)),
                          if (u['shopName'] != null && u['shopName'].toString().isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(u['shopName'],
                                style: GoogleFonts.outfit(
                                    fontSize: 13, color: AppTheme.textSecondary)),
                          ],
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              // KYC Badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: kycColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: kycColor.withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(kycIcon, size: 12, color: kycColor),
                                    const SizedBox(width: 4),
                                    Text(kycLabel,
                                        style: GoogleFonts.outfit(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: kycColor)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Deleted Badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.error.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.delete_rounded, size: 12, color: AppTheme.error),
                                    const SizedBox(width: 4),
                                    Text('Deleted by $deletedBy on $deletedDate',
                                        style: GoogleFonts.outfit(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.error)),
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

              const SizedBox(height: 16),
              Divider(color: Colors.grey.shade100, height: 1),

              // ── Activity Timeline Header ──────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
                child: Row(
                  children: [
                    Icon(Icons.history_rounded, size: 16, color: AppTheme.primaryColor),
                    const SizedBox(width: 8),
                    Text('Activity History',
                        style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary)),
                    const Spacer(),
                    if (!_isLoading && _auditLogs.isNotEmpty)
                      Text('${_auditLogs.length} events',
                          style: GoogleFonts.outfit(
                              fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                ),
              ),

              // ── Timeline List ─────────────────────────────────────────────
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(
                            child: Text('Failed to load activity',
                                style: GoogleFonts.outfit(color: AppTheme.textSecondary)))
                        : _auditLogs.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.timeline_rounded,
                                        size: 40, color: Colors.grey.shade300),
                                    const SizedBox(height: 8),
                                    Text('No activity recorded',
                                        style: GoogleFonts.outfit(
                                            color: AppTheme.textSecondary)),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                controller: scrollController,
                                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                                itemCount: _auditLogs.length,
                                itemBuilder: (ctx, idx) {
                                  final log = _auditLogs[idx];
                                  final action = log['action'] ?? '';
                                  final color = _getActivityColor(action);
                                  final icon = _getActivityIcon(action);
                                  final label = _formatAction(action);
                                  final timestamp = log['timestamp'] != null
                                      ? DateFormat('dd MMM yyyy, hh:mm a')
                                          .format(DateTime.parse(log['timestamp']).toLocal())
                                      : '-';
                                  // Use resolved full name if available, fallback to email
                                  final adminName = (log['adminName'] as String?)?.isNotEmpty == true
                                      ? log['adminName'] as String
                                      : (log['adminEmail'] as String? ?? 'System');
                                  final isLast = idx == _auditLogs.length - 1;

                                  // Build context-specific detail lines
                                  final List<String> detailLines = [];
                                  final changes = log['changes'] as Map<String, dynamic>?;
                                  final changesAfter = changes?['after'] as Map<String, dynamic>?;
                                  if (action.toUpperCase().contains('ASSIGN') && changesAfter != null) {
                                    final agentName = changesAfter['assignedAgentName'] as String?;
                                    if (agentName != null && agentName.isNotEmpty) {
                                      detailLines.add('Agent: $agentName');
                                    }
                                  } else if (changes != null) {
                                    final changesBefore = changes['before'] as Map<String, dynamic>?;
                                    if (changesBefore != null && changesAfter != null) {
                                      final technicalKeys = {'updatedAt', 'createdAt', '__v', '_id', 'id', 'password', 'fcmToken', 'notesHistory', 'adminId', 'adminName'};
                                      changesAfter.forEach((key, valAfter) {
                                        if (technicalKeys.contains(key)) return;
                                        final valBefore = changesBefore[key];
                                        if (valBefore?.toString() != valAfter?.toString()) {
                                          final friendlyKey = key.replaceAll(RegExp(r'(?=[A-Z])'), ' ').trim();
                                          final capKey = friendlyKey.isNotEmpty
                                              ? friendlyKey[0].toUpperCase() + friendlyKey.substring(1)
                                              : key;
                                          String beforeStr = valBefore?.toString() ?? '(Empty)';
                                          String afterStr = valAfter?.toString() ?? '(Empty)';
                                          if (key == 'assignedAgent') {
                                            beforeStr = changesBefore['assignedAgentName']?.toString() ?? beforeStr;
                                            afterStr = changesAfter['assignedAgentName']?.toString() ?? afterStr;
                                          }
                                          detailLines.add('$capKey: $beforeStr ➔ $afterStr');
                                        }
                                      });
                                    }
                                  }

                                  return Stack(
                                    children: [
                                      if (!isLast)
                                        Positioned(
                                          left: 15.25,
                                          top: 36,
                                          bottom: 4,
                                          child: Container(
                                            width: 1.5,
                                            color: Colors.grey.shade200,
                                          ),
                                        ),
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Timeline dot
                                          SizedBox(
                                            width: 32,
                                            child: Container(
                                              width: 32,
                                              height: 32,
                                              decoration: BoxDecoration(
                                                color: color.withValues(alpha: 0.1),
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                    color: color.withValues(alpha: 0.4), width: 1.5),
                                              ),
                                              child: Icon(icon, size: 14, color: color),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          // Content
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const SizedBox(height: 4),
                                                Text(label,
                                                    style: GoogleFonts.outfit(
                                                        fontWeight: FontWeight.w600,
                                                        fontSize: 13,
                                                        color: color,
                                                        height: 1.2)),
                                                const SizedBox(height: 2),
                                                Text(timestamp,
                                                    style: GoogleFonts.outfit(
                                                        fontSize: 11,
                                                        color: AppTheme.textSecondary,
                                                        height: 1.2)),
                                                const SizedBox(height: 2),
                                                Text('By: $adminName',
                                                    style: GoogleFonts.outfit(
                                                        fontSize: 11,
                                                        color: Colors.grey.shade400,
                                                        height: 1.2)),
                                                for (final detail in detailLines) ...[
                                                  const SizedBox(height: 2),
                                                  Text(detail,
                                                      style: GoogleFonts.outfit(
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.w500,
                                                          color: Colors.grey.shade500,
                                                          height: 1.2)),
                                                ],
                                                if (!isLast) const SizedBox(height: 20),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  );
                                },
                              ),
              ),

              // ── Footer Action Buttons ─────────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Colors.grey.shade100)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: widget.onRestore,
                        icon: const Icon(Icons.restore_rounded, size: 16),
                        label: Text('Restore User',
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryColor,
                          side: BorderSide(color: AppTheme.primaryColor),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: widget.onPurge,
                        icon: const Icon(Icons.delete_forever_rounded, size: 16),
                        label: Text('Purge Forever',
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.error,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
      },
    );
  }
}
