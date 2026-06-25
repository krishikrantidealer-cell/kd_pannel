import 'package:equatable/equatable.dart';

enum DealersStatus { initial, loading, success, failure, submitting }

class DealersState extends Equatable {
  final DealersStatus status;
  final List<Map<String, dynamic>> allRawUsers;
  final List<Map<String, dynamic>> allRawOrders;
  final List<Map<String, dynamic>> salesAgents;
  
  // Filtering and pagination states
  final String searchQuery;
  final String selectedAgent;
  final String selectedState;
  final String selectedTimeframe;
  final DateTime? customStartDate;
  final DateTime? customEndDate;
  final bool showHighValueOnly;
  final bool showInactiveOnly;
  final bool showActiveOnly;
  final int currentPage;
  final int pageSize;
  
  // Messages for UI notifications
  final String? errorMessage;
  final String? actionSuccessMessage;

  const DealersState({
    this.status = DealersStatus.initial,
    this.allRawUsers = const [],
    this.allRawOrders = const [],
    this.salesAgents = const [],
    this.searchQuery = '',
    this.selectedAgent = 'All Sales Agents',
    this.selectedState = 'All States',
    this.selectedTimeframe = 'This Week',
    this.customStartDate,
    this.customEndDate,
    this.showHighValueOnly = false,
    this.showInactiveOnly = false,
    this.showActiveOnly = false,
    this.currentPage = 1,
    this.pageSize = 10,
    this.errorMessage,
    this.actionSuccessMessage,
  });

  DealersState copyWith({
    DealersStatus? status,
    List<Map<String, dynamic>>? allRawUsers,
    List<Map<String, dynamic>>? allRawOrders,
    List<Map<String, dynamic>>? salesAgents,
    String? searchQuery,
    String? selectedAgent,
    String? selectedState,
    String? selectedTimeframe,
    DateTime? customStartDate,
    DateTime? customEndDate,
    bool? showHighValueOnly,
    bool? showInactiveOnly,
    bool? showActiveOnly,
    int? currentPage,
    int? pageSize,
    String? errorMessage,
    String? actionSuccessMessage,
  }) {
    return DealersState(
      status: status ?? this.status,
      allRawUsers: allRawUsers ?? this.allRawUsers,
      allRawOrders: allRawOrders ?? this.allRawOrders,
      salesAgents: salesAgents ?? this.salesAgents,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedAgent: selectedAgent ?? this.selectedAgent,
      selectedState: selectedState ?? this.selectedState,
      selectedTimeframe: selectedTimeframe ?? this.selectedTimeframe,
      customStartDate: customStartDate ?? this.customStartDate,
      customEndDate: customEndDate ?? this.customEndDate,
      showHighValueOnly: showHighValueOnly ?? this.showHighValueOnly,
      showInactiveOnly: showInactiveOnly ?? this.showInactiveOnly,
      showActiveOnly: showActiveOnly ?? this.showActiveOnly,
      currentPage: currentPage ?? this.currentPage,
      pageSize: pageSize ?? this.pageSize,
      errorMessage: errorMessage, // Reset by default when copyWith is called unless set
      actionSuccessMessage: actionSuccessMessage, // Reset by default when copyWith is called unless set
    );
  }

  // Explicit helper to update error or success messages without discarding other updates
  DealersState copyWithMessages({
    DealersStatus? status,
    List<Map<String, dynamic>>? allRawUsers,
    List<Map<String, dynamic>>? allRawOrders,
    List<Map<String, dynamic>>? salesAgents,
    String? searchQuery,
    String? selectedAgent,
    String? selectedState,
    String? selectedTimeframe,
    DateTime? customStartDate,
    DateTime? customEndDate,
    bool? showHighValueOnly,
    bool? showInactiveOnly,
    bool? showActiveOnly,
    int? currentPage,
    int? pageSize,
    String? errorMessage,
    String? actionSuccessMessage,
  }) {
    return DealersState(
      status: status ?? this.status,
      allRawUsers: allRawUsers ?? this.allRawUsers,
      allRawOrders: allRawOrders ?? this.allRawOrders,
      salesAgents: salesAgents ?? this.salesAgents,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedAgent: selectedAgent ?? this.selectedAgent,
      selectedState: selectedState ?? this.selectedState,
      selectedTimeframe: selectedTimeframe ?? this.selectedTimeframe,
      customStartDate: customStartDate ?? this.customStartDate,
      customEndDate: customEndDate ?? this.customEndDate,
      showHighValueOnly: showHighValueOnly ?? this.showHighValueOnly,
      showInactiveOnly: showInactiveOnly ?? this.showInactiveOnly,
      showActiveOnly: showActiveOnly ?? this.showActiveOnly,
      currentPage: currentPage ?? this.currentPage,
      pageSize: pageSize ?? this.pageSize,
      errorMessage: errorMessage ?? this.errorMessage,
      actionSuccessMessage: actionSuccessMessage ?? this.actionSuccessMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        allRawUsers,
        allRawOrders,
        salesAgents,
        searchQuery,
        selectedAgent,
        selectedState,
        selectedTimeframe,
        customStartDate,
        customEndDate,
        showHighValueOnly,
        showInactiveOnly,
        showActiveOnly,
        currentPage,
        pageSize,
        errorMessage,
        actionSuccessMessage,
      ];
}
