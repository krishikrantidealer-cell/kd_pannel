import 'package:flutter/material.dart';
import 'package:kd_pannel/core/auth/auth_service.dart';

class NavigationService {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  static final GlobalKey<ScaffoldMessengerState> messengerKey = GlobalKey<ScaffoldMessengerState>();

  static bool _isRedirectingToLogin = false;

  static void navigateToLogin({bool showSessionExpiredMessage = true}) {
    if (_isRedirectingToLogin) return;
    _isRedirectingToLogin = true;

    // Clear local session state synchronously
    AuthService().clearLocalSessionState();

    // Redirect to login screen and clear the navigation stack
    navigatorKey.currentState?.pushNamedAndRemoveUntil(
      '/login',
      (route) => false,
    );

    if (showSessionExpiredMessage) {
      messengerKey.currentState?.clearSnackBars();
      messengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text('Your session has expired or your account has been updated. Please log in again.'),
          backgroundColor: Colors.redAccent,
          duration: Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    // Reset redirect flag after a small delay to allow transition to complete
    Future.delayed(const Duration(seconds: 2), () {
      _isRedirectingToLogin = false;
    });
  }
}
