// ---------------------------------------------------------------------------
// Category & Collection Domain Models
// ---------------------------------------------------------------------------

class CategoryModel {
  final String id;
  final String name;
  final String? image;
  final int order;
  final List<SubCategoryModel> subCategories;
  final Map<String, dynamic> rawMap;

  CategoryModel({
    required this.id,
    required this.name,
    this.image,
    this.order = 0,
    this.subCategories = const [],
    this.rawMap = const {},
  });

  factory CategoryModel.fromJson(dynamic jsonRaw) {
    if (jsonRaw is! Map) {
      return CategoryModel(id: '', name: '');
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

    final id = extractId(json['_id'] ?? json['id']);
    final name = (json['name'] ?? '').toString();

    final List<SubCategoryModel> subs = [];
    if (json['subCategories'] is List) {
      for (var s in json['subCategories']) {
        if (s is Map) {
          subs.add(SubCategoryModel.fromJson(s));
        }
      }
    }

    return CategoryModel(
      id: id,
      name: name,
      image: json['image']?.toString() ?? json['icon']?.toString(),
      order: ((json['order'] ?? 0) as num).toInt(),
      subCategories: subs,
      rawMap: json,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'image': image,
      'order': order,
      'subCategories': subCategories.map((s) => s.toJson()).toList(),
    };
  }
}

class SubCategoryModel {
  final String id;
  final String name;
  final String? image;
  final int order;

  SubCategoryModel({
    required this.id,
    required this.name,
    this.image,
    this.order = 0,
  });

  factory SubCategoryModel.fromJson(dynamic jsonRaw) {
    if (jsonRaw is! Map) {
      return SubCategoryModel(id: '', name: '');
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

    return SubCategoryModel(
      id: extractId(json['_id'] ?? json['id']),
      name: (json['name'] ?? '').toString(),
      image: json['image']?.toString() ?? json['icon']?.toString(),
      order: ((json['order'] ?? 0) as num).toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'image': image,
      'order': order,
    };
  }
}

class CollectionModel {
  final String id;
  final String name;
  final String? description;
  final String? image;
  final List<SubCollectionModel> subCollections;
  final Map<String, dynamic> rawMap;

  CollectionModel({
    required this.id,
    required this.name,
    this.description,
    this.image,
    this.subCollections = const [],
    this.rawMap = const {},
  });

  factory CollectionModel.fromJson(dynamic jsonRaw) {
    if (jsonRaw is! Map) {
      return CollectionModel(id: '', name: '');
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

    final id = extractId(json['_id'] ?? json['id']);
    final name = (json['name'] ?? '').toString();

    final List<SubCollectionModel> subs = [];
    if (json['subCollections'] is List) {
      for (var s in json['subCollections']) {
        if (s is Map) {
          subs.add(SubCollectionModel.fromJson(s));
        }
      }
    }

    return CollectionModel(
      id: id,
      name: name,
      description: json['description']?.toString(),
      image: json['image']?.toString(),
      subCollections: subs,
      rawMap: json,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'description': description,
      'image': image,
      'subCollections': subCollections.map((s) => s.toJson()).toList(),
    };
  }
}

class SubCollectionModel {
  final String id;
  final String name;

  SubCollectionModel({
    required this.id,
    required this.name,
  });

  factory SubCollectionModel.fromJson(dynamic jsonRaw) {
    if (jsonRaw is! Map) {
      return SubCollectionModel(id: '', name: '');
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

    return SubCollectionModel(
      id: extractId(json['_id'] ?? json['id']),
      name: (json['name'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
    };
  }
}
