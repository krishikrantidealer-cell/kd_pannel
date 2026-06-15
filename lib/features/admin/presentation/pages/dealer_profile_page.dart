import 'package:flutter/material.dart';
import 'package:kd_pannel/app_theme.dart';
import 'package:kd_pannel/core/responsive/responsive.dart';

class DealerProfilePage extends StatelessWidget {
  const DealerProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final isTablet = Responsive.isTablet(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16 : (isTablet ? 24 : 40),
          vertical: isMobile ? 20 : 32,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. BREADCRUMB HEADER
            _buildBreadcrumbs(context, isMobile),
            SizedBox(height: isMobile ? 20 : 28),

            // 2. PREMIUM HERO SECTION
            const _DealerHeroCard(),
            SizedBox(height: isMobile ? 24 : 32),

            // 3. STATS CARDS ROW
            const _StatsCardsSection(),
            SizedBox(height: isMobile ? 24 : 32),

            // 4. INFORMATION & TIMELINE ROW
            if (!isMobile)
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Expanded(flex: 1, child: _DealerInformationCard()),
                    const SizedBox(width: 32),
                    const Expanded(flex: 1, child: _ActivityTimelineCard()),
                  ],
                ),
              )
            else ...[
              const _DealerInformationCard(),
              const SizedBox(height: 24),
              const _ActivityTimelineCard(),
            ],
            SizedBox(height: isMobile ? 24 : 32),

            // 5. ORDER HISTORY SECTION
            const _OrderHistoryCard(),
            SizedBox(height: isMobile ? 24 : 32),

            // 6. DOCUMENTS / KYC SECTION
            const _DealerKycDocumentsCard(),
            SizedBox(height: isMobile ? 24 : 40),
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
        _BreadcrumbItem(label: 'Dealers', onTap: () => Navigator.pop(context)),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            '/',
            style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 15),
          ),
        ),
        const Text(
          'Dealer Profile',
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
            decoration: isHovered
                ? TextDecoration.underline
                : TextDecoration.none,
          ),
        ),
      ),
    );
  }
}

class _DealerHeroCard extends StatelessWidget {
  const _DealerHeroCard();

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
              left: 48,
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
              vertical: isMobile ? 32 : 48,
            ),
            child: isMobile
                ? _buildProfileInfo(context, isMobile, isTablet)
                : Row(
                    children: [
                      Expanded(
                        child: _buildProfileInfo(context, isMobile, isTablet),
                      ),
                      const SizedBox(width: 48),
                      _buildActionButtons(context, isMobile, isTablet),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileInfo(BuildContext context, bool isMobile, bool isTablet) {
    return Column(
      crossAxisAlignment: isMobile
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: isMobile
              ? MainAxisAlignment.center
              : MainAxisAlignment.start,
          children: [
            Flexible(
              child: Text(
                'Jai Kisan Fertilizers',
                textAlign: isMobile ? TextAlign.center : TextAlign.start,
                style: TextStyle(
                  fontSize: isMobile ? 26 : (isTablet ? 32 : 36),
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1B5E20),
                  letterSpacing: isMobile ? -0.5 : -1.0,
                ),
              ),
            ),
            if (!isMobile) const SizedBox(width: 16),
            if (!isMobile)
              _buildStatusBadge('Verified', const Color(0xFF10B981)),
          ],
        ),
        if (isMobile) const SizedBox(height: 8),
        if (isMobile) _buildStatusBadge('Verified', const Color(0xFF10B981)),
        const SizedBox(height: 20),
        if (isMobile)
          Column(
            children: [
              _buildHeroContactItem(Icons.phone_outlined, '98765 43210'),
              const SizedBox(height: 8),
              _buildHeroContactItem(
                Icons.location_on_outlined,
                'Pune, Maharashtra',
              ),
              const SizedBox(height: 8),
              _buildHeroContactItem(
                Icons.person_outline,
                'Agent: Rajesh Kumar',
              ),
            ],
          )
        else
          Wrap(
            spacing: 28,
            runSpacing: 12,
            children: [
              _buildHeroContactItem(Icons.phone_outlined, '98765 43210'),
              _buildHeroContactItem(
                Icons.location_on_outlined,
                'Pune, Maharashtra',
              ),
              _buildHeroContactItem(
                Icons.person_outline,
                'Agent: Rajesh Kumar',
              ),
            ],
          ),
        if (isMobile) const SizedBox(height: 32),
        if (isMobile) _buildActionButtons(context, isMobile, isTablet),
      ],
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    bool isMobile,
    bool isTablet,
  ) {
    final wrapAlignment = isMobile ? WrapAlignment.center : WrapAlignment.start;

    return Wrap(
      alignment: wrapAlignment,
      spacing: 12,
      runSpacing: 12,
      children: [
        _ActionButton(
          icon: Icons.call,
          label: 'Call',
          color: const Color(0xFF2E7D32),
          isSolid: true,
          width: isMobile ? (MediaQuery.of(context).size.width - 84) / 2 : null,
        ),
        _ActionButton(
          icon: Icons.chat_bubble_outline,
          label: 'WhatsApp',
          color: const Color(0xFF128C7E),
          width: isMobile ? (MediaQuery.of(context).size.width - 84) / 2 : null,
        ),
        _ActionButton(
          icon: Icons.add_shopping_cart,
          label: 'Create Order',
          color: const Color(0xFFF57C00),
          width: isMobile ? (MediaQuery.of(context).size.width - 44) : null,
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _buildHeroContactItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF2E7D32)),
        const SizedBox(width: 10),
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
}

class _ActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isSolid;
  final double? width;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    this.isSolid = false,
    this.width,
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
    );
  }
}

