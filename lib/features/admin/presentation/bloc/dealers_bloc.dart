import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dealers_event.dart';
import 'dealers_state.dart';
import 'package:kd_pannel/core/network/api_client.dart';

class DealersBloc extends Bloc<DealersEvent, DealersState> {
  DealersBloc() : super(const DealersState()) {
    on<FetchDealersDataEvent>(_onFetchDealersData);
    on<AssignAgentToDealerEvent>(_onAssignAgentToDealer);
    on<BulkAssignAgentToDealersEvent>(_onBulkAssignAgentToDealers);
    on<CreateSalesAgentEvent>(_onCreateSalesAgent);
    on<UpdateDealersFilterEvent>(_onUpdateDealersFilter);
    on<ClearDealersMessageEvent>(_onClearDealersMessage);
    on<ToggleBlockDealerEvent>(_onToggleBlockDealer);
    on<DeleteDealerEvent>(_onDeleteDealer);
    on<UpdateDealerDetailsEvent>(_onUpdateDealerDetails);
  }

  Future<void> _onFetchDealersData(
    FetchDealersDataEvent event,
    Emitter<DealersState> emit,
  ) async {
    emit(state.copyWith(status: DealersStatus.loading));
    try {
      final client = ApiClient();
      final results = await Future.wait([
        client.get('/users'),
        client.get('/users?role=sales'),
        client.get('/orders/admin/all'),
      ]);

      final usersRes = results[0];
      final salesRes = results[1];
      final ordersRes = results[2];

      List<Map<String, dynamic>> users = [];
      List<Map<String, dynamic>> salesAgents = [];
      List<Map<String, dynamic>> orders = [];

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

      if (ordersRes.statusCode == 200) {
        final data = jsonDecode(ordersRes.body);
        if (data['success'] == true) {
          orders = List<Map<String, dynamic>>.from(data['orders'] ?? []);
        } else {
          throw Exception(data['message'] ?? 'Failed to parse orders');
        }
      } else {
        throw Exception('Failed to load orders: ${ordersRes.statusCode}');
      }

      emit(
        state.copyWith(
          status: DealersStatus.success,
          allRawUsers: users,
          salesAgents: salesAgents,
          allRawOrders: orders,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: DealersStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> _onAssignAgentToDealer(
    AssignAgentToDealerEvent event,
    Emitter<DealersState> emit,
  ) async {
    // Optimistic Update
    final updatedUsers = state.allRawUsers.map((u) {
      if (u['_id'] == event.userId || u['id'] == event.userId) {
        final updatedUser = Map<String, dynamic>.from(u);
        final agent = state.salesAgents.firstWhere(
          (a) => a['_id'] == event.agentId,
          orElse: () => <String, dynamic>{},
        );
        updatedUser['assignedAgent'] = agent.isNotEmpty ? agent : null;
        return updatedUser;
      }
      return u;
    }).toList();

    emit(state.copyWith(
      status: DealersStatus.submitting,
      allRawUsers: updatedUsers,
    ));

    try {
      final res = await ApiClient().put('/users/${event.userId}/assign-agent', {
        'agentId': event.agentId,
      });

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) {
          emit(
            state.copyWithMessages(
              status: DealersStatus.success,
              actionSuccessMessage: 'Agent assigned successfully',
            ),
          );
          // Refresh list
          add(const FetchDealersDataEvent(forceRefresh: true));
        } else {
          throw Exception(data['message'] ?? 'Failed to assign agent');
        }
      } else {
        throw Exception('Failed to assign agent: ${res.statusCode}');
      }
    } catch (e) {
      emit(
        state.copyWithMessages(
          status: DealersStatus
              .success, // Keep success status to show existing tables
          errorMessage: e.toString(),
        ),
      );
      add(const FetchDealersDataEvent(forceRefresh: true));
    }
  }

  Future<void> _onBulkAssignAgentToDealers(
    BulkAssignAgentToDealersEvent event,
    Emitter<DealersState> emit,
  ) async {
    emit(state.copyWith(status: DealersStatus.submitting));
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

      emit(state.copyWithMessages(
        status: DealersStatus.success,
        actionSuccessMessage:
            'Agent assigned to $successCount dealers successfully',
      ));
      add(const FetchDealersDataEvent(forceRefresh: true));
    } catch (e) {
      emit(state.copyWithMessages(
        status: DealersStatus.success,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onCreateSalesAgent(
    CreateSalesAgentEvent event,
    Emitter<DealersState> emit,
  ) async {
    emit(state.copyWith(status: DealersStatus.submitting));
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
          emit(
            state.copyWithMessages(
              status: DealersStatus.success,
              actionSuccessMessage: 'Sales agent created successfully',
            ),
          );
          // Refresh list
          add(const FetchDealersDataEvent(forceRefresh: true));
        } else {
          throw Exception(data['message'] ?? 'Failed to create sales agent');
        }
      } else {
        final data = jsonDecode(res.body);
        throw Exception(data['message'] ?? 'Failed to create sales agent');
      }
    } catch (e) {
      emit(
        state.copyWithMessages(
          status: DealersStatus
              .success, // Keep success status to show existing tables
          errorMessage: e.toString(),
        ),
      );
    }
  }

  void _onUpdateDealersFilter(
    UpdateDealersFilterEvent event,
    Emitter<DealersState> emit,
  ) {
    emit(
      state.copyWith(
        searchQuery: event.searchQuery,
        selectedAgent: event.selectedAgent,
        selectedState: event.selectedState,
        selectedTimeframe: event.selectedTimeframe,
        customStartDate: event.customStartDate,
        customEndDate: event.customEndDate,
        showHighValueOnly: event.showHighValueOnly,
        showInactiveOnly: event.showInactiveOnly,
        showActiveOnly: event.showActiveOnly,
        currentPage: event.currentPage,
        pageSize: event.pageSize,
      ),
    );
  }

  void _onClearDealersMessage(
    ClearDealersMessageEvent event,
    Emitter<DealersState> emit,
  ) {
    emit(state.copyWith(errorMessage: null, actionSuccessMessage: null));
  }

  Future<void> _onToggleBlockDealer(
    ToggleBlockDealerEvent event,
    Emitter<DealersState> emit,
  ) async {
    emit(state.copyWith(status: DealersStatus.submitting));
    try {
      final res = await ApiClient().put('/users/${event.userId}/block', {});

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) {
          final String msg = data['message'] ?? 'Dealer block status updated';
          emit(
            state.copyWithMessages(
              status: DealersStatus.success,
              actionSuccessMessage: msg,
            ),
          );
          add(const FetchDealersDataEvent(forceRefresh: true));
        } else {
          throw Exception(data['message'] ?? 'Failed to update block status');
        }
      } else {
        throw Exception('Server returned status code: ${res.statusCode}');
      }
    } catch (e) {
      emit(
        state.copyWithMessages(
          status: DealersStatus.success,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> _onDeleteDealer(
    DeleteDealerEvent event,
    Emitter<DealersState> emit,
  ) async {
    // Optimistic Update
    final updatedUsers =
        state.allRawUsers
            .where((u) => u['_id'] != event.userId && u['id'] != event.userId)
            .toList();

    emit(state.copyWith(
      status: DealersStatus.submitting,
      allRawUsers: updatedUsers,
    ));

    try {
      final res = await ApiClient().delete('/users/${event.userId}');

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) {
          emit(
            state.copyWithMessages(
              status: DealersStatus.success,
              actionSuccessMessage: 'Dealer deleted successfully',
            ),
          );
          add(const FetchDealersDataEvent(forceRefresh: true));
        } else {
          throw Exception(data['message'] ?? 'Failed to delete dealer');
        }
      } else {
        final data = jsonDecode(res.body);
        throw Exception(data['message'] ?? 'Server error');
      }
    } catch (e) {
      emit(
        state.copyWithMessages(
          status: DealersStatus.success,
          errorMessage: e.toString(),
        ),
      );
      add(const FetchDealersDataEvent(forceRefresh: true));
    }
  }

  Future<void> _onUpdateDealerDetails(
    UpdateDealerDetailsEvent event,
    Emitter<DealersState> emit,
  ) async {
    // Optimistic Update: Change the local state immediately for instant feedback
    final updatedUsers = state.allRawUsers.map((u) {
      if (u['_id'] == event.userId || u['id'] == event.userId) {
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
        if (event.updateData.containsKey('leadStatus')) {
          updatedUser['leadStatus'] = event.updateData['leadStatus'];
        }
        if (event.updateData.containsKey('leadNotes')) {
          updatedUser['leadNotes'] = event.updateData['leadNotes'];
        }
        if (event.updateData.containsKey('address')) {
          final existingAddress =
              Map<String, dynamic>.from(updatedUser['address'] ?? {});
          updatedUser['address'] = {
            ...existingAddress,
            ...event.updateData['address'],
          };
        }
        return updatedUser;
      }
      return u;
    }).toList();

    emit(state.copyWith(
      status: DealersStatus.submitting,
      allRawUsers: updatedUsers,
    ));

    try {
      final res = await ApiClient().put('/users/${event.userId}', event.updateData);

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) {
          emit(
            state.copyWithMessages(
              status: DealersStatus.success,
              actionSuccessMessage: 'Dealer updated successfully',
            ),
          );
          add(const FetchDealersDataEvent(forceRefresh: true));
        } else {
          throw Exception(data['message'] ?? 'Failed to update dealer');
        }
      } else {
        final data = jsonDecode(res.body);
        throw Exception(data['message'] ?? 'Server error');
      }
    } catch (e) {
      emit(
        state.copyWithMessages(
          status: DealersStatus.success,
          errorMessage: e.toString(),
        ),
      );
      // Trigger a refresh to revert to server state on failure
      add(const FetchDealersDataEvent(forceRefresh: true));
    }
  }
}
