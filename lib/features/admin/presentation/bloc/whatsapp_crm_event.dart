import 'package:equatable/equatable.dart';

abstract class WhatsAppCrmEvent extends Equatable {
  const WhatsAppCrmEvent();

  @override
  List<Object?> get props => [];
}

class FetchConversationsEvent extends WhatsAppCrmEvent {
  final String search;
  final String status;
  final int page;
  final bool append;

  const FetchConversationsEvent({
    this.search = '',
    this.status = 'open',
    this.page = 1,
    this.append = false,
  });

  @override
  List<Object?> get props => [search, status, page, append];
}

class SelectConversationEvent extends WhatsAppCrmEvent {
  final dynamic conversation;
  const SelectConversationEvent(this.conversation);

  @override
  List<Object?> get props => [conversation];
}

class StartOrGetConversationEvent extends WhatsAppCrmEvent {
  final String phone;
  final String? name;

  const StartOrGetConversationEvent({
    required this.phone,
    this.name,
  });

  @override
  List<Object?> get props => [phone, name];
}

class FetchMessagesEvent extends WhatsAppCrmEvent {
  final String conversationId;
  final int page;
  final bool appendTop;

  const FetchMessagesEvent({
    required this.conversationId,
    this.page = 1,
    this.appendTop = false,
  });

  @override
  List<Object?> get props => [conversationId, page, appendTop];
}

class SendMessageEvent extends WhatsAppCrmEvent {
  final String conversationId;
  final String content;
  final String type;
  final String? mediaUrl;

  const SendMessageEvent({
    required this.conversationId,
    required this.content,
    this.type = 'Text',
    this.mediaUrl,
  });

  @override
  List<Object?> get props => [conversationId, content, type, mediaUrl];
}

class SendTemplateEvent extends WhatsAppCrmEvent {
  final String conversationId;
  final String templateName;
  final List<String> bodyValues;
  final String languageCode;

  const SendTemplateEvent({
    required this.conversationId,
    required this.templateName,
    this.bodyValues = const [],
    this.languageCode = 'en',
  });

  @override
  List<Object?> get props => [conversationId, templateName, bodyValues, languageCode];
}

class AddInternalNoteEvent extends WhatsAppCrmEvent {
  final String conversationId;
  final String note;

  const AddInternalNoteEvent({
    required this.conversationId,
    required this.note,
  });

  @override
  List<Object?> get props => [conversationId, note];
}

class UpdateContactLanguageEvent extends WhatsAppCrmEvent {
  final String conversationId;
  final String languageCode;

  const UpdateContactLanguageEvent({
    required this.conversationId,
    required this.languageCode,
  });

  @override
  List<Object?> get props => [conversationId, languageCode];
}

class ReassignAgentEvent extends WhatsAppCrmEvent {
  final String conversationId;
  final String agentId;

  const ReassignAgentEvent({
    required this.conversationId,
    required this.agentId,
  });

  @override
  List<Object?> get props => [conversationId, agentId];
}

class UpdateConversationStatusEvent extends WhatsAppCrmEvent {
  final String conversationId;
  final String status;

  const UpdateConversationStatusEvent({
    required this.conversationId,
    required this.status,
  });

  @override
  List<Object?> get props => [conversationId, status];
}

class TriggerOutboundCallFromChatEvent extends WhatsAppCrmEvent {
  final String customerPhone;

  const TriggerOutboundCallFromChatEvent(this.customerPhone);

  @override
  List<Object?> get props => [customerPhone];
}

class WebSocketNewMessageReceivedEvent extends WhatsAppCrmEvent {
  final Map<String, dynamic> payload;

  const WebSocketNewMessageReceivedEvent(this.payload);

  @override
  List<Object?> get props => [payload];
}

class WebSocketMessageStatusUpdatedEvent extends WhatsAppCrmEvent {
  final Map<String, dynamic> payload;

  const WebSocketMessageStatusUpdatedEvent(this.payload);

  @override
  List<Object?> get props => [payload];
}

class ClearWhatsAppCrmMessageEvent extends WhatsAppCrmEvent {
  const ClearWhatsAppCrmMessageEvent();
}
