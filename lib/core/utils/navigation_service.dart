import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kd_pannel/core/auth/auth_service.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/orders_bloc.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/orders_event.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/leads_bloc.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/leads_event.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/dealers_bloc.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/dealers_event.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/products_bloc.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/products_event.dart';

class NavigationService {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  static final GlobalKey<ScaffoldMessengerState> messengerKey = GlobalKey<ScaffoldMessengerState>();

  static bool _isRedirectingToLogin = false;
  static bool get isRedirectingToLogin => _isRedirectingToLogin;

  static void navigateToLogin({bool showSessionExpiredMessage = true}) {
    if (_isRedirectingToLogin) return;
    _isRedirectingToLogin = true;

    // Clear local session state and telemetry
    AuthService().logout();

    // Reset all global Blocs to prevent data leaking between users
    final context = navigatorKey.currentContext;
    if (context != null) {
      try {
        context.read<OrdersBloc>().add(ResetOrdersEvent());
      } catch (e) {
        debugPrint('[NavigationService] OrdersBloc reset skipped: $e');
      }
      try {
        context.read<LeadsBloc>().add(ResetLeadsEvent());
      } catch (e) {
        debugPrint('[NavigationService] LeadsBloc reset skipped: $e');
      }
      try {
        context.read<DealersBloc>().add(ResetDealersEvent());
      } catch (e) {
        debugPrint('[NavigationService] DealersBloc reset skipped: $e');
      }
      try {
        context.read<ProductsBloc>().add(ResetProductsEvent());
      } catch (e) {
        debugPrint('[NavigationService] ProductsBloc reset skipped: $e');
      }
    }

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
