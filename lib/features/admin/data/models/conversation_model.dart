import 'package:equatable/equatable.dart';
import 'chat_message_model.dart';

/// Strongly-typed immutable ConversationModel
class ConversationModel extends Equatable {
  final String id;
  final String customerPhone;
  final String? customerName;
  final String? contactId;
  final String status; // 'open' | 'closed' | 'snoozed'
  final String? assignedToId;
  final String? assignedToName;
  final String? preferredLanguage; // 'en' | 'hi' | 'mr' | 'gu'
  final int unreadCount;
  final ChatMessageModel? lastMessage;
  final DateTime updatedAt;
  final List<String> tags;
  final Map<String, dynamic> metadata;

  const ConversationModel({
    required this.id,
    required this.customerPhone,
    this.customerName,
    this.contactId,
    this.status = 'open',
    this.assignedToId,
    this.assignedToName,
    this.preferredLanguage = 'hi',
    this.unreadCount = 0,
    this.lastMessage,
    required this.updatedAt,
    this.tags = const [],
    this.metadata = const {},
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    // Parse contact name & id
    String? cName;
    String? cId;
    if (json['contactId'] != null) {
      if (json['contactId'] is Map) {
        cId = json['contactId']['_id']?.toString();
        cName = json['contactId']['name']?.toString();
      } else {
        cId = json['contactId'].toString();
      }
    }
    cName = cName ?? json['customerName']?.toString() ?? json['name']?.toString();

    // Parse assigned sales rep
    String? agId;
    String? agName;
    if (json['assignedTo'] != null) {
      if (json['assignedTo'] is Map) {
        agId = json['assignedTo']['_id']?.toString();
        final first = json['assignedTo']['firstName']?.toString() ?? '';
        final last = json['assignedTo']['lastName']?.toString() ?? '';
        agName = '$first $last'.trim();
      } else {
        agId = json['assignedTo'].toString();
      }
    }

    ChatMessageModel? lastMsg;
    if (json['lastMessage'] != null && json['lastMessage'] is Map<String, dynamic>) {
      lastMsg = ChatMessageModel.fromJson(json['lastMessage'] as Map<String, dynamic>);
    }

    return ConversationModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      customerPhone: (json['customerPhone'] ?? json['phone'] ?? '').toString(),
      customerName: cName,
      contactId: cId,
      status: (json['status'] ?? 'open').toString().toLowerCase(),
      assignedToId: agId,
      assignedToName: agName,
      preferredLanguage: (json['preferredLanguage'] ?? json['language'] ?? 'hi').toString(),
      unreadCount: int.tryParse((json['unreadCount'] ?? 0).toString()) ?? 0,
      lastMessage: lastMsg,
      updatedAt: json['updatedAt'] != null
          ? (DateTime.tryParse(json['updatedAt'].toString())?.toLocal() ?? DateTime.now())
          : DateTime.now(),
      tags: json['tags'] is List ? List<String>.from(json['tags'].map((t) => t.toString())) : [],
      metadata: json['metadata'] is Map<String, dynamic> ? json['metadata'] as Map<String, dynamic> : <String, dynamic>{},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'customerPhone': customerPhone,
      'customerName': customerName,
      'contactId': contactId,
      'status': status,
      'assignedTo': assignedToId,
      'assignedToName': assignedToName,
      'preferredLanguage': preferredLanguage,
      'unreadCount': unreadCount,
      'lastMessage': lastMessage?.toJson(),
      'updatedAt': updatedAt.toIso8601String(),
      'tags': tags,
      'metadata': metadata,
    };
  }

  @override
  List<Object?> get props => [
        id,
        customerPhone,
        customerName,
        contactId,
        status,
        assignedToId,
        assignedToName,
        preferredLanguage,
        unreadCount,
        lastMessage,
        updatedAt,
        tags,
      ];
}
