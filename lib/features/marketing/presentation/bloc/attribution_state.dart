import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

enum AttributionStatus { initial, loading, loaded, error }

class AttributionState extends Equatable {
  final AttributionStatus status;
  final bool isRefreshing;
  final bool isSyncing;
  final String? syncMessage;
  final bool syncWarning;
  final String channel;
  final String datePreset;
  final DateTimeRange? customDateRange;
  final bool liveOnly;
  final String searchQuery;
  final String sortBy;
  final bool sortAscending;
  final Map<String, dynamic> totals;
  final List<Map<String, dynamic>> campaigns;
  final String? lastSyncedAt;
  final String? errorMessage;

  const AttributionState({
    this.status = AttributionStatus.initial,
    this.isRefreshing = false,
    this.isSyncing = false,
    this.syncMessage,
    this.syncWarning = false,
    this.channel = 'all',
    this.datePreset = 'all',
    this.customDateRange,
    this.liveOnly = true,
    this.searchQuery = '',
    this.sortBy = 'spend',
    this.sortAscending = false,
    this.totals = const {},
    this.campaigns = const [],
    this.lastSyncedAt,
    this.errorMessage,
  });

  List<Map<String, dynamic>> get visibleCampaigns {
    final q = searchQuery.trim().toLowerCase();
    final filtered = q.isEmpty
        ? List<Map<String, dynamic>>.from(campaigns)
        : campaigns.where((c) {
            final name = (c['campaignName'] ?? c['campaignId'] ?? '').toString().toLowerCase();
            final ch = (c['channel'] ?? '').toString().toLowerCase();
            return name.contains(q) || ch.contains(q);
          }).toList();

    filtered.sort((a, b) {
      int cmp;
      if (sortBy == 'campaignName') {
        cmp = (a['campaignName'] ?? '').toString().compareTo((b['campaignName'] ?? '').toString());
      } else {
        final av = num.tryParse('${a[sortBy] ?? 0}') ?? 0;
        final bv = num.tryParse('${b[sortBy] ?? 0}') ?? 0;
        cmp = av.compareTo(bv);
      }
      return sortAscending ? cmp : -cmp;
    });
    return filtered;
  }

  AttributionState copyWith({
    AttributionStatus? status,
    bool? isRefreshing,
    bool? isSyncing,
    String? syncMessage,
    bool clearSyncMessage = false,
    bool? syncWarning,
    String? channel,
    String? datePreset,
    DateTimeRange? customDateRange,
    bool? liveOnly,
    String? searchQuery,
    String? sortBy,
    bool? sortAscending,
    Map<String, dynamic>? totals,
    List<Map<String, dynamic>>? campaigns,
    String? lastSyncedAt,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AttributionState(
      status: status ?? this.status,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isSyncing: isSyncing ?? this.isSyncing,
      syncMessage: clearSyncMessage ? null : (syncMessage ?? this.syncMessage),
      syncWarning: syncWarning ?? this.syncWarning,
      channel: channel ?? this.channel,
      datePreset: datePreset ?? this.datePreset,
      customDateRange: customDateRange ?? this.customDateRange,
      liveOnly: liveOnly ?? this.liveOnly,
      searchQuery: searchQuery ?? this.searchQuery,
      sortBy: sortBy ?? this.sortBy,
      sortAscending: sortAscending ?? this.sortAscending,
      totals: totals ?? this.totals,
      campaigns: campaigns ?? this.campaigns,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
        status,
        isRefreshing,
        isSyncing,
        syncMessage,
        syncWarning,
        channel,
        datePreset,
        customDateRange,
        liveOnly,
        searchQuery,
        sortBy,
        sortAscending,
        totals,
        campaigns,
        lastSyncedAt,
        errorMessage,
      ];
}
