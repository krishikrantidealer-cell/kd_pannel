import 'dart:ui' as ui;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kd_pannel/app_theme.dart';
import 'package:kd_pannel/core/responsive/responsive.dart';
import 'package:kd_pannel/features/shared/widgets/stat_card_widget.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shimmer/shimmer.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/leads_bloc.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/leads_event.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/leads_state.dart';
import 'package:kd_pannel/core/auth/auth_service.dart';
import 'package:kd_pannel/util/export_helper.dart';
import 'package:kd_pannel/core/network/websocket_service.dart';
import 'package:kd_pannel/core/utils/navigation_service.dart';

class LeadsPage extends StatefulWidget {
  final bool isStandalone;
  const LeadsPage({super.key, this.isStandalone = false});

  @override
  State<LeadsPage> createState() => _LeadsPageState();
}

class _LeadsPageState extends State<LeadsPage> {
  final TextEditingController _searchController = TextEditingController();
  bool _isExporting = false;
  LeadsBloc? _leadsBloc;

  void _exportLeadsToCSV() async {
    setState(() => _isExporting = true);

    // Generate CSV content
    final leads = filteredLeads;
    final headers = [
      'Name',
      'Phone',
      'City',
      'State',
      'Assigned Agent',
      'Source',
      'Status',
      'KYC Status',
      'GST Number',
      'User Type',
    ];

    final buffer = StringBuffer();
    buffer.writeln(
      headers.map((h) => '"${h.replaceAll('"', '""')}"').join(','),
    );

    for (final lead in leads) {
      final row = [
        lead['name'] ?? '',
        lead['phone'] ?? '',
        lead['city'] ?? '',
        lead['state'] ?? '',
        lead['agent'] ?? '',
        lead['source'] ?? '',
        lead['status'] ?? '',
        lead['kycStatus'] ?? '',
        lead['gstNumber'] ?? '',
        lead['userType'] ?? '',
      ];
      buffer.writeln(
        row.map((val) => '"${val.toString().replaceAll('"', '""')}"').join(','),
      );
    }

    // Simulate small delay for UI feedback
    await Future.delayed(const Duration(milliseconds: 1000));

    if (mounted) {
      // Trigger download using the platform export helper
      downloadCsv(buffer.toString(), 'leads_export.csv');

      setState(() => _isExporting = false);
      NavigationService.messengerKey.currentState?.showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.info,
          behavior: SnackBarBehavior.floating,
          content: Row(
            children: [
              const Icon(Icons.download_rounded, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                'Leads data exported successfully to CSV!',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  StreamSubscription? _wsSubscription;

  @override
  void initState() {
    super.initState();
    _leadsBloc = context.read<LeadsBloc>();
    final bloc = _leadsBloc!;
    _searchController.text = bloc.state.searchQuery;
    if (bloc.state.status == LeadsStatus.initial) {
      bloc.add(const FetchLeadsDataEvent());
    }

    WebSocketService().connect();

    _wsSubscription = WebSocketService().leadsUpdates.listen((_) {
      if (mounted && _leadsBloc != null) {
        _leadsBloc!.add(const FetchLeadsDataEvent(forceRefresh: true));
      }
    });
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
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

  Future<void> _editLead(Map<String, dynamic> lead) async {
    final nameController = TextEditingController(text: lead['name']);
    final shopNameController = TextEditingController(
      text: lead['shopName'] ?? '',
    );
    final gstController = TextEditingController(text: lead['gstNumber'] ?? '');
    final phoneController = TextEditingController(text: lead['phone']);
    final villageAreaController = TextEditingController(
      text: lead['villageArea'] ?? '',
    );
    final addressLine2Controller = TextEditingController(
      text: lead['addressLine2'] ?? '',
    );
    final cityController = TextEditingController(text: lead['city']);
    final stateController = TextEditingController(text: lead['state']);
    final pincodeController = TextEditingController(
      text: lead['pincode'] ?? '',
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Edit Details',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildEditField('Name', nameController),
              const SizedBox(height: 12),
              _buildEditField('Shop Name', shopNameController),
              const SizedBox(height: 12),
              _buildEditField('GST Number', gstController),
              const SizedBox(height: 12),
              _buildEditField(
                'Phone (Not Editable)',
                phoneController,
                readOnly: true,
              ),
              const SizedBox(height: 12),
              _buildEditField(
                'Village/Area (Address 1)',
                villageAreaController,
              ),
              const SizedBox(height: 12),
              _buildEditField(
                'Address Line 2 (Optional)',
                addressLine2Controller,
              ),
              const SizedBox(height: 12),
              _buildEditField('City/Tehsil', cityController),
              const SizedBox(height: 12),
              _buildEditField('State', stateController),
              const SizedBox(height: 12),
              _buildEditField('Pincode', pincodeController),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final String fullName = nameController.text.trim();
      final names = fullName.split(' ');
      final firstName = names.isNotEmpty ? names[0] : '';
      final lastName = names.length > 1 ? names.sublist(1).join(' ') : '';

      _leadsBloc?.add(
        UpdateLeadDetailsEvent(
          userId: lead['id'],
          updateData: {
            'firstName': firstName,
            'lastName': lastName,
            'shopName': shopNameController.text.trim(),
            'gstNumber': gstController.text.trim(),
            'phoneNumber': phoneController.text.trim(),
            'address': {
              'villageArea': villageAreaController.text.trim(),
              'addressLine2': addressLine2Controller.text.trim(),
              'address2': addressLine2Controller.text.trim(),
              'cityTehsil': cityController.text.trim(),
              'state': stateController.text.trim(),
              'pincode': pincodeController.text.trim(),
            },
          },
        ),
      );
    }
  }

  Widget _buildEditField(
    String label,
    TextEditingController controller, {
    bool readOnly = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          readOnly: readOnly,
          style: GoogleFonts.outfit(
            fontSize: 14,
            color: readOnly ? AppTheme.textSecondary : AppTheme.textPrimary,
          ),
          decoration: InputDecoration(
            fillColor: readOnly ? const Color(0xFFF9FAFB) : Colors.white,
            filled: readOnly,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppTheme.borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppTheme.borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: AppTheme.primaryColor,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _deleteLead(String userId, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: AppTheme.error,
              size: 28,
            ),
            const SizedBox(width: 12),
            Text(
              'Delete Record',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete lead "$name"? This action cannot be undone and all associated data will be removed.',
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
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: Text(
              'Confirm Delete',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      context.read<LeadsBloc>().add(DeleteLeadEvent(userId));
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
    final state = context.read<LeadsBloc>().state;
    return _getAllLeads(state.allRawUsers);
  }

  List<Map<String, dynamic>> _getAllLeads(List<Map<String, dynamic>> rawUsers) {
    final isSales = AuthService().isSales;
    final agentId = AuthService().currentUserId;

    return rawUsers
        .where((u) {
          final role = u['role'] ?? 'user';
          if (role != 'user') return false;

          // Leads should ONLY show non-verified users
          final kycStatus = u['kycStatus'] ?? 'pending';
          if (kycStatus == 'verified') return false;

          if (isSales) {
            final dynamic assignedAgent = u['assignedAgent'];
            String? assignedAgentId;
            if (assignedAgent is Map) {
              assignedAgentId = (assignedAgent['_id'] ?? assignedAgent['\$oid'])?.toString();
            } else {
              assignedAgentId = assignedAgent?.toString();
            }
            return assignedAgentId == agentId;
          }
          return true;
        })
        .map((u) {
          final String personName =
              (u['firstName'] != null || u['lastName'] != null)
              ? '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'.trim()
              : '';
          final dynamic assignedAgent = u['assignedAgent'];
          String? resolvedAgentId;
          String agentName = '-';
          
          if (assignedAgent != null) {
            if (assignedAgent is Map) {
              resolvedAgentId = (assignedAgent['_id'] ?? assignedAgent['\$oid'])?.toString();
              agentName = '${assignedAgent['firstName'] ?? ''} ${assignedAgent['lastName'] ?? ''}'.trim();
              if (agentName.isEmpty) agentName = (assignedAgent['phoneNumber'] ?? '-').toString();
            } else {
              resolvedAgentId = assignedAgent.toString();
              agentName = 'Assigned'; // Fallback name if it's just an ID
            }
            if (resolvedAgentId == null || resolvedAgentId.trim().isEmpty || resolvedAgentId == '-') {
              resolvedAgentId = null;
              agentName = '-';
            }
          }

          return {
            'id': u['_id'],
            'name': personName.isNotEmpty
                ? personName
                : (u['phoneNumber'] ?? 'Unnamed Lead'),
            'phone': u['phoneNumber'] ?? '',
            'shopName': u['shopName'] ?? '',
            'villageArea': u['address']?['villageArea'] ?? '',
            'addressLine2': u['address']?['addressLine2'] ?? '',
            'city': u['address']?['cityTehsil'] ?? '',
            'state': u['address']?['state'] ?? '',
            'pincode': u['address']?['pincode'] ?? '',
            'activity': u['updatedAt'] != null
                ? _formatTimeAgo(u['updatedAt'])
                : '-',
            'agent': agentName,
            'agentId': resolvedAgentId,
            'source': u['source'] ?? 'App',
            'processingStatus':
                u['kycStatus'] == 'pending' || u['kycStatus'] == 'submitted'
                ? 'KYC Pending'
                : (resolvedAgentId != null ? 'Assigned' : 'Unassigned'),
            'kycStatus': u['kycStatus'] ?? 'pending',
            'gstNumber': u['gstNumber'] ?? '',
            'userType': u['userType'] ?? '',
            'licenceImage': u['licenceImage'] ?? '',
            'shopImage': u['shopImage'] ?? '',
            'status': u['status'] ?? u['leadStatus'] ?? 'prospect',
            'notes': u['notes'] ?? u['leadNotes'] ?? '',
            'createdAt': u['createdAt'],
            'updatedAt': u['updatedAt'],
            'notesHistory': u['notesHistory'] ?? [],
          };
        })
        .toList();
  }

  final List<String> dropdownOptions = [
    'All Time',
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
    'KYC Pending',
    'KYC Confirm',
  ];

  final Map<String, String> statusMapping = {
    'Assigned': 'Assigned',
    'Unassigned': 'Unassigned',
  };

  List<Map<String, dynamic>> get filteredLeads {
    final state = context.read<LeadsBloc>().state;
    return _getFilteredLeads(allLeads, state);
  }

  List<Map<String, dynamic>> _getFilteredLeads(
    List<Map<String, dynamic>> leads,
    LeadsState state,
  ) {
    List<Map<String, dynamic>> result = leads;

    // 2. Chip Filtering
    if (state.selectedFilterChip != 'All') {
      if (state.selectedFilterChip == 'Unassigned') {
        result = result
            .where((l) => l['agentId'] == null && l['kycStatus'] != 'verified')
            .toList();
      } else if (state.selectedFilterChip == 'Assigned') {
        result = result
            .where((l) => l['agentId'] != null && l['kycStatus'] != 'verified')
            .toList();
      } else if (state.selectedFilterChip == 'KYC Pending') {
        result = result
            .where(
              (l) =>
                  l['kycStatus'] == 'pending' || l['kycStatus'] == 'submitted',
            )
            .toList();
      } else if (state.selectedFilterChip == 'KYC Confirm') {
        result = result.where((l) => l['kycStatus'] == 'verified').toList();
      }
    }

    // 3. Search Query
    final query = state.searchQuery.toLowerCase();
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

  Widget _buildSkeletonLoading(bool isDesktop, bool isMobile) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 28 : 16,
        vertical: isDesktop ? 20 : 12,
      ),
      child: Shimmer.fromColors(
        baseColor: Colors.grey[200]!,
        highlightColor: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 40,
              width: 200,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: List.generate(
                isDesktop ? 4 : 2,
                (index) => Expanded(
                  child: Container(
                    height: 100,
                    margin: EdgeInsets.only(
                      right: index == (isDesktop ? 3 : 1) ? 0 : 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Container(
              height: 40,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              height: 500,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = Responsive.isDesktop(context);
    final bool isMobile = Responsive.isMobile(context);

    return SelectionArea(
      child: BlocConsumer<LeadsBloc, LeadsState>(
        listener: (context, state) {
          if (_searchController.text != state.searchQuery) {
            _searchController.text = state.searchQuery;
          }
          if (state.errorMessage != null) {
            NavigationService.messengerKey.currentState?.showSnackBar(
              SnackBar(
                content: Text(state.errorMessage!),
                backgroundColor: AppTheme.error,
              ),
            );
            _leadsBloc?.add(const ClearLeadsMessageEvent());
          }
          if (state.actionSuccessMessage != null) {
            NavigationService.messengerKey.currentState?.showSnackBar(
              SnackBar(
                content: Text(state.actionSuccessMessage!),
                backgroundColor: AppTheme.success,
              ),
            );
            _leadsBloc?.add(const ClearLeadsMessageEvent());
          }
        },
        builder: (context, state) {
          final allLeadsData = _getAllLeads(state.allRawUsers);

          // Date Filtering (Global for page)
          DateTime? startDate;
          DateTime? endDate;

          if (state.selectedRange != null && state.selectedRange!.startDate != null) {
            startDate = state.selectedRange!.startDate;
            endDate = state.selectedRange!.endDate ?? state.selectedRange!.startDate;
            endDate = DateTime(endDate!.year, endDate.month, endDate.day, 23, 59, 59);
          } else if (state.selectedTimeframe.isNotEmpty && state.selectedTimeframe != 'All Time') {
            final now = DateTime.now();
            endDate = now;
            switch (state.selectedTimeframe) {
              case 'Last 1 Week': startDate = now.subtract(const Duration(days: 7)); break;
              case 'Last 2 Weeks': startDate = now.subtract(const Duration(days: 14)); break;
              case 'Last 3 Weeks': startDate = now.subtract(const Duration(days: 21)); break;
              case 'Last 1 Month': startDate = DateTime(now.year, now.month - 1, now.day); break;
              case 'Last 3 Months': startDate = DateTime(now.year, now.month - 3, now.day); break;
              case 'Last 6 Months': startDate = DateTime(now.year, now.month - 6, now.day); break;
              case 'This Month': startDate = DateTime(now.year, now.month, 1); break;
            }
          }

          var dateFilteredLeads = allLeadsData;
          if (startDate != null && endDate != null) {
            dateFilteredLeads = allLeadsData.where((l) {
              final dateStr = l['createdAt'] ?? l['updatedAt'];
              if (dateStr == null) return false;
              try {
                final date = DateTime.parse(dateStr).toLocal();
                return date.isAfter(startDate!) && date.isBefore(endDate!);
              } catch (e) {
                return false;
              }
            }).toList();
          }

          final filteredLeadsData = _getFilteredLeads(dateFilteredLeads, state);

          final verifiedDealersCount = state.allRawUsers.where((u) {
            final role = u['role'] ?? 'user';
            final kycStatus = u['kycStatus'] ?? 'pending';
            final isVerifiedDealer = role == 'user' && kycStatus == 'verified';
            if (!isVerifiedDealer) return false;

            if (AuthService().isSales) {
              final dynamic assignedAgent = u['assignedAgent'];
              String? assignedAgentId;
              if (assignedAgent is Map) {
                assignedAgentId = (assignedAgent['_id'] ?? assignedAgent['\$oid'])?.toString();
              } else {
                assignedAgentId = assignedAgent?.toString();
              }
              return assignedAgentId == AuthService().currentUserId;
            }
            return true;
          }).length;

          final Widget body = Builder(
            builder: (context) => (state.status == LeadsStatus.loading && state.allRawUsers.isEmpty)
                ? _buildSkeletonLoading(isDesktop, isMobile)
                : CustomScrollView(
                    slivers: [
                            SliverPadding(
                              padding: EdgeInsets.symmetric(
                                horizontal: isDesktop ? 28 : 16,
                                vertical: isDesktop ? 20 : 12,
                              ),
                              sliver: SliverToBoxAdapter(
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
                                                child: _buildTimeframeRow(
                                                  isMobile,
                                                  state,
                                                ),
                                              ),
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
                                                  padding: EdgeInsets.zero,
                                                  onPressed: _isExporting
                                                      ? null
                                                      : _exportLeadsToCSV,
                                                  icon: _isExporting
                                                      ? const SizedBox(
                                                          width: 16,
                                                          height: 16,
                                                          child:
                                                              CircularProgressIndicator(
                                                                strokeWidth: 2,
                                                                color:
                                                                    AppTheme.primaryColor,
                                                              ),
                                                        )
                                                      : const Icon(
                                                          Icons.download_rounded,
                                                          size: 18,
                                                          color: AppTheme.primaryColor,
                                                        ),
                                                ),
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
                                              AuthService().isSales
                                                  ? 'My Assigned Leads'
                                                  : 'Leads Management',
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
                                              OutlinedButton.icon(
                                                onPressed: _isExporting
                                                    ? null
                                                    : _exportLeadsToCSV,
                                                icon: _isExporting
                                                    ? const SizedBox(
                                                        width: 14,
                                                        height: 14,
                                                        child: CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                          color: AppTheme.primaryColor,
                                                        ),
                                                      )
                                                    : const Icon(
                                                        Icons.download,
                                                        size: 16,
                                                      ),
                                                label: Text(
                                                  _isExporting
                                                      ? 'Exporting...'
                                                      : 'Export CSV',
                                                  style: GoogleFonts.outfit(
                                                    fontWeight: FontWeight.bold,
                                                    color: AppTheme.primaryColor,
                                                  ),
                                                ),
                                                style: OutlinedButton.styleFrom(
                                                  side: const BorderSide(
                                                    color: AppTheme.primaryColor,
                                                    width: 1.5,
                                                  ),
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 12,
                                                  ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(
                                                      12,
                                                    ),
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
                                      leads: dateFilteredLeads,
                                      verifiedDealersCount: (state.selectedTimeframe == 'All Time' || (state.selectedTimeframe.isEmpty && state.selectedRange == null))
                                          ? verifiedDealersCount
                                          : dateFilteredLeads.where((l) => l['kycStatus'] == 'verified').length,
                                    ),
                                    const SizedBox(height: 24),
                                    _buildFilterChips(isMobile, state),
                                    const SizedBox(height: 16),
                                  ],
                                ),
                              ),
                            ),
                            SliverPadding(
                              padding: EdgeInsets.symmetric(horizontal: isDesktop ? 28 : 16),
                              sliver: SliverToBoxAdapter(
                                child: _LeadsTableCard(
                                  leads: filteredLeadsData,
                                  totalEntries: filteredLeadsData.length,
                                  isMobile: isMobile,
                                  salesAgents: state.salesAgents,
                                  onAssignAgent: _assignAgent,
                                  onBulkAssignAgent: _bulkAssignAgent,
                                  onEditLead: _editLead,
                                  onDeleteLead: _deleteLead,
                                ),
                              ),
                            ),
                            const SliverToBoxAdapter(child: SizedBox(height: 40)),
                          ],
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
      ),
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
      case 'KYC Pending':
        return Icons.pending_actions_rounded;
      case 'KYC Confirm':
        return Icons.verified_user_rounded;
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

  Widget _buildSkeletonLoading(bool isDesktop, bool isMobile) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 28 : 16,
        vertical: isDesktop ? 20 : 12,
      ),
      child: Shimmer.fromColors(
        baseColor: Colors.grey[200]!,
        highlightColor: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 40,
              width: 200,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: List.generate(
                isDesktop ? 4 : 2,
                (index) => Expanded(
                  child: Container(
                    height: 100,
                    margin: EdgeInsets.only(
                      right: index == (isDesktop ? 3 : 1) ? 0 : 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Container(
              height: 40,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              height: 500,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ],
        ),
      ),
    );
  }

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
  final Function(Map<String, dynamic> lead) onEditLead;
  final Function(String userId, String name) onDeleteLead;

  const _LeadsTableCard({
    required this.leads,
    required this.totalEntries,
    required this.isMobile,
    required this.salesAgents,
    required this.onAssignAgent,
    required this.onBulkAssignAgent,
    required this.onEditLead,
    required this.onDeleteLead,
  });

  @override
  State<_LeadsTableCard> createState() => _LeadsTableCardState();
}

class _LeadsTableCardState extends State<_LeadsTableCard> {
  String selectedAssign = 'Assign';
  String selectedStatus = 'Status';
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

  @override
  void didUpdateWidget(_LeadsTableCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Removed automatic jump to page 1 on length change as it causes UX issues during edits/refreshes.
  }

  Widget _buildSkeletonLoading(bool isDesktop, bool isMobile) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 28 : 16,
        vertical: isDesktop ? 20 : 12,
      ),
      child: Shimmer.fromColors(
        baseColor: Colors.grey[200]!,
        highlightColor: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 40,
              width: 200,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: List.generate(
                isDesktop ? 4 : 2,
                (index) => Expanded(
                  child: Container(
                    height: 100,
                    margin: EdgeInsets.only(
                      right: index == (isDesktop ? 3 : 1) ? 0 : 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Container(
              height: 40,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              height: 500,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = Responsive.isDesktop(context);

    // 1. Local Filtering for Table Controls (Status & Agent only)
    List<Map<String, dynamic>> tableLeads = widget.leads;

    // Filter by Assigned Agent (only for admin)
    if (AuthService().isAdmin &&
        selectedAssign != 'Assign' &&
        selectedAssign != 'All') {
      tableLeads = tableLeads.where((l) {
        if (selectedAssign == 'Unassigned') return l['agentId'] == null;
        return l['agent'].toString().toLowerCase().contains(
          selectedAssign.toLowerCase(),
        );
      }).toList();
    }

    // Filter by Status
    if (selectedStatus != 'Status' && selectedStatus != 'All') {
      tableLeads = tableLeads.where((l) {
        final status = l['status'] ?? 'prospect';
        String dbStatus = status.toString().toLowerCase();
        String filterStatus = selectedStatus.toLowerCase();
        if (filterStatus == 'interested') filterStatus = 'intrested';
        if (filterStatus == 'connected but not interested')
          filterStatus = 'connected but not intrested';
        return dbStatus == filterStatus;
      }).toList();
    }

    final total = tableLeads.length;
    final totalPages = (total / _pageSize).ceil();
    final currentPage = _currentPage.clamp(1, totalPages > 0 ? totalPages : 1);
    final startIndex = (currentPage - 1) * _pageSize;
    final endIndex = (startIndex + _pageSize) > total
        ? total
        : (startIndex + _pageSize);
    final paginatedLeads = total == 0
        ? <Map<String, dynamic>>[]
        : tableLeads.sublist(startIndex, endIndex);

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
          LayoutBuilder(
            builder: (context, constraints) {
              final double minTableWidth = widget.isMobile ? 1200.0 : (AuthService().isAdmin ? 1200.0 : 1000.0);
              final double width = constraints.maxWidth > minTableWidth ? constraints.maxWidth : minTableWidth;
              return ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(scrollbars: true),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: width,
                    child: _LeadsTable(
                      leads: paginatedLeads,
                      isMobile: widget.isMobile,
                      salesAgents: widget.salesAgents,
                      onAssignAgent: widget.onAssignAgent,
                      onEditLead: widget.onEditLead,
                      onDeleteLead: widget.onDeleteLead,
                      selectedLeadIds: _selectedLeadIds,
                      isSubmitting:
                          context.read<LeadsBloc>().state.status ==
                          LeadsStatus.submitting,
                      onSelectionChanged: () {
                        setState(() {});
                      },
                    ),
                  ),
                ),
              );
            },
          ),
          _buildTableFooter(widget.isMobile, currentPage, total),
        ],
      ),
    );
  }

  Widget _buildCombinedControls() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (AuthService().isAdmin)
          _buildTableDropdown('Assign', selectedAssign, [
            'All',
            'Unassigned',
            ...widget.salesAgents.map(
              (agent) =>
                  '${agent['firstName'] ?? ''} ${agent['lastName'] ?? ''}'
                      .trim(),
            ),
          ], (val) => setState(() => selectedAssign = val!)),
        if (AuthService().isAdmin) const SizedBox(width: 12),
        _buildTableDropdown('Status', selectedStatus, [
          'All',
          'KYC Pending',
          'Call Not Picked',
          'Connected But Not Interested',
          'Quotation Sent',
          'Negotiation',
          'Follow-up',
          'Lost',
          'Interested',
          'Customer Busy',
          'Call Switch Off',
          'Prospect',
        ], (val) => setState(() => selectedStatus = val!)),
      ],
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
              items: [10, 50, 100, 150, 200]
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

  Widget _buildTableFooter(bool isMobile, int currentPage, int total) {
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
                _buildPaginationControls(currentPage, total),
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
                _buildPaginationControls(currentPage, total),
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
  final Function(Map<String, dynamic> lead) onEditLead;
  final Function(String userId, String name) onDeleteLead;
  final Set<String> selectedLeadIds;
  final VoidCallback onSelectionChanged;
  final bool isSubmitting;

  const _LeadsTable({
    required this.leads,
    required this.isMobile,
    required this.salesAgents,
    required this.onAssignAgent,
    required this.onEditLead,
    required this.onDeleteLead,
    required this.selectedLeadIds,
    required this.onSelectionChanged,
    this.isSubmitting = false,
  });

  @override
  State<_LeadsTable> createState() => _LeadsTableState();
}

class _LeadsTableState extends State<_LeadsTable> {
  // Removed hoveredRowIndex to prevent full table rebuilds on hover

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

  Widget _buildSkeletonLoading(bool isDesktop, bool isMobile) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 28 : 16,
        vertical: isDesktop ? 20 : 12,
      ),
      child: Shimmer.fromColors(
        baseColor: Colors.grey[200]!,
        highlightColor: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 40,
              width: 200,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: List.generate(
                isDesktop ? 4 : 2,
                (index) => Expanded(
                  child: Container(
                    height: 100,
                    margin: EdgeInsets.only(
                      right: index == (isDesktop ? 3 : 1) ? 0 : 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Container(
              height: 40,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              height: 500,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final columns = [
      const _LeadColumnConfig('Lead Name', 28),
      const _LeadColumnConfig('Phone Number', 14),
      const _LeadColumnConfig('Location', 14),
      const _LeadColumnConfig('Last Activity', 12),
      if (AuthService().isAdmin) const _LeadColumnConfig('Assigned Agent', 14),
      const _LeadColumnConfig('Status', 14),
      const _LeadColumnConfig('Actions', 12),
    ];

    Widget tableHeader = Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppTheme.lightBorderColor, width: 1.5),
        ),
        color: Color(0xFFF9FAFB),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.isSubmitting)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: LinearProgressIndicator(
                minHeight: 2,
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppTheme.primaryColor,
                ),
              ),
            ),
          Row(
            children: [
              if (AuthService().isAdmin)
                SizedBox(
                  width: 40,
                  child: Center(
                    child: _CustomCheckbox(
                      isSelected: isAllSelected,
                      onTap: _toggleAll,
                    ),
                  ),
                ),
              ...columns.map((col) {
                final rightPadding = col.title == 'Assigned Agent' ? 36.0 : 12.0;
                final Widget child = Padding(
                  padding: EdgeInsets.only(left: 12, right: rightPadding),
                  child: _HeaderText(col.title),
                );
                return Expanded(
                  flex: col.flex,
                  child: col.isCenter ? Center(child: child) : child,
                );
              }),
            ],
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        tableHeader,
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: widget.leads.length,
          itemExtent: 68, // Massive optimization: bypass height calculation
          addRepaintBoundaries: true,
          itemBuilder: (context, index) {
            final lead = widget.leads[index];
            final bool isAlternate = index % 2 == 1;
            final String leadId = lead['id'] ?? '';
            return _LeadRow(
              lead: lead,
              isAlternate: isAlternate,
              isMobile: widget.isMobile,
              isSelected: widget.selectedLeadIds.contains(leadId),
              isAllSelected: isAllSelected,
              onToggleSelection: () => _toggleSelection(leadId),
              onTap: () => Navigator.pushNamed(
                context,
                '/leads/profile',
                arguments: lead,
              ),
              salesAgents: widget.salesAgents,
              onAssignAgent: widget.onAssignAgent,
              onEdit: widget.onEditLead,
              onDelete: widget.onDeleteLead,
            );
          },
        ),
      ],
    );
  }
}

class _LeadRow extends StatefulWidget {
  final Map<String, dynamic> lead;
  final bool isAlternate;
  final bool isMobile;
  final bool isSelected;
  final bool isAllSelected;
  final VoidCallback onToggleSelection;
  final VoidCallback onTap;
  final List<Map<String, dynamic>> salesAgents;
  final Function(String userId, String? agentId) onAssignAgent;
  final Function(Map<String, dynamic> lead) onEdit;
  final Function(String userId, String name) onDelete;

  const _LeadRow({
    required this.lead,
    required this.isAlternate,
    required this.isMobile,
    required this.isSelected,
    required this.isAllSelected,
    required this.onToggleSelection,
    required this.onTap,
    required this.salesAgents,
    required this.onAssignAgent,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_LeadRow> createState() => _LeadRowState();
}

class _LeadRowState extends State<_LeadRow> {
  bool isHovered = false;

  static final TextStyle _nameStyle = GoogleFonts.outfit(
    fontSize: 13,
    color: AppTheme.textPrimary,
    fontWeight: FontWeight.w700,
  );
  static final TextStyle _subStyle = GoogleFonts.outfit(
    fontSize: 11,
    color: AppTheme.textSecondary,
    fontWeight: FontWeight.w500,
  );
  static final TextStyle _cellStyleText = GoogleFonts.outfit(
    fontSize: 13,
    fontWeight: FontWeight.w500,
  );
  static final TextStyle _statusTextStyle = GoogleFonts.outfit(
    fontSize: 10.5,
    fontWeight: FontWeight.bold,
  );

  @override
  Widget build(BuildContext context) {
    Color rowBgColor = widget.isAlternate ? const Color(0xFFFAFBFC) : Colors.white;
    if (widget.isSelected) rowBgColor = AppTheme.primaryColor.withValues(alpha: 0.04);
    if (isHovered) rowBgColor = AppTheme.primaryColor.withValues(alpha: 0.03);

    return RepaintBoundary(
      child: MouseRegion(
        onEnter: (_) => setState(() => isHovered = true),
        onExit: (_) => setState(() => isHovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () {
             Navigator.pushNamed(
                context,
                '/leads/profile',
                arguments: widget.lead,
              );
          },
          behavior: HitTestBehavior.opaque,
          child: Container(
            decoration: BoxDecoration(
              border: const Border(
                bottom: BorderSide(color: Color(0xFFF3F4F6), width: 0.5),
              ),
              color: rowBgColor,
            ),
            child: Row(
              children: [
                if (AuthService().isAdmin)
                  SizedBox(
                    width: 40,
                    child: Center(
                      child: (isHovered || widget.isSelected)
                          ? GestureDetector(
                              onTap: () {}, // Prevent row tap
                              child: _CustomCheckbox(
                                isSelected: widget.isSelected,
                                onTap: widget.onToggleSelection,
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                Expanded(
                  flex: 28,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.lead['name'],
                          style: _nameStyle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (widget.lead['shopName'] != null &&
                            widget.lead['shopName'].toString().isNotEmpty &&
                            widget.lead['shopName'].toString().toLowerCase() !=
                                'my store')
                          Text(
                            widget.lead['shopName'],
                            style: _subStyle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ),
                _cell(widget.lead['phone'], flex: 1.4, isSecondary: true),
                _cell(
                  (widget.lead['city'] != null &&
                          widget.lead['city'].toString().trim().isNotEmpty &&
                          widget.lead['state'] != null &&
                          widget.lead['state'].toString().trim().isNotEmpty)
                      ? '${widget.lead['city']}, ${widget.lead['state']}'
                      : ((widget.lead['city'] ?? '').toString().trim().isNotEmpty
                            ? widget.lead['city']
                            : (widget.lead['state'] ?? '')),
                  flex: 1.4,
                  isSecondary: true,
                ),
                _cell(widget.lead['activity'], flex: 1.2, isSecondary: true),
                if (AuthService().isAdmin)
                  Expanded(
                    flex: 14,
                    child: Padding(
                      padding: const EdgeInsets.only(
                        left: 12,
                        right: 36,
                        top: 8,
                        bottom: 8,
                      ),
                      child: GestureDetector(
                        onTap: () {}, // Prevent row tap from triggering when clicking interactive element
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: const Color(0xFFE5E7EB),
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value:
                                  widget.salesAgents.any(
                                    (agent) =>
                                        agent['_id'] == widget.lead['agentId'],
                                  )
                                  ? widget.lead['agentId']
                                  : null,
                              isExpanded: true,
                              isDense: true,
                              icon: const Icon(
                                Icons.arrow_drop_down,
                                size: 16,
                                color: AppTheme.textSecondary,
                              ),
                              hint: Text('-', style: _subStyle),
                              onChanged: (String? newAgentId) {
                                if (widget.lead['id'] != null) {
                                  widget.onAssignAgent(
                                    widget.lead['id'],
                                    newAgentId,
                                  );
                                }
                              },
                              items: [
                                DropdownMenuItem<String>(
                                  value: null,
                                  child: Text('-', style: _subStyle),
                                ),
                                ...widget.salesAgents.map((agent) {
                                  final agentName =
                                      '${agent['firstName'] ?? ''} ${agent['lastName'] ?? ''}'
                                          .trim();
                                  return DropdownMenuItem<String>(
                                    value: agent['_id'],
                                    child: Text(
                                      agentName.isNotEmpty
                                          ? agentName
                                          : (agent['phoneNumber'] ?? ''),
                                      style: _cellStyleText.copyWith(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
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
                  ),
                _statusCell(widget.lead['status'] ?? 'prospect', flex: 1.4),
                Expanded(
                  flex: 12,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(
                        left: 12,
                        top: 10,
                        bottom: 10,
                      ),
                      child: GestureDetector(
                        onTap: () {}, // Stop propagation for buttons
                        child: _ConnectedActionButtons(
                          onEdit: () => widget.onEdit(widget.lead),
                          onDelete: () => widget.onDelete(widget.lead['id'], widget.lead['name']),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatStatusName(String status) {
    switch (status.toLowerCase()) {
      case 'kyc pending':
        return 'KYC Pending';
      case 'call not picked':
        return 'Call Not Picked';
      case 'connected but not intrested':
        return 'Connected But Not Interested';
      case 'quotation sent':
        return 'Quotation Sent';
      case 'negotiation':
        return 'Negotiation';
      case 'follow-up':
        return 'Follow-up';
      case 'lost':
        return 'Lost';
      case 'intrested':
        return 'Interested';
      case 'customer busy':
        return 'Customer Busy';
      case 'call switch off':
        return 'Call Switch Off';
      case 'prospect':
        return 'Prospect';
      default:
        return status;
    }
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
          style: isBold 
              ? _nameStyle 
              : _cellStyleText.copyWith(color: isSecondary ? AppTheme.textSecondary : AppTheme.textBody),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _statusCell(String status, {double flex = 1.0}) {
    Color color = Colors.grey;
    switch (status.toLowerCase()) {
      case 'kyc pending': color = Colors.amber; break;
      case 'call not picked': color = Colors.orange; break;
      case 'connected but not intrested': color = Colors.blueGrey; break;
      case 'quotation sent': color = Colors.blue; break;
      case 'negotiation': color = Colors.indigo; break;
      case 'follow-up': color = Colors.deepPurple; break;
      case 'lost': color = Colors.red; break;
      case 'intrested': color = Colors.green; break;
      case 'customer busy': color = Colors.teal; break;
      case 'call switch off': color = Colors.redAccent; break;
      case 'prospect': color = Colors.cyan; break;
    }

    return Expanded(
      flex: (flex * 10).toInt(),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
            ),
            child: Text(
              _formatStatusName(status).toUpperCase(),
              style: _statusTextStyle.copyWith(color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }
}

class _ConnectedActionButtons extends StatefulWidget {
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ConnectedActionButtons({required this.onEdit, required this.onDelete});

  @override
  State<_ConnectedActionButtons> createState() =>
      _ConnectedActionButtonsState();
}

class _ConnectedActionButtonsState extends State<_ConnectedActionButtons> {
  bool isEditHovered = false;
  bool isDeleteHovered = false;

  Widget _buildSkeletonLoading(bool isDesktop, bool isMobile) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 28 : 16,
        vertical: isDesktop ? 20 : 12,
      ),
      child: Shimmer.fromColors(
        baseColor: Colors.grey[200]!,
        highlightColor: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 40,
              width: 200,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: List.generate(
                isDesktop ? 4 : 2,
                (index) => Expanded(
                  child: Container(
                    height: 100,
                    margin: EdgeInsets.only(
                      right: index == (isDesktop ? 3 : 1) ? 0 : 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Container(
              height: 40,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              height: 500,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 70,
          height: 32,
          child: MouseRegion(
            onEnter: (_) => setState(() => isEditHovered = true),
            onExit: (_) => setState(() => isEditHovered = false),
            child: GestureDetector(
              onTap: widget.onEdit,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  color: isEditHovered ? AppTheme.info : Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isEditHovered
                        ? AppTheme.info
                        : AppTheme.borderColor.withValues(alpha: 0.6),
                  ),
                ),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.edit_outlined,
                        size: 14,
                        color: isEditHovered ? Colors.white : AppTheme.info,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Edit',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isEditHovered
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
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 32,
          height: 32,
          child: MouseRegion(
            onEnter: (_) => setState(() => isDeleteHovered = true),
            onExit: (_) => setState(() => isDeleteHovered = false),
            child: GestureDetector(
              onTap: widget.onDelete,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  color: isDeleteHovered ? AppTheme.error : Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isDeleteHovered
                        ? AppTheme.error
                        : AppTheme.error.withValues(alpha: 0.3),
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.delete_outline_rounded,
                    size: 16,
                    color: isDeleteHovered ? Colors.white : AppTheme.error,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HeaderText extends StatelessWidget {
  final String text;

  const _HeaderText(this.text);

  Widget _buildSkeletonLoading(bool isDesktop, bool isMobile) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 28 : 16,
        vertical: isDesktop ? 20 : 12,
      ),
      child: Shimmer.fromColors(
        baseColor: Colors.grey[200]!,
        highlightColor: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 40,
              width: 200,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: List.generate(
                isDesktop ? 4 : 2,
                (index) => Expanded(
                  child: Container(
                    height: 100,
                    margin: EdgeInsets.only(
                      right: index == (isDesktop ? 3 : 1) ? 0 : 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Container(
              height: 40,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              height: 500,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ],
        ),
      ),
    );
  }

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

  Widget _buildSkeletonLoading(bool isDesktop, bool isMobile) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 28 : 16,
        vertical: isDesktop ? 20 : 12,
      ),
      child: Shimmer.fromColors(
        baseColor: Colors.grey[200]!,
        highlightColor: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 40,
              width: 200,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: List.generate(
                isDesktop ? 4 : 2,
                (index) => Expanded(
                  child: Container(
                    height: 100,
                    margin: EdgeInsets.only(
                      right: index == (isDesktop ? 3 : 1) ? 0 : 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Container(
              height: 40,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              height: 500,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unassignedCount = leads
        .where((l) => l['agentId'] == null)
        .length;
    final assignedCount = leads
        .where((l) => l['agentId'] != null)
        .length;
    final kycPendingCount = leads
        .where((l) {
          final status = l['kycStatus'].toString().toLowerCase();
          return status == 'pending' || status == 'submitted';
        })
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
              onTap: () {
                context.read<LeadsBloc>().add(
                  const UpdateLeadsFilterEvent(
                    selectedFilterChip: 'Unassigned',
                    currentPage: 1,
                    searchQuery: '',
                  ),
                );
              },
            ),
            StatCardWidget(
              width: width,
              title: 'Assigned Lead',
              value: '$assignedCount',
              icon: Icons.person_pin_outlined,
              color: AppTheme.info,
              isCompact: true,
              onTap: () {
                context.read<LeadsBloc>().add(
                  const UpdateLeadsFilterEvent(
                    selectedFilterChip: 'Assigned',
                    currentPage: 1,
                    searchQuery: '',
                  ),
                );
              },
            ),
            StatCardWidget(
              width: width,
              title: 'KYC Pending',
              value: '$kycPendingCount',
              icon: Icons.pending_actions_outlined,
              color: AppTheme.error,
              isCompact: true,
              onTap: () {
                context.read<LeadsBloc>().add(
                  const UpdateLeadsFilterEvent(
                    selectedFilterChip: 'KYC Pending',
                    currentPage: 1,
                    searchQuery: '',
                  ),
                );
              },
            ),
            StatCardWidget(
              width: width,
              title: 'Verified Dealer',
              value: '$verifiedDealersCount',
              icon: Icons.verified_user_outlined,
              color: AppTheme.success,
              isCompact: true,
              onTap: () {
                context.read<LeadsBloc>().add(
                  const UpdateLeadsFilterEvent(
                    selectedFilterChip: 'KYC Confirm',
                    currentPage: 1,
                    searchQuery: '',
                  ),
                );
              },
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

  Widget _buildSkeletonLoading(bool isDesktop, bool isMobile) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 28 : 16,
        vertical: isDesktop ? 20 : 12,
      ),
      child: Shimmer.fromColors(
        baseColor: Colors.grey[200]!,
        highlightColor: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 40,
              width: 200,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: List.generate(
                isDesktop ? 4 : 2,
                (index) => Expanded(
                  child: Container(
                    height: 100,
                    margin: EdgeInsets.only(
                      right: index == (isDesktop ? 3 : 1) ? 0 : 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Container(
              height: 40,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              height: 500,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ],
        ),
      ),
    );
  }

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

  Widget _buildSkeletonLoading(bool isDesktop, bool isMobile) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 28 : 16,
        vertical: isDesktop ? 20 : 12,
      ),
      child: Shimmer.fromColors(
        baseColor: Colors.grey[200]!,
        highlightColor: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 40,
              width: 200,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: List.generate(
                isDesktop ? 4 : 2,
                (index) => Expanded(
                  child: Container(
                    height: 100,
                    margin: EdgeInsets.only(
                      right: index == (isDesktop ? 3 : 1) ? 0 : 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Container(
              height: 40,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              height: 500,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ],
        ),
      ),
    );
  }

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

  Widget _buildSkeletonLoading(bool isDesktop, bool isMobile) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 28 : 16,
        vertical: isDesktop ? 20 : 12,
      ),
      child: Shimmer.fromColors(
        baseColor: Colors.grey[200]!,
        highlightColor: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 40,
              width: 200,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: List.generate(
                isDesktop ? 4 : 2,
                (index) => Expanded(
                  child: Container(
                    height: 100,
                    margin: EdgeInsets.only(
                      right: index == (isDesktop ? 3 : 1) ? 0 : 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Container(
              height: 40,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              height: 500,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ],
        ),
      ),
    );
  }

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

class _LeadColumnConfig {
  final String title;
  final int flex;
  final bool isCenter;

  const _LeadColumnConfig(this.title, this.flex, {this.isCenter = false});
}

class _SourceBadge extends StatelessWidget {
  final String source;

  const _SourceBadge({required this.source});

  Widget _buildSkeletonLoading(bool isDesktop, bool isMobile) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 28 : 16,
        vertical: isDesktop ? 20 : 12,
      ),
      child: Shimmer.fromColors(
        baseColor: Colors.grey[200]!,
        highlightColor: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 40,
              width: 200,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: List.generate(
                isDesktop ? 4 : 2,
                (index) => Expanded(
                  child: Container(
                    height: 100,
                    margin: EdgeInsets.only(
                      right: index == (isDesktop ? 3 : 1) ? 0 : 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Container(
              height: 40,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              height: 500,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Color badgeColor;
    Color textColor;
    IconData icon;

    final String sourceLower = source.toLowerCase();

    if (sourceLower.contains('whatsapp') || sourceLower.contains('ctwa')) {
      badgeColor = const Color(0xFFE8F8EF);
      textColor = const Color(0xFF107C41);
      icon = Icons.chat_bubble_outline_rounded;
    } else if (sourceLower.contains('meta') ||
        sourceLower.contains('facebook') ||
        sourceLower.contains('instagram')) {
      badgeColor = const Color(0xFFE8F3FF);
      textColor = const Color(0xFF1877F2);
      icon = Icons.campaign_outlined;
    } else if (sourceLower.contains('google')) {
      badgeColor = const Color(0xFFFEF3F2);
      textColor = const Color(0xFFD92D20);
      icon = Icons.search_rounded;
    } else if (sourceLower.contains('firebase') ||
        sourceLower.contains('notification')) {
      badgeColor = const Color(0xFFFFF7ED);
      textColor = const Color(0xFFEA580C);
      icon = Icons.notifications_active_outlined;
    } else if (sourceLower.contains('website') || sourceLower.contains('web')) {
      badgeColor = const Color(0xFFF0FDFA);
      textColor = const Color(0xFF0D9488);
      icon = Icons.language_rounded;
    } else {
      badgeColor = const Color(0xFFF3F4F6);
      textColor = const Color(0xFF4B5563);
      icon = Icons.phone_android_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: textColor.withValues(alpha: 0.15), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(
            source,
            style: GoogleFonts.outfit(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
