import 'dart:convert';
import 'package:kd_pannel/core/network/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum UserRole { admin, sales }

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  UserRole? _currentUserRole;

  UserRole? get currentUserRole => _currentUserRole;

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final roleStr = prefs.getString('kd_user_role');
      if (roleStr == 'admin') {
        _currentUserRole = UserRole.admin;
      } else if (roleStr == 'sales') {
        _currentUserRole = UserRole.sales;
      }
    } catch (_) {}
  }

  Future<bool> login({
    required String email,
    required String password,
    required UserRole role,
    bool rememberMe = true,
  }) async {
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
          if (rememberMe) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('kd_user_role', userRoleStr);
          }

          if (userRoleStr == 'admin') {
            _currentUserRole = UserRole.admin;
          } else if (userRoleStr == 'sales') {
            _currentUserRole = UserRole.sales;
          } else {
            _currentUserRole = null;
            return false;
          }
          return true;
        }
      }
      return false;
    } catch (e) {
      print('Login error: $e');
      return false;
    }
  }

  Future<void> logout() async {
    _currentUserRole = null;
    await ApiClient().clearTokens();
  }

  bool get isAdmin => _currentUserRole == UserRole.admin;
  bool get isSales => _currentUserRole == UserRole.sales;
}
