import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kd_pannel/app_theme.dart';
import 'package:kd_pannel/features/auth/presentation/pages/login_page.dart';
import 'package:kd_pannel/features/admin/presentation/pages/dealer_profile_page.dart';
import 'package:kd_pannel/features/admin/presentation/pages/lead_profile_page.dart';
import 'package:kd_pannel/features/admin/presentation/pages/order_details_page.dart';
import 'package:kd_pannel/features/admin/presentation/pages/sales_coupon_page.dart';
import 'package:kd_pannel/features/shared/widgets/main_layout.dart';
import 'package:kd_pannel/core/auth/auth_service.dart';
import 'package:kd_pannel/core/utils/navigation_service.dart';
import 'package:kd_pannel/core/network/websocket_service.dart';
import 'package:kd_pannel/core/services/analytics_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/dealers_bloc.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/orders_bloc.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/orders_event.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/leads_bloc.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/leads_event.dart';

import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';

class AppCache {
  static ui.Image? logoImage;
  static ui.Image? logoCopyImage;
  static ui.Image? adminImage;

  static Future<void> preload() async {
    try {
      final data = await rootBundle.load('assets/images/logo.png');
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      logoImage = (await codec.getNextFrame()).image;
    } catch (_) {}

    try {
      final data = await rootBundle.load('assets/images/logo_copy.png');
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      logoCopyImage = (await codec.getNextFrame()).image;
    } catch (_) {}

    try {
      final data = await rootBundle.load('assets/images/admin.png');
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      adminImage = (await codec.getNextFrame()).image;
    } catch (_) {}
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load brand images into memory buffer
  await AppCache.preload();

  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider<DealersBloc>(
          create: (context) => DealersBloc(),
        ),
        BlocProvider<OrdersBloc>(
          create: (context) => OrdersBloc()..add(const FetchOrdersEvent()),
        ),
        BlocProvider<LeadsBloc>(
          create: (context) => LeadsBloc()..add(const FetchLeadsDataEvent()),
        ),
      ],
      child: const MyAppWrapper(),
    ),
  );
}

class MyAppWrapper extends StatefulWidget {
  const MyAppWrapper({super.key});

  @override
  State<MyAppWrapper> createState() => _MyAppWrapperState();
}

class _MyAppWrapperState extends State<MyAppWrapper> {
  bool _isInitialized = false;
  String _initialRoute = '/login';

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    // 1. Core Services
    await AuthService().init();
    await AnalyticsService().init();

    // 2. Session Recovery
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('kd_access_token');
      final role = prefs.getString('kd_user_role');
      final userId = prefs.getString('kd_user_id');
      
      if (token != null && role != null && userId != null) {
        _initialRoute = role == 'sales' ? '/leads' : '/dashboard';
        WebSocketService().connect();
      }
    } catch (_) {}

    // 3. Fonts (Non-blocking)
    GoogleFonts.pendingFonts([
      GoogleFonts.outfit(fontWeight: FontWeight.w400),
      GoogleFonts.outfit(fontWeight: FontWeight.w700),
    ]).catchError((_) => []);

    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: NavigationService.navigatorKey,
      scaffoldMessengerKey: NavigationService.messengerKey,
      title: 'KrishiDealer Portal',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        FlutterQuillLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en', '')],
      builder: (context, child) {
        if (!_isInitialized) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF1B5E20)),
            ),
          );
        }
        return child!;
      },
      initialRoute: '/',
      routes: {
        '/': (context) {
          if (!_isInitialized) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(color: Color(0xFF1B5E20)),
              ),
            );
          }
          // Once initialized, we use the calculated initial route
          // But since we are already at '/', we can just return the correct widget
          final initialRoute = _initialRoute;
          if (initialRoute == '/leads') return const MainLayout();
          if (initialRoute == '/dashboard') return const MainLayout();
          return const LoginPage();
        },
        '/login': (context) => const LoginPage(),

        // Admin Routes
        '/dashboard': (context) => const MainLayout(),
        '/leads': (context) => const MainLayout(),
        '/leads/profile': (context) =>
            const MainLayout(child: LeadProfilePage()),
        '/dealers': (context) => const MainLayout(),
        '/dealers/profile': (context) =>
            const MainLayout(child: DealerProfilePage()),
        '/orders': (context) => const MainLayout(),
        '/orders/details': (context) =>
            const MainLayout(child: OrderDetailsPage()),
        '/products': (context) => const MainLayout(),
        '/marketing': (context) => const MainLayout(),
        '/support': (context) => const MainLayout(),
        '/team': (context) => const MainLayout(),
        '/reports': (context) => const MainLayout(
          child: Scaffold(body: Center(child: Text('Reports'))),
        ),
        '/settings': (context) => const MainLayout(
          child: Scaffold(body: Center(child: Text('Settings'))),
        ),
        // Sales Routes
        '/sales/dashboard': (context) => const MainLayout(),
        '/sales/coupons': (context) => const MainLayout(child: SalesCouponPage()),
      },
    );
  }
}

// Remove the old MyApp class as it is now merged into MyAppWrapper
