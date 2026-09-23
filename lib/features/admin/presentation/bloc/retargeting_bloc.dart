import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kd_pannel/core/network/api_client.dart';
import 'retargeting_event.dart';
import 'retargeting_state.dart';

class RetargetingBloc extends Bloc<RetargetingEvent, RetargetingState> {
  RetargetingBloc() : super(const RetargetingState()) {
    on<FetchCohortsEvent>(_onFetchCohorts);
    on<SendWhatsAppCohortBroadcastEvent>(_onSendBroadcast);
    on<ClearRetargetingMessageEvent>(_onClearMessages);
  }

  Future<void> _onFetchCohorts(
    FetchCohortsEvent event,
    Emitter<RetargetingState> emit,
  ) async {
    emit(state.copyWith(
      isLoading: true,
      selectedCohort: event.cohort,
      selectedLanguage: event.language,
    ));

    try {
      final endpoint =
          '/retargeting/cohorts?cohort=${event.cohort}&language=${event.language}';
      final res = await ApiClient().get(endpoint);

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true) {
          final List<dynamic> leads = body['data'] ?? [];
          final int count = body['totalCount'] ?? leads.length;

          emit(state.copyWith(
            status: RetargetingStatus.loaded,
            leads: leads,
            totalCount: count,
            isLoading: false,
          ));
          return;
        }
      }

      emit(state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to fetch retargeting cohort leads',
      ));
    } catch (e) {
      debugPrint('[RetargetingBloc] Error fetching cohorts: $e');
      emit(state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onSendBroadcast(
    SendWhatsAppCohortBroadcastEvent event,
    Emitter<RetargetingState> emit,
  ) async {
    emit(state.copyWith(isBroadcasting: true));
    try {
      final res = await ApiClient().post('/retargeting/broadcast', {
        'userIds': event.userIds,
        'templateName': event.templateName,
        'defaultLanguage': event.defaultLanguage,
        'bodyValues': event.bodyValues,
      });

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true) {
          final int sent = body['successCount'] ?? 0;
          final int failed = body['failCount'] ?? 0;

          emit(state.copyWith(
            isBroadcasting: false,
            broadcastSuccessCount: sent,
            broadcastFailCount: failed,
            successMessage:
                'WhatsApp Broadcast Complete: $sent sent, $failed failed via MyOperator WABA',
          ));
          return;
        }
      }

      final body = jsonDecode(res.body);
      emit(state.copyWith(
        isBroadcasting: false,
        errorMessage: body['message'] ?? 'Failed to execute WhatsApp broadcast',
      ));
    } catch (e) {
      debugPrint('[RetargetingBloc] Error sending broadcast: $e');
      emit(state.copyWith(
        isBroadcasting: false,
        errorMessage: 'Network error executing broadcast',
      ));
    }
  }

  void _onClearMessages(
    ClearRetargetingMessageEvent event,
    Emitter<RetargetingState> emit,
  ) {
    emit(state.copyWith(clearError: true, clearSuccess: true));
  }
}
