import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kd_pannel/app_theme.dart';
import 'package:kd_pannel/core/network/api_client.dart';
import 'package:kd_pannel/core/responsive/responsive.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/leads_bloc.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/leads_event.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/leads_state.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/dealers_bloc.dart';
import 'package:http/http.dart' as http;

class TeamManagementPage extends StatefulWidget {
  const TeamManagementPage({super.key});

  @override
  State<TeamManagementPage> createState() => _TeamManagementPageState();
}

class _TeamManagementPageState extends State<TeamManagementPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isActionLoading = false;
  int _currentPage = 1;
  final int _pageSize = 10;
  late TabController _tabController;

  List<Map<String, dynamic>> _deletedUsersList = [];
  bool _isLoadingDeletedUsers = false;
  DateTimeRange? _conversionDateRange;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && mounted) {
        setState(() {});
      }
    });
    _fetchDeletedUsers();
  }

  Future<void> _fetchDeletedUsers() async {
    if (_isLoadingDeletedUsers) return;
    setState(() => _isLoadingDeletedUsers = true);
    try {
      final res = await ApiClient().get('/users?trash=true&role=user&limit=1000');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true || data['users'] != null) {
          final list = List<Map<String, dynamic>>.from(data['users'] ?? []);
          if (mounted) {
            setState(() {
              _deletedUsersList = list;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('[TeamManagementPage] Error fetching deleted users: $e');
    } finally {
      if (mounted) setState(() => _isLoadingDeletedUsers = false);
    }
  }

  bool _isWithinDateRange(dynamic dateVal) {
    if (_conversionDateRange == null) return true;
    if (dateVal == null) return false;

    DateTime? dt;
    if (dateVal is DateTime) {
      dt = dateVal;
    } else if (dateVal is String) {
      dt = DateTime.tryParse(dateVal);
    } else if (dateVal is Map) {
      final d = dateVal['\$date'] ?? dateVal['date'];
      if (d is String) dt = DateTime.tryParse(d);
    }

    if (dt == null) return false;

    final start = DateTime(
      _conversionDateRange!.start.year,
      _conversionDateRange!.start.month,
      _conversionDateRange!.start.day,
      0, 0, 0,
    );
    final end = DateTime(
      _conversionDateRange!.end.year,
      _conversionDateRange!.end.month,
      _conversionDateRange!.end.day,
      23, 59, 59, 999,
    );

    return dt.isAfter(start.subtract(const Duration(milliseconds: 1))) &&
        dt.isBefore(end.add(const Duration(milliseconds: 1)));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _triggerBlocRefresh() {
    context.read<LeadsBloc>().add(
      const FetchLeadsDataEvent(forceRefresh: true),
    );
  }

  Future<void> _deleteSalesAgent(String agentId, String agentName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Sales Agent',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        content: Text(
          'Are you sure you want to delete $agentName? This agent will be removed and automatically unassigned from all their assigned leads and dealers.',
          style: GoogleFonts.outfit(
            color: AppTheme.textSecondary,
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.outfit(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isActionLoading = true);
    try {
      final res = await ApiClient().delete('/users/sales/$agentId');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Sales agent deleted successfully'),
                backgroundColor: AppTheme.success,
              ),
            );
          }
          _triggerBlocRefresh();
        } else {
          throw Exception(data['message'] ?? 'Failed to delete agent');
        }
      } else {
        throw Exception('Server returned code: ${res.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  void _showSalesAgentFormDialog({Map<String, dynamic>? agent}) {
    final isEdit = agent != null;
    final formKey = GlobalKey<FormState>();
    final firstNameController = TextEditingController(
      text: agent?['firstName'] ?? '',
    );
    final lastNameController = TextEditingController(
      text: agent?['lastName'] ?? '',
    );
    final emailController = TextEditingController(text: agent?['email'] ?? '');
    final phoneController = TextEditingController(
      text: agent?['phoneNumber'] ?? '',
    );
    final passwordController = TextEditingController();
    bool obscurePassword = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setStateDialog) {
          return AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              isEdit ? 'Edit Sales Agent' : 'Create Sales Agent',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: firstNameController,
                      decoration: _buildInputDecoration(
                        'First Name',
                        Icons.person_outline,
                      ),
                      validator: (val) =>
                          val == null || val.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: lastNameController,
                      decoration: _buildInputDecoration(
                        'Last Name',
                        Icons.person_outline,
                      ),
                      validator: (val) =>
                          val == null || val.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: emailController,
                      decoration: _buildInputDecoration(
                        'Email Address',
                        Icons.email_outlined,
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (val) => val == null || !val.contains('@')
                          ? 'Invalid email'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: phoneController,
                      decoration: _buildInputDecoration(
                        'Phone Number',
                        Icons.phone_outlined,
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (val) =>
                          val == null || val.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: passwordController,
                      decoration: _buildInputDecoration(
                        isEdit ? 'New Password (Optional)' : 'Password',
                        Icons.lock_outline,
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 20,
                            color: AppTheme.textSecondary,
                          ),
                          onPressed: () {
                            setStateDialog(() {
                              obscurePassword = !obscurePassword;
                            });
                          },
                        ),
                      ),
                      obscureText: obscurePassword,
                      validator: (val) {
                        if (isEdit && (val == null || val.isEmpty)) return null;
                        if (val == null || val.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.outfit(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: _isActionLoading
                    ? null
                    : () async {
                        if (formKey.currentState!.validate()) {
                          setStateDialog(() => _isActionLoading = true);
                          try {
                            final payload = {
                              'firstName': firstNameController.text.trim(),
                              'lastName': lastNameController.text.trim(),
                              'email': emailController.text.trim(),
                              'phoneNumber': phoneController.text.trim(),
                            };
                            if (passwordController.text.isNotEmpty) {
                              payload['password'] = passwordController.text;
                            }

                            final http.Response res;
                            if (isEdit) {
                              res = await ApiClient().put(
                                '/users/sales/${agent['_id']}',
                                payload,
                              );
                            } else {
                              res = await ApiClient().post(
                                '/users/sales',
                                payload,
                              );
                            }

                            if (res.statusCode == 200 ||
                                res.statusCode == 201) {
                              final data = jsonDecode(res.body);
                              if (data['success'] == true) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        isEdit
                                            ? 'Sales agent updated successfully'
                                            : 'Sales agent created successfully',
                                      ),
                                      backgroundColor: AppTheme.success,
                                    ),
                                  );
                                }
                                if (dialogCtx.mounted) {
                                  Navigator.pop(dialogCtx);
                                }
                                _triggerBlocRefresh();
                              } else {
                                throw Exception(
                                  data['message'] ?? 'Action failed',
                                );
                              }
                            } else {
                              final data = jsonDecode(res.body);
                              throw Exception(
                                data['message'] ??
                                    'Server returned code: ${res.statusCode}',
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: $e'),
                                  backgroundColor: AppTheme.error,
                                ),
                              );
                            }
                          } finally {
                            setStateDialog(() => _isActionLoading = false);
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isActionLoading
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(isEdit ? 'Update' : 'Create'),
              ),
            ],
          );
        },
      ),
    );
  }

  InputDecoration _buildInputDecoration(
    String label,
    IconData icon, {
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.outfit(
        color: AppTheme.textSecondary,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      prefixIcon: Icon(icon, size: 18, color: AppTheme.primaryColor),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.borderColor, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.error, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.error, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);
    final isMobile = Responsive.isMobile(context);

    return BlocBuilder<LeadsBloc, LeadsState>(
      builder: (context, state) {
        final allSalesAgents = state.allRawUsers
            .where((u) => u['role'] == 'sales')
            .toList();

        final filteredAgents = allSalesAgents.where((agent) {
          final name = '${agent['firstName'] ?? ''} ${agent['lastName'] ?? ''}'
              .toLowerCase();
          final email = (agent['email'] ?? '').toLowerCase();
          final phone = (agent['phoneNumber'] ?? '').toLowerCase();
          final query = _searchQuery.toLowerCase();
          return name.contains(query) ||
              email.contains(query) ||
              phone.contains(query);
        }).toList();

        // Dynamically compute assigned leads/dealers counts
        final Map<String, int> leadsCountMap = {};
        final Map<String, int> dealersCountMap = {};

        for (final user in state.allRawUsers) {
          if (user['role'] == 'user' && user['assignedAgent'] != null) {
            final agentId =
                user['assignedAgent']['_id'] ?? user['assignedAgent'];
            if (agentId is String) {
              final isVerified = user['kycStatus'] == 'verified';
              if (isVerified) {
                dealersCountMap[agentId] = (dealersCountMap[agentId] ?? 0) + 1;
              } else {
                leadsCountMap[agentId] = (leadsCountMap[agentId] ?? 0) + 1;
              }
            }
          }
        }

        final totalPages = (filteredAgents.length / _pageSize).ceil();
        final int displayPages = totalPages > 0 ? totalPages : 1;
        if (_currentPage > displayPages) {
          _currentPage = displayPages;
        }
        final int startIndex = ((_currentPage - 1) * _pageSize).clamp(
          0,
          filteredAgents.length,
        );
        final int endIndex = (startIndex + _pageSize).clamp(
          0,
          filteredAgents.length,
        );
        final paginatedAgents = filteredAgents.isEmpty
            ? <Map<String, dynamic>>[]
            : filteredAgents.sublist(startIndex, endIndex);

        final Widget bodyContent = SelectionArea(
          child:
              (state.status == LeadsStatus.loading && state.allRawUsers.isEmpty)
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(80.0),
                    child: CircularProgressIndicator(
                      color: AppTheme.primaryColor,
                    ),
                  ),
                )
              : ScrollConfiguration(
                  behavior: ScrollConfiguration.of(
                    context,
                  ).copyWith(scrollbars: false),
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isDesktop ? 28 : 16,
                        vertical: isDesktop ? 20 : 12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          // Page Header Title, Description, and Tab Bar
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Team Management',
                                    style: GoogleFonts.outfit(
                                      fontSize: isMobile ? 20 : 26,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _tabController.index == 0
                                        ? 'Monitor and coordinate your sales agent team assignments.'
                                        : 'Track sales agent performance and lead-to-dealer conversions.',
                                    style: GoogleFonts.outfit(
                                      fontSize: isMobile ? 12 : 14,
                                      color: AppTheme.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                height: 42,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFFE2E8F0),
                                  ),
                                ),
                                padding: const EdgeInsets.all(4),
                                child: TabBar(
                                  controller: _tabController,
                                  isScrollable: true,
                                  tabAlignment: TabAlignment.start,
                                  indicator: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.05,
                                        ),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  indicatorSize: TabBarIndicatorSize.tab,
                                  labelColor: AppTheme.primaryColor,
                                  unselectedLabelColor: AppTheme.textSecondary,
                                  labelStyle: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                  unselectedLabelStyle: GoogleFonts.outfit(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                  dividerColor: Colors.transparent,
                                  labelPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  tabs: const [
                                    Tab(
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.group_rounded, size: 16),
                                          SizedBox(width: 8),
                                          Text('Team Members'),
                                        ],
                                      ),
                                    ),
                                    Tab(
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.trending_up_rounded,
                                            size: 16,
                                          ),
                                          SizedBox(width: 8),
                                          Text('Lead Dealer Conversion'),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          if (_tabController.index == 1)
                            _buildConversionsTab(
                              context,
                              state,
                              isDesktop,
                              isMobile,
                            )
                          else ...[
                            // Stats Summary Row
                            Row(
                              children: [
                                Expanded(
                                  child: _buildSummaryCard(
                                    'Total Sales Agents',
                                    allSalesAgents.length.toString(),
                                    Icons.group_outlined,
                                    Colors.green,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildSummaryCard(
                                    'Assigned Leads',
                                    state.allRawUsers
                                        .where(
                                          (u) =>
                                              u['role'] == 'user' &&
                                              u['kycStatus'] != 'verified' &&
                                              u['assignedAgent'] != null,
                                        )
                                        .length
                                        .toString(),
                                    Icons.campaign_outlined,
                                    Colors.blue,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildSummaryCard(
                                    'Assigned Dealers',
                                    state.allRawUsers
                                        .where(
                                          (u) =>
                                              u['role'] == 'user' &&
                                              u['kycStatus'] == 'verified' &&
                                              u['assignedAgent'] != null,
                                        )
                                        .length
                                        .toString(),
                                    Icons.storefront_outlined,
                                    Colors.teal,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),

                            // Search and Actions Bar
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppTheme.borderColor),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      height: 42,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF9FAFB),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: AppTheme.borderColor,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.search,
                                            size: 18,
                                            color: AppTheme.textSecondary,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: TextField(
                                              controller: _searchController,
                                              style: GoogleFonts.outfit(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: AppTheme.textPrimary,
                                              ),
                                              onChanged: (val) {
                                                setState(() {
                                                  _searchQuery = val;
                                                  _currentPage = 1;
                                                });
                                              },
                                              decoration: InputDecoration(
                                                hintText:
                                                    'Search by name, email or phone...',
                                                hintStyle: GoogleFonts.outfit(
                                                  fontSize: 14,
                                                  color: AppTheme.textSecondary,
                                                  fontWeight: FontWeight.w400,
                                                ),
                                                border: InputBorder.none,
                                                isDense: true,
                                                contentPadding: EdgeInsets.zero,
                                              ),
                                            ),
                                          ),
                                          if (_searchQuery.isNotEmpty)
                                            IconButton(
                                              icon: const Icon(
                                                Icons.clear,
                                                size: 16,
                                              ),
                                              padding: EdgeInsets.zero,
                                              constraints:
                                                  const BoxConstraints(),
                                              onPressed: () {
                                                _searchController.clear();
                                                setState(() {
                                                  _searchQuery = '';
                                                  _currentPage = 1;
                                                });
                                              },
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  SizedBox(
                                    height: 42,
                                    child: ElevatedButton.icon(
                                      onPressed: () =>
                                          _showSalesAgentFormDialog(),
                                      icon: const Icon(Icons.add, size: 18),
                                      label: Text(
                                        'Add Sales Agent',
                                        style: GoogleFonts.outfit(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.primaryColor,
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 20,
                                        ),
                                        minimumSize: const Size(0, 42),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Main List/Table View
                            if (filteredAgents.isEmpty)
                              Container(
                                height: 200,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: AppTheme.borderColor,
                                  ),
                                ),
                                child: Text(
                                  _searchQuery.isEmpty
                                      ? 'No sales agents found'
                                      : 'No matching sales agents found',
                                  style: GoogleFonts.outfit(
                                    color: AppTheme.textSecondary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              )
                            else
                              SelectionContainer.disabled(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    if (isMobile)
                                      ListView.builder(
                                        shrinkWrap: true,
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        itemCount: paginatedAgents.length,
                                        itemBuilder: (context, index) {
                                          final agent = paginatedAgents[index];
                                          final agentId = agent['_id'] ?? '';
                                          final name =
                                              '${agent['firstName'] ?? ''} ${agent['lastName'] ?? ''}'
                                                  .trim();
                                          final email = agent['email'] ?? '-';
                                          final phone =
                                              agent['phoneNumber'] ?? '-';
                                          final leadsCount =
                                              leadsCountMap[agentId] ?? 0;
                                          final dealersCount =
                                              dealersCountMap[agentId] ?? 0;

                                          return Card(
                                            margin: const EdgeInsets.only(
                                              bottom: 12,
                                            ),
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              side: const BorderSide(
                                                color: AppTheme.borderColor,
                                              ),
                                            ),
                                            color: Colors.white,
                                            clipBehavior: Clip.antiAlias,
                                            child: InkWell(
                                              onTap: () {
                                                Navigator.pushNamed(
                                                  context,
                                                  '/team/profile',
                                                  arguments: agent,
                                                );
                                              },
                                              child: Padding(
                                                padding: const EdgeInsets.all(
                                                  16,
                                                ),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        CircleAvatar(
                                                          backgroundColor:
                                                              AppTheme
                                                                  .primaryColor
                                                                  .withOpacity(
                                                                    0.12,
                                                                  ),
                                                          radius: 20,
                                                          child: Text(
                                                            name.isNotEmpty
                                                                ? name[0]
                                                                      .toUpperCase()
                                                                : 'S',
                                                            style: GoogleFonts.outfit(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color: AppTheme
                                                                  .primaryColor,
                                                              fontSize: 14,
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          width: 12,
                                                        ),
                                                        Expanded(
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              Text(
                                                                name,
                                                                style: GoogleFonts.outfit(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  fontSize: 14,
                                                                  color: AppTheme
                                                                      .textPrimary,
                                                                ),
                                                              ),
                                                              Text(
                                                                phone,
                                                                style: GoogleFonts.outfit(
                                                                  fontSize: 12,
                                                                  color: AppTheme
                                                                      .textSecondary,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        IconButton(
                                                          icon: const Icon(
                                                            Icons.edit_outlined,
                                                            size: 18,
                                                            color: Colors.blue,
                                                          ),
                                                          onPressed: () =>
                                                              _showSalesAgentFormDialog(
                                                                agent: agent,
                                                              ),
                                                        ),
                                                        IconButton(
                                                          icon: const Icon(
                                                            Icons
                                                                .delete_outline_rounded,
                                                            size: 18,
                                                            color:
                                                                AppTheme.error,
                                                          ),
                                                          onPressed: () =>
                                                              _deleteSalesAgent(
                                                                agentId,
                                                                name,
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                    const Divider(height: 24),
                                                    Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .spaceBetween,
                                                      children: [
                                                        Text(
                                                          email,
                                                          style: GoogleFonts.outfit(
                                                            fontSize: 12,
                                                            color: AppTheme
                                                                .textSecondary,
                                                          ),
                                                        ),
                                                        Row(
                                                          children: [
                                                            _buildMiniBadge(
                                                              'Leads: $leadsCount',
                                                              Colors.blue,
                                                            ),
                                                            const SizedBox(
                                                              width: 8,
                                                            ),
                                                            _buildMiniBadge(
                                                              'Dealers: $dealersCount',
                                                              Colors.teal,
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      )
                                    else
                                      // Desktop Table View
                                      Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          border: Border.all(
                                            color: AppTheme.borderColor,
                                          ),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          child: Table(
                                            columnWidths: const {
                                              0: FlexColumnWidth(3.5),
                                              1: FlexColumnWidth(2.0),
                                              2: FlexColumnWidth(1.5),
                                              3: FlexColumnWidth(1.5),
                                              4: FlexColumnWidth(1.5),
                                            },
                                            defaultVerticalAlignment:
                                                TableCellVerticalAlignment
                                                    .middle,
                                            children: [
                                              // Table Header Row
                                              TableRow(
                                                decoration: const BoxDecoration(
                                                  color: Color(0xFFF8FAFC),
                                                  border: Border(
                                                    bottom: BorderSide(
                                                      color:
                                                          AppTheme.borderColor,
                                                    ),
                                                  ),
                                                ),
                                                children: [
                                                  _buildTableHeaderCell(
                                                    'Sales Agent',
                                                  ),
                                                  _buildTableHeaderCell(
                                                    'Contact Info',
                                                  ),
                                                  _buildTableHeaderCell(
                                                    'Leads',
                                                  ),
                                                  _buildTableHeaderCell(
                                                    'Dealers',
                                                  ),
                                                  _buildTableHeaderCell(
                                                    'Actions',
                                                    alignRight: true,
                                                  ),
                                                ],
                                              ),
                                              // Table Data Rows
                                              ...paginatedAgents.asMap().entries.map((
                                                entry,
                                              ) {
                                                final index = entry.key;
                                                final agent = entry.value;
                                                final agentId =
                                                    agent['_id'] ?? '';
                                                final name =
                                                    '${agent['firstName'] ?? ''} ${agent['lastName'] ?? ''}'
                                                        .trim();
                                                final email =
                                                    agent['email'] ?? '-';
                                                final phone =
                                                    agent['phoneNumber'] ?? '-';
                                                final leadsCount =
                                                    leadsCountMap[agentId] ?? 0;
                                                final dealersCount =
                                                    dealersCountMap[agentId] ??
                                                    0;

                                                final isAlternate = index.isOdd;
                                                final rowBgColor = isAlternate
                                                    ? const Color(0xFFFAFBFC)
                                                    : Colors.white;

                                                final onTap = () {
                                                  Navigator.pushNamed(
                                                    context,
                                                    '/team/profile',
                                                    arguments: agent,
                                                  );
                                                };

                                                return TableRow(
                                                  decoration: BoxDecoration(
                                                    color: rowBgColor,
                                                    border: const Border(
                                                      bottom: BorderSide(
                                                        color: Color(
                                                          0xFFF1F5F9,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  children: [
                                                    InkWell(
                                                      onTap: onTap,
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 16,
                                                              vertical: 12,
                                                            ),
                                                        child: Row(
                                                          children: [
                                                            CircleAvatar(
                                                              backgroundColor:
                                                                  AppTheme
                                                                      .primaryColor
                                                                      .withOpacity(
                                                                        0.12,
                                                                      ),
                                                              radius: 18,
                                                              child: Text(
                                                                name.isNotEmpty
                                                                    ? name[0]
                                                                          .toUpperCase()
                                                                    : 'S',
                                                                style: GoogleFonts.outfit(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  color: AppTheme
                                                                      .primaryColor,
                                                                  fontSize: 12,
                                                                ),
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                              width: 12,
                                                            ),
                                                            Expanded(
                                                              child: Column(
                                                                crossAxisAlignment:
                                                                    CrossAxisAlignment
                                                                        .start,
                                                                children: [
                                                                  Text(
                                                                    name,
                                                                    style: GoogleFonts.outfit(
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                      color: AppTheme
                                                                          .textPrimary,
                                                                      fontSize:
                                                                          13.5,
                                                                    ),
                                                                  ),
                                                                  const SizedBox(
                                                                    height: 2,
                                                                  ),
                                                                  Text(
                                                                    email,
                                                                    style: GoogleFonts.outfit(
                                                                      fontSize:
                                                                          11,
                                                                      color: AppTheme
                                                                          .textSecondary,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w400,
                                                                    ),
                                                                    maxLines: 1,
                                                                    overflow:
                                                                        TextOverflow
                                                                            .ellipsis,
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                    InkWell(
                                                      onTap: onTap,
                                                      child: _buildTableCell(
                                                        phone,
                                                      ),
                                                    ),
                                                    InkWell(
                                                      onTap: onTap,
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 16,
                                                            ),
                                                        child: Align(
                                                          alignment: Alignment
                                                              .centerLeft,
                                                          child: _buildBadge(
                                                            leadsCount
                                                                .toString(),
                                                            Colors.blue,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    InkWell(
                                                      onTap: onTap,
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 16,
                                                            ),
                                                        child: Align(
                                                          alignment: Alignment
                                                              .centerLeft,
                                                          child: _buildBadge(
                                                            dealersCount
                                                                .toString(),
                                                            Colors.teal,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 16,
                                                            vertical: 10,
                                                          ),
                                                      child: Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .end,
                                                        children: [
                                                          _buildRowActionButton(
                                                            icon: Icons
                                                                .edit_outlined,
                                                            tooltip:
                                                                'Edit Agent',
                                                            color: Colors.blue,
                                                            onPressed: () =>
                                                                _showSalesAgentFormDialog(
                                                                  agent: agent,
                                                                ),
                                                          ),
                                                          const SizedBox(
                                                            width: 8,
                                                          ),
                                                          _buildRowActionButton(
                                                            icon: Icons
                                                                .delete_outline_rounded,
                                                            tooltip:
                                                                'Delete Agent',
                                                            color:
                                                                AppTheme.error,
                                                            onPressed: () =>
                                                                _deleteSalesAgent(
                                                                  agentId,
                                                                  name,
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                );
                                              }),
                                            ],
                                          ),
                                        ),
                                      ),
                                    if (filteredAgents.length > _pageSize) ...[
                                      const SizedBox(height: 24),
                                      _buildPaginationControls(
                                        _currentPage,
                                        filteredAgents.length,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
        );

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          body: bodyContent,
        );
      },
    );
  }

  Widget _buildConversionsTab(
    BuildContext context,
    LeadsState state,
    bool isDesktop,
    bool isMobile,
  ) {
    final dealersState = context.watch<DealersBloc>().state;
    final allOrders = dealersState.allRawOrders;

    final allSalesAgents = state.allRawUsers
        .where((u) => u['role'] == 'sales')
        .toList();

    final filteredAgents = allSalesAgents.where((agent) {
      final name = '${agent['firstName'] ?? ''} ${agent['lastName'] ?? ''}'
          .toLowerCase();
      final email = (agent['email'] ?? '').toLowerCase();
      final phone = (agent['phoneNumber'] ?? '').toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query) ||
          email.contains(query) ||
          phone.contains(query);
    }).toList();

    final Map<String, List<Map<String, dynamic>>> convertedDealersMap = {};
    final Map<String, List<Map<String, dynamic>>> activeLeadsMap = {};
    final Map<String, List<Map<String, dynamic>>> deletedLeadsMap = {};
    final Map<String, Set<String>> dealersWithOrdersMap = {};
    final Map<String, int> agentOrdersCountMap = {};

    int totalTeamConversions = 0;
    int totalTeamDeletedLeads = 0;
    int totalTeamOrders = 0;

    final List<Map<String, dynamic>> combinedUsers = [
      ...state.allRawUsers,
      ..._deletedUsersList,
    ];
    final Set<String> processedUserIds = {};

    for (final user in combinedUsers) {
      final uid = (user['_id'] ?? user['\$oid'] ?? user['id'])?.toString();
      if (uid != null && processedUserIds.contains(uid)) continue;
      if (uid != null) processedUserIds.add(uid);

      final isDeleted =
          user['isDeleted'] == true || user['status'] == 'deleted' || user['trash'] == true;
      final agentIdObj = user['assignedAgent'];
      String? agentId;
      if (agentIdObj is Map) {
        agentId = (agentIdObj['_id'] ?? agentIdObj['\$oid'] ?? agentIdObj['id'])
            ?.toString();
      } else if (agentIdObj is String) {
        agentId = agentIdObj;
      }

      if (agentId != null && agentId.isNotEmpty) {
        if (isDeleted) {
          final deletedDate = user['deletedAt'] ?? user['updatedAt'] ?? user['createdAt'];
          if (_isWithinDateRange(deletedDate)) {
            deletedLeadsMap.putIfAbsent(agentId, () => []).add(user);
            totalTeamDeletedLeads++;
          }
        } else if (user['role'] == 'user') {
          final isVerified = user['kycStatus'] == 'verified';
          if (isVerified) {
            final approvedDate = user['kycApprovedAt'] ?? user['updatedAt'] ?? user['createdAt'];
            if (_isWithinDateRange(approvedDate)) {
              convertedDealersMap.putIfAbsent(agentId, () => []).add(user);
              totalTeamConversions++;
            }
          } else {
            final assignedDate = user['assignedAt'] ?? user['createdAt'];
            if (_isWithinDateRange(assignedDate)) {
              activeLeadsMap.putIfAbsent(agentId, () => []).add(user);
            }
          }
        }
      }
    }

    // Process orders to calculate dealer-to-order ratio
    for (final order in allOrders) {
      if (order['orderStatus'] == 'Cancelled') continue;
      final orderDate = order['createdAt'] ?? order['orderDate'];
      if (!_isWithinDateRange(orderDate)) continue;

      final userObj = order['user'];
      if (userObj == null) continue;

      String? userId;
      if (userObj is Map) {
        userId = (userObj['_id'] ?? userObj['\$oid'] ?? userObj['id'])
            ?.toString();
      } else if (userObj is String) {
        userId = userObj;
      }

      if (userId == null || userId.isEmpty) continue;

      // Find sales agent of this dealer
      for (final entry in convertedDealersMap.entries) {
        final agentId = entry.key;
        final dealersList = entry.value;
        final isDealerOfAgent = dealersList.any((d) {
          final dId = (d['_id'] ?? d['\$oid'] ?? d['id'])?.toString();
          return dId == userId;
        });

        if (isDealerOfAgent) {
          dealersWithOrdersMap.putIfAbsent(agentId, () => {}).add(userId);
          agentOrdersCountMap[agentId] =
              (agentOrdersCountMap[agentId] ?? 0) + 1;
          totalTeamOrders++;
          break;
        }
      }
    }

    int totalDealersWithOrdersCount = dealersWithOrdersMap.values
        .fold<Set<String>>({}, (prev, set) => prev..addAll(set))
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                'Converted Dealers',
                totalTeamConversions.toString(),
                Icons.verified_rounded,
                const Color(0xFF10B981),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildSummaryCard(
                'Dealers Who Ordered',
                '$totalDealersWithOrdersCount of $totalTeamConversions',
                Icons.shopping_cart_checkout_rounded,
                const Color(0xFF8B5CF6),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildSummaryCard(
                'Total Dealer Orders',
                '$totalTeamOrders Orders',
                Icons.shopping_bag_rounded,
                const Color(0xFF0284C7),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildSummaryCard(
                'Deleted Leads',
                totalTeamDeletedLeads.toString(),
                Icons.delete_sweep_rounded,
                const Color(0xFFF43F5E),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _buildDateFilterRow(),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.search,
                        size: 18,
                        color: AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                          onChanged: (val) {
                            setState(() {
                              _searchQuery = val;
                            });
                          },
                          decoration: InputDecoration(
                            hintText:
                                'Search conversion stats & ratios by sales agent...',
                            hintStyle: GoogleFonts.outfit(
                              fontSize: 14,
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w400,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      if (_searchQuery.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (filteredAgents.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.sentiment_dissatisfied_rounded,
                  size: 48,
                  color: AppTheme.textSecondary,
                ),
                const SizedBox(height: 12),
                Text(
                  'No sales agents found matching your query',
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredAgents.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final agent = filteredAgents[index];
              final agentId = agent['_id']?.toString() ?? '';
              final convertedDealers = convertedDealersMap[agentId] ?? [];
              final activeLeads = activeLeadsMap[agentId] ?? [];
              final deletedLeads = deletedLeadsMap[agentId] ?? [];
              final totalAssigned =
                  convertedDealers.length + activeLeads.length;
              final double conversionRate = totalAssigned > 0
                  ? (convertedDealers.length / totalAssigned) * 100
                  : 0.0;

              final dealersWithOrdersSet = dealersWithOrdersMap[agentId] ?? {};
              final agentOrdersCount = agentOrdersCountMap[agentId] ?? 0;
              final double ordersPerDealer = convertedDealers.isNotEmpty
                  ? (agentOrdersCount / convertedDealers.length)
                  : 0.0;
              final double dealerOrderActivationRate =
                  convertedDealers.isNotEmpty
                  ? (dealersWithOrdersSet.length / convertedDealers.length) *
                        100
                  : 0.0;

              final agentName =
                  '${agent['firstName'] ?? ''} ${agent['lastName'] ?? ''}'
                      .trim();
              final name = agentName.isNotEmpty
                  ? agentName
                  : (agent['shopName'] ?? agent['email'] ?? 'Sales Agent');

              return _buildAgentConversionCard(
                context,
                agent: agent,
                name: name,
                convertedDealers: convertedDealers,
                activeLeadsCount: activeLeads.length,
                deletedLeads: deletedLeads,
                totalAssigned: totalAssigned,
                conversionRate: conversionRate,
                dealersWithOrdersCount: dealersWithOrdersSet.length,
                totalDealerOrders: agentOrdersCount,
                ordersPerDealer: ordersPerDealer,
                dealerOrderActivationRate: dealerOrderActivationRate,
                allOrders: allOrders,
              );
            },
          ),
      ],
    );
  }

  Widget _buildDateFilterRow() {
    String selectedPreset = 'All Time';
    if (_conversionDateRange != null) {
      final now = DateTime.now();
      final start = _conversionDateRange!.start;
      final end = _conversionDateRange!.end;
      final diffDays = end.difference(start).inDays;

      if (start.year == now.year &&
          start.month == now.month &&
          start.day == now.day &&
          end.year == now.year &&
          end.month == now.month &&
          end.day == now.day) {
        selectedPreset = 'Today';
      } else if (diffDays >= 6 && diffDays <= 7) {
        selectedPreset = 'Last 7 Days';
      } else if (diffDays >= 29 && diffDays <= 31) {
        selectedPreset = 'Last 30 Days';
      } else {
        selectedPreset = 'Custom';
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.calendar_today_rounded,
            size: 16,
            color: AppTheme.primaryColor,
          ),
          const SizedBox(width: 8),
          Text(
            'Timeframe: ',
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildDateFilterPill(
                  'All Time',
                  selectedPreset == 'All Time',
                  () {
                    setState(() => _conversionDateRange = null);
                  },
                ),
                _buildDateFilterPill(
                  'Today',
                  selectedPreset == 'Today',
                  () {
                    final now = DateTime.now();
                    setState(
                      () => _conversionDateRange =
                          DateTimeRange(start: now, end: now),
                    );
                  },
                ),
                _buildDateFilterPill(
                  'Last 7 Days',
                  selectedPreset == 'Last 7 Days',
                  () {
                    final now = DateTime.now();
                    setState(
                      () => _conversionDateRange = DateTimeRange(
                        start: now.subtract(const Duration(days: 7)),
                        end: now,
                      ),
                    );
                  },
                ),
                _buildDateFilterPill(
                  'Last 30 Days',
                  selectedPreset == 'Last 30 Days',
                  () {
                    final now = DateTime.now();
                    setState(
                      () => _conversionDateRange = DateTimeRange(
                        start: now.subtract(const Duration(days: 30)),
                        end: now,
                      ),
                    );
                  },
                ),
                _buildDateFilterPill(
                  _conversionDateRange != null && selectedPreset == 'Custom'
                      ? '${_conversionDateRange!.start.day}/${_conversionDateRange!.start.month} - ${_conversionDateRange!.end.day}/${_conversionDateRange!.end.month}'
                      : 'Custom Range 📅',
                  selectedPreset == 'Custom',
                  () async {
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      initialDateRange: _conversionDateRange ??
                          DateTimeRange(
                            start: DateTime.now().subtract(
                              const Duration(days: 30),
                            ),
                            end: DateTime.now(),
                          ),
                    );
                    if (picked != null) {
                      setState(() => _conversionDateRange = picked);
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateFilterPill(
    String label,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryColor
                : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildAgentConversionCard(
    BuildContext context, {
    required Map<String, dynamic> agent,
    required String name,
    required List<Map<String, dynamic>> convertedDealers,
    required int activeLeadsCount,
    required List<Map<String, dynamic>> deletedLeads,
    required int totalAssigned,
    required double conversionRate,
    required int dealersWithOrdersCount,
    required int totalDealerOrders,
    required double ordersPerDealer,
    required double dealerOrderActivationRate,
    required List<Map<String, dynamic>> allOrders,
  }) {
    Color rateBadgeColor;
    Color rateBgColor;
    if (conversionRate >= 25.0) {
      rateBadgeColor = const Color(0xFF10B981);
      rateBgColor = const Color(0xFFECFDF5);
    } else if (conversionRate >= 10.0) {
      rateBadgeColor = const Color(0xFFF59E0B);
      rateBgColor = const Color(0xFFFFFBEB);
    } else {
      rateBadgeColor = const Color(0xFF64748B);
      rateBgColor = const Color(0xFFF8FAFC);
    }

    final email = agent['email'] ?? 'No email';
    final phone = agent['phoneNumber'] ?? 'No phone';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: SelectionContainer.disabled(
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
              childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              leading: CircleAvatar(
                backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
                radius: 24,
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'S',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                    fontSize: 16,
                  ),
                ),
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$email • $phone',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: rateBgColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: rateBadgeColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.trending_up_rounded,
                              size: 14,
                              color: rateBadgeColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${convertedDealers.length} Converted Dealers',
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: rateBadgeColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3E8FF),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFD8B4FE)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.shopping_cart_checkout_rounded,
                              size: 13,
                              color: Color(0xFF7E22CE),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$dealersWithOrdersCount of ${convertedDealers.length} Dealers Ordered ($totalDealerOrders Orders)',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF7E22CE),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    _buildStatPill(
                      'Converted Dealers',
                      '${convertedDealers.length}',
                      Icons.check_circle_rounded,
                      const Color(0xFF10B981),
                    ),
                    _buildStatPill(
                      'Active Leads',
                      '$activeLeadsCount',
                      Icons.campaign_rounded,
                      const Color(0xFF0284C7),
                    ),
                    _buildStatPill(
                      'Dealers Who Ordered',
                      '$dealersWithOrdersCount of ${convertedDealers.length}',
                      Icons.shopping_cart_checkout_rounded,
                      const Color(0xFF8B5CF6),
                    ),
                    _buildStatPill(
                      'Total Orders',
                      '$totalDealerOrders Orders',
                      Icons.shopping_bag_rounded,
                      const Color(0xFF7E22CE),
                    ),
                    _buildStatPill(
                      'Deleted Leads',
                      '${deletedLeads.length}',
                      Icons.delete_outline_rounded,
                      const Color(0xFFF43F5E),
                    ),
                  ],
                ),
              ),
              children: [
                const Divider(height: 1, color: AppTheme.borderColor),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Converted Dealers (${convertedDealers.length})',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      '$dealersWithOrdersCount of ${convertedDealers.length} Dealers Placed Orders ($totalDealerOrders Orders Total)',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: const Color(0xFF7E22CE),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (convertedDealers.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Center(
                      child: Text(
                        'No lead-to-dealer conversions recorded yet for this sales agent.',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: convertedDealers.length,
                    separatorBuilder: (context, idx) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, idx) {
                      final dealer = convertedDealers[idx];
                      final dId =
                          (dealer['_id'] ?? dealer['\$oid'] ?? dealer['id'])
                              ?.toString();
                      final dFirstName = dealer['firstName'] ?? '';
                      final dLastName = dealer['lastName'] ?? '';
                      final dPersonName = '$dFirstName $dLastName'.trim();
                      final dShop = (dealer['shopName'] ?? '').toString();
                      final dPhone =
                          (dealer['phoneNumber'] ?? dealer['phone'] ?? '')
                              .toString();
                      final dTitle = dPersonName.isNotEmpty
                          ? dPersonName
                          : (dShop.isNotEmpty
                                ? dShop
                                : (dPhone.isNotEmpty
                                      ? dPhone
                                      : 'Verified Dealer'));

                      final dealerOrdersCount = allOrders.where((o) {
                        if (o['orderStatus'] == 'Cancelled') return false;
                        final u = o['user'];
                        if (u == null) return false;
                        final uId =
                            (u is Map ? (u['_id'] ?? u['\$oid'] ?? u['id']) : u)
                                ?.toString();
                        return uId == dId;
                      }).length;

                      final address =
                          dealer['address'] as Map<String, dynamic>?;
                      final city =
                          address?['cityTehsil'] ?? dealer['city'] ?? '';
                      final stateStr =
                          address?['state'] ?? dealer['state'] ?? '';
                      final location = [
                        city,
                        stateStr,
                      ].where((s) => s.toString().isNotEmpty).join(', ');

                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.verified_rounded,
                              size: 18,
                              color: Color(0xFF10B981),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    dTitle,
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                  if (dShop.isNotEmpty && dShop != dTitle)
                                    Text(
                                      dShop,
                                      style: GoogleFonts.outfit(
                                        fontSize: 11,
                                        color: AppTheme.textSecondary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: dealerOrdersCount > 0
                                    ? const Color(0xFFF3E8FF)
                                    : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: dealerOrdersCount > 0
                                      ? const Color(0xFFD8B4FE)
                                      : const Color(0xFFCBD5E1),
                                ),
                              ),
                              child: Text(
                                dealerOrdersCount > 0
                                    ? '$dealerOrdersCount Orders'
                                    : 'No Orders',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: dealerOrdersCount > 0
                                      ? const Color(0xFF7E22CE)
                                      : AppTheme.textSecondary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            if (dPhone.isNotEmpty) ...[
                              Text(
                                dPhone,
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                            if (location.isNotEmpty) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: const Color(0xFFCBD5E1),
                                  ),
                                ),
                                child: Text(
                                  location,
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                if (deletedLeads.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      const Icon(
                        Icons.delete_outline_rounded,
                        size: 16,
                        color: Color(0xFFF43F5E),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Deleted Leads (${deletedLeads.length})',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFF43F5E),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: deletedLeads.length,
                    separatorBuilder: (context, idx) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, idx) {
                      final dLead = deletedLeads[idx];
                      final lFirstName = dLead['firstName'] ?? '';
                      final lLastName = dLead['lastName'] ?? '';
                      final lPersonName = '$lFirstName $lLastName'.trim();
                      final lPhone =
                          (dLead['phoneNumber'] ?? dLead['phone'] ?? '')
                              .toString();
                      final lTitle = lPersonName.isNotEmpty
                          ? lPersonName
                          : (lPhone.isNotEmpty ? lPhone : 'Deleted Lead');

                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF1F2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFECDD3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.remove_circle_outline_rounded,
                              size: 16,
                              color: Color(0xFFE11D48),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                lTitle,
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFFBE123C),
                                ),
                              ),
                            ),
                            if (lPhone.isNotEmpty)
                              Text(
                                lPhone,
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFFBE123C),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatPill(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            '$label: ',
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeaderCell(String text, {bool alignRight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Align(
        alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
        child: Text(
          text.toUpperCase(),
          style: GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
            color: const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildTableCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Text(
        text,
        style: GoogleFonts.outfit(
          fontSize: 13,
          color: AppTheme.textBody,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildMiniBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: GoogleFonts.outfit(
          fontSize: 10.5,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildBadge(String countText, Color baseColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: baseColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: baseColor.withOpacity(0.18), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(shape: BoxShape.circle, color: baseColor),
          ),
          const SizedBox(width: 6),
          Text(
            countText,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: baseColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRowActionButton({
    required IconData icon,
    required String tooltip,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      textStyle: GoogleFonts.outfit(fontSize: 11, color: Colors.white),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              color: Colors.white,
            ),
            child: Icon(icon, size: 16, color: color),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaginationControls(int currentPage, int total) {
    final int totalPages = (total / _pageSize).ceil();
    final int displayPages = totalPages > 0 ? totalPages : 1;

    List<Widget> pageButtons = [];

    if (displayPages <= 5) {
      for (int i = 1; i <= displayPages; i++) {
        pageButtons.add(
          _PageNumberButton(
            page: i,
            isActive: currentPage == i,
            onTap: () {
              setState(() {
                _currentPage = i;
              });
            },
          ),
        );
        if (i < displayPages) {
          pageButtons.add(const SizedBox(width: 8));
        }
      }
    } else {
      pageButtons.add(
        _PageNumberButton(
          page: 1,
          isActive: currentPage == 1,
          onTap: () {
            setState(() {
              _currentPage = 1;
            });
          },
        ),
      );
      pageButtons.add(const SizedBox(width: 8));

      if (currentPage > 3) {
        pageButtons.add(
          Text(
            '...',
            style: GoogleFonts.outfit(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
        pageButtons.add(const SizedBox(width: 8));
      }

      final start = (currentPage - 1).clamp(2, displayPages - 1);
      final end = (currentPage + 1).clamp(2, displayPages - 1);

      for (int i = start; i <= end; i++) {
        if (i > 1 && i < displayPages) {
          pageButtons.add(
            _PageNumberButton(
              page: i,
              isActive: currentPage == i,
              onTap: () {
                setState(() {
                  _currentPage = i;
                });
              },
            ),
          );
          pageButtons.add(const SizedBox(width: 8));
        }
      }

      if (currentPage < displayPages - 2) {
        pageButtons.add(
          Text(
            '...',
            style: GoogleFonts.outfit(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
        pageButtons.add(const SizedBox(width: 8));
      }

      pageButtons.add(
        _PageNumberButton(
          page: displayPages,
          isActive: currentPage == displayPages,
          onTap: () {
            setState(() {
              _currentPage = displayPages;
            });
          },
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _PaginationButton(
          onTap: currentPage > 1
              ? () {
                  setState(() {
                    _currentPage = currentPage - 1;
                  });
                }
              : null,
          icon: Icons.chevron_left,
          isDisabled: currentPage <= 1,
        ),
        const SizedBox(width: 12),
        ...pageButtons,
        const SizedBox(width: 12),
        _PaginationButton(
          onTap: currentPage < displayPages
              ? () {
                  setState(() {
                    _currentPage = currentPage + 1;
                  });
                }
              : null,
          icon: Icons.chevron_right,
          isDisabled: currentPage >= displayPages,
        ),
      ],
    );
  }
}

class _PageNumberButton extends StatefulWidget {
  final int page;
  final bool isActive;
  final VoidCallback? onTap;

  const _PageNumberButton({
    required this.page,
    required this.isActive,
    this.onTap,
  });

  @override
  State<_PageNumberButton> createState() => _PageNumberButtonState();
}

class _PageNumberButtonState extends State<_PageNumberButton> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: widget.isActive
                ? AppTheme.primaryColor
                : (isHovered ? const Color(0xFFF3F4F6) : Colors.white),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: widget.isActive
                  ? AppTheme.primaryColor
                  : AppTheme.borderColor,
            ),
          ),
          child: Text(
            '${widget.page}',
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: widget.isActive ? Colors.white : AppTheme.textBody,
            ),
          ),
        ),
      ),
    );
  }
}

class _PaginationButton extends StatefulWidget {
  final VoidCallback? onTap;
  final IconData icon;
  final bool isDisabled;

  const _PaginationButton({
    required this.onTap,
    required this.icon,
    this.isDisabled = false,
  });

  @override
  State<_PaginationButton> createState() => _PaginationButtonState();
}

class _PaginationButtonState extends State<_PaginationButton> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.isDisabled
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      child: GestureDetector(
        onTap: widget.isDisabled ? null : widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: widget.isDisabled
                ? Colors.white
                : (isHovered ? const Color(0xFFF3F4F6) : Colors.white),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Icon(
            widget.icon,
            size: 18,
            color: widget.isDisabled
                ? const Color(0xFFD1D5DB)
                : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}
