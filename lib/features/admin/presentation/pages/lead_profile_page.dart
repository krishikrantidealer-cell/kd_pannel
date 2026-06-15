import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kd_pannel/app_theme.dart';
import 'package:kd_pannel/core/network/api_client.dart';
import 'package:kd_pannel/core/responsive/responsive.dart';
import 'package:url_launcher/url_launcher.dart';

class LeadProfilePage extends StatefulWidget {
  const LeadProfilePage({super.key});

  @override
  State<LeadProfilePage> createState() => _LeadProfilePageState();
}

class _LeadProfilePageState extends State<LeadProfilePage>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _lead;
  bool _isLoading = false;
  List<Map<String, dynamic>> _salesAgents = [];
  late TabController _tabController;
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_selectedTabIndex != _tabController.index) {
        setState(() => _selectedTabIndex = _tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_lead == null) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, dynamic>) {
        _lead = Map<String, dynamic>.from(args);
      }
      _fetchSalesAgents();
    }
  }

  Future<void> _fetchSalesAgents() async {
    try {
      final res = await ApiClient().get('/users?role=sales');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && mounted) {
          setState(() {
            _salesAgents = List<Map<String, dynamic>>.from(data['users'] ?? []);
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading sales agents: $e');
    }
  }

  Future<void> _convertDealer() async {
    if (_lead == null) return;
    setState(() => _isLoading = true);
    try {
      final userId = _lead!['id'];
      final res = await ApiClient().put('/users/$userId/kyc', {
        'status': 'verified',
      });
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('KYC Approved! User is now a Dealer.'),
              backgroundColor: AppTheme.success,
            ),
          );
          if (mounted) {
            Navigator.pop(context); // Go back
          }
        }
      } else {
        throw Exception('Failed to verify KYC: ${res.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _rejectKyc(String reason) async {
    if (_lead == null) return;
    setState(() => _isLoading = true);
    try {
      final userId = _lead!['id'];
      final res = await ApiClient().put('/users/$userId/kyc', {
        'status': 'rejected',
        'reason': reason,
      });
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('KYC Rejected.'),
              backgroundColor: AppTheme.error,
            ),
          );
          if (mounted) {
            Navigator.pop(context); // Go back
          }
        }
      } else {
        throw Exception('Failed to reject KYC: ${res.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showRejectDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject KYC Verification'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Reason for rejection',
            hintText: 'e.g., Shop licence image is blurry or expired',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final reason = controller.text.trim();
              if (reason.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Rejection reason is required')),
                );
                return;
              }
              Navigator.pop(context);
              _rejectKyc(reason);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Reject', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _assignAgent(String? agentId) async {
    if (_lead == null) return;
    try {
      final userId = _lead!['id'];
      final res = await ApiClient().put('/users/$userId/assign-agent', {
        'agentId': agentId,
      });
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Agent assigned successfully'),
              backgroundColor: AppTheme.success,
            ),
          );
          if (mounted) {
            setState(() {
              final newAgent = data['user']?['assignedAgent'];
              _lead!['agentId'] = newAgent?['_id'];
              _lead!['agent'] = newAgent != null
                  ? '${newAgent['firstName'] ?? ''} ${newAgent['lastName'] ?? ''}'
                        .trim()
                  : '-';
            });
          }
        }
      } else {
        throw Exception('Failed to assign agent: ${res.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
      );
    }
  }

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open link: $urlString'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_lead == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.primaryColor),
        ),
      );
    }

    final isMobile = Responsive.isMobile(context);
    final isTablet = Responsive.isTablet(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            )
          : SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 16 : (isTablet ? 24 : 40),
                vertical: isMobile ? 20 : 32,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBreadcrumbs(context, isMobile),
                  SizedBox(height: isMobile ? 20 : 28),
                  _HeroProfileSection(
                    lead: _lead!,
                    onConvertDealer: _convertDealer,
                    onRejectKyc: _showRejectDialog,
                  ),
                  SizedBox(height: isMobile ? 24 : 32),

                  // Pill-style tab bar
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.borderColor),
                      boxShadow: AppTheme.softShadow,
                    ),
                    padding: const EdgeInsets.all(3),
                    child: TabBar(
                      controller: _tabController,
                      labelColor: Colors.white,
                      unselectedLabelColor: AppTheme.textSecondary,
                      indicator: BoxDecoration(
                        color: AppTheme.primaryColor,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      splashBorderRadius: BorderRadius.circular(9),
                      labelStyle: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      unselectedLabelStyle: GoogleFonts.outfit(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      tabs: const [
                        Tab(text: 'Lead Information'),
                        Tab(text: 'KYC Documents'),
                        Tab(text: 'Activity Timeline'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Animated tab content
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.04),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: KeyedSubtree(
                      key: ValueKey(_selectedTabIndex),
                      child: _buildTabContent(isMobile, isTablet),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildTabContent(bool isMobile, bool isTablet) {
    switch (_selectedTabIndex) {
      case 0:
        return _LeadInformationCard(
          lead: _lead!,
          salesAgents: _salesAgents,
          onAssignAgent: _assignAgent,
        );
      case 1:
        return _DealerKycDocumentsCard(
          lead: _lead!,
          onViewDocument: _launchUrl,
        );
      case 2:
        return const _ActivityTimelineCard();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildBreadcrumbs(BuildContext context, bool isMobile) {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(
            Icons.arrow_back,
            size: isMobile ? 18 : 20,
            color: const Color(0xFF6B7280),
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          splashRadius: 20,
        ),
        const SizedBox(width: 12),
        _BreadcrumbItem(label: 'Leads', onTap: () => Navigator.pop(context)),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            '/',
            style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 15),
          ),
        ),
        const Text(
          'Lead Profile',
          style: TextStyle(
            color: Color(0xFF111827),
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _BreadcrumbItem extends StatefulWidget {
  final String label;
  final VoidCallback onTap;

  const _BreadcrumbItem({required this.label, required this.onTap});

  @override
  State<_BreadcrumbItem> createState() => _BreadcrumbItemState();
}

class _BreadcrumbItemState extends State<_BreadcrumbItem> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Text(
          widget.label,
          style: TextStyle(
            color: const Color(0xFF6B7280),
            fontSize: 15,
            fontWeight: FontWeight.w500,
            decoration: (isHovered || isMobile)
                ? TextDecoration.underline
                : TextDecoration.none,
          ),
        ),
      ),
    );
  }
}

class _HeroProfileSection extends StatelessWidget {
  final Map<String, dynamic> lead;
  final VoidCallback onConvertDealer;
  final VoidCallback onRejectKyc;

  const _HeroProfileSection({
    required this.lead,
    required this.onConvertDealer,
    required this.onRejectKyc,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final isTablet = Responsive.isTablet(context);

    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: isMobile ? 0 : 240),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(isMobile ? 20 : 28),
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFFF3FAEE), Color(0xFFFFFDF0)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: isMobile ? -100 : -40,
            bottom: isMobile ? -100 : -60,
            child: Opacity(
              opacity: 0.12,
              child: Container(
                width: isMobile ? 260 : 340,
                height: isMobile ? 260 : 340,
                decoration: const BoxDecoration(
                  color: Color(0xFF2E7D32),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          Positioned(
            right: isMobile ? 40 : 140,
            top: isMobile ? -100 : -70,
            child: Opacity(
              opacity: 0.08,
              child: Container(
                width: isMobile ? 200 : 240,
                height: isMobile ? 200 : 240,
                decoration: const BoxDecoration(
                  color: Color(0xFF4CAF50),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          if (!isMobile)
            Positioned(
              right: 48,
              top: 48,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2E7D32).withOpacity(0.15),
                      blurRadius: 50,
                      spreadRadius: 20,
                    ),
                  ],
                ),
              ),
            ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.1)),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 20 : (isTablet ? 32 : 48),
              vertical: isMobile ? 32 : 32,
            ),
            child: _buildProfileInfo(context, isMobile, isTablet),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileInfo(BuildContext context, bool isMobile, bool isTablet) {
    final stateText = lead['state'].toString().isNotEmpty
        ? ', ${lead['state']}'
        : '';
    final locationText = '${lead['city']}$stateText';

    return Column(
      crossAxisAlignment: isMobile
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          lead['name'],
          textAlign: isMobile ? TextAlign.center : TextAlign.start,
          style: TextStyle(
            fontSize: isMobile ? 26 : (isTablet ? 32 : 38),
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1B5E20),
            letterSpacing: isMobile ? -0.5 : -1.0,
          ),
        ),
        const SizedBox(height: 18),
        if (isMobile)
          Column(
            children: [
              _buildHeroContactItem(Icons.phone_outlined, lead['phone']),
              const SizedBox(height: 8),
              _buildHeroContactItem(
                Icons.location_on_outlined,
                locationText.isNotEmpty ? locationText : '-',
              ),
              const SizedBox(height: 8),
              _buildHeroContactItem(
                Icons.hub_outlined,
                'Source: ${lead['source']}',
              ),
            ],
          )
        else
          Wrap(
            alignment: WrapAlignment.start,
            spacing: 12,
            runSpacing: 8,
            children: [
              _buildHeroContactItem(Icons.phone_outlined, lead['phone']),
              _buildDivider(),
              _buildHeroContactItem(
                Icons.location_on_outlined,
                locationText.isNotEmpty ? locationText : '-',
              ),
              _buildDivider(),
              _buildHeroContactItem(
                Icons.hub_outlined,
                'Source: ${lead['source']}',
              ),
            ],
          ),
        SizedBox(height: isMobile ? 32 : 36),
        Wrap(
          alignment: isMobile ? WrapAlignment.center : WrapAlignment.start,
          spacing: isMobile ? 12 : 16,
          runSpacing: isMobile ? 12 : 16,
          children: [
            _ActionButton(
              icon: Icons.chat_bubble_outline,
              label: 'WhatsApp',
              color: const Color(0xFF128C7E),
              isSolid: true,
              width: isMobile
                  ? (MediaQuery.of(context).size.width - 60) / 2
                  : null,
            ),
            _ActionButton(
              icon: Icons.person_add_outlined,
              label: 'Convert Dealer',
              color: const Color(0xFF1976D2),
              isSolid: true,
              onTap: onConvertDealer,
              width: isMobile
                  ? (MediaQuery.of(context).size.width - 60) / 3
                  : null,
            ),
            _ActionButton(
              icon: Icons.block_outlined,
              label: 'Reject KYC',
              color: const Color(0xFFD32F2F),
              isSolid: true,
              onTap: onRejectKyc,
              width: isMobile
                  ? (MediaQuery.of(context).size.width - 60) / 3
                  : null,
            ),
          ],
        ),
      ],
    );
  }



  Widget _buildHeroContactItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF2E7D32)),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            fontSize: 15,
            color: Color(0xFF4B5563),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        '|',
        style: TextStyle(
          color: Color(0xFFD1D5DB),
          fontWeight: FontWeight.w400,
          fontSize: 16,
        ),
      ),
    );
  }
}

