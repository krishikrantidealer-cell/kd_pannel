import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kd_pannel/core/auth/auth_service.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/leads_event.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/leads_state.dart';
import 'package:kd_pannel/core/network/api_client.dart';
import 'package:kd_pannel/core/services/analytics_service.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

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
    on<DeleteLeadEvent>(_onDeleteLead);
    on<UpdateLeadDetailsEvent>(_onUpdateLeadDetails);
    on<AdminSubmitKycEvent>(_onAdminSubmitKyc);
    on<ResetLeadsEvent>(_onResetLeads);
    on<FetchLeadDetailsEvent>(_onFetchLeadDetails);
    on<FetchLeadEventsEvent>(_onFetchLeadEvents);
    on<ImportLeadsEvent>(_onImportLeads);
    on<FetchDailyLeadStatsEvent>(_onFetchDailyLeadStats);
    on<ToggleAnalyticsViewModeEvent>(_onToggleAnalyticsViewMode);
  }

  void _onToggleAnalyticsViewMode(
    ToggleAnalyticsViewModeEvent event,
    Emitter<LeadsState> emit,
  ) {
    emit(state.copyWith(analyticsViewMode: event.mode));
  }

  Future<void> _onImportLeads(
    ImportLeadsEvent event,
    Emitter<LeadsState> emit,
  ) async {
    emit(state.copyWith(status: LeadsStatus.submitting));
    try {
      final res = await ApiClient().post('/users/bulk', {'users': event.leads});

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) {
          emit(
            state.copyWith(
              status: LeadsStatus.success,
              actionSuccessMessage:
                  data['message'] ?? 'Leads imported successfully',
            ),
          );
          add(const FetchLeadsDataEvent(forceRefresh: true));
        } else {
          throw Exception(data['message'] ?? 'Failed to import leads');
        }
      } else {
        // Handle non-JSON responses (like HTML 404/500 pages)
        if (res.body.contains('<!DOCTYPE html>') ||
            res.body.contains('<html>')) {
          throw Exception(
            'Server returned an HTML error (${res.statusCode}). Please ensure the backend is running and the route is deployed.',
          );
        }
        final data = jsonDecode(res.body);
        throw Exception(
          data['message'] ?? 'Failed to import leads: ${res.statusCode}',
        );
      }
    } catch (e) {
      String userMessage = e.toString().replaceAll('Exception: ', '');
      if (e is FormatException) {
        userMessage =
            'Invalid server response format. The backend might be returning an HTML error page instead of JSON.';
      }
      emit(
        state.copyWithKeepMessages(
          status: LeadsStatus.failure,
          errorMessage: userMessage,
        ),
      );
    }
  }

  Future<void> _onFetchLeadDetails(
    FetchLeadDetailsEvent event,
    Emitter<LeadsState> emit,
  ) async {
    emit(state.copyWith(isLoadingProfile: true));
    try {
      final res = await ApiClient().get('/users/${event.userId}');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['user'] != null) {
          emit(
            state.copyWith(
              isLoadingProfile: false,
              currentLeadDetails: Map<String, dynamic>.from(data['user']),
            ),
          );
        } else {
          throw Exception(data['message'] ?? 'Failed to load lead details');
        }
      } else {
        throw Exception('Server returned ${res.statusCode}');
      }
    } catch (e) {
      emit(
        state.copyWith(
          isLoadingProfile: false,
          errorMessage: 'Error loading lead: ${e.toString()}',
        ),
      );
    }
  }

  Future<void> _onFetchLeadEvents(
    FetchLeadEventsEvent event,
    Emitter<LeadsState> emit,
  ) async {
    emit(state.copyWith(isLoadingEvents: true));
    try {
      final events = await AnalyticsService().fetchEvents(
        userEmail: event.identifier,
        actorOnly: false,
      );
      emit(state.copyWith(isLoadingEvents: false, currentLeadEvents: events));
    } catch (e) {
      emit(
        state.copyWith(
          isLoadingEvents: false,
          errorMessage: 'Error loading events: ${e.toString()}',
        ),
      );
    }
  }

  void _onResetLeads(ResetLeadsEvent event, Emitter<LeadsState> emit) {
    emit(const LeadsState());
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

      emit(
        state.copyWith(
          status: LeadsStatus.success,
          allRawUsers: users,
          salesAgents: salesAgents,
        ),
      );
      add(
        FetchDailyLeadStatsEvent(
          selectedDate: state.selectedDailyDate,
          selectedAgentId:
              state.selectedDailyAgentId ??
              (AuthService().isSales ? AuthService().currentUserId : null),
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(status: LeadsStatus.failure, errorMessage: e.toString()),
      );
    }
  }

  Future<void> _onFetchDailyLeadStats(
    FetchDailyLeadStatsEvent event,
    Emitter<LeadsState> emit,
  ) async {
    final targetDate =
        event.selectedDate ?? state.selectedDailyDate ?? DateTime.now();
    final targetAgentId =
        event.selectedAgentId ??
        state.selectedDailyAgentId ??
        (AuthService().isSales ? AuthService().currentUserId : null);

    emit(
      state.copyWith(
        isLoadingDailyStats: true,
        selectedDailyDate: targetDate,
        selectedDailyAgentId: targetAgentId,
      ),
    );

    try {
      final dateStr =
          "${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}";
      String url = '/users/daily-lead-stats?date=$dateStr';
      if (targetAgentId != null && targetAgentId.isNotEmpty) {
        url += '&agentId=$targetAgentId';
      }

      final res = await ApiClient().get(url);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) {
          emit(
            state.copyWith(
              isLoadingDailyStats: false,
              dailyLeadStats: Map<String, dynamic>.from(data),
            ),
          );
        } else {
          throw Exception(
            data['message'] ?? 'Failed to fetch daily lead stats',
          );
        }
      } else {
        throw Exception('Server returned ${res.statusCode}');
      }
    } catch (e) {
      emit(state.copyWith(isLoadingDailyStats: false));
    }
  }

  Future<void> _onAssignAgentToLead(
    AssignAgentToLeadEvent event,
    Emitter<LeadsState> emit,
  ) async {
    // Optimistic Update
    final updatedUsers = state.allRawUsers.map((u) {
      if (u['_id'] == event.userId) {
        final updatedUser = Map<String, dynamic>.from(u);
        final agent = state.salesAgents.firstWhere(
          (a) => a['_id'] == event.agentId,
          orElse: () => <String, dynamic>{},
        );
        updatedUser['assignedAgent'] = agent.isNotEmpty ? agent : null;

        // Optimistically update status to 'new' if it was 'prospect'
        final currentStatus =
            (updatedUser['status'] ?? updatedUser['leadStatus'] ?? 'prospect')
                .toString()
                .toLowerCase();
        if (event.agentId != null && currentStatus == 'prospect') {
          updatedUser['status'] = 'new';
          updatedUser['leadStatus'] = 'new';
        }

        return updatedUser;
      }
      return u;
    }).toList();

    emit(
      state.copyWith(status: LeadsStatus.submitting, allRawUsers: updatedUsers),
    );

    try {
      final res = await ApiClient().put('/users/${event.userId}/assign-agent', {
        'agentId': event.agentId,
      });

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) {
          // Log Activity
          AnalyticsService().logEvent(
            'assign_agent',
            properties: {
              'targetUserId': event.userId,
              'assignedAgentId': event.agentId,
              'details': event.agentId != null
                  ? 'Assigned agent to user'
                  : 'Unassigned agent from user',
            },
          );
          await AnalyticsService().flush();

          emit(
            state.copyWith(
              status: LeadsStatus.success,
              actionSuccessMessage: event.agentId != null
                  ? 'Agent assigned successfully'
                  : 'Agent unassigned',
            ),
          );
          add(FetchLeadDetailsEvent(event.userId));
          // Refresh daily stats so banner count updates immediately
          add(
            FetchDailyLeadStatsEvent(
              selectedDate: state.selectedDailyDate,
              selectedAgentId: state.selectedDailyAgentId,
            ),
          );
        } else {
          throw Exception(data['message'] ?? 'Failed to assign agent');
        }
      } else {
        throw Exception('Failed to assign agent: ${res.statusCode}');
      }
    } catch (e) {
      emit(
        state.copyWithKeepMessages(
          status: LeadsStatus.success,
          errorMessage: e.toString(),
        ),
      );
      add(const FetchLeadsDataEvent(forceRefresh: true));
    }
  }

  Future<void> _onBulkAssignAgentToLeads(
    BulkAssignAgentToLeadsEvent event,
    Emitter<LeadsState> emit,
  ) async {
    // Optimistic Update
    final updatedUsers = state.allRawUsers.map((u) {
      if (event.userIds.contains(u['_id'])) {
        final updatedUser = Map<String, dynamic>.from(u);
        final agent = state.salesAgents.firstWhere(
          (a) => a['_id'] == event.agentId,
          orElse: () => <String, dynamic>{},
        );
        updatedUser['assignedAgent'] = agent.isNotEmpty ? agent : null;

        // Optimistically update status to 'new' if it was 'prospect'
        final currentStatus =
            (updatedUser['status'] ?? updatedUser['leadStatus'] ?? 'prospect')
                .toString()
                .toLowerCase();
        if (event.agentId != null && currentStatus == 'prospect') {
          updatedUser['status'] = 'new';
          updatedUser['leadStatus'] = 'new';
        }
        return updatedUser;
      }
      return u;
    }).toList();

    emit(
      state.copyWith(status: LeadsStatus.submitting, allRawUsers: updatedUsers),
    );

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

      // Log Activity
      AnalyticsService().logEvent(
        'bulk_assign_agent',
        properties: {
          'count': successCount,
          'assignedAgentId': event.agentId,
          'details': 'Bulk assigned agent to $successCount leads',
        },
      );
      await AnalyticsService().flush();

      emit(
        state.copyWith(
          status: LeadsStatus.success,
          actionSuccessMessage:
              'Agent assigned to $successCount leads successfully',
        ),
      );
      add(const FetchLeadsDataEvent(forceRefresh: true));
      // Refresh daily stats so banner count updates immediately
      add(
        FetchDailyLeadStatsEvent(
          selectedDate: state.selectedDailyDate,
          selectedAgentId: state.selectedDailyAgentId,
        ),
      );
    } catch (e) {
      emit(
        state.copyWithKeepMessages(
          status: LeadsStatus.success,
          errorMessage: e.toString(),
        ),
      );
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
        'monthlyTarget': event.monthlyTarget ?? 500000.0,
      });

      if (res.statusCode == 201) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) {
          // Log Activity
          AnalyticsService().logEvent(
            'create_sales_agent',
            properties: {
              'email': event.email.trim(),
              'details': 'Created new sales agent: ${event.firstName}',
            },
          );
          await AnalyticsService().flush();

          emit(
            state.copyWith(
              status: LeadsStatus.success,
              actionSuccessMessage: 'Sales agent created successfully',
            ),
          );
          add(const FetchLeadsDataEvent(forceRefresh: true));
        } else {
          throw Exception(data['message'] ?? 'Failed to create sales agent');
        }
      } else {
        final data = jsonDecode(res.body);
        throw Exception(data['message'] ?? 'Failed to create sales agent');
      }
    } catch (e) {
      // Revert optimistic update by triggering a fresh data fetch from server
      add(const FetchLeadsDataEvent(forceRefresh: true));

      emit(
        state.copyWithKeepMessages(
          status: LeadsStatus.failure,
          errorMessage: 'Verification failed: ${e.toString()}',
        ),
      );
    }
  }

  Future<void> _onVerifyKYC(
    VerifyKYCEvent event,
    Emitter<LeadsState> emit,
  ) async {
    // Optimistic Update
    final updatedUsers = state.allRawUsers.map((u) {
      if (u['_id'] == event.userId) {
        final updatedUser = Map<String, dynamic>.from(u);
        updatedUser['kycStatus'] = 'verified';
        return updatedUser;
      }
      return u;
    }).toList();

    emit(
      state.copyWith(status: LeadsStatus.submitting, allRawUsers: updatedUsers),
    );

    try {
      final res = await ApiClient().put('/users/${event.userId}/kyc', {
        'status': 'verified',
      });

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) {
          // Log Activity
          AnalyticsService().logEvent(
            'kyc_verified',
            properties: {
              'targetUserId': event.userId,
              'details': 'Verified KYC for user',
            },
          );
          await AnalyticsService().flush();

          try {
            await ApiClient().post('/users/notifications/send', {
              'recipient': event.userId,
              'userId': event.userId,
              'title': 'KYC Verification Approved',
              'body':
                  'Congratulations! Your KYC verification has been approved. You are now a dealer.',
              'type': 'kyc_approval',
            });
          } catch (e) {
            // Log notification failure but don't fail the verification flow
          }

          emit(
            state.copyWith(
              status: LeadsStatus.success,
              actionSuccessMessage: 'KYC Approved! User is now a Dealer.',
            ),
          );
          add(FetchLeadDetailsEvent(event.userId));
        } else {
          throw Exception(data['message'] ?? 'Failed to verify KYC');
        }
      } else {
        throw Exception('Server returned status code: ${res.statusCode}');
      }
    } catch (e) {
      emit(
        state.copyWithKeepMessages(
          status: LeadsStatus.success,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> _onRejectKYC(
    RejectKYCEvent event,
    Emitter<LeadsState> emit,
  ) async {
    // Optimistic Update
    final updatedUsers = state.allRawUsers.map((u) {
      if (u['_id'] == event.userId) {
        final updatedUser = Map<String, dynamic>.from(u);
        updatedUser['kycStatus'] = 'rejected';
        return updatedUser;
      }
      return u;
    }).toList();

    emit(
      state.copyWith(status: LeadsStatus.submitting, allRawUsers: updatedUsers),
    );

    try {
      final res = await ApiClient().put('/users/${event.userId}/kyc', {
        'status': 'rejected',
        'reason': event.reason,
      });

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) {
          // Log Activity
          AnalyticsService().logEvent(
            'kyc_rejected',
            properties: {
              'targetUserId': event.userId,
              'reason': event.reason,
              'details': 'Rejected KYC for user: ${event.reason}',
            },
          );
          await AnalyticsService().flush();

          try {
            await ApiClient().post('/users/notifications/send', {
              'recipient': event.userId,
              'userId': event.userId,
              'title': 'KYC Verification Rejected',
              'body': 'Your KYC has been rejected: ${event.reason}',
              'type': 'kyc_rejection',
            });
          } catch (e) {
            // Log notification failure but don't fail the rejection flow
          }

          emit(
            state.copyWith(
              status: LeadsStatus.success,
              actionSuccessMessage: 'KYC Rejected successfully.',
            ),
          );
          add(FetchLeadDetailsEvent(event.userId));
        } else {
          throw Exception(data['message'] ?? 'Failed to reject KYC');
        }
      } else {
        throw Exception('Server returned status code: ${res.statusCode}');
      }
    } catch (e) {
      emit(
        state.copyWithKeepMessages(
          status: LeadsStatus.success,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  void _onUpdateLeadsFilter(
    UpdateLeadsFilterEvent event,
    Emitter<LeadsState> emit,
  ) {
    if (event.resetRange) {
      emit(
        state.copyWithResetRange(
          searchQuery: event.searchQuery,
          selectedState: event.selectedState,
          selectedTimeframe: event.selectedTimeframe,
          selectedFilterChip: event.selectedFilterChip,
          currentPage: event.currentPage,
          pageSize: event.pageSize,
        ),
      );
    } else {
      emit(
        state.copyWith(
          searchQuery: event.searchQuery,
          selectedState: event.selectedState,
          selectedTimeframe: event.selectedTimeframe,
          selectedRange: event.selectedRange,
          selectedFilterChip: event.selectedFilterChip,
          currentPage: event.currentPage,
          pageSize: event.pageSize,
        ),
      );
    }
  }

  void _onClearLeadsMessage(
    ClearLeadsMessageEvent event,
    Emitter<LeadsState> emit,
  ) {
    emit(state.copyWith(errorMessage: null, actionSuccessMessage: null));
  }

  Future<void> _onToggleBlockLead(
    ToggleBlockLeadEvent event,
    Emitter<LeadsState> emit,
  ) async {
    // Optimistic Update
    final updatedUsers = state.allRawUsers.map((u) {
      if (u['_id'] == event.userId) {
        final updatedUser = Map<String, dynamic>.from(u);
        final bool currentBlocked = updatedUser['isBlocked'] ?? false;
        updatedUser['isBlocked'] = !currentBlocked;
        return updatedUser;
      }
      return u;
    }).toList();

    emit(
      state.copyWith(status: LeadsStatus.submitting, allRawUsers: updatedUsers),
    );

    try {
      final res = await ApiClient().put('/users/${event.userId}/block', {});

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) {
          // Log Activity
          AnalyticsService().logEvent(
            'toggle_block',
            properties: {
              'targetUserId': event.userId,
              'details': 'Toggled block status for user',
            },
          );
          await AnalyticsService().flush();

          final String msg = data['message'] ?? 'Lead block status updated';
          final updatedRawUsers = state.allRawUsers.map((user) {
            if (user['_id'] == event.userId) {
              final updatedUser = Map<String, dynamic>.from(user);
              final bool currentBlocked = updatedUser['isBlocked'] ?? false;
              updatedUser['isBlocked'] = !currentBlocked;
              return updatedUser;
            }
            return user;
          }).toList();

          emit(
            state.copyWith(
              status: LeadsStatus.success,
              allRawUsers: updatedRawUsers,
              actionSuccessMessage: msg,
            ),
          );
          add(FetchLeadDetailsEvent(event.userId));
        } else {
          throw Exception(data['message'] ?? 'Failed to update block status');
        }
      } else {
        throw Exception('Server returned status code: ${res.statusCode}');
      }
    } catch (e) {
      emit(
        state.copyWithKeepMessages(
          status: LeadsStatus.success,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> _onDeleteLead(
    DeleteLeadEvent event,
    Emitter<LeadsState> emit,
  ) async {
    // Optimistic Update
    final updatedUsers = state.allRawUsers
        .where((u) => u['_id'] != event.userId)
        .toList();

    emit(
      state.copyWith(status: LeadsStatus.submitting, allRawUsers: updatedUsers),
    );

    try {
      final Map<String, dynamic> targetUser = state.allRawUsers.firstWhere(
        (u) => u['_id'] == event.userId,
        orElse: () => <String, dynamic>{},
      );
      final String leadName =
          (targetUser['firstName'] != null || targetUser['lastName'] != null)
          ? '${targetUser['firstName'] ?? ''} ${targetUser['lastName'] ?? ''}'
                .trim()
          : (targetUser['shopName'] ?? targetUser['phoneNumber'] ?? 'Lead');

      final res = await ApiClient().delete('/users/${event.userId}');

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) {
          // Log Activity
          AnalyticsService().logEvent(
            'delete_lead',
            properties: {
              'targetUserId': event.userId,
              'details': 'Permanently deleted lead account: $leadName',
            },
          );
          await AnalyticsService().flush();

          emit(
            state.copyWith(
              status: LeadsStatus.success,
              actionSuccessMessage: 'Lead deleted successfully',
            ),
          );
          add(const FetchLeadsDataEvent(forceRefresh: true));
        } else {
          throw Exception(data['message'] ?? 'Failed to delete lead');
        }
      } else {
        final data = jsonDecode(res.body);
        throw Exception(data['message'] ?? 'Server error');
      }
    } catch (e) {
      emit(
        state.copyWithKeepMessages(
          status: LeadsStatus.success,
          errorMessage: e.toString(),
        ),
      );
      add(const FetchLeadsDataEvent(forceRefresh: true));
    }
  }

  Future<void> _onUpdateLeadDetails(
    UpdateLeadDetailsEvent event,
    Emitter<LeadsState> emit,
  ) async {
    // Optimistic Update: Change the local state immediately for instant feedback
    final updatedUsers = state.allRawUsers.map((u) {
      if (u['_id'] == event.userId) {
        final updatedUser = Map<String, dynamic>.from(u);
        if (event.updateData.containsKey('firstName')) {
          updatedUser['firstName'] = event.updateData['firstName'];
        }
        if (event.updateData.containsKey('lastName')) {
          updatedUser['lastName'] = event.updateData['lastName'];
        }
        if (event.updateData.containsKey('shopName')) {
          updatedUser['shopName'] = event.updateData['shopName'];
        }
        if (event.updateData.containsKey('gstNumber')) {
          updatedUser['gstNumber'] = event.updateData['gstNumber'];
        }
        if (event.updateData.containsKey('status') ||
            event.updateData.containsKey('leadStatus')) {
          final val =
              event.updateData['status'] ?? event.updateData['leadStatus'];
          updatedUser['status'] = val;
          updatedUser['leadStatus'] = val;
        }
        if (event.updateData.containsKey('notes') ||
            event.updateData.containsKey('leadNotes')) {
          final val =
              event.updateData['notes'] ?? event.updateData['leadNotes'];
          updatedUser['notes'] = val;
          updatedUser['leadNotes'] = val;
        }
        if (event.updateData.containsKey('address')) {
          final existingAddress = Map<String, dynamic>.from(
            updatedUser['address'] ?? {},
          );
          updatedUser['address'] = {
            ...existingAddress,
            ...event.updateData['address'],
          };
        }
        if (event.updateData.containsKey('monthlyTarget')) {
          updatedUser['monthlyTarget'] = event.updateData['monthlyTarget'];
        }
        return updatedUser;
      }
      return u;
    }).toList();

    emit(
      state.copyWith(status: LeadsStatus.submitting, allRawUsers: updatedUsers),
    );

    try {
      final res = await ApiClient().put(
        '/users/${event.userId}',
        event.updateData,
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) {
          // Log Activity: Discern between general edit vs status/note updates
          String eventName = 'edit_lead';
          String logDetails = 'Updated details for lead';

          if (event.updateData.containsKey('leadStatus') ||
              event.updateData.containsKey('status')) {
            eventName = 'update_lead_status';
            final status =
                event.updateData['leadStatus'] ?? event.updateData['status'];
            logDetails = 'Changed lead status to $status';
          } else if (event.updateData.containsKey('leadNotes') ||
              event.updateData.containsKey('notes')) {
            eventName = 'add_lead_note';
            logDetails = 'Added follow-up notes to lead';
          }

          final String firstName = event.updateData['firstName'] ?? '';
          final String lastName = event.updateData['lastName'] ?? '';
          final String fullName = '$firstName $lastName'.trim();

          AnalyticsService().logEvent(
            eventName,
            properties: {
              'targetUserId': event.userId,
              'details':
                  '$logDetails${fullName.isNotEmpty ? ': $fullName' : ''}',
              'fields': event.updateData.keys.join(', '),
              if (event.updateData.containsKey('leadStatus') ||
                  event.updateData.containsKey('status'))
                'newStatus':
                    event.updateData['leadStatus'] ??
                    event.updateData['status'],
            },
          );
          await AnalyticsService().flush();

          emit(
            state.copyWith(
              status: LeadsStatus.success,
              actionSuccessMessage: 'Lead updated successfully',
            ),
          );
          add(FetchLeadDetailsEvent(event.userId));
        } else {
          throw Exception(data['message'] ?? 'Failed to update lead');
        }
      } else {
        final data = jsonDecode(res.body);
        throw Exception(data['message'] ?? 'Server error');
      }
    } catch (e) {
      emit(
        state.copyWithKeepMessages(
          status: LeadsStatus.success,
          errorMessage: e.toString(),
        ),
      );
      // Trigger a refresh to revert to server state on failure
      add(const FetchLeadsDataEvent(forceRefresh: true));
    }
  }

  Future<void> _onAdminSubmitKyc(
    AdminSubmitKycEvent event,
    Emitter<LeadsState> emit,
  ) async {
    emit(state.copyWith(status: LeadsStatus.submitting));

    try {
      final client = ApiClient();
      final res = await client.multipartRequest(
        method: 'POST',
        endpoint: '/users/${event.userId}/kyc',
        fields: {
          'userType': event.userType,
          'shopName': event.shopName,
          'gstNumber': event.gstNumber ?? '',
        },
        filesBuilder: () {
          final files = <http.MultipartFile>[];
          if (event.licenceImageBytes != null &&
              event.licenceFileName != null) {
            files.add(
              http.MultipartFile.fromBytes(
                'licenceImage',
                event.licenceImageBytes!,
                filename: event.licenceFileName!,
                contentType: _getMediaType(event.licenceFileName!),
              ),
            );
          }
          if (event.shopImageBytes != null && event.shopFileName != null) {
            files.add(
              http.MultipartFile.fromBytes(
                'shopImage',
                event.shopImageBytes!,
                filename: event.shopFileName!,
                contentType: _getMediaType(event.shopFileName!),
              ),
            );
          }
          return files;
        },
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) {
          // Log Activity
          AnalyticsService().logEvent(
            'admin_kyc_submit',
            properties: {
              'targetUserId': event.userId,
              'details': 'Submitted KYC on behalf of user: ${event.shopName}',
            },
          );
          await AnalyticsService().flush();

          emit(
            state.copyWith(
              status: LeadsStatus.success,
              actionSuccessMessage: 'KYC documents uploaded successfully',
            ),
          );
          add(FetchLeadDetailsEvent(event.userId));
        } else {
          throw Exception(data['message'] ?? 'Failed to upload KYC');
        }
      } else {
        final data = jsonDecode(res.body);
        throw Exception(data['message'] ?? 'Server error: ${res.statusCode}');
      }
    } catch (e) {
      emit(
        state.copyWithKeepMessages(
          status: LeadsStatus.success,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  MediaType _getMediaType(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    switch (ext) {
      case 'png':
        return MediaType('image', 'png');
      case 'jpg':
      case 'jpeg':
        return MediaType('image', 'jpeg');
      case 'gif':
        return MediaType('image', 'gif');
      case 'webp':
        return MediaType('image', 'webp');
      case 'pdf':
        return MediaType('application', 'pdf');
      default:
        return MediaType('application', 'octet-stream');
    }
  }
}
