import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kd_pannel/core/network/api_client.dart';
import 'package:kd_pannel/core/network/websocket_service.dart';
import 'whatsapp_crm_event.dart';
import 'whatsapp_crm_state.dart';

class WhatsAppCrmBloc extends Bloc<WhatsAppCrmEvent, WhatsAppCrmState> {
  StreamSubscription? _wsSubscription;

  WhatsAppCrmBloc() : super(const WhatsAppCrmState()) {
    on<FetchConversationsEvent>(_onFetchConversations);
    on<SelectConversationEvent>(_onSelectConversation);
    on<StartOrGetConversationEvent>(_onStartOrGetConversation);
    on<FetchMessagesEvent>(_onFetchMessages);
    on<SendMessageEvent>(_onSendMessage);
    on<SendTemplateEvent>(_onSendTemplate);
    on<AddInternalNoteEvent>(_onAddInternalNote);
    on<UpdateContactLanguageEvent>(_onUpdateContactLanguage);
    on<ReassignAgentEvent>(_onReassignAgent);
    on<UpdateConversationStatusEvent>(_onUpdateConversationStatus);
    on<TriggerOutboundCallFromChatEvent>(_onTriggerOutboundCall);
    on<WebSocketNewMessageReceivedEvent>(_onWebSocketNewMessage);
    on<WebSocketMessageStatusUpdatedEvent>(_onWebSocketMessageStatusUpdated);
    on<ClearWhatsAppCrmMessageEvent>(_onClearMessages);

    _initWebSocket();
  }

  void _initWebSocket() {
    _wsSubscription = WebSocketService().chatUpdates.listen((event) {
      final type = event['type'];
      final data = event['data'];
      if (type == 'NEW_MESSAGE' && data != null) {
        add(WebSocketNewMessageReceivedEvent(data as Map<String, dynamic>));
      } else if (type == 'MESSAGE_STATUS_UPDATED' && data != null) {
        add(WebSocketMessageStatusUpdatedEvent(data as Map<String, dynamic>));
      }
    });
  }

  @override
  Future<void> close() {
    _wsSubscription?.cancel();
    return super.close();
  }

  Future<void> _onFetchConversations(
    FetchConversationsEvent event,
    Emitter<WhatsAppCrmState> emit,
  ) async {
    emit(state.copyWith(
      isLoadingConversations: true,
      selectedStatusFilter: event.status,
      searchQuery: event.search,
      conversationsPage: event.page,
    ));

    try {
      // Also fetch sales agents list if empty
      List<dynamic> agents = state.salesAgents;
      if (agents.isEmpty) {
        final agentRes = await ApiClient().get('/users?role=sales');
        if (agentRes.statusCode == 200) {
          final agentBody = jsonDecode(agentRes.body);
          if (agentBody['success'] == true) {
            agents = agentBody['data'] ?? [];
          }
        }
      }

      final endpoint =
          '/conversations?status=${event.status}&search=${Uri.encodeComponent(event.search)}&page=${event.page}&limit=20';
      final res = await ApiClient().get(endpoint);

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true) {
          final List<dynamic> fetched = body['data'] ?? [];
          final int totalPages = body['pagination']?['pages'] ?? 1;

          List<dynamic> updatedList = event.append && event.page > 1
              ? [...state.conversations, ...fetched]
              : fetched;

          dynamic selected = state.selectedConversation;
          // If search was performed and nothing is selected, auto-select first
          if (event.search.isNotEmpty && updatedList.isNotEmpty && selected == null) {
            selected = updatedList.first;
            add(FetchMessagesEvent(conversationId: selected['_id'].toString()));
          }

          emit(state.copyWith(
            status: WhatsAppCrmStatus.loaded,
            conversations: updatedList,
            selectedConversation: selected,
            salesAgents: agents,
            totalPages: totalPages,
            isLoadingConversations: false,
          ));
          return;
        }
      }

