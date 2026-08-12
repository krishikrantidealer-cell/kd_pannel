import 'package:equatable/equatable.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';

enum LeadsStatus { initial, loading, success, failure, submitting }

class LeadsState extends Equatable {
  final LeadsStatus status;
  final List<Map<String, dynamic>> allRawUsers;
  final List<Map<String, dynamic>> salesAgents;

  // Filtering and pagination states
  final String searchQuery;
  final String selectedState;
  final String selectedTimeframe;
  final PickerDateRange? selectedRange;
  final String selectedFilterChip;
  final int currentPage;
  final int pageSize;

  // Messages for UI notifications
  final String? errorMessage;
  final String? actionSuccessMessage;

  // Profile-specific states
  final Map<String, dynamic>? currentLeadDetails;
  final List<Map<String, dynamic>> currentLeadEvents;
  final bool isLoadingProfile;
  final bool isLoadingEvents;

  // Daily performance analytics states
  final Map<String, dynamic>? dailyLeadStats;
  final DateTime? selectedDailyDate;
  final String? selectedDailyAgentId;
  final bool isLoadingDailyStats;
  final String analyticsViewMode; // 'allTime' or 'daily'

  const LeadsState({
    this.status = LeadsStatus.initial,
    this.allRawUsers = const [],
    this.salesAgents = const [],
    this.searchQuery = '',
    this.selectedState = 'All States',
    this.selectedTimeframe = 'All Time',
    this.selectedRange,
    this.selectedFilterChip = 'All',
    this.currentPage = 1,
    this.pageSize = 10,
    this.errorMessage,
    this.actionSuccessMessage,
    this.currentLeadDetails,
    this.currentLeadEvents = const [],
    this.isLoadingProfile = false,
    this.isLoadingEvents = false,
    this.dailyLeadStats,
    this.selectedDailyDate,
    this.selectedDailyAgentId,
    this.isLoadingDailyStats = false,
    this.analyticsViewMode = 'allTime',
  });

  LeadsState copyWith({
    LeadsStatus? status,
    List<Map<String, dynamic>>? allRawUsers,
    List<Map<String, dynamic>>? salesAgents,
    String? searchQuery,
    String? selectedState,
    String? selectedTimeframe,
    PickerDateRange? selectedRange,
    String? selectedFilterChip,
    int? currentPage,
    int? pageSize,
    String? errorMessage,
    String? actionSuccessMessage,
    Map<String, dynamic>? currentLeadDetails,
    List<Map<String, dynamic>>? currentLeadEvents,
    bool? isLoadingProfile,
    bool? isLoadingEvents,
    Map<String, dynamic>? dailyLeadStats,
    DateTime? selectedDailyDate,
    String? selectedDailyAgentId,
    bool? isLoadingDailyStats,
    String? analyticsViewMode,
  }) {
    return LeadsState(
      status: status ?? this.status,
      allRawUsers: allRawUsers ?? this.allRawUsers,
      salesAgents: salesAgents ?? this.salesAgents,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedState: selectedState ?? this.selectedState,
      selectedTimeframe: selectedTimeframe ?? this.selectedTimeframe,
      selectedRange: selectedRange ?? this.selectedRange,
      selectedFilterChip: selectedFilterChip ?? this.selectedFilterChip,
      currentPage: currentPage ?? this.currentPage,
      pageSize: pageSize ?? this.pageSize,
      errorMessage: errorMessage, // Reset by default when copyWith is called unless explicitly set
      actionSuccessMessage: actionSuccessMessage, // Reset by default when copyWith is called unless explicitly set
      currentLeadDetails: currentLeadDetails ?? this.currentLeadDetails,
      currentLeadEvents: currentLeadEvents ?? this.currentLeadEvents,
      isLoadingProfile: isLoadingProfile ?? this.isLoadingProfile,
      isLoadingEvents: isLoadingEvents ?? this.isLoadingEvents,
      dailyLeadStats: dailyLeadStats ?? this.dailyLeadStats,
      selectedDailyDate: selectedDailyDate ?? this.selectedDailyDate,
      selectedDailyAgentId: selectedDailyAgentId ?? this.selectedDailyAgentId,
      isLoadingDailyStats: isLoadingDailyStats ?? this.isLoadingDailyStats,
      analyticsViewMode: analyticsViewMode ?? this.analyticsViewMode,
    );
  }

