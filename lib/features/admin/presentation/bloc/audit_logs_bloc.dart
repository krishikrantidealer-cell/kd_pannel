import 'package:flutter_bloc/flutter_bloc.dart';
import 'audit_logs_event.dart';
import 'audit_logs_state.dart';
import 'package:kd_pannel/core/services/analytics_service.dart';

class AuditLogsBloc extends Bloc<AuditLogsEvent, AuditLogsState> {
  AuditLogsBloc() : super(const AuditLogsState()) {
    on<FetchAuditLogsInitial>(_onFetchInitial);
    on<FetchAuditLogsMore>(_onFetchMore);
    on<SearchAuditLogs>(_onSearch);
    on<ChangeAuditLogsFilters>(_onChangeFilters);
    on<NewAuditLogReceived>(_onNewLogReceived);
    on<ClearAuditLogsMessage>(_onClearMessage);
  }

  void _onNewLogReceived(NewAuditLogReceived event, Emitter<AuditLogsState> emit) {
    // Prevent duplicates (though WS should be reliable)
    final exists = state.logs.any((l) => (l['_id'] ?? l['id']) == (event.log['_id'] ?? event.log['id']));
    if (exists) return;

    final updatedLogs = [event.log, ...state.logs];
    emit(state.copyWith(logs: updatedLogs));
  }

  Future<void> _onFetchInitial(
    FetchAuditLogsInitial event,
    Emitter<AuditLogsState> emit,
  ) async {
    if (!event.forceRefresh && state.status == AuditLogsStatus.success) return;

    final String? activeRole = event.role ?? state.currentRole;
    emit(state.copyWith(status: AuditLogsStatus.loading, logs: [], currentRole: activeRole)); // Clear logs on role change/refresh
    try {
      String? startDate;
      String? endDate;
      if (state.selectedDateRange != null) {
        startDate = state.selectedDateRange!.start.toUtc().toIso8601String();
        endDate = state.selectedDateRange!.end.toUtc().toIso8601String();
      }

      final result = await AnalyticsService().fetchAuditLogs(
        limit: 50,
        role: activeRole,
        search: state.searchQuery,
        action: state.actionFilter,
        targetModel: state.moduleFilter,
        adminEmail: state.agentEmail,
        startDate: startDate,
        endDate: endDate,
      );
      final List<Map<String, dynamic>> logs = (result['logs'] as List).cast<Map<String, dynamic>>();
      final int totalCount = result['totalCount'] ?? 0;
      final String? nextCursor = result['nextCursor'];

      emit(state.copyWith(
        status: AuditLogsStatus.success,
        logs: logs,
        totalCount: totalCount,
        nextCursor: nextCursor,
        hasReachedMax: nextCursor == null,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: AuditLogsStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onFetchMore(
    FetchAuditLogsMore event,
    Emitter<AuditLogsState> emit,
  ) async {
    if (state.hasReachedMax || state.status == AuditLogsStatus.loadingMore) return;

    emit(state.copyWith(status: AuditLogsStatus.loadingMore));
    try {
      String? startDate;
      String? endDate;
      if (state.selectedDateRange != null) {
        startDate = state.selectedDateRange!.start.toUtc().toIso8601String();
        endDate = state.selectedDateRange!.end.toUtc().toIso8601String();
      }

      final result = await AnalyticsService().fetchAuditLogs(
        limit: 50,
        before: state.nextCursor,
        role: state.currentRole,
        search: state.searchQuery,
        action: state.actionFilter,
        targetModel: state.moduleFilter,
        adminEmail: state.agentEmail,
        startDate: startDate,
        endDate: endDate,
      );
      final List<Map<String, dynamic>> moreLogs = (result['logs'] as List).cast<Map<String, dynamic>>();
      final int totalCount = result['totalCount'] ?? state.totalCount;
      final String? nextCursor = result['nextCursor'];

      emit(state.copyWith(
        status: AuditLogsStatus.success,
        logs: List.of(state.logs)..addAll(moreLogs),
        totalCount: totalCount,
        nextCursor: nextCursor,
        hasReachedMax: nextCursor == null,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: AuditLogsStatus.success, // Keep existing logs
        errorMessage: 'Failed to load more logs: ${e.toString()}',
      ));
    }
  }

  void _onSearch(SearchAuditLogs event, Emitter<AuditLogsState> emit) {
    add(ChangeAuditLogsFilters(searchQuery: event.query));
  }

  void _onChangeFilters(ChangeAuditLogsFilters event, Emitter<AuditLogsState> emit) {
    emit(state.copyWith(
      searchQuery: event.searchQuery,
      actionFilter: event.actionFilter,
      moduleFilter: event.moduleFilter,
      agentEmail: event.agentEmail,
      selectedDateRange: event.selectedDateRange,
    ));
    add(FetchAuditLogsInitial(forceRefresh: true, role: state.currentRole));
  }

  void _onClearMessage(ClearAuditLogsMessage event, Emitter<AuditLogsState> emit) {
    emit(state.copyWith(errorMessage: null, actionSuccessMessage: null));
  }
}
