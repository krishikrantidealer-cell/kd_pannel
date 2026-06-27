import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'leads_event.dart';
import 'leads_state.dart';
import 'package:kd_pannel/core/network/api_client.dart';
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
      status: LeadsStatus.submitting,
      allRawUsers: updatedUsers,
    ));

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
      add(const FetchLeadsDataEvent(forceRefresh: true));
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
          final updatedRawUsers = state.allRawUsers.map((user) {
            if (user['_id'] == event.userId || user['id'] == event.userId) {
              final updatedUser = Map<String, dynamic>.from(user);
              final bool currentBlocked = updatedUser['isBlocked'] ?? false;
              updatedUser['isBlocked'] = !currentBlocked;
              return updatedUser;
            }
            return user;
          }).toList();

          emit(state.copyWith(
            status: LeadsStatus.success,
            allRawUsers: updatedRawUsers,
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

  Future<void> _onDeleteLead(
    DeleteLeadEvent event,
    Emitter<LeadsState> emit,
  ) async {
    // Optimistic Update
    final updatedUsers =
        state.allRawUsers
            .where((u) => u['_id'] != event.userId && u['id'] != event.userId)
            .toList();

    emit(state.copyWith(
      status: LeadsStatus.submitting,
      allRawUsers: updatedUsers,
    ));

    try {
      final res = await ApiClient().delete('/users/${event.userId}');

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) {
          emit(state.copyWith(
            status: LeadsStatus.success,
            actionSuccessMessage: 'Lead deleted successfully',
          ));
          add(const FetchLeadsDataEvent(forceRefresh: true));
        } else {
          throw Exception(data['message'] ?? 'Failed to delete lead');
        }
      } else {
        final data = jsonDecode(res.body);
        throw Exception(data['message'] ?? 'Server error');
      }
    } catch (e) {
      emit(state.copyWithKeepMessages(
        status: LeadsStatus.success,
        errorMessage: e.toString(),
      ));
      add(const FetchLeadsDataEvent(forceRefresh: true));
    }
  }

  Future<void> _onUpdateLeadDetails(
    UpdateLeadDetailsEvent event,
    Emitter<LeadsState> emit,
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
          final existingAddress = Map<String, dynamic>.from(updatedUser['address'] ?? {});
          updatedUser['address'] = {...existingAddress, ...event.updateData['address']};
        }
        return updatedUser;
      }
      return u;
    }).toList();

    emit(state.copyWith(
      status: LeadsStatus.submitting,
      allRawUsers: updatedUsers,
    ));

    try {
      final res = await ApiClient().put('/users/${event.userId}', event.updateData);

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) {
          emit(state.copyWith(
            status: LeadsStatus.success,
            actionSuccessMessage: 'Lead updated successfully',
          ));
          add(const FetchLeadsDataEvent(forceRefresh: true));
        } else {
          throw Exception(data['message'] ?? 'Failed to update lead');
        }
      } else {
        final data = jsonDecode(res.body);
        throw Exception(data['message'] ?? 'Server error');
      }
    } catch (e) {
      emit(state.copyWithKeepMessages(
        status: LeadsStatus.success,
        errorMessage: e.toString(),
      ));
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
        filesBuilder: () => [
          http.MultipartFile.fromBytes(
            'licenceImage',
            event.licenceImageBytes,
            filename: event.licenceFileName,
            contentType: _getMediaType(event.licenceFileName),
          ),
          http.MultipartFile.fromBytes(
            'shopImage',
            event.shopImageBytes,
            filename: event.shopFileName,
            contentType: _getMediaType(event.shopFileName),
          ),
        ],
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) {
          emit(state.copyWith(
            status: LeadsStatus.success,
            actionSuccessMessage: 'KYC documents uploaded successfully',
          ));
          add(const FetchLeadsDataEvent(forceRefresh: true));
        } else {
          throw Exception(data['message'] ?? 'Failed to upload KYC');
        }
      } else {
        final data = jsonDecode(res.body);
        throw Exception(data['message'] ?? 'Server error: ${res.statusCode}');
      }
    } catch (e) {
      emit(state.copyWithKeepMessages(
        status: LeadsStatus.success,
        errorMessage: e.toString(),
      ));
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
