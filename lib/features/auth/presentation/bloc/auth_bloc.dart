import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kd_pannel/core/auth/auth_service.dart';
import 'package:kd_pannel/core/network/websocket_service.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthService _authService;

  AuthBloc({AuthService? authService})
      : _authService = authService ?? AuthService(),
        super(const AuthState()) {
    on<AuthRoleSelectedEvent>(_onRoleSelected);
    on<AuthLoginRequestedEvent>(_onLoginRequested);
    on<AuthSessionRestoredEvent>(_onSessionRestored);
    on<AuthResetEvent>(_onReset);
    on<AuthClearErrorEvent>(_onClearError);
  }

  void _onRoleSelected(AuthRoleSelectedEvent event, Emitter<AuthState> emit) {
    emit(state.copyWith(
      selectedRole: event.role,
      clearError: true,
    ));
  }

  Future<void> _onLoginRequested(
    AuthLoginRequestedEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(
      status: AuthStatus.loading,
      selectedRole: event.role,
      clearError: true,
    ));

    final success = await _authService.login(
      email: event.email,
      password: event.password,
      role: event.role,
      rememberMe: event.rememberMe,
    );

    if (success && _authService.currentUserRole != null) {
      WebSocketService().connect();
      emit(state.copyWith(
        status: AuthStatus.authenticated,
        authenticatedRole: _authService.currentUserRole,
        userId: _authService.currentUserId,
        email: _authService.currentUserEmail,
        userName: _authService.currentUserName,
        clearError: true,
      ));
    } else {
      emit(state.copyWith(
        status: AuthStatus.failure,
        errorMessage: _authService.lastError ??
            'Authorization failed. Please verify your credentials.',
      ));
    }
  }

  void _onSessionRestored(
    AuthSessionRestoredEvent event,
    Emitter<AuthState> emit,
  ) {
    final role = _authService.currentUserRole;
    if (role != null && _authService.currentUserId != null) {
      emit(state.copyWith(
        status: AuthStatus.authenticated,
        selectedRole: role,
        authenticatedRole: role,
        userId: _authService.currentUserId,
        email: _authService.currentUserEmail,
        userName: _authService.currentUserName,
        clearError: true,
      ));
    } else {
      emit(state.copyWith(
        status: AuthStatus.unauthenticated,
        clearUser: true,
        clearError: true,
      ));
    }
  }

  void _onReset(AuthResetEvent event, Emitter<AuthState> emit) {
    emit(AuthState(
      status: AuthStatus.unauthenticated,
      selectedRole: state.selectedRole,
    ));
  }

  void _onClearError(AuthClearErrorEvent event, Emitter<AuthState> emit) {
    emit(state.copyWith(clearError: true));
  }
}
