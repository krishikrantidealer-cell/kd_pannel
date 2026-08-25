import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kd_pannel/core/auth/auth_service.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/leads_event.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/leads_state.dart';
import 'package:kd_pannel/core/network/websocket_service.dart';
import 'package:kd_pannel/core/repositories/notification_repository.dart';
import 'package:kd_pannel/core/repositories/user_repository.dart';
import 'package:kd_pannel/core/services/analytics_service.dart';

class LeadsBloc extends Bloc<LeadsEvent, LeadsState> {
  StreamSubscription? _wsSubscription;
  final UserRepository _userRepo = UserRepository();
  final NotificationRepository _notifRepo = NotificationRepository();

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

    _wsSubscription = WebSocketService().leadsUpdates.listen((_) {
      if (!isClosed) {
        add(const FetchLeadsDataEvent(forceRefresh: true));
      }
    });
  }

  @override
  Future<void> close() {
    _wsSubscription?.cancel();
    return super.close();
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
      final data = await _userRepo.importLeads(event.leads);
      emit(
        state.copyWith(
          status: LeadsStatus.success,
          actionSuccessMessage:
              data['message'] ?? 'Leads imported successfully',
        ),
      );
      add(const FetchLeadsDataEvent(forceRefresh: true));
    } catch (e) {
      String userMessage = e.toString().replaceAll('Exception: ', '');
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
      final user = await _userRepo.getUserById(event.userId);
      emit(
        state.copyWith(
          isLoadingProfile: false,
          currentLeadDetails: user,
        ),
      );
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
      final results = await _userRepo.fetchDealersData(
        forceRefresh: event.forceRefresh,
      );

      emit(
        state.copyWith(
          status: LeadsStatus.success,
          allRawUsers: results['users'] ?? [],
          salesAgents: results['salesAgents'] ?? [],
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
    final targetAgentId = AuthService().isSales
        ? AuthService().currentUserId
        : event.selectedAgentId;

    emit(
      state.copyWith(
        isLoadingDailyStats: true,
        selectedDailyDate: targetDate,
        selectedDailyAgentId: targetAgentId,
        resetDailyAgent: targetAgentId == null,
      ),
    );

    try {
      final stats = await _userRepo.fetchDailyLeadStats(
        targetDate,
        agentId: targetAgentId,
      );
      emit(
        state.copyWith(
          isLoadingDailyStats: false,
          dailyLeadStats: stats,
          selectedDailyAgentId: targetAgentId,
          resetDailyAgent: targetAgentId == null,
        ),
      );
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
      await _userRepo.assignAgent(event.userId, event.agentId);

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
    } catch (e) {
      emit(
        state.copyWithKeepMessages(
          status: LeadsStatus.success,
          errorMessage: e.toString().replaceAll('Exception: ', ''),
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
      int successCount = 0;
      final futures = event.userIds.map((userId) async {
        try {
          await _userRepo.assignAgent(userId, event.agentId);
          successCount++;
        } catch (_) {}
      }).toList();

      await Future.wait(futures);

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
      await _userRepo.createSalesAgent(
        firstName: event.firstName,
        lastName: event.lastName,
        email: event.email,
        phoneNumber: event.phoneNumber,
        password: event.password,
      );

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
    } catch (e) {
      emit(
        state.copyWithKeepMessages(
          status: LeadsStatus.success,
          errorMessage: e.toString().replaceAll('Exception: ', ''),
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
      await _userRepo.updateKycStatus(event.userId, 'verified');

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
        await _notifRepo.sendNotification(
          userId: event.userId,
          title: 'KYC Verification Approved',
          body: 'Congratulations! Your KYC verification has been approved. You are now a dealer.',
        );
      } catch (_) {}

      emit(
        state.copyWith(
          status: LeadsStatus.success,
          actionSuccessMessage: 'KYC Approved! User is now a Dealer.',
        ),
      );
      add(FetchLeadDetailsEvent(event.userId));
    } catch (e) {
      emit(
        state.copyWithKeepMessages(
          status: LeadsStatus.success,
          errorMessage: e.toString().replaceAll('Exception: ', ''),
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
      await _userRepo.updateKycStatus(event.userId, 'rejected', reason: event.reason);

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
        await _notifRepo.sendNotification(
          userId: event.userId,
          title: 'KYC Verification Rejected',
          body: 'Your KYC has been rejected: ${event.reason}',
        );
      } catch (_) {}

      emit(
        state.copyWith(
          status: LeadsStatus.success,
          actionSuccessMessage: 'KYC Rejected successfully.',
        ),
      );
      add(FetchLeadDetailsEvent(event.userId));
    } catch (e) {
      emit(
        state.copyWithKeepMessages(
          status: LeadsStatus.success,
          errorMessage: e.toString().replaceAll('Exception: ', ''),
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
      await _userRepo.toggleBlockUser(event.userId);

      // Log Activity
      AnalyticsService().logEvent(
        'toggle_block',
        properties: {
          'targetUserId': event.userId,
          'details': 'Toggled block status for user',
        },
      );
      await AnalyticsService().flush();

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
          actionSuccessMessage: 'Lead block status updated',
        ),
      );
      add(FetchLeadDetailsEvent(event.userId));
    } catch (e) {
      emit(
        state.copyWithKeepMessages(
          status: LeadsStatus.success,
          errorMessage: e.toString().replaceAll('Exception: ', ''),
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

      await _userRepo.deleteUser(event.userId);

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
    } catch (e) {
      emit(
        state.copyWithKeepMessages(
          status: LeadsStatus.success,
          errorMessage: e.toString().replaceAll('Exception: ', ''),
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
      await _userRepo.updateUserDetails(event.userId, event.updateData);

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
    } catch (e) {
      emit(
        state.copyWithKeepMessages(
          status: LeadsStatus.success,
          errorMessage: e.toString().replaceAll('Exception: ', ''),
        ),
      );
      add(const FetchLeadsDataEvent(forceRefresh: true));
    }
  }

  Future<void> _onAdminSubmitKyc(
    AdminSubmitKycEvent event,
    Emitter<LeadsState> emit,
  ) async {
    emit(state.copyWith(status: LeadsStatus.submitting));

    try {
      await _userRepo.submitAdminKyc(
        userId: event.userId,
        userType: event.userType,
        shopName: event.shopName,
        gstNumber: event.gstNumber,
        licenceImageBytes: event.licenceImageBytes,
        licenceFileName: event.licenceFileName,
        shopImageBytes: event.shopImageBytes,
        shopFileName: event.shopFileName,
      );

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
    } catch (e) {
      emit(
        state.copyWithKeepMessages(
          status: LeadsStatus.success,
          errorMessage: e.toString().replaceAll('Exception: ', ''),
        ),
      );
    }
  }
}
