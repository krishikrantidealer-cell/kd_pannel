import 'package:equatable/equatable.dart';

enum WhatsAppCrmStatus { initial, loading, loaded, error }

class WhatsAppCrmState extends Equatable {
  final WhatsAppCrmStatus status;
  final List<dynamic> conversations;
  final dynamic selectedConversation;
  final List<dynamic> messages;
  final List<dynamic> salesAgents;
  final bool isLoadingConversations;
  final bool isLoadingMessages;
  final bool isSendingMessage;
  final bool isCalling;
  final bool isSyncingRoster;
  final int conversationsPage;
  final int totalPages;
  final String selectedStatusFilter;
  final String selectedTabFilter; // 'all', 'active', 'leads', 'dealers', 'unread'
  final String searchQuery;
  final String? errorMessage;
  final String? successMessage;

  const WhatsAppCrmState({
    this.status = WhatsAppCrmStatus.initial,
    this.conversations = const [],
    this.selectedConversation,
    this.messages = const [],
    this.salesAgents = const [],
    this.isLoadingConversations = false,
    this.isLoadingMessages = false,
    this.isSendingMessage = false,
    this.isCalling = false,
    this.isSyncingRoster = false,
    this.conversationsPage = 1,
    this.totalPages = 1,
    this.selectedStatusFilter = 'open',
    this.selectedTabFilter = 'all',
    this.searchQuery = '',
    this.errorMessage,
    this.successMessage,
  });

  WhatsAppCrmState copyWith({
    WhatsAppCrmStatus? status,
    List<dynamic>? conversations,
    dynamic selectedConversation,
    bool clearSelectedConversation = false,
    List<dynamic>? messages,
    List<dynamic>? salesAgents,
    bool? isLoadingConversations,
    bool? isLoadingMessages,
    bool? isSendingMessage,
    bool? isCalling,
    bool? isSyncingRoster,
    int? conversationsPage,
    int? totalPages,
    String? selectedStatusFilter,
    String? selectedTabFilter,
    String? searchQuery,
    String? errorMessage,
    bool clearError = false,
    String? successMessage,
    bool clearSuccess = false,
  }) {
    return WhatsAppCrmState(
      status: status ?? this.status,
      conversations: conversations ?? this.conversations,
      selectedConversation: clearSelectedConversation
          ? null
          : (selectedConversation ?? this.selectedConversation),
      messages: messages ?? this.messages,
      salesAgents: salesAgents ?? this.salesAgents,
      isLoadingConversations: isLoadingConversations ?? this.isLoadingConversations,
      isLoadingMessages: isLoadingMessages ?? this.isLoadingMessages,
      isSendingMessage: isSendingMessage ?? this.isSendingMessage,
      isCalling: isCalling ?? this.isCalling,
      isSyncingRoster: isSyncingRoster ?? this.isSyncingRoster,
      conversationsPage: conversationsPage ?? this.conversationsPage,
      totalPages: totalPages ?? this.totalPages,
      selectedStatusFilter: selectedStatusFilter ?? this.selectedStatusFilter,
      selectedTabFilter: selectedTabFilter ?? this.selectedTabFilter,
      searchQuery: searchQuery ?? this.searchQuery,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }

  @override
  List<Object?> get props => [
        status,
        conversations,
        selectedConversation,
        messages,
        salesAgents,
        isLoadingConversations,
        isLoadingMessages,
        isSendingMessage,
        isCalling,
        isSyncingRoster,
        conversationsPage,
        totalPages,
        selectedStatusFilter,
        selectedTabFilter,
        searchQuery,
        errorMessage,
        successMessage,
      ];
}
