import 'package:flutter_bloc/flutter_bloc.dart';
import 'audit_logs_event.dart';
import 'audit_logs_state.dart';
import 'package:kd_pannel/core/services/analytics_service.dart';

class AuditLogsBloc extends Bloc<AuditLogsEvent, AuditLogsState> {
  AuditLogsBloc() : super(const AuditLogsState()) {
    on<FetchAuditLogsInitial>(_onFetchInitial);
    on<FetchAuditLogsMore>(_onFetchMore);
    on<SearchAuditLogs>(_onSearch);
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

    emit(state.copyWith(status: AuditLogsStatus.loading, logs: [], currentRole: event.role)); // Clear logs on role change/refresh
    try {
      final result = await AnalyticsService().fetchAuditLogs(
        limit: 50,
        role: event.role,
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
      final result = await AnalyticsService().fetchAuditLogs(
        limit: 50,
        before: state.nextCursor,
        role: state.currentRole,
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
    emit(state.copyWith(searchQuery: event.query));
  }

  void _onClearMessage(ClearAuditLogsMessage event, Emitter<AuditLogsState> emit) {
    emit(state.copyWith(errorMessage: null, actionSuccessMessage: null));
  }
}
