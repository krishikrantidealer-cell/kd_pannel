import 'package:flutter_bloc/flutter_bloc.dart';
import 'engagement_hub_state.dart';

class EngagementHubCubit extends Cubit<EngagementHubState> {
  EngagementHubCubit() : super(const EngagementHubState());

  void selectTab(int index) {
    final tab = EngagementHubTab.fromIndex(index);
    final updatedLoaded = Set<int>.from(state.loadedTabs)..add(index);
    emit(state.copyWith(
      activeTab: tab,
      loadedTabs: updatedLoaded,
    ));
  }

  void selectTabByType(EngagementHubTab tab) {
    final updatedLoaded = Set<int>.from(state.loadedTabs)..add(tab.index);
    emit(state.copyWith(
      activeTab: tab,
      loadedTabs: updatedLoaded,
    ));
  }

  void openTelemetryWithUser(String userIdentifier) {
    final updatedLoaded = Set<int>.from(state.loadedTabs)..add(EngagementHubTab.telemetry.index);
    emit(state.copyWith(
      activeTab: EngagementHubTab.telemetry,
      loadedTabs: updatedLoaded,
      prefilledUserQuery: userIdentifier,
    ));
  }

  void openPushWithSegment(String segmentKey) {
    final updatedLoaded = Set<int>.from(state.loadedTabs)..add(EngagementHubTab.pushCampaigns.index);
    emit(state.copyWith(
      activeTab: EngagementHubTab.pushCampaigns,
      loadedTabs: updatedLoaded,
      prefilledSegmentKey: segmentKey,
    ));
  }

  void openSalesActivity({String role = 'sales'}) {
    final updatedLoaded = Set<int>.from(state.loadedTabs)..add(EngagementHubTab.salesActivity.index);
    emit(state.copyWith(
      activeTab: EngagementHubTab.salesActivity,
      loadedTabs: updatedLoaded,
      prefilledSalesRole: role,
    ));
  }

  void clearPrefills() {
    emit(state.copyWith(clearPrefills: true));
  }

  void reset() {
    emit(const EngagementHubState());
  }
}
