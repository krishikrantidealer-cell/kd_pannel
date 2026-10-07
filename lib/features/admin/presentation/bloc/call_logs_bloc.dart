import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kd_pannel/core/auth/auth_service.dart';
import 'package:kd_pannel/core/network/api_client.dart';
import 'package:kd_pannel/core/network/websocket_service.dart';
import 'package:kd_pannel/core/services/telephony_audio_service.dart';
import 'call_logs_event.dart';
import 'call_logs_state.dart';

class CallLogsBloc extends Bloc<CallLogsEvent, CallLogsState> {
  StreamSubscription? _wsSubscription;
  Timer? _activeCallPollingTimer;

  CallLogsBloc() : super(const CallLogsState()) {
    on<FetchCallLogsEvent>(_onFetchCallLogs);
    on<TriggerOutboundCallEvent>(_onTriggerOutboundCall);
    on<EndActiveCallEvent>(_onEndActiveCall);
    on<DismissDispositionModalEvent>(_onDismissDispositionModal);
    on<SaveCallDispositionEvent>(_onSaveCallDisposition);
    on<WebSocketCallUpdateReceivedEvent>(_onWebSocketCallUpdate);
    on<DeleteCallLogEvent>(_onDeleteCallLog);
    on<BulkDeleteCallLogsEvent>(_onBulkDeleteCallLogs);
    on<ClearAllCallLogsEvent>(_onClearAllCallLogs);
    on<ClearCallLogsMessageEvent>(_onClearMessages);

    _initWebSocket();
  }

  void _initWebSocket() {
    _wsSubscription?.cancel();
    _wsSubscription = WebSocketService().chatUpdates.listen((event) {
      if (isClosed) return;
      try {
        final Map<String, dynamic> cleanEvent = Map<String, dynamic>.from(event);
        final String? type = cleanEvent['type']?.toString();
        final dynamic rawData = cleanEvent['data'];

        if ((type == 'CALL_UPDATE' || type == 'CALL_ENDED') && rawData != null) {
          if (rawData is Map) {
            final Map<String, dynamic> mapData = Map<String, dynamic>.from(rawData);
            if (mapData.isNotEmpty) {
              add(WebSocketCallUpdateReceivedEvent(mapData));
            }
          }
        } else if (type == 'CALL_DELETED' && rawData != null) {
          final String? deletedId = (rawData is Map ? rawData['id'] : rawData)?.toString();
          if (deletedId != null && deletedId.isNotEmpty) {
            add(DeleteCallLogEvent(deletedId));
          }
        } else if (type == 'CALLS_CLEARED') {
          add(const ClearAllCallLogsEvent());
        }
      } catch (_) {}
    });
  }

