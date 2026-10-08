import 'package:flutter/foundation.dart';

class TelemetryUserIdentity {
  final String id;
  final String displayName;
  final String phoneNumber;
  final String userType; // 'Dealer', 'Lead', 'Guest', 'Customer'
  final Map<String, dynamic>? rawDetails;

  const TelemetryUserIdentity({
    required this.id,
    required this.displayName,
    required this.phoneNumber,
    required this.userType,
    this.rawDetails,
  });
}

/// High-Performance O(1) In-Memory Lookup Index for CRM Users (Dealers & Leads)
class TelemetryUserLookup {
  final Map<String, TelemetryUserIdentity> _byId = {};
  final Map<String, TelemetryUserIdentity> _byPhone = {};
  final Map<String, TelemetryUserIdentity> _byLast10 = {};
  final Map<String, TelemetryUserIdentity> _byEmail = {};
  final Map<String, TelemetryUserIdentity> _byNormalizedName = {};

  final Set<String> _salesAgentIdentifiers = {};

  bool _isBuilt = false;
  bool get isBuilt => _isBuilt;

  void buildIndex({
    required List<Map<String, dynamic>> rawDealers,
    required List<Map<String, dynamic>> rawLeads,
    required List<Map<String, dynamic>> salesAgents,
  }) {
    _byId.clear();
    _byPhone.clear();
    _byLast10.clear();
    _byEmail.clear();
    _byNormalizedName.clear();
    _salesAgentIdentifiers.clear();

    // 1. Index Sales Agents
    for (final a in salesAgents) {
      final fn = (a['firstName'] ?? '').toString().trim().toLowerCase();
      final ln = (a['lastName'] ?? '').toString().trim().toLowerCase();
      final full = '$fn $ln'.trim();
      final name = (a['name'] ?? '').toString().trim().toLowerCase();
      final email = (a['email'] ?? '').toString().trim().toLowerCase();
      final phone = _extractDigits(a['phoneNumber'] ?? a['phone'] ?? '');
      final uid = (a['_id'] ?? a['id'] ?? '').toString().trim().toLowerCase();

      if (fn.isNotEmpty) _salesAgentIdentifiers.add(fn);
      if (ln.isNotEmpty) _salesAgentIdentifiers.add(ln);
      if (full.isNotEmpty) _salesAgentIdentifiers.add(full);
      if (name.isNotEmpty) _salesAgentIdentifiers.add(name);
      if (email.isNotEmpty) _salesAgentIdentifiers.add(email);
      if (phone.isNotEmpty) _salesAgentIdentifiers.add(phone);
      if (uid.isNotEmpty) _salesAgentIdentifiers.add(uid);
    }

    // 2. Index Dealers (Higher precedence)
    for (final d in rawDealers) {
      final identity = _createIdentity(d, 'Dealer');
      _registerIdentity(identity, d);
    }

    // 3. Index Leads
    for (final l in rawLeads) {
      final identity = _createIdentity(l, 'Lead');
      _registerIdentity(identity, l);
    }

    _isBuilt = true;
  }

  bool isSalesAgent(String? identifier) {
    if (identifier == null || identifier.isEmpty) return false;
    final clean = identifier.trim().toLowerCase();
    final digits = _extractDigits(clean);
    return _salesAgentIdentifiers.contains(clean) ||
        (digits.isNotEmpty && _salesAgentIdentifiers.contains(digits));
  }

