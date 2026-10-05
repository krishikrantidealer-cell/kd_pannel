import 'package:equatable/equatable.dart';

/// Strongly-typed immutable CallLogModel
class CallLogModel extends Equatable {
  final String id;
  final String providerCallId;
  final String direction; // 'inbound' | 'outbound'
  final String customerPhone;
  final String? customerName;
  final String? agentPhone;
  final String? agentId;
  final String? agentName;
  final String? contactId;
  final String status; // 'initiated' | 'ringing' | 'answered' | 'missed' | 'busy' | 'failed' | 'ended' | 'no-answer'
  final int durationSeconds;
  final String? disposition;
  final String? userDisposition;
  final DateTime? followUpDate;
  final String? followUpNote;
  final String? notes;
  final List<String> tags;
  final String? recordingUrl;
  final String? recordingId;
  final String? callSummary;
  final String callMode; // 'webcall' | 'click2call'
  final DateTime createdAt;
  final Map<String, dynamic> metadata;

  const CallLogModel({
    required this.id,
    required this.providerCallId,
    required this.direction,
    required this.customerPhone,
    this.customerName,
    this.agentPhone,
    this.agentId,
    this.agentName,
    this.contactId,
    required this.status,
    this.durationSeconds = 0,
    this.disposition,
    this.userDisposition,
    this.followUpDate,
    this.followUpNote,
    this.notes,
    this.tags = const [],
    this.recordingUrl,
    this.recordingId,
    this.callSummary,
    this.callMode = 'click2call',
    required this.createdAt,
    this.metadata = const {},
  });

  factory CallLogModel.fromJson(Map<String, dynamic> json) {
    // Parse Agent details
    String? agId;
    String? agName;
    if (json['agentId'] != null) {
      if (json['agentId'] is Map) {
        agId = json['agentId']['_id']?.toString();
        final first = json['agentId']['firstName']?.toString() ?? '';
        final last = json['agentId']['lastName']?.toString() ?? '';
        agName = '$first $last'.trim();
      } else {
        agId = json['agentId'].toString();
      }
    }

    // Parse Contact details
    String? cId;
    String? cName;
    if (json['contactId'] != null) {
      if (json['contactId'] is Map) {
        cId = json['contactId']['_id']?.toString();
        cName = json['contactId']['name']?.toString();
      } else {
        cId = json['contactId'].toString();
      }
    }

    final meta = json['metadata'] is Map<String, dynamic> ? json['metadata'] as Map<String, dynamic> : <String, dynamic>{};

    return CallLogModel(
      id: (json['_id'] ?? json['id'] ?? json['callId'] ?? '').toString(),
      providerCallId: (json['providerCallId'] ?? json['callId'] ?? '').toString(),
      direction: (json['direction'] ?? json['type'] ?? 'outbound').toString().toLowerCase(),
      customerPhone: (json['customerPhone'] ?? json['phone'] ?? '').toString(),
      customerName: cName,
      agentPhone: json['agentPhone']?.toString(),
      agentId: agId,
      agentName: agName,
      contactId: cId,
      status: (json['status'] ?? 'initiated').toString().toLowerCase(),
      durationSeconds: int.tryParse((json['durationSeconds'] ?? json['duration'] ?? 0).toString()) ?? 0,
      disposition: json['disposition']?.toString(),
      userDisposition: json['userDisposition']?.toString(),
      followUpDate: json['followUpDate'] != null ? DateTime.tryParse(json['followUpDate'].toString())?.toLocal() : null,
      followUpNote: json['followUpNote']?.toString(),
      notes: json['notes']?.toString(),
      tags: json['tags'] is List ? List<String>.from(json['tags'].map((t) => t.toString())) : [],
      recordingUrl: json['recordingUrl']?.toString(),
      recordingId: json['recordingId']?.toString(),
      callSummary: json['callSummary']?.toString(),
      callMode: (meta['callMode'] ?? json['callMode'] ?? 'click2call').toString(),
      createdAt: json['createdAt'] != null
          ? (DateTime.tryParse(json['createdAt'].toString())?.toLocal() ?? DateTime.now())
          : DateTime.now(),
      metadata: meta,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'providerCallId': providerCallId,
      'direction': direction,
      'customerPhone': customerPhone,
      'customerName': customerName,
      'agentPhone': agentPhone,
      'agentId': agentId,
      'agentName': agentName,
      'contactId': contactId,
      'status': status,
      'durationSeconds': durationSeconds,
      'disposition': disposition,
      'userDisposition': userDisposition,
      'followUpDate': followUpDate?.toIso8601String(),
      'followUpNote': followUpNote,
      'notes': notes,
      'tags': tags,
      'recordingUrl': recordingUrl,
      'recordingId': recordingId,
      'callSummary': callSummary,
      'callMode': callMode,
      'createdAt': createdAt.toIso8601String(),
      'metadata': metadata,
    };
  }

  @override
  List<Object?> get props => [
        id,
        providerCallId,
        direction,
        customerPhone,
        customerName,
        agentPhone,
        agentId,
        agentName,
        contactId,
        status,
        durationSeconds,
        disposition,
        userDisposition,
        followUpDate,
        followUpNote,
        notes,
        tags,
        recordingUrl,
        recordingId,
        callSummary,
        callMode,
        createdAt,
      ];
}
