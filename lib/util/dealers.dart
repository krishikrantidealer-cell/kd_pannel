class Dealer {
  final String name;
  final String phone;
  final String city;
  final String state;
  final String agent;
  final String gstStatus;
  final int totalOrders;
  final String purchaseValue;
  final bool isHighValue;
  final bool isInactive;
  final String source;
  final String? deepLinkUrl;
  final String? utmSource;
  final String? utmMedium;
  final String? utmCampaign;
  final String? utmTerm;
  final String? utmContent;
  final String? id;
  final String? agentId;
  final String? licenceImage;
  final String? shopImage;
  final String? gstNumber;
  final String? email;
  final String? userType;
  final String? kycStatus;
  final String? shopName;
  final Map<String, dynamic>? address;
  final bool isBlocked;
  final String? status;
  final String? notes;
  final String? createdAt;
  final String? updatedAt;
  final List<Map<String, dynamic>> notesHistory;

  Dealer({
    required this.name,
    required this.phone,
    required this.city,
    required this.state,
    required this.agent,
    required this.gstStatus,
    required this.totalOrders,
    required this.purchaseValue,
    required this.isHighValue,
    required this.isInactive,
    this.source = 'App',
    this.deepLinkUrl,
    this.utmSource,
    this.utmMedium,
    this.utmCampaign,
    this.utmTerm,
    this.utmContent,
    this.id,
    this.agentId,
    this.licenceImage,
    this.shopImage,
    this.gstNumber,
    this.email,
    this.userType,
    this.kycStatus,
    this.shopName,
    this.address,
    this.isBlocked = false,
    this.status = 'prospect',
    this.notes = '',
    this.createdAt,
    this.updatedAt,
    this.notesHistory = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      'city': city,
      'state': state,
      'agent': agent,
      'gstStatus': gstStatus,
      'totalOrders': totalOrders,
      'purchaseValue': purchaseValue,
      'isHighValue': isHighValue,
      'isInactive': isInactive,
      'source': source,
      'deepLinkUrl': deepLinkUrl,
      'utmSource': utmSource,
      'utmMedium': utmMedium,
      'utmCampaign': utmCampaign,
      'utmTerm': utmTerm,
      'utmContent': utmContent,
      'id': id,
      'agentId': agentId,
      'licenceImage': licenceImage,
      'shopImage': shopImage,
      'gstNumber': gstNumber,
      'email': email,
      'userType': userType,
      'kycStatus': kycStatus,
      'shopName': shopName,
      'address': address,
      'isBlocked': isBlocked,
      'status': status,
      'notes': notes,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'notesHistory': notesHistory,
    };
  }

  factory Dealer.fromMap(Map<String, dynamic> map) {
    final String personName = (map['firstName'] != null || map['lastName'] != null)
        ? '${map['firstName'] ?? ''} ${map['lastName'] ?? ''}'.trim()
        : (map['name'] ?? '');

    final assignedAgent = map['assignedAgent'];
    String? resolvedAgentId = map['agentId'];
    String agentName = map['agent'] ?? '-';

    if (assignedAgent != null) {
      if (assignedAgent is Map) {
        resolvedAgentId = (assignedAgent['_id'] ?? assignedAgent['\$oid'] ?? assignedAgent).toString();
        agentName = '${assignedAgent['firstName'] ?? ''} ${assignedAgent['lastName'] ?? ''}'.trim();
        if (agentName.isEmpty) agentName = (assignedAgent['phoneNumber'] ?? '').toString();
      } else {
        resolvedAgentId = assignedAgent.toString();
        // Only use ID as name if we don't already have a name from 'agent' field
        if (agentName == '-' || agentName == 'null' || agentName.isEmpty) {
          agentName = resolvedAgentId;
        }
      }
    }

    if (resolvedAgentId == 'null' || resolvedAgentId == '-') resolvedAgentId = null;
    if (agentName.isEmpty || agentName == 'null') agentName = '-';

    return Dealer(
      name: personName.isNotEmpty ? personName : (map['phoneNumber'] ?? 'Unnamed Dealer'),
      phone: map['phoneNumber'] ?? map['phone'] ?? '',
      city: map['address']?['cityTehsil'] ?? map['city'] ?? '',
      state: map['address']?['state'] ?? map['state'] ?? '',
      agent: agentName,
      gstStatus: map['gstStatus'] ?? 'Verified',
      totalOrders: map['totalOrders'] ?? 0,
      purchaseValue: map['purchaseValue'] ?? '₹0',
      isHighValue: map['isHighValue'] ?? false,
      isInactive: map['isInactive'] ?? false,
      source: map['source'] ?? 'App',
      deepLinkUrl: map['deepLinkUrl'],
      utmSource: map['utmSource'] ?? map['utm_source'],
      utmMedium: map['utmMedium'] ?? map['utm_medium'],
      utmCampaign: map['utmCampaign'] ?? map['utm_campaign'],
      utmTerm: map['utmTerm'] ?? map['utm_term'],
      utmContent: map['utmContent'] ?? map['utm_content'],
      id: (map['id'] ?? map['_id'])?.toString(),
      agentId: resolvedAgentId,
      licenceImage: map['licenceImage'],
      shopImage: map['shopImage'],
      gstNumber: map['gstNumber'],
      email: map['email'],
      userType: map['userType'],
      kycStatus: map['kycStatus'],
      shopName: map['shopName'],
      address: map['address'] != null ? Map<String, dynamic>.from(map['address']) : null,
      isBlocked: map['isBlocked'] ?? false,
      status: map['status'] ?? map['leadStatus'] ?? 'prospect',
      notes: map['notes'] ?? map['leadNotes'] ?? '',
      createdAt: map['createdAt'],
      updatedAt: map['updatedAt'],
      notesHistory: map['notesHistory'] != null ? List<Map<String, dynamic>>.from(map['notesHistory']) : [],
    );
  }
}

