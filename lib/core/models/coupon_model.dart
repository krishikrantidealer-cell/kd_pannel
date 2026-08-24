// ---------------------------------------------------------------------------
// Coupon & Promotion Domain Models
// ---------------------------------------------------------------------------

enum CouponType { percentage, absolute, freeProduct, unknown }

class CouponModel {
  final String id;
  final String code;
  final CouponType discountType;
  final double discountValue;
  final double minimumPurchaseAmount;
  final double maxDiscount;
  final String? freeProductName;
  final String? description;
  final bool isActive;
  final DateTime? validUntil;
  final Map<String, dynamic> rawMap;

  CouponModel({
    required this.id,
    required this.code,
    required this.discountType,
    this.discountValue = 0.0,
    this.minimumPurchaseAmount = 0.0,
    this.maxDiscount = 0.0,
    this.freeProductName,
    this.description,
    this.isActive = true,
    this.validUntil,
    this.rawMap = const {},
  });

  bool canApply(double subtotal) {
    if (!isActive) return false;
    if (minimumPurchaseAmount > 0 && subtotal < minimumPurchaseAmount) return false;
    return true;
  }

  double calculateDiscount(double subtotal) {
    if (!canApply(subtotal)) return 0.0;

    double discount = 0.0;
    if (discountType == CouponType.percentage) {
      discount = (subtotal * discountValue / 100).clamp(0.0, subtotal);
      if (maxDiscount > 0 && discount > maxDiscount) {
        discount = maxDiscount;
      }
    } else if (discountType == CouponType.absolute) {
      discount = discountValue.clamp(0.0, subtotal);
    }
    return discount;
  }

  factory CouponModel.fromJson(dynamic jsonRaw) {
    if (jsonRaw is! Map) {
      return CouponModel(
        id: '',
        code: '',
        discountType: CouponType.unknown,
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

    final rawType = (json['discountType'] ?? '').toString().toLowerCase();
    CouponType type = CouponType.unknown;
    if (rawType.contains('percent')) {
      type = CouponType.percentage;
    } else if (rawType.contains('absolute') || rawType.contains('fixed')) {
      type = CouponType.absolute;
    } else if (rawType.contains('free')) {
      type = CouponType.freeProduct;
    }

    DateTime? parseDate(dynamic d) {
      if (d == null) return null;
      if (d is DateTime) return d;
      return DateTime.tryParse(d.toString());
    }

    return CouponModel(
      id: extractId(json['_id'] ?? json['id']),
      code: (json['code'] ?? '').toString().toUpperCase(),
      discountType: type,
      discountValue: ((json['discountValue'] ?? 0) as num).toDouble(),
      minimumPurchaseAmount: ((json['minimumPurchaseAmount'] ?? json['minPurchase'] ?? 0) as num).toDouble(),
      maxDiscount: ((json['maxDiscount'] ?? 0) as num).toDouble(),
      freeProductName: json['freeProductName']?.toString(),
      description: json['description']?.toString(),
      isActive: json['isActive'] != false,
      validUntil: parseDate(json['validUntil']),
      rawMap: json,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'code': code,
      'discountType': discountType.name,
      'discountValue': discountValue,
      'minimumPurchaseAmount': minimumPurchaseAmount,
      'maxDiscount': maxDiscount,
      'freeProductName': freeProductName,
      'description': description,
      'isActive': isActive,
    };
  }
}

class SalesCouponModel {
  final String id;
  final String code;
  final String? salesExecutiveId;
  final String? salesExecutiveName;
  final List<PriceOverrideModel> overrides;
  final bool isActive;
  final Map<String, dynamic> rawMap;

  SalesCouponModel({
    required this.id,
    required this.code,
    this.salesExecutiveId,
    this.salesExecutiveName,
    this.overrides = const [],
    this.isActive = true,
    this.rawMap = const {},
  });

  factory SalesCouponModel.fromJson(dynamic jsonRaw) {
    if (jsonRaw is! Map) {
      return SalesCouponModel(id: '', code: '');
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

    final List<PriceOverrideModel> overrideList = [];
    if (json['overrides'] is List) {
      for (var o in json['overrides']) {
        if (o is Map) {
          overrideList.add(PriceOverrideModel.fromJson(o));
        }
      }
    }

    return SalesCouponModel(
      id: extractId(json['_id'] ?? json['id']),
      code: (json['code'] ?? '').toString().toUpperCase(),
      salesExecutiveId: json['salesExecutiveId']?.toString(),
      salesExecutiveName: json['salesExecutiveName']?.toString(),
      overrides: overrideList,
      isActive: json['isActive'] != false,
      rawMap: json,
    );
  }
}

class PriceOverrideModel {
  final String variantId;
  final double overridePrice;

  PriceOverrideModel({
    required this.variantId,
    required this.overridePrice,
  });

  factory PriceOverrideModel.fromJson(dynamic jsonRaw) {
    if (jsonRaw is! Map) {
      return PriceOverrideModel(variantId: '', overridePrice: 0.0);
    }
    final json = Map<String, dynamic>.from(jsonRaw);
    return PriceOverrideModel(
      variantId: (json['variantId'] ?? json['variant'] ?? '').toString(),
      overridePrice: ((json['overridePrice'] ?? json['price'] ?? 0) as num).toDouble(),
    );
  }
}
