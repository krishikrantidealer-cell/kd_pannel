import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:kd_pannel/core/network/websocket_service.dart';
import 'package:kd_pannel/features/marketing/data/attribution_repository.dart';
import 'package:kd_pannel/features/marketing/presentation/bloc/attribution_event.dart';
import 'package:kd_pannel/features/marketing/presentation/bloc/attribution_state.dart';

class AttributionBloc extends Bloc<AttributionEvent, AttributionState> {
  final AttributionRepository _repository;
  StreamSubscription? _attrSub;
  StreamSubscription? _leadsSub;
  Timer? _wsDebounce;

  AttributionBloc({AttributionRepository? repository})
      : _repository = repository ?? AttributionRepository(),
        super(const AttributionState()) {
    on<LoadAttributionEvent>(_onLoad);
    on<ChangeAttributionChannelEvent>(_onChangeChannel);
    on<ChangeAttributionDatePresetEvent>(_onChangeDatePreset);
    on<ToggleLiveCampaignsEvent>(_onToggleLive);
    on<SyncMetaSpendEvent>(_onSyncMetaSpend);
    on<AttributionSearchChangedEvent>(_onSearchChanged);
    on<AttributionSortChangedEvent>(_onSortChanged);
    on<ResetAttributionEvent>(_onReset);

    _attrSub = WebSocketService().attributionUpdates.listen((_) => _scheduleWsRefresh());
    _leadsSub = WebSocketService().leadsUpdates.listen((_) => _scheduleWsRefresh());
  }

  void _scheduleWsRefresh() {
    if (state.status != AttributionStatus.loaded) return;
    _wsDebounce?.cancel();
    _wsDebounce = Timer(const Duration(seconds: 2), () {
      if (!isClosed) {
        add(const LoadAttributionEvent(silent: true));
      }
    });
  }

  (String, String) resolveDateStrings([String? presetOverride, DateTimeRange? customOverride]) {
    final preset = presetOverride ?? state.datePreset;
    final customRange = customOverride ?? state.customDateRange;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTime start;
    DateTime end = today;

    switch (preset) {
      case 'today':
        start = today;
        break;
      case 'yesterday':
        start = today.subtract(const Duration(days: 1));
        end = start;
        break;
      case '7d':
        start = today.subtract(const Duration(days: 6));
        break;
      case '30d':
        start = today.subtract(const Duration(days: 29));
        break;
      case 'custom':
        if (customRange != null) {
          start = customRange.start;
          end = customRange.end;
        } else {
          start = DateTime(2024, 1, 1);
        }
        break;
      case 'all':
      default:
        start = DateTime(2024, 1, 1);
        break;
    }

    return (
      DateFormat('yyyy-MM-dd').format(start),
      DateFormat('yyyy-MM-dd').format(end),
    );
  }

  Future<void> _onLoad(
    LoadAttributionEvent event,
    Emitter<AttributionState> emit,
  ) async {
    final hasLoadedData = state.status == AttributionStatus.loaded;
    if (event.silent && hasLoadedData) {
      emit(state.copyWith(isRefreshing: true, clearError: true, clearSyncMessage: true));
    } else if (!hasLoadedData) {
      emit(state.copyWith(status: AttributionStatus.loading, clearError: true, clearSyncMessage: true));
    } else {
      emit(state.copyWith(isRefreshing: true, clearError: true, clearSyncMessage: true));
    }

    try {
      final (startStr, endStr) = resolveDateStrings();
      final data = await _repository.fetchReport(
        startDate: startStr,
        endDate: endStr,
        channel: state.channel,
        liveOnly: state.liveOnly,
      );

      emit(state.copyWith(
        status: AttributionStatus.loaded,
        isRefreshing: false,
        totals: Map<String, dynamic>.from(data['totals'] ?? {}),
        campaigns: List<Map<String, dynamic>>.from(data['campaigns'] ?? []),
        lastSyncedAt: data['lastSyncedAt']?.toString(),
        clearError: true,
      ));
    } catch (e) {
      if (hasLoadedData) {
        emit(state.copyWith(
          isRefreshing: false,
          syncMessage: 'Refresh failed: $e',
          syncWarning: true,
        ));
      } else {
        emit(state.copyWith(
          status: AttributionStatus.error,
          isRefreshing: false,
          errorMessage: e.toString(),
        ));
      }
    }
  }

  Future<void> _onChangeChannel(
    ChangeAttributionChannelEvent event,
    Emitter<AttributionState> emit,
  ) async {
    emit(state.copyWith(channel: event.channel));
    add(const LoadAttributionEvent(silent: true));
  }

  Future<void> _onChangeDatePreset(
    ChangeAttributionDatePresetEvent event,
    Emitter<AttributionState> emit,
  ) async {
    emit(state.copyWith(
      datePreset: event.preset,
      customDateRange: event.customRange ?? state.customDateRange,
    ));
    add(const LoadAttributionEvent(silent: true));
  }

  Future<void> _onToggleLive(
    ToggleLiveCampaignsEvent event,
    Emitter<AttributionState> emit,
  ) async {
    emit(state.copyWith(liveOnly: event.liveOnly));
    add(const LoadAttributionEvent(silent: true));
  }

  Future<void> _onSyncMetaSpend(
    SyncMetaSpendEvent event,
    Emitter<AttributionState> emit,
  ) async {
    emit(state.copyWith(isSyncing: true, clearSyncMessage: true));
    try {
      final (startStr, endStr) = resolveDateStrings();
      final data = await _repository.syncMetaSpend(
        startDate: startStr,
        endDate: endStr,
      );
      final skipped = data['skipped'] == true;
      final msg = skipped
          ? (data['message']?.toString() ?? 'Meta Marketing API token not configured.')
          : 'Synced ${data['synced'] ?? 0} spend rows & ${data['matchedUsers'] ?? 0} CRM leads.';
      emit(state.copyWith(
        isSyncing: false,
        syncMessage: msg,
        syncWarning: skipped,
      ));
      if (!skipped) {
        add(const LoadAttributionEvent(silent: true));
      }
    } catch (e) {
      emit(state.copyWith(
        isSyncing: false,
        syncMessage: 'Sync error: $e',
        syncWarning: true,
      ));
    }
  }

  void _onSearchChanged(
    AttributionSearchChangedEvent event,
    Emitter<AttributionState> emit,
  ) {
    emit(state.copyWith(searchQuery: event.query));
  }

  void _onSortChanged(
    AttributionSortChangedEvent event,
    Emitter<AttributionState> emit,
  ) {
    emit(state.copyWith(sortBy: event.sortBy, sortAscending: event.ascending));
  }

  void _onReset(
    ResetAttributionEvent event,
    Emitter<AttributionState> emit,
  ) {
    _wsDebounce?.cancel();
    emit(const AttributionState());
  }

  @override
  Future<void> close() {
    _wsDebounce?.cancel();
    _attrSub?.cancel();
    _leadsSub?.cancel();
    return super.close();
  }
}
