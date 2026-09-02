class OrderItem {
  final String productId;
  final String variantId;
  final String title;
  final String? vendor;
  final String? technicalName;
  final String? image;
  final int quantity;
  final double price;
  final String? variantSize;
  final String? basePacking;
  final double? packVolume;
  final String? basePackingUnit;
  final bool isCustomBasePack;
  final bool isCustomPrice;
  final double? originalPrice;
  final double? costPrice;

  OrderItem({
    required this.productId,
    required this.variantId,
    required this.title,
    this.vendor,
    this.technicalName,
    this.image,
    required this.quantity,
    required this.price,
    this.variantSize,
    this.basePacking,
    this.packVolume,
    this.basePackingUnit,
    this.isCustomBasePack = false,
    this.isCustomPrice = false,
    this.originalPrice,
    this.costPrice,
  });

  factory OrderItem.fromJson(dynamic jsonRaw) {
    if (jsonRaw is! Map) {
      return OrderItem(
        productId: '',
        variantId: '',
        title: '',
        quantity: 0,
        price: 0.0,
      );
    }
    final json = Map<String, dynamic>.from(jsonRaw);
    final dynamic rawProduct = json['product'];
    final Map<String, dynamic>? productMap =
        rawProduct is Map ? Map<String, dynamic>.from(rawProduct) : null;
    String? sizeVal = json['variant']?.toString();
    if (sizeVal == 'Standard' || sizeVal == '') sizeVal = null;
    String? basePackingVal = json['basePacking']?.toString();
    double? packVol = (json['packVolume'] as num?)?.toDouble();
    String? baseUnit = json['basePackingUnit']?.toString();
    bool customPack = json['isCustomBasePack'] == true;
    bool customPrice = json['isCustomPrice'] == true;
    double? origPrice = (json['originalPrice'] as num?)?.toDouble();
    double? cp = (json['costPrice'] as num?)?.toDouble() ??
        (json['cost_price'] as num?)?.toDouble();

    if (productMap != null && productMap['variants'] is List) {
      final variantsList = productMap['variants'] as List;
      dynamic matchingVariant;
      for (final v in variantsList) {
        if (v is Map &&
            (v['_id']?.toString() == json['variantId']?.toString() ||
                v['id']?.toString() == json['variantId']?.toString())) {
          matchingVariant = v;
          break;
        }
      }
      if (matchingVariant != null && matchingVariant is Map) {
        sizeVal ??= matchingVariant['size']?.toString() ??
            matchingVariant['packSize']?.toString();
        if (basePackingVal == null || basePackingVal.isEmpty) {
          basePackingVal = matchingVariant['basePacking']?.toString();
          if (basePackingVal == null || basePackingVal.isEmpty) {
            final mvVol = matchingVariant['packVolume'];
            final mvUnit = matchingVariant['basePackingUnit'];
            if (mvVol != null) {
              basePackingVal =
                  '${mvVol % 1 == 0 ? mvVol.toInt() : mvVol} ${mvUnit ?? ''}'
                      .trim();
            }
          }
        }
        packVol ??= (matchingVariant['packVolume'] as num?)?.toDouble();
        baseUnit ??= matchingVariant['basePackingUnit']?.toString();
        cp ??= (matchingVariant['costPrice'] as num?)?.toDouble() ??
            (matchingVariant['cost_price'] as num?)?.toDouble();
      }
    }

    if ((basePackingVal == null || basePackingVal.isEmpty) && packVol != null) {
      basePackingVal =
          '${packVol % 1 == 0 ? packVol.toInt() : packVol} ${baseUnit ?? ''}'
              .trim();
    }

    return OrderItem(
      productId: json['product'] is Map
          ? (json['product']['_id']?.toString() ?? '')
          : (json['product']?.toString() ?? ''),
      variantId: json['variantId']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      vendor: json['vendor']?.toString(),
      technicalName: json['technicalName']?.toString(),
      image: json['image']?.toString(),
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      variantSize: sizeVal,
      basePacking: basePackingVal,
      packVolume: packVol,
      basePackingUnit: baseUnit,
      isCustomBasePack: customPack,
      isCustomPrice: customPrice,
      originalPrice: origPrice,
      costPrice: cp,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product': productId,
      'variantId': variantId,
      'title': title,
      'vendor': vendor,
      'technicalName': technicalName,
      'image': image,
      'quantity': quantity,
      'price': price,
      'variant': variantSize,
      'basePacking': basePacking,
      'packVolume': packVolume,
      'basePackingUnit': basePackingUnit,
      'isCustomBasePack': isCustomBasePack,
      'isCustomPrice': isCustomPrice,
      'originalPrice': originalPrice,
      'costPrice': costPrice,
    };
  }
}

