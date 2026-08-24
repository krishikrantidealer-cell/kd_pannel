import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shimmer/shimmer.dart';
import 'package:kd_pannel/app_theme.dart';
import 'package:kd_pannel/core/responsive/responsive.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/push_campaigns_bloc.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/push_campaigns_event.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/push_campaigns_state.dart';
import 'package:kd_pannel/features/admin/presentation/widgets/campaigns/create_segment_dialog.dart';
import 'package:kd_pannel/features/admin/presentation/widgets/campaigns/edit_segment_dialog.dart';
import 'package:kd_pannel/features/admin/presentation/widgets/campaigns/add_template_dialog.dart';
import 'package:kd_pannel/features/admin/presentation/widgets/campaigns/edit_template_dialog.dart';
import 'package:kd_pannel/features/admin/presentation/widgets/campaigns/test_push_dialog.dart';

class PushCampaignsPage extends StatefulWidget {
  const PushCampaignsPage({super.key});

  @override
  State<PushCampaignsPage> createState() => _PushCampaignsPageState();
}

class _PushCampaignsPageState extends State<PushCampaignsPage>
    with SingleTickerProviderStateMixin {
  String _selectedCategoryFilter = 'All';
  String _searchQuery = '';
  String? _selectedSegmentKey;
  int _sidebarActiveTab =
      0; // 0: Rotation sequence & Copies, 1: Smartphone Push Simulator, 2: Segment Settings
  int _simulatorDeviceType =
      0; // 0: Android Material 3, 1: iOS Dynamic Lock Screen

  // Sample variable preview data
  String _previewDealerName = 'Ramesh Patel';
  String _previewShopName = 'Kisan Krishi Kendra';
  String _previewCity = 'Indore';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bloc = context.read<PushCampaignsBloc>();
      if (bloc.state.status == PushCampaignsStatus.initial) {
        bloc.add(const FetchPushCampaignsEvent());
      }
    });
  }

  void _fetchCampaigns() {
    context.read<PushCampaignsBloc>().add(
      const FetchPushCampaignsEvent(forceRefresh: true),
    );
  }

  String _replaceVariables(String raw) {
    if (raw.isEmpty) return '';
    return raw
        .replaceAll(
          RegExp(r'\{\{\s*name\s*\}\}', caseSensitive: false),
          _previewDealerName,
        )
        .replaceAll(
          RegExp(r'\{\{\s*dealerName\s*\}\}', caseSensitive: false),
          _previewDealerName,
        )
        .replaceAll(
          RegExp(r'\{\{\s*shopName\s*\}\}', caseSensitive: false),
          _previewShopName,
        )
        .replaceAll(
          RegExp(r'\{\{\s*shopname\s*\}\}', caseSensitive: false),
          _previewShopName,
        )
        .replaceAll(
          RegExp(r'\{\{\s*dukaan\s*\}\}', caseSensitive: false),
          _previewShopName,
        )
        .replaceAll(
          RegExp(r'\{\{\s*city\s*\}\}', caseSensitive: false),
          _previewCity,
        );
  }

  Color _getCategoryColor(String? category) {
    final cat = (category ?? '').toLowerCase();
    switch (cat) {
      case 'kyc':
        return const Color(0xFF8B5CF6); // Purple
      case 'cart':
        return const Color(0xFFF59E0B); // Amber
      case 'orders':
        return const Color(0xFF3B82F6); // Blue
      case 'promotional':
      case 'flash':
        return const Color(0xFFEC4899); // Pink
      case 'seasonal':
        return const Color(0xFF06B6D4); // Cyan
      case 're-engagement':
        return const Color(0xFF10B981); // Emerald
      case 'marketing':
        return const Color(0xFF6366F1); // Indigo
      default:
        return const Color(0xFF2E7D32); // Brand Green
    }
  }

  IconData _getCategoryIcon(String? category) {
    final cat = (category ?? '').toLowerCase();
    switch (cat) {
      case 'kyc':
        return Icons.assignment_ind_rounded;
      case 'cart':
        return Icons.shopping_cart_checkout_rounded;
      case 'orders':
        return Icons.inventory_2_rounded;
      case 'promotional':
      case 'flash':
        return Icons.local_offer_rounded;
      case 'seasonal':
        return Icons.water_drop_rounded;
      case 're-engagement':
        return Icons.replay_circle_filled_rounded;
      case 'marketing':
        return Icons.campaign_rounded;
      default:
        return Icons.notifications_active_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PushCampaignsBloc, PushCampaignsState>(
      listener: (context, state) {
        if (state.errorMessage != null && state.errorMessage!.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(child: Text(state.errorMessage!)),
                ],
              ),
              backgroundColor: AppTheme.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
          context.read<PushCampaignsBloc>().add(
            const ClearPushCampaignsMessageEvent(),
          );
        }
        if (state.successMessage != null && state.successMessage!.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(child: Text(state.successMessage!)),
                ],
              ),
              backgroundColor: const Color(0xFF16A34A),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
          context.read<PushCampaignsBloc>().add(
            const ClearPushCampaignsMessageEvent(),
          );
        }
      },
      builder: (context, state) {
        final campaigns = state.campaigns;

        // Ensure selected campaign exists
        Map<String, dynamic>? selectedCampaign;
        if (_selectedSegmentKey != null) {
          selectedCampaign = campaigns.firstWhere(
            (c) => c['segmentKey'] == _selectedSegmentKey,
            orElse: () => campaigns.isNotEmpty ? campaigns.first : {},
          );
          if (selectedCampaign.isEmpty) selectedCampaign = null;
        } else if (campaigns.isNotEmpty) {
          selectedCampaign = campaigns.first;
          _selectedSegmentKey = selectedCampaign['segmentKey'];
        }

        final filteredCampaigns = campaigns.where((c) {
          if (_selectedCategoryFilter != 'All' &&
              (c['category'] ?? '').toString().toLowerCase() !=
                  _selectedCategoryFilter.toLowerCase()) {
            return false;
          }
          if (_searchQuery.isNotEmpty) {
            final q = _searchQuery.toLowerCase();
            final name = (c['name'] ?? '').toString().toLowerCase();
            final seg = (c['segmentKey'] ?? '').toString().toLowerCase();
            final desc = (c['description'] ?? '').toString().toLowerCase();
            if (!name.contains(q) && !seg.contains(q) && !desc.contains(q)) {
              return false;
            }
          }
          return true;
        }).toList();

        final activeCount = campaigns
            .where((c) => c['isEnabled'] == true)
            .length;
        final totalCopies = campaigns.fold<int>(
          0,
          (sum, c) => sum + ((c['templates'] as List?)?.length ?? 0),
        );

        return Scaffold(
          backgroundColor: const Color(0xFFF1F5F9),
          body: state.status == PushCampaignsStatus.loading && campaigns.isEmpty
              ? _buildShimmerLoading(context)
              : Row(
                  children: [
                    // Main Left Studio Section
                    Expanded(
                      flex: 3,
                      child: CustomScrollView(
                        slivers: [
                          // Modern Top Studio App Bar
                          SliverToBoxAdapter(
                            child: _buildStudioHeader(
                              context,
                              state,
                              activeCount,
                              totalCopies,
                            ),
                          ),

                          // Search, Category Filters, and Metric Tiles
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildStudioMetricsRow(
                                    state,
                                    activeCount,
                                    campaigns.length,
                                    totalCopies,
                                  ),
                                  const SizedBox(height: 18),
                                  _buildFilterAndSearchBar(state),
                                  const SizedBox(height: 16),
                                ],
                              ),
                            ),
                          ),

                          // Campaign Segment List
                          if (filteredCampaigns.isEmpty)
                            SliverFillRemaining(
                              hasScrollBody: false,
                              child: _buildEmptyState(),
                            )
                          else
                            SliverPadding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),
                              sliver: SliverList(
                                delegate: SliverChildBuilderDelegate((
                                  ctx,
                                  index,
                                ) {
                                  final camp = filteredCampaigns[index];
                                  final isSelected =
                                      camp['segmentKey'] == _selectedSegmentKey;
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 14),
                                    child: _buildModernSegmentCard(
                                      camp,
                                      isSelected: isSelected,
                                    ),
                                  );
                                }, childCount: filteredCampaigns.length),
                              ),
                            ),
                          const SliverToBoxAdapter(child: SizedBox(height: 40)),
                        ],
                      ),
                    ),

                    // Right Live Push Simulator & Inspector Sidebar
                    if (Responsive.isDesktop(context))
                      Container(
                        width: 480,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 20,
                              offset: const Offset(-4, 0),
                            ),
                          ],
                          border: const Border(
                            left: BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                        ),
                        child: selectedCampaign == null
                            ? _buildNoSelectionPlaceholder()
                            : _buildRightStudioInspector(
                                selectedCampaign,
                                state,
                              ),
                      ),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildStudioHeader(
    BuildContext context,
    PushCampaignsState state,
    int activeCount,
    int totalCopies,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF15803D), Color(0xFF22C55E)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF16A34A).withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.campaign_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Push Marketing & Notification Studio',
                        style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF86EFAC)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: Color(0xFF16A34A),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Auto-Dispatch Active',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF15803D),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Multi-segment lifecycle automation, daily copy rotation & interactive lock-screen simulation',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _fetchCampaigns,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF334155),
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(
                  'Sync Engine',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: () => _showCreateSegmentDialog(state),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.add_rounded, size: 20),
                label: Text(
                  'New Segment',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStudioMetricsRow(
    PushCampaignsState state,
    int activeCount,
    int totalSegments,
    int totalCopies,
  ) {
    return Row(
      children: [
        _buildStatTile(
          title: 'Active Segments',
          value: '$activeCount / $totalSegments',
          subtitle: 'Live lifecycle triggers',
          icon: Icons.hub_rounded,
          color: const Color(0xFF16A34A),
          bgColor: const Color(0xFFF0FDF4),
        ),
        const SizedBox(width: 12),
        _buildStatTile(
          title: 'FCM Audience Reach',
          value: '${state.usersWithToken} Holders',
          subtitle: 'of ${state.totalUsers} registered users',
          icon: Icons.phonelink_ring_rounded,
          color: const Color(0xFF2563EB),
          bgColor: const Color(0xFFEFF6FF),
        ),
        const SizedBox(width: 12),
        _buildStatTile(
          title: 'Notification Copies',
          value: '$totalCopies Copies',
          subtitle: 'In rotation sequence',
          icon: Icons.auto_stories_rounded,
          color: const Color(0xFF9333EA),
          bgColor: const Color(0xFFFAF5FF),
        ),
        const SizedBox(width: 12),
        _buildStatTile(
          title: 'Engine Mode',
          value: '100% Dynamic',
          subtitle: 'IST Scheduled Daily',
          icon: Icons.bolt_rounded,
          color: const Color(0xFFEA580C),
          bgColor: const Color(0xFFFFF7ED),
        ),
      ],
    );
  }

  Widget _buildStatTile({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  Text(
                    value,
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.outfit(
                      fontSize: 10.5,
                      color: const Color(0xFF94A3B8),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterAndSearchBar(PushCampaignsState state) {
    final categories = [
      {'value': 'All', 'label': 'All Campaigns', 'icon': Icons.bolt_rounded},
      {
        'value': 'kyc',
        'label': 'KYC Leads (Pre-KYC)',
        'icon': Icons.assignment_ind_rounded,
      },
      {
        'value': 'cart',
        'label': 'Cart Recovery',
        'icon': Icons.shopping_cart_checkout_rounded,
      },
      {
        'value': 'marketing',
        'label': 'Marketing & Catalog',
        'icon': Icons.campaign_rounded,
      },
      {
        'value': 'orders',
        'label': 'Order Retention',
        'icon': Icons.inventory_2_rounded,
      },
      {
        'value': 'seasonal',
        'label': 'Seasonal Surge',
        'icon': Icons.water_drop_rounded,
      },
      {
        'value': 'promotional',
        'label': 'Flash Discounts',
        'icon': Icons.local_offer_rounded,
      },
      {
        'value': 're-engagement',
        'label': 'Win-Back Dormant',
        'icon': Icons.replay_circle_filled_rounded,
      },
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCBD5E1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: InputDecoration(
                    hintText:
                        'Search campaigns by name, key (e.g. A, B, seasonal), or audience rule...',
                    hintStyle: GoogleFonts.outfit(
                      fontSize: 13.5,
                      color: const Color(0xFF94A3B8),
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: Color(0xFF475569),
                      size: 22,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () => setState(() => _searchQuery = ''),
                          )
                        : null,
                    isDense: true,
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: Color(0xFF16A34A),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: categories.map((cat) {
              final isSelected = _selectedCategoryFilter == cat['value'];
              final val = cat['value'] as String;
              final count = val == 'All'
                  ? state.campaigns.length
                  : state.campaigns
                        .where(
                          (c) =>
                              (c['category'] ?? '').toString().toLowerCase() ==
                              val.toLowerCase(),
                        )
                        .length;

              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedCategoryFilter = val;
                  });
                },
                borderRadius: BorderRadius.circular(8),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF0F172A)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF0F172A)
                          : const Color(0xFFCBD5E1),
                      width: isSelected ? 1.5 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isSelected
                            ? const Color(0xFF0F172A).withValues(alpha: 0.15)
                            : Colors.black.withValues(alpha: 0.02),
                        blurRadius: isSelected ? 6 : 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        cat['icon'] as IconData,
                        size: 14,
                        color: isSelected
                            ? const Color(0xFF4ADE80)
                            : const Color(0xFF475569),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        cat['label'] as String,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w600,
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF1E293B)
                              : const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF334155)
                                : const Color(0xFFCBD5E1),
                          ),
                        ),
                        child: Text(
                          '$count',
                          style: GoogleFonts.outfit(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: isSelected
                                ? const Color(0xFF4ADE80)
                                : const Color(0xFF475569),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildModernSegmentCard(
    Map<String, dynamic> campaign, {
    required bool isSelected,
  }) {
    final segKey = (campaign['segmentKey'] ?? '').toString();
    final name = (campaign['name'] ?? 'Untitled Segment').toString();
    final isEnabled = campaign['isEnabled'] == true;
    final scheduledTime = campaign['scheduledTime'] ?? '09:30';
    final mode = campaign['mode'] ?? 'rotating';
    final pinnedId = campaign['pinnedTemplateId'];
    final category = campaign['category']?.toString();
    final templates = List<Map<String, dynamic>>.from(
      campaign['templates'] ?? [],
    );
    final isDispatchedToday = campaign['isDispatchedToday'] == true;
    final dispatchedCount = campaign['dispatchedTodayCount'] ?? 0;
    final audienceCount =
        campaign['totalAudience'] ??
        campaign['eligibleAudience'] ??
        campaign['eligibleCount'] ??
        0;

    final isLeadSegment = ['A', 'B', 'C'].contains(segKey.toUpperCase());
    final isDealerSegment = [
      'D',
      'E',
      'F',
      'G',
      'H',
      'I',
      'J',
    ].contains(segKey.toUpperCase());
    final catColor = _getCategoryColor(category);

    // Active copy preview
    Map<String, dynamic>? activeTemplate;
    if (templates.isNotEmpty) {
      if (mode == 'pinned' && pinnedId != null) {
        activeTemplate = templates.firstWhere(
          (t) => (t['_id'] ?? t['id'])?.toString() == pinnedId.toString(),
          orElse: () => templates.first,
        );
      } else {
        activeTemplate = templates.first;
      }
    }

    return InkWell(
      onTap: () {
        setState(() {
          _selectedSegmentKey = segKey;
        });
        context.read<PushCampaignsBloc>().add(SelectCampaignEvent(campaign));
      },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF16A34A)
                : const Color(0xFFE2E8F0),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? const Color(0xFF16A34A).withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: 0.03),
              blurRadius: isSelected ? 16 : 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Segment Top Bar
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFFF0FDF4)
                      : const Color(0xFFFAFAFA),
                  border: const Border(
                    bottom: BorderSide(color: Color(0xFFF1F5F9)),
                  ),
                ),
                child: Row(
                  children: [
                    // Segment Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: isEnabled ? catColor : const Color(0xFF94A3B8),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'SEGMENT $segKey',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  name,
                                  style: GoogleFonts.outfit(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF0F172A),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            (campaign['description'] ??
                                    'Dynamic automated targeting rule')
                                .toString(),
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: const Color(0xFF64748B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Daily IST Schedule Chip
                    InkWell(
                      onTap: () => _pickScheduledTime(segKey, scheduledTime),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.access_time_rounded,
                              size: 14,
                              color: Color(0xFF475569),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '$scheduledTime IST',
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF334155),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.arrow_drop_down_rounded,
                              size: 16,
                              color: Color(0xFF94A3B8),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Enable / Disable Switch
                    Switch(
                      value: isEnabled,
                      activeThumbColor: const Color(0xFF16A34A),
                      activeTrackColor: const Color(0xFFBBF7D0),
                      onChanged: (v) {
                        context.read<PushCampaignsBloc>().add(
                          ToggleCampaignEnabledEvent(
                            segmentKey: segKey,
                            isEnabled: v,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Segment Body Details
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Audience & Status Badges
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        // Audience Type Tag
                        if (isLeadSegment)
                          _buildPillBadge(
                            '🎯 $audienceCount Leads (Pre-KYC)',
                            const Color(0xFF7E22CE),
                            const Color(0xFFFAF5FF),
                            const Color(0xFFE9D5FF),
                          )
                        else if (isDealerSegment)
                          _buildPillBadge(
                            '👥 $audienceCount Verified Dealers',
                            const Color(0xFF1D4ED8),
                            const Color(0xFFEFF6FF),
                            const Color(0xFFBFDBFE),
                          )
                        else
                          _buildPillBadge(
                            '📢 $audienceCount Audience',
                            const Color(0xFF334155),
                            const Color(0xFFF1F5F9),
                            const Color(0xFFCBD5E1),
                          ),

                        // Dispatched Status
                        if (isDispatchedToday)
                          _buildPillBadge(
                            '✓ Sent Today ($dispatchedCount)',
                            const Color(0xFF15803D),
                            const Color(0xFFDCFCE7),
                            const Color(0xFF86EFAC),
                            icon: Icons.check_circle_rounded,
                          )
                        else
                          _buildPillBadge(
                            '⏳ Scheduled for $scheduledTime',
                            const Color(0xFFB45309),
                            const Color(0xFFFEF3C7),
                            const Color(0xFFFDE68A),
                          ),

                        // Rotation Mode
                        if (mode == 'pinned')
                          _buildPillBadge(
                            '📌 Pinned Single Copy',
                            const Color(0xFFB45309),
                            const Color(0xFFFFFBEB),
                            const Color(0xFFFDE68A),
                          )
                        else
                          _buildPillBadge(
                            '🔄 Rotation (${templates.length} Copies)',
                            const Color(0xFF475569),
                            const Color(0xFFF8FAFC),
                            const Color(0xFFE2E8F0),
                          ),

                        // Category Tag
                        if (category != null && category.isNotEmpty)
                          _buildPillBadge(
                            category.toUpperCase(),
                            catColor,
                            catColor.withValues(alpha: 0.08),
                            catColor.withValues(alpha: 0.2),
                            icon: _getCategoryIcon(category),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Active Template Live Mini-Card Preview
                    if (activeTemplate != null)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Banner thumbnail if available
                            if ((activeTemplate['imageUrl'] ?? '')
                                .toString()
                                .isNotEmpty) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  activeTemplate['imageUrl'],
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 60,
                                    height: 60,
                                    color: const Color(0xFFE2E8F0),
                                    child: const Icon(
                                      Icons.broken_image_rounded,
                                      size: 20,
                                      color: Color(0xFF94A3B8),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF16A34A),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          'ACTIVE COPY',
                                          style: GoogleFonts.outfit(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _replaceVariables(
                                            (activeTemplate['title'] ?? '')
                                                .toString(),
                                          ),
                                          style: GoogleFonts.outfit(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFF0F172A),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _replaceVariables(
                                      (activeTemplate['body'] ?? '').toString(),
                                    ),
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      color: const Color(0xFF475569),
                                      height: 1.3,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          border: Border.all(
                                            color: const Color(0xFFCBD5E1),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.touch_app_rounded,
                                              size: 12,
                                              color: Color(0xFF16A34A),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              activeTemplate['button1'] ??
                                                  activeTemplate['btn1Text'] ??
                                                  '⚡ Open Offer',
                                              style: GoogleFonts.outfit(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: const Color(0xFF0F172A),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Target: ${activeTemplate['actionRoute'] ?? campaign['targetRoute'] ?? '/dashboard'}',
                                        style: GoogleFonts.outfit(
                                          fontSize: 11,
                                          color: const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.info_outline_rounded,
                              size: 16,
                              color: Color(0xFFB45309),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'No notification copies added yet. Click "+ Add Copy" to start automated rotation.',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  color: const Color(0xFF92400E),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 14),

                    // Quick Action Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () =>
                              _showTestPushDialog(segKey, activeTemplate),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF334155),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: const Icon(
                            Icons.phone_android_rounded,
                            size: 15,
                            color: Color(0xFF475569),
                          ),
                          label: Text(
                            'Send Test',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () => _triggerInstantBroadcast(segKey),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F172A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: const Icon(
                            Icons.rocket_launch_rounded,
                            size: 15,
                            color: Color(0xFFFACC15),
                          ),
                          label: Text(
                            'Broadcast Now',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPillBadge(
    String label,
    Color textColor,
    Color bgColor,
    Color borderColor, {
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: textColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w700,
              fontSize: 11.5,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRightStudioInspector(
    Map<String, dynamic> campaign,
    PushCampaignsState state,
  ) {
    final segKey = campaign['segmentKey'] ?? '';
    final name = campaign['name'] ?? 'Segment';
    final templates = List<Map<String, dynamic>>.from(
      campaign['templates'] ?? [],
    );
    final mode = campaign['mode'] ?? 'rotating';
    final pinnedId = campaign['pinnedTemplateId'];

    return Column(
      children: [
        // Sidebar Studio Tabs
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F172A),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'SEGMENT $segKey',
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                name,
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF0F172A),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Edit Segment Settings',
                        icon: const Icon(Icons.tune_rounded, size: 18),
                        onPressed: () =>
                            _showEditSegmentDialog(campaign, state),
                      ),
                      IconButton(
                        tooltip: 'Delete Segment',
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                          color: AppTheme.error,
                        ),
                        onPressed: () => _deleteSegment(segKey),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Tab Selector
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    _buildSidebarTabButton(
                      0,
                      'Copies (${templates.length})',
                      Icons.format_list_bulleted_rounded,
                    ),
                    _buildSidebarTabButton(
                      1,
                      'Live Simulator',
                      Icons.smartphone_rounded,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Sidebar Content View
        Expanded(
          child: _sidebarActiveTab == 0
              ? _buildCopiesManagerTab(campaign, templates, mode, pinnedId)
              : _buildLiveSimulatorTab(campaign, templates, mode, pinnedId),
        ),
      ],
    );
  }

  Widget _buildSidebarTabButton(int index, String label, IconData icon) {
    final isSelected = _sidebarActiveTab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _sidebarActiveTab = index),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected
                    ? const Color(0xFF16A34A)
                    : const Color(0xFF64748B),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? const Color(0xFF0F172A)
                      : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCopiesManagerTab(
    Map<String, dynamic> campaign,
    List<Map<String, dynamic>> templates,
    String mode,
    dynamic pinnedId,
  ) {
    final segKey = campaign['segmentKey'] ?? '';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Rotation Sequence (${templates.length} Active)',
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF334155),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => _showAddTemplateDialog(segKey),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(Icons.add_rounded, size: 16),
              label: Text(
                'Add Copy',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (templates.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.post_add_rounded,
                  size: 40,
                  color: Color(0xFF94A3B8),
                ),
                const SizedBox(height: 10),
                Text(
                  'No copies in rotation yet',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: const Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Add high-converting notification variants that rotate daily for this segment.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  onPressed: () => _showAddTemplateDialog(segKey),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Add 1st Copy Preset'),
                ),
              ],
            ),
          )
        else
          ReorderableListView.builder(
            shrinkWrap: true,
            buildDefaultDragHandles: false,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: templates.length,
            onReorderItem: (oldIndex, newIndex) {
              context.read<PushCampaignsBloc>().add(
                ReorderCampaignTemplatesEvent(
                  segmentKey: segKey,
                  oldIndex: oldIndex,
                  newIndex: newIndex,
                ),
              );
            },
            itemBuilder: (ctx, index) {
              final tpl = templates[index];
              final tplId = (tpl['_id'] ?? tpl['id'])?.toString() ?? '';
              final isPinned =
                  mode == 'pinned' && pinnedId?.toString() == tplId;

              return Padding(
                key: ValueKey(tplId.isNotEmpty ? tplId : 'tpl_$index'),
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildTemplateListItemCard(
                  campaign,
                  tpl,
                  index: index,
                  isPinned: isPinned,
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildTemplateListItemCard(
    Map<String, dynamic> campaign,
    Map<String, dynamic> tpl, {
    required int index,
    required bool isPinned,
  }) {
    final segKey = campaign['segmentKey'] ?? '';
    final tplId = (tpl['_id'] ?? tpl['id'])?.toString() ?? '';
    final title = tpl['title'] ?? 'Notification Title';
    final body = tpl['body'] ?? '';
    final imageUrl = (tpl['imageUrl'] ?? '').toString();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPinned ? const Color(0xFFF59E0B) : const Color(0xFFE2E8F0),
          width: isPinned ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Prominent Visual Drag Handle
                ReorderableDragStartListener(
                  index: index,
                  child: Tooltip(
                    message: 'Drag & drop to reorder rotation sequence',
                    child: MouseRegion(
                      cursor: SystemMouseCursors.grab,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.drag_indicator_rounded,
                              size: 18,
                              color: Color(0xFF475569),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Day / Step Sequence Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: isPinned
                        ? const Color(0xFFFEF3C7)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isPinned
                          ? const Color(0xFFFDE68A)
                          : const Color(0xFFCBD5E1),
                    ),
                  ),
                  child: Text(
                    isPinned ? '📌 PINNED' : 'DAY ${index + 1}',
                    style: GoogleFonts.outfit(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: isPinned
                          ? const Color(0xFFB45309)
                          : const Color(0xFF475569),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _replaceVariables(title),
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // Pin / Unpin Button
                IconButton(
                  tooltip: isPinned
                      ? 'Unpin (Resume Rotation)'
                      : 'Pin this Copy',
                  icon: Icon(
                    isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                    size: 16,
                    color: isPinned
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFF94A3B8),
                  ),
                  onPressed: () {
                    context.read<PushCampaignsBloc>().add(
                      TogglePinTemplateEvent(
                        segmentKey: segKey,
                        templateId: tplId,
                        isCurrentlyPinned: isPinned,
                      ),
                    );
                  },
                ),

                // Edit Button
                IconButton(
                  tooltip: 'Edit Copy',
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  onPressed: () => _showEditTemplateDialog(segKey, tpl),
                ),

                // Delete Button
                IconButton(
                  tooltip: 'Delete Copy',
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    size: 16,
                    color: AppTheme.error,
                  ),
                  onPressed: () => _deleteTemplate(segKey, tplId),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _replaceVariables(body),
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: const Color(0xFF64748B),
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (imageUrl.isNotEmpty) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(
                  imageUrl,
                  height: 60,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLiveSimulatorTab(
    Map<String, dynamic> campaign,
    List<Map<String, dynamic>> templates,
    String mode,
    dynamic pinnedId,
  ) {
    Map<String, dynamic> currentTemplate = templates.isNotEmpty
        ? (mode == 'pinned' && pinnedId != null
              ? templates.firstWhere(
                  (t) =>
                      (t['_id'] ?? t['id'])?.toString() == pinnedId.toString(),
                  orElse: () => templates.first,
                )
              : templates.first)
        : {
            'title': '🌧️ {{name}} जी, आज का स्पेशल ऑफर लाइव है!',
            'body':
                '{{shopName}} के लिए कीटनाशक और फफूंदनाशक पर 15% एक्स्ट्रा मार्जिन।',
            'imageUrl': '',
            'button1': '⚡ Open Offer',
            'button2': '📞 Call Support',
          };

    final title = _replaceVariables(currentTemplate['title'] ?? '');
    final body = _replaceVariables(currentTemplate['body'] ?? '');
    final bannerImg = (currentTemplate['imageUrl'] ?? '').toString();
    final btn1 =
        currentTemplate['button1'] ??
        currentTemplate['btn1Text'] ??
        '⚡ Open Offer';
    final btn2 =
        currentTemplate['button2'] ??
        currentTemplate['btn2Text'] ??
        '📞 Call Support';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Device Type Switcher & Variable Simulation Controls
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Device OS Preview',
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF475569),
              ),
            ),
            Row(
              children: [
                ChoiceChip(
                  label: const Text('Android'),
                  selected: _simulatorDeviceType == 0,
                  onSelected: (v) => setState(() => _simulatorDeviceType = 0),
                  selectedColor: const Color(0xFF16A34A),
                  labelStyle: GoogleFonts.outfit(
                    fontSize: 11,
                    color: _simulatorDeviceType == 0
                        ? Colors.white
                        : const Color(0xFF475569),
                  ),
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  label: const Text('iOS / iPhone'),
                  selected: _simulatorDeviceType == 1,
                  onSelected: (v) => setState(() => _simulatorDeviceType = 1),
                  selectedColor: const Color(0xFF0F172A),
                  labelStyle: GoogleFonts.outfit(
                    fontSize: 11,
                    color: _simulatorDeviceType == 1
                        ? Colors.white
                        : const Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Live Smartphone Mockup Shell
        Center(
          child: Container(
            width: 380,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
              border: Border.all(color: const Color(0xFF334155), width: 3),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Speaker & Camera notch / Dynamic island
                Container(
                  width: 90,
                  height: 18,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF1E293B),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Clock & Date display
                Text(
                  '09:41',
                  style: GoogleFonts.outfit(
                    fontSize: 42,
                    fontWeight: FontWeight.w300,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Friday, August 22',
                  style: GoogleFonts.outfit(
                    fontSize: 12.5,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 20),

                // Push Notification Card on Lock Screen
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF16A34A),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(
                              Icons.grass_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Krishi Kranti',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'Now',
                            style: GoogleFonts.outfit(
                              fontSize: 10.5,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        title.isNotEmpty ? title : 'Notification Headline',
                        style: GoogleFonts.outfit(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        body.isNotEmpty ? body : 'Notification Body Content...',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: const Color(0xFF334155),
                          height: 1.3,
                        ),
                      ),
                      if (bannerImg.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            bannerImg,
                            height: 110,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const SizedBox.shrink(),
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      // Interactive Action CTA Pills
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF16A34A),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                btn1,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          if (btn2.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0xFFCBD5E1),
                                  ),
                                ),
                                child: Text(
                                  btn2,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF334155),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Variable Live Preview Tuner
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Simulate Dealer Profile Tags',
                style: GoogleFonts.outfit(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        labelText: 'Dealer Name {{name}}',
                        isDense: true,
                      ),
                      controller: TextEditingController(
                        text: _previewDealerName,
                      ),
                      onChanged: (v) => setState(() => _previewDealerName = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        labelText: 'Shop Name {{shopName}}',
                        isDense: true,
                      ),
                      controller: TextEditingController(text: _previewShopName),
                      onChanged: (v) => setState(() => _previewShopName = v),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.search_off_rounded,
            size: 48,
            color: Color(0xFF94A3B8),
          ),
          const SizedBox(height: 12),
          Text(
            'No matching campaigns found',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Try adjusting your search keywords or category filters.',
            style: GoogleFonts.outfit(
              fontSize: 13,
              color: const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoSelectionPlaceholder() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.touch_app_rounded,
                size: 32,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Select any Segment Card',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Click on any push campaign card from the left studio to manage notification copies, reorder sequence, and test in live lock screen simulator.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 12.5,
                color: const Color(0xFF94A3B8),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Modals and Dialogs ---

  void _showCreateSegmentDialog(PushCampaignsState state) {
    CreateSegmentDialog.show(context);
  }

  void _showEditSegmentDialog(
    Map<String, dynamic> campaign,
    PushCampaignsState state,
  ) {
    EditSegmentDialog.show(context, campaign);
  }

  void _showAddTemplateDialog(String segmentKey) {
    AddTemplateDialog.show(context, segmentKey);
  }

  void _showEditTemplateDialog(
    String segmentKey,
    Map<String, dynamic> template,
  ) {
    EditTemplateDialog.show(
      context,
      segmentKey: segmentKey,
      template: template,
    );
  }

  void _showTestPushDialog(String segmentKey, Map<String, dynamic>? template) {
    TestPushDialog.show(
      context,
      segmentKey: segmentKey,
      template: template,
    );
  }

  void _triggerInstantBroadcast(String segmentKey) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '🚀 Trigger Instant Broadcast for Segment $segmentKey?',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'This will immediately send live push notifications to all currently eligible users in Segment $segmentKey.',
          style: GoogleFonts.outfit(
            fontSize: 13.5,
            color: const Color(0xFF475569),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<PushCampaignsBloc>().add(
                TriggerBroadcastEvent(segmentKey: segmentKey),
              );
            },
            child: const Text('Dispatch Now'),
          ),
        ],
      ),
    );
  }

  void _deleteSegment(String segmentKey) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Segment $segmentKey?',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: AppTheme.error,
          ),
        ),
        content: Text(
          'Are you sure you want to delete Segment $segmentKey? All its copies, rotation history, and schedule will be permanently removed.',
          style: GoogleFonts.outfit(fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<PushCampaignsBloc>().add(
                DeleteCampaignSegmentEvent(segmentKey),
              );
            },
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );
  }

  void _deleteTemplate(String segmentKey, String templateId) {
    context.read<PushCampaignsBloc>().add(
      DeleteCampaignTemplateEvent(
        segmentKey: segmentKey,
        templateId: templateId,
      ),
    );
  }

  Future<void> _pickScheduledTime(String segmentKey, String currentTime) async {
    final parts = currentTime.split(':');
    final initialHour = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 9 : 9;
    final initialMin = parts.length > 1 ? int.tryParse(parts[1]) ?? 30 : 30;

    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initialHour, minute: initialMin),
      helpText: 'Select Daily Dispatch Time (Kolkata IST)',
    );

    if (picked != null) {
      final formatted =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      if (!mounted) return;
      context.read<PushCampaignsBloc>().add(
        UpdateCampaignScheduleEvent(
          segmentKey: segmentKey,
          scheduledTime: formatted,
        ),
      );
    }
  }

  Widget _buildShimmerLoading(BuildContext context) {
    return Row(
      children: [
        // Main Studio Skeleton
        Expanded(
          flex: 3,
          child: Shimmer.fromColors(
            baseColor: Colors.grey.shade200,
            highlightColor: Colors.grey.shade50,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                // 1. Header Shimmer
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 240,
                              height: 22,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              width: 360,
                              height: 14,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Container(
                          width: 110,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          width: 130,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // 2. Metrics Tiles Shimmer
                Row(
                  children: List.generate(
                    4,
                    (index) => Expanded(
                      child: Container(
                        margin: EdgeInsets.only(right: index < 3 ? 12 : 0),
                        height: 84,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // 3. Search & Filter Bar Shimmer
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: List.generate(
                          6,
                          (index) => Container(
                            margin: const EdgeInsets.only(right: 8),
                            width: 100,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // 4. Segment Cards Shimmer
                ...List.generate(
                  3,
                  (index) => Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    height: 180,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Right Sidebar Inspector Shimmer
        if (Responsive.isDesktop(context))
          Container(
            width: 480,
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(left: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Shimmer.fromColors(
              baseColor: Colors.grey.shade200,
              highlightColor: Colors.grey.shade50,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      height: 460,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(32),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
