import 'package:equatable/equatable.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';

enum LeadsStatus { initial, loading, success, failure, submitting }

class LeadsState extends Equatable {
  final LeadsStatus status;
  final List<Map<String, dynamic>> allRawUsers;
  final List<Map<String, dynamic>> salesAgents;

  // Filtering and pagination states
  final String searchQuery;
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

  const LeadsState({
    this.status = LeadsStatus.initial,
    this.allRawUsers = const [],
    this.salesAgents = const [],
    this.searchQuery = '',
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
  });

  LeadsState copyWith({
    LeadsStatus? status,
    List<Map<String, dynamic>>? allRawUsers,
    List<Map<String, dynamic>>? salesAgents,
    String? searchQuery,
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
  }) {
    return LeadsState(
      status: status ?? this.status,
      allRawUsers: allRawUsers ?? this.allRawUsers,
      salesAgents: salesAgents ?? this.salesAgents,
      searchQuery: searchQuery ?? this.searchQuery,
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
    );
  }

  LeadsState copyWithKeepMessages({
    LeadsStatus? status,
    List<Map<String, dynamic>>? allRawUsers,
    List<Map<String, dynamic>>? salesAgents,
    String? searchQuery,
    String? selectedTimeframe,
    PickerDateRange? selectedRange,
    String? selectedFilterChip,
    int? currentPage,
    int? pageSize,
    String? errorMessage,
    String? actionSuccessMessage,
  }) {
    return LeadsState(
      status: status ?? this.status,
      allRawUsers: allRawUsers ?? this.allRawUsers,
      salesAgents: salesAgents ?? this.salesAgents,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedTimeframe: selectedTimeframe ?? this.selectedTimeframe,
      selectedRange: selectedRange ?? this.selectedRange,
      selectedFilterChip: selectedFilterChip ?? this.selectedFilterChip,
      currentPage: currentPage ?? this.currentPage,
      pageSize: pageSize ?? this.pageSize,
      errorMessage: errorMessage ?? this.errorMessage,
      actionSuccessMessage: actionSuccessMessage ?? this.actionSuccessMessage,
    );
  }

  LeadsState copyWithResetRange({
    LeadsStatus? status,
    List<Map<String, dynamic>>? allRawUsers,
    List<Map<String, dynamic>>? salesAgents,
    String? searchQuery,
    String? selectedTimeframe,
    String? selectedFilterChip,
    int? currentPage,
    int? pageSize,
    String? errorMessage,
    String? actionSuccessMessage,
  }) {
    return LeadsState(
      status: status ?? this.status,
      allRawUsers: allRawUsers ?? this.allRawUsers,
      salesAgents: salesAgents ?? this.salesAgents,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedTimeframe: selectedTimeframe ?? this.selectedTimeframe,
      selectedRange: null, // explicitly reset selectedRange
      selectedFilterChip: selectedFilterChip ?? this.selectedFilterChip,
      currentPage: currentPage ?? this.currentPage,
      pageSize: pageSize ?? this.pageSize,
      errorMessage: errorMessage,
      actionSuccessMessage: actionSuccessMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        allRawUsers,
        salesAgents,
        searchQuery,
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
      ];
}
