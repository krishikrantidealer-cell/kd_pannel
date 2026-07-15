import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kd_pannel/app_theme.dart';
import 'package:kd_pannel/core/responsive/responsive.dart';
import 'package:kd_pannel/core/network/api_client.dart';
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
      final searchFilter = _searchQuery.isNotEmpty ? '&search=${Uri.encodeComponent(_searchQuery)}' : '';
      
      final url = '/users?trash=true&role=user&kycStatus=$kycFilter&page=$_page&limit=$_limit$searchFilter';
      final res = await ApiClient().get(url);
      
      if (requestId != _currentRequestId || !mounted) return;

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) {
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
        } else {
          throw Exception(data['message'] ?? 'Failed to load trash users');
        }
      } else {
        throw Exception('Failed to connect to server: ${res.statusCode}');
      }
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
        final res = await ApiClient().put('/users/$userId/restore', {});
        final data = jsonDecode(res.body);
        if (res.statusCode == 200 && data['success'] == true) {
          AnalyticsService().logEvent('restore_user', properties: {
            'targetUserId': userId,
            'userName': userName,
            'details': 'Restored user account from trash: $userName',
          });
          _showSnack('"$userName" has been restored successfully!');
          _fetchTrashData(isFirstLoad: true);
        } else {
          throw Exception(data['message'] ?? 'Failed to restore user');
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
        final res = await ApiClient().delete('/users/$userId/permanent');
        final data = jsonDecode(res.body);
        if (res.statusCode == 200 && data['success'] == true) {
          AnalyticsService().logEvent('permanent_delete_user', properties: {
            'targetUserId': userId,
            'userName': userName,
            'details': 'Permanently deleted user account: $userName',
          });
          _showSnack('"$userName" has been permanently deleted.');
          _fetchTrashData(isFirstLoad: true);
        } else {
          throw Exception(data['message'] ?? 'Failed to permanently delete user');
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

              // Tabs and count
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        _buildSegmentButton('Leads', _selectedTab == 'Leads'),
                        _buildSegmentButton('Dealers', _selectedTab == 'Dealers'),
                      ],
                    ),
                  ),
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
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 60.0),
                        child: CircularProgressIndicator(color: AppTheme.primaryColor),
                      ),
                    )
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
        2: FlexColumnWidth(3), // Shop Name
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
            _buildTableHeaderCell('Shop Name'),
            _buildTableHeaderCell('Deleted Date'),
            _buildTableHeaderCell('Actions', alignRight: true),
          ],
        ),
        // Table Rows
        ...items.map((u) {
          final String name = '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'.trim();
          final String displayName = name.isEmpty ? 'Unknown User' : name;
          final String displayPhoneStr = _cleanDeletedField(u['phoneNumber']);
          final String displayShopStr = u['shopName'] ?? '-';
          final String deletedDateStr = u['deletedAt'] != null
              ? DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(u['deletedAt']).toLocal())
              : '-';

          return TableRow(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
            ),
            children: [
              _buildTableCell(
                Text(
                  displayName,
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                ),
              ),
              _buildTableCell(Text(displayPhoneStr, style: GoogleFonts.outfit(color: AppTheme.textPrimary))),
              _buildTableCell(
                Text(
                  displayShopStr,
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
        final String deletedDateStr = u['deletedAt'] != null
            ? DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(u['deletedAt']).toLocal())
            : '-';

        return Padding(
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
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textPrimary),
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
              if (u['shopName'] != null && u['shopName'].toString().isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  'Shop Name: ${u['shopName']}',
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
        );
      },
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
