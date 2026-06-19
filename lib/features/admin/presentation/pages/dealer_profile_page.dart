import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kd_pannel/app_theme.dart';
import 'package:kd_pannel/core/network/api_client.dart';
import 'package:kd_pannel/core/responsive/responsive.dart';
import 'package:kd_pannel/features/admin/presentation/pages/orders_page.dart';
import 'package:kd_pannel/util/dealers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class DealerProfilePage extends StatefulWidget {
  const DealerProfilePage({super.key});

  @override
  State<DealerProfilePage> createState() => _DealerProfilePageState();
}

class _DealerProfilePageState extends State<DealerProfilePage> {
  Dealer? _dealer;
  bool _isLoading = false;
  List<Map<String, dynamic>> _salesAgents = [];
  List<Map<String, dynamic>> _orders = [];
  bool _isLoadingOrders = false;
  String? _agentId;
  String? _agentName;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_dealer == null) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Dealer) {
        _dealer = args;
        _agentId = args.agentId;
        _agentName = args.agent;
        _saveDealerToCache(_dealer!);
        _refreshDealerDetails();
      } else {
        _loadDealerFromCache();
      }
      _fetchSalesAgents();
      _fetchOrders();
    }
  }

  Future<void> _saveDealerToCache(Dealer dealer) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('kd_current_dealer', jsonEncode(dealer.toMap()));
    } catch (e) {
      debugPrint('Error saving dealer to cache: $e');
    }
  }

  Future<void> _loadDealerFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dealerStr = prefs.getString('kd_current_dealer');
      if (dealerStr != null) {
        if (mounted) {
          setState(() {
            _dealer = Dealer.fromMap(jsonDecode(dealerStr));
            _agentId = _dealer?.agentId;
            _agentName = _dealer?.agent;
          });
        }
        _refreshDealerDetails();
        _fetchOrders();
      }
    } catch (e) {
      debugPrint('Error loading dealer from cache: $e');
    }
  }

  Future<void> _refreshDealerDetails() async {
    if (_dealer == null) return;
    try {
      final userId = _dealer!.id;
      if (userId == null) return;
      final res = await ApiClient().get('/users');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) {
          final users = List<Map<String, dynamic>>.from(data['users'] ?? []);
          final freshUser = users.firstWhere(
            (u) => u['_id'] == userId || u['id'] == userId,
            orElse: () => <String, dynamic>{},
          );
          if (freshUser.isNotEmpty) {
            final String agentName = freshUser['assignedAgent'] != null
                ? '${freshUser['assignedAgent']['firstName'] ?? ''} ${freshUser['assignedAgent']['lastName'] ?? ''}'
                      .trim()
                : '-';

            final String name =
                (freshUser['shopName'] != null &&
                    freshUser['shopName'].toString().trim().isNotEmpty)
                ? freshUser['shopName']
                : ((freshUser['firstName'] != null &&
                          freshUser['firstName'].toString().trim().isNotEmpty)
                      ? '${freshUser['firstName']} ${freshUser['lastName'] ?? ''}'
                            .trim()
                      : (freshUser['phoneNumber'] ?? 'Unnamed Dealer'));

            final freshDealer = Dealer(
              name: name,
              phone: freshUser['phoneNumber'] ?? '',
              city: freshUser['address']?['cityTehsil'] ?? '',
              state: freshUser['address']?['state'] ?? '',
              agent: agentName.isNotEmpty ? agentName : '-',
              gstStatus: 'Verified',
              totalOrders: _orders.length,
              purchaseValue: _dealer!.purchaseValue,
              isHighValue: _dealer!.isHighValue,
              isInactive: _orders.isEmpty,
              id: freshUser['_id'],
              agentId: freshUser['assignedAgent']?['_id'],
              licenceImage: freshUser['licenceImage'],
              shopImage: freshUser['shopImage'],
              gstNumber: freshUser['gstNumber'],
              email: freshUser['email'],
              userType: freshUser['userType'],
              kycStatus: freshUser['kycStatus'],
              address: freshUser['address'] != null
                  ? Map<String, dynamic>.from(freshUser['address'])
                  : null,
            );

            if (mounted) {
              setState(() {
                _dealer = freshDealer;
                _agentId = freshDealer.agentId;
                _agentName = freshDealer.agent;
              });
            }
            _saveDealerToCache(freshDealer);
          }
        }
      }
    } catch (e) {
      debugPrint('Error refreshing dealer details: $e');
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

  Future<void> _fetchOrders() async {
    if (_dealer?.id == null) return;
    setState(() => _isLoadingOrders = true);
    try {
      final res = await ApiClient().get('/orders/admin/all');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) {
          final List rawOrders = data['orders'] ?? [];
          final String userId = _dealer!.id!;

          final List<Map<String, dynamic>> filtered = [];
          for (final o in rawOrders) {
            if (o is Map && o['user']?['_id'] == userId) {
              filtered.add(Map<String, dynamic>.from(o));
            }
          }

          if (mounted) {
            setState(() {
              _orders = filtered;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading orders: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingOrders = false;
        });
      }
    }
  }

  Future<void> _assignAgent(String? newAgentId) async {
    if (_dealer?.id == null) return;
    setState(() => _isLoading = true);
    try {
      final res = await ApiClient().put('/users/${_dealer!.id}/assign-agent', {
        'agentId': newAgentId,
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
              _agentId = newAgent?['_id'];
              _agentName = newAgent != null
                  ? '${newAgent['firstName'] ?? ''} ${newAgent['lastName'] ?? ''}'
                        .trim()
                  : '-';
            });
            final updatedDealer = Dealer(
              name: _dealer!.name,
              phone: _dealer!.phone,
              city: _dealer!.city,
              state: _dealer!.state,
              agent: _agentName ?? _dealer!.agent,
              gstStatus: _dealer!.gstStatus,
              totalOrders: _dealer!.totalOrders,
              purchaseValue: _dealer!.purchaseValue,
              isHighValue: _dealer!.isHighValue,
              isInactive: _dealer!.isInactive,
              id: _dealer!.id,
              agentId: _agentId ?? _dealer!.agentId,
              licenceImage: _dealer!.licenceImage,
              shopImage: _dealer!.shopImage,
              gstNumber: _dealer!.gstNumber,
              email: _dealer!.email,
              userType: _dealer!.userType,
              kycStatus: _dealer!.kycStatus,
              address: _dealer!.address,
            );
            _saveDealerToCache(updatedDealer);
          }
        }
      } else {
        throw Exception('Failed to assign agent: ${res.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
    if (_dealer == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.primaryColor),
        ),
      );
    }

    final isMobile = Responsive.isMobile(context);
    final isTablet = Responsive.isTablet(context);

    // Dynamic dealer updated by agent selection
    final currentDealer = Dealer(
      name: _dealer!.name,
      phone: _dealer!.phone,
      city: _dealer!.city,
      state: _dealer!.state,
      agent: _agentName ?? _dealer!.agent,
      gstStatus: _dealer!.gstStatus,
      totalOrders: _orders.length,
      purchaseValue: _dealer!.purchaseValue,
      isHighValue: _dealer!.isHighValue,
      isInactive: _orders.isEmpty,
      id: _dealer!.id,
      agentId: _agentId ?? _dealer!.agentId,
      licenceImage: _dealer!.licenceImage,
      shopImage: _dealer!.shopImage,
      gstNumber: _dealer!.gstNumber,
      email: _dealer!.email,
      userType: _dealer!.userType,
      kycStatus: _dealer!.kycStatus,
      address: _dealer!.address,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
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
                  // 1. BACK HEADER
                  _buildBreadcrumbs(context, isMobile),
                  const SizedBox(height: 16),

                  // 2. HEADER SECTION
                  _DealerHeroCard(dealer: currentDealer),
                  const SizedBox(height: 24),

                  // 3. STATS CARDS ROW
                  _StatsCardsSection(dealer: currentDealer, orders: _orders),
                  const SizedBox(height: 24),

                  // 4. INFORMATION & DOCUMENTS ROW
                  if (!isMobile)
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            flex: 1,
                            child: _DealerInformationCard(
                              dealer: currentDealer,
                              salesAgents: _salesAgents,
                              currentAgentId: _agentId,
                              onAssignAgent: _assignAgent,
                            ),
                          ),
                          const SizedBox(width: 32),
                          Expanded(
                            flex: 1,
                            child: _DealerKycDocumentsCard(
                              dealer: currentDealer,
                              onViewDocument: _launchUrl,
                            ),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    _DealerInformationCard(
                      dealer: currentDealer,
                      salesAgents: _salesAgents,
                      currentAgentId: _agentId,
                      onAssignAgent: _assignAgent,
                    ),
                    const SizedBox(height: 24),
                    _DealerKycDocumentsCard(
                      dealer: currentDealer,
                      onViewDocument: _launchUrl,
                    ),
                  ],
                  const SizedBox(height: 24),

                  // 5. ORDER HISTORY SECTION
                  _OrderHistoryCard(
                    dealer: currentDealer,
                    orders: _orders,
                    isLoading: _isLoadingOrders,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildBreadcrumbs(BuildContext context, bool isMobile) {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back,
            size: 20,
            color: Color(0xFF6B7280),
          ),
          constraints: const BoxConstraints(),
          padding: EdgeInsets.zero,
          splashRadius: 20,
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Text(
              'Back to Dealers',
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF6B7280),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DealerHeroCard extends StatelessWidget {
  final Dealer dealer;
  const _DealerHeroCard({required this.dealer});

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final isTablet = Responsive.isTablet(context);

    final String initial = dealer.name.isNotEmpty
        ? dealer.name.substring(0, 1).toUpperCase()
        : 'J';

    final Widget avatar = Container(
      width: 48,
      height: 48,
      decoration: const BoxDecoration(
        color: Color(0xFFE8F5E9),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initial,
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF298E4D),
          ),
        ),
      ),
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    avatar,
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dealer.name,
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1F2937),
                            ),
                          ),
                          const SizedBox(height: 4),
                          _buildStatusBadge(
                            dealer.gstStatus,
                            const Color(0xFF10B981),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildContactRow(isMobile),
                const SizedBox(height: 16),
                _buildActionButtons(context, isMobile, isTablet),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                avatar,
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            dealer.name,
                            style: GoogleFonts.outfit(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1F2937),
                            ),
                          ),
                          const SizedBox(width: 12),
                          _buildStatusBadge(
                            dealer.gstStatus,
                            const Color(0xFF10B981),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      _buildContactRow(isMobile),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                _buildActionButtons(context, isMobile, isTablet),
              ],
            ),
    );
  }

  Widget _buildContactRow(bool isMobile) {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _buildContactItem(Icons.phone_outlined, dealer.phone),
        _buildContactDivider(),
        _buildContactItem(
          Icons.location_on_outlined,
          dealer.city.isNotEmpty
              ? '${dealer.city}, ${dealer.state}'
              : dealer.state,
        ),
        _buildContactDivider(),
        _buildContactItem(Icons.person_outline, 'Agent: ${dealer.agent}'),
      ],
    );
  }

  Widget _buildContactDivider() {
    return Container(
      width: 4,
      height: 4,
      decoration: const BoxDecoration(
        color: Color(0xFFD1D5DB),
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildContactItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF2E7D32)),
        const SizedBox(width: 6),
        Text(
          text,
          style: GoogleFonts.outfit(
            fontSize: 14,
            color: const Color(0xFF4B5563),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    bool isMobile,
    bool isTablet,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _ActionButton(
          icon: Icons.call,
          label: 'Call',
          color: const Color(0xFF2E7D32),
          isSolid: true,
          onTap: () async {
            final url = 'tel:${dealer.phone}';
            final Uri uri = Uri.parse(url);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri);
            }
          },
        ),
        _ActionButton(
          icon: FontAwesomeIcons.whatsapp,
          label: 'WhatsApp',
          color: const Color(0xFF25D366),
          isSolid: true,
          onTap: () async {
            final cleanPhone = dealer.phone.replaceAll(RegExp(r'[^0-9]'), '');
            final url = 'https://wa.me/$cleanPhone';
            final Uri uri = Uri.parse(url);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        text,
        style: GoogleFonts.outfit(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
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

class _StatsCardsSection extends StatelessWidget {
  final Dealer dealer;
  final List<Map<String, dynamic>> orders;
  const _StatsCardsSection({required this.dealer, required this.orders});

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);
    final isMobile = Responsive.isMobile(context);

    // Calculate dynamic values based on orders
    String lastOrderDate = 'No Orders';
    if (orders.isNotEmpty) {
      dynamic latestDate =
          orders.first['placedAt'] ?? orders.first['createdAt'];
      if (latestDate != null) {
        try {
          final dt = DateTime.parse(latestDate.toString());
          final months = [
            'Jan',
            'Feb',
            'Mar',
            'Apr',
            'May',
            'Jun',
            'Jul',
            'Aug',
            'Sep',
            'Oct',
            'Nov',
            'Dec',
          ];
          lastOrderDate =
              '${dt.day.toString().padLeft(2, '0')} ${months[dt.month - 1]} ${dt.year}';
        } catch (_) {}
      }
    }

    String activeSince = 'New Account';
    if (orders.isNotEmpty) {
      dynamic oldestDateRaw =
          orders.last['placedAt'] ?? orders.last['createdAt'];
      if (oldestDateRaw != null) {
        try {
          final oldestDate = DateTime.parse(oldestDateRaw.toString());
          final difference = DateTime.now().difference(oldestDate);
          final years = difference.inDays ~/ 365;
          final months = (difference.inDays % 365) ~/ 30;
          if (years > 0) {
            activeSince = '$years Year${years > 1 ? "s" : ""}';
          } else if (months > 0) {
            activeSince = '$months Month${months > 1 ? "s" : ""}';
          } else {
            activeSince =
                '${difference.inDays} Day${difference.inDays > 1 ? "s" : ""}';
          }
        } catch (_) {}
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = isDesktop ? 24.0 : 16.0;
        final items = [
          {
            'title': 'Total Orders',
            'value': dealer.totalOrders.toString(),
            'icon': Icons.shopping_bag_outlined,
            'color': Colors.blue,
          },
          {
            'title': 'Total Purchase Value',
            'value': dealer.purchaseValue,
            'icon': Icons.currency_rupee_outlined,
            'color': Colors.green,
          },
          {
            'title': 'Last Order Date',
            'value': lastOrderDate,
            'icon': Icons.calendar_today_outlined,
            'color': Colors.purple,
          },
          {
            'title': 'Dealer Active Since',
            'value': activeSince,
            'icon': Icons.timer_outlined,
            'color': Colors.orange,
          },
        ];

        if (isDesktop) {
          return Row(
            children: items
                .map(
                  (item) => Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: item == items.last ? 0 : spacing,
                      ),
                      child: _StatCard(
                        title: item['title'] as String,
                        value: item['value'] as String,
                        icon: item['icon'] as IconData,
                        color: item['color'] as Color,
                      ),
                    ),
                  ),
                )
                .toList(),
          );
        }

        final count = isMobile ? 2 : 2;
        final width = (constraints.maxWidth - (spacing * (count - 1))) / count;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: items
              .map(
                (item) => _StatCard(
                  width: width,
                  title: item['title'] as String,
                  value: item['value'] as String,
                  icon: item['icon'] as IconData,
                  color: item['color'] as Color,
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final double? width;
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    this.width,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return Container(
      width: width,
      height: isMobile ? 110 : 120,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 16,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
          ),
          Positioned(
            left: 76,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: const Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF111827),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DealerInformationCard extends StatelessWidget {
  final Dealer dealer;
  final List<Map<String, dynamic>> salesAgents;
  final String? currentAgentId;
  final Function(String? agentId) onAssignAgent;

  const _DealerInformationCard({
    required this.dealer,
    required this.salesAgents,
    this.currentAgentId,
    required this.onAssignAgent,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final tier = dealer.isHighValue
        ? 'Platinum Distributor'
        : 'Authorized Dealer';

    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dealer Information',
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            Icons.business_outlined,
            'Dealer Name',
            dealer.name,
            Colors.green,
            isMobile,
          ),
          _buildDivider(),
          _buildInfoRow(
            Icons.phone_android_outlined,
            'Phone Number',
            dealer.phone,
            Colors.blue,
            isMobile,
          ),
          _buildDivider(),
          _buildInfoRow(
            Icons.map_outlined,
            'State',
            dealer.state.isNotEmpty ? dealer.state : '-',
            Colors.purple,
            isMobile,
          ),
          _buildDivider(),
          _buildInfoRow(
            Icons.location_city_outlined,
            'City',
            dealer.city.isNotEmpty ? dealer.city : '-',
            Colors.orange,
            isMobile,
          ),
          _buildDivider(),
          _buildInfoRow(
            Icons.receipt_outlined,
            'GST Number',
            dealer.gstNumber ?? 'Not Provided',
            Colors.red,
            isMobile,
          ),
          _buildDivider(),
          _buildInfoRow(
            Icons.category_outlined,
            'Dealer Type',
            tier,
            Colors.teal,
            isMobile,
          ),
          _buildDivider(),
          // Custom row for Assigned Agent dropdown
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.indigo.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.badge_outlined,
                    size: 14,
                    color: Colors.indigo,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Assigned Agent',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: const Color(0xFF6B7280),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value:
                              salesAgents.any(
                                (agent) => agent['_id'] == currentAgentId,
                              )
                              ? currentAgentId
                              : null,
                          isExpanded: false,
                          isDense: true,
                          alignment: Alignment.centerRight,
                          icon: const Icon(Icons.arrow_drop_down, size: 16),
                          hint: Text(
                            '-',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
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
                                  fontSize: 13,
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
                                    fontSize: 13,
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
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value,
    Color color,
    bool isMobile,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: const Color(0xFF6B7280),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: const Color(0xFF111827),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() => const Divider(height: 1, color: Color(0xFFF3F4F6));
}

class _OrderHistoryCard extends StatefulWidget {
  final Dealer dealer;
  final List<Map<String, dynamic>> orders;
  final bool isLoading;

  const _OrderHistoryCard({
    required this.dealer,
    required this.orders,
    required this.isLoading,
  });

  @override
  State<_OrderHistoryCard> createState() => _OrderHistoryCardState();
}

class _OrderHistoryCardState extends State<_OrderHistoryCard> {
  int currentPage = 1;
  static const int pageSize = 5;

  String _formatAmt(double val) {
    final s = val.toInt().toString();
    if (s.length <= 3) return s;
    final lastThree = s.substring(s.length - 3);
    var otherParts = s.substring(0, s.length - 3);
    if (otherParts.isNotEmpty) {
      otherParts = otherParts.replaceAllMapped(
        RegExp(r'(\d)(?=(\d\d)+(?!\d))'),
        (Match m) => '${m[1]},',
      );
      return '$otherParts,$lastThree';
    }
    return lastThree;
  }

  String _getProductsSummary(Map<String, dynamic> order) {
    final items = order['items'] as List?;
    if (items == null || items.isEmpty) return 'No Products';
    return items
        .map((i) => i['title'] ?? '')
        .where((t) => t.toString().isNotEmpty)
        .join(', ');
  }

  String _formatDate(dynamic dateString) {
    if (dateString == null) return '-';
    try {
      final dt = DateTime.parse(dateString.toString());
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${dt.day.toString().padLeft(2, '0')} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return dateString.toString();
    }
  }

  String _formatAmount(dynamic amt) {
    if (amt == null) return '₹ 0';
    double val = 0.0;
    if (amt is num) {
      val = amt.toDouble();
    } else {
      val = double.tryParse(amt.toString()) ?? 0.0;
    }
    return '₹ ${_formatAmt(val)}';
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'delivered':
        return const Color(0xFF10B981);
      case 'pending':
      case 'processing':
      case 'shipped':
      case 'out for delivery':
        return const Color(0xFFF59E0B);
      case 'cancelled':
      case 'failed':
      default:
        return const Color(0xFFEF4444);
    }
  }

  void _openOrder(Map<String, dynamic> rawOrder) {
    final orderModel = OrderModel.fromJson(rawOrder);
    Navigator.pushNamed(context, '/orders/details', arguments: orderModel);
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final totalOrders = widget.orders.length;

    final int totalPages = (totalOrders / pageSize).ceil().clamp(1, 9999);
    if (currentPage > totalPages) {
      currentPage = totalPages;
    }

    final startIndex = (currentPage - 1) * pageSize;
    final endIndex = startIndex + pageSize;
    final currentPageOrders = widget.orders.sublist(
      startIndex,
      endIndex > totalOrders ? totalOrders : endIndex,
    );

    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order History',
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 16),
          if (widget.isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: CircularProgressIndicator(color: AppTheme.primaryColor),
              ),
            )
          else ...[
            _buildOrderTable(context, isMobile, currentPageOrders),
            const SizedBox(height: 16),
            _buildPagination(
              isMobile,
              totalOrders,
              startIndex,
              endIndex,
              totalPages,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOrderTable(
    BuildContext context,
    bool isMobile,
    List<Map<String, dynamic>> orders,
  ) {
    if (orders.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'No orders found.',
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: const Color(0xFF6B7280),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }

    final tableWidget = Table(
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      columnWidths: const {
        0: FlexColumnWidth(1.2),
        1: FlexColumnWidth(2),
        2: FlexColumnWidth(1),
        3: FlexColumnWidth(1),
        4: FlexColumnWidth(1.2),
      },
      children: [
        TableRow(
          decoration: const BoxDecoration(
            color: Color(0xFFF9FAFB),
            border: Border(
              bottom: BorderSide(color: AppTheme.borderColor, width: 1.5),
            ),
          ),
          children: [
            _headerCell('Order ID'),
            _headerCell('Products'),
            _headerCell('Date'),
            _headerCell('Amount'),
            _headerCell('Status', isCenter: true),
          ],
        ),
        ...orders.map((o) {
          final String id = o['orderId'] ?? o['_id'] ?? '';
          final String products = _getProductsSummary(o);
          final String date = _formatDate(o['placedAt'] ?? o['createdAt']);
          final String amount = _formatAmount(o['totalAmount']);
          final String status = o['orderStatus'] ?? 'Processing';
          final Color color = _getStatusColor(status);

          return _orderRow(id, products, date, amount, status, color, o);
        }),
      ],
    );

    final borderedTable = Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.borderColor),
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: tableWidget,
    );

    if (!isMobile) return borderedTable;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(width: 600, child: borderedTable),
    );
  }

  Widget _headerCell(String text, {bool isCenter = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: isCenter
          ? Center(
              child: Text(
                text.toUpperCase(),
                style: AppTheme.tableHeader.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            )
          : Text(
              text.toUpperCase(),
              style: AppTheme.tableHeader.copyWith(fontWeight: FontWeight.w800),
            ),
    );
  }

  TableRow _orderRow(
    String id,
    String prod,
    String date,
    String amt,
    String status,
    Color statusColor,
    Map<String, dynamic> rawOrder,
  ) {
    return TableRow(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.lightBorderColor)),
      ),
      children: [
        _cell(id, isLink: true, onTap: () => _openOrder(rawOrder)),
        _cell(prod, onTap: () => _openOrder(rawOrder)),
        _cell(date, onTap: () => _openOrder(rawOrder)),
        _cell(amt, isBold: true, onTap: () => _openOrder(rawOrder)),
        Center(
          child: _statusBadge(
            status,
            statusColor,
            onTap: () => _openOrder(rawOrder),
          ),
        ),
      ],
    );
  }

  Widget _cell(
    String text, {
    bool isBold = false,
    bool isLink = false,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: MouseRegion(
        cursor: onTap != null
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Text(
            text,
            style: GoogleFonts.outfit(
              fontSize: 13,
              color: isLink
                  ? AppTheme.primaryColor
                  : (isBold
                        ? const Color(0xFF111827)
                        : const Color(0xFF4B5563)),
              fontWeight: (isBold || isLink)
                  ? FontWeight.w700
                  : FontWeight.w500,
              decoration: isLink
                  ? TextDecoration.underline
                  : TextDecoration.none,
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(String status, Color color, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: MouseRegion(
        cursor: onTap != null
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            status,
            style: GoogleFonts.outfit(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPagination(
    bool isMobile,
    int totalOrders,
    int startIndex,
    int endIndex,
    int totalPages,
  ) {
    final showStart = totalOrders == 0 ? 0 : startIndex + 1;
    final showEnd = endIndex > totalOrders ? totalOrders : endIndex;

    return isMobile
        ? Column(
            children: [
              Text(
                'Showing $showStart to $showEnd of $totalOrders entries',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: const Color(0xFF6B7280),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              _buildPaginationControls(totalPages),
            ],
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Showing $showStart to $showEnd of $totalOrders entries',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: const Color(0xFF6B7280),
                  fontWeight: FontWeight.w500,
                ),
              ),
              _buildPaginationControls(totalPages),
            ],
          );
  }

  Widget _buildPaginationControls(int totalPages) {
    final List<Widget> children = [];

    // Left arrow
    children.add(
      _pbtn(Icons.chevron_left, currentPage > 1, () {
        if (currentPage > 1) {
          setState(() => currentPage--);
        }
      }),
    );
    children.add(const SizedBox(width: 8));

    // Page numbers
    for (int i = 1; i <= totalPages; i++) {
      if (i == 1 ||
          i == totalPages ||
          (i >= currentPage - 1 && i <= currentPage + 1)) {
        children.add(
          _pnum(i, i == currentPage, () {
            setState(() => currentPage = i);
          }),
        );
      } else if (i == 2 && currentPage > 3) {
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '...',
              style: GoogleFonts.outfit(color: const Color(0xFF9CA3AF)),
            ),
          ),
        );
      } else if (i == totalPages - 1 && currentPage < totalPages - 2) {
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '...',
              style: GoogleFonts.outfit(color: const Color(0xFF9CA3AF)),
            ),
          ),
        );
      }
    }

    children.add(const SizedBox(width: 8));
    // Right arrow
    children.add(
      _pbtn(Icons.chevron_right, currentPage < totalPages, () {
        if (currentPage < totalPages) {
          setState(() => currentPage++);
        }
      }),
    );

    return Row(mainAxisSize: MainAxisSize.min, children: children);
  }

  Widget _pbtn(IconData icon, bool enabled, VoidCallback onTap) =>
      GestureDetector(
        onTap: enabled ? onTap : null,
        child: MouseRegion(
          cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE5E7EB)),
              borderRadius: BorderRadius.circular(6),
              color: enabled ? Colors.white : const Color(0xFFF3F4F6),
            ),
            child: Icon(
              icon,
              size: 18,
              color: enabled
                  ? const Color(0xFF6B7280)
                  : const Color(0xFFD1D5DB),
            ),
          ),
        ),
      );

  Widget _pnum(int n, bool active, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Container(
        width: 32,
        height: 32,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? AppTheme.primaryColor : Colors.white,
          border: Border.all(
            color: active ? AppTheme.primaryColor : const Color(0xFFE5E7EB),
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          '$n',
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : const Color(0xFF4B5563),
          ),
        ),
      ),
    ),
  );
}

