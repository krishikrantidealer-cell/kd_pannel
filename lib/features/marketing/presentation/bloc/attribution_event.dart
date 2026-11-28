import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

abstract class AttributionEvent extends Equatable {
  const AttributionEvent();

  @override
  List<Object?> get props => [];
}

class LoadAttributionEvent extends AttributionEvent {
  final bool silent;
  const LoadAttributionEvent({this.silent = false});

  @override
  List<Object?> get props => [silent];
}

class ChangeAttributionChannelEvent extends AttributionEvent {
  final String channel;
  const ChangeAttributionChannelEvent(this.channel);

  @override
  List<Object?> get props => [channel];
}

class ChangeAttributionDatePresetEvent extends AttributionEvent {
  final String preset;
  final DateTimeRange? customRange;
  const ChangeAttributionDatePresetEvent(this.preset, {this.customRange});

  @override
  List<Object?> get props => [preset, customRange];
}

class ToggleLiveCampaignsEvent extends AttributionEvent {
  final bool liveOnly;
  const ToggleLiveCampaignsEvent(this.liveOnly);

  @override
  List<Object?> get props => [liveOnly];
}

class SyncMetaSpendEvent extends AttributionEvent {
  const SyncMetaSpendEvent();
}

class AttributionSearchChangedEvent extends AttributionEvent {
  final String query;
  const AttributionSearchChangedEvent(this.query);

  @override
  List<Object?> get props => [query];
}

class AttributionSortChangedEvent extends AttributionEvent {
  final String sortBy;
  final bool ascending;
  const AttributionSortChangedEvent(this.sortBy, this.ascending);

  @override
  List<Object?> get props => [sortBy, ascending];
}

class ResetAttributionEvent extends AttributionEvent {
  const ResetAttributionEvent();
}