  LeadsState copyWithKeepMessages({
    LeadsStatus? status,
    List<Map<String, dynamic>>? allRawUsers,
    List<Map<String, dynamic>>? salesAgents,
    String? searchQuery,
    String? selectedState,
    String? selectedTimeframe,
    PickerDateRange? selectedRange,
    String? selectedFilterChip,
    int? currentPage,
    int? pageSize,
    String? errorMessage,
    String? actionSuccessMessage,
    Map<String, dynamic>? dailyLeadStats,
    DateTime? selectedDailyDate,
    String? selectedDailyAgentId,
    bool? isLoadingDailyStats,
    String? analyticsViewMode,
  }) {
    return LeadsState(
      status: status ?? this.status,
      allRawUsers: allRawUsers ?? this.allRawUsers,
      salesAgents: salesAgents ?? this.salesAgents,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedState: selectedState ?? this.selectedState,
      selectedTimeframe: selectedTimeframe ?? this.selectedTimeframe,
      selectedRange: selectedRange ?? this.selectedRange,
      selectedFilterChip: selectedFilterChip ?? this.selectedFilterChip,
      currentPage: currentPage ?? this.currentPage,
      pageSize: pageSize ?? this.pageSize,
      errorMessage: errorMessage ?? this.errorMessage,
      actionSuccessMessage: actionSuccessMessage ?? this.actionSuccessMessage,
      dailyLeadStats: dailyLeadStats ?? this.dailyLeadStats,
      selectedDailyDate: selectedDailyDate ?? this.selectedDailyDate,
      selectedDailyAgentId: selectedDailyAgentId ?? this.selectedDailyAgentId,
      isLoadingDailyStats: isLoadingDailyStats ?? this.isLoadingDailyStats,
      analyticsViewMode: analyticsViewMode ?? this.analyticsViewMode,
    );
  }

  LeadsState copyWithResetRange({
    LeadsStatus? status,
    List<Map<String, dynamic>>? allRawUsers,
    List<Map<String, dynamic>>? salesAgents,
    String? searchQuery,
    String? selectedState,
    String? selectedTimeframe,
    String? selectedFilterChip,
    int? currentPage,
    int? pageSize,
    String? errorMessage,
    String? actionSuccessMessage,
    Map<String, dynamic>? dailyLeadStats,
    DateTime? selectedDailyDate,
    String? selectedDailyAgentId,
    bool? isLoadingDailyStats,
    String? analyticsViewMode,
  }) {
    return LeadsState(
      status: status ?? this.status,
      allRawUsers: allRawUsers ?? this.allRawUsers,
      salesAgents: salesAgents ?? this.salesAgents,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedState: selectedState ?? this.selectedState,
      selectedTimeframe: selectedTimeframe ?? this.selectedTimeframe,
      selectedRange: null, // explicitly reset selectedRange
      selectedFilterChip: selectedFilterChip ?? this.selectedFilterChip,
      currentPage: currentPage ?? this.currentPage,
      pageSize: pageSize ?? this.pageSize,
      errorMessage: errorMessage,
      actionSuccessMessage: actionSuccessMessage,
      dailyLeadStats: dailyLeadStats ?? this.dailyLeadStats,
      selectedDailyDate: selectedDailyDate ?? this.selectedDailyDate,
      selectedDailyAgentId: selectedDailyAgentId ?? this.selectedDailyAgentId,
      isLoadingDailyStats: isLoadingDailyStats ?? this.isLoadingDailyStats,
      analyticsViewMode: analyticsViewMode ?? this.analyticsViewMode,
    );
  }

  @override
  List<Object?> get props => [
        status,
        allRawUsers,
        salesAgents,
        searchQuery,
        selectedState,
        selectedTimeframe,
        selectedRange,
        selectedFilterChip,
        currentPage,
        pageSize,
        errorMessage,
        actionSuccessMessage,
        currentLeadDetails,
        currentLeadEvents,
        isLoadingProfile,
        isLoadingEvents,
        dailyLeadStats,
        selectedDailyDate,
        selectedDailyAgentId,
        isLoadingDailyStats,
        analyticsViewMode,
      ];
}
