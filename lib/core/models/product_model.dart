// ---------------------------------------------------------------------------
// Product & Variant Domain Models
// ---------------------------------------------------------------------------

class ProductModel {
  final String id;
  final String title;
  final String? vendor;
  final String? technicalName;
  final String? description;
  final List<String> images;
  final List<String> categories;
  final List<String> categoryIds;
  final List<String> tags;
  final bool isFeatured;
  final List<ProductVariantModel> variants;
  final String? status;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic> rawMap;

  ProductModel({
    required this.id,
    required this.title,
    this.vendor,
    this.technicalName,
    this.description,
    this.images = const [],
    this.categories = const [],
    this.categoryIds = const [],
    this.tags = const [],
    this.isFeatured = false,
    this.variants = const [],
    this.status,
    this.createdAt,
    this.updatedAt,
    this.rawMap = const {},
  });

  String get primaryImage => images.isNotEmpty ? images.first : '';
  String get displayTitle => title.isNotEmpty ? title : (vendor ?? 'Unnamed Product');
  bool get hasVariants => variants.isNotEmpty;

  double get minPrice {
    if (variants.isEmpty) return 0.0;
    double min = double.infinity;
    for (var v in variants) {
      final p = v.dealerPrice > 0 ? v.dealerPrice : v.price;
      if (p > 0 && p < min) min = p;
    }
    return min == double.infinity ? 0.0 : min;
  }

  factory ProductModel.fromJson(dynamic jsonRaw) {
    if (jsonRaw is! Map) {
      return ProductModel(id: '', title: '');
    }
    final json = Map<String, dynamic>.from(jsonRaw);

    // Extract ID (handles Mongo ObjectId, _id, id, and $oid)
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
    final title = (json['title'] ?? json['name'] ?? '').toString();

    // Images
    final List<String> imgList = [];
    if (json['images'] is List) {
      for (var img in json['images']) {
        if (img != null && img.toString().isNotEmpty) {
          imgList.add(img.toString());
        }
      }
    }

    // Categories
    final List<String> cats = [];
    if (json['categories'] is List) {
      for (var c in json['categories']) {
        if (c != null && c.toString().isNotEmpty) {
          cats.add(c.toString());
        }
      }
    } else if (json['category'] != null && json['category'].toString().isNotEmpty) {
      cats.addAll(
        json['category'].toString().split(',').map((s) => s.trim()).where((s) => s.isNotEmpty),
      );
    }

    // Category IDs
    final List<String> catIdList = [];
    if (json['categoryIds'] is List) {
      for (var cid in json['categoryIds']) {
        final clean = extractId(cid);
        if (clean.isNotEmpty) catIdList.add(clean);
      }
    }

    // Tags
    final List<String> tagList = [];
    if (json['tags'] is List) {
      for (var t in json['tags']) {
        if (t != null && t.toString().isNotEmpty) {
          tagList.add(t.toString());
        }
      }
    }

    // Variants
    final List<ProductVariantModel> variantList = [];
    if (json['variants'] is List) {
      for (var v in json['variants']) {
        if (v is Map) {
          variantList.add(ProductVariantModel.fromJson(v));
        }
      }
    }

    DateTime? parseDate(dynamic d) {
      if (d == null) return null;
      if (d is DateTime) return d;
      return DateTime.tryParse(d.toString());
    }

    return ProductModel(
      id: id,
      title: title,
      vendor: json['vendor']?.toString(),
      technicalName: json['technicalName']?.toString(),
      description: json['description']?.toString(),
      images: imgList,
      categories: cats,
      categoryIds: catIdList,
      tags: tagList,
      isFeatured: json['isFeatured'] == true,
      variants: variantList,
      status: json['status']?.toString(),
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
      rawMap: json,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'title': title,
      'vendor': vendor,
      'technicalName': technicalName,
      'description': description,
      'images': images,
      'categories': categories,
      'categoryIds': categoryIds,
      'tags': tags,
      'isFeatured': isFeatured,
      'variants': variants.map((v) => v.toJson()).toList(),
      'status': status,
    };
  }
}

