import 'package:equatable/equatable.dart';
import 'package:kd_pannel/core/auth/auth_service.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, failure }

class AuthState extends Equatable {
  final AuthStatus status;
  final UserRole selectedRole;
  final UserRole? authenticatedRole;
  final String? userId;
  final String? email;
  final String? userName;
  final String? errorMessage;

  const AuthState({
    this.status = AuthStatus.initial,
    this.selectedRole = UserRole.admin,
    this.authenticatedRole,
    this.userId,
    this.email,
    this.userName,
    this.errorMessage,
  });

  bool get isLoading => status == AuthStatus.loading;
  bool get isAuthenticated => status == AuthStatus.authenticated;

  AuthState copyWith({
    AuthStatus? status,
    UserRole? selectedRole,
    UserRole? authenticatedRole,
    String? userId,
    String? email,
    String? userName,
    String? errorMessage,
    bool clearError = false,
    bool clearUser = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      selectedRole: selectedRole ?? this.selectedRole,
      authenticatedRole: clearUser ? null : (authenticatedRole ?? this.authenticatedRole),
      userId: clearUser ? null : (userId ?? this.userId),
      email: clearUser ? null : (email ?? this.email),
      userName: clearUser ? null : (userName ?? this.userName),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
        status,
        selectedRole,
        authenticatedRole,
        userId,
        email,
        userName,
        errorMessage,
      ];
}
