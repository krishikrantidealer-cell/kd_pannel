import 'package:equatable/equatable.dart';

abstract class CallLogsEvent extends Equatable {
  const CallLogsEvent();

  @override
  List<Object?> get props => [];
}

class FetchCallLogsEvent extends CallLogsEvent {
  final int page;
  final String type;
  final String status;
  final String? agentId;
  final String search;

  const FetchCallLogsEvent({
    this.page = 1,
    this.type = 'all',
    this.status = 'all',
    this.agentId,
    this.search = '',
  });

  @override
  List<Object?> get props => [page, type, status, agentId, search];
}

class TriggerOutboundCallEvent extends CallLogsEvent {
  final String customerPhone;
  final String? customerName;

  const TriggerOutboundCallEvent(this.customerPhone, {this.customerName});

  @override
  List<Object?> get props => [customerPhone, customerName];
}

class SaveCallDispositionEvent extends CallLogsEvent {
  final String callLogId;
  final String userDisposition;
  final DateTime? followUpDate;
  final String? followUpNote;
  final String? notes;

  const SaveCallDispositionEvent({
    required this.callLogId,
    required this.userDisposition,
    this.followUpDate,
    this.followUpNote,
    this.notes,
  });

  @override
  List<Object?> get props => [callLogId, userDisposition, followUpDate, followUpNote, notes];
}

class WebSocketCallUpdateReceivedEvent extends CallLogsEvent {
  final Map<String, dynamic> callLog;

  const WebSocketCallUpdateReceivedEvent(this.callLog);

  @override
  List<Object?> get props => [callLog];
}

class ClearCallLogsMessageEvent extends CallLogsEvent {
  const ClearCallLogsMessageEvent();
}
