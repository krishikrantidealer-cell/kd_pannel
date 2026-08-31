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
import 'package:kd_pannel/core/auth/auth_service.dart';
import 'package:kd_pannel/core/repositories/user_repository.dart';
import 'package:kd_pannel/core/utils/currency_utils.dart';
import 'package:shimmer/shimmer.dart';
import 'package:http/http.dart' as http;

class TeamManagementPage extends StatefulWidget {
  const TeamManagementPage({super.key});

  @override
  State<TeamManagementPage> createState() => _TeamManagementPageState();
}

class _TeamManagementPageState extends State<TeamManagementPage> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _permissionSearchController = TextEditingController();
  String _searchQuery = '';
  String _permissionSearchQuery = '';
  bool _isActionLoading = false;
  int _currentPage = 1;
  final int _pageSize = 10;
  int _selectedTabIndex = 0;

  static final Map<String, Map<String, dynamic>> _persistedPermissionsCache = {};
  final Map<String, Map<String, dynamic>> _agentPermissionsState = {};
  final Set<String> _savingPermissionAgentIds = {};

  List<Map<String, dynamic>> _deletedUsersList = [];
  bool _isLoadingDeletedUsers = false;
  DateTimeRange? _conversionDateRange;

  @override
  void initState() {
    super.initState();
    _fetchDeletedUsers();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final leadsBloc = context.read<LeadsBloc>();
      if (leadsBloc.state.status == LeadsStatus.initial ||
          leadsBloc.state.salesAgents.isEmpty) {
        leadsBloc.add(const FetchLeadsDataEvent(forceRefresh: true));
      }
    });
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
    } catch (_) {
      // Graceful fallback
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
    _searchController.dispose();
    _permissionSearchController.dispose();
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

        final bool isInitialOrLoading =
            (state.status == LeadsStatus.loading ||
                    state.status == LeadsStatus.initial) &&
                state.allRawUsers.isEmpty;

        final Widget bodyContent = SelectionArea(
          child: isInitialOrLoading
              ? _buildShimmerLoading(isDesktop, isMobile)
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
                                     _selectedTabIndex == 0
                                         ? 'Monitor and coordinate your sales agent team assignments.'
                                         : (_selectedTabIndex == 1
                                             ? 'Track sales agent performance and lead-to-dealer conversions.'
                                             : 'Configure granular Lead and Dealer action permissions for sales agents.'),
                                     style: GoogleFonts.outfit(
                                       fontSize: isMobile ? 12 : 14,
                                       color: AppTheme.textSecondary,
                                       fontWeight: FontWeight.w500,
                                     ),
                                   ),
                                 ],
                               ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _buildTabSelector(isMobile),
                                    const SizedBox(width: 8),
                                    Container(
                                      height: 38,
                                      width: 38,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: AppTheme.borderColor,
                                        ),
                                      ),
                                      child: IconButton(
                                        tooltip: 'Refresh Team Data',
                                        padding: EdgeInsets.zero,
                                        icon: state.status == LeadsStatus.loading
                                            ? const SizedBox(
                                                width: 16,
                                                height: 16,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: AppTheme.primaryColor,
                                                ),
                                              )
                                            : const Icon(
                                                Icons.refresh_rounded,
                                                size: 18,
                                                color: AppTheme.textSecondary,
                                              ),
                                        onPressed: () {
                                          _fetchDeletedUsers();
                                          context.read<LeadsBloc>().add(
                                                const FetchLeadsDataEvent(
                                                  forceRefresh: true,
                                                ),
                                              );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                             ],
                           ),
                           const SizedBox(height: 20),

                           if (_selectedTabIndex == 2)
                             _buildPermissionsTab(
                               context,
                               state,
                               isDesktop,
                               isMobile,
                             )
                           else if (_selectedTabIndex == 1)
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
    final Map<String, double> agentSalesAmountMap = {};
    final Map<String, double> dealerSalesAmountMap = {};

    int totalTeamConversions = 0;
    int totalTeamDeletedLeads = 0;
    int totalTeamOrders = 0;
    double totalTeamSalesAmount = 0.0;

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

    final Map<String, String> dealerIdToAgentIdMap = {};
    for (final entry in convertedDealersMap.entries) {
      for (final dealer in entry.value) {
        final dId = (dealer['_id'] ?? dealer['\$oid'] ?? dealer['id'])?.toString();
        if (dId != null && dId.isNotEmpty) {
          dealerIdToAgentIdMap[dId] = entry.key;
        }
      }
    }

    final Map<String, int> dealerOrdersCountMap = {};

    // Process orders in O(1) per order using the inverted index
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

      final double orderAmount = CurrencyUtils.parse(
        order['totalAmount'] ?? order['grandTotal'] ?? 0,
      );

      final agentId = dealerIdToAgentIdMap[userId];
      if (agentId != null) {
        dealersWithOrdersMap.putIfAbsent(agentId, () => {}).add(userId);
        agentOrdersCountMap[agentId] =
            (agentOrdersCountMap[agentId] ?? 0) + 1;
        agentSalesAmountMap[agentId] =
            (agentSalesAmountMap[agentId] ?? 0.0) + orderAmount;
        dealerSalesAmountMap[userId] =
            (dealerSalesAmountMap[userId] ?? 0.0) + orderAmount;
        dealerOrdersCountMap[userId] =
            (dealerOrdersCountMap[userId] ?? 0) + 1;
        totalTeamOrders++;
        totalTeamSalesAmount += orderAmount;
      }
    }

    int totalDealersWithOrdersCount = dealersWithOrdersMap.values
        .fold<Set<String>>({}, (prev, set) => prev..addAll(set))
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isDesktop)
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
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  'Dealers Ordered',
                  '$totalDealersWithOrdersCount of $totalTeamConversions',
                  Icons.shopping_cart_checkout_rounded,
                  const Color(0xFF8B5CF6),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  'Total Orders',
                  '$totalTeamOrders Orders',
                  Icons.shopping_bag_rounded,
                  const Color(0xFF0284C7),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  'Total Sales Revenue',
                  CurrencyUtils.formatInr(totalTeamSalesAmount),
                  Icons.currency_rupee_rounded,
                  const Color(0xFF059669),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  'Deleted Leads',
                  totalTeamDeletedLeads.toString(),
                  Icons.delete_sweep_rounded,
                  const Color(0xFFF43F5E),
                ),
              ),
            ],
          )
        else
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: (MediaQuery.of(context).size.width - 48) / 2,
                child: _buildSummaryCard(
                  'Converted Dealers',
                  totalTeamConversions.toString(),
                  Icons.verified_rounded,
                  const Color(0xFF10B981),
                ),
              ),
              SizedBox(
                width: (MediaQuery.of(context).size.width - 48) / 2,
                child: _buildSummaryCard(
                  'Dealers Ordered',
                  '$totalDealersWithOrdersCount of $totalTeamConversions',
                  Icons.shopping_cart_checkout_rounded,
                  const Color(0xFF8B5CF6),
                ),
              ),
              SizedBox(
                width: (MediaQuery.of(context).size.width - 48) / 2,
                child: _buildSummaryCard(
                  'Total Orders',
                  '$totalTeamOrders Orders',
                  Icons.shopping_bag_rounded,
                  const Color(0xFF0284C7),
                ),
              ),
              SizedBox(
                width: (MediaQuery.of(context).size.width - 48) / 2,
                child: _buildSummaryCard(
                  'Total Sales Revenue',
                  CurrencyUtils.formatInr(totalTeamSalesAmount),
                  Icons.currency_rupee_rounded,
                  const Color(0xFF059669),
                ),
              ),
              SizedBox(
                width: (MediaQuery.of(context).size.width - 48) / 2,
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

              final double agentSalesAmount = agentSalesAmountMap[agentId] ?? 0.0;

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
                totalSalesAmount: agentSalesAmount,
                dealerSalesAmountMap: dealerSalesAmountMap,
                dealerOrdersCountMap: dealerOrdersCountMap,
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
    required double totalSalesAmount,
    required Map<String, double> dealerSalesAmountMap,
    required Map<String, int> dealerOrdersCountMap,
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
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFFA7F3D0),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.payments_outlined,
                                  size: 14,
                                  color: Color(0xFF059669),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${CurrencyUtils.formatInr(totalSalesAmount)} Total Sales',
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF059669),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
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
                        ],
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
                child: Builder(
                  builder: (context) {
                    final int directOnboardedCount = convertedDealers.where((d) {
                      final via = (d['createdVia'] ?? '').toString().toLowerCase();
                      final src = (d['source'] ?? '').toString().toLowerCase();
                      return via == 'panel' || (src == 'kd panel' && via != 'lead_conversion');
                    }).length;
                    final int leadUpgradeCount = convertedDealers.where((d) {
                      final via = (d['createdVia'] ?? '').toString().toLowerCase();
                      return via == 'lead_conversion';
                    }).length;

                    return Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        _buildStatPill(
                          'Total Sales',
                          CurrencyUtils.formatInr(totalSalesAmount),
                          Icons.currency_rupee_rounded,
                          const Color(0xFF059669),
                        ),
                        _buildStatPill(
                          'Converted Dealers',
                          '${convertedDealers.length}',
                          Icons.check_circle_rounded,
                          const Color(0xFF10B981),
                        ),
                        if (directOnboardedCount > 0)
                          _buildStatPill(
                            'Direct Onboarded',
                            '$directOnboardedCount',
                            Icons.person_add_alt_1_rounded,
                            const Color(0xFF0284C7),
                          ),
                        if (leadUpgradeCount > 0)
                          _buildStatPill(
                            'Lead Upgrades',
                            '$leadUpgradeCount',
                            Icons.published_with_changes_rounded,
                            const Color(0xFF059669),
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
                        if (totalDealerOrders > 0)
                          _buildStatPill(
                            'Avg Order Value',
                            CurrencyUtils.formatInr(totalSalesAmount / totalDealerOrders),
                            Icons.auto_graph_rounded,
                            const Color(0xFFD97706),
                          ),
                        _buildStatPill(
                          'Deleted Leads',
                          '${deletedLeads.length}',
                          Icons.delete_outline_rounded,
                          const Color(0xFFF43F5E),
                        ),
                      ],
                    );
                  },
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
                      '$dealersWithOrdersCount of ${convertedDealers.length} Dealers Placed Orders ($totalDealerOrders Orders Total · ${CurrencyUtils.formatInr(totalSalesAmount)})',
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

                      final String createdVia =
                          (dealer['createdVia'] ?? '').toString().toLowerCase();
                      final String source =
                          (dealer['source'] ?? '').toString();
                      final bool isDirectOnboard = createdVia == 'panel' ||
                          (source == 'KD Panel' &&
                              createdVia != 'lead_conversion');
                      final bool isLeadUpgrade =
                          createdVia == 'lead_conversion';

                      final int dealerOrdersCount =
                          (dId != null) ? (dealerOrdersCountMap[dId] ?? 0) : 0;

                      final double dealerSales = (dId != null)
                          ? (dealerSalesAmountMap[dId] ?? 0.0)
                          : 0.0;

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
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          dTitle,
                                          style: GoogleFonts.outfit(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.textPrimary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isDirectOnboard
                                              ? const Color(0xFFE0F2FE)
                                              : (isLeadUpgrade
                                                  ? const Color(0xFFDCFCE7)
                                                  : const Color(0xFFF1F5F9)),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                          border: Border.all(
                                            color: isDirectOnboard
                                                ? const Color(0xFFBAE6FD)
                                                : (isLeadUpgrade
                                                    ? const Color(0xFFBBF7D0)
                                                    : const Color(
                                                        0xFFE2E8F0,
                                                      )),
                                          ),
                                        ),
                                        child: Text(
                                          isDirectOnboard
                                              ? 'Direct Onboard'
                                              : (isLeadUpgrade
                                                  ? 'Lead Upgraded'
                                                  : 'App Verified'),
                                          style: GoogleFonts.outfit(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: isDirectOnboard
                                                ? const Color(0xFF0369A1)
                                                : (isLeadUpgrade
                                                    ? const Color(0xFF15803D)
                                                    : const Color(
                                                        0xFF475569,
                                                      )),
                                          ),
                                        ),
                                      ),
                                    ],
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
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: dealerSales > 0
                                    ? const Color(0xFFECFDF5)
                                    : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: dealerSales > 0
                                      ? const Color(0xFFA7F3D0)
                                      : const Color(0xFFCBD5E1),
                                ),
                              ),
                              child: Text(
                                dealerSales > 0
                                    ? CurrencyUtils.formatInr(dealerSales)
                                    : '₹0 Sales',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: dealerSales > 0
                                      ? const Color(0xFF059669)
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

  Widget _buildShimmerLoading(bool isDesktop, bool isMobile) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 28 : 16,
        vertical: isDesktop ? 20 : 12,
      ),
      child: Shimmer.fromColors(
        baseColor: const Color(0xFFE5E7EB),
        highlightColor: const Color(0xFFF9FAFB),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            // Header Row Shimmer
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 28,
                      width: 220,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 16,
                      width: 320,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ],
                ),
                Container(
                  height: 42,
                  width: 150,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Tabs Bar Shimmer
            Container(
              height: 46,
              width: isDesktop ? 400 : double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(height: 24),
            // KPI Summary Cards Shimmer
            if (isDesktop)
              Row(
                children: List.generate(
                  4,
                  (index) => Expanded(
                    child: Container(
                      height: 84,
                      margin: EdgeInsets.only(right: index < 3 ? 12 : 0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              )
            else
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: List.generate(
                  4,
                  (index) => Container(
                    width: (MediaQuery.of(context).size.width - 48) / 2,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 20),
            // Search / Filter Bar Shimmer
            Container(
              height: 52,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            const SizedBox(height: 20),
            // Team Member Cards list Shimmer
            ...List.generate(
              4,
              (index) => Container(
                height: 140,
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // SEGMENTED TAB SELECTOR (100% Smooth 60fps)
  // ==========================================

  Widget _buildTabSelector(bool isMobile) {
    final tabs = [
      {'title': 'Team Members', 'icon': Icons.group_rounded},
      {'title': 'Lead Dealer Conversion', 'icon': Icons.trending_up_rounded},
      {'title': 'Permissions', 'icon': Icons.security_rounded},
    ];

    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(tabs.length, (index) {
            final isSelected = _selectedTabIndex == index;
            final tab = tabs[index];
            return Padding(
              padding: EdgeInsets.only(right: index < tabs.length - 1 ? 4 : 0),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    if (_selectedTabIndex != index) {
                      setState(() {
                        _selectedTabIndex = index;
                      });
                    }
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeInOutCubic,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          tab['icon'] as IconData,
                          size: 16,
                          color: isSelected
                              ? AppTheme.primaryColor
                              : AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          tab['title'] as String,
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w600,
                            color: isSelected
                                ? AppTheme.primaryColor
                                : AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  // ==========================================
  // PERMISSIONS TAB IMPLEMENTATION
  // ==========================================

  bool _toBool(dynamic val, {bool defaultValue = false}) {
    if (val == null) return defaultValue;
    if (val is bool) return val;
    if (val is num) return val == 1;
    if (val is String) {
      final s = val.toLowerCase().trim();
      if (s == 'true' || s == '1') return true;
      if (s == 'false' || s == '0') return false;
    }
    return defaultValue;
  }

  Map<String, dynamic> _getAgentPermissions(Map<String, dynamic> agent) {
    final agentId = agent['_id']?.toString() ?? '';
    if (agentId.isNotEmpty && _persistedPermissionsCache.containsKey(agentId)) {
      return _persistedPermissionsCache[agentId]!;
    }
    if (_agentPermissionsState.containsKey(agentId)) {
      return _agentPermissionsState[agentId]!;
    }
    dynamic raw = agent['permissions'];
    if (raw is String) {
      try {
        raw = jsonDecode(raw);
      } catch (_) {}
    }
    if (raw is Map) {
      final leadMap = raw['lead'] is Map
          ? Map<String, dynamic>.from(raw['lead'])
          : (raw['leads'] is Map
              ? Map<String, dynamic>.from(raw['leads'])
              : <String, dynamic>{});
      final dealerMap = raw['dealer'] is Map
          ? Map<String, dynamic>.from(raw['dealer'])
          : (raw['dealers'] is Map
              ? Map<String, dynamic>.from(raw['dealers'])
              : <String, dynamic>{});
      final perms = {
        'lead': {
          'create': _toBool(leadMap['create'], defaultValue: true),
          'update': _toBool(leadMap['update'], defaultValue: true),
          'reassign': _toBool(leadMap['reassign'], defaultValue: false),
          'delete': _toBool(leadMap['delete'], defaultValue: true),
        },
        'dealer': {
          'create': _toBool(dealerMap['create'], defaultValue: true),
          'update': _toBool(dealerMap['update'], defaultValue: true),
          'reassign': _toBool(dealerMap['reassign'], defaultValue: false),
          'delete': _toBool(dealerMap['delete'], defaultValue: true),
        }
      };
      if (agentId.isNotEmpty) {
        _persistedPermissionsCache[agentId] = perms;
      }
      return perms;
    }
    final defaultPerms = {
      'lead': {
        'create': true,
        'update': true,
        'reassign': false,
        'delete': true,
      },
      'dealer': {
        'create': true,
        'update': true,
        'reassign': false,
        'delete': true,
      }
    };
    if (agentId.isNotEmpty) {
      _persistedPermissionsCache[agentId] = defaultPerms;
    }
    return defaultPerms;
  }

  Future<void> _toggleAgentPermission(
    Map<String, dynamic> agent,
    String module,
    String action,
    bool newValue,
  ) async {
    final agentId = agent['_id']?.toString() ?? '';
    if (agentId.isEmpty) return;

    final currentPerms = _getAgentPermissions(agent);
    final updatedPerms = {
      'lead': Map<String, dynamic>.from(currentPerms['lead'] ?? {}),
      'dealer': Map<String, dynamic>.from(currentPerms['dealer'] ?? {}),
    };
    updatedPerms[module]?[action] = newValue;

    setState(() {
      _persistedPermissionsCache[agentId] = updatedPerms;
      _agentPermissionsState[agentId] = updatedPerms;
      agent['permissions'] = updatedPerms;
      _savingPermissionAgentIds.add(agentId);
    });

    try {
      var res = await ApiClient().put('/users/$agentId', {
        'permissions': updatedPerms,
      });
      if (res.statusCode != 200 && res.statusCode != 201) {
        res = await ApiClient().put('/users/sales/$agentId', {
          'permissions': updatedPerms,
        });
      }

      if (res.statusCode == 200 || res.statusCode == 201) {
        _persistedPermissionsCache[agentId] = updatedPerms;
        agent['permissions'] = updatedPerms;
        UserRepository().invalidateCache();
        if (AuthService().currentUserId == agentId) {
          AuthService().updatePermissions(updatedPerms);
        }

        final agentName =
            '${agent['firstName'] ?? ''} ${agent['lastName'] ?? ''}'.trim();
        final actionDisplay = action[0].toUpperCase() + action.substring(1);
        final moduleDisplay = module[0].toUpperCase() + module.substring(1);
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(
                    newValue
                        ? Icons.check_circle_outline
                        : Icons.remove_circle_outline,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$moduleDisplay $actionDisplay permission ${newValue ? 'granted to' : 'revoked from'} $agentName',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              backgroundColor:
                  newValue ? AppTheme.primaryColor : const Color(0xFF334155),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      } else {
        throw Exception('Server returned status ${res.statusCode}');
      }
    } catch (e) {
      setState(() {
        _persistedPermissionsCache[agentId] = currentPerms;
        _agentPermissionsState[agentId] = currentPerms;
        agent['permissions'] = currentPerms;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update permission: $e'),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _savingPermissionAgentIds.remove(agentId);
        });
      }
    }
  }

  Future<void> _applyPermissionPreset(
    Map<String, dynamic> agent,
    String presetType,
  ) async {
    final agentId = agent['_id']?.toString() ?? '';
    if (agentId.isEmpty) return;

    final Map<String, dynamic> updatedPerms;
    if (presetType == 'full') {
      updatedPerms = {
        'lead': {'create': true, 'update': true, 'reassign': true, 'delete': true},
        'dealer': {'create': true, 'update': true, 'reassign': true, 'delete': true},
      };
    } else if (presetType == 'standard') {
      updatedPerms = {
        'lead': {'create': true, 'update': true, 'reassign': false, 'delete': true},
        'dealer': {'create': true, 'update': true, 'reassign': false, 'delete': true},
      };
    } else {
      // restricted / read-only updates
      updatedPerms = {
        'lead': {'create': false, 'update': false, 'reassign': false, 'delete': false},
        'dealer': {'create': false, 'update': false, 'reassign': false, 'delete': false},
      };
    }

    final currentPerms = _getAgentPermissions(agent);
    setState(() {
      _persistedPermissionsCache[agentId] = updatedPerms;
      _agentPermissionsState[agentId] = updatedPerms;
      agent['permissions'] = updatedPerms;
      _savingPermissionAgentIds.add(agentId);
    });

    try {
      var res = await ApiClient().put('/users/$agentId', {
        'permissions': updatedPerms,
      });
      if (res.statusCode != 200 && res.statusCode != 201) {
        res = await ApiClient().put('/users/sales/$agentId', {
          'permissions': updatedPerms,
        });
      }

      if (res.statusCode == 200 || res.statusCode == 201) {
        _persistedPermissionsCache[agentId] = updatedPerms;
        agent['permissions'] = updatedPerms;
        UserRepository().invalidateCache();
        if (AuthService().currentUserId == agentId) {
          AuthService().updatePermissions(updatedPerms);
        }

        final agentName =
            '${agent['firstName'] ?? ''} ${agent['lastName'] ?? ''}'.trim();
        final presetLabel = presetType == 'full'
            ? 'Full Access'
            : (presetType == 'standard'
                ? 'Standard Access (Create, Update, Delete)'
                : 'Restricted Access (View Only)');
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Applied $presetLabel preset to $agentName',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              backgroundColor: AppTheme.primaryColor,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        throw Exception('Server error: ${res.statusCode}');
      }
    } catch (e) {
      setState(() {
        _persistedPermissionsCache[agentId] = currentPerms;
        _agentPermissionsState[agentId] = currentPerms;
        agent['permissions'] = currentPerms;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to apply preset: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _savingPermissionAgentIds.remove(agentId);
        });
      }
    }
  }

  Widget _buildPermissionsTab(
    BuildContext context,
    LeadsState state,
    bool isDesktop,
    bool isMobile,
  ) {
    final allSalesAgents = (state.salesAgents.isNotEmpty)
        ? state.salesAgents
        : state.allRawUsers.where((u) => u['role'] == 'sales').toList();

    final filteredAgents = allSalesAgents.where((agent) {
      final name =
          '${agent['firstName'] ?? ''} ${agent['lastName'] ?? ''}'.toLowerCase();
      final email = (agent['email'] ?? '').toLowerCase();
      final phone = (agent['phoneNumber'] ?? '').toLowerCase();
      final query = _permissionSearchQuery.toLowerCase();
      return name.contains(query) ||
          email.contains(query) ||
          phone.contains(query);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Explainer Banner with Reassign Highlight
        _buildPermissionExplainerBanner(isDesktop, isMobile),
        const SizedBox(height: 20),

        // 2. Search & Toolbar
        _buildPermissionSearchBar(allSalesAgents.length, isMobile),
        const SizedBox(height: 20),

        // 3. Sales Agents Permission Cards
        if (filteredAgents.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.security_outlined,
                    size: 28,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  _permissionSearchQuery.isNotEmpty
                      ? 'No sales agents matching "$_permissionSearchQuery"'
                      : 'No sales agents found in system',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Add a sales agent under the Team Members tab to configure their permissions.',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
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
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final agent = filteredAgents[index];
              return _buildAgentPermissionCard(
                agent,
                isDesktop,
                isMobile,
              );
            },
          ),
      ],
    );
  }

  Widget _buildPermissionExplainerBanner(bool isDesktop, bool isMobile) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF0F3820),
            AppTheme.primaryColor,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background subtle ambient icon
          Positioned(
            right: -20,
            bottom: -20,
            child: Icon(
              Icons.shield_rounded,
              size: 160,
              color: Colors.white.withValues(alpha: 0.05),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(isDesktop ? 22 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.admin_panel_settings_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sales Agent Authorization & Role Permissions',
                            style: GoogleFonts.outfit(
                              fontSize: isMobile ? 15 : 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Configure granular Create, Update, Reassign, and Delete rules per team member.',
                            style: GoogleFonts.outfit(
                              fontSize: isMobile ? 11 : 12.5,
                              color: Colors.white.withValues(alpha: 0.8),
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Reassign Explainer Highlight Box
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFBBF24).withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.swap_horiz_rounded,
                          color: Color(0xFFFBBF24),
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Reassign Permission Workflow',
                              style: GoogleFonts.outfit(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFFEF3C7),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'When Reassign is enabled, the sales agent can transfer an assigned lead or dealer to another sales teammate. Once reassigned, the lead or dealer is transferred to the new agent and will no longer be visible to this sales agent.',
                              style: GoogleFonts.outfit(
                                fontSize: 11.5,
                                color: Colors.white.withValues(alpha: 0.9),
                                height: 1.35,
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
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionSearchBar(int totalAgents, bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(14),
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
                      controller: _permissionSearchController,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                      onChanged: (val) {
                        setState(() {
                          _permissionSearchQuery = val;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Search sales agents to configure permissions...',
                        hintStyle: GoogleFonts.outfit(
                          fontSize: 13.5,
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w400,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  if (_permissionSearchQuery.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        _permissionSearchController.clear();
                        setState(() {
                          _permissionSearchQuery = '';
                        });
                      },
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.people_alt_outlined,
                  size: 16,
                  color: AppTheme.textPrimary,
                ),
                const SizedBox(width: 6),
                Text(
                  '$totalAgents Sales Agents',
                  style: GoogleFonts.outfit(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgentPermissionCard(
    Map<String, dynamic> agent,
    bool isDesktop,
    bool isMobile,
  ) {
    final agentId = agent['_id']?.toString() ?? '';
    final firstName = agent['firstName'] ?? '';
    final lastName = agent['lastName'] ?? '';
    final name = '$firstName $lastName'.trim().isNotEmpty
        ? '$firstName $lastName'.trim()
        : (agent['name'] ?? 'Sales Agent');
    final email = agent['email'] ?? '-';
    final phone = agent['phoneNumber'] ?? '-';
    final initials = (name.isNotEmpty ? name[0] : 'S').toUpperCase();

    final perms = _getAgentPermissions(agent);
    final leadPerms = perms['lead'] as Map<String, dynamic>? ?? {};
    final dealerPerms = perms['dealer'] as Map<String, dynamic>? ?? {};

    int activeCount = 0;
    if (leadPerms['create'] == true) activeCount++;
    if (leadPerms['update'] == true) activeCount++;
    if (leadPerms['reassign'] == true) activeCount++;
    if (leadPerms['delete'] == true) activeCount++;
    if (dealerPerms['create'] == true) activeCount++;
    if (dealerPerms['update'] == true) activeCount++;
    if (dealerPerms['reassign'] == true) activeCount++;
    if (dealerPerms['delete'] == true) activeCount++;

    final isSaving = _savingPermissionAgentIds.contains(agentId);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: activeCount > 0
              ? AppTheme.primaryColor.withValues(alpha: 0.15)
              : AppTheme.borderColor,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Agent Card Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              border: Border(
                bottom: BorderSide(
                  color: const Color(0xFFE2E8F0),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                // Agent Avatar
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF34D399), Color(0xFF059669)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF059669).withValues(alpha: 0.25),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      initials,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Name & Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              style: GoogleFonts.outfit(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: AppTheme.primaryColor.withValues(alpha: 0.2),
                                width: 0.5,
                              ),
                            ),
                            child: Text(
                              'SALES AGENT',
                              style: GoogleFonts.outfit(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.primaryColor,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.email_outlined,
                                size: 13,
                                color: AppTheme.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                email,
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.phone_outlined,
                                size: 13,
                                color: AppTheme.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                phone,
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
                    ],
                  ),
                ),

                // Active Rules Counter Badge
                if (!isMobile) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: activeCount > 0
                          ? const Color(0xFFECFDF5)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: activeCount > 0
                            ? const Color(0xFFA7F3D0)
                            : const Color(0xFFCBD5E1),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: activeCount > 0
                                ? const Color(0xFF10B981)
                                : const Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$activeCount/8 Active',
                          style: GoogleFonts.outfit(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: activeCount > 0
                                ? const Color(0xFF047857)
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                ],

                // Preset Quick Menu
                PopupMenuButton<String>(
                  onSelected: (val) => _applyPermissionPreset(agent, val),
                  tooltip: 'Apply Permission Template',
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  itemBuilder: (ctx) => [
                    PopupMenuItem(
                      value: 'standard',
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle_outline,
                            size: 16,
                            color: AppTheme.primaryColor,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Standard (Create, Update, Delete)',
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'full',
                      child: Row(
                        children: [
                          const Icon(
                            Icons.admin_panel_settings_outlined,
                            size: 16,
                            color: Color(0xFF059669),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Full Access (All 8)',
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'restricted',
                      child: Row(
                        children: [
                          const Icon(
                            Icons.lock_outline,
                            size: 16,
                            color: Color(0xFFE11D48),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Restricted (View Only)',
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Presets',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.arrow_drop_down,
                          size: 16,
                          color: AppTheme.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),

                if (isSaving) ...[
                  const SizedBox(width: 10),
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Two Permission Categories (Lead & Dealer)
          Padding(
            padding: const EdgeInsets.all(18),
            child: isDesktop
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildPermissionModuleBox(
                          title: 'Lead Permissions',
                          subtitle: 'Rules applied when agent handles prospects & leads',
                          icon: Icons.campaign_rounded,
                          accentColor: const Color(0xFF0284C7),
                          moduleKey: 'lead',
                          permissions: leadPerms,
                          onToggle: (action, val) =>
                              _toggleAgentPermission(agent, 'lead', action, val),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildPermissionModuleBox(
                          title: 'Dealer Permissions',
                          subtitle: 'Rules applied when agent handles verified store accounts',
                          icon: Icons.storefront_rounded,
                          accentColor: const Color(0xFF0D9488),
                          moduleKey: 'dealer',
                          permissions: dealerPerms,
                          onToggle: (action, val) =>
                              _toggleAgentPermission(agent, 'dealer', action, val),
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      _buildPermissionModuleBox(
                        title: 'Lead Permissions',
                        subtitle: 'Rules applied when agent handles prospects & leads',
                        icon: Icons.campaign_rounded,
                        accentColor: const Color(0xFF0284C7),
                        moduleKey: 'lead',
                        permissions: leadPerms,
                        onToggle: (action, val) =>
                            _toggleAgentPermission(agent, 'lead', action, val),
                      ),
                      const SizedBox(height: 16),
                      _buildPermissionModuleBox(
                        title: 'Dealer Permissions',
                        subtitle: 'Rules applied when agent handles verified store accounts',
                        icon: Icons.storefront_rounded,
                        accentColor: const Color(0xFF0D9488),
                        moduleKey: 'dealer',
                        permissions: dealerPerms,
                        onToggle: (action, val) =>
                            _toggleAgentPermission(agent, 'dealer', action, val),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionModuleBox({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required String moduleKey,
    required Map<String, dynamic> permissions,
    required Function(String action, bool value) onToggle,
  }) {
    final bool canCreate = permissions['create'] ?? true;
    final bool canUpdate = permissions['update'] ?? true;
    final bool canReassign = permissions['reassign'] ?? true;
    final bool canDelete = permissions['delete'] ?? false;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: accentColor, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          const SizedBox(height: 10),

          // 1. Create Permission
          _buildPermissionToggleRow(
            title: moduleKey == 'lead' ? 'Create Leads' : 'Create Dealers',
            description: moduleKey == 'lead'
                ? 'Allow adding new farmer & customer prospects'
                : 'Allow onboarding new verified store accounts',
            icon: Icons.add_circle_outline_rounded,
            value: canCreate,
            onChanged: (val) => onToggle('create', val),
          ),

          // 2. Update Permission
          _buildPermissionToggleRow(
            title: moduleKey == 'lead' ? 'Update Leads' : 'Update Dealers',
            description: moduleKey == 'lead'
                ? 'Allow modifying lead contact info, KYC & statuses'
                : 'Allow updating store info, terms & KYC records',
            icon: Icons.edit_outlined,
            value: canUpdate,
            onChanged: (val) => onToggle('update', val),
          ),

          // 3. Reassign Permission (with highlight indicator)
          _buildPermissionToggleRow(
            title: moduleKey == 'lead' ? 'Reassign Leads' : 'Reassign Dealers',
            description: moduleKey == 'lead'
                ? 'Can transfer leads to teammates (removes from active view)'
                : 'Can transfer dealers to teammates (removes from active view)',
            icon: Icons.swap_horiz_rounded,
            value: canReassign,
            isReassign: true,
            onChanged: (val) => onToggle('reassign', val),
          ),

          // 4. Delete Permission
          _buildPermissionToggleRow(
            title: moduleKey == 'lead' ? 'Delete Leads' : 'Delete Dealers',
            description: moduleKey == 'lead'
                ? 'Allow archiving or soft-deleting lead records'
                : 'Allow archiving or blocking dealer records',
            icon: Icons.delete_outline_rounded,
            value: canDelete,
            isDestructive: true,
            onChanged: (val) => onToggle('delete', val),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionToggleRow({
    required String title,
    required String description,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool isReassign = false,
    bool isDestructive = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: value ? Colors.white : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: value
                ? (isReassign
                    ? const Color(0xFFF59E0B).withValues(alpha: 0.3)
                    : const Color(0xFF10B981).withValues(alpha: 0.25))
                : const Color(0xFFE5E7EB),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: value
                  ? (isDestructive
                      ? AppTheme.error
                      : (isReassign
                          ? const Color(0xFFD97706)
                          : AppTheme.primaryColor))
                  : const Color(0xFF94A3B8),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.outfit(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: value
                              ? AppTheme.textPrimary
                              : const Color(0xFF64748B),
                        ),
                      ),
                      if (isReassign) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: const Color(0xFFFCD34D),
                              width: 0.5,
                            ),
                          ),
                          child: Text(
                            'Transfers Out',
                            style: GoogleFonts.outfit(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFFB45309),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    description,
                    style: GoogleFonts.outfit(
                      fontSize: 10.5,
                      color: const Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Transform.scale(
              scale: 0.75,
              child: Switch.adaptive(
                value: value,
                activeThumbColor: isDestructive
                    ? AppTheme.error
                    : (isReassign
                        ? const Color(0xFFD97706)
                        : AppTheme.primaryColor),
                activeTrackColor: isDestructive
                    ? AppTheme.error.withValues(alpha: 0.25)
                    : (isReassign
                        ? const Color(0xFFFDE68A)
                        : const Color(0xFFA7F3D0)),
                inactiveThumbColor: const Color(0xFF94A3B8),
                inactiveTrackColor: const Color(0xFFE2E8F0),
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      ),
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
