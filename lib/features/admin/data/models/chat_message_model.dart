import 'package:equatable/equatable.dart';

/// Strongly-typed immutable ChatMessageModel
class ChatMessageModel extends Equatable {
  final String id;
  final String conversationId;
  final String direction; // 'inbound' | 'outbound'
  final String text;
  final String messageType; // 'text' | 'template' | 'image' | 'document' | 'audio' | 'interactive' | 'note'
  final String status; // 'sent' | 'delivered' | 'read' | 'failed' | 'pending'
  final String? mediaUrl;
  final String? caption;
  final String? senderName;
  final String? authorId;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;

  const ChatMessageModel({
    required this.id,
    required this.conversationId,
    required this.direction,
    required this.text,
    this.messageType = 'text',
    this.status = 'sent',
    this.mediaUrl,
    this.caption,
    this.senderName,
    this.authorId,
    required this.timestamp,
    this.metadata = const {},
  });

  bool get isOutbound => direction == 'outbound';
  bool get isInbound => direction == 'inbound';
  bool get isInternalNote => messageType == 'note';

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      id: (json['_id'] ?? json['id'] ?? json['messageId'] ?? '').toString(),
      conversationId: (json['conversationId'] ?? json['conversation_id'] ?? '').toString(),
      direction: (json['direction'] ?? (json['isOutbound'] == true ? 'outbound' : 'inbound')).toString().toLowerCase(),
      text: (json['text'] ?? json['content'] ?? json['body'] ?? json['message'] ?? '').toString(),
      messageType: (json['messageType'] ?? json['type'] ?? 'text').toString().toLowerCase(),
      status: (json['status'] ?? json['deliveryStatus'] ?? 'sent').toString().toLowerCase(),
      mediaUrl: json['mediaUrl']?.toString() ?? json['url']?.toString(),
      caption: json['caption']?.toString(),
      senderName: json['senderName']?.toString() ?? json['authorName']?.toString(),
      authorId: json['authorId']?.toString() ?? json['adminId']?.toString(),
      timestamp: json['timestamp'] != null
          ? (DateTime.tryParse(json['timestamp'].toString())?.toLocal() ?? DateTime.now())
          : (json['createdAt'] != null
              ? (DateTime.tryParse(json['createdAt'].toString())?.toLocal() ?? DateTime.now())
              : DateTime.now()),
      metadata: json['metadata'] is Map<String, dynamic> ? json['metadata'] as Map<String, dynamic> : <String, dynamic>{},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'conversationId': conversationId,
      'direction': direction,
      'text': text,
      'messageType': messageType,
      'status': status,
      'mediaUrl': mediaUrl,
      'caption': caption,
      'senderName': senderName,
      'authorId': authorId,
      'timestamp': timestamp.toIso8601String(),
      'metadata': metadata,
    };
  }

  @override
  List<Object?> get props => [
        id,
        conversationId,
        direction,
        text,
        messageType,
        status,
        mediaUrl,
        caption,
        senderName,
        authorId,
        timestamp,
      ];
}
