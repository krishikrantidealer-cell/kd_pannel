import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kd_pannel/app_theme.dart';
import 'package:kd_pannel/core/network/api_client.dart';
import 'package:kd_pannel/core/responsive/responsive.dart';
import 'package:kd_pannel/core/services/dashboard_service.dart';
import 'package:kd_pannel/features/shared/widgets/stat_card_widget.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';

class LeadsPage extends StatefulWidget {
  final bool isStandalone;
  const LeadsPage({super.key, this.isStandalone = false});

  @override
  State<LeadsPage> createState() => _LeadsPageState();
}

class _LeadsPageState extends State<LeadsPage> {
  List<Map<String, dynamic>> _allRawUsers = [];
  List<Map<String, dynamic>> _salesAgents = [];
  bool _isLoading = true;
  String? _errorMessage;

  String selectedDropdown = 'This Month';
  PickerDateRange? _selectedRange;
  String selectedFilterChip = 'All';
  int currentPage = 1;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final usersRes = await ApiClient().get('/users');
      if (usersRes.statusCode == 200) {
        final data = jsonDecode(usersRes.body);
        if (data['success'] == true) {
          _allRawUsers = List<Map<String, dynamic>>.from(data['users'] ?? []);
        }
      } else {
        throw Exception('Failed to load users: ${usersRes.statusCode}');
      }