  void _startActiveCallPolling(String? callLogId, String? customerPhone) {
    _activeCallPollingTimer?.cancel();
    if (callLogId == null || callLogId.isEmpty || callLogId.startsWith('WEB_')) {
      return;
    }

    _activeCallPollingTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) async {
      if (!state.isCallActive && !state.isTriggeringCall) {
        _activeCallPollingTimer?.cancel();
        return;
      }
      try {
        final res = await ApiClient().get('/calls/logs?limit=5');
        if (res.statusCode == 200) {
          final body = jsonDecode(res.body);
          final List<dynamic> logs = body['data'] ?? [];
          if (logs.isNotEmpty) {
            final match = logs.firstWhere(
              (l) => l['_id']?.toString() == callLogId ||
                     l['callId']?.toString() == callLogId ||
                     l['providerCallId']?.toString() == callLogId,
              orElse: () => null,
            );

            if (match != null) {
              final cleanMatch = jsonDecode(jsonEncode(match));
              final Map<String, dynamic> matchMap = (cleanMatch is Map)
                  ? Map<String, dynamic>.from(cleanMatch)
                  : {};
              final status = (matchMap['status'] ?? '').toString().toLowerCase();
              final isEnded = status == 'ended' ||
                              status == 'completed' ||
                              status == 'missed' ||
                              status == 'failed' ||
                              status == 'busy' ||
                              status == 'rejected' ||
                              status == 'no-answer' ||
                              status == 'canceled' ||
                              status == 'cancelled' ||
                              status == 'disconnected' ||
                              (matchMap['recordingUrl'] != null && matchMap['recordingUrl'].toString().isNotEmpty);
              final isAnswered = status == 'answered';
              if (isEnded) {
                _activeCallPollingTimer?.cancel();
                if (matchMap.isNotEmpty) {
                  add(WebSocketCallUpdateReceivedEvent(matchMap));
                }
              } else if (isAnswered && !state.isCallActive) {
                if (matchMap.isNotEmpty) {
                  add(WebSocketCallUpdateReceivedEvent(matchMap));
                }
              }
            }
          }
        }
      } catch (_) {}
    });
  }

  void _stopActiveCallPolling() {
    _activeCallPollingTimer?.cancel();
    _activeCallPollingTimer = null;
  }

  @override
  Future<void> close() {
    _stopActiveCallPolling();
    _wsSubscription?.cancel();
    _wsDebounceFetchTimer?.cancel();
    return super.close();
  }

  Future<void> _onFetchCallLogs(
    FetchCallLogsEvent event,
    Emitter<CallLogsState> emit,
  ) async {
    emit(state.copyWith(
      isLoading: true,
      page: event.page,
      selectedType: event.type,
      selectedStatus: event.status,
      selectedAgentId: event.agentId,
      clearSelectedAgent: event.agentId == null,
      searchQuery: event.search,
    ));

    try {
const List<Map<String, dynamic>> kTelephonyConfiguredAgents = [
  {
    'name': '👑 Yashraj Singh (Admin)',
    'email': 'admin@krishikranti.com',
    'phone': '+91 7316917246',
    'line': 'Main Account (6ab0de5d51766538)',
    'companyId': '6ab0de5d51766538',
  },
  {
    'name': 'Anshika Gupta',
    'email': 'ebsale08@gmail.com',
    'phone': '+91 7316917267',
    'line': 'Ram Ji Shukla - 2 (6abcea24dbd6a999)',
    'companyId': '6abcea24dbd6a999',
  },
  {
    'name': 'Runa Singh',
    'email': 'essentialsale14@gmail.com',
    'phone': '+91 7316917220',
    'line': 'Ram Ji Shukla - 3 (6abcea4e66e65852)',
    'companyId': '6abcea4e66e65852',
  },
  {
    'name': 'Ajay Yadav',
    'email': 'essentialsale8@gmail.com',
    'phone': '+91 7316917210',
    'line': 'Ram Ji Shukla - 4 (6abcea68a9843790)',
    'companyId': '6abcea68a9843790',
  },
  {
    'name': 'Yogesh Nandwanshi',
    'email': 'sales3.essential@gmail.com',
    'phone': '+91 7316917208',
    'line': 'Ram Ji Shukla - 5 (6abcea80a6fa9438)',
    'companyId': '6abcea80a6fa9438',
  },
  {
    'name': 'Garima Gokulpure',
    'email': 'essentialbiosciences12@gmail.com',
    'phone': '+91 7316917216',
    'line': 'Ram Ji Shukla - 6 (6abceacb44b44323)',
    'companyId': '6abceacb44b44323',
  },
  {
    'name': 'Eram Istiyaque',
    'email': 'sales6.essential@gmail.com',
    'phone': '+91 7316917216',
    'line': 'Ram Ji Shukla - 6 (6abceacb44b44323)',
    'companyId': '6abceacb44b44323',
  },
];

      // Instantaneous agent list fallback (non-blocking)
      List<dynamic> agents = state.salesAgents;
      if (agents.isEmpty) {
        agents = kTelephonyConfiguredAgents.map((cfg) => {
          '_id': cfg['companyId'],
          'firstName': cfg['name'],
          'lastName': '',
          'name': cfg['name'],
          'email': cfg['email'],
          'phoneNumber': cfg['phone'],
          'accountName': cfg['line'],
          'companyId': cfg['companyId'],
        }).toList();
      }

      String endpoint = '/calls/logs?page=${event.page}&limit=25';
      if (event.search.isNotEmpty) {
        endpoint += '&search=${Uri.encodeComponent(event.search)}';
      }
      if (event.type != 'all') {
        endpoint += '&type=${event.type}';
      }
      if (event.status != 'all') {
        endpoint += '&status=${event.status}';
      }
      if (event.agentId != null && event.agentId!.isNotEmpty) {
        endpoint += '&agentId=${event.agentId}';
      }

      // Concurrently fetch call logs and agent registry in parallel
      final List<Future<dynamic>> parallelTasks = [
        ApiClient().get(endpoint),
        if (state.salesAgents.isEmpty) ApiClient().get('/calls/agents'),
      ];

      final results = await Future.wait(parallelTasks);
      final res = results[0];

      if (results.length > 1) {
        try {
          final agentRes = results[1];
          if (agentRes.statusCode == 200) {
            final agentBody = jsonDecode(agentRes.body);
            if (agentBody['success'] == true && agentBody['agents'] != null && (agentBody['agents'] as List).isNotEmpty) {
              agents = agentBody['agents'] as List<dynamic>;
            }
          }
        } catch (_) {}
      }
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true) {
          final List<dynamic> logs = body['data'] ?? [];
          final int total = body['pagination']?['total'] ?? logs.length;
          final int totalPages = body['pagination']?['pages'] ?? 1;

          final metrics = body['metrics'] ?? {};
          final int totalCalls = metrics['totalCalls'] ?? total;
          final int inbound = metrics['inboundCount'] ?? logs.where((l) => l['type'] == 'inbound').length;
          final int outbound = metrics['outboundCount'] ?? logs.where((l) => l['type'] == 'outbound').length;
          final int missed = metrics['missedCount'] ?? logs.where((l) => l['status'] == 'missed').length;
          final int totalSecs = metrics['totalSeconds'] ?? 0;
          final List<dynamic> leaderboard = metrics['leaderboard'] ?? [];

          emit(state.copyWith(
            status: CallLogsStatus.loaded,
            callLogs: logs,
            salesAgents: agents,
            totalCount: total,
            totalPages: totalPages,
            isLoading: false,
            totalCalls: totalCalls,
            inboundCount: inbound,
            outboundCount: outbound,
            missedCount: missed,
            totalTalkTimeSeconds: totalSecs,
            leaderboard: leaderboard,
          ));
          return;
        }
      }

      emit(state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to fetch call logs',
      ));
    } catch (e) {
      debugPrint('[CallLogsBloc] Error fetching call logs: $e');
      emit(state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onTriggerOutboundCall(
    TriggerOutboundCallEvent event,
    Emitter<CallLogsState> emit,
  ) async {
    emit(state.copyWith(
      isTriggeringCall: true,
      isCallActive: false,
      activeCustomerPhone: event.customerPhone,
      activeCustomerName: event.customerName,
      showPostCallDisposition: false,
    ));
    try {
      final res = await ApiClient().post('/calls/trigger', {
        'customerPhone': event.customerPhone,
        'callMode': event.callMode,
      });
      debugPrint('[CallLogsBloc] /calls/trigger status: ${res.statusCode}, body: ${res.body}');

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final logData = body['data']?['callLog'];
        final callLogId = logData?['_id'] ?? logData?['callId'] ?? body['data']?['providerCallId'];

        _startActiveCallPolling(callLogId?.toString(), event.customerPhone);
        emit(state.copyWith(
          isTriggeringCall: true,
          isCallActive: false,
          activeCallLogId: callLogId?.toString(),
          successMessage: '📱 Call dispatched! Ringing customer and agent...',
        ));
        add(FetchCallLogsEvent(page: 1, type: state.selectedType, status: state.selectedStatus, agentId: state.selectedAgentId));
      } else {
        final body = jsonDecode(res.body);
        debugPrint('[CallLogsBloc] Call trigger failed: ${body['message']}');
        emit(state.copyWith(
          isTriggeringCall: false,
          isCallActive: false,
          errorMessage: body['message'] ?? 'Failed to initiate outbound call',
        ));
      }
    } catch (e) {
      debugPrint('[CallLogsBloc] Error triggering call exception: $e');
      emit(state.copyWith(
        isTriggeringCall: false,
        isCallActive: false,
        errorMessage: 'Network error initiating call',
      ));
    }
  }

  Future<void> _onEndActiveCall(
    EndActiveCallEvent event,
    Emitter<CallLogsState> emit,
  ) async {
    _stopActiveCallPolling();
    final activeLogId = state.activeCallLogId;
    final activePhone = state.activeCustomerPhone;

    emit(state.copyWith(
      isTriggeringCall: false,
      isCallActive: false,
      showPostCallDisposition: (activePhone != null && activePhone.isNotEmpty) || (activeLogId != null && activeLogId.isNotEmpty),
    ));

    try {
      await ApiClient().post('/calls/end', {
        if (activeLogId != null) 'callLogId': activeLogId,
        if (activePhone != null) 'customerPhone': activePhone,
        'durationSeconds': event.durationSeconds,
      });
    } catch (e) {
      debugPrint('[CallLogsBloc] Error ending active call: $e');
    }
  }

  void _onDismissDispositionModal(
    DismissDispositionModalEvent event,
    Emitter<CallLogsState> emit,
  ) {
    emit(state.copyWith(
      showPostCallDisposition: false,
      clearActiveCallLogId: true,
    ));
  }

  Future<void> _onSaveCallDisposition(
    SaveCallDispositionEvent event,
    Emitter<CallLogsState> emit,
  ) async {
    emit(state.copyWith(isSavingDisposition: true));
    try {
      final res = await ApiClient().post('/calls/disposition', {
        'callLogId': event.callLogId,
        'userDisposition': event.userDisposition,
        'followUpDate': event.followUpDate?.toIso8601String(),
        'followUpNote': event.followUpNote,
        'notes': event.notes,
      });

      if (res.statusCode == 200) {
        emit(state.copyWith(
          isSavingDisposition: false,
          showPostCallDisposition: false,
          clearActiveCallLogId: true,
          successMessage: 'Call disposition saved and synced to customer timeline',
        ));
        add(FetchCallLogsEvent(page: state.page, type: state.selectedType, status: state.selectedStatus, agentId: state.selectedAgentId));
      } else {
        final body = jsonDecode(res.body);
        emit(state.copyWith(
          isSavingDisposition: false,
          errorMessage: body['message'] ?? 'Failed to save disposition',
        ));
      }
    } catch (e) {
      debugPrint('[CallLogsBloc] Error saving disposition: $e');
      emit(state.copyWith(
        isSavingDisposition: false,
        errorMessage: 'Network error saving disposition',
      ));
    }
  }

  Timer? _wsDebounceFetchTimer;

  void _onWebSocketCallUpdate(
    WebSocketCallUpdateReceivedEvent event,
    Emitter<CallLogsState> emit,
  ) {
    final updatedLog = event.callLog;
    final logId = updatedLog['_id']?.toString();
    final callStatus = (updatedLog['status'] ?? '').toString().toLowerCase();
    final eventName = (updatedLog['event'] ?? '').toString().toLowerCase();

    final List<dynamic> currentLogs = List.from(state.callLogs);
    if (logId != null) {
      final index = currentLogs.indexWhere((l) => l['_id']?.toString() == logId);
      if (index != -1) {
        currentLogs[index] = updatedLog;
      } else {
        currentLogs.insert(0, updatedLog);
      }
    }

    // Recompute fast live metrics from current state
    final totalCalls = currentLogs.length > state.totalCalls ? currentLogs.length : state.totalCalls;
    final inbound = currentLogs.where((l) => (l['direction'] ?? l['type']) == 'inbound').length;
    final outbound = currentLogs.where((l) => (l['direction'] ?? l['type']) == 'outbound').length;
    final missed = currentLogs.where((l) {
      final s = (l['status'] ?? '').toString().toLowerCase();
      return s == 'missed' || s == 'no-answer';
    }).length;

    final currentUserId = AuthService().currentUserId;
    final currentUserEmail = AuthService().currentUserEmail?.toLowerCase();
    final currentUserPhone = AuthService().currentUserPhone?.replaceAll(RegExp(r'\D'), '').replaceFirst(RegExp(r'^91'), '');
    final currentAgentWhatsApp = AuthService().agentWhatsAppNumber?.replaceAll(RegExp(r'\D'), '').replaceFirst(RegExp(r'^91'), '');
    final bool isAdmin = AuthService().currentUserRole == UserRole.admin;

    final eventAgentId = (updatedLog['agentId'] is Map)
        ? updatedLog['agentId']['_id']?.toString()
        : updatedLog['agentId']?.toString();
    final eventAgentEmail = (updatedLog['agentId'] is Map)
        ? updatedLog['agentId']['email']?.toString().toLowerCase()
        : null;
    final eventAgentPhone = (updatedLog['agentPhone'] ?? '').toString().replaceAll(RegExp(r'\D'), '').replaceFirst(RegExp(r'^91'), '');

    final rawCustomer = updatedLog['customerPhone'] ??
                        updatedLog['caller_number_raw'] ??
                        updatedLog['cli'] ??
                        updatedLog['caller_id'] ??
                        updatedLog['customer_number'] ??
                        updatedLog['number'] ??
                        updatedLog['phone'] ??
                        updatedLog['destination_number'] ??
                        updatedLog['to'] ??
                        '';
    final customerPhone = rawCustomer.toString().replaceAll(RegExp(r'\D'), '').replaceFirst(RegExp(r'^91'), '');
    final activePhone = (state.activeCustomerPhone ?? '').replaceAll(RegExp(r'\D'), '').replaceFirst(RegExp(r'^91'), '');
    final providerCallId = (updatedLog['providerCallId'] ?? '').toString();
    final callId = (updatedLog['callId'] ?? '').toString();

    bool isThisActiveCall = false;
    if (state.activeCallLogId != null && state.activeCallLogId!.isNotEmpty) {
      if (state.activeCallLogId == logId ||
          state.activeCallLogId == providerCallId ||
          state.activeCallLogId == callId) {
        isThisActiveCall = true;
      }
    } else if (state.isCallActive || state.isTriggeringCall) {
      if (activePhone.isNotEmpty && customerPhone.isNotEmpty &&
          (activePhone.endsWith(customerPhone) || customerPhone.endsWith(activePhone))) {
        isThisActiveCall = true;
      }
    }

    bool isAgentMatch = false;
    if (isThisActiveCall) {
      isAgentMatch = true;
    } else if (currentUserId != null && eventAgentId != null && currentUserId == eventAgentId) {
      isAgentMatch = true;
    } else if (currentUserEmail != null && eventAgentEmail != null && currentUserEmail == eventAgentEmail) {
      isAgentMatch = true;
    } else if (currentUserPhone != null && currentUserPhone.isNotEmpty && eventAgentPhone.isNotEmpty &&
               (currentUserPhone.endsWith(eventAgentPhone) || eventAgentPhone.endsWith(currentUserPhone))) {
      isAgentMatch = true;
    } else if (currentAgentWhatsApp != null && currentAgentWhatsApp.isNotEmpty && eventAgentPhone.isNotEmpty &&
               (currentAgentWhatsApp.endsWith(eventAgentPhone) || eventAgentPhone.endsWith(currentAgentWhatsApp))) {
      isAgentMatch = true;
    } else if (state.isCallActive || state.isTriggeringCall) {
      isAgentMatch = true;
    } else if (isAdmin) {
      final adminDids = ['7316917246', '07316917246'];
      if (adminDids.any((d) => eventAgentPhone.endsWith(d) || d.endsWith(eventAgentPhone))) {
        isAgentMatch = true;
      }
    }

    final bool isPayloadEnded = updatedLog['isEnded'] == true ||
                                updatedLog['callEnded'] == true ||
                                eventName.contains('end') ||
                                eventName.contains('hung') ||
                                eventName.contains('summary') ||
                                eventName.contains('disconnect') ||
                                eventName.contains('miss') ||
                                eventName.contains('busy') ||
                                eventName.contains('reject') ||
                                eventName.contains('cancel') ||
                                eventName.contains('complete');

    final bool isEnded = isPayloadEnded ||
                         callStatus == 'completed' ||
                         callStatus == 'missed' ||
                         callStatus == 'ended' ||
                         callStatus == 'failed' ||
                         callStatus == 'no-answer' ||
                         callStatus == 'busy' ||
                         callStatus == 'rejected' ||
                         callStatus == 'canceled' ||
                         callStatus == 'cancelled' ||
                         callStatus == 'hangup' ||
                         callStatus == 'disconnected' ||
                         (updatedLog['recordingUrl'] != null && updatedLog['recordingUrl'].toString().isNotEmpty) ||
                         (updatedLog['callSummary'] != null && updatedLog['callSummary'].toString().isNotEmpty && updatedLog['callSummary'] != 'In Progress');

    final bool isAnswered = (callStatus == 'answered' || eventName == 'call.answered' || eventName == 'answered') && !isEnded;

    if (isThisActiveCall && isAnswered && !state.isCallActive) {
      TelephonyAudioService().stopDialingTone();
      emit(state.copyWith(
        callLogs: currentLogs,
        totalCalls: totalCalls,
        inboundCount: inbound > state.inboundCount ? inbound : state.inboundCount,
        outboundCount: outbound > state.outboundCount ? outbound : state.outboundCount,
        missedCount: missed > state.missedCount ? missed : state.missedCount,
        isTriggeringCall: false,
        isCallActive: true,
      ));
      return;
    }

    if ((isThisActiveCall || isAgentMatch) && isEnded) {
      _stopActiveCallPolling();
      final String? userDisposition = updatedLog['userDisposition']?.toString();
      final bool hasDisposition = userDisposition != null && userDisposition.isNotEmpty && userDisposition != 'null';

      final customerName = (updatedLog['contactId'] is Map)
          ? updatedLog['contactId']['name']?.toString()
          : (updatedLog['customerName']?.toString() ?? (updatedLog['name']?.toString() ?? state.activeCustomerName));

      final effectivePhone = customerPhone.isNotEmpty ? customerPhone : state.activeCustomerPhone;

      emit(state.copyWith(
        callLogs: currentLogs,
        totalCalls: totalCalls,
        inboundCount: inbound > state.inboundCount ? inbound : state.inboundCount,
        outboundCount: outbound > state.outboundCount ? outbound : state.outboundCount,
        missedCount: missed > state.missedCount ? missed : state.missedCount,
        isCallActive: false,
        isTriggeringCall: false,
        activeCallLogId: (logId != null && logId.isNotEmpty) ? logId : (providerCallId.isNotEmpty ? providerCallId : callId),
        activeCustomerPhone: effectivePhone,
        activeCustomerName: customerName,
        showPostCallDisposition: !hasDisposition && (effectivePhone != null && effectivePhone.isNotEmpty),
      ));
    } else {
      emit(state.copyWith(
        callLogs: currentLogs,
        totalCalls: totalCalls,
        inboundCount: inbound > state.inboundCount ? inbound : state.inboundCount,
        outboundCount: outbound > state.outboundCount ? outbound : state.outboundCount,
        missedCount: missed > state.missedCount ? missed : state.missedCount,
      ));
    }

    // Schedule debounced full state sync in background
    if (state.page == 1) {
      _wsDebounceFetchTimer?.cancel();
      _wsDebounceFetchTimer = Timer(const Duration(milliseconds: 1500), () {
        add(FetchCallLogsEvent(
          page: 1,
          type: state.selectedType,
          status: state.selectedStatus,
          agentId: state.selectedAgentId,
          search: state.searchQuery,
        ));
      });
    }
  }

  Future<void> _onDeleteCallLog(
    DeleteCallLogEvent event,
    Emitter<CallLogsState> emit,
  ) async {
    final updatedLogs = state.callLogs.where((l) {
      final id = l['_id']?.toString() ?? l['callId']?.toString() ?? l['providerCallId']?.toString();
      return id != event.callLogId;
    }).toList();

    emit(state.copyWith(
      callLogs: updatedLogs,
      totalCount: state.totalCount > 0 ? state.totalCount - 1 : 0,
    ));

    try {
      await ApiClient().delete('/calls/${event.callLogId}');
    } catch (e) {
      debugPrint('[CallLogsBloc] Delete call log error: $e');
    }
  }

  Future<void> _onBulkDeleteCallLogs(
    BulkDeleteCallLogsEvent event,
    Emitter<CallLogsState> emit,
  ) async {
    if (event.callLogIds.isEmpty) return;
    final idsSet = event.callLogIds.toSet();
    final updatedLogs = state.callLogs.where((l) {
      final id = l['_id']?.toString() ?? l['callId']?.toString() ?? l['providerCallId']?.toString();
      return !idsSet.contains(id);
    }).toList();

    final deletedCount = state.callLogs.length - updatedLogs.length;
    emit(state.copyWith(
      callLogs: updatedLogs,
      totalCount: state.totalCount >= deletedCount ? state.totalCount - deletedCount : 0,
    ));

    try {
      await ApiClient().post('/calls/bulk-delete', {
        'ids': event.callLogIds,
        'callLogIds': event.callLogIds,
      });
    } catch (e) {
      debugPrint('[CallLogsBloc] Bulk delete call logs error: $e');
    }
  }

  Future<void> _onClearAllCallLogs(
    ClearAllCallLogsEvent event,
    Emitter<CallLogsState> emit,
  ) async {
    emit(state.copyWith(
      callLogs: [],
      totalCount: 0,
      totalCalls: 0,
      inboundCount: 0,
      outboundCount: 0,
      missedCount: 0,
    ));

    try {
      await ApiClient().post('/calls/clear', {});
    } catch (e) {
      debugPrint('[CallLogsBloc] Clear call logs error: $e');
      try {
        await ApiClient().delete('/calls/clear');
      } catch (_) {}
    }
  }

  void _onClearMessages(
    ClearCallLogsMessageEvent event,
    Emitter<CallLogsState> emit,
  ) {
    emit(state.copyWith(clearError: true, clearSuccess: true));
  }
}
