import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kd_pannel/app_theme.dart';
import 'package:kd_pannel/features/auth/presentation/pages/login_page.dart';
import 'package:kd_pannel/features/admin/presentation/pages/dealer_profile_page.dart';
import 'package:kd_pannel/features/admin/presentation/pages/lead_profile_page.dart';
import 'package:kd_pannel/features/admin/presentation/pages/order_details_page.dart';
import 'package:kd_pannel/features/admin/presentation/pages/sales_coupon_page.dart';
import 'package:kd_pannel/features/shared/widgets/main_layout.dart';
import 'package:kd_pannel/features/admin/presentation/pages/team_member_profile_page.dart';
import 'package:kd_pannel/features/admin/presentation/pages/trash_page.dart';
import 'package:kd_pannel/features/admin/presentation/pages/estimate_generator_page.dart';
import 'package:kd_pannel/features/admin/presentation/pages/whatsapp_crm_page.dart';
import 'package:kd_pannel/features/admin/presentation/pages/call_logs_page.dart';
import 'package:kd_pannel/core/auth/auth_service.dart';
import 'package:kd_pannel/core/utils/navigation_service.dart';
import 'package:kd_pannel/core/network/websocket_service.dart';
import 'package:kd_pannel/core/services/analytics_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/dealers_bloc.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/dealers_event.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/orders_bloc.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/orders_event.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/leads_bloc.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/leads_event.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/products_bloc.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/products_event.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/audit_logs_bloc.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/audit_logs_event.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/push_campaigns_bloc.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/push_campaigns_event.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/whatsapp_crm_bloc.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/whatsapp_crm_event.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/call_logs_bloc.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/call_logs_event.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/retargeting_bloc.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/retargeting_event.dart';
import 'package:kd_pannel/features/admin/presentation/cubit/engagement_hub_cubit.dart';

