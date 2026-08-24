import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:kd_pannel/core/network/api_client.dart';

/// Repository for handling all user, dealer, lead, and sales agent operations.
class UserRepository {
  static final UserRepository _instance = UserRepository._internal();
  factory UserRepository() => _instance;
  UserRepository._internal();

  final ApiClient _apiClient = ApiClient();

  List<Map<String, dynamic>>? _cachedUsers;
  List<Map<String, dynamic>>? _cachedSalesAgents;
  DateTime? _lastCacheTime;
  static const Duration _cacheTtl = Duration(minutes: 3);

  /// Fetch all users and sales agents
  Future<Map<String, List<Map<String, dynamic>>>> fetchDealersData({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh &&
        _cachedUsers != null &&
        _cachedSalesAgents != null &&
        _lastCacheTime != null &&
        DateTime.now().difference(_lastCacheTime!) < _cacheTtl) {
      return {
        'users': _cachedUsers!,
        'salesAgents': _cachedSalesAgents!,
      };
    }

    final results = await Future.wait([
      _apiClient.get('/users'),
      _apiClient.get('/users?role=sales'),
      _apiClient.get('/orders/admin/all'),
    ]);

    final usersRes = results[0];
    final salesRes = results[1];
    final ordersRes = results[2];

    List<Map<String, dynamic>> users = [];
    List<Map<String, dynamic>> salesAgents = [];
    List<Map<String, dynamic>> orders = [];

    if (usersRes.statusCode == 200) {
      final data = jsonDecode(usersRes.body);
      if (data['success'] == true) {
        users = List<Map<String, dynamic>>.from(data['users'] ?? []);
      } else {
        throw Exception(data['message'] ?? 'Failed to parse users');
      }
    } else {
      throw Exception('Failed to load users: ${usersRes.statusCode}');
    }

    if (salesRes.statusCode == 200) {
      final data = jsonDecode(salesRes.body);
      if (data['success'] == true) {
        salesAgents = List<Map<String, dynamic>>.from(data['users'] ?? []);
      } else {
        throw Exception(data['message'] ?? 'Failed to parse sales agents');
      }
    } else {
      throw Exception('Failed to load sales agents: ${salesRes.statusCode}');
    }

    if (ordersRes.statusCode == 200) {
      final data = jsonDecode(ordersRes.body);
      if (data['success'] == true) {
        orders = List<Map<String, dynamic>>.from(data['orders'] ?? []);
      } else {
        throw Exception(data['message'] ?? 'Failed to parse orders');
      }
    } else {
      throw Exception('Failed to load orders: ${ordersRes.statusCode}');
    }

    _cachedUsers = users;
    _cachedSalesAgents = salesAgents;
    _lastCacheTime = DateTime.now();

    return {
      'users': users,
      'salesAgents': salesAgents,
      'orders': orders,
    };
  }