      emit(state.copyWith(
        isLoadingConversations: false,
        errorMessage: 'Failed to fetch conversations',
      ));
    } catch (e) {
      debugPrint('[WhatsAppCrmBloc] Error fetching conversations: $e');
      emit(state.copyWith(
        isLoadingConversations: false,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onSelectConversation(
    SelectConversationEvent event,
    Emitter<WhatsAppCrmState> emit,
  ) async {
    final conv = event.conversation;
    emit(state.copyWith(
      selectedConversation: conv,
      messages: [],
    ));

    if (conv != null && conv['_id'] != null) {
      add(FetchMessagesEvent(conversationId: conv['_id'].toString()));
    }
  }

  Future<void> _onStartOrGetConversation(
    StartOrGetConversationEvent event,
    Emitter<WhatsAppCrmState> emit,
  ) async {
    emit(state.copyWith(isLoadingConversations: true));
    try {
      final res = await ApiClient().post('/conversations/start', {
        'phone': event.phone,
        'name': event.name,
      });

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true && body['data'] != null) {
          final conv = body['data'];
          final List<dynamic> list = List.from(state.conversations);
          final index = list.indexWhere((c) => c['_id'].toString() == conv['_id'].toString());
          if (index != -1) {
            list[index] = conv;
          } else {
            list.insert(0, conv);
          }

          emit(state.copyWith(
            conversations: list,
            selectedConversation: conv,
            isLoadingConversations: false,
          ));
          add(FetchMessagesEvent(conversationId: conv['_id'].toString()));
          return;
        }
      }

      emit(state.copyWith(isLoadingConversations: false));
      add(FetchConversationsEvent(search: event.phone));
    } catch (e) {
      debugPrint('[WhatsAppCrmBloc] Error starting conversation: $e');
      emit(state.copyWith(isLoadingConversations: false));
      add(FetchConversationsEvent(search: event.phone));
    }
  }

  Future<void> _onFetchMessages(
    FetchMessagesEvent event,
    Emitter<WhatsAppCrmState> emit,
  ) async {
    emit(state.copyWith(isLoadingMessages: true));
    try {
      final res = await ApiClient().get(
        '/conversations/${event.conversationId}/messages?page=${event.page}&limit=35',
      );

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true) {
          final List<dynamic> fetched = body['data'] ?? [];
          List<dynamic> updatedMessages;
          if (event.appendTop && event.page > 1) {
            updatedMessages = [...fetched, ...state.messages];
          } else {
            updatedMessages = fetched;
          }

          emit(state.copyWith(
            messages: updatedMessages,
            isLoadingMessages: false,
          ));
          return;
        }
      }
      emit(state.copyWith(isLoadingMessages: false));
    } catch (e) {
      debugPrint('[WhatsAppCrmBloc] Error fetching messages: $e');
      emit(state.copyWith(isLoadingMessages: false));
    }
  }

  Future<void> _onSendMessage(
    SendMessageEvent event,
    Emitter<WhatsAppCrmState> emit,
  ) async {
    emit(state.copyWith(isSendingMessage: true));
    try {
      final res = await ApiClient().post('/messages/send', {
        'conversationId': event.conversationId,
        'type': event.type,
        'content': event.content,
        'mediaUrl': event.mediaUrl,
      });

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true && body['data'] != null) {
          final newMsg = body['data'];
          final List<dynamic> updatedMessages = List.from(state.messages);
          updatedMessages.add(newMsg);

          emit(state.copyWith(
            messages: updatedMessages,
            isSendingMessage: false,
          ));
          return;
        }
      }

      final body = jsonDecode(res.body);
      emit(state.copyWith(
        isSendingMessage: false,
        errorMessage: body['message'] ?? 'Failed to send WhatsApp message',
      ));
    } catch (e) {
      debugPrint('[WhatsAppCrmBloc] Error sending message: $e');
      emit(state.copyWith(
        isSendingMessage: false,
        errorMessage: 'Network error sending WhatsApp message',
      ));
    }
  }

  Future<void> _onSendTemplate(
    SendTemplateEvent event,
    Emitter<WhatsAppCrmState> emit,
  ) async {
    emit(state.copyWith(isSendingMessage: true));
    try {
      final res = await ApiClient().post('/messages/send', {
        'conversationId': event.conversationId,
        'type': 'Template',
        'templateName': event.templateName,
        'bodyValues': event.bodyValues,
        'languageCode': event.languageCode,
      });

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true && body['data'] != null) {
          final newMsg = body['data'];
          final List<dynamic> updatedMessages = List.from(state.messages);
          updatedMessages.add(newMsg);

          emit(state.copyWith(
            messages: updatedMessages,
            isSendingMessage: false,
            successMessage: 'Template dispatched via MyOperator WABA',
          ));
          return;
        }
      }

      final body = jsonDecode(res.body);
      emit(state.copyWith(
        isSendingMessage: false,
        errorMessage: body['message'] ?? 'Failed to dispatch template',
      ));
    } catch (e) {
      debugPrint('[WhatsAppCrmBloc] Error sending template: $e');
      emit(state.copyWith(
        isSendingMessage: false,
        errorMessage: 'Network error dispatching template',
      ));
    }
  }

  Future<void> _onAddInternalNote(
    AddInternalNoteEvent event,
    Emitter<WhatsAppCrmState> emit,
  ) async {
    try {
      final res = await ApiClient().post('/notes', {
        'conversationId': event.conversationId,
        'note': event.note,
      });

      if (res.statusCode == 201 || res.statusCode == 200) {
        emit(state.copyWith(successMessage: 'Internal note logged & synced to customer'));
        add(FetchMessagesEvent(conversationId: event.conversationId));
      }
    } catch (e) {
      debugPrint('[WhatsAppCrmBloc] Error adding note: $e');
    }
  }

  Future<void> _onUpdateContactLanguage(
    UpdateContactLanguageEvent event,
    Emitter<WhatsAppCrmState> emit,
  ) async {
    try {
      final res = await ApiClient().put('/conversations/${event.conversationId}/language', {
        'preferredLanguage': event.languageCode,
      });

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        emit(state.copyWith(
          selectedConversation: body['data'],
          successMessage: 'Language updated to ${event.languageCode.toUpperCase()}',
        ));
      }
    } catch (e) {
      debugPrint('[WhatsAppCrmBloc] Error updating language: $e');
    }
  }

  Future<void> _onReassignAgent(
    ReassignAgentEvent event,
    Emitter<WhatsAppCrmState> emit,
  ) async {
    try {
      final res = await ApiClient().post('/conversations/assign', {
        'conversationId': event.conversationId,
        'agentId': event.agentId,
      });

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true) {
          final updated = body['data'];
          final List<dynamic> list = List.from(state.conversations);
          final index = list.indexWhere((c) => c['_id'].toString() == updated['_id'].toString());
          if (index != -1) list[index] = updated;

          emit(state.copyWith(
            conversations: list,
            selectedConversation: updated,
            successMessage: 'Lead successfully reassigned',
          ));
        }
      }
    } catch (e) {
      debugPrint('[WhatsAppCrmBloc] Error reassigning agent: $e');
    }
  }

  Future<void> _onUpdateConversationStatus(
    UpdateConversationStatusEvent event,
    Emitter<WhatsAppCrmState> emit,
  ) async {
    try {
      final res = await ApiClient().put('/conversations/${event.conversationId}/status', {
        'status': event.status,
      });

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true) {
          final updated = body['data'];
          final List<dynamic> list = List.from(state.conversations);
          final index = list.indexWhere((c) => c['_id'].toString() == updated['_id'].toString());
          if (index != -1) list[index] = updated;

          emit(state.copyWith(
            conversations: list,
            selectedConversation: updated,
            successMessage: 'Status updated to ${event.status}',
          ));
        }
      }
    } catch (e) {
      debugPrint('[WhatsAppCrmBloc] Error updating status: $e');
    }
  }

  Future<void> _onTriggerOutboundCall(
    TriggerOutboundCallFromChatEvent event,
    Emitter<WhatsAppCrmState> emit,
  ) async {
    emit(state.copyWith(isCalling: true));
    try {
      final res = await ApiClient().post('/calls/trigger', {
        'customerPhone': event.customerPhone,
      });

      if (res.statusCode == 200) {
        emit(state.copyWith(
          isCalling: false,
          successMessage: 'Outbound OBD call initiated via MyOperator!',
        ));
      } else {
        final body = jsonDecode(res.body);
        emit(state.copyWith(
          isCalling: false,
          errorMessage: body['message'] ?? 'Failed to initiate call',
        ));
      }
    } catch (e) {
      debugPrint('[WhatsAppCrmBloc] Error triggering call: $e');
      emit(state.copyWith(
        isCalling: false,
        errorMessage: 'Network error initiating call',
      ));
    }
  }

  void _onWebSocketNewMessage(
    WebSocketNewMessageReceivedEvent event,
    Emitter<WhatsAppCrmState> emit,
  ) {
    final newConv = event.payload['conversation'];
    final newMsg = event.payload['message'];

    if (newConv == null || newConv['_id'] == null) return;

    final String convId = newConv['_id'].toString();
    final List<dynamic> updatedConversations = List.from(state.conversations);
    final index = updatedConversations.indexWhere((c) => c['_id'].toString() == convId);

    if (index != -1) {
      updatedConversations[index] = newConv;
    } else {
      updatedConversations.insert(0, newConv);
    }

    // Sort by last message time
    updatedConversations.sort((a, b) {
      final dateA = a['lastMessageAt'] != null ? DateTime.tryParse(a['lastMessageAt'].toString()) : null;
      final dateB = b['lastMessageAt'] != null ? DateTime.tryParse(b['lastMessageAt'].toString()) : null;
      if (dateA == null) return 1;
      if (dateB == null) return -1;
      return dateB.compareTo(dateA);
    });

    List<dynamic> updatedMessages = List.from(state.messages);
    if (state.selectedConversation != null &&
        state.selectedConversation['_id'].toString() == convId &&
        newMsg != null) {
      final msgId = newMsg['_id']?.toString() ?? '';
      final alreadyExists = updatedMessages.any((m) => m['_id'].toString() == msgId);
      if (!alreadyExists) {
        updatedMessages.add(newMsg);
      }
    }

    emit(state.copyWith(
      conversations: updatedConversations,
      messages: updatedMessages,
    ));
  }

  void _onWebSocketMessageStatusUpdated(
    WebSocketMessageStatusUpdatedEvent event,
    Emitter<WhatsAppCrmState> emit,
  ) {
    final conversationId = event.payload['conversationId'];
    final messageId = event.payload['messageId'];
    final status = event.payload['status'];

    if (state.selectedConversation != null &&
        state.selectedConversation['_id'].toString() == conversationId.toString()) {
      final List<dynamic> updatedMessages = List.from(state.messages);
      final index = updatedMessages.indexWhere((m) => m['_id'].toString() == messageId.toString());
      if (index != -1) {
        final msg = Map<String, dynamic>.from(updatedMessages[index]);
        msg['status'] = status;
        updatedMessages[index] = msg;
        emit(state.copyWith(messages: updatedMessages));
      }
    }
  }

  void _onClearMessages(
    ClearWhatsAppCrmMessageEvent event,
    Emitter<WhatsAppCrmState> emit,
  ) {
    emit(state.copyWith(clearError: true, clearSuccess: true));
  }
}
