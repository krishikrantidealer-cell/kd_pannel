import 'package:flutter/material.dart';
import 'core/di/service_locator.dart';
import 'features/dashboard/presentation/pages/dashboard_page.dart';
import 'features/dashboard/presentation/pages/sales_dashboard_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupServiceLocator();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Role-based navigation preparation
    bool isAdmin = false;

    return MaterialApp(
      title: 'KrishiDealer Admin Panel',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4CAF50)),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: isAdmin ? const DashboardPage() : const SalesDashboardPage(),
    );
  }
}
