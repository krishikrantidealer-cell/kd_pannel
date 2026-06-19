import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kd_pannel/app_theme.dart';
import 'package:kd_pannel/core/responsive/responsive.dart';
import 'package:kd_pannel/features/shared/widgets/stat_card_widget.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/leads_bloc.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/leads_event.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/leads_state.dart';

class LeadsPage extends StatefulWidget {
  final bool isStandalone;
  const LeadsPage({super.key, this.isStandalone = false});

  @override
  State<LeadsPage> createState() => _LeadsPageState();
}

class _LeadsPageState extends State<LeadsPage> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final bloc = context.read<LeadsBloc>();
    _searchController.text = bloc.state.searchQuery;
    if (bloc.state.status == LeadsStatus.initial) {
      bloc.add(const FetchLeadsDataEvent());
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _assignAgent(String userId, String? agentId) {
    context.read<LeadsBloc>().add(AssignAgentToLeadEvent(userId, agentId));
  }

  void _bulkAssignAgent(List<String> userIds, String? agentId) {
    context.read<LeadsBloc>().add(
      BulkAssignAgentToLeadsEvent(userIds, agentId),
    );
  }

  String _formatTimeAgo(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes} mins ago';
      if (diff.inHours < 24) return '${diff.inHours} hours ago';
      if (diff.inDays == 1) return 'Yesterday';
      return '${diff.inDays} days ago';
    } catch (e) {
      return '-';
    }
  }

  List<Map<String, dynamic>> get allLeads {
    final state = context.read<LeadsBloc>().state;
    return _getAllLeads(state.allRawUsers);
  }

  List<Map<String, dynamic>> _getAllLeads(List<Map<String, dynamic>> rawUsers) {
    return rawUsers
        .where((u) {
          final role = u['role'] ?? 'user';
          final kycStatus = u['kycStatus'] ?? 'pending';
          return role == 'user' && kycStatus != 'verified';
        })
        .map((u) {
          return {
            'id': u['_id'],
            'name':
                (u['firstName'] != null &&
                    u['firstName'].toString().trim().isNotEmpty)
                ? '${u['firstName']} ${u['lastName'] ?? ''}'.trim()
                : (u['shopName'] != null &&
                      u['shopName'].toString().trim().isNotEmpty)
                ? u['shopName']
                : (u['phoneNumber'] ?? 'Unnamed Lead'),
            'phone': u['phoneNumber'] ?? '',
            'city': u['address']?['cityTehsil'] ?? '',
            'state': u['address']?['state'] ?? '',
            'activity': u['updatedAt'] != null
                ? _formatTimeAgo(u['updatedAt'])
                : '-',
            'agent': u['assignedAgent'] != null
                ? '${u['assignedAgent']['firstName']} ${u['assignedAgent']['lastName'] ?? ''}'
                      .trim()
                : '-',
            'agentId': u['assignedAgent']?['_id'],
            'source': u['source'] ?? 'App',
            'status':
                u['kycStatus'] == 'pending' || u['kycStatus'] == 'submitted'
                ? 'KYC Pending'
                : (u['assignedAgent'] != null ? 'Assigned' : 'Unassigned'),
            'kycStatus': u['kycStatus'] ?? 'pending',
            'gstNumber': u['gstNumber'] ?? '',
            'userType': u['userType'] ?? '',
            'licenceImage': u['licenceImage'] ?? '',
            'shopImage': u['shopImage'] ?? '',
          };
        })
        .toList();
  }

  final List<String> dropdownOptions = [
    'Last 1 Week',
    'Last 2 Weeks',
    'Last 3 Weeks',
    'Last 1 Month',
    'Last 3 Months',
    'Last 6 Months',
    'This Month',
  ];

  final List<String> filterChips = [
    'All',
    'Assigned',
    'Unassigned',
    'KYC Confirm',
    'KYC Pending',
  ];

  final Map<String, String> statusMapping = {
    'Assigned': 'Assigned',
    'Unassigned': 'Unassigned',
    'KYC Confirm': 'KYC Confirm',
    'KYC Pending': 'KYC Pending',
  };

  List<Map<String, dynamic>> get filteredLeads {
    final state = context.read<LeadsBloc>().state;
    return _getFilteredLeads(
      allLeads,
      state.selectedFilterChip,
      state.searchQuery,
    );
  }

  List<Map<String, dynamic>> _getFilteredLeads(
    List<Map<String, dynamic>> leads,
    String selectedFilterChip,
    String searchQuery,
  ) {
    List<Map<String, dynamic>> result = leads;

    if (selectedFilterChip != 'All') {
      if (selectedFilterChip == 'Unassigned') {
        result = result.where((l) => l['agentId'] == null).toList();
      } else if (selectedFilterChip == 'Assigned') {
        result = result.where((l) => l['agentId'] != null).toList();
      } else if (selectedFilterChip == 'KYC Pending') {
        result = result
            .where(
              (l) =>
                  l['kycStatus'] == 'pending' || l['kycStatus'] == 'submitted',
            )
            .toList();
      } else if (selectedFilterChip == 'KYC Confirm') {
        result = []; // Verified users are dealers, so they don't show up here
      }
    }

    final query = searchQuery.toLowerCase();
    if (query.isNotEmpty) {
      result = result.where((l) {
        return l['name'].toString().toLowerCase().contains(query) ||
            l['phone'].toString().toLowerCase().contains(query) ||
            l['city'].toString().toLowerCase().contains(query) ||
            l['source'].toString().toLowerCase().contains(query) ||
            l['agent'].toString().toLowerCase().contains(query);
      }).toList();
    }

    return result;
  }

  String _getRangeDisplay(
    PickerDateRange? selectedRange,
    String selectedTimeframe,
  ) {
    if (selectedRange != null &&
        selectedRange.startDate != null &&
        selectedRange.endDate != null) {
      final start = selectedRange.startDate!;
      final end = selectedRange.endDate!;
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${start.day.toString().padLeft(2, '0')} ${months[start.month - 1]} - ${end.day.toString().padLeft(2, '0')} ${months[end.month - 1]}';
    }
    return selectedTimeframe;
  }

  void _showSyncfusionDatePicker(PickerDateRange? initialRange) {
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
            initialSelectedRange: initialRange,
            onSubmit: (Object? val) {
              if (val is PickerDateRange &&
                  val.startDate != null &&
                  val.endDate != null) {
                context.read<LeadsBloc>().add(
                  UpdateLeadsFilterEvent(
                    selectedRange: val,
                    selectedTimeframe: '',
                  ),
                );
                Navigator.pop(context);
              }
            },
            onCancel: () => Navigator.pop(context),
          ),
        ),
      ),
    );
  }

  void _showCreateSalesAgentDialog() {
    final formKey = GlobalKey<FormState>();
    final firstNameController = TextEditingController();
    final lastNameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Create Sales Agent',
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
                    'Password',
                    Icons.lock_outline,
                  ),
                  obscureText: true,
                  validator: (val) => val == null || val.length < 6
                      ? 'Password must be at least 6 characters'
                      : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.outfit(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                context.read<LeadsBloc>().add(
                  CreateSalesAgentFromLeadsEvent(
                    firstName: firstNameController.text.trim(),
                    lastName: lastNameController.text.trim(),
                    email: emailController.text.trim(),
                    phoneNumber: phoneController.text.trim(),
                    password: passwordController.text,
                  ),
                );
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  InputDecoration _buildInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.outfit(
        color: AppTheme.textSecondary,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      prefixIcon: Icon(icon, size: 18, color: AppTheme.primaryColor),
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
    final bool isDesktop = Responsive.isDesktop(context);
    final bool isMobile = Responsive.isMobile(context);

    return BlocConsumer<LeadsBloc, LeadsState>(
      listener: (context, state) {
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: AppTheme.error,
            ),
          );
          context.read<LeadsBloc>().add(const ClearLeadsMessageEvent());
        }
        if (state.actionSuccessMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.actionSuccessMessage!),
              backgroundColor: AppTheme.success,
            ),
          );
          context.read<LeadsBloc>().add(const ClearLeadsMessageEvent());
        }
      },
      builder: (context, state) {
        final verifiedDealersCount = state.allRawUsers
            .where((u) => u['role'] == 'user' && u['kycStatus'] == 'verified')
            .length;

        final Widget body =
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
                        if (isMobile)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!widget.isStandalone) ...[
                                Text(
                                  'Leads',
                                  style: AppTheme.headingXL.copyWith(
                                    letterSpacing: -0.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: _showCreateSalesAgentDialog,
                                      icon: const Icon(Icons.add, size: 16),
                                      label: Text(
                                        'Sales Agent',
                                        style: GoogleFonts.outfit(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.primaryColor,
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 10,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _buildTimeframeRow(isMobile, state),
                                  ),
                                ],
                              ),
                            ],
                          )
                        else
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              if (!widget.isStandalone)
                                Text(
                                  'Leads Management',
                                  style: AppTheme.headingXL.copyWith(
                                    letterSpacing: -0.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                )
                              else
                                const SizedBox.shrink(),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: _showCreateSalesAgentDialog,
                                    icon: const Icon(Icons.add, size: 16),
                                    label: Text(
                                      'Create Sales Agent',
                                      style: GoogleFonts.outfit(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryColor,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  _buildTimeframeRow(isMobile, state),
                                ],
                              ),
                            ],
                          ),
                        const SizedBox(height: 16),
                        _LeadsStatsGrid(
                          leads: allLeads,
                          verifiedDealersCount: verifiedDealersCount,
                        ),
                        const SizedBox(height: 24),
                        _buildFilterChips(isMobile, state),
                        const SizedBox(height: 16),
                        _LeadsTableCard(
                          leads: filteredLeads,
                          totalEntries: filteredLeads.length,
                          isMobile: isMobile,
                          salesAgents: state.salesAgents,
                          onAssignAgent: _assignAgent,
                          onBulkAssignAgent: _bulkAssignAgent,
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
              );

        if (widget.isStandalone) {
          return Scaffold(
            backgroundColor: AppTheme.backgroundColor,
            appBar: AppBar(
              title: Text(
                'Leads Management',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              backgroundColor: Colors.white,
              foregroundColor: AppTheme.textPrimary,
              elevation: 0,
              bottom: const PreferredSize(
                preferredSize: Size.fromHeight(1),
                child: Divider(height: 1, color: AppTheme.lightBorderColor),
              ),
            ),
            body: body,
          );
        }

        return body;
      },
    );
  }

  Widget _buildTimeframeRow(bool isMobile, LeadsState state) {
    return Container(
      height: isMobile ? 38 : 42,
      padding: const EdgeInsets.only(left: 12, right: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        mainAxisSize: isMobile ? MainAxisSize.max : MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => _showSyncfusionDatePicker(state.selectedRange),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Icon(
                  Icons.calendar_month_outlined,
                  size: isMobile ? 16 : 18,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
          ),
          Container(
            width: 1,
            height: 16,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            color: AppTheme.borderColor.withValues(alpha: 0.6),
          ),
          if (isMobile)
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: null,
                  isExpanded: true,
                  isDense: true,
                  padding: EdgeInsets.zero,
                  hint: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _getRangeDisplay(
                            state.selectedRange,
                            state.selectedTimeframe,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.keyboard_arrow_down,
                        size: 16,
                        color: AppTheme.textSecondary,
                      ),
                    ],
                  ),
                  icon: const SizedBox.shrink(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      context.read<LeadsBloc>().add(
                        UpdateLeadsFilterEvent(
                          selectedTimeframe: newValue,
                          resetRange: true,
                        ),
                      );
                    }
                  },
                  items: dropdownOptions
                      .map<DropdownMenuItem<String>>(
                        (String value) => DropdownMenuItem<String>(
                          value: value,
                          child: Text(
                            value,
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            )
          else
            DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: null,
                isExpanded: false,
                isDense: true,
                padding: EdgeInsets.zero,
                hint: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Text(
                        _getRangeDisplay(
                          state.selectedRange,
                          state.selectedTimeframe,
                        ),
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(left: 2, right: 2),
                      child: Icon(
                        Icons.keyboard_arrow_down,
                        size: 18,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
                icon: const SizedBox.shrink(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    context.read<LeadsBloc>().add(
                      UpdateLeadsFilterEvent(
                        selectedTimeframe: newValue,
                        resetRange: true,
                      ),
                    );
                  }
                },
                items: dropdownOptions
                    .map<DropdownMenuItem<String>>(
                      (String value) => DropdownMenuItem<String>(
                        value: value,
                        child: Text(
                          value,
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(bool isMobile, LeadsState state) {
    if (!isMobile) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildSearchField(250), // Final refined width for perfect alignment
          const SizedBox(width: 16), // Refined gap for grid rhythm
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics:
                  const NeverScrollableScrollPhysics(), // Forced single-line rhythm
              child: Row(
                children: filterChips
                    .map(
                      (chip) => Padding(
                        padding: const EdgeInsets.only(
                          right: 8,
                        ), // Refined 8px spacing
                        child: _FilterChipItem(
                          label: chip,
                          icon: _getChipIcon(chip),
                          isSelected: state.selectedFilterChip == chip,
                          onTap: () {
                            context.read<LeadsBloc>().add(
                              UpdateLeadsFilterEvent(
                                selectedFilterChip: chip,
                                currentPage: 1,
                                searchQuery:
                                    '', // Clear search on filter change
                              ),
                            );
                            _searchController.clear();
                          },
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSearchField(double.infinity),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: filterChips
                  .map(
                    (chip) => Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: _FilterChipItem(
                        label: chip,
                        icon: _getChipIcon(chip),
                        isSelected: state.selectedFilterChip == chip,
                        onTap: () {
                          context.read<LeadsBloc>().add(
                            UpdateLeadsFilterEvent(
                              selectedFilterChip: chip,
                              currentPage: 1,
                              searchQuery: '', // Clear search on filter change
                            ),
                          );
                          _searchController.clear();
                        },
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      );
    }
  }

  IconData _getChipIcon(String chip) {
    switch (chip) {
      case 'All':
        return Icons.grid_view_rounded;
      case 'Assigned':
        return Icons.person_pin_rounded;
      case 'Unassigned':
        return Icons.person_off_rounded;
      case 'KYC Confirm':
        return Icons.verified_user_rounded;
      case 'KYC Pending':
        return Icons.history_edu_rounded;
      default:
        return Icons.filter_list_rounded;
    }
  }

  Widget _buildSearchField(double? width) {
    return Container(
      width: width,
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
              onChanged: (val) {
                context.read<LeadsBloc>().add(
                  UpdateLeadsFilterEvent(searchQuery: val, currentPage: 1),
                );
              },
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: 'Search leads...',
                hintStyle: GoogleFonts.outfit(
                  fontSize: 14,
                  color: AppTheme.textSecondary.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w500,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChipItem extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChipItem({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_FilterChipItem> createState() => _FilterChipItemState();
}

class _FilterChipItemState extends State<_FilterChipItem> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    final bool isMobile = Responsive.isMobile(context);
    final Color iconColor = widget.isSelected
        ? AppTheme.primaryColor
        : (isHovered ? AppTheme.textPrimary : _getMutedIconColor(widget.label));

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(
            horizontal: isMobile
                ? 12
                : 16, // Reduced from 18 to 16 for micro-alignment
            vertical: isMobile ? 6 : 8,
          ),
          decoration: BoxDecoration(
            gradient: widget.isSelected
                ? LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppTheme.primaryColor.withValues(alpha: 0.12),
                      AppTheme.primaryColor.withValues(alpha: 0.08),
                    ],
                  )
                : (isHovered
                      ? LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppTheme.primaryColor.withValues(alpha: 0.06),
                            AppTheme.primaryColor.withValues(alpha: 0.04),
                          ],
                        )
                      : null),
            color: (widget.isSelected || isHovered) ? null : Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: widget.isSelected
                ? [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : (isHovered
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null),
            border: Border.all(
              color: widget.isSelected
                  ? AppTheme.primaryColor
                  : (isHovered
                        ? AppTheme.primaryColor.withValues(alpha: 0.4)
                        : AppTheme.borderColor),
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 16, color: iconColor),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: GoogleFonts.outfit(
                  color: widget.isSelected
                      ? AppTheme.primaryColor
                      : AppTheme.textPrimary,
                  fontWeight: FontWeight.w700, // Always bold by default
                  fontSize: isMobile ? 12 : 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getMutedIconColor(String chip) {
    switch (chip) {
      case 'All':
        return AppTheme.textSecondary;
      case 'Assigned':
        return AppTheme.info.withValues(alpha: 0.7);
      case 'Unassigned':
        return const Color(0xFF8B5CF6).withValues(alpha: 0.7);
      case 'KYC Confirm':
        return AppTheme.teal.withValues(alpha: 0.7);
      case 'KYC Pending':
        return AppTheme.error.withValues(alpha: 0.7);
      default:
        return AppTheme.textSecondary;
    }
  }
}

class _LeadsTableCard extends StatefulWidget {
  final List<Map<String, dynamic>> leads;
  final int totalEntries;
  final bool isMobile;
  final List<Map<String, dynamic>> salesAgents;
  final Function(String userId, String? agentId) onAssignAgent;
  final Function(List<String> userIds, String? agentId) onBulkAssignAgent;

  const _LeadsTableCard({
    required this.leads,
    required this.totalEntries,
    required this.isMobile,
    required this.salesAgents,
    required this.onAssignAgent,
    required this.onBulkAssignAgent,
  });

  @override
  State<_LeadsTableCard> createState() => _LeadsTableCardState();
}

class _LeadsTableCardState extends State<_LeadsTableCard> {
  String selectedSource = 'Lead Source';
  String selectedAssign = 'Assign';
  PickerDateRange? _selectedTableRange;
  String selectedTableDropdown = 'Today';
  final Set<String> _selectedLeadIds = {};
  int get _currentPage => context.read<LeadsBloc>().state.currentPage;
  int get _pageSize => context.read<LeadsBloc>().state.pageSize;

  Future<void> _handleBulkAssign(String? agentId) async {
    final agentName = agentId == null
        ? 'None'
        : widget.salesAgents.firstWhere(
                (a) => a['_id'] == agentId,
                orElse: () => <String, dynamic>{},
              )['firstName'] ??
              'Agent';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Confirm Bulk Assignment',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        content: Text(
          'Are you sure you want to assign ${agentId == null ? "no agent" : "sales agent \"$agentName\""} to ${_selectedLeadIds.length} selected leads?',
          style: GoogleFonts.outfit(color: AppTheme.textSecondary),
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
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Confirm',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final ids = _selectedLeadIds.toList();
      setState(() {
        _selectedLeadIds.clear();
      });
      await widget.onBulkAssignAgent(ids, agentId);
    }
  }

  Widget _buildBulkActionsControls() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${_selectedLeadIds.length} selected',
          style: GoogleFonts.outfit(
            fontSize: widget.isMobile ? 12 : 13,
            color: AppTheme.primaryColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 12),
        Container(
          height: widget.isMobile ? 32 : 36,
          padding: const EdgeInsets.only(left: 12, right: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppTheme.primaryColor.withValues(alpha: 0.5),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              padding: EdgeInsets.zero,
              isExpanded: false,
              isDense: true,
              hint: Text(
                'Bulk Action',
                style: GoogleFonts.outfit(
                  fontSize: widget.isMobile ? 11 : 12,
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              value: null,
              icon: Padding(
                padding: const EdgeInsets.only(left: 4, right: 4),
                child: Icon(
                  Icons.keyboard_arrow_down,
                  size: widget.isMobile ? 14 : 16,
                  color: AppTheme.primaryColor,
                ),
              ),
              items: [
                DropdownMenuItem<String>(
                  value: 'unassign',
                  child: Text(
                    'Unassign Agent',
                    style: GoogleFonts.outfit(
                      fontSize: widget.isMobile ? 11 : 12,
                      color: AppTheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ...widget.salesAgents.map((agent) {
                  final name =
                      '${agent['firstName'] ?? ''} ${agent['lastName'] ?? ''}'
                          .trim();
                  return DropdownMenuItem<String>(
                    value: agent['_id'],
                    child: Text(
                      name.isNotEmpty ? name : (agent['phoneNumber'] ?? ''),
                      style: GoogleFonts.outfit(
                        fontSize: widget.isMobile ? 11 : 12,
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }),
              ],
              onChanged: (val) {
                if (val == 'unassign') {
                  _handleBulkAssign(null);
                } else if (val != null) {
                  _handleBulkAssign(val);
                }
              },
            ),
          ),
        ),
        const SizedBox(width: 8),
        TextButton(
          onPressed: () {
            setState(() {
              _selectedLeadIds.clear();
            });
          },
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            minimumSize: Size(0, widget.isMobile ? 32 : 36),
          ),
          child: Text(
            'Clear',
            style: GoogleFonts.outfit(
              fontSize: widget.isMobile ? 11 : 12,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  String get _tableRangeDisplay {
    if (_selectedTableRange != null &&
        _selectedTableRange!.startDate != null &&
        _selectedTableRange!.endDate != null) {
      final start = _selectedTableRange!.startDate!;
      final end = _selectedTableRange!.endDate!;
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${start.day.toString().padLeft(2, '0')} ${months[start.month - 1]} - ${end.day.toString().padLeft(2, '0')} ${months[end.month - 1]}';
    }
    return selectedTableDropdown;
  }

  void _showTableDatePicker() {
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
            initialSelectedRange: _selectedTableRange,
            onSubmit: (Object? val) {
              if (val is PickerDateRange &&
                  val.startDate != null &&
                  val.endDate != null) {
                setState(() => _selectedTableRange = val);
                Navigator.pop(context);
              }
            },
            onCancel: () => Navigator.pop(context),
          ),
        ),
      ),
    );
  }

  @override
  void didUpdateWidget(_LeadsTableCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.leads.length != widget.leads.length) {
      context.read<LeadsBloc>().add(
        const UpdateLeadsFilterEvent(currentPage: 1),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = Responsive.isDesktop(context);
    final total = widget.leads.length;
    final totalPages = (total / _pageSize).ceil();
    final currentPage = _currentPage.clamp(1, totalPages > 0 ? totalPages : 1);
    final startIndex = (currentPage - 1) * _pageSize;
    final endIndex = (startIndex + _pageSize) > total
        ? total
        : (startIndex + _pageSize);
    final paginatedLeads = total == 0
        ? <Map<String, dynamic>>[]
        : widget.leads.sublist(startIndex, endIndex);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.5)),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: widget.isMobile
                ? const EdgeInsets.all(16)
                : const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            child: isDesktop
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Lead Records',
                        style: AppTheme.headingMD.copyWith(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                      _selectedLeadIds.isNotEmpty
                          ? _buildBulkActionsControls()
                          : _buildCombinedControls(),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lead Records',
                        style: GoogleFonts.outfit(
                          fontSize: widget.isMobile ? 15 : 16,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                          letterSpacing: widget.isMobile ? 0.2 : 0.0,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: _selectedLeadIds.isNotEmpty
                            ? _buildBulkActionsControls()
                            : _buildCombinedControls(),
                      ),
                    ],
                  ),
          ),
          _LeadsTable(
            leads: paginatedLeads,
            isMobile: widget.isMobile,
            salesAgents: widget.salesAgents,
            onAssignAgent: widget.onAssignAgent,
            selectedLeadIds: _selectedLeadIds,
            onSelectionChanged: () {
              setState(() {});
            },
          ),
          _buildTableFooter(widget.isMobile, currentPage),
        ],
      ),
    );
  }

  Widget _buildCombinedControls() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildTableDropdown(
          'Lead Source',
          selectedSource,
          ['All', 'Facebook', 'Google', 'Website', 'Direct'],
          (val) => setState(() => selectedSource = val!),
        ),
        const SizedBox(width: 12),
        _buildTableDropdown('Assign', selectedAssign, [
          'All',
          'Amit Patel',
          'Priya Singh',
          'Unassigned',
        ], (val) => setState(() => selectedAssign = val!)),
        const SizedBox(width: 12),
        _buildTableDateSection(),
      ],
    );
  }

  Widget _buildTableDateSection() {
    return Container(
      height: widget.isMobile ? 32 : 36,
      padding: const EdgeInsets.only(left: 10, right: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: _showTableDatePicker,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Icon(
                  Icons.calendar_month_outlined,
                  size: widget.isMobile ? 14 : 16,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
          ),
          Container(
            width: 1,
            height: 16,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            color: AppTheme.borderColor.withValues(alpha: 0.6),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: null,
              isExpanded: false,
              isDense: true,
              padding: EdgeInsets.zero,
              hint: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(
                      _tableRangeDisplay,
                      style: GoogleFonts.outfit(
                        fontSize: widget.isMobile ? 11 : 12,
                        color: AppTheme.textPrimary.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 2, right: 2),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      size: widget.isMobile ? 14 : 16,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              icon: const SizedBox.shrink(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    selectedTableDropdown = newValue;
                    _selectedTableRange = null;
                  });
                }
              },
              items: ['Today', 'Yesterday', 'Last 7 Days', 'Last 30 Days']
                  .map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(
                        value,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  })
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableDropdown(
    String hint,
    String current,
    List<String> options,
    ValueChanged<String?> onChanged,
  ) {
    return Container(
      height: widget.isMobile ? 32 : 36,
      padding: const EdgeInsets.only(left: 12, right: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          padding: EdgeInsets.zero,
          isExpanded: false,
          isDense: true,
          hint: Text(
            hint,
            style: GoogleFonts.outfit(
              fontSize: widget.isMobile ? 11 : 12,
              color: AppTheme.textPrimary.withValues(alpha: 0.8),
              fontWeight: FontWeight.w600,
            ),
          ),
          value: options.contains(current) ? current : null,
          icon: Padding(
            padding: const EdgeInsets.only(left: 4, right: 4),
            child: Icon(
              Icons.keyboard_arrow_down,
              size: widget.isMobile ? 14 : 16,
              color: AppTheme.textSecondary,
            ),
          ),
          items: options
              .map(
                (e) => DropdownMenuItem(
                  value: e,
                  child: Text(
                    e,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: GoogleFonts.outfit(
                      fontSize: widget.isMobile ? 11 : 12,
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildPageSizeSelector() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Show',
          style: GoogleFonts.outfit(
            fontSize: 12,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _pageSize,
              icon: const Icon(
                Icons.arrow_drop_down,
                size: 18,
                color: AppTheme.textSecondary,
              ),
              style: GoogleFonts.outfit(
                fontSize: 11,
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
              ),
              dropdownColor: Colors.white,
              items: [10, 20, 30, 40, 50]
                  .map<DropdownMenuItem<int>>(
                    (int val) =>
                        DropdownMenuItem<int>(value: val, child: Text('$val')),
                  )
                  .toList(),
              onChanged: (int? newValue) {
                if (newValue != null) {
                  context.read<LeadsBloc>().add(
                    UpdateLeadsFilterEvent(pageSize: newValue, currentPage: 1),
                  );
                }
              },
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'entries',
          style: GoogleFonts.outfit(
            fontSize: 12,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildTableFooter(bool isMobile, int currentPage) {
    final total = widget.leads.length;
    final start = total == 0 ? 0 : (currentPage - 1) * _pageSize + 1;
    final end = (currentPage * _pageSize) > total
        ? total
        : (currentPage * _pageSize);

    final footerPadding = isMobile
        ? const EdgeInsets.symmetric(horizontal: 16, vertical: 12)
        : const EdgeInsets.symmetric(horizontal: 12, vertical: 12);

    return Container(
      padding: footerPadding,
      decoration: const BoxDecoration(
        color: Color(0xFFF9FAFB),
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(AppTheme.borderRadiusLarge),
        ),
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    Text(
                      'Showing $start to $end of $total entries',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    _buildPageSizeSelector(),
                  ],
                ),
                const SizedBox(height: 12),
                _buildPaginationControls(currentPage),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Showing $start to $end of $total entries',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 20),
                    _buildPageSizeSelector(),
                  ],
                ),
                _buildPaginationControls(currentPage),
              ],
            ),
    );
  }

  Widget _buildPaginationControls(int currentPage) {
    final int totalPages = (widget.leads.length / _pageSize).ceil();
    final int displayPages = totalPages > 0 ? totalPages : 1;

    List<Widget> pageButtons = [];

    if (displayPages <= 5) {
      for (int i = 1; i <= displayPages; i++) {
        pageButtons.add(
          _PageNumberButton(
            page: i,
            isActive: currentPage == i,
            onTap: () {
              context.read<LeadsBloc>().add(
                UpdateLeadsFilterEvent(currentPage: i),
              );
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
            context.read<LeadsBloc>().add(
              const UpdateLeadsFilterEvent(currentPage: 1),
            );
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
                context.read<LeadsBloc>().add(
                  UpdateLeadsFilterEvent(currentPage: i),
                );
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
            context.read<LeadsBloc>().add(
              UpdateLeadsFilterEvent(currentPage: displayPages),
            );
          },
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PaginationButton(
          onTap: currentPage > 1
              ? () {
                  context.read<LeadsBloc>().add(
                    UpdateLeadsFilterEvent(currentPage: currentPage - 1),
                  );
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
                  context.read<LeadsBloc>().add(
                    UpdateLeadsFilterEvent(currentPage: currentPage + 1),
                  );
                }
              : null,
          icon: Icons.chevron_right,
          isDisabled: currentPage >= displayPages,
        ),
      ],
    );
  }
}

class _LeadsTable extends StatefulWidget {
  final List<Map<String, dynamic>> leads;
  final bool isMobile;
  final List<Map<String, dynamic>> salesAgents;
  final Function(String userId, String? agentId) onAssignAgent;
  final Set<String> selectedLeadIds;
  final VoidCallback onSelectionChanged;

  const _LeadsTable({
    required this.leads,
    required this.isMobile,
    required this.salesAgents,
    required this.onAssignAgent,
    required this.selectedLeadIds,
    required this.onSelectionChanged,
  });

  @override
  State<_LeadsTable> createState() => _LeadsTableState();
}

class _LeadsTableState extends State<_LeadsTable> {
  int? hoveredRowIndex;

  bool get isAllSelected =>
      widget.leads.isNotEmpty &&
      widget.leads.every((l) => widget.selectedLeadIds.contains(l['id'] ?? ''));

  void _toggleAll() {
    setState(() {
      if (isAllSelected) {
        for (var l in widget.leads) {
          widget.selectedLeadIds.remove(l['id'] ?? '');
        }
      } else {
        for (var l in widget.leads) {
          if (l['id'] != null) {
            widget.selectedLeadIds.add(l['id']);
          }
        }
      }
    });
    widget.onSelectionChanged();
  }

  void _toggleSelection(String leadId) {
    setState(() {
      if (widget.selectedLeadIds.contains(leadId)) {
        widget.selectedLeadIds.remove(leadId);
      } else {
        widget.selectedLeadIds.add(leadId);
      }
    });
    widget.onSelectionChanged();
  }

  @override
  Widget build(BuildContext context) {
    final columns = [
      '', // Checkbox column
      'Lead Name',
      'Phone Number',
      'Location',
      'Last Activity',
      'Assigned Agent',
      'Source',
      'Lead Status',
      'Actions',
    ];

    Widget tableHeader = Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppTheme.lightBorderColor, width: 1.5),
        ),
        color: Color(0xFFF9FAFB),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Center(
              child: _CustomCheckbox(
                isSelected: isAllSelected,
                onTap: _toggleAll,
              ),
            ),
          ),
          Expanded(
            flex: 18,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _HeaderText(columns[1]),
            ),
          ),
          Expanded(
            flex: 14,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _HeaderText(columns[2]),
            ),
          ),
          Expanded(
            flex: 12,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _HeaderText(columns[3]),
            ),
          ),
          Expanded(
            flex: 11,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _HeaderText(columns[4]),
            ),
          ),
          Expanded(
            flex: 12,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _HeaderText(columns[5]),
            ),
          ),
          Expanded(
            flex: 10,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _HeaderText(columns[6]),
            ),
          ),
          Expanded(flex: 12, child: Center(child: _HeaderText(columns[7]))),
          Expanded(flex: 13, child: Center(child: _HeaderText(columns[8]))),
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final double minTableWidth = widget.isMobile ? 1100.0 : 900.0;
        final double tableWidth = constraints.maxWidth > minTableWidth
            ? constraints.maxWidth
            : minTableWidth;

        return ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(
            scrollbars: false,
            dragDevices: {
              ui.PointerDeviceKind.touch,
              ui.PointerDeviceKind.mouse,
              ui.PointerDeviceKind.trackpad,
            },
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: SizedBox(
              width: tableWidth,
              child: SelectionArea(
                child: Column(
                  children: [
                    tableHeader,
                    ...widget.leads.asMap().entries.map((entry) {
                      final index = entry.key;
                      final lead = entry.value;
                      final bool isAlternate = index % 2 == 1;
                      final String leadId = lead['id'] ?? '';
                      return _LeadRow(
                        lead: lead,
                        isAlternate: isAlternate,
                        isMobile: widget.isMobile,
                        isHovered: hoveredRowIndex == index,
                        isSelected: widget.selectedLeadIds.contains(leadId),
                        isAllSelected: isAllSelected,
                        onToggleSelection: () => _toggleSelection(leadId),
                        onTap: () => Navigator.pushNamed(
                          context,
                          '/leads/profile',
                          arguments: lead,
                        ),
                        onHover: () => setState(() => hoveredRowIndex = index),
                        onExit: () => setState(() => hoveredRowIndex = null),
                        salesAgents: widget.salesAgents,
                        onAssignAgent: widget.onAssignAgent,
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LeadRow extends StatelessWidget {
  final Map<String, dynamic> lead;
  final bool isAlternate;
  final bool isMobile;
  final bool isHovered;
  final bool isSelected;
  final bool isAllSelected;
  final VoidCallback onToggleSelection;
  final VoidCallback onTap;
  final VoidCallback onHover;
  final VoidCallback onExit;
  final List<Map<String, dynamic>> salesAgents;
  final Function(String userId, String? agentId) onAssignAgent;

  const _LeadRow({
    required this.lead,
    required this.isAlternate,
    required this.isMobile,
    required this.isHovered,
    required this.isSelected,
    required this.isAllSelected,
    required this.onToggleSelection,
    required this.onTap,
    required this.onHover,
    required this.onExit,
    required this.salesAgents,
    required this.onAssignAgent,
  });

  @override
  Widget build(BuildContext context) {
    Color rowBgColor = isAlternate ? const Color(0xFFFAFBFC) : Colors.white;
    if (isSelected) rowBgColor = AppTheme.primaryColor.withValues(alpha: 0.04);
    if (isHovered) rowBgColor = const Color(0xFFF1F9F3);

    return MouseRegion(
      onEnter: (_) => onHover(),
      onExit: (_) => onExit(),
      cursor: SystemMouseCursors.basic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          border: const Border(
            bottom: BorderSide(color: Color(0xFFF3F4F6), width: 0.5),
          ),
          color: rowBgColor,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Stack(
          children: [
            // Animated Left Accent Strip
            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              left: 0,
              top: isHovered ? 0 : 12,
              bottom: isHovered ? 0 : 12,
              width: isHovered ? 4 : 0,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 160),
                opacity: isHovered ? 1 : 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: const BorderRadius.horizontal(
                      right: Radius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
            Row(
              children: [
                SizedBox(
                  width: 40,
                  child: Center(
                    child: (isHovered || isSelected)
                        ? _CustomCheckbox(
                            isSelected: isSelected,
                            onTap: onToggleSelection,
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
                _cell(lead['name'], flex: 1.8, isBold: true),
                _cell(lead['phone'], flex: 1.4, isSecondary: true),
                _cell(
                  (lead['city'] != null &&
                          lead['city'].toString().trim().isNotEmpty &&
                          lead['state'] != null &&
                          lead['state'].toString().trim().isNotEmpty)
                      ? '${lead['city']}, ${lead['state']}'
                      : ((lead['city'] ?? '').toString().trim().isNotEmpty
                            ? lead['city']
                            : (lead['state'] ?? '')),
                  flex: 1.2,
                  isSecondary: true,
                ),
                _cell(lead['activity'], flex: 1.1, isSecondary: true),
                Expanded(
                  flex: 12,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value:
                              salesAgents.any(
                                (agent) => agent['_id'] == lead['agentId'],
                              )
                              ? lead['agentId']
                              : null,
                          isExpanded: true,
                          isDense: true,
                          icon: const Icon(
                            Icons.arrow_drop_down,
                            size: 16,
                            color: AppTheme.textSecondary,
                          ),
                          hint: Text(
                            '-',
                            style: GoogleFonts.outfit(
                              fontSize: 12.5,
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          onChanged: (String? newAgentId) {
                            onAssignAgent(lead['id'], newAgentId);
                          },
                          items: [
                            DropdownMenuItem<String>(
                              value: null,
                              child: Text(
                                '-',
                                style: GoogleFonts.outfit(
                                  fontSize: 12.5,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ),
                            ...salesAgents.map((agent) {
                              final agentName =
                                  '${agent['firstName'] ?? ''} ${agent['lastName'] ?? ''}'
                                      .trim();
                              return DropdownMenuItem<String>(
                                value: agent['_id'],
                                child: Text(
                                  agentName.isNotEmpty
                                      ? agentName
                                      : (agent['phoneNumber'] ?? ''),
                                  style: GoogleFonts.outfit(
                                    fontSize: 12.5,
                                    color: AppTheme.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                _cell(lead['source'], flex: 1.0, isSecondary: true),
                Expanded(
                  flex: 12,
                  child: Center(child: _StatusBadge(status: lead['status'])),
                ),
                Expanded(
                  flex: 13,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: _ConnectedActionButtons(onView: onTap),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _cell(
    String text, {
    double flex = 1.0,
    bool isBold = false,
    bool isSecondary = false,
    TextAlign textAlign = TextAlign.left,
  }) {
    return Expanded(
      flex: (flex * 10).toInt(),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Text(
          text,
          textAlign: textAlign,
          style: GoogleFonts.outfit(
            fontSize: 13,
            color: isBold
                ? AppTheme.textPrimary
                : (isSecondary ? AppTheme.textSecondary : AppTheme.textBody),
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _ConnectedActionButtons extends StatefulWidget {
  final VoidCallback onView;

  const _ConnectedActionButtons({required this.onView});

  @override
  State<_ConnectedActionButtons> createState() =>
      _ConnectedActionButtonsState();
}

class _ConnectedActionButtonsState extends State<_ConnectedActionButtons> {
  bool isViewHovered = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100, // Reduced width for single button
      height: 32, // Refined height
      child: MouseRegion(
        onEnter: (_) => setState(() => isViewHovered = true),
        onExit: (_) => setState(() => isViewHovered = false),
        child: GestureDetector(
          onTap: widget.onView,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOutCubic,
            transform: Matrix4.translationValues(
              0,
              isViewHovered ? -1.5 : 0.0,
              0,
            ),
            decoration: BoxDecoration(
              color: isViewHovered ? AppTheme.primaryColor : Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isViewHovered
                    ? AppTheme.primaryColor
                    : AppTheme.borderColor.withValues(alpha: 0.6),
              ),
              boxShadow: isViewHovered
                  ? [
                      BoxShadow(
                        color: AppTheme.primaryColor.withValues(alpha: 0.15),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.visibility_outlined,
                    size: 14,
                    color: isViewHovered ? Colors.white : AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'View',
                    style: GoogleFonts.outfit(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: isViewHovered
                          ? Colors.white
                          : AppTheme.textPrimary,
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
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case 'Order Pending':
        color = AppTheme.warning;
        break;
      case 'Order Confirm':
        color = AppTheme.success;
        break;
      case 'Assigned':
        color = AppTheme.info;
        break;
      case 'Unassigned':
        color = const Color(0xFF8B5CF6);
        break;
      case 'KYC Confirm':
        color = AppTheme.teal;
        break;
      case 'KYC Pending':
        color = AppTheme.error;
        break;
      default:
        color = AppTheme.info;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
      ),
      child: Text(
        status,
        style: GoogleFonts.outfit(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _HeaderText extends StatelessWidget {
  final String text;

  const _HeaderText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: AppTheme.tableHeader.copyWith(
        fontWeight:
            FontWeight.w800, // Softer weight matching other management pages
        letterSpacing: 0.5,
        fontSize: 11,
        color: AppTheme.textSecondary, // Softer neutral color
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _LeadsStatsGrid extends StatelessWidget {
  final List<Map<String, dynamic>> leads;
  final int verifiedDealersCount;

  const _LeadsStatsGrid({
    required this.leads,
    required this.verifiedDealersCount,
  });

  @override
  Widget build(BuildContext context) {
    final unassignedCount = leads.where((l) => l['agentId'] == null).length;
    final assignedCount = leads.where((l) => l['agentId'] != null).length;
    final kycPendingCount = leads
        .where(
          (l) => l['kycStatus'] == 'pending' || l['kycStatus'] == 'submitted',
        )
        .length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double spacing = AppTheme.spacingSmall;
        final int columns;
        if (constraints.maxWidth >= 1200) {
          columns = 4;
        } else if (constraints.maxWidth >= 768) {
          columns = 2;
        } else {
          columns = 2; // Mobile
        }

        final double width =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            StatCardWidget(
              width: width,
              title: 'Unassigned Lead',
              value: '$unassignedCount',
              icon: Icons.person_off_outlined,
              color: AppTheme.warning,
              isCompact: true,
            ),
            StatCardWidget(
              width: width,
              title: 'Assigned Lead',
              value: '$assignedCount',
              icon: Icons.person_pin_outlined,
              color: AppTheme.info,
              isCompact: true,
            ),
            StatCardWidget(
              width: width,
              title: 'KYC Pending',
              value: '$kycPendingCount',
              icon: Icons.pending_actions_outlined,
              color: AppTheme.error,
              isCompact: true,
            ),
            StatCardWidget(
              width: width,
              title: 'KYC Confirm',
              value: '$verifiedDealersCount',
              icon: Icons.verified_user_outlined,
              color: AppTheme.success,
              isCompact: true,
            ),
          ],
        );
      },
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

class _CustomCheckbox extends StatefulWidget {
  final bool isSelected;
  final VoidCallback? onTap;

  const _CustomCheckbox({required this.isSelected, this.onTap});

  @override
  State<_CustomCheckbox> createState() => _CustomCheckboxState();
}

class _CustomCheckboxState extends State<_CustomCheckbox> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: widget.isSelected
                ? AppTheme.primaryColor
                : (isHovered
                      ? AppTheme.primaryColor.withValues(alpha: 0.05)
                      : Colors.white),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: widget.isSelected
                  ? AppTheme.primaryColor
                  : (isHovered
                        ? AppTheme.primaryColor.withValues(alpha: 0.5)
                        : AppTheme.borderColor),
              width: 1.5,
            ),
          ),
          child: widget.isSelected
              ? const Icon(Icons.check_rounded, size: 12, color: Colors.white)
              : null,
        ),
      ),
    );
  }
}
