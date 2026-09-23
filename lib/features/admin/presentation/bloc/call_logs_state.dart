import 'package:equatable/equatable.dart';

enum CallLogsStatus { initial, loading, loaded, error }

class CallLogsState extends Equatable {
  final CallLogsStatus status;
  final List<dynamic> callLogs;
  final List<dynamic> salesAgents;
  final int totalCount;
  final int page;
  final int totalPages;
  final bool isLoading;
  final bool isTriggeringCall;
  final bool isSavingDisposition;

  // Telephony Metrics & Leaderboards
  final int totalCalls;
  final int inboundCount;
  final int outboundCount;
  final int missedCount;
  final int totalTalkTimeSeconds;
  final List<dynamic> leaderboard;

  final String selectedType;
  final String selectedStatus;
  final String? selectedAgentId;
  final String searchQuery;

  final String? errorMessage;
  final String? successMessage;

  const CallLogsState({
    this.status = CallLogsStatus.initial,
    this.callLogs = const [],
    this.salesAgents = const [],
    this.totalCount = 0,
    this.page = 1,
    this.totalPages = 1,
    this.isLoading = false,
    this.isTriggeringCall = false,
    this.isSavingDisposition = false,
    this.totalCalls = 0,
    this.inboundCount = 0,
    this.outboundCount = 0,
    this.missedCount = 0,
    this.totalTalkTimeSeconds = 0,
    this.leaderboard = const [],
    this.selectedType = 'all',
    this.selectedStatus = 'all',
    this.selectedAgentId,
    this.searchQuery = '',
    this.errorMessage,
    this.successMessage,
  });

  CallLogsState copyWith({
    CallLogsStatus? status,
    List<dynamic>? callLogs,
    List<dynamic>? salesAgents,
    int? totalCount,
    int? page,
    int? totalPages,
    bool? isLoading,
    bool? isTriggeringCall,
    bool? isSavingDisposition,
    int? totalCalls,
    int? inboundCount,
    int? outboundCount,
    int? missedCount,
    int? totalTalkTimeSeconds,
    List<dynamic>? leaderboard,
    String? selectedType,
    String? selectedStatus,
    String? selectedAgentId,
    bool clearSelectedAgent = false,
    String? searchQuery,
    String? errorMessage,
    bool clearError = false,
    String? successMessage,
    bool clearSuccess = false,
  }) {
    return CallLogsState(
      status: status ?? this.status,
      callLogs: callLogs ?? this.callLogs,
      salesAgents: salesAgents ?? this.salesAgents,
      totalCount: totalCount ?? this.totalCount,
      page: page ?? this.page,
      totalPages: totalPages ?? this.totalPages,
      isLoading: isLoading ?? this.isLoading,
      isTriggeringCall: isTriggeringCall ?? this.isTriggeringCall,
      isSavingDisposition: isSavingDisposition ?? this.isSavingDisposition,
      totalCalls: totalCalls ?? this.totalCalls,
      inboundCount: inboundCount ?? this.inboundCount,
      outboundCount: outboundCount ?? this.outboundCount,
      missedCount: missedCount ?? this.missedCount,
      totalTalkTimeSeconds: totalTalkTimeSeconds ?? this.totalTalkTimeSeconds,
      leaderboard: leaderboard ?? this.leaderboard,
      selectedType: selectedType ?? this.selectedType,
      selectedStatus: selectedStatus ?? this.selectedStatus,
      selectedAgentId: clearSelectedAgent ? null : (selectedAgentId ?? this.selectedAgentId),
      searchQuery: searchQuery ?? this.searchQuery,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }

  @override
  List<Object?> get props => [
        status,
        callLogs,
        salesAgents,
        totalCount,
        page,
        totalPages,
        isLoading,
        isTriggeringCall,
        isSavingDisposition,
        totalCalls,
        inboundCount,
        outboundCount,
        missedCount,
        totalTalkTimeSeconds,
        leaderboard,
        selectedType,
        selectedStatus,
        selectedAgentId,
        searchQuery,
        errorMessage,
        successMessage,
      ];
}
