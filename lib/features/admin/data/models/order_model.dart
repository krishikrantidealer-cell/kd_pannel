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
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    final productMap = json['product'] as Map<String, dynamic>?;
    String? sizeVal;
    String? basePackingVal;
    if (productMap != null && productMap['variants'] is List) {
      final variantsList = productMap['variants'] as List;
      final matchingVariant = variantsList.firstWhere(
        (v) =>
            v is Map && v['_id']?.toString() == json['variantId']?.toString(),
        orElse: () => null,
      );
      if (matchingVariant != null && matchingVariant is Map) {
        sizeVal = matchingVariant['size']?.toString();
        basePackingVal = matchingVariant['basePacking']?.toString();
      }
    }

    return OrderItem(
      productId: json['product'] is Map
          ? (json['product']['_id'] ?? '')
          : (json['product'] ?? ''),
      variantId: json['variantId'] ?? '',
      title: json['title'] ?? '',
      vendor: json['vendor'],
      technicalName: json['technicalName'],
      image: json['image'],
      quantity: json['quantity'] ?? 0,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      variantSize: sizeVal,
      basePacking: basePackingVal,
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

  OrderModel({
    required this.id,
    required this.orderId,
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
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    final userJson = json['user'] as Map<String, dynamic>?;
    String customerName = 'Unknown Customer';
    String? shopName;
    String customerPhone = '';
    String customerRole = 'Lead';
    if (userJson != null) {
      final firstName = userJson['firstName'] ?? '';
      final lastName = userJson['lastName'] ?? '';
      shopName = userJson['shopName']?.toString();
      final fullName = '$firstName $lastName'.trim();
      if (fullName.isNotEmpty) {
        customerName = fullName;
      } else if (shopName != null && shopName.isNotEmpty) {
        customerName = shopName;
      }
      customerPhone = userJson['phoneNumber'] ?? '';
      final isKycVerified =
          userJson['kycStatus'] == 'verified' ||
          (userJson['isKycComplete'] == true);
      customerRole = isKycVerified ? 'Dealer' : 'Lead';
    }

    final itemsList =
        (json['items'] as List?)?.map((i) => OrderItem.fromJson(i)).toList() ??
        [];
    final freeItemsList =
        (json['freeItems'] as List?)
            ?.map((f) => FreeItem.fromJson(f))
            .toList() ??
        [];

    final placedAtRaw = json['placedAt'] ?? json['createdAt'];

    return OrderModel(
      id: json['_id'] ?? '',
      orderId: json['orderId'] ?? '',
      customerName: customerName,
      shopName: shopName,
      customerPhone: customerPhone,
      customerRole: customerRole,
      items: itemsList,
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
      discountAmount: (json['discountAmount'] as num?)?.toDouble() ?? 0.0,
      couponCode: json['couponCode'],
      freeItems: freeItemsList,
      shippingAddress: ShippingAddress.fromJson(json['shippingAddress'] ?? {}),
      paymentMethod: json['paymentMethod'] ?? 'Online',
      paymentStatus: json['paymentStatus'] ?? 'Pending',
      razorpayPaymentId: json['razorpayPaymentId'],
      advanceAmount: (json['advanceAmount'] as num?)?.toDouble() ?? 0.0,
      remainingAmount: (json['remainingAmount'] as num?)?.toDouble() ?? 0.0,
      orderStatus: json['orderStatus'] ?? 'Processing',
      courierStatus: json['courierStatus'],
      awbNumber: json['awbNumber'],
      courierName: json['courierName'],
      trackingUrl: json['trackingUrl'],
      placedAt: placedAtRaw != null
          ? DateTime.parse(placedAtRaw)
          : DateTime.now(),
      processingAt: json['processingAt'] != null
          ? DateTime.parse(json['processingAt'])
          : null,
      shippedAt: json['shippedAt'] != null
          ? DateTime.parse(json['shippedAt'])
          : null,
      outForDeliveryAt: json['outForDeliveryAt'] != null
          ? DateTime.parse(json['outForDeliveryAt'])
          : null,
      deliveredAt: json['deliveredAt'] != null
          ? DateTime.parse(json['deliveredAt'])
          : null,
      cancelledAt: json['cancelledAt'] != null
          ? DateTime.parse(json['cancelledAt'])
          : null,
      rtoAt: json['rtoAt'] != null ? DateTime.parse(json['rtoAt']) : null,
      assignedAgent: json['assignedAgent'],
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
    };
  }
}
