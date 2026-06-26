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
import 'package:http/http.dart' as http;

class TeamManagementPage extends StatefulWidget {
  const TeamManagementPage({super.key});

  @override
  State<TeamManagementPage> createState() => _TeamManagementPageState();
}

class _TeamManagementPageState extends State<TeamManagementPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isActionLoading = false;

  @override
  void dispose() {
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
                          // Page Header Title and Description
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                    'Monitor and coordinate your sales agent team assignments.',
                                    style: GoogleFonts.outfit(
                                      fontSize: isMobile ? 12 : 14,
                                      color: AppTheme.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

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
                                        borderRadius: BorderRadius.circular(10),
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
                                border: Border.all(color: AppTheme.borderColor),
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
                          else if (isMobile)
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: filteredAgents.length,
                              itemBuilder: (context, index) {
                                final agent = filteredAgents[index];
                                final agentId = agent['_id'] ?? '';
                                final name =
                                    '${agent['firstName'] ?? ''} ${agent['lastName'] ?? ''}'
                                        .trim();
                                final email = agent['email'] ?? '-';
                                final phone = agent['phoneNumber'] ?? '-';
                                final leadsCount = leadsCountMap[agentId] ?? 0;
                                final dealersCount =
                                    dealersCountMap[agentId] ?? 0;

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: const BorderSide(
                                      color: AppTheme.borderColor,
                                    ),
                                  ),
                                  color: Colors.white,
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            CircleAvatar(
                                              backgroundColor: AppTheme
                                                  .primaryColor
                                                  .withOpacity(0.12),
                                              radius: 20,
                                              child: Text(
                                                name.isNotEmpty
                                                    ? name[0].toUpperCase()
                                                    : 'S',
                                                style: GoogleFonts.outfit(
                                                  fontWeight: FontWeight.bold,
                                                  color: AppTheme.primaryColor,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    name,
                                                    style: GoogleFonts.outfit(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 14,
                                                      color:
                                                          AppTheme.textPrimary,
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
                                                Icons.delete_outline_rounded,
                                                size: 18,
                                                color: AppTheme.error,
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
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              email,
                                              style: GoogleFonts.outfit(
                                                fontSize: 12,
                                                color: AppTheme.textSecondary,
                                              ),
                                            ),
                                            Row(
                                              children: [
                                                _buildMiniBadge(
                                                  'Leads: $leadsCount',
                                                  Colors.blue,
                                                ),
                                                const SizedBox(width: 8),
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
                                );
                              },
                            )
                          else
                            // Desktop Table View
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppTheme.borderColor),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Table(
                                  columnWidths: const {
                                    0: FlexColumnWidth(2.5),
                                    1: FlexColumnWidth(2.5),
                                    2: FlexColumnWidth(2.0),
                                    3: FlexColumnWidth(1.2),
                                    4: FlexColumnWidth(1.2),
                                    5: FlexColumnWidth(1.2),
                                  },
                                  defaultVerticalAlignment:
                                      TableCellVerticalAlignment.middle,
                                  children: [
                                    // Table Header Row
                                    TableRow(
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFF9FAFB),
                                        border: Border(
                                          bottom: BorderSide(
                                            color: AppTheme.borderColor,
                                          ),
                                        ),
                                      ),
                                      children: [
                                        _buildTableHeaderCell('Name'),
                                        _buildTableHeaderCell('Email'),
                                        _buildTableHeaderCell('Phone'),
                                        _buildTableHeaderCell('Leads'),
                                        _buildTableHeaderCell('Dealers'),
                                        _buildTableHeaderCell(
                                          'Actions',
                                          alignRight: true,
                                        ),
                                      ],
                                    ),
                                    // Table Data Rows
                                    ...filteredAgents.map((agent) {
                                      final agentId = agent['_id'] ?? '';
                                      final name =
                                          '${agent['firstName'] ?? ''} ${agent['lastName'] ?? ''}'
                                              .trim();
                                      final email = agent['email'] ?? '-';
                                      final phone = agent['phoneNumber'] ?? '-';
                                      final leadsCount =
                                          leadsCountMap[agentId] ?? 0;
                                      final dealersCount =
                                          dealersCountMap[agentId] ?? 0;

                                      return TableRow(
                                        decoration: const BoxDecoration(
                                          border: Border(
                                            bottom: BorderSide(
                                              color: Color(0xFFF1F5F9),
                                            ),
                                          ),
                                        ),
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 14,
                                            ),
                                            child: Row(
                                              children: [
                                                CircleAvatar(
                                                  backgroundColor: AppTheme
                                                      .primaryColor
                                                      .withOpacity(0.12),
                                                  radius: 18,
                                                  child: Text(
                                                    name.isNotEmpty
                                                        ? name[0].toUpperCase()
                                                        : 'S',
                                                    style: GoogleFonts.outfit(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color:
                                                          AppTheme.primaryColor,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Text(
                                                  name,
                                                  style: GoogleFonts.outfit(
                                                    fontWeight: FontWeight.bold,
                                                    color: AppTheme.textPrimary,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          _buildTableCell(email),
                                          _buildTableCell(phone),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                            ),
                                            child: Align(
                                              alignment: Alignment.centerLeft,
                                              child: _buildBadge(
                                                leadsCount.toString(),
                                                Colors.blue,
                                              ),
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                            ),
                                            child: Align(
                                              alignment: Alignment.centerLeft,
                                              child: _buildBadge(
                                                dealersCount.toString(),
                                                Colors.teal,
                                              ),
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 10,
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.end,
                                              children: [
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
                                                    color: AppTheme.error,
                                                  ),
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

  Widget _buildTableHeaderCell(String text, {bool alignRight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Align(
        alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
        child: Text(
          text,
          style: GoogleFonts.outfit(
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
            color: AppTheme.textSecondary,
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
          color: AppTheme.textPrimary,
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

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: GoogleFonts.outfit(
          fontSize: 11.5,
          fontWeight: FontWeight.bold,
          color: color,
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
}