  /// Fetch user profile details by ID
  Future<Map<String, dynamic>> getUserById(String userId) async {
    final res = await _apiClient.get('/users/$userId');
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      if (data['success'] == true && data['user'] != null) {
        return Map<String, dynamic>.from(data['user']);
      }
      throw Exception(data['message'] ?? 'Failed to load user details');
    }
    throw Exception('Server returned ${res.statusCode}');
  }

  /// Fetch user orders
  Future<List<Map<String, dynamic>>> getUserOrders(String userId) async {
    final res = await _apiClient.get(
      '/orders/admin/all?userId=$userId&user=$userId',
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      if (data['success'] == true) {
        final List rawOrders = data['orders'] ?? [];
        final mappedOrders =
            rawOrders.map((o) => Map<String, dynamic>.from(o)).toList();
        final filtered = mappedOrders
            .where(
              (o) =>
                  (o['user'] is Map &&
                      (o['user']['_id']?.toString() == userId.toString() ||
                          o['user']['id']?.toString() == userId.toString())) ||
                  o['user']?.toString() == userId.toString(),
            )
            .toList();
        return filtered.isNotEmpty ? filtered : mappedOrders;
      }
      throw Exception(data['message'] ?? 'Failed to load user orders');
    }
    throw Exception('Server returned ${res.statusCode}');
  }

  /// Create a new Dealer
  Future<Map<String, dynamic>> createDealer({
    required Map<String, dynamic> dealerData,
    List<int>? licenceBytes,
    String? licenceFileName,
    List<int>? shopBytes,
    String? shopFileName,
  }) async {
    http.Response res;
    if (licenceBytes != null || shopBytes != null) {
      final fields = <String, String>{};
      dealerData.forEach((k, v) {
        if (v is Map) {
          fields[k] = jsonEncode(v);
        } else if (v != null) {
          fields[k] = v.toString();
        }
      });

      res = await _apiClient.multipartRequest(
        method: 'POST',
        endpoint: '/users/dealer',
        fields: fields,
        filesBuilder: () {
          final files = <http.MultipartFile>[];
          if (licenceBytes != null && licenceFileName != null) {
            files.add(
              http.MultipartFile.fromBytes(
                'licenceImage',
                licenceBytes,
                filename: licenceFileName,
              ),
            );
          }
          if (shopBytes != null && shopFileName != null) {
            files.add(
              http.MultipartFile.fromBytes(
                'shopImage',
                shopBytes,
                filename: shopFileName,
              ),
            );
          }
          return files;
        },
      );
    } else {
      res = await _apiClient.post('/users/dealer', dealerData);
    }

    final data = jsonDecode(res.body);
    if (res.statusCode == 200 || res.statusCode == 201) {
      if (data['success'] == true) {
        invalidateCache();
        return data;
      }
      throw Exception(data['message'] ?? 'Failed to create dealer');
    }
    throw Exception(data['message'] ?? 'Failed to create dealer: ${res.statusCode}');
  }

  /// Assign agent to user
  Future<void> assignAgent(String userId, String? agentId) async {
    final res = await _apiClient.put('/users/$userId/assign-agent', {
      'assignedAgentId': agentId,
    });
    if (res.statusCode != 200) {
      final data = jsonDecode(res.body);
      throw Exception(data['message'] ?? 'Failed to assign agent');
    }
    invalidateCache();
  }

  /// Update KYC Status
  Future<void> updateKycStatus(
    String userId,
    String status, {
    String reason = '',
  }) async {
    final res = await _apiClient.put('/users/$userId/kyc', {
      'kycStatus': status,
      if (reason.isNotEmpty) 'rejectionReason': reason,
    });
    if (res.statusCode != 200) {
      final data = jsonDecode(res.body);
      throw Exception(data['message'] ?? 'Failed to update KYC');
    }
    invalidateCache();
  }

  /// Block/Unblock user
  Future<void> toggleBlockUser(String userId) async {
    final res = await _apiClient.put('/users/$userId/block', {});
    if (res.statusCode != 200) {
      final data = jsonDecode(res.body);
      throw Exception(data['message'] ?? 'Failed to toggle block status');
    }
    invalidateCache();
  }

  /// Delete user
  Future<void> deleteUser(String userId) async {
    final res = await _apiClient.delete('/users/$userId');
    if (res.statusCode != 200) {
      final data = jsonDecode(res.body);
      throw Exception(data['message'] ?? 'Failed to delete user');
    }
    invalidateCache();
  }

  /// Update lead/dealer notes
  Future<void> updateNotes(String userId, String notes) async {
    final res = await _apiClient.put('/users/$userId', {
      'notes': notes,
      'leadNotes': notes,
    });
    if (res.statusCode != 200) {
      final data = jsonDecode(res.body);
      throw Exception(data['message'] ?? 'Failed to update notes');
    }
    invalidateCache();
  }

  /// Add lead status note
  Future<void> addStatusNote(
    String userId, {
    required String status,
    required String note,
  }) async {
    final res = await _apiClient.put('/users/$userId', {
      'status': status,
      'leadStatus': status,
      'note': note,
      'newNote': note,
    });
    if (res.statusCode != 200) {
      final data = jsonDecode(res.body);
      throw Exception(data['message'] ?? 'Failed to add status note');
    }
    invalidateCache();
  }

  /// Create a sales agent user
  Future<Map<String, dynamic>> createSalesAgent({
    required String firstName,
    required String lastName,
    required String email,
    required String phoneNumber,
    required String password,
  }) async {
    final res = await _apiClient.post('/users/sales', {
      'firstName': firstName.trim(),
      'lastName': lastName.trim(),
      'email': email.trim(),
      'phoneNumber': phoneNumber.trim(),
      'password': password,
    });

    final data = jsonDecode(res.body);
    if (res.statusCode == 201 || res.statusCode == 200) {
      if (data['success'] == true) {
        invalidateCache();
        return data;
      }
      throw Exception(data['message'] ?? 'Failed to create sales agent');
    }
    throw Exception(data['message'] ?? 'Failed to create sales agent');
  }

  /// Update arbitrary user/dealer/lead details
  Future<void> updateUserDetails(
    String userId,
    Map<String, dynamic> updateData,
  ) async {
    final res = await _apiClient.put('/users/$userId', updateData);
    if (res.statusCode != 200) {
      final data = jsonDecode(res.body);
      throw Exception(data['message'] ?? 'Failed to update user details');
    }
    invalidateCache();
  }

  /// Bulk import leads
  Future<Map<String, dynamic>> importLeads(
    List<Map<String, dynamic>> leads,
  ) async {
    final res = await _apiClient.post('/users/bulk', {'users': leads});
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      if (data['success'] == true) {
        invalidateCache();
        return data;
      }
      throw Exception(data['message'] ?? 'Failed to import leads');
    }
    throw Exception('Server returned status code: ${res.statusCode}');
  }

  /// Fetch daily lead statistics
  Future<Map<String, dynamic>> fetchDailyLeadStats(
    DateTime date, {
    String? agentId,
  }) async {
    final dateStr =
        "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    String url = '/users/daily-lead-stats?date=$dateStr';
    if (agentId != null && agentId.isNotEmpty) {
      url += '&agentId=$agentId';
    }

    final res = await _apiClient.get(url);
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      if (data['success'] == true) {
        return Map<String, dynamic>.from(data);
      }
      throw Exception(data['message'] ?? 'Failed to fetch daily lead stats');
    }
    throw Exception('Server returned ${res.statusCode}');
  }

  /// Submit admin KYC on behalf of user
  Future<Map<String, dynamic>> submitAdminKyc({
    required String userId,
    required String userType,
    required String shopName,
    String? gstNumber,
    List<int>? licenceImageBytes,
    String? licenceFileName,
    List<int>? shopImageBytes,
    String? shopFileName,
  }) async {
    final res = await _apiClient.multipartRequest(
      method: 'POST',
      endpoint: '/users/$userId/kyc',
      fields: {
        'userType': userType,
        'shopName': shopName,
        'gstNumber': gstNumber ?? '',
      },
      filesBuilder: () {
        final files = <http.MultipartFile>[];
        if (licenceImageBytes != null && licenceFileName != null) {
          files.add(
            http.MultipartFile.fromBytes(
              'licenceImage',
              licenceImageBytes,
              filename: licenceFileName,
            ),
          );
        }
        if (shopImageBytes != null && shopFileName != null) {
          files.add(
            http.MultipartFile.fromBytes(
              'shopImage',
              shopImageBytes,
              filename: shopFileName,
            ),
          );
        }
        return files;
      },
    );

    final data = jsonDecode(res.body);
    if (res.statusCode == 200 || res.statusCode == 201) {
      if (data['success'] == true) {
        invalidateCache();
        return data;
      }
      throw Exception(data['message'] ?? 'Failed to upload KYC');
    }
    throw Exception(data['message'] ?? 'Server error: ${res.statusCode}');
  }

  /// Fetch deleted trash users
  Future<Map<String, dynamic>> fetchTrashUsers({
    required String kycStatus,
    required int page,
    required int limit,
    String search = '',
    String startDate = '',
    String endDate = '',
  }) async {
    final searchFilter = search.isNotEmpty ? '&search=${Uri.encodeComponent(search)}' : '';
    final dateFilter = (startDate.isNotEmpty && endDate.isNotEmpty) ? '&startDate=$startDate&endDate=$endDate' : '';
    final url = '/users?trash=true&role=user&kycStatus=$kycStatus&page=$page&limit=$limit$searchFilter$dateFilter';

    final res = await _apiClient.get(url);
    final data = jsonDecode(res.body);
    if (res.statusCode == 200 && data['success'] == true) {
      return data;
    }
    throw Exception(data['message'] ?? 'Failed to load trash users (${res.statusCode})');
  }

  /// Restore user from trash
  Future<bool> restoreUser(String userId) async {
    final res = await _apiClient.put('/users/$userId/restore', {});
    final data = jsonDecode(res.body);
    if (res.statusCode == 200 && data['success'] == true) {
      invalidateCache();
      return true;
    }
    throw Exception(data['message'] ?? 'Failed to restore user');
  }

  /// Permanently delete user
  Future<bool> permanentlyDeleteUser(String userId) async {
    final res = await _apiClient.delete('/users/$userId/permanent');
    final data = jsonDecode(res.body);
    if (res.statusCode == 200 && data['success'] == true) {
      invalidateCache();
      return true;
    }
    throw Exception(data['message'] ?? 'Failed to permanently delete user');
  }

  /// Invalidate cache
  void invalidateCache() {
    _cachedUsers = null;
    _cachedSalesAgents = null;
    _lastCacheTime = null;
  }
}