final List<Dealer> allDealers = [
  Dealer(
    name: 'Krishi Seva Kendra',
    phone: '+91 98765 43210',
    city: 'Nagpur',
    state: 'Maharashtra',
    agent: 'Rajesh Kumar',
    gstStatus: 'Verified',
    totalOrders: 45,
    purchaseValue: '₹12,45,000',
    isHighValue: true,
    isInactive: false,
  ),
  Dealer(
    name: 'Gajanan Agro Agency',
    phone: '+91 91234 56789',
    city: 'Pune',
    state: 'Maharashtra',
    agent: 'Suresh Patil',
    gstStatus: 'Pending',
    totalOrders: 22,
    purchaseValue: '₹5,60,000',
    isHighValue: false,
    isInactive: false,
  ),
  Dealer(
    name: 'Bharat Fertilizer Store',
    phone: '+91 99887 76655',
    city: 'Nashik',
    state: 'Maharashtra',
    agent: 'Amit Shah',
    gstStatus: 'Verified',
    totalOrders: 78,
    purchaseValue: '₹25,30,000',
    isHighValue: true,
    isInactive: false,
  ),
  Dealer(
    name: 'Kisan Mitra Traders',
    phone: '+91 94567 12345',
    city: 'Ahmedabad',
    state: 'Gujarat',
    agent: 'Vijay Deshmukh',
    gstStatus: 'Rejected',
    totalOrders: 12,
    purchaseValue: '₹2,10,000',
    isHighValue: false,
    isInactive: true,
  ),
  Dealer(
    name: 'Modern Agro Solution',
    phone: '+91 96789 01234',
    city: 'Indore',
    state: 'Madhya Pradesh',
    agent: 'Rajesh Kumar',
    gstStatus: 'Verified',
    totalOrders: 34,
    purchaseValue: '₹8,90,000',
    isHighValue: false,
    isInactive: false,
  ),
  Dealer(
    name: 'Sai Baba Krishi Kendra',
    phone: '+91 93210 98765',
    city: 'Kolhapur',
    state: 'Maharashtra',
    agent: 'Suresh Patil',
    gstStatus: 'Verified',
    totalOrders: 56,
    purchaseValue: '₹15,75,000',
    isHighValue: true,
    isInactive: false,
  ),
  Dealer(
    name: 'Green Field Pesticides',
    phone: '+91 91098 76543',
    city: 'Surat',
    state: 'Gujarat',
    agent: 'Amit Shah',
    gstStatus: 'Pending',
    totalOrders: 18,
    purchaseValue: '₹4,25,000',
    isHighValue: false,
    isInactive: true,
  ),
  Dealer(
    name: 'Agro World Enterprises',
    phone: '+91 95432 10987',
    city: 'Jalgaon',
    state: 'Maharashtra',
    agent: 'Vijay Deshmukh',
    gstStatus: 'Verified',
    totalOrders: 92,
    purchaseValue: '₹32,10,000',
    isHighValue: true,
    isInactive: false,
  ),
  Dealer(
    name: 'Jai Kisan Beej Bhandar',
    phone: '+91 92109 87654',
    city: 'Bhopal',
    state: 'Madhya Pradesh',
    agent: 'Rajesh Kumar',
    gstStatus: 'Verified',
    totalOrders: 28,
    purchaseValue: '₹6,40,000',
    isHighValue: false,
    isInactive: false,
  ),
  Dealer(
    name: 'Vikas Agro Center',
    phone: '+91 98987 65432',
    city: 'Latur',
    state: 'Maharashtra',
    agent: 'Amit Shah',
    gstStatus: 'Pending',
    totalOrders: 15,
    purchaseValue: '₹3,15,000',
    isHighValue: false,
    isInactive: false,
  ),
];