class FreeItem {
  final String name;
  final String? imageUrl;
  final int quantity;
  final bool isFree;

  FreeItem({
    required this.name,
    this.imageUrl,
    required this.quantity,
    this.isFree = true,
  });

  factory FreeItem.fromJson(Map<String, dynamic> json) {
    return FreeItem(
      name: json['name'] ?? '',
      imageUrl: json['imageUrl'],
      quantity: json['quantity'] ?? 1,
      isFree: json['isFree'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'imageUrl': imageUrl,
      'quantity': quantity,
      'isFree': isFree,
    };
  }
}

class ShippingAddress {
  final String? name;
  final String? phoneNumber;
  final String villageArea;
  final String cityTehsil;
  final String? state;
  final String pincode;

  ShippingAddress({
    this.name,
    this.phoneNumber,
    required this.villageArea,
    required this.cityTehsil,
    this.state,
    required this.pincode,
  });

  factory ShippingAddress.fromJson(Map<String, dynamic> json) {
    return ShippingAddress(
      name: json['name'],
      phoneNumber: json['phoneNumber'],
      villageArea: json['villageArea'] ?? '',
      cityTehsil: json['cityTehsil'] ?? '',
      state: json['state'],
      pincode: json['pincode'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'phoneNumber': phoneNumber,
      'villageArea': villageArea,
      'cityTehsil': cityTehsil,
      'state': state,
      'pincode': pincode,
    };
  }
}

class OrderModel {
  final String id;
  final String orderId;
  final String? userId; // Added userId
  final String customerName;
  final String? shopName;
  final String customerPhone;
  final String customerRole; // 'Dealer' or 'Lead'
  final List<OrderItem> items;
  final double totalAmount;
  final double discountAmount;
  final String? couponCode;
  final List<FreeItem> freeItems;
  final ShippingAddress shippingAddress;
  final String paymentMethod; // 'Online', 'Partial'
  String paymentStatus; // 'Pending', 'Paid', 'Failed', 'Partially Paid'
  final String? razorpayPaymentId;
  final double advanceAmount;
  final double remainingAmount;
  String
  orderStatus; // 'Processing', 'Shipped', 'Out for Delivery', 'Delivered', 'Cancelled', 'RTO'
  String? courierStatus;
  String? awbNumber;
  String? courierName;
  String? trackingUrl;
  final DateTime placedAt;
  DateTime? processingAt;
  DateTime? shippedAt;
  DateTime? outForDeliveryAt;
  DateTime? deliveredAt;
  DateTime? cancelledAt;
  DateTime? rtoAt;
  final String? assignedAgent;
  final String? assignedAgentId;
  final String? createdBy;
  final String? createdById;
  final String? source; // 'panel', 'app', etc.

  bool get isPanelOrder {
    final cleanId = orderId.toUpperCase().trim();
    if (cleanId.startsWith('KD-') || cleanId.startsWith('KD')) return true;
    if (cleanId.startsWith('ORD-') || cleanId.startsWith('ORD')) return false;
    if (source != null && source!.isNotEmpty) {
      final s = source!.toLowerCase().trim();
      if (s == 'panel' || s == 'admin') return true;
      if (s == 'app') return false;
    }
    return items.any((i) => i.isCustomBasePack || i.isCustomPrice) ||
        paymentMethod == 'Partial';
  }

