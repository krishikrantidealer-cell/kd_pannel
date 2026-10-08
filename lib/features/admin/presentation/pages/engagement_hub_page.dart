import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kd_pannel/app_theme.dart';
import 'package:kd_pannel/core/responsive/responsive.dart';
import 'package:kd_pannel/features/admin/presentation/cubit/engagement_hub_cubit.dart';
import 'package:kd_pannel/features/admin/presentation/cubit/engagement_hub_state.dart';
import 'package:kd_pannel/features/admin/presentation/pages/user_events_page.dart';
import 'package:kd_pannel/features/admin/presentation/pages/push_campaigns_page.dart';
import 'package:kd_pannel/features/admin/presentation/pages/audit_logs_container_page.dart';

class EngagementHubPage extends StatefulWidget {
  final int initialTab;

  const EngagementHubPage({
    super.key,
    this.initialTab = 0,
  });

  @override
  State<EngagementHubPage> createState() => _EngagementHubPageState();
}

class _EngagementHubPageState extends State<EngagementHubPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const List<Map<String, dynamic>> _tabs = [
    {
      'tab': EngagementHubTab.telemetry,
      'title': 'Marketing & Telemetry',
      'shortTitle': 'Telemetry',
      'icon': Icons.insights_rounded,
      'subtitle': 'User Drop-offs, Funnels & District Heatmap',
    },
    {
      'tab': EngagementHubTab.pushCampaigns,
      'title': 'Push Campaigns',
      'shortTitle': 'Push Broadcasts',
      'icon': Icons.notifications_active_rounded,
      'subtitle': 'FCM Broadcasts, Smartphone Simulator & Segments',
    },
    {
      'tab': EngagementHubTab.salesActivity,
      'title': 'Sales Activity',
      'shortTitle': 'Sales Logs',
      'icon': Icons.local_activity_rounded,
      'subtitle': 'Sales Team Actions & Admin Audit Logs',
    },
  ];

  @override
  void initState() {
    super.initState();
    final initialIndex = widget.initialTab.clamp(0, _tabs.length - 1);
    _tabController = TabController(
      length: _tabs.length,
      initialIndex: initialIndex,
      vsync: this,
    );

    _tabController.addListener(_handleTabChange);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<EngagementHubCubit>().selectTab(initialIndex);
      }
    });
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) return;
    final currentIndex = _tabController.index;
    context.read<EngagementHubCubit>().selectTab(currentIndex);
  }

  @override
  void didUpdateWidget(covariant EngagementHubPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab) {
      final target = widget.initialTab.clamp(0, _tabs.length - 1);
      if (_tabController.index != target) {
        _tabController.animateTo(target);
        context.read<EngagementHubCubit>().selectTab(target);
      }
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);

    return BlocConsumer<EngagementHubCubit, EngagementHubState>(
      listener: (context, state) {
        final targetIndex = state.activeTab.index;
        if (_tabController.index != targetIndex) {
          _tabController.animateTo(targetIndex);
        }
      },
      builder: (context, state) {
        final selectedIndex = state.activeTab.index;
        final loadedTabs = state.loadedTabs;

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(64),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(
                    color: Color(0xFFE2E8F0),
                    width: 1,
                  ),
                ),
              ),
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 24 : 12,
                vertical: 8,
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    // Header Title & Badge
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.rocket_launch_rounded,
                            color: AppTheme.primaryColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Engagement & Growth Hub',
                                  style: GoogleFonts.outfit(
                                    fontSize: isDesktop ? 17 : 15,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDCFCE7),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: const Color(0xFF86EFAC),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Text(
                                    'ENTERPRISE',
                                    style: GoogleFonts.outfit(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF15803D),
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (isDesktop)
                              Text(
                                _tabs[selectedIndex]['subtitle'] as String,
                                style: GoogleFonts.outfit(
                                  fontSize: 11.5,
                                  color: AppTheme.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),

                    const Spacer(),

                    // Segmented Pill Navigation Tabs
                    Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFE2E8F0),
                          width: 1,
                        ),
                      ),
                      padding: const EdgeInsets.all(3),
                      child: TabBar(
                        controller: _tabController,
                        isScrollable: !isDesktop,
                        tabAlignment: isDesktop ? TabAlignment.center : TabAlignment.start,
                        indicator: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(9),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        indicatorSize: TabBarIndicatorSize.tab,
                        labelColor: AppTheme.primaryColor,
                        unselectedLabelColor: AppTheme.textSecondary,
                        labelStyle: GoogleFonts.outfit(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                        unselectedLabelStyle: GoogleFonts.outfit(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        dividerColor: Colors.transparent,
                        labelPadding: EdgeInsets.symmetric(
                          horizontal: isDesktop ? 16 : 10,
                        ),
                        tabs: List.generate(_tabs.length, (index) {
                          final item = _tabs[index];
                          final isSelected = selectedIndex == index;
                          return Tab(
                            height: 36,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  item['icon'] as IconData,
                                  size: 16,
                                  color: isSelected
                                      ? AppTheme.primaryColor
                                      : AppTheme.textSecondary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  isDesktop
                                      ? item['title'] as String
                                      : item['shortTitle'] as String,
                                ),
                              ],
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            physics: const NeverScrollableScrollPhysics(), // Prevent gesture collisions with canvas/charts
            children: List.generate(_tabs.length, (index) {
              final isLoaded = loadedTabs.contains(index);
              if (!isLoaded) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: AppTheme.primaryColor,
                    strokeWidth: 2.5,
                  ),
                );
              }

              return _KeepAliveTabWrapper(
                child: _buildTabContent(index),
              );
            }),
          ),
        );
      },
    );
  }

  Widget _buildTabContent(int index) {
    switch (index) {
      case 0:
        return const _TabErrorBoundary(
          tabName: 'Marketing & Telemetry',
          child: UserEventsPage(),
        );
      case 1:
        return const _TabErrorBoundary(
          tabName: 'Push Campaigns',
          child: PushCampaignsPage(),
        );
      case 2:
        return const _TabErrorBoundary(
          tabName: 'Sales Activity',
          child: AuditLogsContainerPage(),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

class _KeepAliveTabWrapper extends StatefulWidget {
  final Widget child;

  const _KeepAliveTabWrapper({required this.child});

  @override
  State<_KeepAliveTabWrapper> createState() => _KeepAliveTabWrapperState();
}

class _KeepAliveTabWrapperState extends State<_KeepAliveTabWrapper>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class _TabErrorBoundary extends StatefulWidget {
  final String tabName;
  final Widget child;

  const _TabErrorBoundary({
    required this.tabName,
    required this.child,
  });

  @override
  State<_TabErrorBoundary> createState() => _TabErrorBoundaryState();
}

class _TabErrorBoundaryState extends State<_TabErrorBoundary> {
  bool _hasError = false;
  String _errorMessage = '';

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Color(0xFFEF4444),
                size: 40,
              ),
              const SizedBox(height: 16),
              Text(
                '${widget.tabName} Render Boundary',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage.isNotEmpty
                    ? _errorMessage
                    : 'An issue occurred while loading this tab. You can retry safely without reloading the entire console.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _hasError = false;
                    _errorMessage = '';
                  });
                },
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Retry Tab'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return widget.child;
  }
}
