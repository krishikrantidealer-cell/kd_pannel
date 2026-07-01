import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:kd_pannel/core/network/api_client.dart';

/// A service that fetches real-world enterprise data from the backend.
class DashboardService {
  static final DashboardService _instance = DashboardService._internal();
  factory DashboardService() => _instance;
  DashboardService._internal();

  final ApiClient _client = ApiClient();

  Map<String, dynamic>? _cachedData;
  String? _lastPeriod;
  DateTime? _lastFetch;
  Future<Map<String, dynamic>>? _fetchFuture;

  Future<Map<String, dynamic>> _getAnalytics(String period) async {
    // 1. Check valid cache
    if (_cachedData != null && 
        _lastPeriod == period && 
        _lastFetch != null && 
        DateTime.now().difference(_lastFetch!) < const Duration(seconds: 15)) {
      return _cachedData!;
    }

    // 2. Return existing in-flight request if any
    if (_fetchFuture != null) {
      return _fetchFuture!;
    }

    // 3. Initiate new fetch
    final Future<Map<String, dynamic>> call = () async {
      try {
        final res = await _client.get('/admin/dashboard?period=$period');
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          if (data['success'] == true) {
            _cachedData = Map<String, dynamic>.from(data['analytics'] ?? {});
            _lastPeriod = period;
            _lastFetch = DateTime.now();
            return _cachedData!;
          }
        } else {
          debugPrint('[DashboardService] Fetch failed: ${res.statusCode}');
        }
      } catch (e) {
        debugPrint('[DashboardService] Error: $e');
      } finally {
        _fetchFuture = null;
      }
      return _cachedData ?? <String, dynamic>{};
    }();

    _fetchFuture = call;
    return call;

    return _fetchFuture!;
  }

  // --- Admin Dashboard Stats ---

  Future<String> getRevenueToday({String period = 'Today'}) async {
    final data = await _getAnalytics(period);
    final orders = data['orders'] as Map<String, dynamic>?;
    final val = orders?['periodRevenue'] ?? orders?['totalRevenue'] ?? 0;
    return '₹${_formatCurrency((val as num).toDouble())}';
  }

  Future<String> getOrderToday({String period = 'Today'}) async {
    final data = await _getAnalytics(period);
    final orders = data['orders'] as Map<String, dynamic>?;
    final val = orders?['periodTotal'] ?? orders?['total'] ?? 0;
    return '$val';
  }

  Future<String> getActiveDealers({String period = 'Today'}) async {
    final data = await _getAnalytics(period);
    final users = data['users'] as Map<String, dynamic>?;
    // Fallback order: active -> verified -> total
    final val = users?['active'] ?? users?['verified'] ?? users?['total'] ?? 0;
    return '$val';
  }

  Future<String> getNewLeads({String period = 'Today'}) async {
    final data = await _getAnalytics(period);
    final users = data['users'] as Map<String, dynamic>?;
    final val = users?['newLeads'] ?? users?['pendingKyc'] ?? 0;
    return '$val';
  }

  Future<String> getAbandonedCheckouts({String period = 'Today'}) async {
    final data = await _getAnalytics(period);
    final checkouts = data['checkouts'] as Map<String, dynamic>?;
    final val = checkouts?['abandoned'] ?? 0;
    return '$val';
  }

  Future<String> getPendingOrders({String period = 'Today'}) async {
    final data = await _getAnalytics(period);
    final orders = data['orders'] as Map<String, dynamic>?;
    final val = orders?['pending'] ?? 0;
    return '$val';
  }

  Future<String> getEventsToday({String period = 'Today'}) async {
    final data = await _getAnalytics(period);
    final events = data['events'] as Map<String, dynamic>?;
    final val = events?['periodTotal'] ?? 0;
    return '$val';
  }

  String _formatCurrency(double amount) {
    if (amount >= 100000) {
      return '${(amount / 100000).toStringAsFixed(1)}L';
    }
    if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}k';
    }
    return amount.toStringAsFixed(0);
  }

  // --- Dealer Management Stats ---
  Future<String> getDealerTotalDealers() async {
    final data = await _getAnalytics('Today');
    return (data['users']?['total'] ?? 0).toString();
  }

  Future<String> getDealerActiveDealers() async {
    final data = await _getAnalytics('Today');
    return (data['users']?['verified'] ?? 0).toString();
  }

  Future<String> getDealerHighValueDealers() async {
    // This would need a more specific query, but using verified for now
    final data = await _getAnalytics('Today');
    return (data['users']?['verified'] ?? 0).toString();
  }

  Future<String> getDealerInactiveDealers() async {
    final data = await _getAnalytics('Today');
    final total = data['users']?['total'] ?? 0;
    final verified = data['users']?['verified'] ?? 0;
    return (total - verified).toString();
  }

  // --- Leads Dashboard Stats ---
  // Using simplified counts from analytics
  Future<String> getLeadsUnassigned() async {
    final data = await _getAnalytics('Today');
    return (data['users']?['pendingKyc'] ?? 0).toString();
  }

  Future<String> getLeadsAssigned() async {
    return '0';
  }

  Future<String> getLeadsKycPending() async {
    final data = await _getAnalytics('Today');
    return (data['users']?['pendingKyc'] ?? 0).toString();
  }

  Future<String> getLeadsKycConfirm() async {
    return '0';
  }

  Future<String> getLeadsOrderPending() async {
    final data = await _getAnalytics('Today');
    return (data['orders']?['pending'] ?? 0).toString();
  }

  Future<String> getLeadsOrderConfirm() async {
    return '0';
  }
}
