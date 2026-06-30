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

  @override
  void initState() {
    super.initState();
    _dealersBloc = context.read<DealersBloc>();
    final bloc = _dealersBloc!;
    if (bloc.state.status == DealersStatus.initial) {
      bloc.add(const FetchDealersDataEvent());
    }

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
    'All Time',
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

    // Optimization: Group orders by user ID once
    final Map<String, List<Map<String, dynamic>>> ordersByUserId = {};
    for (final order in state.allRawOrders) {
      if (order['orderStatus'] == 'Cancelled') continue;
      final userId = order['user']?['_id'];
      if (userId != null) {
        ordersByUserId.putIfAbsent(userId, () => []).add(order);
      }
    }

    return state.allRawUsers
        .where((u) {
          final role = u['role'] ?? 'user';
          final kycStatus = u['kycStatus'] ?? 'pending';
          final isDealer = role == 'user' && kycStatus == 'verified';
          if (!isDealer) return false;

          if (isSales) {
            final assignedAgentId = u['assignedAgent']?['_id'];
            return assignedAgentId == agentId;
          }
          return true;
        })
        .map((u) {
          final userId = u['_id'];
          final dealerOrders = ordersByUserId[userId] ?? [];
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
            notesHistory: u['notesHistory'] != null
                ? List<Map<String, dynamic>>.from(u['notesHistory'])
                : [],
          );
        })
        .toList();
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

  List<Dealer> _getFilteredDealersInternal(
    List<Dealer> calculatedDealers,
    DealersState state,
  ) {
    return calculatedDealers.where((dealer) {
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

  List<Dealer> _getFilteredDealers(DealersState state) {
    return _getFilteredDealersInternal(_getallCalculatedDealers(state), state);
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

    return SelectionArea(
      child: BlocProvider.value(
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

            final allCalculated = _getallCalculatedDealers(state);
            final filteredDealers = _getFilteredDealersInternal(
              allCalculated,
              state,
            );

            final double minTableWidth = isMobile
                ? 1300.0
                : (AuthService().isAdmin ? 1220.0 : 1020.0);

            final Widget body = CustomScrollView(
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
                        _buildHeader(context, state, isMobile),
                        const SizedBox(height: 16),
                        _buildStatsCardsInternal(allCalculated, state, context),
                        const SizedBox(height: 24),
                        _buildFiltersRow(context, state, isMobile, isDesktop),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: isDesktop ? 28 : 16),
                  sliver: SliverToBoxAdapter(
                    child: _DealerTableCard(
                      dealers: filteredDealers,
                      isMobile: isMobile,
                      salesAgents: state.salesAgents,
                      onAssignAgent: (userId, agentId) {
                        _dealersBloc?.add(
                          AssignAgentToDealerEvent(
                            userId: userId,
                            agentId: agentId,
                          ),
                        );
                      },
                      onBulkAssignAgent: (userIds, agentId) {
                        _dealersBloc?.add(
                          BulkAssignAgentToDealersEvent(
                            userIds: userIds,
                            agentId: agentId,
                          ),
                        );
                      },
                      onEditDealer: _editDealer,
                      onDeleteDealer: _deleteDealer,
                      isSubmitting: state.status == DealersStatus.submitting,
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
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

  Widget _buildStatsCardsInternal(
    List<Dealer> calculated,
    DealersState state,
    BuildContext context,
  ) {
    final isDesktop = Responsive.isDesktop(context);
    var filtered = calculated;

    // Apply page-level Date Filtering for stats cards
    DateTime? startDate;
    DateTime? endDate;

    if (state.selectedTimeframe == 'Custom Range' &&
        state.customStartDate != null) {
      startDate = state.customStartDate;
      endDate = state.customEndDate ?? state.customStartDate;
      endDate = DateTime(endDate!.year, endDate.month, endDate.day, 23, 59, 59);
    } else if (state.selectedTimeframe != 'Custom Range' &&
        state.selectedTimeframe.isNotEmpty &&
        state.selectedTimeframe != 'All Time') {
      final now = DateTime.now();
      endDate = now;
      switch (state.selectedTimeframe) {
        case 'Today':
          startDate = DateTime(now.year, now.month, now.day);
          break;
        case 'Yesterday':
          final yesterday = now.subtract(const Duration(days: 1));
          startDate = DateTime(yesterday.year, yesterday.month, yesterday.day);
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
          endDate = startDate.add(
            const Duration(days: 6, hours: 23, minutes: 59, seconds: 59),
          );
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
      filtered = filtered.where((dealer) {
        final dateStr = dealer.createdAt ?? dealer.updatedAt;
        if (dateStr == null) return false;
        try {
          final date = DateTime.parse(dateStr).toLocal();
          return !date.isBefore(startDate!) && !date.isAfter(endDate!);
        } catch (e) {
          return false;
        }
      }).toList();
    }

    final totalDealers = filtered.length;
    final activeDealers = filtered.where((d) => !d.isInactive).length;
    final highValueDealers = filtered.where((d) => d.isHighValue).length;
    final inactiveDealers = filtered.where((d) => d.isInactive).length;

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
}

class _DealerTableCard extends StatefulWidget {
  final List<Dealer> dealers;
  final bool isMobile;
  final List<Map<String, dynamic>> salesAgents;
  final Function(String userId, String? agentId) onAssignAgent;
  final Function(List<String> userIds, String? agentId) onBulkAssignAgent;
  final Function(Dealer dealer) onEditDealer;
  final Function(String userId, String name) onDeleteDealer;
  final bool isSubmitting;

  const _DealerTableCard({
    super.key,
    required this.dealers,
    required this.isMobile,
    required this.salesAgents,
    required this.onAssignAgent,
    required this.onBulkAssignAgent,
    required this.onEditDealer,
    required this.onDeleteDealer,
    required this.isSubmitting,
  });

  @override
  State<_DealerTableCard> createState() => _DealerTableCardState();
}

class _DealerTableCardState extends State<_DealerTableCard> {
  String selectedAssign = 'Assign';
  String selectedStatus = 'Status';
  PickerDateRange? _selectedTableRange;
  String selectedTableDropdown = 'All Time';
  final Set<String> _selectedDealerIds = {};

  int get _currentPage => context.read<DealersBloc>().state.currentPage;
  int get _pageSize => context.read<DealersBloc>().state.pageSize;

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
          'Are you sure you want to assign ${agentId == null ? "no agent" : "sales agent \\\"$agentName\\\""} to ${_selectedDealerIds.length} selected dealers?',
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Confirm',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final ids = _selectedDealerIds.toList();
      await widget.onBulkAssignAgent(ids, agentId);
      setState(() {
        _selectedDealerIds.clear();
      });
    }
  }

  Widget _buildBulkActionsControls() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${_selectedDealerIds.length} selected',
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
              _selectedDealerIds.clear();
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
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCombinedControls() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (AuthService().isAdmin) ...[
          _buildTableDropdown('Assign', selectedAssign, [
            'All',
            'Unassigned',
            ...widget.salesAgents.map(
              (agent) =>
                  '${agent['firstName'] ?? ''} ${agent['lastName'] ?? ''}'
                      .trim(),
            ),
          ], (val) => setState(() => selectedAssign = val!)),
          const SizedBox(width: 12),
        ],
        const SizedBox(width: 12),
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
        const SizedBox(width: 12),
        _buildTableDateSection(),
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
              items:
                  [
                    'All Time',
                    'Today',
                    'Yesterday',
                    'Last 7 Days',
                    'Last 30 Days',
                  ].map<DropdownMenuItem<String>>((String value) {
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
                  }).toList(),
            ),
          ),
        ],
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

    Widget buildPageButton(int page, bool isActive) {
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () {
            context.read<DealersBloc>().add(
              UpdateDealersFilterEvent(currentPage: page),
            );
          },
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

    Widget buildChevronButton(
      IconData icon,
      bool isEnabled,
      VoidCallback onTap,
    ) {
      return MouseRegion(
        cursor: isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
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
              color: isEnabled
                  ? AppTheme.textSecondary
                  : const Color(0xFFD1D5DB),
            ),
          ),
        ),
      );
    }

    if (displayPages <= 5) {
      for (int i = 1; i <= displayPages; i++) {
        pageButtons.add(buildPageButton(i, currentPage == i));
        if (i < displayPages) {
          pageButtons.add(const SizedBox(width: 8));
        }
      }
    } else {
      pageButtons.add(buildPageButton(1, currentPage == 1));
      pageButtons.add(const SizedBox(width: 8));

      if (currentPage > 3) {
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
        pageButtons.add(const SizedBox(width: 8));
      }

      final start = (currentPage - 1).clamp(2, displayPages - 1);
      final end = (currentPage + 1).clamp(2, displayPages - 1);

      for (int i = start; i <= end; i++) {
        if (i > 1 && i < displayPages) {
          pageButtons.add(buildPageButton(i, currentPage == i));
          pageButtons.add(const SizedBox(width: 8));
        }
      }

      if (currentPage < displayPages - 2) {
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
        pageButtons.add(const SizedBox(width: 8));
      }

      pageButtons.add(
        buildPageButton(displayPages, currentPage == displayPages),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        buildChevronButton(Icons.chevron_left, currentPage > 1, () {
          context.read<DealersBloc>().add(
            UpdateDealersFilterEvent(currentPage: currentPage - 1),
          );
        }),
        const SizedBox(width: 8),
        ...pageButtons,
        const SizedBox(width: 8),
        buildChevronButton(Icons.chevron_right, currentPage < displayPages, () {
          context.read<DealersBloc>().add(
            UpdateDealersFilterEvent(currentPage: currentPage + 1),
          );
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = Responsive.isDesktop(context);

    // 1. Local Filtering for Table Controls
    List<Dealer> tableDealers = widget.dealers;

    // Filter by Status
    if (selectedStatus != 'Status' && selectedStatus != 'All') {
      tableDealers = tableDealers.where((d) {
        final status = d.status ?? 'prospect';
        String dbStatus = status.toLowerCase();
        String filterStatus = selectedStatus.toLowerCase();
        if (filterStatus == 'interested') filterStatus = 'intrested';
        if (filterStatus == 'connected but not interested')
          filterStatus = 'connected but not intrested';
        return dbStatus == filterStatus;
      }).toList();
    }

    // Filter by Assigned Agent (only for admin)
    if (AuthService().isAdmin &&
        selectedAssign != 'Assign' &&
        selectedAssign != 'All') {
      tableDealers = tableDealers.where((d) {
        if (selectedAssign == 'Unassigned') return d.agentId == null;
        return d.agent.toLowerCase().contains(selectedAssign.toLowerCase());
      }).toList();
    }

    // Filter by Table Date Section
    DateTime? tableStartDate;
    DateTime? tableEndDate;
    if (_selectedTableRange != null && _selectedTableRange!.startDate != null) {
      tableStartDate = _selectedTableRange!.startDate;
      tableEndDate =
          _selectedTableRange!.endDate ?? _selectedTableRange!.startDate;
      tableEndDate = DateTime(
        tableEndDate!.year,
        tableEndDate.month,
        tableEndDate.day,
        23,
        59,
        59,
      );
    } else {
      final now = DateTime.now();
      switch (selectedTableDropdown) {
        case 'Today':
          tableStartDate = DateTime(now.year, now.month, now.day);
          tableEndDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
          break;
        case 'Yesterday':
          final yesterday = now.subtract(const Duration(days: 1));
          tableStartDate = DateTime(
            yesterday.year,
            yesterday.month,
            yesterday.day,
          );
          tableEndDate = DateTime(
            yesterday.year,
            yesterday.month,
            yesterday.day,
            23,
            59,
            59,
          );
          break;
        case 'Last 7 Days':
          tableStartDate = now.subtract(const Duration(days: 7));
          tableEndDate = now;
          break;
        case 'Last 30 Days':
          tableStartDate = now.subtract(const Duration(days: 30));
          tableEndDate = now;
          break;
      }
    }

    if (tableStartDate != null && tableEndDate != null) {
      tableDealers = tableDealers.where((d) {
        final dateStr = d.createdAt ?? d.updatedAt;
        if (dateStr == null) return false;
        try {
          final date = DateTime.parse(dateStr).toLocal();
          return date.isAfter(tableStartDate!) && date.isBefore(tableEndDate!);
        } catch (e) {
          return false;
        }
      }).toList();
    }

    final total = tableDealers.length;
    final totalPages = (total / _pageSize).ceil();
    final currentPage = _currentPage.clamp(1, totalPages > 0 ? totalPages : 1);
    final startIndex = (currentPage - 1) * _pageSize;
    final endIndex = (startIndex + _pageSize) > total
        ? total
        : (startIndex + _pageSize);
    final paginatedDealers = total == 0
        ? <Dealer>[]
        : tableDealers.sublist(startIndex, endIndex);

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
                        'Dealer Records',
                        style: AppTheme.headingMD.copyWith(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                      _selectedDealerIds.isNotEmpty
                          ? _buildBulkActionsControls()
                          : _buildCombinedControls(),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dealer Records',
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
                        child: _selectedDealerIds.isNotEmpty
                            ? _buildBulkActionsControls()
                            : _buildCombinedControls(),
                      ),
                    ],
                  ),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final double minTableWidth = widget.isMobile
                  ? 1300.0
                  : (AuthService().isAdmin ? 1220.0 : 1020.0);
              final double width = constraints.maxWidth > minTableWidth
                  ? constraints.maxWidth
                  : minTableWidth;
              return ScrollConfiguration(
                behavior: ScrollConfiguration.of(
                  context,
                ).copyWith(scrollbars: true),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: width,
                    child: _DealerTable(
                      dealers: paginatedDealers,
                      isMobile: widget.isMobile,
                      salesAgents: widget.salesAgents,
                      onAssignAgent: widget.onAssignAgent,
                      onEditDealer: widget.onEditDealer,
                      onDeleteDealer: widget.onDeleteDealer,
                      selectedDealerIds: _selectedDealerIds,
                      isSubmitting: widget.isSubmitting,
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
  // Removed hoveredRowIndex from parent to prevent full table rebuilds on hover

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
      const _DealerColumnConfig('Dealer Name', 32),
      const _DealerColumnConfig('Phone Number', 20),
      const _DealerColumnConfig('Location', 20),
      if (AuthService().isAdmin)
        const _DealerColumnConfig('Assigned Agent', 20),
      const _DealerColumnConfig('Status', 16),
      const _DealerColumnConfig('Orders', 12, isCenter: true),
      const _DealerColumnConfig('Purchase Value', 20, isCenter: true),
      const _DealerColumnConfig('Actions', 18, isCenter: true),
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
                final rightPadding = col.title == 'Assigned Agent'
                    ? 36.0
                    : 12.0;
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
          itemCount: widget.dealers.length,
          itemExtent: 68,
          addRepaintBoundaries: true,
          itemBuilder: (context, index) {
            final dealer = widget.dealers[index];
            final bool isAlternate = index % 2 == 1;
            final String dealerId = dealer.id ?? '';
            return _DealerRow(
              dealer: dealer,
              isAlternate: isAlternate,
              isMobile: widget.isMobile,
              isSelected: widget.selectedDealerIds.contains(dealerId),
              onToggleSelection: () => _toggleSelection(dealerId),
              onTap: () => Navigator.pushNamed(
                context,
                '/dealers/profile',
                arguments: dealer,
              ),
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
              onDelete: () => widget.onDeleteDealer(dealerId, dealer.name),
            );
          },
        ),
      ],
    );
  }
}

class _DealerRow extends StatefulWidget {
  final Dealer dealer;
  final bool isAlternate;
  final bool isMobile;
  final bool isSelected;
  final VoidCallback onToggleSelection;
  final VoidCallback onTap;
  final List<Map<String, dynamic>> salesAgents;
  final Function(String userId, String? agentId) onAssignAgent;
  final VoidCallback? onCreateOrder;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _DealerRow({
    required this.dealer,
    required this.isAlternate,
    required this.isMobile,
    required this.isSelected,
    required this.onToggleSelection,
    required this.onTap,
    required this.salesAgents,
    required this.onAssignAgent,
    this.onCreateOrder,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_DealerRow> createState() => _DealerRowState();
}

class _DealerRowState extends State<_DealerRow> {
  bool isHovered = false;

  // Optimized static styles to avoid repeated GoogleFonts calls
  static final TextStyle _shopNameStyle = GoogleFonts.outfit(
    fontSize: 13,
    color: AppTheme.textPrimary,
    fontWeight: FontWeight.w700,
  );
  static final TextStyle _dealerNameStyle = GoogleFonts.outfit(
    fontSize: 11,
    color: AppTheme.textSecondary,
    fontWeight: FontWeight.w500,
  );
  static final TextStyle _cellTextStyle = GoogleFonts.outfit(
    fontSize: 13,
    fontWeight: FontWeight.w500,
  );
  static final TextStyle _cellBoldTextStyle = GoogleFonts.outfit(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    color: AppTheme.textPrimary,
  );
  static final TextStyle _statusTextStyle = GoogleFonts.outfit(
    fontSize: 10.5,
    fontWeight: FontWeight.bold,
  );

  @override
  Widget build(BuildContext context) {
    // Simplified background logic
    final Color rowBgColor = isHovered
        ? const Color(0xFFF1F9F3)
        : (widget.isSelected
              ? AppTheme.primaryColor.withValues(alpha: 0.04)
              : (widget.isAlternate ? const Color(0xFFFAFBFC) : Colors.white));

    return RepaintBoundary(
      child: MouseRegion(
        onEnter: (_) => setState(() => isHovered = true),
        onExit: (_) => setState(() => isHovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            decoration: BoxDecoration(
              border: const Border(
                bottom: BorderSide(color: Color(0xFFF3F4F6), width: 0.5),
              ),
              color: rowBgColor,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  if (AuthService().isAdmin)
                    SizedBox(
                      width: 40,
                      child: Center(
                        child: (isHovered || widget.isSelected)
                            ? _CustomCheckbox(
                                isSelected: widget.isSelected,
                                onTap: widget.onToggleSelection,
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),
                  Expanded(
                    flex: 32,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.dealer.shopName != null &&
                                    widget.dealer.shopName!.isNotEmpty
                                ? widget.dealer.shopName!
                                : 'Unnamed Shop',
                            style: _shopNameStyle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            widget.dealer.name,
                            style: _dealerNameStyle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                  _cell(widget.dealer.phone, flex: 20, isSecondary: true),
                  _cell(
                    (widget.dealer.city.isNotEmpty &&
                            widget.dealer.state.isNotEmpty)
                        ? '${widget.dealer.city}, ${widget.dealer.state}'
                        : (widget.dealer.city.isNotEmpty
                              ? widget.dealer.city
                              : widget.dealer.state),
                    flex: 20,
                    isSecondary: true,
                  ),
                  if (AuthService().isAdmin)
                    Expanded(
                      flex: 20,
                      child: Padding(
                        padding: const EdgeInsets.only(
                          left: 12,
                          right: 36,
                          top: 8,
                          bottom: 8,
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
                                    widget.salesAgents.any(
                                      (agent) =>
                                          agent['_id'] == widget.dealer.agentId,
                                    )
                                    ? widget.dealer.agentId
                                    : null,
                                isExpanded: true,
                                isDense: true,
                                icon: const Icon(
                                  Icons.arrow_drop_down,
                                  size: 16,
                                  color: AppTheme.textSecondary,
                                ),
                                hint: Text('-', style: _dealerNameStyle),
                                onChanged: (String? newAgentId) {
                                  if (widget.dealer.id != null) {
                                    widget.onAssignAgent(
                                      widget.dealer.id!,
                                      newAgentId,
                                    );
                                  }
                                },
                                items: [
                                  DropdownMenuItem<String>(
                                    value: null,
                                    child: Text('-', style: _dealerNameStyle),
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
                                        style: _cellBoldTextStyle.copyWith(
                                          fontSize: 12.5,
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
                  _statusCell(widget.dealer.status ?? 'prospect', flex: 16),
                  _cell(
                    widget.dealer.totalOrders.toString(),
                    flex: 12,
                    isBold: true,
                    textAlign: TextAlign.center,
                  ),
                  _cell(
                    widget.dealer.purchaseValue,
                    flex: 20,
                    isBold: true,
                    textAlign: TextAlign.center,
                  ),
                  Expanded(
                    flex: 18,
                    child: Center(
                      child: GestureDetector(
                        onTap: () {}, // Stop propagation for buttons
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.onCreateOrder != null) ...[
                              GestureDetector(
                                onTap: widget.onCreateOrder,
                                child: MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor,
                                      borderRadius: BorderRadius.circular(8),
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
                                          style: _statusTextStyle.copyWith(
                                            color: Colors.white,
                                            fontSize: 11,
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
                              onEdit: widget.onEdit,
                              onDelete: widget.onDelete,
                            ),
                          ],
                        ),
                      ),
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
          style: isBold
              ? _cellBoldTextStyle
              : _cellTextStyle.copyWith(
                  color: isSecondary
                      ? AppTheme.textSecondary
                      : AppTheme.textBody,
                ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
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
