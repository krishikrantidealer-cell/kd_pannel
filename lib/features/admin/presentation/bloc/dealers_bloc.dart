import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/dealers_event.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/dealers_state.dart';
import 'package:kd_pannel/core/network/api_client.dart';
import 'package:kd_pannel/core/services/analytics_service.dart';

import 'package:http/http.dart' as http;

class DealersBloc extends Bloc<DealersEvent, DealersState> {
  DealersBloc() : super(const DealersState()) {
    on<FetchDealersDataEvent>(_onFetchDealersData);
    on<CreateDealerEvent>(_onCreateDealer);
    on<AssignAgentToDealerEvent>(_onAssignAgentToDealer);
    on<BulkAssignAgentToDealersEvent>(_onBulkAssignAgentToDealers);
    on<CreateSalesAgentEvent>(_onCreateSalesAgent);
    on<UpdateDealersFilterEvent>(_onUpdateDealersFilter);
    on<ClearDealersMessageEvent>(_onClearDealersMessage);
    on<ToggleBlockDealerEvent>(_onToggleBlockDealer);
    on<DeleteDealerEvent>(_onDeleteDealer);
    on<UpdateDealerDetailsEvent>(_onUpdateDealerDetails);
    on<ResetDealersEvent>(_onResetDealers);
    on<FetchDealerDetailsEvent>(_onFetchDealerDetails);
    on<FetchDealerOrdersEvent>(_onFetchDealerOrders);
    on<FetchDealerEventsEvent>(_onFetchDealerEvents);
    on<FetchDealerEventsMoreEvent>(_onFetchDealerEventsMore);
  }

  Future<void> _onCreateDealer(
    CreateDealerEvent event,
    Emitter<DealersState> emit,
  ) async {
    emit(state.copyWith(status: DealersStatus.submitting));
    try {
      http.Response res;

      if (event.licenceBytes != null || event.shopBytes != null) {
        final fields = <String, String>{};
        event.dealerData.forEach((k, v) {
          if (v is Map) {
            fields[k] = jsonEncode(v);
          } else if (v != null) {
            fields[k] = v.toString();
          }
        });

        res = await ApiClient().multipartRequest(
          method: 'POST',
          endpoint: '/users/dealer',
          fields: fields,
          filesBuilder: () {
            final files = <http.MultipartFile>[];
            if (event.licenceBytes != null && event.licenceFileName != null) {
              files.add(
                http.MultipartFile.fromBytes(
                  'licenceImage',
                  event.licenceBytes!,
                  filename: event.licenceFileName!,
                ),
              );
            }
            if (event.shopBytes != null && event.shopFileName != null) {
              files.add(
                http.MultipartFile.fromBytes(
                  'shopImage',
                  event.shopBytes!,
                  filename: event.shopFileName!,
                ),
              );
            }
            return files;
          },
        );
      } else {
        res = await ApiClient().post('/users/dealer', event.dealerData);
      }

      final data = jsonDecode(res.body);

      if (res.statusCode == 200 || res.statusCode == 201) {
        if (data['success'] == true) {
          emit(
            state.copyWith(
              status: DealersStatus.success,
              actionSuccessMessage: data['message'] ?? 'Dealer created successfully',
            ),
          );
          add(const FetchDealersDataEvent(forceRefresh: true));
        } else {
          throw Exception(data['message'] ?? 'Failed to create dealer');
        }
      } else {
        throw Exception(data['message'] ?? 'Failed to create dealer: ${res.statusCode}');
      }
    } catch (e) {
      emit(
        state.copyWith(
          status: DealersStatus.failure,
          errorMessage: e.toString().replaceAll('Exception: ', ''),
        ),
      );
    }
  }