      final salesRes = await ApiClient().get('/users?role=sales');
      if (salesRes.statusCode == 200) {
        final data = jsonDecode(salesRes.body);
        if (data['success'] == true) {
          _salesAgents = List<Map<String, dynamic>>.from(data['users'] ?? []);
        }
      } else {
        throw Exception('Failed to load sales agents: ${salesRes.statusCode}');
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _assignAgent(String userId, String? agentId) async {
    try {
      final res = await ApiClient().put('/users/$userId/assign-agent', {
        'agentId': agentId,
      });
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Agent assigned successfully'), backgroundColor: AppTheme.success),
          );
          _fetchData();
        }
      } else {
        throw Exception('Failed to assign agent: ${res.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
      );
    }
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
    return _allRawUsers.where((u) {
      final role = u['role'] ?? 'user';
      final kycStatus = u['kycStatus'] ?? 'pending';
      return role == 'user' && kycStatus != 'verified';
    }).map((u) {
      return {
        'id': u['_id'],
        'name': (u['firstName'] != null && u['firstName'].toString().trim().isNotEmpty)
            ? '${u['firstName']} ${u['lastName'] ?? ''}'.trim()
            : (u['shopName'] != null && u['shopName'].toString().trim().isNotEmpty)
                ? u['shopName']
                : (u['phoneNumber'] ?? 'Unnamed Lead'),
        'phone': u['phoneNumber'] ?? '',
        'city': u['address']?['cityTehsil'] ?? '',
        'state': u['address']?['state'] ?? '',
        'activity': u['updatedAt'] != null ? _formatTimeAgo(u['updatedAt']) : '-',
        'agent': u['assignedAgent'] != null
            ? '${u['assignedAgent']['firstName']} ${u['assignedAgent']['lastName'] ?? ''}'.trim()
            : '-',
        'agentId': u['assignedAgent']?['_id'],
        'source': u['source'] ?? 'App',
        'status': u['kycStatus'] == 'pending' || u['kycStatus'] == 'submitted'
            ? 'KYC Pending'
            : (u['assignedAgent'] != null ? 'Assigned' : 'Unassigned'),
        'kycStatus': u['kycStatus'] ?? 'pending',
        'gstNumber': u['gstNumber'] ?? '',
        'userType': u['userType'] ?? '',
        'licenceImage': u['licenceImage'] ?? '',
        'shopImage': u['shopImage'] ?? '',
      };
    }).toList();
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
    'Order Pending',
    'Order Confirm',
    'Assigned',
    'Unassigned',
    'KYC Confirm',
    'KYC Pending',
  ];

  final Map<String, String> statusMapping = {
    'Order Pending': 'Order Pending',
    'Order Confirm': 'Order Confirm',
    'Assigned': 'Assigned',
    'Unassigned': 'Unassigned',
    'KYC Confirm': 'KYC Confirm',
    'KYC Pending': 'KYC Pending',
  };

  List<Map<String, dynamic>> get filteredLeads {
    List<Map<String, dynamic>> leads = allLeads;

    if (selectedFilterChip != 'All') {
      if (selectedFilterChip == 'Unassigned') {
        leads = leads.where((l) => l['agentId'] == null).toList();
      } else if (selectedFilterChip == 'Assigned') {
        leads = leads.where((l) => l['agentId'] != null).toList();
      } else if (selectedFilterChip == 'KYC Pending') {
        leads = leads.where((l) => l['kycStatus'] == 'pending' || l['kycStatus'] == 'submitted').toList();
      } else if (selectedFilterChip == 'KYC Confirm') {
        leads = []; // Verified users are dealers, so they don't show up here
      }
    }

    final query = _searchController.text.toLowerCase();
    if (query.isNotEmpty) {
      leads = leads.where((l) {
        return l['name'].toString().toLowerCase().contains(query) ||
            l['phone'].toString().toLowerCase().contains(query) ||
            l['city'].toString().toLowerCase().contains(query) ||
            l['source'].toString().toLowerCase().contains(query) ||
            l['agent'].toString().toLowerCase().contains(query);
      }).toList();
    }

    return leads;
  }

  String get _rangeDisplay {
    if (_selectedRange != null &&
        _selectedRange!.startDate != null &&
        _selectedRange!.endDate != null) {
      final start = _selectedRange!.startDate!;
      final end = _selectedRange!.endDate!;
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
    return selectedDropdown;
  }

  void _showSyncfusionDatePicker() {
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
            initialSelectedRange: _selectedRange,
            onSubmit: (Object? val) {
              if (val is PickerDateRange &&
                  val.startDate != null &&
                  val.endDate != null) {
                setState(() {
                  _selectedRange = val;
                  selectedDropdown = '';
                });
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
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Create Sales Agent',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: firstNameController,
                    decoration: _buildInputDecoration('First Name', Icons.person_outline),
                    validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: lastNameController,
                    decoration: _buildInputDecoration('Last Name', Icons.person_outline),
                    validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: emailController,
                    decoration: _buildInputDecoration('Email Address', Icons.email_outlined),
                    keyboardType: TextInputType.emailAddress,
                    validator: (val) => val == null || !val.contains('@') ? 'Invalid email' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phoneController,
                    decoration: _buildInputDecoration('Phone Number', Icons.phone_outlined),
                    keyboardType: TextInputType.phone,
                    validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: passwordController,
                    decoration: _buildInputDecoration('Password', Icons.lock_outline),
                    obscureText: true,
                    validator: (val) => val == null || val.length < 6 ? 'Password must be at least 6 characters' : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: GoogleFonts.outfit(color: AppTheme.textSecondary, fontWeight: FontWeight.bold),
              ),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (formKey.currentState!.validate()) {
                        setDialogState(() => isSubmitting = true);
                        try {
                          final res = await ApiClient().post('/users/sales', {
                            'firstName': firstNameController.text.trim(),
                            'lastName': lastNameController.text.trim(),
                            'email': emailController.text.trim(),
                            'phoneNumber': phoneController.text.trim(),
                            'password': passwordController.text,
                          });
                          if (res.statusCode == 201) {
                            final data = jsonDecode(res.body);
                            if (data['success'] == true) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Sales agent created successfully'), backgroundColor: AppTheme.success),
                                );
                                Navigator.pop(context);
                                _fetchData();
                              }
                            }
                          } else {
                            final data = jsonDecode(res.body);
                            throw Exception(data['message'] ?? 'Failed to create sales agent');
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
                            );
                          }
                        } finally {
                          if (context.mounted) {
                            setDialogState(() => isSubmitting = false);
                          }
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.outfit(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
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
    final verifiedDealersCount = _allRawUsers.where((u) => u['role'] == 'user' && u['kycStatus'] == 'verified').length;

    final Widget body = _isLoading
        ? const Center(
            child: Padding(
              padding: EdgeInsets.all(80.0),
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            ),
          )
        : _errorMessage != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(40.0),
                  child: Text('Error: $_errorMessage', style: const TextStyle(color: Colors.red)),
                ),
              )
            : ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (!widget.isStandalone)
                              Text(
                                isMobile ? 'Leads' : 'Leads Management',
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
                                    isMobile ? 'Sales Agent' : 'Create Sales Agent',
                                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryColor,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: isMobile ? 12 : 16,
                                      vertical: isMobile ? 10 : 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                _buildTimeframeRow(isMobile),
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
                        _buildFilterChips(isMobile),
                        const SizedBox(height: 16),
                        _LeadsTableCard(
                          leads: filteredLeads,
                          totalEntries: filteredLeads.length,
                          isMobile: isMobile,
                          salesAgents: _salesAgents,
                          onAssignAgent: _assignAgent,
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
  }

  Widget _buildTimeframeRow(bool isMobile) {
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
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: _showSyncfusionDatePicker,
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
                      _rangeDisplay,
                      style: GoogleFonts.outfit(
                        fontSize: isMobile ? 12 : 13,
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
                  setState(() {
                    selectedDropdown = newValue;
                    _selectedRange = null;
                  });
                }
              },
              items: dropdownOptions
                  .map<DropdownMenuItem<String>>(
                    (String value) => DropdownMenuItem<String>(
                      value: value,
                      child: Text(
                        value,
                        style: GoogleFonts.outfit(
                          fontSize: isMobile ? 12 : 13,
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

  Widget _buildFilterChips(bool isMobile) {
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
                          isSelected: selectedFilterChip == chip,
                          onTap: () => setState(() {
                            selectedFilterChip = chip;
                            currentPage = 1;
                            _searchController
                                .clear(); // Clear search on filter change
                          }),
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
                        isSelected: selectedFilterChip == chip,
                        onTap: () => setState(() {
                          selectedFilterChip = chip;
                          currentPage = 1;
                        }),
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
      case 'Order Pending':
        return Icons.schedule_rounded;
      case 'Order Confirm':
        return Icons.check_circle_outline_rounded;
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
              onChanged: (val) => setState(() {}),
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
      case 'Order Pending':
        return AppTheme.warning.withValues(alpha: 0.7);
      case 'Order Confirm':
        return AppTheme.success.withValues(alpha: 0.7);
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

  const _LeadsTableCard({
    required this.leads,
    required this.totalEntries,
    required this.isMobile,
    required this.salesAgents,
    required this.onAssignAgent,
  });

  @override
  State<_LeadsTableCard> createState() => _LeadsTableCardState();
}

class _LeadsTableCardState extends State<_LeadsTableCard> {
  String selectedSource = 'Lead Source';
  String selectedAssign = 'Assign';
  PickerDateRange? _selectedTableRange;
  String selectedTableDropdown = 'Today';

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
  Widget build(BuildContext context) {
    final bool isDesktop = Responsive.isDesktop(context);

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
                      _buildCombinedControls(),
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
                        child: _buildCombinedControls(),
                      ),
                    ],
                  ),
          ),
          _LeadsTable(
            leads: widget.leads,
            isMobile: widget.isMobile,
            salesAgents: widget.salesAgents,
            onAssignAgent: widget.onAssignAgent,
          ),
          _buildTableFooter(widget.isMobile),
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

  Widget _buildTableFooter(bool isMobile) {
    final footerPadding = isMobile
        ? const EdgeInsets.symmetric(horizontal: 16, vertical: 12)
        : const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ); // Aligned with card header grid

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
                Text(
                  'Showing 1 to ${widget.leads.length} of ${widget.totalEntries} entries',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                _buildPaginationControls(),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Showing 1 to ${widget.leads.length} of ${widget.totalEntries} entries',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                _buildPaginationControls(),
              ],
            ),
    );
  }

  Widget _buildPaginationControls() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PaginationButton(
          onTap: () {},
          icon: Icons.chevron_left,
          isDisabled: true,
        ),
        const SizedBox(width: 12),
        const _PageNumberButton(page: 1, isActive: true, onTap: null),
        const SizedBox(width: 8), // Refined spacing
        const _PageNumberButton(page: 2, isActive: false, onTap: null),
        const SizedBox(width: 8), // Refined spacing
        const _PageNumberButton(page: 3, isActive: false, onTap: null),
        const SizedBox(width: 12),
        _PaginationButton(
          onTap: () {},
          icon: Icons.chevron_right,
          isDisabled: false,
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

  const _LeadsTable({
    required this.leads,
    required this.isMobile,
    required this.salesAgents,
    required this.onAssignAgent,
  });

  @override
  State<_LeadsTable> createState() => _LeadsTableState();
}

