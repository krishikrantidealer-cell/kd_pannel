import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kd_pannel/app_theme.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/audit_logs_bloc.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/audit_logs_event.dart';
import 'package:kd_pannel/features/admin/presentation/pages/admin_audit_logs_page.dart';

class AuditLogsContainerPage extends StatefulWidget {
  const AuditLogsContainerPage({super.key});

  @override
  State<AuditLogsContainerPage> createState() => _AuditLogsContainerPageState();
}

class _AuditLogsContainerPageState extends State<AuditLogsContainerPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Row(
                children: [
                  Text(
                    'Logs',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 32),
                  Expanded(
                    child: TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      indicatorColor: AppTheme.primaryColor,
                      indicatorSize: TabBarIndicatorSize.label,
                      labelColor: AppTheme.primaryColor,
                      unselectedLabelColor: AppTheme.textSecondary,
                      labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 13),
                      unselectedLabelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13),
                      dividerColor: Colors.transparent,
                      tabs: const [
                        Tab(text: 'Admin Activity'),
                        Tab(text: 'Sales Activity'),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          const AdminAuditLogsPage(roleFilter: 'admin'),
          const AdminAuditLogsPage(roleFilter: 'sales'),
        ],
      ),
    );
  }
}