class _StatsCardsSection extends StatelessWidget {
  const _StatsCardsSection();

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);
    final isMobile = Responsive.isMobile(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = isDesktop ? 24.0 : 16.0;
        final items = [
          {
            'title': 'Total Orders',
            'value': '156',
            'image': 'assets/images/order today.png',
            'color': Colors.blue,
          },
          {
            'title': 'Total Purchase Value',
            'value': '₹ 12.5L',
            'image': 'assets/images/Revenue.png',
            'color': Colors.green,
          },
          {
            'title': 'Last Order Date',
            'value': '24 Oct 2023',
            'image': 'assets/images/Total dealer.png',
            'color': Colors.purple,
          },
          {
            'title': 'Dealer Active Since',
            'value': '2 Years',
            'image': 'assets/images/New leads.png',
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
                        image: item['image'] as String,
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
                  image: item['image'] as String,
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
  final String image;
  final Color color;

  const _StatCard({
    this.width,
    required this.title,
    required this.value,
    required this.image,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return Container(
      width: width,
      height: isMobile ? 140 : 170,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: Container(
              height: isMobile ? 65 : 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [color.withOpacity(0.15), color.withOpacity(0.01)],
                ),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.elliptical(
                    isMobile ? 100 : 120,
                    isMobile ? 25 : 35,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: isMobile ? 16 : 20,
            child: SizedBox(
              width: isMobile ? 36 : 42,
              height: isMobile ? 36 : 42,
              child: Image.asset(image, color: color, fit: BoxFit.contain),
            ),
          ),
          Positioned(
            bottom: isMobile ? 12 : 16,
            child: Column(
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: isMobile ? 10 : 12,
                    color: const Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: isMobile ? 18 : 22,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1F2937),
                  ),
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
  const _DealerInformationCard();

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return Container(
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Dealer Information',
                style: TextStyle(
                  fontSize: isMobile ? 18 : 20,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF111827),
                ),
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(
                  Icons.edit_outlined,
                  size: 20,
                  color: Color(0xFF6B7280),
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildInfoRow(
            Icons.business_outlined,
            'Dealer Name',
            'Jai Kisan Fertilizers',
            Colors.green,
            isMobile,
          ),
          _buildDivider(),
          _buildInfoRow(
            Icons.phone_android_outlined,
            'Phone Number',
            '+91 98765 43210',
            Colors.blue,
            isMobile,
          ),
          _buildDivider(),
          _buildInfoRow(
            Icons.map_outlined,
            'State',
            'Maharashtra',
            Colors.purple,
            isMobile,
          ),
          _buildDivider(),
          _buildInfoRow(
            Icons.location_city_outlined,
            'City',
            'Pune',
            Colors.orange,
            isMobile,
          ),
          _buildDivider(),
          _buildInfoRow(
            Icons.receipt_outlined,
            'GST Number',
            '27ABCDE1234F1Z5',
            Colors.red,
            isMobile,
          ),
          _buildDivider(),
          _buildInfoRow(
            Icons.category_outlined,
            'Dealer Type',
            'Platinum Retailer',
            Colors.teal,
            isMobile,
          ),
          _buildDivider(),
          _buildInfoRow(
            Icons.badge_outlined,
            'Assigned Agent',
            'Rajesh Kumar',
            Colors.indigo,
            isMobile,
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
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
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
                fontSize: 13,
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

  Widget _buildDivider() => const Divider(height: 1, color: Color(0xFFF3F4F6));
}

class _ActivityTimelineCard extends StatelessWidget {
  const _ActivityTimelineCard();

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return Container(
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
          const SizedBox(height: 32),
          Column(
            children: [
              _buildTimelineItem(
                icon: Icons.person_add_alt_1_outlined,
                iconColor: Colors.blue,
                title: 'Dealer Registered',
                time: '12 Jan 2022, 10:30 AM',
                isMobile: isMobile,
              ),
              _buildTimelineItem(
                icon: Icons.verified_outlined,
                iconColor: Colors.teal,
                title: 'GST Verified',
                time: '14 Jan 2022, 02:15 PM',
                isMobile: isMobile,
              ),
              _buildTimelineItem(
                icon: Icons.support_agent_outlined,
                iconColor: Colors.purple,
                title: 'Sales Agent Assigned',
                time: '15 Jan 2022, 11:00 AM',
                isMobile: isMobile,
              ),
              _buildTimelineItem(
                icon: Icons.shopping_bag_outlined,
                iconColor: const Color(0xFFF57C00),
                title: 'First Order Created',
                time: '20 Jan 2022, 04:30 PM',
                isMobile: isMobile,
              ),
              _buildTimelineItem(
                icon: Icons.check_circle_outline,
                iconColor: const Color(0xFF2E7D32),
                title: 'Purchase Completed',
                time: '24 Oct 2023, 05:20 PM',
                isLast: true,
                isMobile: isMobile,
              ),
            ],
          ),
          const SizedBox(height: 24),
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

    if (isMobile) {
      return Padding(padding: const EdgeInsets.only(bottom: 24), child: item);
    }

    return Expanded(child: item);
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
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                shape: BoxShape.circle,
                border: Border.all(color: iconColor.withOpacity(0.2), width: 1),
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            if (!isLast)
              Expanded(
                child: Container(
                  width: 2.5,
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
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
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
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
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

class _OrderHistoryCard extends StatelessWidget {
  const _OrderHistoryCard();

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return Container(
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
            'Order History',
            style: TextStyle(
              fontSize: isMobile ? 18 : 20,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 24),
          _buildOrderTable(context, isMobile),
          const SizedBox(height: 24),
          _buildPagination(isMobile),
        ],
      ),
    );
  }

  Widget _buildOrderTable(BuildContext context, bool isMobile) {
    final table = Table(
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
            border: Border(
              bottom: BorderSide(color: Color(0xFFF3F4F6), width: 1.5),
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
        _orderRow(
          '#ORD-1024',
          'NPK 19:19:19, Urea',
          '24 Oct 2023',
          '₹ 24,500',
          'Completed',
          const Color(0xFF10B981),
        ),
        _orderRow(
          '#ORD-1021',
          'Hybrid Seeds, Potash',
          '20 Oct 2023',
          '₹ 12,200',
          'Pending',
          const Color(0xFFF59E0B),
        ),
        _orderRow(
          '#ORD-1018',
          'Drip Pipes, Filters',
          '15 Oct 2023',
          '₹ 45,000',
          'Completed',
          const Color(0xFF10B981),
        ),
        _orderRow(
          '#ORD-1015',
          'Water Soluble Fert.',
          '10 Oct 2023',
          '₹ 8,400',
          'Cancelled',
          const Color(0xFFEF4444),
        ),
        _orderRow(
          '#ORD-1012',
          'Pesticides, Spray',
          '05 Oct 2023',
          '₹ 15,600',
          'Completed',
          const Color(0xFF10B981),
        ),
      ],
    );

    if (!isMobile) return table;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(width: 600, child: table),
    );
  }

  Widget _headerCell(String text, {bool isCenter = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 8, right: 8),
      child: isCenter
          ? Center(child: Text(text, style: _headerStyle))
          : Text(text, style: _headerStyle),
    );
  }

  static const _headerStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.bold,
    color: Color(0xFF9CA3AF),
  );

  TableRow _orderRow(
    String id,
    String prod,
    String date,
    String amt,
    String status,
    Color statusColor,
  ) {
    return TableRow(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF9FAFB))),
      ),
      children: [
        _cell(id, isBold: true),
        _cell(prod),
        _cell(date),
        _cell(amt, isBold: true),
        Center(child: _statusBadge(status, statusColor)),
      ],
    );
  }

  Widget _cell(String text, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          color: isBold ? const Color(0xFF111827) : const Color(0xFF4B5563),
          fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }

  Widget _statusBadge(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status,
        style: const TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: 0.1,
        ),
      ),
    );
  }

  Widget _buildPagination(bool isMobile) {
    return isMobile
        ? Column(
            children: [
              const Text(
                'Showing 1 to 5 of 156 entries',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              _buildPaginationControls(),
            ],
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Showing 1 to 5 of 156 entries',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w500,
                ),
              ),
              _buildPaginationControls(),
            ],
          );
  }

  Widget _buildPaginationControls() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _pbtn(Icons.chevron_left, false),
        const SizedBox(width: 8),
        _pnum(1, true),
        _pnum(2, false),
        _pnum(3, false),
        const SizedBox(width: 8),
        _pbtn(Icons.chevron_right, true),
      ],
    );
  }

  Widget _pbtn(IconData icon, bool enabled) => Container(
    width: 32,
    height: 32,
    decoration: BoxDecoration(
      border: Border.all(color: const Color(0xFFE5E7EB)),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Icon(
      icon,
      size: 18,
      color: enabled ? const Color(0xFF6B7280) : const Color(0xFFD1D5DB),
    ),
  );

  Widget _pnum(int n, bool active) => Container(
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
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: active ? Colors.white : const Color(0xFF4B5563),
      ),
    ),
  );
}

