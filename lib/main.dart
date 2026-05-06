import 'package:flutter/material.dart';
import 'package:kd_pannel/app_theme.dart';
import 'package:kd_pannel/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:kd_pannel/features/dashboard/presentation/pages/support_dashboard_page.dart';
import 'package:kd_pannel/features/dashboard/presentation/widgets/main_layout.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
      initialRoute: '/dashboard',
      routes: {
        '/dashboard': (context) => const MainLayout(child: DashboardPage()),
        '/leads': (context) => const MainLayout(child: Scaffold(body: Center(child: Text('Leads')))),
        '/dealers': (context) => const MainLayout(child: Scaffold(body: Center(child: Text('Dealers')))),
        '/orders': (context) => const MainLayout(child: Scaffold(body: Center(child: Text('Orders')))),
        '/products': (context) => const MainLayout(child: Scaffold(body: Center(child: Text('Products')))),
        '/marketing': (context) => const MainLayout(child: Scaffold(body: Center(child: Text('Marketing')))),
        '/support': (context) => const MainLayout(child: SupportDashboardPage()),
        '/team': (context) => const MainLayout(child: Scaffold(body: Center(child: Text('Team')))),
        '/reports': (context) => const MainLayout(child: Scaffold(body: Center(child: Text('Reports')))),
        '/settings': (context) => const MainLayout(child: Scaffold(body: Center(child: Text('Settings')))),
      },
    );
  }
}
