import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'leads_event.dart';
import 'leads_state.dart';
import 'package:kd_pannel/core/network/api_client.dart';

class LeadsBloc extends Bloc<LeadsEvent, LeadsState> {
  LeadsBloc() : super(const LeadsState()) {
    on<FetchLeadsDataEvent>(_onFetchLeadsData);
    on<AssignAgentToLeadEvent>(_onAssignAgentToLead);
    on<BulkAssignAgentToLeadsEvent>(_onBulkAssignAgentToLeads);
    on<CreateSalesAgentFromLeadsEvent>(_onCreateSalesAgent);
    on<VerifyKYCEvent>(_onVerifyKYC);
    on<RejectKYCEvent>(_onRejectKYC);
    on<UpdateLeadsFilterEvent>(_onUpdateLeadsFilter);
    on<ClearLeadsMessageEvent>(_onClearLeadsMessage);
    on<ToggleBlockLeadEvent>(_onToggleBlockLead);
  }

  Future<void> _onFetchLeadsData(
    FetchLeadsDataEvent event,
    Emitter<LeadsState> emit,
  ) async {
    emit(state.copyWith(status: LeadsStatus.loading));
    try {
      final client = ApiClient();
      final results = await Future.wait([
        client.get('/users'),
        client.get('/users?role=sales'),
      ]);

      final usersRes = results[0];
      final salesRes = results[1];

      List<Map<String, dynamic>> users = [];
      List<Map<String, dynamic>> salesAgents = [];

      if (usersRes.statusCode == 200) {
        final data = jsonDecode(usersRes.body);
        if (data['success'] == true) {
          users = List<Map<String, dynamic>>.from(data['users'] ?? []);
        } else {
          throw Exception(data['message'] ?? 'Failed to parse users');
        }
      } else {
        throw Exception('Failed to load users: ${usersRes.statusCode}');
      }

      if (salesRes.statusCode == 200) {
        final data = jsonDecode(salesRes.body);
        if (data['success'] == true) {
          salesAgents = List<Map<String, dynamic>>.from(data['users'] ?? []);
        } else {
          throw Exception(data['message'] ?? 'Failed to parse sales agents');
        }
      } else {
        throw Exception('Failed to load sales agents: ${salesRes.statusCode}');
      }

      emit(state.copyWith(
        status: LeadsStatus.success,
        allRawUsers: users,
        salesAgents: salesAgents,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: LeadsStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onAssignAgentToLead(
    AssignAgentToLeadEvent event,
    Emitter<LeadsState> emit,
  ) async {
    emit(state.copyWith(status: LeadsStatus.submitting));
    try {
      final res = await ApiClient().put('/users/${event.userId}/assign-agent', {
        'agentId': event.agentId,
      });

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) {
          emit(state.copyWith(
            status: LeadsStatus.success,
            actionSuccessMessage: 'Agent assigned successfully',
          ));
          add(const FetchLeadsDataEvent(forceRefresh: true));
        } else {
          throw Exception(data['message'] ?? 'Failed to assign agent');
        }
      } else {
        throw Exception('Failed to assign agent: ${res.statusCode}');
      }
    } catch (e) {
      emit(state.copyWithKeepMessages(
        status: LeadsStatus.success,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onBulkAssignAgentToLeads(
    BulkAssignAgentToLeadsEvent event,
    Emitter<LeadsState> emit,
  ) async {
    emit(state.copyWith(status: LeadsStatus.submitting));
    try {
      final client = ApiClient();
      final futures = event.userIds.map((userId) {
        return client.put('/users/$userId/assign-agent', {
          'agentId': event.agentId,
        });
      }).toList();

      final responses = await Future.wait(futures);
      int successCount = 0;
      for (final res in responses) {
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          if (data['success'] == true) {
            successCount++;
          }
        }
      }

      emit(state.copyWith(
        status: LeadsStatus.success,
        actionSuccessMessage: 'Agent assigned to $successCount leads successfully',
      ));
      add(const FetchLeadsDataEvent(forceRefresh: true));
    } catch (e) {
      emit(state.copyWithKeepMessages(
        status: LeadsStatus.success,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onCreateSalesAgent(
    CreateSalesAgentFromLeadsEvent event,
    Emitter<LeadsState> emit,
  ) async {
    emit(state.copyWith(status: LeadsStatus.submitting));
    try {
      final res = await ApiClient().post('/users/sales', {
        'firstName': event.firstName.trim(),
        'lastName': event.lastName.trim(),
        'email': event.email.trim(),
        'phoneNumber': event.phoneNumber.trim(),
        'password': event.password,
      });

      if (res.statusCode == 201) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) {
          emit(state.copyWith(
            status: LeadsStatus.success,
            actionSuccessMessage: 'Sales agent created successfully',
          ));
          add(const FetchLeadsDataEvent(forceRefresh: true));
        } else {
          throw Exception(data['message'] ?? 'Failed to create sales agent');
        }
      } else {
        final data = jsonDecode(res.body);
        throw Exception(data['message'] ?? 'Failed to create sales agent');
      }
    } catch (e) {
      emit(state.copyWithKeepMessages(
        status: LeadsStatus.success,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onVerifyKYC(
    VerifyKYCEvent event,
    Emitter<LeadsState> emit,
  ) async {
    emit(state.copyWith(status: LeadsStatus.submitting));
    try {
      final res = await ApiClient().put(
        '/users/${event.userId}/kyc',
        {'status': 'verified'},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) {
          try {
            await ApiClient().post('/notifications', {
              'recipient': event.userId,
              'userId': event.userId,
              'title': 'KYC Verification Approved',
              'body': 'Congratulations! Your KYC verification has been approved. You are now a dealer.',
              'type': 'kyc_approval',
            });
          } catch (e) {
            // Log notification failure but don't fail the verification flow
          }

          emit(state.copyWith(
            status: LeadsStatus.success,
            actionSuccessMessage: 'KYC Approved! User is now a Dealer.',
          ));
          add(const FetchLeadsDataEvent(forceRefresh: true));
        } else {
          throw Exception(data['message'] ?? 'Failed to verify KYC');
        }
      } else {
        throw Exception('Server returned status code: ${res.statusCode}');
      }
    } catch (e) {
      emit(state.copyWithKeepMessages(
        status: LeadsStatus.success,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onRejectKYC(
    RejectKYCEvent event,
    Emitter<LeadsState> emit,
  ) async {
    emit(state.copyWith(status: LeadsStatus.submitting));
    try {
      final res = await ApiClient().put(
        '/users/${event.userId}/kyc',
        {'status': 'rejected', 'reason': event.reason},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) {
          try {
            await ApiClient().post('/notifications', {
              'recipient': event.userId,
              'userId': event.userId,
              'title': 'KYC Verification Rejected',
              'body': 'Your KYC has been rejected: ${event.reason}',
              'type': 'kyc_rejection',
            });
          } catch (e) {
            // Log notification failure but don't fail the rejection flow
          }

          emit(state.copyWith(
            status: LeadsStatus.success,
            actionSuccessMessage: 'KYC Rejected successfully.',
          ));
          add(const FetchLeadsDataEvent(forceRefresh: true));
        } else {
          throw Exception(data['message'] ?? 'Failed to reject KYC');
        }
      } else {
        throw Exception('Server returned status code: ${res.statusCode}');
      }
    } catch (e) {
      emit(state.copyWithKeepMessages(
        status: LeadsStatus.success,
        errorMessage: e.toString(),
      ));
    }
  }

  void _onUpdateLeadsFilter(
    UpdateLeadsFilterEvent event,
    Emitter<LeadsState> emit,
  ) {
    if (event.resetRange) {
      emit(state.copyWithResetRange(
        searchQuery: event.searchQuery,
        selectedTimeframe: event.selectedTimeframe,
        selectedFilterChip: event.selectedFilterChip,
        currentPage: event.currentPage,
        pageSize: event.pageSize,
      ));
    } else {
      emit(state.copyWith(
        searchQuery: event.searchQuery,
        selectedTimeframe: event.selectedTimeframe,
        selectedRange: event.selectedRange,
        selectedFilterChip: event.selectedFilterChip,
        currentPage: event.currentPage,
        pageSize: event.pageSize,
      ));
    }
  }

  void _onClearLeadsMessage(
    ClearLeadsMessageEvent event,
    Emitter<LeadsState> emit,
  ) {
    emit(state.copyWith(
      errorMessage: null,
      actionSuccessMessage: null,
    ));
  }

  Future<void> _onToggleBlockLead(
    ToggleBlockLeadEvent event,
    Emitter<LeadsState> emit,
  ) async {
    emit(state.copyWith(status: LeadsStatus.submitting));
    try {
      final res = await ApiClient().put('/users/${event.userId}/block', {});

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) {
          final String msg = data['message'] ?? 'Lead block status updated';
          emit(state.copyWith(
            status: LeadsStatus.success,
            actionSuccessMessage: msg,
          ));
          add(const FetchLeadsDataEvent(forceRefresh: true));
        } else {
          throw Exception(data['message'] ?? 'Failed to update block status');
        }
      } else {
        throw Exception('Server returned status code: ${res.statusCode}');
      }
    } catch (e) {
      emit(state.copyWithKeepMessages(
        status: LeadsStatus.success,
        errorMessage: e.toString(),
      ));
    }
  }
}
