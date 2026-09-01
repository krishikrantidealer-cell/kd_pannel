import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:kd_pannel/app_theme.dart';
import 'package:kd_pannel/core/network/api_client.dart';
import 'package:kd_pannel/core/responsive/responsive.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/leads_bloc.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/leads_event.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/leads_state.dart';
import 'package:kd_pannel/features/admin/presentation/widgets/team/team_members_tab_view.dart';
import 'package:kd_pannel/features/admin/presentation/widgets/team/team_lead_conversions_tab_view.dart';
import 'package:kd_pannel/features/admin/presentation/widgets/team/team_permissions_tab_view.dart';

class TeamManagementPage extends StatefulWidget {
  final int initialTabIndex;
  const TeamManagementPage({super.key, this.initialTabIndex = 0});

  @override
  State<TeamManagementPage> createState() => _TeamManagementPageState();
}

class _TeamManagementPageState extends State<TeamManagementPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedTabIndex = 0;
  List<Map<String, dynamic>> _deletedUsersList = [];

  @override
  void initState() {
    super.initState();
    _selectedTabIndex = widget.initialTabIndex.clamp(0, 2);
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: _selectedTabIndex,
    );
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging &&
          _selectedTabIndex != _tabController.index) {
        setState(() {
          _selectedTabIndex = _tabController.index;
        });
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LeadsBloc>().add(
        const FetchLeadsDataEvent(forceRefresh: true),
      );
      _fetchDeletedUsers();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchDeletedUsers() async {
    try {
      final res = await ApiClient().get('/users/trash');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['data'] is List) {
          if (mounted) {
            setState(() {
              _deletedUsersList =
                  List<Map<String, dynamic>>.from(data['data']);
            });
          }
        }
      }
    } catch (_) {}
  }

  Widget _buildRefreshButton(LeadsState state) {
    return Container(
      height: 38,
      width: 38,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppTheme.borderColor,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: IconButton(
        tooltip: 'Refresh Team Data',
        padding: EdgeInsets.zero,
        icon: state.status == LeadsStatus.loading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.primaryColor,
                ),
              )
            : const Icon(
                Icons.refresh_rounded,
                size: 18,
                color: AppTheme.textSecondary,
              ),
        onPressed: () {
          _fetchDeletedUsers();
          context.read<LeadsBloc>().add(
            const FetchLeadsDataEvent(forceRefresh: true),
          );
        },
      ),
    );
  }

  Widget _buildCustomTabItem({
    required int index,
    required String title,
    required IconData icon,
    required int count,
    required Color accentColor,
    required bool isSelected,
  }) {
    return Tab(
      height: 38,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 17,
              color: isSelected ? accentColor : const Color(0xFF64748B),
            ),
            const SizedBox(width: 7),
            Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? AppTheme.textPrimary : const Color(0xFF64748B),
              ),
            ),
            if (count >= 0) ...[
              const SizedBox(width: 7),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 1.5,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? accentColor.withValues(alpha: 0.12)
                      : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isSelected ? accentColor : const Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTabSelector(
    bool isMobile,
    int totalAgents,
    int totalConversions,
  ) {
    final tabSelector = Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(3),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          dividerColor: Colors.transparent,
          indicatorSize: TabBarIndicatorSize.tab,
          indicator: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(9),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: const Color(0xFF64748B),
          labelPadding: EdgeInsets.zero,
          splashBorderRadius: BorderRadius.circular(9),
          onTap: (index) {
            if (_selectedTabIndex != index) {
              setState(() {
                _selectedTabIndex = index;
              });
            }
          },
          tabs: [
            _buildCustomTabItem(
              index: 0,
              title: 'Team Members',
              icon: Icons.groups_rounded,
              count: totalAgents,
              accentColor: const Color(0xFF10B981),
              isSelected: _selectedTabIndex == 0,
            ),
            _buildCustomTabItem(
              index: 1,
              title: 'Lead Conversion',
              icon: Icons.trending_up_rounded,
              count: totalConversions,
              accentColor: const Color(0xFF0284C7),
              isSelected: _selectedTabIndex == 1,
            ),
            _buildCustomTabItem(
              index: 2,
              title: 'Permissions Matrix',
              icon: Icons.security_rounded,
              count: totalAgents,
              accentColor: const Color(0xFF8B5CF6),
              isSelected: _selectedTabIndex == 2,
            ),
          ],
        ),
      ),
    );

    return Align(
      alignment: Alignment.centerLeft,
      child: tabSelector,
    );
  }

  Widget _buildShimmerLoading(bool isDesktop, bool isMobile) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 28 : 16,
        vertical: isDesktop ? 20 : 12,
      ),
      child: Shimmer.fromColors(
        baseColor: const Color(0xFFE5E7EB),
        highlightColor: const Color(0xFFF9FAFB),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 28,
                      width: 220,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 16,
                      width: 320,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ],
                ),
                Container(
                  height: 42,
                  width: 150,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              height: 46,
              width: isDesktop ? 400 : double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(height: 24),
            if (isDesktop)
              Row(
                children: List.generate(
                  3,
                  (index) => Expanded(
                    child: Container(
                      height: 84,
                      margin: EdgeInsets.only(right: index < 2 ? 12 : 0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              )
            else
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: List.generate(
                  3,
                  (index) => Container(
                    width: (MediaQuery.of(context).size.width - 48) / 2,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 20),
            Container(
              height: 52,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            const SizedBox(height: 20),
            ...List.generate(
              3,
              (index) => Container(
                height: 140,
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);
    final isMobile = Responsive.isMobile(context);

    return BlocBuilder<LeadsBloc, LeadsState>(
      builder: (context, state) {
        final allSalesAgents = state.allRawUsers
            .where((u) => u['role'] == 'sales')
            .toList();

        final bool isInitialOrLoading =
            (state.status == LeadsStatus.loading ||
                    state.status == LeadsStatus.initial) &&
                state.allRawUsers.isEmpty;

        int totalTeamConversions = 0;
        for (final user in state.allRawUsers) {
          if (user['role'] == 'user' &&
              user['kycStatus'] == 'verified' &&
              user['assignedAgent'] != null) {
            totalTeamConversions++;
          }
        }
        for (final user in _deletedUsersList) {
          if (user['role'] == 'user' &&
              user['kycStatus'] == 'verified' &&
              user['assignedAgent'] != null) {
            totalTeamConversions++;
          }
        }

        final Widget bodyContent = SelectionArea(
          child: isInitialOrLoading
              ? _buildShimmerLoading(isDesktop, isMobile)
              : ScrollConfiguration(
                  behavior: ScrollConfiguration.of(
                    context,
                  ).copyWith(scrollbars: false),
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isDesktop ? 28 : 16,
                        vertical: isDesktop ? 20 : 12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          // Page Header Title, Subtitle, and Refresh Action
                          isDesktop
                              ? Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Team Management',
                                            style: GoogleFonts.outfit(
                                              fontSize: 26,
                                              fontWeight: FontWeight.w800,
                                              color: AppTheme.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          AnimatedSwitcher(
                                            duration: const Duration(
                                              milliseconds: 200,
                                            ),
                                            child: Text(
                                              _selectedTabIndex == 0
                                                  ? 'Monitor and coordinate your sales agent team assignments.'
                                                  : (_selectedTabIndex == 1
                                                      ? 'Track sales agent performance and lead-to-dealer conversions.'
                                                      : 'Configure granular Lead and Dealer action permissions for sales agents.'),
                                              key: ValueKey<int>(
                                                _selectedTabIndex,
                                              ),
                                              style: GoogleFonts.outfit(
                                                fontSize: 14,
                                                color: AppTheme.textSecondary,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    _buildRefreshButton(state),
                                  ],
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'Team Management',
                                            style: GoogleFonts.outfit(
                                              fontSize: 20,
                                              fontWeight: FontWeight.w800,
                                              color: AppTheme.textPrimary,
                                            ),
                                          ),
                                        ),
                                        _buildRefreshButton(state),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _selectedTabIndex == 0
                                          ? 'Monitor and coordinate your sales agent team assignments.'
                                          : (_selectedTabIndex == 1
                                              ? 'Track sales agent performance and lead-to-dealer conversions.'
                                              : 'Configure granular Lead and Dealer action permissions for sales agents.'),
                                      style: GoogleFonts.outfit(
                                        fontSize: 12,
                                        color: AppTheme.textSecondary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                          const SizedBox(height: 16),

                          // Clean Shrink-Wrapped Segmented TabBar
                          _buildTabSelector(
                            isMobile,
                            allSalesAgents.length,
                            totalTeamConversions,
                          ),
                          const SizedBox(height: 20),

                          // Active Tab View Switcher
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            transitionBuilder: (child, animation) =>
                                FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0.0, 0.015),
                                  end: Offset.zero,
                                ).animate(animation),
                                child: child,
                              ),
                            ),
                            child: KeyedSubtree(
                              key: ValueKey<int>(_selectedTabIndex),
                              child: _selectedTabIndex == 2
                                  ? TeamPermissionsTabView(
                                      state: state,
                                      isDesktop: isDesktop,
                                      isMobile: isMobile,
                                    )
                                  : (_selectedTabIndex == 1
                                      ? TeamLeadConversionsTabView(
                                          state: state,
                                          isDesktop: isDesktop,
                                          isMobile: isMobile,
                                          deletedUsersList: _deletedUsersList,
                                        )
                                      : TeamMembersTabView(
                                          state: state,
                                          isDesktop: isDesktop,
                                          isMobile: isMobile,
                                        )),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        );

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          body: bodyContent,
        );
      },
    );
  }
}
