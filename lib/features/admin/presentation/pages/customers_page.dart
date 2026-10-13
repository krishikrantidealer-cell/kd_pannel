import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:kd_pannel/app_theme.dart';
import 'package:kd_pannel/core/auth/auth_service.dart';
import 'package:kd_pannel/core/repositories/user_repository.dart';
import 'package:kd_pannel/core/responsive/responsive.dart';

class CustomersPage extends StatefulWidget {
  const CustomersPage({super.key});

  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounceTimer;

  // Data state
  List<Map<String, dynamic>> _customers = [];
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _salesAgents = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Pagination & Filtering
  int _currentPage = 1;
  int _limit = 25;
  int _totalCount = 0;
  int _requestId = 0;

  String _searchQuery = '';
  String _selectedStatus = 'all'; // 'all', 'false' (active), 'true' (deleted)
  String _selectedAssignment = 'all'; // 'all', 'unassigned', 'assigned', or agentId
  String _selectedKycStatus = 'all'; // 'all', 'not_verified' (leads), 'verified' (dealers)

  // Selected customer for inspector drawer
  Map<String, dynamic>? _selectedCustomer;

  @override
  void initState() {
    super.initState();
    if (!AuthService().isSales) {
      _loadInitialData();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    _fetchStats();
    _fetchCustomers(page: 1);
  }

  Future<void> _fetchStats() async {
    try {
      final statsData = await UserRepository().fetchCustomerDirectoryStats();
      if (!mounted) return;
      setState(() {
        _stats = statsData;
        final List rawBreakdown = statsData['agentBreakdown'] ?? [];
        _salesAgents = rawBreakdown
            .where((a) => a['agentId'] != null)
            .map((a) => Map<String, dynamic>.from(a))
            .toList();
      });
    } catch (_) {}
  }

  Future<void> _fetchCustomers({int? page}) async {
    final int currentReq = ++_requestId;
    final int targetPage = page ?? _currentPage;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _currentPage = targetPage;
    });