class _LeadsTableState extends State<_LeadsTable> {
  int? hoveredRowIndex;
  final Set<String> selectedPhones = {};

  bool get isAllSelected =>
      widget.leads.isNotEmpty &&
      widget.leads.every((l) => selectedPhones.contains(l['phone'] ?? ''));

  void _toggleAll() {
    setState(() {
      if (isAllSelected) {
        for (var l in widget.leads) {
          selectedPhones.remove(l['phone'] ?? '');
        }
      } else {
        for (var l in widget.leads) {
          selectedPhones.add(l['phone'] ?? '');
        }
      }
    });
  }

  void _toggleSelection(String phone) {
    setState(() {
      if (selectedPhones.contains(phone)) {
        selectedPhones.remove(phone);
      } else {
        selectedPhones.add(phone);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final columns = [
      '', // Checkbox column
      'Lead Name',
      'Phone Number',
      'City',
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
            flex: 10,
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
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
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
                      final String phone = lead['phone'] ?? '';
                      return _LeadRow(
                        lead: lead,
                        isAlternate: isAlternate,
                        isMobile: widget.isMobile,
                        isHovered: hoveredRowIndex == index,
                        isSelected: selectedPhones.contains(phone),
                        isAllSelected: isAllSelected,
                        onToggleSelection: () => _toggleSelection(phone),
                        onTap: () =>
                            Navigator.pushNamed(context, '/leads/profile', arguments: lead),
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
                _cell(lead['city'], flex: 1.0, isSecondary: true),
                _cell(lead['activity'], flex: 1.1, isSecondary: true),
                Expanded(
                  flex: 12,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: salesAgents.any((agent) => agent['_id'] == lead['agentId']) ? lead['agentId'] : null,
                          isExpanded: true,
                          isDense: true,
                          icon: const Icon(Icons.arrow_drop_down, size: 16, color: AppTheme.textSecondary),
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
                              final agentName = '${agent['firstName'] ?? ''} ${agent['lastName'] ?? ''}'.trim();
                              return DropdownMenuItem<String>(
                                value: agent['_id'],
                                child: Text(
                                  agentName.isNotEmpty ? agentName : (agent['phoneNumber'] ?? ''),
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
                      child: _ConnectedActionButtons(
                        onView: onTap,
                      ),
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
            transform: Matrix4.translationValues(0, isViewHovered ? -1.5 : 0.0, 0),
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
                      color: isViewHovered ? Colors.white : AppTheme.textPrimary,
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
    final kycPendingCount = leads.where((l) => l['kycStatus'] == 'pending' || l['kycStatus'] == 'submitted').length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double spacing = AppTheme.spacingSmall;
        final int columns;
        if (constraints.maxWidth >= 1200) {
          columns = 6;
        } else if (constraints.maxWidth >= 768) {
          columns = 3;
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
              imagePath: 'assets/images/New leads.png',
              color: AppTheme.warning,
              isCompact: true,
            ),
            StatCardWidget(
              width: width,
              title: 'Assigned Lead',
              value: '$assignedCount',
              imagePath: 'assets/images/Active dealer .png',
              color: AppTheme.info,
              isCompact: true,
            ),
            StatCardWidget(
              width: width,
              title: 'KYC Pending',
              value: '$kycPendingCount',
              imagePath: 'assets/images/order pending.png',
              color: AppTheme.error,
              isCompact: true,
            ),
            StatCardWidget(
              width: width,
              title: 'KYC Confirm',
              value: '$verifiedDealersCount',
              imagePath: 'assets/images/dealer onbord.png',
              color: AppTheme.success,
              isCompact: true,
            ),
            StatCardWidget(
              width: width,
              title: 'Order Pending',
              value: '0',
              imagePath: 'assets/images/order status.png',
              color: AppTheme.warning,
              isCompact: true,
            ),
            StatCardWidget(
              width: width,
              title: 'Order Confirm',
              value: '0',
              imagePath: 'assets/images/order today.png',
              color: AppTheme.lightGreen,
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
  final bool isHeader;

  const _CustomCheckbox({
    required this.isSelected,
    this.onTap,
    this.isHeader = false,
  });

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
