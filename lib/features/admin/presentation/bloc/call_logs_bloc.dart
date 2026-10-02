import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kd_pannel/core/network/api_client.dart';
import 'package:kd_pannel/core/network/websocket_service.dart';
import 'package:kd_pannel/core/services/telephony_audio_service.dart';
import 'call_logs_event.dart';
import 'call_logs_state.dart';

class CallLogsBloc extends Bloc<CallLogsEvent, CallLogsState> {
  StreamSubscription? _wsSubscription;

  CallLogsBloc() : super(const CallLogsState()) {
    on<FetchCallLogsEvent>(_onFetchCallLogs);
    on<TriggerOutboundCallEvent>(_onTriggerOutboundCall);
    on<EndActiveCallEvent>(_onEndActiveCall);
    on<DismissDispositionModalEvent>(_onDismissDispositionModal);
    on<SaveCallDispositionEvent>(_onSaveCallDisposition);
    on<WebSocketCallUpdateReceivedEvent>(_onWebSocketCallUpdate);
    on<ClearCallLogsMessageEvent>(_onClearMessages);

    _initWebSocket();
  }

  void _initWebSocket() {
    _wsSubscription = WebSocketService().chatUpdates.listen((event) {
      final type = event['type'];
      final data = event['data'];
      if ((type == 'CALL_UPDATE' || type == 'CALL_ENDED') && data != null) {
        add(WebSocketCallUpdateReceivedEvent(data as Map<String, dynamic>));
      }
    });
  }

  @override
  Future<void> close() {
    _wsSubscription?.cancel();
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
      // Fetch agents if not present
      List<dynamic> agents = state.salesAgents;
      if (agents.isEmpty) {
        final agentRes = await ApiClient().get('/users?role=sales');
        if (agentRes.statusCode == 200) {
          final agentBody = jsonDecode(agentRes.body);
          if (agentBody['success'] == true) {
            agents = agentBody['data'] ?? [];
          }
        }
      }

      String endpoint = '/calls/logs?page=${event.page}&limit=25';
      if (event.search.isNotEmpty) {
        endpoint += '&customerPhone=${Uri.encodeComponent(event.search)}';
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

      final res = await ApiClient().get(endpoint);
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
      isCallActive: true,
      activeCustomerPhone: event.customerPhone,
      activeCustomerName: event.customerName,
      showPostCallDisposition: false,
    ));
    try {
      final res = await ApiClient().post('/calls/trigger', {
        'customerPhone': event.customerPhone,
      });

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final logData = body['data']?['callLog'];
        final callLogId = logData?['_id'] ?? logData?['callId'] ?? body['data']?['providerCallId'];

        emit(state.copyWith(
          isTriggeringCall: false,
          isCallActive: true,
          activeCallLogId: callLogId?.toString(),
          successMessage: 'Call connecting via MyOperator...',
        ));
        add(FetchCallLogsEvent(page: 1, type: state.selectedType, status: state.selectedStatus, agentId: state.selectedAgentId));
      } else {
        final body = jsonDecode(res.body);
        emit(state.copyWith(
          isTriggeringCall: false,
          isCallActive: false,
          errorMessage: body['message'] ?? 'Failed to initiate outbound call',
        ));
      }
    } catch (e) {
      debugPrint('[CallLogsBloc] Error triggering call: $e');
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
    final activeLogId = state.activeCallLogId;
    final activePhone = state.activeCustomerPhone;

    emit(state.copyWith(
      isTriggeringCall: false,
      isCallActive: false,
      showPostCallDisposition: activeLogId != null || activePhone != null,
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

    // Determine if this update belongs to our active call
    final customerPhone = (updatedLog['customerPhone'] ?? '').toString().replaceAll(RegExp(r'\D'), '');
    final activePhone = (state.activeCustomerPhone ?? '').replaceAll(RegExp(r'\D'), '');

    final bool isThisActiveCall = state.isCallActive ||
        (state.activeCallLogId != null &&
          (state.activeCallLogId == logId ||
           state.activeCallLogId == updatedLog['callId']?.toString() ||
           state.activeCallLogId == updatedLog['providerCallId']?.toString())) ||
        (activePhone.isNotEmpty && customerPhone.isNotEmpty && (activePhone.contains(customerPhone) || customerPhone.contains(activePhone)));

    final bool isPayloadEnded = updatedLog['isEnded'] == true ||
                                updatedLog['callEnded'] == true ||
                                eventName.contains('end') ||
                                eventName.contains('hung') ||
                                eventName.contains('summary') ||
                                eventName.contains('disconnect') ||
                                eventName.contains('complete');

    final bool isEnded = isPayloadEnded ||
                         callStatus == 'completed' ||
                         callStatus == 'missed' ||
                         callStatus == 'ended' ||
                         callStatus == 'failed' ||
                         callStatus == 'no-answer' ||
                         callStatus == 'disconnected' ||
                         (updatedLog['recordingUrl'] != null && updatedLog['recordingUrl'].toString().isNotEmpty) ||
                         (updatedLog['callSummary'] != null && updatedLog['callSummary'].toString().isNotEmpty && updatedLog['callSummary'] != 'In Progress');

    if (isThisActiveCall && isEnded) {
      TelephonyAudioService().playHangupTone();
      emit(state.copyWith(
        callLogs: currentLogs,
        isCallActive: false,
        isTriggeringCall: false,
        showPostCallDisposition: true,
      ));
    } else {
      emit(state.copyWith(callLogs: currentLogs));
    }
  }

  void _onClearMessages(
    ClearCallLogsMessageEvent event,
    Emitter<CallLogsState> emit,
  ) {
    emit(state.copyWith(clearError: true, clearSuccess: true));
  }
}