class _DealerKycDocumentsCard extends StatelessWidget {
  const _DealerKycDocumentsCard();

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

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
          Text(
            'Dealer KYC Documents',
            style: TextStyle(
              fontSize: isMobile ? 18 : 20,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 32),
          if (isMobile)
            Column(
              children: [
                _KycDocumentCard(
                  title: 'GST Certificate',
                  status: 'Verified',
                  subtext: '27ABCDE1234F1Z5',
                  icon: Icons.description_outlined,
                ),
              ],
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _KycDocumentCard(
                  title: 'GST Certificate',
                  status: 'Verified',
                  subtext: '27ABCDE1234F1Z5',
                  icon: Icons.description_outlined,
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

  const _KycDocumentCard({
    required this.title,
    required this.status,
    this.subtext,
    required this.icon,
  });

  @override
  State<_KycDocumentCard> createState() => _KycDocumentCardState();
}

class _KycDocumentCardState extends State<_KycDocumentCard> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    final bool isMobile = Responsive.isMobile(context);

    return Expanded(
      flex: isMobile ? 0 : 1,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => isHovered = true),
        onExit: (_) => setState(() => isHovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isHovered
                  ? const Color(0xFF2E7D32).withOpacity(0.5)
                  : const Color(0xFFE5E7EB),
            ),
            boxShadow: [
              BoxShadow(
                color: isHovered
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
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F8E9),
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
                      color: const Color(0xFF10B981).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle,
                          size: 12,
                          color: Color(0xFF10B981),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          widget.status,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF10B981),
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
  }
}