class _ActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isSolid;
  final double? width;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    this.isSolid = false,
    this.width,
    this.onTap,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return MouseRegion(
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: isMobile ? 48 : 44,
          width: widget.width,
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 22),
          decoration: BoxDecoration(
            color: widget.isSolid
                ? (isHovered ? widget.color.withOpacity(0.9) : widget.color)
                : (isHovered ? widget.color.withOpacity(0.08) : Colors.white),
            borderRadius: BorderRadius.circular(12),
            border: widget.isSolid
                ? null
                : Border.all(
                    color: widget.color.withOpacity(isHovered ? 0.8 : 0.4),
                    width: 1.5,
                  ),
            boxShadow: isHovered
                ? [
                    BoxShadow(
                      color: widget.color.withOpacity(0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: isMobile ? 18 : 19,
                color: widget.isSolid ? Colors.white : widget.color,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  widget.label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: isMobile ? 13 : 14,
                    fontWeight: FontWeight.w700,
                    color: widget.isSolid ? Colors.white : widget.color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LeadInformationCard extends StatelessWidget {
  final Map<String, dynamic> lead;
  final List<Map<String, dynamic>> salesAgents;
  final Function(String? agentId) onAssignAgent;

  const _LeadInformationCard({
    required this.lead,
    required this.salesAgents,
    required this.onAssignAgent,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return Container(
      constraints: BoxConstraints(minHeight: isMobile ? 0 : 580),
      padding: EdgeInsets.all(isMobile ? 20 : 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Lead Information',
            style: TextStyle(
              fontSize: isMobile ? 18 : 20,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF111827),
            ),
          ),
          SizedBox(height: isMobile ? 20 : 24),
          _buildInfoRow(
            Icons.person_outline,
            'Lead Name',
            lead['name'],
            Colors.green,
          ),
          _buildDividerRow(),
          _buildInfoRow(
            Icons.phone_android_outlined,
            'Phone Number',
            lead['phone'],
            Colors.blue,
          ),
          _buildDividerRow(),
          _buildInfoRow(
            Icons.location_city_outlined,
            'City',
            lead['city'].toString().isNotEmpty ? lead['city'] : '-',
            Colors.orange,
          ),
          _buildDividerRow(),
          _buildInfoRow(
            Icons.map_outlined,
            'State',
            lead['state'].toString().isNotEmpty ? lead['state'] : '-',
            Colors.purple,
          ),
          _buildDividerRow(),
          _buildInfoRow(
            Icons.campaign_outlined,
            'Lead Source',
            lead['source'],
            Colors.teal,
          ),
          _buildDividerRow(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.indigo.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.badge_outlined,
                    size: 16,
                    color: Colors.indigo,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  flex: 2,
                  child: Text(
                    'Assigned Sales',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value:
                            salesAgents.any(
                              (agent) => agent['_id'] == lead['agentId'],
                            )
                            ? lead['agentId']
                            : null,
                        isExpanded: false,
                        alignment: Alignment.centerRight,
                        icon: const Icon(Icons.arrow_drop_down, size: 16),
                        hint: Text(
                          '-',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            color: const Color(0xFF111827),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        onChanged: (String? newAgentId) {
                          onAssignAgent(newAgentId);
                        },
                        items: [
                          DropdownMenuItem<String>(
                            value: null,
                            child: Text(
                              '-',
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                color: const Color(0xFF111827),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          ...salesAgents.map((agent) {
                            final agentName =
                                '${agent['firstName'] ?? ''} ${agent['lastName'] ?? ''}'
                                    .trim();
                            return DropdownMenuItem<String>(
                              value: agent['_id'],
                              child: Text(
                                agentName.isNotEmpty
                                    ? agentName
                                    : (agent['phoneNumber'] ?? ''),
                                style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  color: const Color(0xFF111827),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          _buildDividerRow(),
          _buildInfoRow(
            Icons.history_outlined,
            'Last Activity',
            lead['activity'],
            Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF111827),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDividerRow() =>
      const Divider(height: 1, color: Color(0xFFF1F5F9));
}

class _ActivityTimelineCard extends StatelessWidget {
  const _ActivityTimelineCard();

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return Container(
      constraints: BoxConstraints(minHeight: isMobile ? 0 : 580),
      padding: EdgeInsets.all(isMobile ? 20 : 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Activity Timeline',
            style: TextStyle(
              fontSize: isMobile ? 18 : 20,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF111827),
            ),
          ),
          SizedBox(height: isMobile ? 20 : 16),
          Column(
            children: [
              _buildTimelineItem(
                icon: Icons.campaign_outlined,
                iconColor: Colors.blue,
                title: 'Lead Created',
                time: '24 Oct 2023, 10:30 AM',
                isMobile: isMobile,
              ),
              _buildTimelineItem(
                icon: Icons.chat_bubble_outline,
                iconColor: const Color(0xFF128C7E),
                title: 'WhatsApp Chat Started',
                time: '24 Oct 2023, 11:15 AM',
                isMobile: isMobile,
              ),
              _buildTimelineItem(
                icon: Icons.support_agent_outlined,
                iconColor: Colors.purple,
                title: 'Sales Agent Contacted Lead',
                time: '25 Oct 2023, 09:30 AM',
                isMobile: isMobile,
              ),
              _buildTimelineItem(
                icon: Icons.assignment_outlined,
                iconColor: Colors.orange,
                title: 'KYC Submitted',
                time: '25 Oct 2023, 02:15 PM',
                isMobile: isMobile,
              ),
              _buildTimelineItem(
                icon: Icons.verified_outlined,
                iconColor: Colors.teal,
                title: 'GST Verified',
                time: '26 Oct 2023, 10:00 AM',
                isMobile: isMobile,
              ),
              _buildTimelineItem(
                icon: Icons.person_add_alt_1_outlined,
                iconColor: const Color(0xFF2E7D32),
                title: 'Dealer Converted',
                time: '26 Oct 2023, 04:30 PM',
                isMobile: isMobile,
              ),
              _buildTimelineItem(
                icon: Icons.shopping_bag_outlined,
                iconColor: const Color(0xFFF57C00),
                title: 'Order Placed',
                time: '27 Oct 2023, 11:20 AM',
                isLast: true,
                isMobile: isMobile,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFE5E7EB)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
              ),
              child: const Text(
                'See More',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String time,
    bool isLast = false,
    required bool isMobile,
  }) {
    final item = _TimelineItem(
      icon: icon,
      iconColor: iconColor,
      title: title,
      time: time,
      isLast: isLast,
    );

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
      child: item,
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String time;
  final bool isLast;

  const _TimelineItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.time,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                shape: BoxShape.circle,
                border: Border.all(color: iconColor.withOpacity(0.2), width: 1),
              ),
              child: Icon(icon, size: 16, color: iconColor),
            ),
            if (!isLast)
              Container(
                width: 2.5,
                height: 32,
                margin: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      iconColor.withOpacity(0.4),
                      const Color(0xFFE5E7EB),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: isMobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        time,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF9CA3AF),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      Text(
                        time,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF9CA3AF),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

class _DealerKycDocumentsCard extends StatelessWidget {
  final Map<String, dynamic> lead;
  final Function(String url) onViewDocument;

  const _DealerKycDocumentsCard({
    required this.lead,
    required this.onViewDocument,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final hasLicence =
        lead['licenceImage'] != null &&
        lead['licenceImage'].toString().isNotEmpty;
    final hasShopImage =
        lead['shopImage'] != null &&
        lead['shopImage'].toString().isNotEmpty;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 20 : 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'KYC Documents',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 32),
          if (isMobile)
            Column(
              children: [
                _KycDocumentCard(
                  title: 'GST Certificate / Licence',
                  status: lead['kycStatus'],
                  subtext: lead['gstNumber'].toString().isNotEmpty
                      ? lead['gstNumber']
                      : 'No GST Number',
                  icon: Icons.description_outlined,
                  onTap: hasLicence
                      ? () => onViewDocument(lead['licenceImage'])
                      : null,
                ),
                const SizedBox(height: 16),
                _KycDocumentCard(
                  title: 'Shop Image',
                  status: lead['kycStatus'],
                  icon: Icons.storefront_outlined,
                  onTap: hasShopImage
                      ? () => onViewDocument(lead['shopImage'])
                      : null,
                ),
              ],
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _KycDocumentCard(
                  title: 'GST Certificate / Licence',
                  status: lead['kycStatus'],
                  subtext: lead['gstNumber'].toString().isNotEmpty
                      ? lead['gstNumber']
                      : 'No GST Number',
                  icon: Icons.description_outlined,
                  onTap: hasLicence
                      ? () => onViewDocument(lead['licenceImage'])
                      : null,
                ),
                const SizedBox(width: 24),
                _KycDocumentCard(
                  title: 'Shop Image',
                  status: lead['kycStatus'],
                  icon: Icons.storefront_outlined,
                  onTap: hasShopImage
                      ? () => onViewDocument(lead['shopImage'])
                      : null,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _KycDocumentCard extends StatefulWidget {
  final String title;
  final String status;
  final String? subtext;
  final IconData icon;
  final VoidCallback? onTap;

  const _KycDocumentCard({
    required this.title,
    required this.status,
    this.subtext,
    required this.icon,
    this.onTap,
  });

  @override
  State<_KycDocumentCard> createState() => _KycDocumentCardState();
}

class _KycDocumentCardState extends State<_KycDocumentCard> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    final bool isMobile = Responsive.isMobile(context);
    final String displayStatus = widget.status.toUpperCase();
    final bool isVerified = widget.status.toLowerCase() == 'verified';
    final bool isRejected = widget.status.toLowerCase() == 'rejected';
    final Color badgeColor = isVerified
        ? const Color(0xFF10B981)
        : isRejected
        ? const Color(0xFFEF4444)
        : const Color(0xFFF59E0B);

    final card = MouseRegion(
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isHovered && widget.onTap != null
                  ? const Color(0xFF2E7D32).withOpacity(0.5)
                  : const Color(0xFFE5E7EB),
            ),
            boxShadow: [
              BoxShadow(
                color: isHovered && widget.onTap != null
                    ? const Color(0xFF2E7D32).withOpacity(0.08)
                    : Colors.black.withOpacity(0.03),
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
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF1F8E9),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      widget.icon,
                      size: 20,
                      color: const Color(0xFF2E7D32),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: badgeColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isVerified ? Icons.check_circle : Icons.info_outline,
                          size: 12,
                          color: badgeColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          displayStatus,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: badgeColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 6),
              if (widget.subtext != null)
                Text(
                  widget.subtext!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                )
              else
                const SizedBox(height: 14),
            ],
          ),
        ),
      ),
    );

    return isMobile ? card : Expanded(child: card);
  }
}