import 'package:kd_pannel/features/shared/bloc/notifications_cubit.dart';

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

  // ── Global Error Boundaries for Web Stability ──────────────────────────────
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('[Flutter Global Error]: ${details.exceptionAsString()}');
  };

  ErrorWidget.builder = (FlutterErrorDetails errorDetails) {
    return Material(
      color: const Color(0xFFF8FAFC),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 36),
              const SizedBox(height: 12),
              Text(
                'Component Render Recovery',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: const Color(0xFF1E293B)),
              ),
              const SizedBox(height: 6),
              Text(
                'An isolated render issue occurred in this section. The rest of the panel remains active.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(fontSize: 12.5, color: const Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      ),
    );
  };

  // Load brand images into memory buffer
  await AppCache.preload();

  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider<DealersBloc>(
          create: (context) =>
              DealersBloc()..add(const FetchDealersDataEvent()),
        ),
        BlocProvider<OrdersBloc>(
          create: (context) => OrdersBloc()..add(const FetchOrdersEvent()),
        ),
        BlocProvider<LeadsBloc>(
          create: (context) => LeadsBloc()..add(const FetchLeadsDataEvent()),
        ),
        BlocProvider<ProductsBloc>(
          create: (context) => ProductsBloc()..add(const LoadProductsEvent()),
        ),
        BlocProvider<AuditLogsBloc>(
          create: (context) =>
              AuditLogsBloc()..add(const FetchAuditLogsInitial()),
        ),
        BlocProvider<PushCampaignsBloc>(
          create: (context) =>
              PushCampaignsBloc()..add(const FetchPushCampaignsEvent()),
        ),
        BlocProvider<WhatsAppCrmBloc>(
          create: (context) =>
              WhatsAppCrmBloc()..add(const FetchConversationsEvent()),
        ),
        BlocProvider<CallLogsBloc>(
          create: (context) =>
              CallLogsBloc()..add(const FetchCallLogsEvent()),
        ),
        BlocProvider<RetargetingBloc>(
          create: (context) =>
              RetargetingBloc()..add(const FetchCohortsEvent()),
        ),
        BlocProvider<NotificationsCubit>(
          create: (context) =>
              NotificationsCubit()..fetchNotifications(isInitial: true),
        ),
        BlocProvider<EngagementHubCubit>(
          create: (context) => EngagementHubCubit(),
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
        _initialRoute = '/dashboard';
        WebSocketService().connect();
        try {
          context.read<DealersBloc>().add(const FetchDealersDataEvent(forceRefresh: true));
          context.read<LeadsBloc>().add(const FetchLeadsDataEvent(forceRefresh: true));
          context.read<OrdersBloc>().add(const FetchOrdersEvent());
        } catch (_) {}
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
        '/alerts': (context) => const MainLayout(),
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
        '/engagement': (context) => const MainLayout(),
        '/marketing': (context) => const MainLayout(),
        '/push-campaigns': (context) => const MainLayout(),
        '/campaigns': (context) => const MainLayout(),
        '/whatsapp': (context) => const MainLayout(child: WhatsAppCrmPage()),
        '/support': (context) => const MainLayout(child: WhatsAppCrmPage()),
        '/calls': (context) => const MainLayout(child: CallLogsPage()),
        '/call-recordings': (context) => const MainLayout(child: CallLogsPage()),
        '/estimates': (context) => const MainLayout(child: EstimateGeneratorPage()),
        '/coupons': (context) => const MainLayout(child: SalesCouponPage()),
        '/team': (context) => const MainLayout(),
        '/team/profile': (context) =>
            const MainLayout(child: TeamMemberProfilePage()),
        '/logs': (context) => const MainLayout(),
        '/admin/logs': (context) => const MainLayout(),
        '/trash': (context) => const MainLayout(child: TrashPage()),
        '/reports': (context) => const MainLayout(
          child: Scaffold(body: Center(child: Text('Reports'))),
        ),
        '/settings': (context) => const MainLayout(
          child: Scaffold(body: Center(child: Text('Settings'))),
        ),
        // Sales Routes
        '/sales/dashboard': (context) => const MainLayout(),
        '/sales/coupons': (context) =>
            const MainLayout(child: SalesCouponPage()),
        '/sales/estimates': (context) =>
            const MainLayout(child: EstimateGeneratorPage()),
        '/sales/customer': (context) => const MainLayout(),
        '/customer': (context) => const MainLayout(),
      },
      onGenerateRoute: (settings) {
        final uri = Uri.tryParse(settings.name ?? '');
        if (uri != null) {
          final path = uri.path;
          switch (path) {
            case '/orders/details':
              return MaterialPageRoute(
                settings: settings,
                builder: (_) => const MainLayout(child: OrderDetailsPage()),
              );
            case '/dealers/profile':
              return MaterialPageRoute(
                settings: settings,
                builder: (_) => const MainLayout(child: DealerProfilePage()),
              );
            case '/leads/profile':
              return MaterialPageRoute(
                settings: settings,
                builder: (_) => const MainLayout(child: LeadProfilePage()),
              );
            case '/team/profile':
              return MaterialPageRoute(
                settings: settings,
                builder: (_) => const MainLayout(child: TeamMemberProfilePage()),
              );
            case '/trash':
              return MaterialPageRoute(
                settings: settings,
                builder: (_) => const MainLayout(child: TrashPage()),
              );
            case '/sales/estimates':
              return MaterialPageRoute(
                settings: settings,
                builder: (_) => const MainLayout(child: EstimateGeneratorPage()),
              );
            case '/support':
              return MaterialPageRoute(
                settings: settings,
                builder: (_) => const MainLayout(child: WhatsAppCrmPage()),
              );
            case '/calls':
              return MaterialPageRoute(
                settings: settings,
                builder: (_) => const MainLayout(child: CallLogsPage()),
              );
            case '/sales/coupons':
              return MaterialPageRoute(
                settings: settings,
                builder: (_) => const MainLayout(child: SalesCouponPage()),
              );
            default:
              return MaterialPageRoute(
                settings: settings,
                builder: (_) => const MainLayout(),
              );
          }
        }
        return null;
      },
    );
  }
}
