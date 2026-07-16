import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/audit_logs_event.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/audit_logs_state.dart';
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
    // 1. Role filtering: Check if the log's role matches the active tab's role
    final String? logRole = event.log['adminRole'] ?? event.log['role'];
    if (state.currentRole != null && logRole != null) {
      if (logRole.toLowerCase() != state.currentRole!.toLowerCase()) {
        return; // Mismatched tab role, ignore
      }
    }

    // 2. Action filter check
    if (state.actionFilter != 'All' && state.actionFilter.isNotEmpty) {
      final action = (event.log['action'] ?? '').toString().toLowerCase();
      // Action query mimics backend logic: regex matching create/update/delete/security
      final filter = state.actionFilter.toLowerCase();
      if (filter == 'create' && !action.contains('create') && !action.contains('add')) return;
      if (filter == 'update' && !action.contains('update') && !action.contains('edit')) return;
      if (filter == 'delete' && !action.contains('delete') && !action.contains('remove')) return;
      if (filter == 'security' && !action.contains('login') && !action.contains('security') && !action.contains('auth')) return;
    }

    // 3. Module/TargetModel check
    if (state.moduleFilter != 'All' && state.moduleFilter.isNotEmpty) {
      final filter = state.moduleFilter.toLowerCase();
      final targetModel = (event.log['targetModel'] ?? '').toString().toLowerCase();
      final action = (event.log['action'] ?? '').toString().toLowerCase();
      
      if (filter == 'kyc') {
        if (targetModel != 'user' || !action.contains('kyc')) return;
      } else if (filter == 'user') {
        if (targetModel != 'user' || action.contains('kyc')) return;
      } else {
        if (targetModel != filter) return;
      }
    }

    // 4. Agent email check
    if (state.agentEmail != 'All' && state.agentEmail.isNotEmpty) {
      final email = (event.log['adminEmail'] ?? '').toString().toLowerCase();
      if (email != state.agentEmail.toLowerCase()) return;
    }

    // 5. Date range check
    if (state.selectedDateRange != null) {
      final now = DateTime.now();
      final start = state.selectedDateRange!.start;
      // Add 1 day to end date to match backend's inclusive query
      final end = state.selectedDateRange!.end.add(const Duration(days: 1));
      if (now.isBefore(start) || now.isAfter(end)) return;
    }

    // 6. Search query check
    if (state.searchQuery.isNotEmpty) {
      final search = state.searchQuery.toLowerCase();
      final email = (event.log['adminEmail'] ?? '').toString().toLowerCase();
      final action = (event.log['action'] ?? '').toString().toLowerCase();
      final targetModel = (event.log['targetModel'] ?? '').toString().toLowerCase();
      final performer = (event.log['adminName'] ?? '').toString().toLowerCase();
      
      bool matchesChanges = false;
      final changes = event.log['changes'];
      if (changes != null && changes is Map) {
        for (final key in ['before', 'after']) {
          final data = changes[key];
          if (data != null && data is Map) {
            final firstName = (data['firstName'] ?? '').toString().toLowerCase();
            final lastName = (data['lastName'] ?? '').toString().toLowerCase();
            final shopName = (data['shopName'] ?? '').toString().toLowerCase();
            final phone = (data['phoneNumber'] ?? data['phone'] ?? '').toString().toLowerCase();
            final mail = (data['email'] ?? '').toString().toLowerCase();
            final name = (data['name'] ?? '').toString().toLowerCase();
            final title = (data['title'] ?? '').toString().toLowerCase();

            if (firstName.contains(search) ||
                lastName.contains(search) ||
                shopName.contains(search) ||
                phone.contains(search) ||
                mail.contains(search) ||
                name.contains(search) ||
                title.contains(search)) {
              matchesChanges = true;
              break;
            }
          }
        }
      }

      if (!email.contains(search) &&
          !action.contains(search) &&
          !targetModel.contains(search) &&
          !performer.contains(search) &&
          !matchesChanges) {
        return;
      }
    }

    // 7. Prevent duplicates (though WS should be reliable)
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
