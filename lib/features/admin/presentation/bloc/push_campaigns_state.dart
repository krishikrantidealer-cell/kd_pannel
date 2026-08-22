import 'package:equatable/equatable.dart';

enum PushCampaignsStatus { initial, loading, success, failure }

class PushCampaignsState extends Equatable {
  final PushCampaignsStatus status;
  final List<Map<String, dynamic>> campaigns;
  final Map<String, dynamic>? selectedCampaign;
  final List<Map<String, String>> banners;
  final List<Map<String, String>> targetRules;
  final List<Map<String, String>> categories;
  final int totalUsers;
  final int usersWithToken;
  final String? errorMessage;
  final String? successMessage;
  final bool isActionInProgress;

  const PushCampaignsState({
    this.status = PushCampaignsStatus.initial,
    this.campaigns = const [],
    this.selectedCampaign,
    this.banners = const [],
    this.targetRules = const [],
    this.categories = const [],
    this.totalUsers = 0,
    this.usersWithToken = 0,
    this.errorMessage,
    this.successMessage,
    this.isActionInProgress = false,
  });

  PushCampaignsState copyWith({
    PushCampaignsStatus? status,
    List<Map<String, dynamic>>? campaigns,
    Map<String, dynamic>? Function()? selectedCampaign,
    List<Map<String, String>>? banners,
    List<Map<String, String>>? targetRules,
    List<Map<String, String>>? categories,
    int? totalUsers,
    int? usersWithToken,
    String? Function()? errorMessage,
    String? Function()? successMessage,
    bool? isActionInProgress,
  }) {
    return PushCampaignsState(
      status: status ?? this.status,
      campaigns: campaigns ?? this.campaigns,
      selectedCampaign:
          selectedCampaign != null ? selectedCampaign() : this.selectedCampaign,
      banners: banners ?? this.banners,
      targetRules: targetRules ?? this.targetRules,
      categories: categories ?? this.categories,
      totalUsers: totalUsers ?? this.totalUsers,
      usersWithToken: usersWithToken ?? this.usersWithToken,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
      successMessage:
          successMessage != null ? successMessage() : this.successMessage,
      isActionInProgress: isActionInProgress ?? this.isActionInProgress,
    );
  }

  @override
  List<Object?> get props => [
        status,
        campaigns,
        selectedCampaign,
        banners,
        targetRules,
        categories,
        totalUsers,
        usersWithToken,
        errorMessage,
        successMessage,
        isActionInProgress,
      ];
}
