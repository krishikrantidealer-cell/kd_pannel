import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
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
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
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
      _limit = 25;
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

  Future<void> _launchCall(String rawPhone) async {
    final clean = _cleanPhone(rawPhone).replaceAll(RegExp(r'[^0-9+]'), '');
    if (clean.isEmpty) return;
    final uri = Uri.parse('tel:$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _launchWhatsApp(String rawPhone) async {
    String clean = _cleanPhone(rawPhone).replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.length == 10) clean = '91$clean';
    if (clean.isEmpty) return;
    final uri = Uri.parse('https://wa.me/$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _reassignAgent(String userId, String? agentId) async {
    try {
      await UserRepository().assignAgent(userId, agentId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Agent assignment updated successfully'),
          backgroundColor: Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _fetchStats();
      _fetchCustomers(page: _currentPage);
      if (_selectedCustomer != null && _selectedCustomer!['_id'] == userId) {
        setState(() {
          if (agentId == null) {
            _selectedCustomer!['assignedAgent'] = null;
          } else {
            final agent = _salesAgents.firstWhere(
              (a) => a['agentId'] == agentId,
              orElse: () => {'firstName': 'Agent', 'lastName': ''},
            );
            _selectedCustomer!['assignedAgent'] = {
              '_id': agentId,
              'firstName': agent['agentName'] ?? agent['firstName'] ?? 'Agent',
              'phoneNumber': agent['phoneNumber'] ?? '',
            };
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to assign agent: $e'),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
                decoration: const BoxDecoration(
                  color: Color(0xFFF1F5F9),
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
                  // 1. Compact Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        isDesktop ? 20 : 14,
                        14,
                        isDesktop ? 20 : 14,
                        8,
                      ),
                      child: _buildCompactHeader(isDesktop),
                    ),
                  ),

                  // 2. High-Density Metrics KPI Ribbon
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isDesktop ? 20 : 14,
                        vertical: 4,
                      ),
                      child: _buildCompactMetricCards(isDesktop),
                    ),
                  ),

                  // 3. Consolidated Single-Line Search & Filters Bar
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isDesktop ? 20 : 14,
                        vertical: 8,
                      ),
                      child: _buildCompactFiltersBar(isDesktop),
                    ),
                  ),

                  // 4. Compact Customer Table / Cards
                  SliverPadding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 20 : 14,
                      vertical: 4,
                    ),
                    sliver: _buildContentSliver(isDesktop),
                  ),

                  // 5. Compact Pagination Bar
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        isDesktop ? 20 : 14,
                        10,
                        isDesktop ? 20 : 14,
                        18,
                      ),
                      child: _buildCompactPaginationBar(isDesktop),
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

  // -------------------------------------------------------------
  // 1. Compact Header
  // -------------------------------------------------------------
  Widget _buildCompactHeader(bool isDesktop) {
    final total = _stats['total'] ?? 0;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.people_alt_rounded,
            color: AppTheme.primaryColor,
            size: 20,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(
                    'Customer Directory',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Text(
                      '${NumberFormat.decimalPattern().format(total)} Users',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1D4ED8),
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                'Comprehensive directory • KYC verification • Sales agent mapping',
                style: GoogleFonts.outfit(
                  fontSize: 11.5,
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        InkWell(
          onTap: () {
            _fetchStats();
            _fetchCustomers(page: _currentPage);
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.refresh_rounded, size: 16, color: Color(0xFF475569)),
                if (isDesktop) ...[
                  const SizedBox(width: 6),
                  Text(
                    'Refresh',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF475569),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // 2. High-Density Metrics KPI Ribbon
  // -------------------------------------------------------------
  Widget _buildCompactMetricCards(bool isDesktop) {
    final total = _stats['total'] ?? 0;
    final active = _stats['active'] ?? 0;
    final deleted = _stats['deleted'] ?? 0;
    final unassigned = _stats['unassigned'] ?? 0;
    final dealers = _stats['verifiedDealers'] ?? 0;

    final items = [
      _CompactKpiItem(
        label: 'Total Users',
        value: total,
        icon: Icons.groups_rounded,
        color: const Color(0xFF2563EB),
        bgColor: const Color(0xFFEFF6FF),
        isActive: _selectedStatus == 'all' && _selectedAssignment == 'all' && _selectedKycStatus == 'all',
        onTap: () {
          setState(() {
            _selectedStatus = 'all';
            _selectedAssignment = 'all';
            _selectedKycStatus = 'all';
          });
          _fetchCustomers(page: 1);
        },
      ),
      _CompactKpiItem(
        label: 'Active Accounts',
        value: active,
        icon: Icons.check_circle_rounded,
        color: const Color(0xFF16A34A),
        bgColor: const Color(0xFFF0FDF4),
        isActive: _selectedStatus == 'false',
        onTap: () {
          setState(() => _selectedStatus = 'false');
          _fetchCustomers(page: 1);
        },
      ),
      _CompactKpiItem(
        label: 'Deleted Accounts',
        value: deleted,
        icon: Icons.delete_outline_rounded,
        color: const Color(0xFFDC2626),
        bgColor: const Color(0xFFFEF2F2),
        isActive: _selectedStatus == 'true',
        onTap: () {
          setState(() => _selectedStatus = 'true');
          _fetchCustomers(page: 1);
        },
      ),
      _CompactKpiItem(
        label: 'Unassigned',
        value: unassigned,
        icon: Icons.person_off_rounded,
        color: const Color(0xFFD97706),
        bgColor: const Color(0xFFFFFBEB),
        isActive: _selectedAssignment == 'unassigned',
        onTap: () {
          setState(() => _selectedAssignment = 'unassigned');
          _fetchCustomers(page: 1);
        },
      ),
      _CompactKpiItem(
        label: 'Verified Dealers',
        value: dealers,
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
        children: items
            .map((item) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: item,
                  ),
                ))
            .toList(),
      );
    } else {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: items
              .map((item) => Container(
                    width: 155,
                    margin: const EdgeInsets.only(right: 8),
                    child: item,
                  ))
              .toList(),
        ),
      );
    }
  }

  // -------------------------------------------------------------
  // 3. Consolidated Single-Line Search & Filters Bar
  // -------------------------------------------------------------
  Widget _buildCompactFiltersBar(bool isDesktop) {
    final hasActiveFilters = _selectedStatus != 'all' ||
        _selectedAssignment != 'all' ||
        _selectedKycStatus != 'all' ||
        _searchQuery.isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: isDesktop
          ? Row(
              children: [
                // 1. Compact Search Field
                Expanded(
                  flex: 3,
                  child: _buildSearchInput(),
                ),
                const SizedBox(width: 8),

                // 2. Status Dropdown
                _buildCompactDropdown(
                  label: 'Status',
                  icon: Icons.shield_rounded,
                  value: _selectedStatus,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Statuses')),
                    DropdownMenuItem(value: 'false', child: Text('🟢 Active')),
                    DropdownMenuItem(value: 'true', child: Text('🔴 Deleted')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedStatus = val);
                      _fetchCustomers(page: 1);
                    }
                  },
                ),
                const SizedBox(width: 8),

                // 3. Assigned Agent Dropdown
                _buildCompactDropdown(
                  label: 'Agent',
                  icon: Icons.support_agent_rounded,
                  value: _selectedAssignment,
                  items: [
                    const DropdownMenuItem(value: 'all', child: Text('All Agents')),
                    const DropdownMenuItem(value: 'unassigned', child: Text('⚠️ Unassigned')),
                    const DropdownMenuItem(value: 'assigned', child: Text('✅ Assigned')),
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
                const SizedBox(width: 8),

                // 4. KYC / Account Type Dropdown
                _buildCompactDropdown(
                  label: 'Type',
                  icon: Icons.verified_user_rounded,
                  value: _selectedKycStatus,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Types')),
                    DropdownMenuItem(value: 'not_verified', child: Text('🟣 Leads')),
                    DropdownMenuItem(value: 'verified', child: Text('🔵 Dealers')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedKycStatus = val);
                      _fetchCustomers(page: 1);
                    }
                  },
                ),
                const SizedBox(width: 8),

                // 5. Per-page limit selector
                _buildCompactDropdown(
                  label: 'Show',
                  icon: Icons.table_rows_rounded,
                  value: _limit.toString(),
                  items: const [
                    DropdownMenuItem(value: '25', child: Text('25 / page')),
                    DropdownMenuItem(value: '50', child: Text('50 / page')),
                    DropdownMenuItem(value: '100', child: Text('100 / page')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _limit = int.parse(val));
                      _fetchCustomers(page: 1);
                    }
                  },
                ),

                // 6. Reset Filters Button
                if (hasActiveFilters) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: _resetFilters,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.filter_alt_off_rounded, size: 14, color: Color(0xFFDC2626)),
                          const SizedBox(width: 4),
                          Text(
                            'Reset',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFDC2626),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSearchInput(),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildCompactDropdown(
                      label: 'Status',
                      icon: Icons.shield_rounded,
                      value: _selectedStatus,
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All Statuses')),
                        DropdownMenuItem(value: 'false', child: Text('🟢 Active')),
                        DropdownMenuItem(value: 'true', child: Text('🔴 Deleted')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedStatus = val);
                          _fetchCustomers(page: 1);
                        }
                      },
                    ),
                    _buildCompactDropdown(
                      label: 'Agent',
                      icon: Icons.support_agent_rounded,
                      value: _selectedAssignment,
                      items: [
                        const DropdownMenuItem(value: 'all', child: Text('All Agents')),
                        const DropdownMenuItem(value: 'unassigned', child: Text('⚠️ Unassigned')),
                        const DropdownMenuItem(value: 'assigned', child: Text('✅ Assigned')),
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
                    _buildCompactDropdown(
                      label: 'Type',
                      icon: Icons.verified_user_rounded,
                      value: _selectedKycStatus,
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All Types')),
                        DropdownMenuItem(value: 'not_verified', child: Text('🟣 Leads')),
                        DropdownMenuItem(value: 'verified', child: Text('🔵 Dealers')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedKycStatus = val);
                          _fetchCustomers(page: 1);
                        }
                      },
                    ),
                    if (hasActiveFilters)
                      InkWell(
                        onTap: _resetFilters,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          height: 36,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFECACA)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.filter_alt_off_rounded, size: 14, color: Color(0xFFDC2626)),
                              const SizedBox(width: 4),
                              Text(
                                'Reset',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFFDC2626),
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
    );
  }

  Widget _buildSearchInput() {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        style: GoogleFonts.outfit(
          fontSize: 13,
          color: const Color(0xFF0F172A),
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          hintText: 'Search by Name, Phone, Shop Name, City, Pincode...',
          hintStyle: GoogleFonts.outfit(
            color: const Color(0xFF94A3B8),
            fontSize: 12.5,
          ),
          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 18),
          prefixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          suffixIcon: _searchController.text.isNotEmpty
              ? InkWell(
                  onTap: () {
                    _searchController.clear();
                    _onSearchChanged('');
                  },
                  child: const Icon(Icons.clear_rounded, size: 16, color: Color(0xFF94A3B8)),
                )
              : null,
          suffixIconConstraints: const BoxConstraints(minWidth: 30, minHeight: 30),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildCompactDropdown({
    required String label,
    required IconData icon,
    required String value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    final hasValue = items.any((i) => i.value == value);
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF64748B)),
          const SizedBox(width: 4),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: hasValue ? value : (items.isNotEmpty ? items.first.value : null),
              items: items,
              onChanged: onChanged,
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1E293B),
              ),
              icon: const Icon(Icons.arrow_drop_down_rounded, size: 18, color: Color(0xFF64748B)),
              borderRadius: BorderRadius.circular(8),
              dense: true,
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // 4. Content Sliver (High-Density Compact Table or Cards)
  // -------------------------------------------------------------
  Widget _buildContentSliver(bool isDesktop) {
    if (_isLoading) {
      return SliverToBoxAdapter(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 40),
          alignment: Alignment.center,
          child: Column(
            children: [
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF008069)),
              ),
              const SizedBox(height: 12),
              Text(
                'Loading customer database...',
                style: GoogleFonts.outfit(color: const Color(0xFF64748B), fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return SliverToBoxAdapter(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFCA5A5)),
          ),
          child: Column(
            children: [
              const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 32),
              const SizedBox(height: 8),
              Text(
                'Failed to load customers',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 4),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(color: const Color(0xFF64748B), fontSize: 12.5),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => _fetchCustomers(page: _currentPage),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_search_rounded, size: 34, color: Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 12),
              Text(
                'No Customers Found',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'No records match your search or filter settings.',
                style: GoogleFonts.outfit(color: const Color(0xFF64748B), fontSize: 12.5),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _resetFilters,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
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
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Ensure table stretches 100% or horizontally scrolls on narrow viewports
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                    child: DataTable(
                      showCheckboxColumn: false,
                      headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                      headingRowHeight: 38,
                      dataRowMinHeight: 46,
                      dataRowMaxHeight: 52,
                      horizontalMargin: 16,
                      columnSpacing: 18,
                      dividerThickness: 1,
                      columns: [
                        DataColumn(label: Text('CUSTOMER', style: _compactHeaderStyle())),
                        DataColumn(label: Text('SHOP / LOCATION', style: _compactHeaderStyle())),
                        DataColumn(label: Text('STATUS & KYC', style: _compactHeaderStyle())),
                        DataColumn(label: Text('ASSIGNED AGENT', style: _compactHeaderStyle())),
                        DataColumn(label: Text('REGISTERED', style: _compactHeaderStyle())),
                        DataColumn(label: Text('ACTIONS', style: _compactHeaderStyle())),
                      ],
                      rows: _customers.map((c) => _buildCompactDataRow(c)).toList(),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
    } else {
      // Mobile / Tablet compact card list
      return SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => _buildCompactCustomerCard(_customers[index]),
          childCount: _customers.length,
        ),
      );
    }
  }

  TextStyle _compactHeaderStyle() {
    return GoogleFonts.outfit(
      fontWeight: FontWeight.w700,
      fontSize: 11,
      letterSpacing: 0.4,
      color: const Color(0xFF475569),
    );
  }

  DataRow _buildCompactDataRow(Map<String, dynamic> c) {
    final firstName = c['firstName'] ?? '';
    final lastName = c['lastName'] ?? '';
    final fullName = ('$firstName $lastName').trim().isNotEmpty ? ('$firstName $lastName').trim() : 'Unnamed User';
    final cleanPhone = _cleanPhone(c['phoneNumber']);
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
        // 1. Customer Name + Phone + Avatar
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: isDeleted
                    ? const Color(0xFFFEE2E2)
                    : AppTheme.primaryColor.withValues(alpha: 0.12),
                child: Text(
                  fullName.isNotEmpty ? fullName[0].toUpperCase() : 'U',
                  style: GoogleFonts.outfit(
                    color: isDeleted ? const Color(0xFFDC2626) : AppTheme.primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    fullName,
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                      color: isDeleted ? const Color(0xFF94A3B8) : const Color(0xFF0F172A),
                      decoration: isDeleted ? TextDecoration.lineThrough : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      Text(
                        cleanPhone,
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          color: const Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 3),
                      InkWell(
                        onTap: () => _copyToClipboard(cleanPhone, 'Phone number'),
                        child: const Icon(Icons.copy_rounded, size: 11, color: Color(0xFF94A3B8)),
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
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1E293B),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                location.isNotEmpty ? location : (address?['pincode'] ?? 'No address'),
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  color: const Color(0xFF64748B),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),

        // 3. Status & KYC Badges
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Active / Deleted pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isDeleted ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isDeleted ? const Color(0xFFFECACA) : const Color(0xFFBBF7D0),
                  ),
                ),
                child: Text(
                  isDeleted ? 'Deleted' : 'Active',
                  style: GoogleFonts.outfit(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: isDeleted ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              // Dealer / Lead pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isVerifiedDealer ? const Color(0xFFEFF6FF) : const Color(0xFFFAF5FF),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isVerifiedDealer ? const Color(0xFFBFDBFE) : const Color(0xFFE9D5FF),
                  ),
                ),
                child: Text(
                  isVerifiedDealer ? 'Dealer' : 'Lead',
                  style: GoogleFonts.outfit(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
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
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.support_agent_rounded, size: 14, color: Color(0xFF64748B)),
                    const SizedBox(width: 5),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${assignedAgent['firstName'] ?? ''} ${assignedAgent['lastName'] ?? ''}'.trim(),
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: const Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (assignedAgent['phoneNumber'] != null)
                          Text(
                            assignedAgent['phoneNumber'],
                            style: GoogleFonts.outfit(
                              fontSize: 10.5,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                      ],
                    ),
                  ],
                )
              : Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Text(
                    '⚠️ Unassigned',
                    style: GoogleFonts.outfit(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFD97706),
                    ),
                  ),
                ),
        ),

        // 5. Registered Date
        DataCell(
          Text(
            createdAt,
            style: GoogleFonts.outfit(
              fontSize: 11.5,
              color: const Color(0xFF64748B),
            ),
          ),
        ),

        // 6. Quick Actions (Call, WhatsApp, Inspect)
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Phone Call Shortcut
              IconButton(
                tooltip: 'Call $cleanPhone',
                icon: const Icon(Icons.phone_in_talk_rounded, size: 14),
                color: const Color(0xFF008069),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFE8F5E9),
                  padding: const EdgeInsets.all(6),
                  minimumSize: const Size(28, 28),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => _launchCall(cleanPhone),
              ),
              const SizedBox(width: 5),
              // WhatsApp Shortcut
              IconButton(
                tooltip: 'WhatsApp $cleanPhone',
                icon: const Icon(Icons.chat_bubble_rounded, size: 14),
                color: const Color(0xFF16A34A),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFF0FDF4),
                  padding: const EdgeInsets.all(6),
                  minimumSize: const Size(28, 28),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => _launchWhatsApp(cleanPhone),
              ),
              const SizedBox(width: 5),
              // Inspect Dossier
              IconButton(
                tooltip: 'Inspect Dossier',
                icon: const Icon(Icons.visibility_outlined, size: 15),
                color: const Color(0xFF2563EB),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFEFF6FF),
                  padding: const EdgeInsets.all(6),
                  minimumSize: const Size(28, 28),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => setState(() => _selectedCustomer = c),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // Mobile / Tablet Compact Card
  // -------------------------------------------------------------
  Widget _buildCompactCustomerCard(Map<String, dynamic> c) {
    final firstName = c['firstName'] ?? '';
    final lastName = c['lastName'] ?? '';
    final fullName = ('$firstName $lastName').trim().isNotEmpty ? ('$firstName $lastName').trim() : 'Unnamed User';
    final cleanPhone = _cleanPhone(c['phoneNumber']);
    final isDeleted = c['isDeleted'] == true;
    final isDealer = c['kycStatus'] == 'verified';
    final assignedAgent = c['assignedAgent'] as Map<String, dynamic>?;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
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
                  radius: 14,
                  backgroundColor: isDeleted ? const Color(0xFFFEE2E2) : AppTheme.primaryColor.withValues(alpha: 0.1),
                  child: Text(
                    fullName.isNotEmpty ? fullName[0].toUpperCase() : 'U',
                    style: GoogleFonts.outfit(
                      color: isDeleted ? const Color(0xFFDC2626) : AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fullName,
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        cleanPhone,
                        style: GoogleFonts.outfit(fontSize: 11.5, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDeleted ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isDeleted ? 'Deleted' : 'Active',
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isDeleted ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDealer ? const Color(0xFFEFF6FF) : const Color(0xFFFAF5FF),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isDealer ? 'Dealer' : 'Lead',
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isDealer ? const Color(0xFF2563EB) : const Color(0xFF9333EA),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 16, color: Color(0xFFF1F5F9)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  assignedAgent != null
                      ? 'Agent: ${assignedAgent['firstName'] ?? ''} ${assignedAgent['lastName'] ?? ''}'.trim()
                      : '⚠️ Unassigned',
                  style: GoogleFonts.outfit(
                    fontSize: 11.5,
                    color: assignedAgent != null ? const Color(0xFF475569) : const Color(0xFFD97706),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.phone_in_talk_rounded, size: 14),
                      color: const Color(0xFF008069),
                      onPressed: () => _launchCall(cleanPhone),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFFE8F5E9),
                        padding: const EdgeInsets.all(5),
                        minimumSize: const Size(26, 26),
                      ),
                    ),
                    const SizedBox(width: 5),
                    IconButton(
                      icon: const Icon(Icons.chat_bubble_rounded, size: 14),
                      color: const Color(0xFF16A34A),
                      onPressed: () => _launchWhatsApp(cleanPhone),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFFF0FDF4),
                        padding: const EdgeInsets.all(5),
                        minimumSize: const Size(26, 26),
                      ),
                    ),
                    const SizedBox(width: 5),
                    IconButton(
                      icon: const Icon(Icons.visibility_outlined, size: 14),
                      color: const Color(0xFF2563EB),
                      onPressed: () => setState(() => _selectedCustomer = c),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFFEFF6FF),
                        padding: const EdgeInsets.all(5),
                        minimumSize: const Size(26, 26),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // 5. Compact Pagination Bar
  // -------------------------------------------------------------
  Widget _buildCompactPaginationBar(bool isDesktop) {
    final int totalPages = (_totalCount / _limit).ceil();
    final int startItem = _totalCount == 0 ? 0 : (_currentPage - 1) * _limit + 1;
    final int endItem = ((_currentPage * _limit) > _totalCount) ? _totalCount : (_currentPage * _limit);

    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing $startItem–$endItem of ${NumberFormat.decimalPattern().format(_totalCount)} customers',
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: const Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
          Row(
            children: [
              // First page
              IconButton(
                icon: const Icon(Icons.first_page_rounded, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: _currentPage > 1 && !_isLoading
                    ? () => _fetchCustomers(page: 1)
                    : null,
              ),
              // Previous
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: _currentPage > 1 && !_isLoading
                    ? () => _fetchCustomers(page: _currentPage - 1)
                    : null,
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Page $_currentPage of ${totalPages == 0 ? 1 : totalPages}',
                  style: GoogleFonts.outfit(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E293B),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              // Next
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: _currentPage < totalPages && !_isLoading
                    ? () => _fetchCustomers(page: _currentPage + 1)
                    : null,
              ),
              // Last page
              IconButton(
                icon: const Icon(Icons.last_page_rounded, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: _currentPage < totalPages && !_isLoading
                    ? () => _fetchCustomers(page: totalPages)
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // 6. Polished Executive Customer Dossier (Inspector Drawer)
  // -------------------------------------------------------------
  Widget _buildCustomerInspectorDrawer(bool isDesktop) {
    final c = _selectedCustomer!;
    final customerId = c['_id'] ?? '';
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
        color: Colors.black.withValues(alpha: 0.35),
        child: Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onTap: () {}, // Prevent dismissal when tapping drawer
            child: Container(
              width: isDesktop ? 440 : MediaQuery.of(context).size.width * 0.9,
              height: double.infinity,
              color: Colors.white,
              child: Column(
                children: [
                  // Compact Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8FAFC),
                      border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: isDeleted ? const Color(0xFFFEE2E2) : AppTheme.primaryColor.withValues(alpha: 0.12),
                          child: Text(
                            fullName.isNotEmpty ? fullName[0].toUpperCase() : 'U',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: isDeleted ? const Color(0xFFDC2626) : AppTheme.primaryColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                fullName,
                                style: GoogleFonts.outfit(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF0F172A),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
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
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          onPressed: () => setState(() => _selectedCustomer = null),
                        ),
                      ],
                    ),
                  ),

                  // Quick Action Bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => _launchCall(cleanPhone),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              height: 32,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F5E9),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFC8E6C9)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.phone_in_talk_rounded, size: 14, color: Color(0xFF008069)),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Call',
                                    style: GoogleFonts.outfit(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF008069),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: InkWell(
                            onTap: () => _launchWhatsApp(cleanPhone),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              height: 32,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0FDF4),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFBBF7D0)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.chat_bubble_rounded, size: 14, color: Color(0xFF16A34A)),
                                  const SizedBox(width: 4),
                                  Text(
                                    'WhatsApp',
                                    style: GoogleFonts.outfit(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF16A34A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: InkWell(
                            onTap: () => _copyToClipboard(cleanPhone, 'Phone number'),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              height: 32,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.copy_rounded, size: 14, color: Color(0xFF64748B)),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Copy',
                                    style: GoogleFonts.outfit(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF475569),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Drawer Body Scroll
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      children: [
                        // Status Pills Row
                        Row(
                          children: [
                            Expanded(
                              child: _buildCompactInfoBadge(
                                label: 'Status',
                                value: isDeleted ? 'Deleted Account' : 'Active Account',
                                icon: isDeleted ? Icons.cancel_rounded : Icons.check_circle_rounded,
                                color: isDeleted ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                                bgColor: isDeleted ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildCompactInfoBadge(
                                label: 'Account Type',
                                value: isDealer ? 'Verified Dealer' : 'Lead (Pending KYC)',
                                icon: isDealer ? Icons.verified_user_rounded : Icons.person_outline_rounded,
                                color: isDealer ? const Color(0xFF2563EB) : const Color(0xFF9333EA),
                                bgColor: isDealer ? const Color(0xFFEFF6FF) : const Color(0xFFFAF5FF),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Assigned Sales Agent Card (With Quick Reassignment!)
                        _buildCompactSectionCard(
                          title: 'Assigned Sales Agent',
                          icon: Icons.support_agent_rounded,
                          trailing: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isDense: true,
                              hint: Text(
                                'Reassign',
                                style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.primaryColor),
                              ),
                              items: [
                                const DropdownMenuItem(
                                  value: 'none',
                                  child: Text('⚠️ Unassigned (None)'),
                                ),
                                ..._salesAgents.map((agent) {
                                  final name = agent['agentName'] ?? 'Agent';
                                  return DropdownMenuItem(
                                    value: agent['agentId'].toString(),
                                    child: Text(name),
                                  );
                                }),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  _reassignAgent(customerId, val == 'none' ? null : val);
                                }
                              },
                              style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF1E293B)),
                            ),
                          ),
                          child: assignedAgent != null
                              ? Column(
                                  children: [
                                    _buildCompactDetailRow('Agent Name', '${assignedAgent['firstName'] ?? ''} ${assignedAgent['lastName'] ?? ''}'.trim()),
                                    _buildCompactDetailRow('Agent Phone', assignedAgent['phoneNumber'] ?? 'N/A'),
                                    _buildCompactDetailRow('Agent Email', assignedAgent['email'] ?? 'N/A'),
                                    if (c['assignedAt'] != null)
                                      _buildCompactDetailRow('Assigned On', DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.tryParse(c['assignedAt']) ?? DateTime.now())),
                                  ],
                                )
                              : Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFFBEB),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFFFDE68A)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.info_outline_rounded, color: Color(0xFFD97706), size: 16),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Customer is unassigned. Select an agent above to assign.',
                                          style: GoogleFonts.outfit(
                                            fontSize: 11.5,
                                            color: const Color(0xFFB45309),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                        ),

                        const SizedBox(height: 12),

                        // Contact & Business Details
                        _buildCompactSectionCard(
                          title: 'Contact & Business Details',
                          icon: Icons.storefront_rounded,
                          child: Column(
                            children: [
                              _buildCompactDetailRow('Shop / Business', c['shopName'] ?? 'Individual'),
                              _buildCompactDetailRow('Email', c['email'] ?? 'No email provided'),
                              _buildCompactDetailRow('Address Type', c['addressType'] ?? 'Home'),
                              _buildCompactDetailRow('Village / Area', address?['villageArea'] ?? 'N/A'),
                              _buildCompactDetailRow('City / Tehsil', address?['cityTehsil'] ?? 'N/A'),
                              _buildCompactDetailRow('State', address?['state'] ?? 'N/A'),
                              _buildCompactDetailRow('Pincode', address?['pincode'] ?? 'N/A'),
                              _buildCompactDetailRow('Source', c['source'] ?? 'App'),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),

                        // System Timeline
                        _buildCompactSectionCard(
                          title: 'Timeline & System History',
                          icon: Icons.history_rounded,
                          child: Column(
                            children: [
                              _buildCompactDetailRow(
                                'Registered On',
                                c['createdAt'] != null
                                    ? DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.tryParse(c['createdAt']) ?? DateTime.now())
                                    : 'N/A',
                              ),
                              _buildCompactDetailRow(
                                'Last Updated',
                                c['updatedAt'] != null
                                    ? DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.tryParse(c['updatedAt']) ?? DateTime.now())
                                    : 'N/A',
                              ),
                              if (isDeleted) ...[
                                _buildCompactDetailRow(
                                  'Deleted On',
                                  c['deletedAt'] != null
                                      ? DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.tryParse(c['deletedAt']) ?? DateTime.now())
                                      : 'N/A',
                                ),
                                _buildCompactDetailRow('Deleted By', c['deletedByAdminName'] ?? 'Admin'),
                              ],
                            ],
                          ),
                        ),

                        // Notes History (if any)
                        if (notesHistory.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _buildCompactSectionCard(
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
                                  margin: const EdgeInsets.only(bottom: 6),
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(6),
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
                                              fontSize: 11.5,
                                              color: const Color(0xFF334155),
                                            ),
                                          ),
                                          Text(
                                            date,
                                            style: GoogleFonts.outfit(
                                              fontSize: 10.5,
                                              color: const Color(0xFF94A3B8),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        noteText,
                                        style: GoogleFonts.outfit(
                                          fontSize: 11.5,
                                          color: const Color(0xFF475569),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
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

  Widget _buildCompactInfoBadge({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 10.5,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 12,
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

  Widget _buildCompactSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, size: 15, color: const Color(0xFF64748B)),
                  const SizedBox(width: 6),
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              if (trailing != null) trailing,
            ],
          ),
          const Divider(height: 14, color: Color(0xFFF1F5F9)),
          child,
        ],
      ),
    );
  }

  Widget _buildCompactDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 11.5,
                color: const Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 12,
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

// -------------------------------------------------------------
// Compact KPI Tile Component
// -------------------------------------------------------------
class _CompactKpiItem extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final bool isActive;
  final VoidCallback onTap;

  const _CompactKpiItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.bgColor,
    this.isActive = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isActive ? color : const Color(0xFFE2E8F0),
              width: isActive ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isActive ? color.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.015),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(icon, color: color, size: 17),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.outfit(
                        fontSize: 10.5,
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      NumberFormat.compact().format(value),
                      style: GoogleFonts.outfit(
                        fontSize: 15,
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
