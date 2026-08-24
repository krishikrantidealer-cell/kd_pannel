import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:kd_pannel/core/network/api_client.dart';
import 'package:kd_pannel/util/dealers.dart';

/// Repository for handling Dealer and Lead data access.
class DealerRepository {
  static final DealerRepository _instance = DealerRepository._internal();
  factory DealerRepository() => _instance;
  DealerRepository._internal();

  final ApiClient _apiClient = ApiClient();

  List<Dealer>? _cachedDealers;
  DateTime? _dealersCacheTime;
  static const Duration _cacheTtl = Duration(minutes: 5);

  /// Fetch all active dealers.
  Future<List<Dealer>> getDealers({bool forceRefresh = false, String? search}) async {
    if (!forceRefresh &&
        _cachedDealers != null &&
        _dealersCacheTime != null &&
        DateTime.now().difference(_dealersCacheTime!) < _cacheTtl &&
        search == null) {
      return _cachedDealers!;
    }

    try {
      final response = await _apiClient.get('/dealers');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List list = data is List ? data : (data['dealers'] ?? data['data'] ?? []);
        final parsed = list.map((d) {
          if (d is Dealer) return d;
          return Dealer.fromMap(Map<String, dynamic>.from(d as Map));
        }).toList();

        if (search == null) {
          _cachedDealers = parsed;
          _dealersCacheTime = DateTime.now();
        }

        if (search != null && search.trim().isNotEmpty) {
          final q = search.trim().toLowerCase();
          return parsed.where((d) {
            return d.name.toLowerCase().contains(q) ||
                d.phone.toLowerCase().contains(q) ||
                (d.city.toLowerCase().contains(q));
          }).toList();
        }

        return parsed;
      }
    } catch (e) {
      debugPrint('[DealerRepository] getDealers error: $e');
    }

    return _cachedDealers ?? [];
  }

  void invalidateCache() {
    _cachedDealers = null;
    _dealersCacheTime = null;
  }
}
