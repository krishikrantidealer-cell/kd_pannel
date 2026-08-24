// ---------------------------------------------------------------------------
// Marketing Campaign & Audience Segment Domain Models
// ---------------------------------------------------------------------------

class CampaignModel {
  final String id;
  final String name;
  final String title;
  final String body;
  final String? imageUrl;
  final String? actionRoute;
  final String segmentKey;
  final DateTime? scheduledAt;
  final String status;
  final int sentCount;
  final int deliveredCount;
  final int clickedCount;
  final Map<String, dynamic> rawMap;

  CampaignModel({
    required this.id,
    required this.name,
    required this.title,
    required this.body,
    this.imageUrl,
    this.actionRoute,
    required this.segmentKey,
    this.scheduledAt,
    this.status = 'Draft',
    this.sentCount = 0,
    this.deliveredCount = 0,
    this.clickedCount = 0,
    this.rawMap = const {},
  });

  factory CampaignModel.fromJson(dynamic jsonRaw) {
    if (jsonRaw is! Map) {
      return CampaignModel(
        id: '',
        name: '',
        title: '',
        body: '',
        segmentKey: '',
      );
    }
    final json = Map<String, dynamic>.from(jsonRaw);

    String extractId(dynamic item) {
      if (item == null) return '';
      if (item is String) return item;
      if (item is Map) {
        return item['\$oid']?.toString() ??
            item['_id']?.toString() ??
            item['id']?.toString() ??
            '';
      }
      return item.toString();
    }

    DateTime? parseDate(dynamic d) {
      if (d == null) return null;
      if (d is DateTime) return d;
      return DateTime.tryParse(d.toString());
    }

    return CampaignModel(
      id: extractId(json['_id'] ?? json['id']),
      name: (json['name'] ?? json['campaignName'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      body: (json['body'] ?? '').toString(),
      imageUrl: json['imageUrl']?.toString() ?? json['image']?.toString(),
      actionRoute: json['actionRoute']?.toString() ?? json['target']?.toString(),
      segmentKey: (json['segmentKey'] ?? json['segment'] ?? '').toString(),
      scheduledAt: parseDate(json['scheduledAt']),
      status: (json['status'] ?? 'Draft').toString(),
      sentCount: ((json['sentCount'] ?? 0) as num).toInt(),
      deliveredCount: ((json['deliveredCount'] ?? 0) as num).toInt(),
      clickedCount: ((json['clickedCount'] ?? 0) as num).toInt(),
      rawMap: json,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'title': title,
      'body': body,
      'imageUrl': imageUrl,
      'actionRoute': actionRoute,
      'segmentKey': segmentKey,
      'status': status,
    };
  }
}

class SegmentModel {
  final String id;
  final String name;
  final String key;
  final String? description;
  final String audienceType;
  final int count;
  final Map<String, dynamic> rules;
  final bool isActive;
  final Map<String, dynamic> rawMap;

  SegmentModel({
    required this.id,
    required this.name,
    required this.key,
    this.description,
    this.audienceType = 'Dealers',
    this.count = 0,
    this.rules = const {},
    this.isActive = true,
    this.rawMap = const {},
  });

  factory SegmentModel.fromJson(dynamic jsonRaw) {
    if (jsonRaw is! Map) {
      return SegmentModel(id: '', name: '', key: '');
    }
    final json = Map<String, dynamic>.from(jsonRaw);

    String extractId(dynamic item) {
      if (item == null) return '';
      if (item is String) return item;
      if (item is Map) {
        return item['\$oid']?.toString() ??
            item['_id']?.toString() ??
            item['id']?.toString() ??
            '';
      }
      return item.toString();
    }

    return SegmentModel(
      id: extractId(json['_id'] ?? json['id']),
      name: (json['name'] ?? '').toString(),
      key: (json['key'] ?? json['segmentKey'] ?? '').toString(),
      description: json['description']?.toString(),
      audienceType: (json['audienceType'] ?? 'Dealers').toString(),
      count: ((json['count'] ?? json['estimatedCount'] ?? 0) as num).toInt(),
      rules: json['rules'] is Map ? Map<String, dynamic>.from(json['rules'] as Map) : {},
      isActive: json['isActive'] != false,
      rawMap: json,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'key': key,
      'description': description,
      'audienceType': audienceType,
      'rules': rules,
      'isActive': isActive,
    };
  }
}
