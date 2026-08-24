import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:kd_pannel/core/network/api_client.dart';
import 'package:kd_pannel/core/models/coupon_model.dart';

/// Repository for handling Orders, Coupons, and fulfillment.
class OrderRepository {
  static final OrderRepository _instance = OrderRepository._internal();
  factory OrderRepository() => _instance;
  OrderRepository._internal();

  final ApiClient _apiClient = ApiClient();

  List<Map<String, dynamic>>? _cachedActiveCoupons;
  DateTime? _couponsCacheTime;
  static const Duration _couponCacheTtl = Duration(minutes: 5);

  /// Create a new order.
  Future<Map<String, dynamic>> createOrder(Map<String, dynamic> payload) async {
    try {
      final response = await _apiClient.post(
        '/orders',
        payload,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'order': data['order'] ?? data,
        };
      } else {
        final data = jsonDecode(response.body);
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to create order (Status ${response.statusCode})',
        };
      }
    } catch (e) {
      debugPrint('[OrderRepository] createOrder error: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Get typed active CouponModels.
  Future<List<CouponModel>> getActiveCouponModels({bool forceRefresh = false}) async {
    final rawList = await getActiveCoupons(forceRefresh: forceRefresh);
    return rawList.map((c) => CouponModel.fromJson(c)).toList();
  }

  /// Get active raw coupons.
  Future<List<Map<String, dynamic>>> getActiveCoupons({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _cachedActiveCoupons != null &&
        _couponsCacheTime != null &&
        DateTime.now().difference(_couponsCacheTime!) < _couponCacheTtl) {
      return _cachedActiveCoupons!;
    }

    try {
      final response = await _apiClient.get('/coupons/active');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final list = data['coupons'] as List? ?? [];
          final active = list
              .map((c) => Map<String, dynamic>.from(c as Map))
              .where((c) => c['isActive'] == true)
              .toList();
          _cachedActiveCoupons = active;
          _couponsCacheTime = DateTime.now();
          return active;
        }
      }
    } catch (e) {
      debugPrint('[OrderRepository] getActiveCoupons error: $e');
    }

    return _cachedActiveCoupons ?? [];
  }

  /// Validate a sales coupon and return typed SalesCouponModel.
  Future<Map<String, dynamic>> validateSalesCoupon({
    required String code,
    required double subtotal,
  }) async {
    try {
      final response = await _apiClient.post(
        '/sales-coupons/validate',
        {
          'code': code.trim().toUpperCase(),
          'subtotal': subtotal,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final rawCoupon = data['coupon'] ?? data;
          return {
            'success': true,
            'coupon': rawCoupon,
            'couponModel': SalesCouponModel.fromJson(rawCoupon),
          };
        }
      }
      final data = jsonDecode(response.body);
      return {
        'success': false,
        'message': data['message'] ?? 'Invalid sales coupon',
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Fetch admin orders with query params.
  Future<List<dynamic>> fetchAdminOrders(String queryParams) async {
    final response = await _apiClient.get('/orders/admin/all$queryParams');
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        return (data['orders'] as List? ?? []);
      }
      throw Exception(data['message'] ?? 'Failed to load orders');
    }
    throw Exception('Failed to load orders. Status code: ${response.statusCode}');
  }

  /// Fetch all estimates
  Future<List<Map<String, dynamic>>> fetchEstimates() async {
    final response = await _apiClient.get('/admin/estimates');
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        return List<Map<String, dynamic>>.from(data['estimates'] ?? []);
      }
      throw Exception(data['message'] ?? 'Failed to load estimates');
    }
    throw Exception('Failed to load estimates (${response.statusCode})');
  }

  /// Create estimate
  Future<Map<String, dynamic>> createEstimate(Map<String, dynamic> estimateData) async {
    final response = await _apiClient.post('/admin/estimates', estimateData);
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 || response.statusCode == 201) {
      if (data['success'] == true) {
        return data;
      }
      throw Exception(data['message'] ?? 'Failed to create estimate');
    }
    throw Exception(data['message'] ?? 'Server error (${response.statusCode})');
  }

  /// Update estimate
  Future<Map<String, dynamic>> updateEstimate(String dbId, Map<String, dynamic> estimateData) async {
    final response = await _apiClient.put('/admin/estimates/$dbId', estimateData);
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      if (data['success'] == true) {
        return data;
      }
      throw Exception(data['message'] ?? 'Failed to update estimate');
    }
    throw Exception(data['message'] ?? 'Server error (${response.statusCode})');
  }

  /// Delete estimate
  Future<bool> deleteEstimate(String dbId) async {
    final response = await _apiClient.delete('/admin/estimates/$dbId');
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        return true;
      }
      throw Exception(data['message'] ?? 'Failed to delete estimate');
    }
    throw Exception('Server error (${response.statusCode})');
  }

  /// Invalidate coupon cache.
  void invalidateCouponCache() {
    _cachedActiveCoupons = null;
    _couponsCacheTime = null;
  }
}
