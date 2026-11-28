import 'package:equatable/equatable.dart';
import 'package:kd_pannel/core/auth/auth_service.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class AuthRoleSelectedEvent extends AuthEvent {
  final UserRole role;
  const AuthRoleSelectedEvent(this.role);

  @override
  List<Object?> get props => [role];
}

class AuthLoginRequestedEvent extends AuthEvent {
  final String email;
  final String password;
  final UserRole role;
  final bool rememberMe;

  const AuthLoginRequestedEvent({
    required this.email,
    required this.password,
    required this.role,
    this.rememberMe = true,
  });

  @override
  List<Object?> get props => [email, password, role, rememberMe];
}

class AuthSessionRestoredEvent extends AuthEvent {
  const AuthSessionRestoredEvent();
}

class AuthResetEvent extends AuthEvent {
  const AuthResetEvent();
}

class AuthClearErrorEvent extends AuthEvent {
  const AuthClearErrorEvent();
}
