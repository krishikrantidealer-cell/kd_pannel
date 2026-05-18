import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kd_pannel/app_theme.dart';
import 'package:kd_pannel/features/auth/presentation/pages/login_page.dart';
import 'package:kd_pannel/features/admin/presentation/pages/dashboard_page.dart';
import 'package:kd_pannel/features/admin/presentation/pages/dealer_management_page.dart';
import 'package:kd_pannel/features/admin/presentation/pages/dealer_profile_page.dart';
import 'package:kd_pannel/features/admin/presentation/pages/lead_profile_page.dart';
import 'package:kd_pannel/features/admin/presentation/pages/leads_page.dart';
import 'package:kd_pannel/features/admin/presentation/pages/support_dashboard_page.dart';
import 'package:kd_pannel/features/sales/presentation/pages/sales_dashboard_page.dart';
import 'package:kd_pannel/features/shared/widgets/main_layout.dart';

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
        '/dashboard': (context) => const MainLayout(child: DashboardPage()),
        '/leads': (context) => const MainLayout(child: LeadsPage()),
        '/leads/profile': (context) => const MainLayout(child: LeadProfilePage()),
        '/dealers': (context) => const MainLayout(child: DealerManagementPage()),
        '/dealers/profile': (context) => const MainLayout(child: DealerProfilePage()),
        '/orders': (context) => const MainLayout(child: Scaffold(body: Center(child: Text('Orders')))),
        '/products': (context) => const MainLayout(child: Scaffold(body: Center(child: Text('Products')))),
        '/marketing': (context) => const MainLayout(child: Scaffold(body: Center(child: Text('Marketing')))),
        '/support': (context) => const MainLayout(child: SupportDashboardPage()),
        '/team': (context) => const MainLayout(child: Scaffold(body: Center(child: Text('Team')))),
        '/reports': (context) => const MainLayout(child: Scaffold(body: Center(child: Text('Reports')))),
        '/settings': (context) => const MainLayout(child: Scaffold(body: Center(child: Text('Settings')))),

        // Sales Routes
        '/sales/dashboard': (context) => const MainLayout(child: SalesDashboardPage()),
      },
    );
  }
}