  Future<void> _onFetchDealerDetails(
    FetchDealerDetailsEvent event,
    Emitter<DealersState> emit,
  ) async {
    emit(state.copyWith(isLoadingProfile: true));
    try {
      final res = await ApiClient().get('/users/${event.userId}');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['user'] != null) {
          emit(state.copyWith(
            isLoadingProfile: false,
            currentDealerDetails: Map<String, dynamic>.from(data['user']),
          ));
        } else {
          throw Exception(data['message'] ?? 'Failed to load dealer details');
        }
      } else {
        throw Exception('Server returned ${res.statusCode}');
      }
    } catch (e) {
      emit(state.copyWith(
        isLoadingProfile: false,
        errorMessage: 'Error loading dealer: ${e.toString()}',
      ));
    }
  }

  Future<void> _onFetchDealerOrders(
    FetchDealerOrdersEvent event,
    Emitter<DealersState> emit,
  ) async {
    emit(state.copyWith(isLoadingOrders: true));
    try {
      final res = await ApiClient().get(
        '/orders/admin/all?userId=${event.userId}&user=${event.userId}',
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) {
          final List rawOrders = data['orders'] ?? [];
          final filtered = rawOrders
              .map((o) => Map<String, dynamic>.from(o))
              .where(
                (o) =>
                    (o['user'] is Map && o['user']['_id'] == event.userId) ||
                    o['user'] == event.userId,
              )
              .toList();

          emit(state.copyWith(
            isLoadingOrders: false,
            currentDealerOrders: filtered,
          ));
        } else {
          throw Exception(data['message'] ?? 'Failed to load orders');
        }
      } else {
        throw Exception('Server returned ${res.statusCode}');
      }
    } catch (e) {
      emit(state.copyWith(
        isLoadingOrders: false,
        errorMessage: 'Error loading orders: ${e.toString()}',
      ));
    }
  }

  Future<void> _onFetchDealerEvents(
    FetchDealerEventsEvent event,
    Emitter<DealersState> emit,
  ) async {
    if (!event.forceRefresh && state.currentDealerEvents.isNotEmpty) return;

    emit(state.copyWith(
      isLoadingEvents: true,
      currentDealerEvents: [],
      eventsNextCursor: null,
      hasReachedMaxEvents: false,
    ));
    try {
      final result = await AnalyticsService().fetchEventsPaged(
        userEmail: event.identifier,
        limit: 50,
        actorOnly: false,
      );
      final List<Map<String, dynamic>> events =
          (result['events'] as List).cast<Map<String, dynamic>>();
      final String? nextCursor = result['nextCursor'];

      emit(state.copyWith(
        isLoadingEvents: false,
        currentDealerEvents: events,
        eventsNextCursor: nextCursor,
        hasReachedMaxEvents: nextCursor == null,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoadingEvents: false,
        errorMessage: 'Error loading events: ${e.toString()}',
      ));
    }
  }

  Future<void> _onFetchDealerEventsMore(
    FetchDealerEventsMoreEvent event,
    Emitter<DealersState> emit,
  ) async {
    if (state.hasReachedMaxEvents || state.isLoadingMoreEvents) return;

    emit(state.copyWith(isLoadingMoreEvents: true));
    try {
      final result = await AnalyticsService().fetchEventsPaged(
        userEmail: event.identifier,
        limit: 50,
        before: state.eventsNextCursor,
        actorOnly: false,
      );
      final List<Map<String, dynamic>> moreEvents =
          (result['events'] as List).cast<Map<String, dynamic>>();
      final String? nextCursor = result['nextCursor'];

      emit(state.copyWith(
        isLoadingMoreEvents: false,
        currentDealerEvents: List.of(state.currentDealerEvents)
          ..addAll(moreEvents),
        eventsNextCursor: nextCursor,
        hasReachedMaxEvents: nextCursor == null,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoadingMoreEvents: false,
        errorMessage: 'Error loading more events: ${e.toString()}',
      ));
    }
  }

  void _onResetDealers(ResetDealersEvent event, Emitter<DealersState> emit) {
    emit(const DealersState());
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
      if (u['_id'] == event.userId) {
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
          // Log Activity
          AnalyticsService().logEvent('assign_agent', properties: {
            'targetUserId': event.userId,
            'assignedAgentId': event.agentId,
            'details': event.agentId != null 
                ? 'Assigned agent to dealer' 
                : 'Unassigned agent from dealer',
          });
          await AnalyticsService().flush();

          emit(
            state.copyWithMessages(
              status: DealersStatus.success,
              actionSuccessMessage: 'Agent assigned successfully',
            ),
          );
          // Refresh only this dealer
          add(FetchDealerDetailsEvent(event.userId));
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
    int successCount = 0;
    try {
      final client = ApiClient();
      final futures = event.userIds.map((userId) {
        return client.put('/users/$userId/assign-agent', {
          'agentId': event.agentId,
        });
      }).toList();

      final responses = await Future.wait(futures);
      for (final res in responses) {
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          if (data['success'] == true) {
            successCount++;
          }
        }
      }

      // Log Activity
      AnalyticsService().logEvent('bulk_assign_agent', properties: {
        'count': successCount,
        'assignedAgentId': event.agentId,
        'details': 'Bulk assigned agent to $successCount dealers',
      });
      await AnalyticsService().flush();

      emit(state.copyWithMessages(
        status: DealersStatus.success,
        actionSuccessMessage:
            'Agent assigned to $successCount dealers successfully',
      ));
      add(const FetchDealersDataEvent(forceRefresh: true));
    } catch (e) {
      // Log Activity
      AnalyticsService().logEvent('bulk_assign_agent', properties: {
        'count': successCount,
        'assignedAgentId': event.agentId,
        'details': 'Bulk assigned agent to $successCount dealers',
      });
      await AnalyticsService().flush();

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
          // Log Activity
          AnalyticsService().logEvent('create_sales_agent', properties: {
            'firstName': event.firstName,
            'email': event.email,
            'details': 'Created new sales agent: ${event.firstName} ${event.lastName}',
          });
          await AnalyticsService().flush();

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
          // Log Activity
          AnalyticsService().logEvent('toggle_block', properties: {
            'targetUserId': event.userId,
            'details': 'Toggled block status for dealer',
          });
          await AnalyticsService().flush();

          final String msg = data['message'] ?? 'Dealer block status updated';
          emit(
            state.copyWithMessages(
              status: DealersStatus.success,
              actionSuccessMessage: msg,
            ),
          );
          add(FetchDealerDetailsEvent(event.userId));
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
            .where((u) => u['_id'] != event.userId)
            .toList();

    emit(state.copyWith(
      status: DealersStatus.submitting,
      allRawUsers: updatedUsers,
    ));

    try {
      final Map<String, dynamic> targetUser = state.allRawUsers.firstWhere(
        (u) => u['_id'] == event.userId,
        orElse: () => <String, dynamic>{},
      );
      final String dealerName = (targetUser['shopName'] ?? '').toString().isNotEmpty 
          ? targetUser['shopName'] 
          : ((targetUser['firstName'] != null || targetUser['lastName'] != null)
              ? '${targetUser['firstName'] ?? ''} ${targetUser['lastName'] ?? ''}'.trim()
              : 'Dealer');

      final res = await ApiClient().delete('/users/${event.userId}');

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) {
          // Log Activity
          AnalyticsService().logEvent('delete_dealer', properties: {
            'targetUserId': event.userId,
            'details': 'Permanently deleted dealer account: $dealerName',
          });
          await AnalyticsService().flush();

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
        if (event.updateData.containsKey('status') || event.updateData.containsKey('leadStatus')) {
          final val = event.updateData['status'] ?? event.updateData['leadStatus'];
          updatedUser['status'] = val;
          updatedUser['leadStatus'] = val;
        }
        if (event.updateData.containsKey('notes') || event.updateData.containsKey('leadNotes')) {
          final val = event.updateData['notes'] ?? event.updateData['leadNotes'];
          updatedUser['notes'] = val;
          updatedUser['leadNotes'] = val;
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
          // Log Activity: Discern between general edit vs status/note updates
          String eventName = 'edit_dealer';
          String logDetails = 'Updated details for dealer';
          
          if (event.updateData.containsKey('leadStatus') || event.updateData.containsKey('status')) {
            eventName = 'update_dealer_status';
            final status = event.updateData['leadStatus'] ?? event.updateData['status'];
            logDetails = 'Changed dealer status to $status';
          } else if (event.updateData.containsKey('leadNotes') || event.updateData.containsKey('notes')) {
            eventName = 'add_dealer_note';
            logDetails = 'Added follow-up notes to dealer';
          }

          AnalyticsService().logEvent(eventName, properties: {
            'targetUserId': event.userId,
            'details': logDetails,
            'fields': event.updateData.keys.join(', '),
            if (event.updateData.containsKey('leadStatus') || event.updateData.containsKey('status'))
              'newStatus': event.updateData['leadStatus'] ?? event.updateData['status'],
          });
          await AnalyticsService().flush();

          emit(
            state.copyWithMessages(
              status: DealersStatus.success,
              actionSuccessMessage: 'Dealer updated successfully',
            ),
          );
          add(FetchDealerDetailsEvent(event.userId));
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
