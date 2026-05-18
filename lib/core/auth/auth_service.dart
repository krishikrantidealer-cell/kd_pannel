enum UserRole { admin, sales }

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  UserRole? _currentUserRole;

  UserRole? get currentUserRole => _currentUserRole;

  void login(UserRole role) {
    _currentUserRole = role;
  }

  void logout() {
    _currentUserRole = null;
  }

  bool get isAdmin => _currentUserRole == UserRole.admin;
  bool get isSales => _currentUserRole == UserRole.sales;
}
