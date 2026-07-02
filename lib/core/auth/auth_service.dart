import 'dart:convert';
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
  String? _lastError;
  String? _sessionId;
  bool _isInitialized = false;

  UserRole? get currentUserRole => _currentUserRole;
  String? get currentUserId => _currentUserId;
  String? get currentUserEmail => _currentUserEmail;
  String? get currentUserName => _currentUserName;
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
    } catch (_) {}
    _isInitialized = true;
  }

  Future<bool> login({
    required String email,
    required String password,
    required UserRole role,
    bool rememberMe = true,
  }) async {
    _lastError = null;
    try {
      final response = await ApiClient().post('/auth/admin/login', {
        'email': email,
        'password': password,
        'deviceId': 'admin-console',
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

          _currentUserId = userIdStr;
          _currentUserEmail = userEmailStr;
          _currentUserName = userName;

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
    _lastError = null;
    ApiClient().clearCache();
    ApiClient().clearTokens();
    WebSocketService().disconnect();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('kd_user_id');
      await prefs.remove('kd_user_email');
      await prefs.remove('kd_user_name');
    } catch (_) {}
  }

  bool get isAdmin => _currentUserRole == UserRole.admin;
  bool get isSales => _currentUserRole == UserRole.sales;
}
