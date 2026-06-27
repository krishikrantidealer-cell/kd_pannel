import 'dart:ui' as ui;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_switch/flutter_switch.dart';
import 'package:shimmer/shimmer.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kd_pannel/app_theme.dart';
import 'package:kd_pannel/core/responsive/responsive.dart';
import 'package:kd_pannel/features/shared/widgets/stat_card_widget.dart';
import 'package:kd_pannel/util/dealers.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';
import '../bloc/dealers_bloc.dart';
import '../bloc/dealers_event.dart';
import '../bloc/dealers_state.dart';
import 'package:kd_pannel/core/auth/auth_service.dart';
import 'package:kd_pannel/util/export_helper.dart';
import 'package:kd_pannel/core/network/websocket_service.dart';
import 'package:kd_pannel/core/utils/navigation_service.dart';
import 'create_order_page.dart';

class DealerManagementPage extends StatefulWidget {
  final bool isStandalone;
  const DealerManagementPage({super.key, this.isStandalone = false});

  @override
  State<DealerManagementPage> createState() => _DealerManagementPageState();
}

class _DealerManagementPageState extends State<DealerManagementPage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _tableHorizontalController = ScrollController();
  bool _isExporting = false;
  DealersBloc? _dealersBloc;
  StreamSubscription? _wsSubscription;
  final Set<String> _selectedDealerIds = {};

  @override
  void initState() {
    super.initState();
    _dealersBloc = DealersBloc()..add(const FetchDealersDataEvent());

    // Connect to WebSockets
    WebSocketService().connect();

    // Listen to WebSocket signals to refresh Dealers
    _wsSubscription = WebSocketService().dealersUpdates.listen((_) {
      if (mounted && _dealersBloc != null) {
        _dealersBloc!.add(const FetchDealersDataEvent(forceRefresh: true));
      }
    });
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    _dealersBloc?.close(); // Manually dispose since we created it
    _searchController.dispose();
    _tableHorizontalController.dispose();
    super.dispose();
  }

  void _exportDealersToCSV() async {
    setState(() => _isExporting = true);

    // Get current state and retrieve filtered dealers
    final state = context.read<DealersBloc>().state;
    final dealers = _getFilteredDealers(state);

    final headers = [
      'Name',
      'Phone',
      'Email',
      'City',
      'State',
      'Assigned Agent',
      'GST Status',
      'GST Number',
      'Total Orders',
      'Purchase Value',
      'User Type',
      'KYC Status',
    ];

    final buffer = StringBuffer();
    buffer.writeln(
      headers.map((h) => '"${h.replaceAll('"', '""')}"').join(','),
    );
    // in the leads and dealers screen  on search when the user enters the number in the table you remove all the other leads and the delaers keep them there
    for (final dealer in dealers) {
      final row = [
        dealer.name,
        dealer.phone,
        dealer.email ?? '',
        dealer.city,
        dealer.state,
        dealer.agent,
        dealer.gstStatus,
        dealer.gstNumber ?? '',
        dealer.totalOrders,
        dealer.purchaseValue,
        dealer.userType ?? '',
        dealer.kycStatus ?? '',
      ];
      buffer.writeln(
        row.map((val) => '"${val.toString().replaceAll('"', '""')}"').join(','),
      );
    }

    // Simulate delay for UI responsiveness
    await Future.delayed(const Duration(milliseconds: 1000));

    if (mounted) {
      // Trigger download using the platform-specific export helper
      downloadCsv(buffer.toString(), 'dealers_export.csv');

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
                'Dealers data exported successfully to CSV!',
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

  final List<String> timeframeOptions = [
    'Today',
    'Yesterday',
    'This Week',
    'Last Week',
    'This Month',
    'Last Month',
    'Custom Range',
  ];

  static const List<String> _indianStatesAndUTs = [
    'Andhra Pradesh',
    'Arunachal Pradesh',
    'Assam',
    'Bihar',
    'Chhattisgarh',
    'Goa',
    'Gujarat',
    'Haryana',
    'Himachal Pradesh',
    'Jharkhand',
    'Karnataka',
    'Kerala',
    'Madhya Pradesh',
    'Maharashtra',
    'Manipur',
    'Meghalaya',
    'Mizoram',
    'Nagaland',
    'Odisha',
    'Punjab',
    'Rajasthan',
    'Sikkim',
    'Tamil Nadu',
    'Telangana',
    'Tripura',
    'Uttar Pradesh',
    'Uttarakhand',
    'West Bengal',
    // Union Territories
    'Andaman and Nicobar Islands',
    'Chandigarh',
    'Dadra and Nagar Haveli and Daman and Diu',
    'Delhi',
    'Jammu and Kashmir',
    'Ladakh',
    'Lakshadweep',
    'Puducherry',
  ];

  List<String> get stateOptions {
    return ['All States', ..._indianStatesAndUTs];
  }

  String _formatCurrency(double amount) {
    final int val = amount.round();
    if (val == 0) return '₹0';
    final str = val.toString();
    if (str.length <= 3) return '₹$str';

    var lastThree = str.substring(str.length - 3);
    var otherParts = str.substring(0, str.length - 3);
    if (otherParts.isNotEmpty) {
      otherParts = otherParts.replaceAllMapped(
        RegExp(r'(\d)(?=(\d\d)+(?!\d))'),
        (Match m) => '${m[1]},',
      );
    }
    return '₹$otherParts,$lastThree';
  }

  List<Dealer> _getallCalculatedDealers(DealersState state) {
    final isSales = AuthService().isSales;
    final agentId = AuthService().currentUserId;

    final verifiedUsers = state.allRawUsers.where((u) {
      final role = u['role'] ?? 'user';
      final kycStatus = u['kycStatus'] ?? 'pending';
      final isDealer = role == 'user' && kycStatus == 'verified';
      if (!isDealer) return false;

      if (isSales) {
        final assignedAgentId = u['assignedAgent']?['_id'];
        return assignedAgentId == agentId;
      }
      return true;
    }).toList();

    return verifiedUsers.map((u) {
      final userId = u['_id'];

      final dealerOrders = state.allRawOrders
          .where(
            (o) =>
                o['user']?['_id'] == userId && o['orderStatus'] != 'Cancelled',
          )
          .toList();
      final totalOrdersCount = dealerOrders.length;

      double purchaseSum = 0.0;
      for (final order in dealerOrders) {
        final amount = order['totalAmount'];
        if (amount != null) {
          if (amount is num) {
            purchaseSum += amount.toDouble();
          } else {
            purchaseSum += double.tryParse(amount.toString()) ?? 0.0;
          }
        }
      }

      final agentName = u['assignedAgent'] != null
          ? '${u['assignedAgent']['firstName'] ?? ''} ${u['assignedAgent']['lastName'] ?? ''}'
                .trim()
          : '-';

      final String personName =
          (u['firstName'] != null || u['lastName'] != null)
          ? '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'.trim()
          : '';

      final isHighVal = purchaseSum >= 500000;
      final isInactiveDealer = totalOrdersCount == 0;

      return Dealer(
        name: personName.isNotEmpty
            ? personName
            : (u['phoneNumber'] ?? 'Unnamed Dealer'),
        phone: u['phoneNumber'] ?? '',
        city: u['address']?['cityTehsil'] ?? '',
        state: u['address']?['state'] ?? '',
        agent: agentName.isNotEmpty ? agentName : '-',
        gstStatus: 'Verified',
        totalOrders: totalOrdersCount,
        purchaseValue: _formatCurrency(purchaseSum),
        isHighValue: isHighVal,
        isInactive: isInactiveDealer,
        source: u['source'] ?? 'App',
        deepLinkUrl: u['deepLinkUrl'],
        id: u['_id'],
        agentId: u['assignedAgent']?['_id'],
        licenceImage: u['licenceImage'],
        shopImage: u['shopImage'],
        gstNumber: u['gstNumber'],
        email: u['email'],
        userType: u['userType'],
        kycStatus: u['kycStatus'],
        shopName: u['shopName'],
        address: u['address'] != null
            ? Map<String, dynamic>.from(u['address'])
            : null,
        status: u['status'] ?? u['leadStatus'] ?? 'prospect',
        notes: u['notes'] ?? u['leadNotes'] ?? '',
        createdAt: u['createdAt'],
        updatedAt: u['updatedAt'],
        notesHistory: u['notesHistory'] != null ? List<Map<String, dynamic>>.from(u['notesHistory']) : [],
      );
    }).toList();
  }

  List<String> _getAgentOptions(DealersState state) {
    final list = ['All Sales Agents'];
    for (final agent in state.salesAgents) {
      final name = '${agent['firstName'] ?? ''} ${agent['lastName'] ?? ''}'
          .trim();
      if (name.isNotEmpty && !list.contains(name)) {
        list.add(name);
      }
    }
    return list;
  }

  List<Dealer> _getFilteredDealers(DealersState state) {
    return _getallCalculatedDealers(state).where((dealer) {
      // Date Filtering
      DateTime? startDate;
      DateTime? endDate;

      if (state.selectedTimeframe == 'Custom Range' &&
          state.customStartDate != null) {
        startDate = state.customStartDate;
        endDate = state.customEndDate ?? state.customStartDate;
        endDate =
            DateTime(endDate!.year, endDate.month, endDate.day, 23, 59, 59);
      } else if (state.selectedTimeframe != 'Custom Range' &&
          state.selectedTimeframe.isNotEmpty) {
        final now = DateTime.now();
        endDate = now;
        switch (state.selectedTimeframe) {
          case 'Today':
            startDate = DateTime(now.year, now.month, now.day);
            break;
          case 'Yesterday':
            final yesterday = now.subtract(const Duration(days: 1));
            startDate = DateTime(
              yesterday.year,
              yesterday.month,
              yesterday.day,
            );
            endDate = DateTime(
              yesterday.year,
              yesterday.month,
              yesterday.day,
              23,
              59,
              59,
            );
            break;
          case 'This Week':
            startDate = now.subtract(Duration(days: now.weekday - 1));
            startDate = DateTime(startDate.year, startDate.month, startDate.day);
            break;
          case 'Last Week':
            startDate = now.subtract(Duration(days: now.weekday + 6));
            startDate = DateTime(startDate.year, startDate.month, startDate.day);
            endDate = startDate.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
            break;
          case 'This Month':
            startDate = DateTime(now.year, now.month, 1);
            break;
          case 'Last Month':
            startDate = DateTime(now.year, now.month - 1, 1);
            endDate = DateTime(now.year, now.month, 0, 23, 59, 59);
            break;
        }
      }

      if (startDate != null && endDate != null) {
        final dateStr = dealer.createdAt ?? dealer.updatedAt;
        if (dateStr == null) return false;
        try {
          final date = DateTime.parse(dateStr).toLocal();
          if (date.isBefore(startDate) || date.isAfter(endDate)) return false;
        } catch (e) {
          return false;
        }
      }

      final query = state.searchQuery.toLowerCase();
      bool matchesSearch =
          dealer.name.toLowerCase().contains(query) ||
          dealer.phone.toLowerCase().contains(query) ||
          dealer.city.toLowerCase().contains(query) ||
          dealer.agent.toLowerCase().contains(query);
      bool matchesAgent =
          state.selectedAgent == 'All Sales Agents' ||
          dealer.agent == state.selectedAgent;
      bool matchesState =
          state.selectedState == 'All States' ||
          dealer.state.trim().toLowerCase() ==
              state.selectedState.trim().toLowerCase();
      bool matchesHighValue = !state.showHighValueOnly || dealer.isHighValue;
      bool matchesInactive = !state.showInactiveOnly || dealer.isInactive;
      return matchesSearch &&
          matchesAgent &&
          matchesState &&
          matchesHighValue &&
          matchesInactive;
    }).toList();
  }

  void _showDatePicker(BuildContext context) {
    final dealersBloc = context.read<DealersBloc>();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
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
            initialSelectedRange:
                dealersBloc.state.customStartDate != null &&
                    dealersBloc.state.customEndDate != null
                ? PickerDateRange(
                    dealersBloc.state.customStartDate,
                    dealersBloc.state.customEndDate,
                  )
                : null,
            onSubmit: (Object? val) {
              if (val is PickerDateRange &&
                  val.startDate != null &&
                  val.endDate != null) {
                dealersBloc.add(
                  UpdateDealersFilterEvent(
                    selectedTimeframe: 'Custom Range',
                    customStartDate: val.startDate,
                    customEndDate: val.endDate,
                  ),
                );
                Navigator.pop(dialogContext);
              }
            },
            onCancel: () => Navigator.pop(dialogContext),
          ),
        ),
      ),
    );
  }

  void _bulkAssignAgent(List<String> userIds, String? agentId) {
    context.read<DealersBloc>().add(
      BulkAssignAgentToDealersEvent(userIds: userIds, agentId: agentId),
    );
    setState(() {
      _selectedDealerIds.clear();
    });
  }

  Future<void> _deleteDealer(String userId, String name) async {
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
          'Are you sure you want to delete dealer "$name"? This action cannot be undone and all associated profile data will be removed.',
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
      context.read<DealersBloc>().add(DeleteDealerEvent(userId));
    }
  }

  Future<void> _editDealer(Dealer dealer) async {
    final nameController = TextEditingController(text: dealer.name);
    final shopNameController = TextEditingController(
      text: dealer.shopName ?? '',
    );
    final gstController = TextEditingController(text: dealer.gstNumber ?? '');
    final phoneController = TextEditingController(text: dealer.phone);
    final villageAreaController = TextEditingController(
      text: dealer.address?['villageArea'] ?? '',
    );
    final addressLine2Controller = TextEditingController(
      text: dealer.address?['addressLine2'] ?? '',
    );
    final cityController = TextEditingController(text: dealer.city);
    final stateController = TextEditingController(text: dealer.state);
    final pincodeController = TextEditingController(
      text: dealer.address?['pincode'] ?? '',
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

      _dealersBloc?.add(
        UpdateDealerDetailsEvent(
          userId: dealer.id!,
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
              width: 250,
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
    if (_dealersBloc == null) return const SizedBox.shrink();

    return BlocProvider.value(
      value: _dealersBloc!,
      child: BlocConsumer<DealersBloc, DealersState>(
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
            _dealersBloc?.add(const ClearDealersMessageEvent());
          }
          if (state.actionSuccessMessage != null) {
            NavigationService.messengerKey.currentState?.showSnackBar(
              SnackBar(
                content: Text(state.actionSuccessMessage!),
                backgroundColor: AppTheme.success,
              ),
            );
            _dealersBloc?.add(const ClearDealersMessageEvent());
          }
        },
        builder: (context, state) {
          final isDesktop = Responsive.isDesktop(context);
          final isMobile = Responsive.isMobile(context);

          final bool isLoaderShowing = state.status == DealersStatus.loading;

          final Widget body = Builder(
            builder: (context) => isLoaderShowing && state.allRawUsers.isEmpty
                ? _buildSkeletonLoading(isDesktop, isMobile)
                : state.status == DealersStatus.failure &&
                      state.allRawUsers.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40.0),
                      child: Text(
                        'Error: ${state.errorMessage ?? "Failed to load"}',
                        style: const TextStyle(color: Colors.red),
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
                            _buildHeader(context, state, isMobile),
                            const SizedBox(height: 16),
                            _buildStatsCards(state, context),
                            const SizedBox(height: 24),
                            _buildFiltersRow(
                              context,
                              state,
                              isMobile,
                              isDesktop,
                            ),
                            const SizedBox(height: 16),
                            _buildDealerTable(context, state, isMobile),
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
                    ),
                  ),
          );

          if (widget.isStandalone) {
            return Scaffold(
              backgroundColor: AppTheme.backgroundColor,
              appBar: AppBar(
                title: Text(
                  AuthService().isSales
                      ? 'My Assigned Dealers'
                      : 'Dealer Management',
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

  Widget _buildHeader(BuildContext context, DealersState state, bool isMobile) {
    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!widget.isStandalone) ...[
            Text(
              'Dealers',
              style: AppTheme.headingXL.copyWith(
                letterSpacing: -0.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(child: _buildTimeframeFilter(context, state, isMobile)),
              const SizedBox(width: 8),
              Container(
                height: 38,
                width: 38,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  onPressed: _isExporting ? null : _exportDealersToCSV,
                  icon: _isExporting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.primaryColor,
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
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (!widget.isStandalone)
          Text(
            AuthService().isSales ? 'My Assigned Dealers' : 'Dealer Management',
            style: AppTheme.headingXL.copyWith(
              letterSpacing: -0.5,
              fontWeight: FontWeight.w800,
            ),
          )
        else
          const SizedBox.shrink(),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            OutlinedButton.icon(
              onPressed: _isExporting ? null : _exportDealersToCSV,
              icon: _isExporting
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.primaryColor,
                      ),
                    )
                  : const Icon(Icons.download, size: 16),
              label: Text(
                _isExporting ? 'Exporting...' : 'Export CSV',
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
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            _buildTimeframeFilter(context, state, isMobile),
          ],
        ),
      ],
    );
  }

  Widget _buildTimeframeFilter(
    BuildContext context,
    DealersState state,
    bool isMobile,
  ) {
    return GestureDetector(
      onTap: () {}, // Swallows taps to prevent event bubbling to parent layout
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: isMobile ? 38 : 42,
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
          border: Border.all(color: AppTheme.borderColor),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Row(
          mainAxisSize: isMobile ? MainAxisSize.max : MainAxisSize.min,
          children: [
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => _showDatePicker(context),
                child: Icon(
                  Icons.calendar_month_outlined,
                  size: isMobile ? 16 : 18,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
            VerticalDivider(
              indent: isMobile ? 8 : 10,
              endIndent: isMobile ? 8 : 10,
              width: isMobile ? 16 : 24,
              color: AppTheme.borderColor,
            ),
            if (isMobile)
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: timeframeOptions.contains(state.selectedTimeframe)
                        ? state.selectedTimeframe
                        : null,
                    isExpanded: true,
                    hint: Text(
                      'Timeframe',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    icon: const Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: Icon(
                        Icons.keyboard_arrow_down,
                        size: 16,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        if (newValue != 'Custom Range') {
                          context.read<DealersBloc>().add(
                            UpdateDealersFilterEvent(
                              selectedTimeframe: newValue,
                              customStartDate: null,
                              customEndDate: null,
                              currentPage: 1,
                            ),
                          );
                        } else {
                          _showDatePicker(context);
                        }
                      }
                    },
                    items: timeframeOptions
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
                  value: timeframeOptions.contains(state.selectedTimeframe)
                      ? state.selectedTimeframe
                      : null,
                  isExpanded: false,
                  hint: Text(
                    'Timeframe',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  icon: const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      size: 18,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      if (newValue != 'Custom Range') {
                        context.read<DealersBloc>().add(
                          UpdateDealersFilterEvent(
                            selectedTimeframe: newValue,
                            customStartDate: null,
                            customEndDate: null,
                            currentPage: 1,
                          ),
                        );
                      } else {
                        _showDatePicker(context);
                      }
                    }
                  },
                  items: timeframeOptions
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
      ),
    );
  }

  Widget _buildStatsCards(DealersState state, BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);
    final calculated = _getallCalculatedDealers(state);
    final totalDealers = calculated.length;
    final activeDealers = calculated.where((d) => !d.isInactive).length;
    final highValueDealers = calculated.where((d) => d.isHighValue).length;
    final inactiveDealers = calculated.where((d) => d.isInactive).length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double spacing = AppTheme.spacingSmall;
        final int columns = isDesktop ? 4 : 2;

        final double width =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            StatCardWidget(
              width: width,
              title: 'Total Dealers',
              value: '$totalDealers',
              icon: Icons.storefront_outlined,
              color: AppTheme.primaryColor,
              isCompact: true,
            ),
            StatCardWidget(
              width: width,
              title: 'Active Dealers',
              value: '$activeDealers',
              icon: Icons.check_circle_outline_rounded,
              color: AppTheme.success,
              isCompact: true,
            ),
            StatCardWidget(
              width: width,
              title: 'High Value Dealers',
              value: '$highValueDealers',
              icon: Icons.monetization_on_outlined,
              color: AppTheme.warning,
              isCompact: true,
            ),
            StatCardWidget(
              width: width,
              title: 'Inactive Dealers',
              value: '$inactiveDealers',
              icon: Icons.unpublished_outlined,
              color: AppTheme.error,
              isCompact: true,
            ),
          ],
        );
      },
    );
  }

  Widget _buildFiltersRow(
    BuildContext context,
    DealersState state,
    bool isMobile,
    bool isDesktop,
  ) {
    final agents = _getAgentOptions(state);
    if (!isMobile) {
      return Row(
        children: [
          _buildSearchField(300),
          if (AuthService().isAdmin) ...[
            const SizedBox(width: 12),
            _buildFilterDropdown(
              'All Sales Agents',
              180,
              agents,
              state.selectedAgent,
              (val) {
                context.read<DealersBloc>().add(
                  UpdateDealersFilterEvent(selectedAgent: val!, currentPage: 1),
                );
              },
            ),
          ],
          const SizedBox(width: 12),
          _buildFilterDropdown(
            'All States',
            150,
            stateOptions,
            state.selectedState,
            (val) {
              context.read<DealersBloc>().add(
                UpdateDealersFilterEvent(selectedState: val!, currentPage: 1),
              );
            },
          ),
          const Spacer(),
          _buildToggleFilter('High Value', state.showHighValueOnly, (val) {
            context.read<DealersBloc>().add(
              UpdateDealersFilterEvent(showHighValueOnly: val, currentPage: 1),
            );
          }),
          const SizedBox(width: 12),
          _buildToggleFilter('Inactive', state.showInactiveOnly, (val) {
            context.read<DealersBloc>().add(
              UpdateDealersFilterEvent(showInactiveOnly: val, currentPage: 1),
            );
          }),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSearchField(double.infinity),
          const SizedBox(height: 12),
          Row(
            children: [
              if (AuthService().isAdmin) ...[
                Expanded(
                  child: _buildFilterDropdown(
                    'Sales Agents',
                    null,
                    agents,
                    state.selectedAgent,
                    (val) {
                      context.read<DealersBloc>().add(
                        UpdateDealersFilterEvent(
                          selectedAgent: val!,
                          currentPage: 1,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: _buildFilterDropdown(
                  'States',
                  null,
                  stateOptions,
                  state.selectedState,
                  (val) {
                    context.read<DealersBloc>().add(
                      UpdateDealersFilterEvent(
                        selectedState: val!,
                        currentPage: 1,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildToggleFilter(
                  'High Value',
                  state.showHighValueOnly,
                  (val) {
                    context.read<DealersBloc>().add(
                      UpdateDealersFilterEvent(
                        showHighValueOnly: val,
                        currentPage: 1,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildToggleFilter('Inactive', state.showInactiveOnly, (
                  val,
                ) {
                  context.read<DealersBloc>().add(
                    UpdateDealersFilterEvent(
                      showInactiveOnly: val,
                      currentPage: 1,
                    ),
                  );
                }),
              ),
            ],
          ),
        ],
      );
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
                _dealersBloc?.add(
                  UpdateDealersFilterEvent(searchQuery: val, currentPage: 1),
                );
              },
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: 'Search dealers...',
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

  Widget _buildFilterDropdown(
    String hint,
    double? width,
    List<String> options,
    String currentValue,
    ValueChanged<String?> onChanged,
  ) {
    return Container(
      height: 38,
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: options.contains(currentValue) ? currentValue : null,
          isExpanded: true,
          padding: EdgeInsets.zero,
          hint: Text(
            hint,
            style: GoogleFonts.outfit(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          icon: const Icon(
            Icons.keyboard_arrow_down,
            size: 16,
            color: AppTheme.textSecondary,
          ),
          onChanged: onChanged,
          items: options
              .map<DropdownMenuItem<String>>(
                (String value) => DropdownMenuItem<String>(
                  value: value,
                  child: Text(
                    value,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
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
    );
  }

  Widget _buildToggleFilter(
    String label,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: GoogleFonts.outfit(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          FlutterSwitch(
            width: 36.0,
            height: 18.0,
            toggleSize: 12.0,
            value: value,
            borderRadius: 20.0,
            padding: 3.0,
            activeColor: AppTheme.primaryColor,
            inactiveColor: AppTheme.borderColor,
            onToggle: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildDealerTable(
    BuildContext context,
    DealersState state,
    bool isMobile,
  ) {
    final filtered = _getFilteredDealers(state);
    final int total = filtered.length;
    final int totalPages = (total / state.pageSize).ceil();
    final safePage = state.currentPage.clamp(
      1,
      totalPages > 0 ? totalPages : 1,
    );

    final int startIndex = (safePage - 1) * state.pageSize;
    final int endIndex = (startIndex + state.pageSize) > total
        ? total
        : (startIndex + state.pageSize);
    final dealersToShow = total == 0
        ? <Dealer>[]
        : filtered.sublist(startIndex, endIndex);

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
          _DealerTable(
            dealers: dealersToShow,
            isMobile: isMobile,
            salesAgents: state.salesAgents,
            onAssignAgent: (userId, agentId) {
              _dealersBloc?.add(
                AssignAgentToDealerEvent(userId: userId, agentId: agentId),
              );
            },
            onEditDealer: _editDealer,
            onDeleteDealer: _deleteDealer,
            selectedDealerIds: _selectedDealerIds,
            isSubmitting: state.status == DealersStatus.submitting,
            onSelectionChanged: () => setState(() {}),
          ),
          _buildTableFooter(context, state, isMobile),
        ],
      ),
    );
  }

  Widget _buildBulkActionDropdown(BuildContext context, DealersState state) {
    if (!AuthService().isAdmin) return const SizedBox.shrink();

    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          hint: Text(
            'Bulk Assign Agent',
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryColor,
            ),
          ),
          icon: const Icon(
            Icons.arrow_drop_down,
            size: 18,
            color: AppTheme.primaryColor,
          ),
          onChanged: (String? agentId) {
            if (agentId != null) {
              _bulkAssignAgent(_selectedDealerIds.toList(), agentId);
            }
          },
          items: state.salesAgents.map((agent) {
            final name =
                '${agent['firstName'] ?? ''} ${agent['lastName'] ?? ''}'.trim();
            return DropdownMenuItem<String>(
              value: agent['_id'],
              child: Text(
                name.isNotEmpty ? name : (agent['phoneNumber'] ?? ''),
                style: GoogleFonts.outfit(fontSize: 12),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildTableHeader(List<Dealer> visibleDealers) {
    return const SizedBox.shrink(); // Handled in _DealerTable now
  }

  Widget _buildDealerRow(
    BuildContext context,
    DealersState state,
    Dealer dealer,
    bool isAlternate,
  ) {
    return const SizedBox.shrink(); // Handled in _DealerTable now
  }

  Widget _buildPageSizeSelector(BuildContext context, DealersState state) {
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
              value: state.pageSize,
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
                  context.read<DealersBloc>().add(
                    UpdateDealersFilterEvent(
                      pageSize: newValue,
                      currentPage: 1,
                    ),
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

  Widget _buildTableFooter(
    BuildContext context,
    DealersState state,
    bool isMobile,
  ) {
    final footerPadding = isMobile
        ? const EdgeInsets.symmetric(horizontal: 16, vertical: 10)
        : const EdgeInsets.symmetric(horizontal: 12, vertical: 8);

    final filtered = _getFilteredDealers(state);
    final totalCount = filtered.length;
    final int totalPages = (totalCount / state.pageSize).ceil();
    final safePage = state.currentPage.clamp(
      1,
      totalPages > 0 ? totalPages : 1,
    );

    final startCount = totalCount == 0
        ? 0
        : (safePage - 1) * state.pageSize + 1;
    final endCount = (safePage * state.pageSize) > totalCount
        ? totalCount
        : (safePage * state.pageSize);

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
                      'Showing $startCount to $endCount of $totalCount entries',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    _buildPageSizeSelector(context, state),
                  ],
                ),
                const SizedBox(height: 12),
                _buildPaginationRow(context, state, totalCount),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Showing $startCount to $endCount of $totalCount entries',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 20),
                    _buildPageSizeSelector(context, state),
                  ],
                ),
                _buildPaginationRow(context, state, totalCount),
              ],
            ),
    );
  }

  Widget _buildPaginationRow(
    BuildContext context,
    DealersState state,
    int totalCount,
  ) {
    final int totalPages = (totalCount / state.pageSize).ceil();
    final int displayPages = totalPages > 0 ? totalPages : 1;
    final safePage = state.currentPage.clamp(1, displayPages);

    List<Widget> pageButtons = [];

    if (displayPages <= 5) {
      for (int i = 1; i <= displayPages; i++) {
        pageButtons.add(
          _buildPaginationPage(i, safePage == i, () {
            context.read<DealersBloc>().add(
              UpdateDealersFilterEvent(currentPage: i),
            );
          }),
        );
      }
    } else {
      pageButtons.add(
        _buildPaginationPage(1, safePage == 1, () {
          context.read<DealersBloc>().add(
            const UpdateDealersFilterEvent(currentPage: 1),
          );
        }),
      );

      if (safePage > 3) {
        pageButtons.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '...',
              style: GoogleFonts.outfit(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      }

      final start = (safePage - 1).clamp(2, displayPages - 1);
      final end = (safePage + 1).clamp(2, displayPages - 1);

      for (int i = start; i <= end; i++) {
        if (i > 1 && i < displayPages) {
          pageButtons.add(
            _buildPaginationPage(i, safePage == i, () {
              context.read<DealersBloc>().add(
                UpdateDealersFilterEvent(currentPage: i),
              );
            }),
          );
        }
      }

      if (safePage < displayPages - 2) {
        pageButtons.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '...',
              style: GoogleFonts.outfit(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      }

      pageButtons.add(
        _buildPaginationPage(displayPages, safePage == displayPages, () {
          context.read<DealersBloc>().add(
            UpdateDealersFilterEvent(currentPage: displayPages),
          );
        }),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildPaginationButton(Icons.chevron_left, safePage > 1, () {
          context.read<DealersBloc>().add(
            UpdateDealersFilterEvent(currentPage: safePage - 1),
          );
        }),
        const SizedBox(width: 8),
        ...pageButtons,
        const SizedBox(width: 8),
        _buildPaginationButton(
          Icons.chevron_right,
          safePage < displayPages,
          () {
            context.read<DealersBloc>().add(
              UpdateDealersFilterEvent(currentPage: safePage + 1),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPaginationButton(
    IconData icon,
    bool isEnabled,
    VoidCallback? onTap,
  ) {
    return MouseRegion(
      cursor: isEnabled && onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: isEnabled ? onTap : null,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Icon(
            icon,
            size: 18,
            color: isEnabled ? AppTheme.textSecondary : const Color(0xFFD1D5DB),
          ),
        ),
      ),
    );
  }

  Widget _buildPaginationPage(int page, bool isActive, VoidCallback? onTap) {
    return MouseRegion(
      cursor: onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isActive ? AppTheme.primaryColor : Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isActive ? AppTheme.primaryColor : AppTheme.borderColor,
            ),
          ),
          child: Text(
            page.toString(),
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isActive ? Colors.white : AppTheme.textBody,
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderText extends StatelessWidget {
  final String text;

  const _HeaderText(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: GoogleFonts.outfit(
      fontSize: 11,
      fontWeight: FontWeight.w800,
      color: AppTheme.textSecondary,
      letterSpacing: 0.5,
    ),
  );
}

class _DealerTable extends StatefulWidget {
  final List<Dealer> dealers;
  final bool isMobile;
  final List<Map<String, dynamic>> salesAgents;
  final Function(String userId, String? agentId) onAssignAgent;
  final Function(Dealer dealer) onEditDealer;
  final Function(String userId, String name) onDeleteDealer;
  final Set<String> selectedDealerIds;
  final VoidCallback onSelectionChanged;
  final bool isSubmitting;

  const _DealerTable({
    required this.dealers,
    required this.isMobile,
    required this.salesAgents,
    required this.onAssignAgent,
    required this.onEditDealer,
    required this.onDeleteDealer,
    required this.selectedDealerIds,
    required this.onSelectionChanged,
    this.isSubmitting = false,
  });

  @override
  State<_DealerTable> createState() => _DealerTableState();
}

class _DealerTableState extends State<_DealerTable> {
  int? hoveredRowIndex;

  bool get isAllSelected =>
      widget.dealers.isNotEmpty &&
      widget.dealers.every((d) => widget.selectedDealerIds.contains(d.id));

  void _toggleAll() {
    setState(() {
      if (isAllSelected) {
        for (var d in widget.dealers) {
          widget.selectedDealerIds.remove(d.id ?? '');
        }
      } else {
        for (var d in widget.dealers) {
          if (d.id != null) {
            widget.selectedDealerIds.add(d.id!);
          }
        }
      }
    });
    widget.onSelectionChanged();
  }

  void _toggleSelection(String dealerId) {
    setState(() {
      if (widget.selectedDealerIds.contains(dealerId)) {
        widget.selectedDealerIds.remove(dealerId);
      } else {
        widget.selectedDealerIds.add(dealerId);
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
              width: 250,
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
      const _DealerColumnConfig('Dealer Name', 20),
      const _DealerColumnConfig('Phone Number', 20),
      const _DealerColumnConfig('Location', 20),
      if (AuthService().isAdmin)
        const _DealerColumnConfig('Assigned Agent', 20),
      const _DealerColumnConfig('Source', 12, isCenter: true),
      const _DealerColumnConfig('Status', 16),
      const _DealerColumnConfig('Orders', 12, isCenter: true),
      const _DealerColumnConfig('Purchase Value', 20, isCenter: true),
      const _DealerColumnConfig('Actions', 30, isCenter: true),
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
                final Widget child = Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final double minTableWidth = widget.isMobile
            ? 1300.0
            : (AuthService().isAdmin ? 1220.0 : 1020.0);
        final double safeMaxWidth = constraints.maxWidth.isInfinite
            ? minTableWidth
            : constraints.maxWidth;
        final double tableWidth = safeMaxWidth > minTableWidth
            ? safeMaxWidth
            : minTableWidth;

        return SelectionArea(
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(
              scrollbars: false,
              dragDevices: {
                ui.PointerDeviceKind.touch,
                ui.PointerDeviceKind.trackpad,
              },
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: SizedBox(
                width: tableWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    tableHeader,
                    ...widget.dealers.asMap().entries.map((entry) {
                      final index = entry.key;
                      final dealer = entry.value;
                      final bool isAlternate = index % 2 == 1;
                      final String dealerId = dealer.id ?? '';
                      return _DealerRow(
                        dealer: dealer,
                        isAlternate: isAlternate,
                        isMobile: widget.isMobile,
                        isHovered: hoveredRowIndex == index,
                        isSelected: widget.selectedDealerIds.contains(dealerId),
                        onToggleSelection: () => _toggleSelection(dealerId),
                        onTap: () => Navigator.pushNamed(
                          context,
                          '/dealers/profile',
                          arguments: dealer,
                        ),
                        onHover: () => setState(() => hoveredRowIndex = index),
                        onExit: () => setState(() => hoveredRowIndex = null),
                        salesAgents: widget.salesAgents,
                        onAssignAgent: widget.onAssignAgent,
                        onCreateOrder: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CreateOrderPage(dealer: dealer),
                            ),
                          );
                          if (result == true && context.mounted) {
                            context.read<DealersBloc>().add(
                              const FetchDealersDataEvent(forceRefresh: true),
                            );
                          }
                        },
                        onEdit: () => widget.onEditDealer(dealer),
                        onDelete: () =>
                            widget.onDeleteDealer(dealerId, dealer.name),
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

class _DealerRow extends StatelessWidget {
  final Dealer dealer;
  final bool isAlternate;
  final bool isMobile;
  final bool isHovered;
  final bool isSelected;
  final VoidCallback onToggleSelection;
  final VoidCallback onTap;
  final VoidCallback onHover;
  final VoidCallback onExit;
  final List<Map<String, dynamic>> salesAgents;
  final Function(String userId, String? agentId) onAssignAgent;
  final VoidCallback? onCreateOrder;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _DealerRow({
    required this.dealer,
    required this.isAlternate,
    required this.isMobile,
    required this.isHovered,
    required this.isSelected,
    required this.onToggleSelection,
    required this.onTap,
    required this.onHover,
    required this.onExit,
    required this.salesAgents,
    required this.onAssignAgent,
    this.onCreateOrder,
    required this.onEdit,
    required this.onDelete,
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
              width: 250,
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
    Color rowBgColor = isAlternate ? const Color(0xFFFAFBFC) : Colors.white;
    if (isSelected) rowBgColor = AppTheme.primaryColor.withValues(alpha: 0.04);
    if (isHovered) rowBgColor = const Color(0xFFF1F9F3);

    return MouseRegion(
      onEnter: (_) => onHover(),
      onExit: (_) => onExit(),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: BoxDecoration(
            border: const Border(
              bottom: BorderSide(color: Color(0xFFF3F4F6), width: 0.5),
            ),
            color: rowBgColor,
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
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    if (AuthService().isAdmin)
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
                    Expanded(
                      flex: 20,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 12,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              dealer.shopName != null &&
                                      dealer.shopName!.isNotEmpty
                                  ? dealer.shopName!
                                  : 'Unnamed Shop',
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              dealer.name,
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                color: AppTheme.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                    _cell(dealer.phone, flex: 20, isSecondary: true),
                    _cell(
                      (dealer.city.isNotEmpty && dealer.state.isNotEmpty)
                          ? '${dealer.city}, ${dealer.state}'
                          : (dealer.city.isNotEmpty
                                ? dealer.city
                                : dealer.state),
                      flex: 20,
                      isSecondary: true,
                    ),
                    if (AuthService().isAdmin)
                      Expanded(
                        flex: 20,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: GestureDetector(
                            onTap: () {}, // Stop propagation for dropdown
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
                                      salesAgents.any(
                                        (agent) =>
                                            agent['_id'] == dealer.agentId,
                                      )
                                      ? dealer.agentId
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
                                    if (dealer.id != null) {
                                      onAssignAgent(dealer.id!, newAgentId);
                                    }
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
                      ),
                    Expanded(
                      flex: 12,
                      child: Center(child: _SourceBadge(source: dealer.source)),
                    ),
                    _statusCell(dealer.status ?? 'prospect', flex: 16),
                    _cell(
                      dealer.totalOrders.toString(),
                      flex: 12,
                      isBold: true,
                      textAlign: TextAlign.center,
                    ),
                    _cell(
                      dealer.purchaseValue,
                      flex: 20,
                      isBold: true,
                      textAlign: TextAlign.center,
                    ),
                    Expanded(
                      flex: 30,
                      child: Center(
                        child: GestureDetector(
                          onTap: () {}, // Stop propagation for buttons
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (onCreateOrder != null) ...[
                                GestureDetector(
                                  onTap: onCreateOrder,
                                  child: MouseRegion(
                                    cursor: SystemMouseCursors.click,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            AppTheme.primaryColor.withValues(
                                              alpha: 0.85,
                                            ),
                                            AppTheme.primaryColor,
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppTheme.primaryColor
                                                .withValues(alpha: 0.25),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.add_shopping_cart_rounded,
                                            size: 13,
                                            color: Colors.white,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Order',
                                            style: GoogleFonts.outfit(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              _ConnectedActionButtons(
                                onEdit: onEdit,
                                onDelete: onDelete,
                              ),
                            ],
                          ),
                        ),
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

  Widget _cell(
    String text, {
    int flex = 1,
    bool isBold = false,
    bool isSecondary = false,
    TextAlign textAlign = TextAlign.left,
  }) {
    return Expanded(
      flex: flex,
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

  Widget _statusCell(String status, {int flex = 1}) {
    Color color = Colors.grey;
    switch (status.toLowerCase()) {
      case 'kyc pending':
        color = Colors.amber;
        break;
      case 'call not picked':
        color = Colors.orange;
        break;
      case 'connected but not intrested':
        color = Colors.blueGrey;
        break;
      case 'quotation sent':
        color = Colors.blue;
        break;
      case 'negotiation':
        color = Colors.indigo;
        break;
      case 'follow-up':
        color = Colors.deepPurple;
        break;
      case 'lost':
        color = Colors.red;
        break;
      case 'intrested':
        color = Colors.green;
        break;
      case 'customer busy':
        color = Colors.teal;
        break;
      case 'call switch off':
        color = Colors.redAccent;
        break;
      case 'prospect':
        color = Colors.cyan;
        break;
    }

    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: color.withOpacity(0.3), width: 1),
            ),
            child: Text(
              status.toUpperCase(),
              style: GoogleFonts.outfit(
                fontSize: 10.5,
                color: color,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }
}

class _DealerColumnConfig {
  final String title;
  final int flex;
  final bool isCenter;

  const _DealerColumnConfig(this.title, this.flex, {this.isCenter = false});
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
              width: 250,
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
              width: 250,
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
          width: 65,
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
        const SizedBox(width: 6),
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
              width: 250,
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
