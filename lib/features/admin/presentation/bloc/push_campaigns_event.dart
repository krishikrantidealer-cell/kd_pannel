import 'package:equatable/equatable.dart';

abstract class PushCampaignsEvent extends Equatable {
  const PushCampaignsEvent();

  @override
  List<Object?> get props => [];
}

/// Fetch all push campaigns, active stats, rules, and banners
class FetchPushCampaignsEvent extends PushCampaignsEvent {
  final bool forceRefresh;
  const FetchPushCampaignsEvent({this.forceRefresh = false});

  @override
  List<Object?> get props => [forceRefresh];
}

/// Select a campaign segment for the detail/copies sidebar
class SelectCampaignEvent extends PushCampaignsEvent {
  final Map<String, dynamic>? campaign;
  const SelectCampaignEvent(this.campaign);

  @override
  List<Object?> get props => [campaign];
}

/// Toggle enable/disable status for a campaign segment
class ToggleCampaignEnabledEvent extends PushCampaignsEvent {
  final String segmentKey;
  final bool isEnabled;

  const ToggleCampaignEnabledEvent({
    required this.segmentKey,
    required this.isEnabled,
  });

  @override
  List<Object?> get props => [segmentKey, isEnabled];
}

/// Update scheduled dispatch time (e.g. "09:00", "11:30")
class UpdateCampaignScheduleEvent extends PushCampaignsEvent {
  final String segmentKey;
  final String scheduledTime;

  const UpdateCampaignScheduleEvent({
    required this.segmentKey,
    required this.scheduledTime,
  });

  @override
  List<Object?> get props => [segmentKey, scheduledTime];
}

/// General config update (mode, route, name, description, etc.)
class UpdateCampaignConfigEvent extends PushCampaignsEvent {
  final String segmentKey;
  final Map<String, dynamic> updates;

  const UpdateCampaignConfigEvent({
    required this.segmentKey,
    required this.updates,
  });

  @override
  List<Object?> get props => [segmentKey, updates];
}

/// Create a brand new campaign segment
class CreateCampaignSegmentEvent extends PushCampaignsEvent {
  final Map<String, dynamic> segmentData;

  const CreateCampaignSegmentEvent(this.segmentData);

  @override
  List<Object?> get props => [segmentData];
}

/// Delete an entire campaign segment
class DeleteCampaignSegmentEvent extends PushCampaignsEvent {
  final String segmentKey;

  const DeleteCampaignSegmentEvent(this.segmentKey);

  @override
  List<Object?> get props => [segmentKey];
}

/// Add a new notification copy/template to a segment
class AddCampaignTemplateEvent extends PushCampaignsEvent {
  final String segmentKey;
  final Map<String, dynamic> templateData;

  const AddCampaignTemplateEvent({
    required this.segmentKey,
    required this.templateData,
  });

  @override
  List<Object?> get props => [segmentKey, templateData];
}

/// Update an existing notification copy/template
class UpdateCampaignTemplateEvent extends PushCampaignsEvent {
  final String segmentKey;
  final String templateId;
  final Map<String, dynamic> templateData;

  const UpdateCampaignTemplateEvent({
    required this.segmentKey,
    required this.templateId,
    required this.templateData,
  });

  @override
  List<Object?> get props => [segmentKey, templateId, templateData];
}

/// Delete a notification template from a segment
class DeleteCampaignTemplateEvent extends PushCampaignsEvent {
  final String segmentKey;
  final String templateId;

  const DeleteCampaignTemplateEvent({
    required this.segmentKey,
    required this.templateId,
  });

  @override
  List<Object?> get props => [segmentKey, templateId];
}

/// Reorder templates in rotation order
class ReorderCampaignTemplatesEvent extends PushCampaignsEvent {
  final String segmentKey;
  final int oldIndex;
  final int newIndex;

  const ReorderCampaignTemplatesEvent({
    required this.segmentKey,
    required this.oldIndex,
    required this.newIndex,
  });

  @override
  List<Object?> get props => [segmentKey, oldIndex, newIndex];
}

/// Pin or unpin a copy for a segment
class TogglePinTemplateEvent extends PushCampaignsEvent {
  final String segmentKey;
  final String templateId;
  final bool isCurrentlyPinned;

  const TogglePinTemplateEvent({
    required this.segmentKey,
    required this.templateId,
    required this.isCurrentlyPinned,
  });

  @override
  List<Object?> get props => [segmentKey, templateId, isCurrentlyPinned];
}

/// Trigger an instant live broadcast for an entire segment
class TriggerBroadcastEvent extends PushCampaignsEvent {
  final String segmentKey;
  final Map<String, dynamic>? customTemplate;

  const TriggerBroadcastEvent({
    required this.segmentKey,
    this.customTemplate,
  });

  @override
  List<Object?> get props => [segmentKey, customTemplate];
}

/// Send instant test push to a specific phone number
class SendTestPushEvent extends PushCampaignsEvent {
  final String segmentKey;
  final String phone;
  final Map<String, dynamic> templateData;

  const SendTestPushEvent({
    required this.segmentKey,
    required this.phone,
    required this.templateData,
  });

  @override
  List<Object?> get props => [segmentKey, phone, templateData];
}

/// Clear messages after being consumed by UI
class ClearPushCampaignsMessageEvent extends PushCampaignsEvent {
  const ClearPushCampaignsMessageEvent();
}

/// Reset state on logout
class ResetPushCampaignsEvent extends PushCampaignsEvent {
  const ResetPushCampaignsEvent();
}
