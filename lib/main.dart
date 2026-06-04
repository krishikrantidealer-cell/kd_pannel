import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kd_pannel/app_theme.dart';
import 'package:kd_pannel/features/auth/presentation/pages/login_page.dart';

import 'package:kd_pannel/features/admin/presentation/pages/lead_profile_page.dart';
import 'package:kd_pannel/features/shared/widgets/main_layout.dart';
import 'package:kd_pannel/features/admin/presentation/pages/orders_page.dart';

import 'dart:ui' as ui;
import 'package:flutter/services.dart';

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

  // Pre-load Outfit fonts to prevent layout shift / font swap on restart
  await GoogleFonts.pendingFonts([
    GoogleFonts.outfit(fontWeight: FontWeight.w300),
    GoogleFonts.outfit(fontWeight: FontWeight.w400),
    GoogleFonts.outfit(fontWeight: FontWeight.w500),
    GoogleFonts.outfit(fontWeight: FontWeight.w600),
    GoogleFonts.outfit(fontWeight: FontWeight.w700),
    GoogleFonts.outfit(fontWeight: FontWeight.w800),
    GoogleFonts.outfit(fontWeight: FontWeight.w900),
  ]);

  // Preload brand images synchronously into memory buffer before running the app
  await AppCache.preload();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KrishiDealer Admin Panel',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginPage(),

        // Admin Routes
        '/dashboard': (context) => const MainLayout(),
        '/leads': (context) => const MainLayout(),
        '/leads/profile': (context) =>
            const MainLayout(child: LeadProfilePage()),
        '/dealers': (context) => const MainLayout(),
        '/orders': (context) => const MainLayout(child: OrdersPage()),
        '/products': (context) => const MainLayout(),
        '/marketing': (context) => const MainLayout(
          child: Scaffold(body: Center(child: Text('Marketing'))),
        ),
        '/support': (context) => const MainLayout(),
        '/team': (context) => const MainLayout(
          child: Scaffold(body: Center(child: Text('Team'))),
        ),
        '/reports': (context) => const MainLayout(
          child: Scaffold(body: Center(child: Text('Reports'))),
        ),
        '/settings': (context) => const MainLayout(
          child: Scaffold(body: Center(child: Text('Settings'))),
        ),
        // Sales Routes
        '/sales/dashboard': (context) => const MainLayout(),
      },
    );
  }
}
