import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:kd_pannel/core/network/api_client.dart';
import 'package:kd_pannel/core/network/websocket_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kd_pannel/core/services/analytics_service.dart';

enum UserRole { admin, sales }

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  UserRole? _currentUserRole;
  String? _currentUserId;
  String? _currentUserEmail;
  String? _currentUserName;
  double? _monthlyTarget;
  Map<String, dynamic>? _permissions;
  String? _lastError;
  String? _sessionId;
  bool _isInitialized = false;

  UserRole? get currentUserRole => _currentUserRole;
  String? get currentUserId => _currentUserId;
  String? get currentUserEmail => _currentUserEmail;
  String? get currentUserName => _currentUserName;
  double? get monthlyTarget => _monthlyTarget;
  Map<String, dynamic>? get permissions => _permissions;
  String? get lastError => _lastError;
  String? get sessionId => _sessionId;
  bool get isInitialized => _isInitialized;

  Future<void> init() async {
    _sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    try {
      final prefs = await SharedPreferences.getInstance();
      final roleStr = prefs.getString('kd_user_role');
      if (roleStr == 'admin') {
        _currentUserRole = UserRole.admin;
      } else if (roleStr == 'sales') {
        _currentUserRole = UserRole.sales;
      }
      _currentUserId = prefs.getString('kd_user_id');
      _currentUserEmail = prefs.getString('kd_user_email');
      _currentUserName = prefs.getString('kd_user_name');
      _monthlyTarget = prefs.getDouble('kd_monthly_target');
      final permStr = prefs.getString('kd_user_permissions');
      if (permStr != null && permStr.isNotEmpty) {
        _permissions = jsonDecode(permStr);
      }
    } catch (_) {}
    _isInitialized = true;
  }

  Future<String> _getOrCreateDeviceId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? id = prefs.getString('kd_client_device_id');
      if (id == null || id.isEmpty) {
        id = 'admin-web-${DateTime.now().millisecondsSinceEpoch}-${(1000 + (DateTime.now().microsecond % 9000))}';
        await prefs.setString('kd_client_device_id', id);
      }
      return id;
    } catch (_) {
      return 'admin-web-console';
    }
  }

  Future<bool> login({
    required String email,
    required String password,
    required UserRole role,
    bool rememberMe = true,
  }) async {
    _lastError = null;
    try {
      final deviceId = await _getOrCreateDeviceId();
      final response = await ApiClient().post('/auth/admin/login', {
        'email': email,
        'password': password,
        'deviceId': deviceId,
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final accessToken = data['accessToken'];
          final refreshToken = data['refreshToken'];
          await ApiClient().setTokens(accessToken, refreshToken, persistent: rememberMe);
          
          final userRoleStr = data['user']['role'];
          final userIdStr = data['user']['id'] ?? data['user']['_id'];
          final userEmailStr = data['user']['email'];
          final firstName = data['user']['firstName'] ?? '';
          final lastName = data['user']['lastName'] ?? '';
          final userName = '$firstName $lastName'.trim();
          final monthlyTarget = (data['user']['monthlyTarget'] as num?)?.toDouble();
          final perms = data['user']['permissions'] as Map<String, dynamic>?;

          _currentUserId = userIdStr;
          _currentUserEmail = userEmailStr;
          _currentUserName = userName;
          _monthlyTarget = monthlyTarget;
          _permissions = perms;

          final prefs = await SharedPreferences.getInstance();
          if (userIdStr != null) {
            await prefs.setString('kd_user_id', userIdStr);
          }
          if (userEmailStr != null) {
            await prefs.setString('kd_user_email', userEmailStr);
          }
          if (userName.isNotEmpty) {
            await prefs.setString('kd_user_name', userName);
          }
          if (monthlyTarget != null) {
            await prefs.setDouble('kd_monthly_target', monthlyTarget);
          }
          if (perms != null) {
            await prefs.setString('kd_user_permissions', jsonEncode(perms));
          }
          if (rememberMe) {
            await prefs.setString('kd_user_role', userRoleStr);
          }

          if (userRoleStr == 'admin') {
            _currentUserRole = UserRole.admin;
          } else if (userRoleStr == 'sales') {
            _currentUserRole = UserRole.sales;
          } else {
            _currentUserRole = null;
            _lastError = 'Access denied: invalid user role "$userRoleStr"';
            print('[AuthService] Login failed: $_lastError');
            return false;
          }

          // Enforce role check: Ensure the authenticated user matches the selected role in the UI
          if (_currentUserRole != role) {
            final String selectedRoleName = role == UserRole.admin ? 'Admin' : 'Sales';
            final String actualRoleName = _currentUserRole == UserRole.admin ? 'Admin' : 'Sales';
            _lastError = 'Access denied: Your account has $actualRoleName privileges, but you selected $selectedRoleName login.';
            _currentUserRole = null;
            return false;
          }

          // Log success to DB event tracking
          AnalyticsService().logEvent('login_success', properties: {
            'email': userEmailStr,
            'role': userRoleStr,
            'details': 'User authenticated successfully',
          });

          return true;
        }
      }
      
      try {
        final err = jsonDecode(response.body);
        _lastError = err['message'] ?? 'Authorization failed';
      } catch (_) {
        _lastError = 'Server returned status ${response.statusCode}';
      }
      print('[AuthService] Login request failed. Status: ${response.statusCode}, Body: ${response.body}');
      return false;
    } catch (e) {
      _lastError = 'Connection error: $e';
      print('Login error: $e');
      return false;
    }
  }

  Future<void> logout() async {
    try {
      await AnalyticsService().handleLogout();
    } catch (e) {
      print('[AuthService] Telemetry cleanup failed: $e');
    }
    await clearLocalSessionState();
  }

  Future<void> clearLocalSessionState() async {
    _currentUserRole = null;
    _currentUserId = null;
    _currentUserEmail = null;
    _currentUserName = null;
    _permissions = null;
    _lastError = null;
    ApiClient().clearCache();
    ApiClient().clearTokens();
    WebSocketService().disconnect();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('kd_user_id');
      await prefs.remove('kd_user_email');
      await prefs.remove('kd_user_name');
      await prefs.remove('kd_user_permissions');
      await prefs.remove('cached_last_agent');
    } catch (_) {}
  }

  bool get isAdmin => _currentUserRole == UserRole.admin;
  bool get isSales => _currentUserRole == UserRole.sales;

  bool _toBool(dynamic val, {bool defaultValue = false}) {
    if (val == null) return defaultValue;
    if (val is bool) return val;
    if (val is num) return val == 1;
    if (val is String) {
      final s = val.toLowerCase().trim();
      if (s == 'true' || s == '1') return true;
      if (s == 'false' || s == '0') return false;
    }
    return defaultValue;
  }

  void updatePermissions(Map<String, dynamic> perms) {
    _permissions = perms;
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('kd_user_permissions', jsonEncode(perms));
    }).catchError((_) {});
  }

  /// Check lead permission for current sales agent (Admins always have full permission)
  bool hasLeadPermission(String action) {
    if (isAdmin) return true;
    if (_permissions == null) return action != 'reassign';
    final leadPerms = _permissions?['lead'] ?? _permissions?['leads'];
    if (leadPerms is Map) {
      if (leadPerms.containsKey(action)) {
        return _toBool(leadPerms[action], defaultValue: action != 'reassign');
      }
    }
    return action != 'reassign';
  }

  /// Check dealer permission for current sales agent (Admins always have full permission)
  bool hasDealerPermission(String action) {
    if (isAdmin) return true;
    if (_permissions == null) return action != 'reassign';
    final dealerPerms = _permissions?['dealer'] ?? _permissions?['dealers'];
    if (dealerPerms is Map) {
      if (dealerPerms.containsKey(action)) {
        return _toBool(dealerPerms[action], defaultValue: action != 'reassign');
      }
    }
    return action != 'reassign';
  }

  Future<void> refreshProfile() async {
    try {
      final res = await ApiClient().get('/users/profile');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['user'] != null) {
          final user = data['user'];
          final firstName = user['firstName'] ?? '';
          final lastName = user['lastName'] ?? '';
          final userName = '$firstName $lastName'.trim();
          final monthlyTarget = (user['monthlyTarget'] as num?)?.toDouble();
          final perms = user['permissions'] as Map<String, dynamic>?;
          
          _currentUserName = userName;
          _monthlyTarget = monthlyTarget;
          _permissions = perms;
          
          final prefs = await SharedPreferences.getInstance();
          if (userName.isNotEmpty) {
            await prefs.setString('kd_user_name', userName);
          }
          if (monthlyTarget != null) {
            await prefs.setDouble('kd_monthly_target', monthlyTarget);
          }
          if (perms != null) {
            await prefs.setString('kd_user_permissions', jsonEncode(perms));
          }
        }
      }
    } catch (e) {
      debugPrint('[AuthService] Failed to refresh profile: $e');
    }
  }

  /// Reset current user's password.
  Future<Map<String, dynamic>> resetPassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final response = await ApiClient().post('/auth/reset-password', {
      'currentPassword': currentPassword.trim(),
      'newPassword': newPassword.trim(),
    });

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return {'success': true, 'message': data['message'] ?? 'Password reset successfully'};
    }
    return {
      'success': false,
      'message': data['message'] ?? 'Incorrect current password or server error (${response.statusCode})',
    };
  }
}