  TelemetryUserIdentity resolve(
    dynamic rawUserIdentifier, {
    String? fallbackName,
    String? fallbackPhone,
    Map<String, dynamic>? userDetails,
  }) {
    final String key = (rawUserIdentifier ?? '').toString().trim();
    final String keyLower = key.toLowerCase();
    final String digits = _extractDigits(key);
    final String last10 = digits.length >= 10 ? digits.substring(digits.length - 10) : '';

    // 1. O(1) ID Lookup
    if (key.isNotEmpty && _byId.containsKey(keyLower)) {
      return _byId[keyLower]!;
    }

    // 2. O(1) Phone Lookup
    if (digits.isNotEmpty && _byPhone.containsKey(digits)) {
      return _byPhone[digits]!;
    }

    // 3. O(1) Last 10 Digits Phone Lookup
    if (last10.isNotEmpty && _byLast10.containsKey(last10)) {
      return _byLast10[last10]!;
    }

    // 4. O(1) Email Lookup
    if (keyLower.contains('@') && _byEmail.containsKey(keyLower)) {
      return _byEmail[keyLower]!;
    }

    // 5. O(1) Name Lookup
    if (keyLower.isNotEmpty && _byNormalizedName.containsKey(keyLower)) {
      return _byNormalizedName[keyLower]!;
    }

    // Fallback resolution if embedded userDetails exists
    if (userDetails != null && userDetails.isNotEmpty) {
      final embeddedName = _resolveFullName(userDetails);
      final embeddedPhone = (userDetails['phoneNumber'] ?? userDetails['phone'] ?? '').toString().trim();
      final embeddedId = (userDetails['_id'] ?? userDetails['id'] ?? key).toString().trim();

      return TelemetryUserIdentity(
        id: embeddedId.isNotEmpty ? embeddedId : key,
        displayName: embeddedName.isNotEmpty ? embeddedName : (fallbackName?.isNotEmpty == true ? fallbackName! : 'Customer'),
        phoneNumber: embeddedPhone.isNotEmpty ? embeddedPhone : (fallbackPhone ?? ''),
        userType: 'Customer',
        rawDetails: userDetails,
      );
    }

    // Generic Fallback
    return TelemetryUserIdentity(
      id: key,
      displayName: fallbackName?.isNotEmpty == true ? fallbackName! : (digits.isNotEmpty ? digits : 'Customer'),
      phoneNumber: fallbackPhone?.isNotEmpty == true ? fallbackPhone! : digits,
      userType: 'Guest',
    );
  }

  void _registerIdentity(TelemetryUserIdentity identity, Map<String, dynamic> raw) {
    final idLower = identity.id.toLowerCase();
    if (idLower.isNotEmpty) _byId[idLower] = identity;

    final phoneDigits = _extractDigits(identity.phoneNumber);
    if (phoneDigits.isNotEmpty) {
      _byPhone[phoneDigits] = identity;
      if (phoneDigits.length >= 10) {
        _byLast10[phoneDigits.substring(phoneDigits.length - 10)] = identity;
      }
    }

    final email = (raw['email'] ?? '').toString().trim().toLowerCase();
    if (email.isNotEmpty) _byEmail[email] = identity;

    final nameLower = identity.displayName.toLowerCase();
    if (nameLower.isNotEmpty) _byNormalizedName[nameLower] = identity;

    final shopName = (raw['shopName'] ?? '').toString().trim().toLowerCase();
    if (shopName.isNotEmpty) _byNormalizedName[shopName] = identity;
  }

  TelemetryUserIdentity _createIdentity(Map<String, dynamic> raw, String userType) {
    final uid = (raw['_id'] ?? raw['id'] ?? '').toString().trim();
    final name = _resolveFullName(raw);
    final phone = (raw['phoneNumber'] ?? raw['phone'] ?? '').toString().trim();

    return TelemetryUserIdentity(
      id: uid,
      displayName: name.isNotEmpty ? name : (phone.isNotEmpty ? phone : '$userType User'),
      phoneNumber: phone,
      userType: userType,
      rawDetails: raw,
    );
  }

  String _resolveFullName(Map<String, dynamic> raw) {
    final fn = (raw['firstName'] ?? '').toString().trim();
    final ln = (raw['lastName'] ?? '').toString().trim();
    final shop = (raw['shopName'] ?? '').toString().trim();
    final full = '$fn $ln'.trim();

    if (full.isNotEmpty && !_isGenericName(full)) return full;
    if (shop.isNotEmpty && !_isGenericName(shop)) return shop;
    return full.isNotEmpty ? full : shop;
  }

  bool _isGenericName(String s) {
    final low = s.toLowerCase();
    return low == 'admin' || low == 'sales' || low == 'customer' || low == 'new customer' || low == 'guest';
  }

  static String _extractDigits(String s) {
    final sb = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final code = s.codeUnitAt(i);
      if (code >= 48 && code <= 57) {
        sb.writeCharCode(code);
      }
    }
    return sb.toString();
  }
}
