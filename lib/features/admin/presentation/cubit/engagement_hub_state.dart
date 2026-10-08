import 'package:equatable/equatable.dart';

enum EngagementHubTab {
  telemetry('telemetry', 'Marketing & Telemetry'),
  pushCampaigns('push', 'Push Campaigns'),
  salesActivity('sales-activity', 'Sales Activity');

  final String pathKey;
  final String label;

  const EngagementHubTab(this.pathKey, this.label);

  static EngagementHubTab fromIndex(int idx) {
    if (idx == 1) return EngagementHubTab.pushCampaigns;
    if (idx == 2) return EngagementHubTab.salesActivity;
    return EngagementHubTab.telemetry;
  }

  static EngagementHubTab fromPathKey(String? key) {
    if (key == null) return EngagementHubTab.telemetry;
    final lower = key.toLowerCase();
    if (lower.contains('push') || lower.contains('campaign')) {
      return EngagementHubTab.pushCampaigns;
    }
    if (lower.contains('sales') || lower.contains('audit') || lower.contains('log')) {
      return EngagementHubTab.salesActivity;
    }
    return EngagementHubTab.telemetry;
  }
}

class EngagementHubState extends Equatable {
  final EngagementHubTab activeTab;
  final Set<int> loadedTabs;
  final String? prefilledUserQuery;
  final String? prefilledSegmentKey;
  final String? prefilledSalesRole;

  const EngagementHubState({
    this.activeTab = EngagementHubTab.telemetry,
    this.loadedTabs = const {0},
    this.prefilledUserQuery,
    this.prefilledSegmentKey,
    this.prefilledSalesRole,
  });

  EngagementHubState copyWith({
    EngagementHubTab? activeTab,
    Set<int>? loadedTabs,
    String? prefilledUserQuery,
    String? prefilledSegmentKey,
    String? prefilledSalesRole,
    bool clearPrefills = false,
  }) {
    return EngagementHubState(
      activeTab: activeTab ?? this.activeTab,
      loadedTabs: loadedTabs ?? this.loadedTabs,
      prefilledUserQuery: clearPrefills ? null : (prefilledUserQuery ?? this.prefilledUserQuery),
      prefilledSegmentKey: clearPrefills ? null : (prefilledSegmentKey ?? this.prefilledSegmentKey),
      prefilledSalesRole: clearPrefills ? null : (prefilledSalesRole ?? this.prefilledSalesRole),
    );
  }

  @override
  List<Object?> get props => [
        activeTab,
        loadedTabs,
        prefilledUserQuery,
        prefilledSegmentKey,
        prefilledSalesRole,
      ];
}
