import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

abstract class AuditLogsEvent extends Equatable {
  const AuditLogsEvent();

  @override
  List<Object?> get props => [];
}

class FetchAuditLogsInitial extends AuditLogsEvent {
  final bool forceRefresh;
  final String? role;
  const FetchAuditLogsInitial({this.forceRefresh = false, this.role});

  @override
  List<Object?> get props => [forceRefresh, role];
}

class FetchAuditLogsMore extends AuditLogsEvent {}

class SearchAuditLogs extends AuditLogsEvent {
  final String query;
  const SearchAuditLogs(this.query);

  @override
  List<Object?> get props => [query];
}

class ChangeAuditLogsFilters extends AuditLogsEvent {
  final String? searchQuery;
  final String? actionFilter;
  final String? moduleFilter;
  final String? agentEmail;
  final DateTimeRange? Function()? selectedDateRange;

  const ChangeAuditLogsFilters({
    this.searchQuery,
    this.actionFilter,
    this.moduleFilter,
    this.agentEmail,
    this.selectedDateRange,
  });

  @override
  List<Object?> get props => [
    searchQuery,
    actionFilter,
    moduleFilter,
    agentEmail,
    selectedDateRange,
  ];
}

class NewAuditLogReceived extends AuditLogsEvent {
  final Map<String, dynamic> log;
  const NewAuditLogReceived(this.log);

  @override
  List<Object?> get props => [log];
}

class ClearAuditLogsMessage extends AuditLogsEvent {}