class _DealerKycDocumentsCard extends StatelessWidget {
  final Dealer dealer;
  final Function(String url) onViewDocument;

  const _DealerKycDocumentsCard({
    required this.dealer,
    required this.onViewDocument,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final hasLicence =
        dealer.licenceImage != null && dealer.licenceImage!.isNotEmpty;
    final hasShopImage =
        dealer.shopImage != null && dealer.shopImage!.isNotEmpty;

    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dealer KYC Documents',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 12),
          Column(
            children: [
              _KycDocumentCard(
                title: 'GST Certificate / Licence',
                status: dealer.kycStatus ?? 'Verified',
                subtext:
                    dealer.gstNumber != null && dealer.gstNumber!.isNotEmpty
                    ? dealer.gstNumber
                    : 'No GST Number',
                icon: Icons.description_outlined,
                onTap: hasLicence
                    ? () => onViewDocument(dealer.licenceImage!)
                    : null,
              ),
              const SizedBox(height: 12),
              _KycDocumentCard(
                title: 'Shop Image',
                status: dealer.kycStatus ?? 'Verified',
                subtext: 'Exterior photo of dealer shop',
                icon: Icons.storefront_outlined,
                onTap: hasShopImage
                    ? () => onViewDocument(dealer.shopImage!)
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
    final String displayStatus = widget.status.toUpperCase();
    const Color badgeColor = Color(0xFF10B981);

    return MouseRegion(
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isHovered && widget.onTap != null
                ? const Color(0xFFF3F4F6)
                : const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFE8F5E9),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.icon,
                  size: 16,
                  color: const Color(0xFF2E7D32),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1F2937),
                      ),
                    ),
                    if (widget.subtext != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.subtext!,
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          color: const Color(0xFF6B7280),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _buildStatusBadge(displayStatus, badgeColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: GoogleFonts.outfit(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
