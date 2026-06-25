import 'package:equatable/equatable.dart';

abstract class DealersEvent extends Equatable {
  const DealersEvent();

  @override
  List<Object?> get props => [];
}

class FetchDealersDataEvent extends DealersEvent {
  final bool forceRefresh;
  const FetchDealersDataEvent({this.forceRefresh = false});

  @override
  List<Object?> get props => [forceRefresh];
}

class AssignAgentToDealerEvent extends DealersEvent {
  final String userId;
  final String? agentId;

  const AssignAgentToDealerEvent({
    required this.userId,
    required this.agentId,
  });

  @override
  List<Object?> get props => [userId, agentId];
}

class CreateSalesAgentEvent extends DealersEvent {
  final String firstName;
  final String lastName;
  final String email;
  final String phoneNumber;
  final String password;

  const CreateSalesAgentEvent({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phoneNumber,
    required this.password,
  });

  @override
  List<Object?> get props => [firstName, lastName, email, phoneNumber, password];
}

class UpdateDealersFilterEvent extends DealersEvent {
  final String? searchQuery;
  final String? selectedAgent;
  final String? selectedState;
  final String? selectedTimeframe;
  final DateTime? customStartDate;
  final DateTime? customEndDate;
  final bool? showHighValueOnly;
  final bool? showInactiveOnly;
  final bool? showActiveOnly;
  final int? currentPage;
  final int? pageSize;

  const UpdateDealersFilterEvent({
    this.searchQuery,
    this.selectedAgent,
    this.selectedState,
    this.selectedTimeframe,
    this.customStartDate,
    this.customEndDate,
    this.showHighValueOnly,
    this.showInactiveOnly,
    this.showActiveOnly,
    this.currentPage,
    this.pageSize,
  });

  @override
  List<Object?> get props => [
        searchQuery,
        selectedAgent,
        selectedState,
        selectedTimeframe,
        customStartDate,
        customEndDate,
        showHighValueOnly,
        showInactiveOnly,
        showActiveOnly,
        currentPage,
        pageSize,
      ];
}

class ClearDealersMessageEvent extends DealersEvent {
  const ClearDealersMessageEvent();
}

class ToggleBlockDealerEvent extends DealersEvent {
  final String userId;
  const ToggleBlockDealerEvent(this.userId);

  @override
  List<Object?> get props => [userId];
}
