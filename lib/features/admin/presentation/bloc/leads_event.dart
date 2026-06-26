import 'package:equatable/equatable.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';

abstract class LeadsEvent extends Equatable {
  const LeadsEvent();

  @override
  List<Object?> get props => [];
}

class FetchLeadsDataEvent extends LeadsEvent {
  final bool forceRefresh;
  const FetchLeadsDataEvent({this.forceRefresh = false});

  @override
  List<Object?> get props => [forceRefresh];
}

class AssignAgentToLeadEvent extends LeadsEvent {
  final String userId;
  final String? agentId;

  const AssignAgentToLeadEvent(this.userId, this.agentId);

  @override
  List<Object?> get props => [userId, agentId];
}

class BulkAssignAgentToLeadsEvent extends LeadsEvent {
  final List<String> userIds;
  final String? agentId;

  const BulkAssignAgentToLeadsEvent(this.userIds, this.agentId);

  @override
  List<Object?> get props => [userIds, agentId];
}

class CreateSalesAgentFromLeadsEvent extends LeadsEvent {
  final String firstName;
  final String lastName;
  final String email;
  final String phoneNumber;
  final String password;

  const CreateSalesAgentFromLeadsEvent({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phoneNumber,
    required this.password,
  });

  @override
  List<Object?> get props => [firstName, lastName, email, phoneNumber, password];
}

class VerifyKYCEvent extends LeadsEvent {
  final String userId;
  const VerifyKYCEvent(this.userId);

  @override
  List<Object?> get props => [userId];
}

class RejectKYCEvent extends LeadsEvent {
  final String userId;
  final String reason;
  const RejectKYCEvent(this.userId, this.reason);

  @override
  List<Object?> get props => [userId, reason];
}

class UpdateLeadsFilterEvent extends LeadsEvent {
  final String? searchQuery;
  final String? selectedTimeframe;
  final PickerDateRange? selectedRange;
  final bool resetRange;
  final String? selectedFilterChip;
  final int? currentPage;
  final int? pageSize;

  const UpdateLeadsFilterEvent({
    this.searchQuery,
    this.selectedTimeframe,
    this.selectedRange,
    this.resetRange = false,
    this.selectedFilterChip,
    this.currentPage,
    this.pageSize,
  });

  @override
  List<Object?> get props => [
        searchQuery,
        selectedTimeframe,
        selectedRange,
        resetRange,
        selectedFilterChip,
        currentPage,
        pageSize,
      ];
}

class ClearLeadsMessageEvent extends LeadsEvent {
  const ClearLeadsMessageEvent();
}

class ToggleBlockLeadEvent extends LeadsEvent {
  final String userId;
  const ToggleBlockLeadEvent(this.userId);

  @override
  List<Object?> get props => [userId];
}

class DeleteLeadEvent extends LeadsEvent {
  final String userId;
  const DeleteLeadEvent(this.userId);

  @override
  List<Object?> get props => [userId];
}