class ProductVariantModel {
  final String id;
  final String size;
  final String? packSizeUnit;
  final String? basePacking;
  final String basePackingUnit;
  final double packVolume;
  final double price;
  final double dealerPrice;
  final double comparePrice;
  final double farmerPrice;
  final String? sku;
  final int moq;
  final int inventoryQuantity;
  final Map<String, dynamic> rates;
  final List<Map<String, dynamic>> priceTiers;
  final Map<String, dynamic> rawMap;

  ProductVariantModel({
    required this.id,
    required this.size,
    this.packSizeUnit,
    this.basePacking,
    this.basePackingUnit = 'lit',
    this.packVolume = 1.0,
    this.price = 0.0,
    this.dealerPrice = 0.0,
    this.comparePrice = 0.0,
    this.farmerPrice = 0.0,
    this.sku,
    this.moq = 1,
    this.inventoryQuantity = 0,
    this.rates = const {},
    this.priceTiers = const [],
    this.rawMap = const {},
  });

  String get effectiveBasePacking =>
      basePacking?.isNotEmpty == true ? basePacking! : '${packVolume % 1 == 0 ? packVolume.toInt() : packVolume} $basePackingUnit'.trim();

  double? getTierRate(String tierId) {
    final dynamic raw = rates[tierId] ?? rates[int.tryParse(tierId)];
    if (raw == null) return null;
    final clean = raw.toString().split('/').first.replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(clean);
  }

  factory ProductVariantModel.fromJson(dynamic jsonRaw) {
    if (jsonRaw is! Map) {
      return ProductVariantModel(id: '', size: 'Standard');
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
    final size = (json['size'] ?? json['packSize'] ?? 'Standard').toString();
    final packVol = ((json['packVolume'] ?? 1) as num).toDouble();
    final price = ((json['price'] ?? 0) as num).toDouble();
    final dealerPrice = ((json['dealerPrice'] ?? price) as num).toDouble();
    final comparePrice = ((json['comparePrice'] ?? json['mrp'] ?? 0) as num).toDouble();
    final farmerPrice = ((json['farmerPrice'] ?? 0) as num).toDouble();

    final ratesMap = json['rates'] is Map
        ? Map<String, dynamic>.from(json['rates'] as Map)
        : <String, dynamic>{};

    final List<Map<String, dynamic>> tiers = [];
    if (json['priceTiers'] is List) {
      for (var t in json['priceTiers']) {
        if (t is Map) {
          tiers.add(Map<String, dynamic>.from(t));
        }
      }
    }

    return ProductVariantModel(
      id: id,
      size: size,
      packSizeUnit: json['packSizeUnit']?.toString(),
      basePacking: json['basePacking']?.toString(),
      basePackingUnit: json['basePackingUnit']?.toString() ?? 'lit',
      packVolume: packVol,
      price: price,
      dealerPrice: dealerPrice,
      comparePrice: comparePrice,
      farmerPrice: farmerPrice,
      sku: json['sku']?.toString(),
      moq: ((json['moq'] ?? 1) as num).toInt(),
      inventoryQuantity: ((json['inventoryQuantity'] ?? json['stock'] ?? 0) as num).toInt(),
      rates: ratesMap,
      priceTiers: tiers,
      rawMap: json,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'size': size,
      'packSizeUnit': packSizeUnit,
      'basePacking': basePacking,
      'basePackingUnit': basePackingUnit,
      'packVolume': packVolume,
      'price': price,
      'dealerPrice': dealerPrice,
      'comparePrice': comparePrice,
      'farmerPrice': farmerPrice,
      'sku': sku,
      'moq': moq,
      'inventoryQuantity': inventoryQuantity,
      'rates': rates,
      'priceTiers': priceTiers,
    };
  }
}