  OrderModel({
    required this.id,
    required this.orderId,
    this.userId, // Added userId
    required this.customerName,
    this.shopName,
    required this.customerPhone,
    required this.customerRole,
    required this.items,
    required this.totalAmount,
    this.discountAmount = 0.0,
    this.couponCode,
    this.freeItems = const [],
    required this.shippingAddress,
    required this.paymentMethod,
    required this.paymentStatus,
    this.razorpayPaymentId,
    this.advanceAmount = 0.0,
    this.remainingAmount = 0.0,
    required this.orderStatus,
    this.courierStatus,
    this.awbNumber,
    this.courierName,
    this.trackingUrl,
    required this.placedAt,
    this.processingAt,
    this.shippedAt,
    this.outForDeliveryAt,
    this.deliveredAt,
    this.cancelledAt,
    this.rtoAt,
    this.assignedAgent,
    this.assignedAgentId,
    this.createdBy,
    this.createdById,
    this.source,
  });

  factory OrderModel.fromJson(dynamic jsonRaw) {
    if (jsonRaw is! Map) {
      return OrderModel(
        id: '',
        orderId: '',
        customerName: 'Unknown',
        customerPhone: '',
        customerRole: 'Lead',
        items: const [],
        totalAmount: 0.0,
        shippingAddress: ShippingAddress(
          villageArea: '',
          cityTehsil: '',
          pincode: '',
        ),
        paymentMethod: 'Online',
        paymentStatus: 'Pending',
        orderStatus: 'Processing',
        placedAt: DateTime.now(),
      );
    }
    final json = Map<String, dynamic>.from(jsonRaw);
    final userRaw = json['user'];
    final userJson = userRaw is Map ? Map<String, dynamic>.from(userRaw) : null;
    String customerName = 'Unknown Customer';
    String? shopName;
    String customerPhone = '';
    String customerRole = 'Lead';
    String? userId;
    String? agentName;
    String? agentId;

    if (userJson != null) {
      userId = userJson['_id']?.toString();
      final firstName = userJson['firstName']?.toString() ?? '';
      final lastName = userJson['lastName']?.toString() ?? '';
      shopName = userJson['shopName']?.toString();
      final fullName = '$firstName $lastName'.trim();
      if (fullName.isNotEmpty) {
        customerName = fullName;
      } else if (shopName != null && shopName.isNotEmpty) {
        customerName = shopName;
      }
      customerPhone = userJson['phoneNumber']?.toString() ?? '';
      final isKycVerified =
          userJson['kycStatus'] == 'verified' ||
          (userJson['isKycComplete'] == true);
      customerRole = isKycVerified ? 'Dealer' : 'Lead';

      final dynamic assignedAgent = userJson['assignedAgent'];
      if (assignedAgent != null) {
        if (assignedAgent is Map) {
          agentId = (assignedAgent['_id'] ?? assignedAgent['id'])?.toString();
          final aFirst = assignedAgent['firstName']?.toString() ?? '';
          final aLast = assignedAgent['lastName']?.toString() ?? '';
          agentName = '$aFirst $aLast'.trim();
          if (agentName.isEmpty) agentName = assignedAgent['phoneNumber']?.toString();
        } else {
          // It's just an ID string
          agentId = assignedAgent.toString();
        }
      }
    }

    final itemsList = (json['items'] as List?)
            ?.map((i) => OrderItem.fromJson(i))
            .toList() ??
        [];
    final freeItemsList = (json['freeItems'] as List?)
            ?.map((f) => FreeItem.fromJson(f is Map ? Map<String, dynamic>.from(f) : {}))
            .toList() ??
        [];

    final placedAtRaw = json['placedAt'] ?? json['createdAt'];
    DateTime placedAtParsed = DateTime.now();
    if (placedAtRaw != null) {
      try {
        placedAtParsed = DateTime.parse(placedAtRaw.toString());
      } catch (_) {}
    }

    final shippingRaw = json['shippingAddress'];
    final shippingMap = shippingRaw is Map ? Map<String, dynamic>.from(shippingRaw) : <String, dynamic>{};

    final sourceVal = json['source']?.toString() ??
        json['createdVia']?.toString() ??
        json['orderSource']?.toString();

    String? createdByName;
    String? createdById;
    final dynamic createdByRaw = json['createdBy'];
    if (createdByRaw != null) {
      if (createdByRaw is Map) {
        createdById = (createdByRaw['_id'] ?? createdByRaw['id'])?.toString();
        final cFirst = createdByRaw['firstName']?.toString() ?? '';
        final cLast = createdByRaw['lastName']?.toString() ?? '';
        createdByName = '$cFirst $cLast'.trim();
        if (createdByName.isEmpty) createdByName = createdByRaw['email']?.toString();
      } else {
        createdById = createdByRaw.toString();
      }
    }

    return OrderModel(
      id: json['_id']?.toString() ?? '',
      orderId: json['orderId']?.toString() ?? '',
      userId: userId,
      customerName: customerName,
      shopName: shopName,
      customerPhone: customerPhone,
      customerRole: customerRole,
      items: itemsList,
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
      discountAmount: (json['discountAmount'] as num?)?.toDouble() ?? 0.0,
      couponCode: json['couponCode']?.toString(),
      freeItems: freeItemsList,
      shippingAddress: ShippingAddress.fromJson(shippingMap),
      paymentMethod: json['paymentMethod']?.toString() ?? 'Online',
      paymentStatus: json['paymentStatus']?.toString() ?? 'Pending',
      razorpayPaymentId: json['razorpayPaymentId']?.toString(),
      advanceAmount: (json['advanceAmount'] as num?)?.toDouble() ?? 0.0,
      remainingAmount: (json['remainingAmount'] as num?)?.toDouble() ?? 0.0,
      orderStatus: json['orderStatus']?.toString() ?? 'Processing',
      courierStatus: json['courierStatus']?.toString(),
      awbNumber: json['awbNumber']?.toString(),
      courierName: json['courierName']?.toString(),
      trackingUrl: json['trackingUrl']?.toString(),
      placedAt: placedAtParsed,
      processingAt: json['processingAt'] != null
          ? DateTime.tryParse(json['processingAt'].toString())
          : null,
      shippedAt: json['shippedAt'] != null
          ? DateTime.tryParse(json['shippedAt'].toString())
          : null,
      outForDeliveryAt: json['outForDeliveryAt'] != null
          ? DateTime.tryParse(json['outForDeliveryAt'].toString())
          : null,
      deliveredAt: json['deliveredAt'] != null
          ? DateTime.tryParse(json['deliveredAt'].toString())
          : null,
      cancelledAt: json['cancelledAt'] != null
          ? DateTime.tryParse(json['cancelledAt'].toString())
          : null,
      rtoAt: json['rtoAt'] != null
          ? DateTime.tryParse(json['rtoAt'].toString())
          : null,
      assignedAgent: agentName ?? json['assignedAgent']?.toString(),
      assignedAgentId: agentId,
      createdBy: createdByName ?? json['createdBy']?.toString(),
      createdById: createdById,
      source: sourceVal,
    );
  }

