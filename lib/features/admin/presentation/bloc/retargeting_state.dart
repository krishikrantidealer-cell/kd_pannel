import 'package:equatable/equatable.dart';

enum RetargetingStatus { initial, loading, loaded, error }

class RetargetingState extends Equatable {
  final RetargetingStatus status;
  final String selectedCohort;
  final String selectedLanguage;
  final List<dynamic> leads;
  final int totalCount;
  final bool isLoading;
  final bool isBroadcasting;
  final int broadcastSuccessCount;
  final int broadcastFailCount;
  final String? errorMessage;
  final String? successMessage;

  const RetargetingState({
    this.status = RetargetingStatus.initial,
    this.selectedCohort = 'cart_48h',
    this.selectedLanguage = 'all',
    this.leads = const [],
    this.totalCount = 0,
    this.isLoading = false,
    this.isBroadcasting = false,
    this.broadcastSuccessCount = 0,
    this.broadcastFailCount = 0,
    this.errorMessage,
    this.successMessage,
  });

  RetargetingState copyWith({
    RetargetingStatus? status,
    String? selectedCohort,
    String? selectedLanguage,
    List<dynamic>? leads,
    int? totalCount,
    bool? isLoading,
    bool? isBroadcasting,
    int? broadcastSuccessCount,
    int? broadcastFailCount,
    String? errorMessage,
    bool clearError = false,
    String? successMessage,
    bool clearSuccess = false,
  }) {
    return RetargetingState(
      status: status ?? this.status,
      selectedCohort: selectedCohort ?? this.selectedCohort,
      selectedLanguage: selectedLanguage ?? this.selectedLanguage,
      leads: leads ?? this.leads,
      totalCount: totalCount ?? this.totalCount,
      isLoading: isLoading ?? this.isLoading,
      isBroadcasting: isBroadcasting ?? this.isBroadcasting,
      broadcastSuccessCount: broadcastSuccessCount ?? this.broadcastSuccessCount,
      broadcastFailCount: broadcastFailCount ?? this.broadcastFailCount,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }

  @override
  List<Object?> get props => [
        status,
        selectedCohort,
        selectedLanguage,
        leads,
        totalCount,
        isLoading,
        isBroadcasting,
        broadcastSuccessCount,
        broadcastFailCount,
        errorMessage,
        successMessage,
      ];
}