    try {
      final res = await UserRepository().fetchCustomerDirectoryUsers(
        page: targetPage,
        limit: _limit,
        search: _searchQuery,
        isDeleted: _selectedStatus,
        assignedAgent: _selectedAssignment,
        kycStatus: _selectedKycStatus,
      );

      if (currentReq != _requestId || !mounted) return;

      final List rawUsers = res['users'] ?? [];
      setState(() {
        _customers = rawUsers.map((u) => Map<String, dynamic>.from(u)).toList();
        _totalCount = res['totalCount'] ?? 0;
        _isLoading = false;
      });
    } catch (e) {
      if (currentReq != _requestId || !mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('Exception:', '').trim();
      });
    }
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      if (mounted) {
        setState(() {
          _searchQuery = query;
        });
        _fetchCustomers(page: 1);
      }
    });
  }

  void _resetFilters() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _selectedStatus = 'all';
      _selectedAssignment = 'all';
      _selectedKycStatus = 'all';
    });
    _fetchCustomers(page: 1);
  }

  String _cleanPhone(dynamic raw) {
    if (raw == null) return 'N/A';
    final str = raw.toString();
    if (str.contains('_deleted_')) {
      return str.split('_deleted_').first;
    }
    return str;
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (AuthService().isSales) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_rounded, size: 40, color: Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 16),
              Text(
                'Access Restricted',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'The Customer Directory is accessible to Administrators only.',
                style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      );
    }

    final isDesktop = Responsive.isDesktop(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          SafeArea(
            child: RefreshIndicator(
              color: AppTheme.primaryColor,
              onRefresh: () async {
                await _fetchStats();
                await _fetchCustomers(page: _currentPage);
              },
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // 1. Page Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        isDesktop ? 24 : 16,
                        20,
                        isDesktop ? 24 : 16,
                        12,
                      ),
                      child: _buildHeader(isDesktop),
                    ),
                  ),

                  // 2. Metrics KPI Summary Cards
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isDesktop ? 24 : 16,
                        vertical: 8,
                      ),
                      child: _buildMetricCards(isDesktop),
                    ),
                  ),

                  // 3. Search & Filters Bar
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isDesktop ? 24 : 16,
                        vertical: 12,
                      ),
                      child: _buildFiltersBar(isDesktop),
                    ),
                  ),

                  // 4. Content (Table or Cards)
                  SliverPadding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 24 : 16,
                      vertical: 6,
                    ),
                    sliver: _buildContentSliver(isDesktop),
                  ),

                  // 5. Pagination Bar
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isDesktop ? 24 : 16,
                        vertical: 20,
                      ),
                      child: _buildPaginationBar(isDesktop),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 6. Customer Inspector Drawer / Modal
          if (_selectedCustomer != null)
            _buildCustomerInspectorDrawer(isDesktop),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDesktop) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.group_rounded,
            color: AppTheme.primaryColor,
            size: 26,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Customers Directory',
                style: GoogleFonts.outfit(
                  fontSize: isDesktop ? 24 : 20,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Comprehensive database of all users • Active & deleted records • Sales agent assignment inspection',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: const Color(0xFF64748B),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        IconButton(
          tooltip: 'Refresh Directory',
          onPressed: () {
            _fetchStats();
            _fetchCustomers(page: _currentPage);
          },
          icon: const Icon(Icons.refresh_rounded, color: Color(0xFF475569)),
          style: IconButton.styleFrom(
            backgroundColor: Colors.white,
            side: const BorderSide(color: Color(0xFFE2E8F0)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCards(bool isDesktop) {
    final total = _stats['total'] ?? 0;
    final active = _stats['active'] ?? 0;
    final deleted = _stats['deleted'] ?? 0;
    final unassigned = _stats['unassigned'] ?? 0;
    final dealers = _stats['verifiedDealers'] ?? 0;

    final cards = [
      _MetricCardItem(
        label: 'Total Users',
        value: NumberFormat.compact().format(total),
        fullValue: '$total users in DB',
        icon: Icons.people_alt_rounded,
        color: const Color(0xFF2563EB),
        bgColor: const Color(0xFFEFF6FF),
        isActive: _selectedStatus == 'all' && _selectedAssignment == 'all',
        onTap: () {
          setState(() {
            _selectedStatus = 'all';
            _selectedAssignment = 'all';
          });
          _fetchCustomers(page: 1);
        },
      ),
      _MetricCardItem(
        label: 'Active Accounts',
        value: NumberFormat.compact().format(active),
        fullValue: '$active active users',
        icon: Icons.check_circle_rounded,
        color: const Color(0xFF16A34A),
        bgColor: const Color(0xFFF0FDF4),
        isActive: _selectedStatus == 'false',
        onTap: () {
          setState(() => _selectedStatus = 'false');
          _fetchCustomers(page: 1);
        },
      ),
      _MetricCardItem(
        label: 'Deleted Accounts',
        value: NumberFormat.compact().format(deleted),
        fullValue: '$deleted deleted users',
        icon: Icons.delete_sweep_rounded,
        color: const Color(0xFFDC2626),
        bgColor: const Color(0xFFFEF2F2),
        isActive: _selectedStatus == 'true',
        onTap: () {
          setState(() => _selectedStatus = 'true');
          _fetchCustomers(page: 1);
        },
      ),
      _MetricCardItem(
        label: 'Unassigned',
        value: NumberFormat.compact().format(unassigned),
        fullValue: '$unassigned unassigned users',
        icon: Icons.person_off_rounded,
        color: const Color(0xFFD97706),
        bgColor: const Color(0xFFFFFBEB),
        isAlert: unassigned > 0,
        isActive: _selectedAssignment == 'unassigned',
        onTap: () {
          setState(() => _selectedAssignment = 'unassigned');
          _fetchCustomers(page: 1);
        },
      ),
      _MetricCardItem(
        label: 'Verified Dealers',
        value: NumberFormat.compact().format(dealers),
        fullValue: '$dealers KYC verified',
        icon: Icons.verified_user_rounded,
        color: const Color(0xFF7C3AED),
        bgColor: const Color(0xFFF5F3FF),
        isActive: _selectedKycStatus == 'verified',
        onTap: () {
          setState(() => _selectedKycStatus = 'verified');
          _fetchCustomers(page: 1);
        },
      ),
    ];

    if (isDesktop) {
      return Row(
        children: cards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 5), child: c))).toList(),
      );
    } else {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: cards.map((c) => SizedBox(width: 170, child: Padding(padding: const EdgeInsets.only(right: 10), child: c))).toList(),
        ),
      );
    }
  }

  Widget _buildFiltersBar(bool isDesktop) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          // Row 1: Search & Reset
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Search by Name, Phone, Shop Name, Email, City, Pincode...',
                    hintStyle: GoogleFonts.outfit(
                      color: const Color(0xFF94A3B8),
                      fontSize: 14,
                    ),
                    prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 22),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 20),
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppTheme.primaryColor, width: 1.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _resetFilters,
                icon: const Icon(Icons.filter_alt_off_rounded, size: 18),
                label: Text(
                  isDesktop ? 'Reset Filters' : 'Reset',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF64748B),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 16 : 12,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Row 2: Filter Selectors (Status, Assignment, KYC Status)
          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // 1. Account Deletion Status
              _buildFilterDropdown(
                label: 'Status',
                icon: Icons.shield_rounded,
                value: _selectedStatus,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All (Active + Deleted)')),
                  DropdownMenuItem(value: 'false', child: Text('🟢 Active Only')),
                  DropdownMenuItem(value: 'true', child: Text('🔴 Deleted Only')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedStatus = val);
                    _fetchCustomers(page: 1);
                  }
                },
              ),

              // 2. Sales Agent Assignment
              _buildFilterDropdown(
                label: 'Assigned Agent',
                icon: Icons.support_agent_rounded,
                value: _selectedAssignment,
                items: [
                  const DropdownMenuItem(value: 'all', child: Text('All Assignments')),
                  const DropdownMenuItem(value: 'unassigned', child: Text('⚠️ Unassigned Only')),
                  const DropdownMenuItem(value: 'assigned', child: Text('✅ Assigned (Any)')),
                  ..._salesAgents.map((agent) {
                    final name = agent['agentName'] ?? 'Agent';
                    final count = agent['total'] ?? 0;
                    return DropdownMenuItem(
                      value: agent['agentId'],
                      child: Text('$name ($count)'),
                    );
                  }),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedAssignment = val);
                    _fetchCustomers(page: 1);
                  }
                },
              ),

              // 3. User Type / KYC
              _buildFilterDropdown(
                label: 'Account Type',
                icon: Icons.verified_user_rounded,
                value: _selectedKycStatus,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Types')),
                  DropdownMenuItem(value: 'not_verified', child: Text('🟣 Leads (Pending KYC)')),
                  DropdownMenuItem(value: 'verified', child: Text('🔵 Verified Dealers')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedKycStatus = val);
                    _fetchCustomers(page: 1);
                  }
                },
              ),

              // Active filter indicator badge
              if (_selectedStatus != 'all' || _selectedAssignment != 'all' || _selectedKycStatus != 'all' || _searchQuery.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.filter_list_rounded, size: 14, color: AppTheme.primaryColor),
                      const SizedBox(width: 4),
                      Text(
                        'Filtered View (${NumberFormat.compact().format(_totalCount)} found)',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String label,
    required IconData icon,
    required String value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF64748B)),
          const SizedBox(width: 6),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: items.any((i) => i.value == value) ? value : 'all',
              items: items,
              onChanged: onChanged,
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1E293B),
              ),
              icon: const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF64748B)),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentSliver(bool isDesktop) {
    if (_isLoading) {
      return SliverToBoxAdapter(
        child: Container(
          padding: const EdgeInsets.all(40),
          alignment: Alignment.center,
          child: Column(
            children: [
              CircularProgressIndicator(color: AppTheme.primaryColor),
              const SizedBox(height: 16),
              Text(
                'Searching customer records...',
                style: GoogleFonts.outfit(color: const Color(0xFF64748B), fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return SliverToBoxAdapter(
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFCA5A5)),
          ),
          child: Column(
            children: [
              const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 40),
              const SizedBox(height: 12),
              Text(
                'Failed to load customers',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 6),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(color: const Color(0xFF64748B), fontSize: 13),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _fetchCustomers(page: _currentPage),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_customers.isEmpty) {
      return SliverToBoxAdapter(
        child: Container(
          padding: const EdgeInsets.all(48),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_search_rounded, size: 44, color: Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 16),
              Text(
                'No Customers Found',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'No user records match your search or filter parameters.',
                style: GoogleFonts.outfit(color: const Color(0xFF64748B), fontSize: 13),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: _resetFilters,
                child: const Text('Clear All Filters'),
              ),
            ],
          ),
        ),
      );
    }

    if (isDesktop) {
      return SliverToBoxAdapter(
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: DataTable(
              showCheckboxColumn: false,
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
              horizontalMargin: 20,
              columnSpacing: 24,
              dataRowMinHeight: 64,
              dataRowMaxHeight: 68,
              columns: [
                DataColumn(label: Text('Customer', style: _headerStyle())),
                DataColumn(label: Text('Shop / Location', style: _headerStyle())),
                DataColumn(label: Text('Account Status', style: _headerStyle())),
                DataColumn(label: Text('Assigned Sales Agent', style: _headerStyle())),
                DataColumn(label: Text('Registration', style: _headerStyle())),
                DataColumn(label: Text('Action', style: _headerStyle())),
              ],
              rows: _customers.map((c) => _buildDataRow(c)).toList(),
            ),
          ),
        ),
      );
    } else {
      // Mobile / Tablet Card list
      return SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => _buildCustomerCard(_customers[index]),
          childCount: _customers.length,
        ),
      );
    }
  }

  TextStyle _headerStyle() {
    return GoogleFonts.outfit(
      fontWeight: FontWeight.w700,
      fontSize: 12.5,
      color: const Color(0xFF475569),
    );
  }

  DataRow _buildDataRow(Map<String, dynamic> c) {
    final firstName = c['firstName'] ?? '';
    final lastName = c['lastName'] ?? '';
    final fullName = ('$firstName $lastName').trim().isNotEmpty ? ('$firstName $lastName').trim() : 'Unnamed User';
    final rawPhone = c['phoneNumber'];
    final cleanPhone = _cleanPhone(rawPhone);
    final shopName = c['shopName'] ?? '';
    final address = c['address'] as Map<String, dynamic>?;
    final city = address?['cityTehsil'] ?? address?['villageArea'] ?? '';
    final state = address?['state'] ?? '';
    final location = [city, state].where((s) => s.toString().isNotEmpty).join(', ');

    final isDeleted = c['isDeleted'] == true;
    final kycStatus = c['kycStatus'] ?? 'pending';
    final isVerifiedDealer = kycStatus == 'verified';

    final assignedAgent = c['assignedAgent'] as Map<String, dynamic>?;
    final createdAt = c['createdAt'] != null
        ? DateFormat('dd MMM yyyy').format(DateTime.tryParse(c['createdAt']) ?? DateTime.now())
        : 'N/A';

    return DataRow(
      onSelectChanged: (_) {
        setState(() => _selectedCustomer = c);
      },
      cells: [
        // 1. Customer Column
        DataCell(
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: isDeleted
                    ? const Color(0xFFFEE2E2)
                    : AppTheme.primaryColor.withValues(alpha: 0.12),
                child: Text(
                  fullName.isNotEmpty ? fullName[0].toUpperCase() : 'U',
                  style: GoogleFonts.outfit(
                    color: isDeleted ? const Color(0xFFDC2626) : AppTheme.primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    fullName,
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                      color: isDeleted ? const Color(0xFF64748B) : const Color(0xFF0F172A),
                      decoration: isDeleted ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        cleanPhone,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: const Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: () => _copyToClipboard(cleanPhone, 'Phone number'),
                        child: const Icon(Icons.copy_rounded, size: 12, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),

        // 2. Shop / Location
        DataCell(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                shopName.isNotEmpty ? shopName : 'Individual',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                location.isNotEmpty ? location : (address?['pincode'] ?? 'No address'),
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),

        // 3. Status Column (Active/Deleted + KYC)
        DataCell(
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDeleted ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isDeleted ? const Color(0xFFFECACA) : const Color(0xFFBBF7D0),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isDeleted ? Icons.cancel_rounded : Icons.check_circle_rounded,
                      size: 11,
                      color: isDeleted ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isDeleted ? 'Deleted' : 'Active',
                      style: GoogleFonts.outfit(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: isDeleted ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isVerifiedDealer ? const Color(0xFFEFF6FF) : const Color(0xFFFAF5FF),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isVerifiedDealer ? 'Dealer' : 'Lead',
                  style: GoogleFonts.outfit(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: isVerifiedDealer ? const Color(0xFF2563EB) : const Color(0xFF9333EA),
                  ),
                ),
              ),
            ],
          ),
        ),

        // 4. Assigned Sales Agent
        DataCell(
          assignedAgent != null
              ? Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.support_agent_rounded, size: 16, color: Color(0xFF475569)),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${assignedAgent['firstName'] ?? ''} ${assignedAgent['lastName'] ?? ''}'.trim(),
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        if (assignedAgent['phoneNumber'] != null)
                          Text(
                            assignedAgent['phoneNumber'],
                            style: GoogleFonts.outfit(
                              fontSize: 11.5,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                      ],
                    ),
                  ],
                )
              : Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 13, color: Color(0xFFD97706)),
                      const SizedBox(width: 4),
                      Text(
                        'Unassigned',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFD97706),
                        ),
                      ),
                    ],
                  ),
                ),
        ),

        // 5. Registered Date
        DataCell(
          Text(
            createdAt,
            style: GoogleFonts.outfit(
              fontSize: 12.5,
              color: const Color(0xFF64748B),
            ),
          ),
        ),

        // 6. Action Button (Inspect)
        DataCell(
          ElevatedButton.icon(
            onPressed: () {
              setState(() => _selectedCustomer = c);
            },
            icon: const Icon(Icons.visibility_rounded, size: 15),
            label: const Text('Inspect'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF1F5F9),
              foregroundColor: const Color(0xFF1E293B),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomerCard(Map<String, dynamic> c) {
    final firstName = c['firstName'] ?? '';
    final lastName = c['lastName'] ?? '';
    final fullName = ('$firstName $lastName').trim().isNotEmpty ? ('$firstName $lastName').trim() : 'Unnamed User';
    final cleanPhone = _cleanPhone(c['phoneNumber']);
    final isDeleted = c['isDeleted'] == true;
    final isDealer = c['kycStatus'] == 'verified';
    final assignedAgent = c['assignedAgent'] as Map<String, dynamic>?;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => setState(() => _selectedCustomer = c),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: isDeleted ? const Color(0xFFFEE2E2) : AppTheme.primaryColor.withValues(alpha: 0.1),
                  child: Text(
                    fullName.isNotEmpty ? fullName[0].toUpperCase() : 'U',
                    style: GoogleFonts.outfit(
                      color: isDeleted ? const Color(0xFFDC2626) : AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fullName,
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        cleanPhone,
                        style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDeleted ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isDeleted ? 'Deleted' : 'Active',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDeleted ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDealer ? const Color(0xFFEFF6FF) : const Color(0xFFFAF5FF),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isDealer ? 'Dealer' : 'Lead',
                        style: GoogleFonts.outfit(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: isDealer ? const Color(0xFF2563EB) : const Color(0xFF9333EA),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 24, color: Color(0xFFF1F5F9)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Assigned Agent', style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF94A3B8))),
                    const SizedBox(height: 2),
                    Text(
                      assignedAgent != null
                          ? '${assignedAgent['firstName'] ?? ''} ${assignedAgent['lastName'] ?? ''}'.trim()
                          : '⚠️ Unassigned',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: assignedAgent != null ? const Color(0xFF0F172A) : const Color(0xFFD97706),
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: () => setState(() => _selectedCustomer = c),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                  label: const Text('Inspect'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaginationBar(bool isDesktop) {
    final int totalPages = (_totalCount / _limit).ceil();
    final int startItem = _totalCount == 0 ? 0 : (_currentPage - 1) * _limit + 1;
    final int endItem = ((_currentPage * _limit) > _totalCount) ? _totalCount : (_currentPage * _limit);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing $startItem–$endItem of ${NumberFormat.decimalPattern().format(_totalCount)} customers',
            style: GoogleFonts.outfit(
              fontSize: 13,
              color: const Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: _currentPage > 1 && !_isLoading
                    ? () => _fetchCustomers(page: _currentPage - 1)
                    : null,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Page $_currentPage of ${totalPages == 0 ? 1 : totalPages}',
                  style: GoogleFonts.outfit(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E293B),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: _currentPage < totalPages && !_isLoading
                    ? () => _fetchCustomers(page: _currentPage + 1)
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // Customer Research Dossier (Inspector Drawer)
  // -------------------------------------------------------------
  Widget _buildCustomerInspectorDrawer(bool isDesktop) {
    final c = _selectedCustomer!;
    final firstName = c['firstName'] ?? '';
    final lastName = c['lastName'] ?? '';
    final fullName = ('$firstName $lastName').trim().isNotEmpty ? ('$firstName $lastName').trim() : 'Unnamed User';
    final cleanPhone = _cleanPhone(c['phoneNumber']);
    final isDeleted = c['isDeleted'] == true;
    final kycStatus = c['kycStatus'] ?? 'pending';
    final isDealer = kycStatus == 'verified';
    final assignedAgent = c['assignedAgent'] as Map<String, dynamic>?;
    final address = c['address'] as Map<String, dynamic>?;
    final notesHistory = (c['notesHistory'] as List?) ?? [];

    return GestureDetector(
      onTap: () => setState(() => _selectedCustomer = null),
      child: Container(
        color: Colors.black.withValues(alpha: 0.4),
        child: Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onTap: () {}, // Prevent dismissal when tapping drawer content
            child: Container(
              width: isDesktop ? 480 : MediaQuery.of(context).size.width * 0.9,
              height: double.infinity,
              color: Colors.white,
              child: Column(
                children: [
                  // Drawer Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      border: Border(bottom: BorderSide(color: const Color(0xFFE2E8F0))),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: isDeleted ? const Color(0xFFFEE2E2) : AppTheme.primaryColor.withValues(alpha: 0.12),
                          child: Text(
                            fullName.isNotEmpty ? fullName[0].toUpperCase() : 'U',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: isDeleted ? const Color(0xFFDC2626) : AppTheme.primaryColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                fullName,
                                style: GoogleFonts.outfit(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Text(
                                    cleanPhone,
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      color: const Color(0xFF64748B),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  InkWell(
                                    onTap: () => _copyToClipboard(cleanPhone, 'Phone number'),
                                    child: const Icon(Icons.copy_rounded, size: 14, color: Color(0xFF94A3B8)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => setState(() => _selectedCustomer = null),
                        ),
                      ],
                    ),
                  ),

                  // Drawer Body
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        // Status Banners
                        Row(
                          children: [
                            Expanded(
                              child: _buildInfoBadge(
                                label: 'Status',
                                value: isDeleted ? 'Deleted Account' : 'Active Account',
                                icon: isDeleted ? Icons.cancel_rounded : Icons.check_circle_rounded,
                                color: isDeleted ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                                bgColor: isDeleted ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildInfoBadge(
                                label: 'Account Type',
                                value: isDealer ? 'Verified Dealer' : 'Lead (Pending KYC)',
                                icon: isDealer ? Icons.verified_user_rounded : Icons.person_outline_rounded,
                                color: isDealer ? const Color(0xFF2563EB) : const Color(0xFF9333EA),
                                bgColor: isDealer ? const Color(0xFFEFF6FF) : const Color(0xFFFAF5FF),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Assigned Sales Agent Card
                        _buildSectionCard(
                          title: 'Assigned Sales Agent',
                          icon: Icons.support_agent_rounded,
                          child: assignedAgent != null
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildDetailRow('Agent Name', '${assignedAgent['firstName'] ?? ''} ${assignedAgent['lastName'] ?? ''}'.trim()),
                                    _buildDetailRow('Agent Phone', assignedAgent['phoneNumber'] ?? 'N/A'),
                                    _buildDetailRow('Agent Email', assignedAgent['email'] ?? 'N/A'),
                                    if (c['assignedAt'] != null)
                                      _buildDetailRow('Assigned On', DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.tryParse(c['assignedAt']) ?? DateTime.now())),
                                  ],
                                )
                              : Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFFBEB),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFFFDE68A)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.info_outline_rounded, color: Color(0xFFD97706), size: 20),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          'This customer has not been assigned to any sales agent yet.',
                                          style: GoogleFonts.outfit(
                                            fontSize: 13,
                                            color: const Color(0xFFB45309),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                        ),

                        const SizedBox(height: 16),

                        // Contact & Address Details
                        _buildSectionCard(
                          title: 'Contact & Business Details',
                          icon: Icons.storefront_rounded,
                          child: Column(
                            children: [
                              _buildDetailRow('Shop / Business', c['shopName'] ?? 'Individual'),
                              _buildDetailRow('Email', c['email'] ?? 'No email provided'),
                              _buildDetailRow('Address Type', c['addressType'] ?? 'Home'),
                              _buildDetailRow('Village / Area', address?['villageArea'] ?? 'N/A'),
                              _buildDetailRow('City / Tehsil', address?['cityTehsil'] ?? 'N/A'),
                              _buildDetailRow('State', address?['state'] ?? 'N/A'),
                              _buildDetailRow('Pincode', address?['pincode'] ?? 'N/A'),
                              _buildDetailRow('Source', c['source'] ?? 'App'),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Lifecycle Timestamps
                        _buildSectionCard(
                          title: 'Timeline & System History',
                          icon: Icons.history_rounded,
                          child: Column(
                            children: [
                              _buildDetailRow(
                                'Registered On',
                                c['createdAt'] != null
                                    ? DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.tryParse(c['createdAt']) ?? DateTime.now())
                                    : 'N/A',
                              ),
                              _buildDetailRow(
                                'Last Updated',
                                c['updatedAt'] != null
                                    ? DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.tryParse(c['updatedAt']) ?? DateTime.now())
                                    : 'N/A',
                              ),
                              if (isDeleted) ...[
                                _buildDetailRow(
                                  'Deleted On',
                                  c['deletedAt'] != null
                                      ? DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.tryParse(c['deletedAt']) ?? DateTime.now())
                                      : 'N/A',
                                ),
                                _buildDetailRow('Deleted By', c['deletedByAdminName'] ?? 'Admin'),
                              ],
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Notes History (if any)
                        if (notesHistory.isNotEmpty)
                          _buildSectionCard(
                            title: 'Notes & Contact History (${notesHistory.length})',
                            icon: Icons.notes_rounded,
                            child: Column(
                              children: notesHistory.map((n) {
                                final noteText = n['note'] ?? '';
                                final author = n['adminName'] ?? n['author'] ?? 'Agent';
                                final date = n['createdAt'] != null
                                    ? DateFormat('dd MMM yyyy').format(DateTime.tryParse(n['createdAt']) ?? DateTime.now())
                                    : '';
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            author,
                                            style: GoogleFonts.outfit(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                              color: const Color(0xFF334155),
                                            ),
                                          ),
                                          Text(
                                            date,
                                            style: GoogleFonts.outfit(
                                              fontSize: 11,
                                              color: const Color(0xFF94A3B8),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        noteText,
                                        style: GoogleFonts.outfit(
                                          fontSize: 12.5,
                                          color: const Color(0xFF475569),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),

                        const SizedBox(height: 20),

                        // Copy Phone Button
                        OutlinedButton.icon(
                          onPressed: () => _copyToClipboard(cleanPhone, 'Phone number'),
                          icon: const Icon(Icons.copy_rounded, size: 16),
                          label: Text(
                            'Copy Phone Number',
                            style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF334155),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoBadge({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xFF64748B)),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const Divider(height: 20, color: Color(0xFFF1F5F9)),
          child,
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 12.5,
                color: const Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: const Color(0xFF0F172A),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCardItem extends StatelessWidget {
  final String label;
  final String value;
  final String fullValue;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final bool isAlert;
  final bool isActive;
  final VoidCallback onTap;

  const _MetricCardItem({
    required this.label,
    required this.value,
    required this.fullValue,
    required this.icon,
    required this.color,
    required this.bgColor,
    this.isAlert = false,
    this.isActive = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isActive ? color : const Color(0xFFE2E8F0),
              width: isActive ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isActive ? color.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.outfit(
                        fontSize: 11.5,
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