  OrderModel copyWith({
    String? id,
    String? orderId,
    String? userId,
    String? customerName,
    String? shopName,
    String? customerPhone,
    String? customerRole,
    List<OrderItem>? items,
    double? totalAmount,
    double? discountAmount,
    String? couponCode,
    List<FreeItem>? freeItems,
    ShippingAddress? shippingAddress,
    String? paymentMethod,
    String? paymentStatus,
    String? razorpayPaymentId,
    double? advanceAmount,
    double? remainingAmount,
    String? orderStatus,
    String? courierStatus,
    String? awbNumber,
    String? courierName,
    String? trackingUrl,
    DateTime? placedAt,
    DateTime? processingAt,
    DateTime? shippedAt,
    DateTime? outForDeliveryAt,
    DateTime? deliveredAt,
    DateTime? cancelledAt,
    DateTime? rtoAt,
    String? assignedAgent,
    String? assignedAgentId,
    String? createdBy,
    String? createdById,
    String? source,
  }) {
    return OrderModel(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      userId: userId ?? this.userId,
      customerName: customerName ?? this.customerName,
      shopName: shopName ?? this.shopName,
      customerPhone: customerPhone ?? this.customerPhone,
      customerRole: customerRole ?? this.customerRole,
      items: items ?? this.items,
      totalAmount: totalAmount ?? this.totalAmount,
      discountAmount: discountAmount ?? this.discountAmount,
      couponCode: couponCode ?? this.couponCode,
      freeItems: freeItems ?? this.freeItems,
      shippingAddress: shippingAddress ?? this.shippingAddress,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      razorpayPaymentId: razorpayPaymentId ?? this.razorpayPaymentId,
      advanceAmount: advanceAmount ?? this.advanceAmount,
      remainingAmount: remainingAmount ?? this.remainingAmount,
      orderStatus: orderStatus ?? this.orderStatus,
      courierStatus: courierStatus ?? this.courierStatus,
      awbNumber: awbNumber ?? this.awbNumber,
      courierName: courierName ?? this.courierName,
      trackingUrl: trackingUrl ?? this.trackingUrl,
      placedAt: placedAt ?? this.placedAt,
      processingAt: processingAt ?? this.processingAt,
      shippedAt: shippedAt ?? this.shippedAt,
      outForDeliveryAt: outForDeliveryAt ?? this.outForDeliveryAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      rtoAt: rtoAt ?? this.rtoAt,
      assignedAgent: assignedAgent ?? this.assignedAgent,
      assignedAgentId: assignedAgentId ?? this.assignedAgentId,
      createdBy: createdBy ?? this.createdBy,
      createdById: createdById ?? this.createdById,
      source: source ?? this.source,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'orderId': orderId,
      'user': {
        'firstName': customerName.split(' ').first,
        'lastName': customerName.split(' ').skip(1).join(' '),
        'shopName': shopName,
        'phoneNumber': customerPhone,
        'kycStatus': customerRole == 'Dealer' ? 'verified' : 'pending',
      },
      'items': items.map((i) => i.toJson()).toList(),
      'totalAmount': totalAmount,
      'discountAmount': discountAmount,
      'couponCode': couponCode,
      'freeItems': freeItems.map((f) => f.toJson()).toList(),
      'shippingAddress': shippingAddress.toJson(),
      'paymentMethod': paymentMethod,
      'paymentStatus': paymentStatus,
      'razorpayPaymentId': razorpayPaymentId,
      'advanceAmount': advanceAmount,
      'remainingAmount': remainingAmount,
      'orderStatus': orderStatus,
      'courierStatus': courierStatus,
      'awbNumber': awbNumber,
      'courierName': courierName,
      'trackingUrl': trackingUrl,
      'placedAt': placedAt.toIso8601String(),
      'processingAt': processingAt?.toIso8601String(),
      'shippedAt': shippedAt?.toIso8601String(),
      'outForDeliveryAt': outForDeliveryAt?.toIso8601String(),
      'deliveredAt': deliveredAt?.toIso8601String(),
      'cancelledAt': cancelledAt?.toIso8601String(),
      'rtoAt': rtoAt?.toIso8601String(),
      'assignedAgent': assignedAgent,
      'createdBy': createdBy,
      'source': source,
    };
  }
}
