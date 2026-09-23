import 'package:equatable/equatable.dart';

abstract class RetargetingEvent extends Equatable {
  const RetargetingEvent();

  @override
  List<Object?> get props => [];
}

class FetchCohortsEvent extends RetargetingEvent {
  final String cohort;
  final String language;

  const FetchCohortsEvent({
    this.cohort = 'cart_48h',
    this.language = 'all',
  });

  @override
  List<Object?> get props => [cohort, language];
}

class SendWhatsAppCohortBroadcastEvent extends RetargetingEvent {
  final List<String> userIds;
  final String templateName;
  final String defaultLanguage;
  final List<String> bodyValues;

  const SendWhatsAppCohortBroadcastEvent({
    required this.userIds,
    required this.templateName,
    this.defaultLanguage = 'en',
    this.bodyValues = const [],
  });

  @override
  List<Object?> get props => [userIds, templateName, defaultLanguage, bodyValues];
}

class ClearRetargetingMessageEvent extends RetargetingEvent {
  const ClearRetargetingMessageEvent();
}
