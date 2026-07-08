import 'package:equatable/equatable.dart';

enum AuditLogsStatus { initial, loading, success, failure, loadingMore }

class AuditLogsState extends Equatable {
  final AuditLogsStatus status;
  final List<Map<String, dynamic>> logs;
  final int totalCount;
  final String? nextCursor;
  final bool hasReachedMax;
  final String searchQuery;
  final String? currentRole;
  final String? errorMessage;
  final String? actionSuccessMessage;

  const AuditLogsState({
    this.status = AuditLogsStatus.initial,
    this.logs = const [],
    this.totalCount = 0,
    this.nextCursor,
    this.hasReachedMax = false,
    this.searchQuery = '',
    this.currentRole,
    this.errorMessage,
    this.actionSuccessMessage,
  });

  AuditLogsState copyWith({
    AuditLogsStatus? status,
    List<Map<String, dynamic>>? logs,
    int? totalCount,
    String? nextCursor,
    bool? hasReachedMax,
    String? searchQuery,
    String? currentRole,
    String? errorMessage,
    String? actionSuccessMessage,
  }) {
    return AuditLogsState(
      status: status ?? this.status,
      logs: logs ?? this.logs,
      totalCount: totalCount ?? this.totalCount,
      nextCursor: nextCursor ?? this.nextCursor,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
      searchQuery: searchQuery ?? this.searchQuery,
      currentRole: currentRole ?? this.currentRole,
      errorMessage: errorMessage ?? this.errorMessage,
      actionSuccessMessage: actionSuccessMessage ?? this.actionSuccessMessage,
    );
  }

  @override
  List<Object?> get props => [
    status,
    logs,
    totalCount,
    nextCursor,
    hasReachedMax,
    searchQuery,
    currentRole,
    errorMessage,
    actionSuccessMessage,
  ];
}
