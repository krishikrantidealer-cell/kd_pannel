import 'package:flutter/material.dart';
import 'package:kd_pannel/core/responsive/responsive.dart';

class LeadProfilePage extends StatelessWidget {
  const LeadProfilePage({super.key});

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

            // 2. HERO PROFILE SECTION
            const _HeroProfileSection(),
            SizedBox(height: isMobile ? 24 : 32),

            // 3. INFORMATION & TIMELINE ROW
            if (!isMobile)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(flex: 1, child: _LeadInformationCard()),
                  const SizedBox(width: 32),
                  const Expanded(flex: 1, child: _ActivityTimelineCard()),
                ],
              )
            else ...[
              const _LeadInformationCard(),
              const SizedBox(height: 24),
              const _ActivityTimelineCard(),
            ],
            SizedBox(height: isMobile ? 24 : 32),

            // 4. KYC DOCUMENTS (Full Width)
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
  const _HeroProfileSection();

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
            child: isMobile
                ? Column(
                    children: [
                      _buildProfileImage(isMobile, isTablet),
                      const SizedBox(height: 24),
                      _buildProfileInfo(context, isMobile, isTablet),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: _buildProfileInfo(context, isMobile, isTablet),
                      ),
                      _buildProfileImage(isMobile, isTablet),
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
        Text(
          'Kumar Agro Mart',
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
              _buildHeroContactItem(Icons.phone_outlined, '99765 43210'),
              const SizedBox(height: 8),
              _buildHeroContactItem(
                Icons.location_on_outlined,
                'Nagpur, Maharashtra',
              ),
              const SizedBox(height: 8),
              _buildHeroContactItem(Icons.hub_outlined, 'Source: CTWA'),
            ],
          )
        else
          Wrap(
            alignment: WrapAlignment.start,
            spacing: 12,
            runSpacing: 8,
            children: [
              _buildHeroContactItem(Icons.phone_outlined, '99765 43210'),
              _buildDivider(),
              _buildHeroContactItem(
                Icons.location_on_outlined,
                'Nagpur, Maharashtra',
              ),
              _buildDivider(),
              _buildHeroContactItem(Icons.hub_outlined, 'Source: CTWA'),
            ],
          ),
        SizedBox(height: isMobile ? 32 : 36),
        Wrap(
          alignment: isMobile ? WrapAlignment.center : WrapAlignment.start,
          spacing: isMobile ? 12 : 16,
          runSpacing: isMobile ? 12 : 16,
          children: [
            _ActionButton(
              icon: Icons.call,
              label: 'Call',
              color: const Color(0xFF2E7D32),
              isSolid: true,
              width: isMobile
                  ? (MediaQuery.of(context).size.width - 84) / 2
                  : null,
            ),
            _ActionButton(
              icon: Icons.chat_bubble_outline,
              label: 'WhatsApp',
              color: const Color(0xFF128C7E),
              width: isMobile
                  ? (MediaQuery.of(context).size.width - 84) / 2
                  : null,
            ),
            _ActionButton(
              icon: Icons.person_add_outlined,
              label: 'Convert Dealer',
              color: const Color(0xFF1976D2),
              width: isMobile
                  ? (MediaQuery.of(context).size.width - 84) / 2
                  : null,
            ),
            _ActionButton(
              icon: Icons.add_shopping_cart,
              label: 'Create Order',
              color: const Color(0xFFF57C00),
              width: isMobile
                  ? (MediaQuery.of(context).size.width - 84) / 2
                  : null,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProfileImage(bool isMobile, bool isTablet) {
    final size = isMobile ? 110.0 : (isTablet ? 140.0 : 160.0);
    final innerSize = isMobile ? 94.0 : (isTablet ? 120.0 : 140.0);

    return Stack(
      alignment: Alignment.center,
      children: [
        if (!isMobile) ...[
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF2E7D32).withOpacity(0.05),
                width: 1,
              ),
            ),
          ),
          Container(
            width: size - 8,
            height: size - 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF2E7D32).withOpacity(0.1),
                width: 1,
              ),
            ),
          ),
        ],
        Container(
          width: innerSize,
          height: innerSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(color: Colors.white, width: isMobile ? 4 : 6),
            boxShadow: [
              BoxShadow(
                color: const Color(
                  0xFF1B5E20,
                ).withOpacity(isMobile ? 0.15 : 0.12),
                blurRadius: isMobile ? 20 : 24,
                offset: Offset(0, isMobile ? 8 : 12),
              ),
              if (isMobile)
                BoxShadow(
                  color: Colors.white.withOpacity(0.8),
                  blurRadius: 0,
                  spreadRadius: 2,
                ),
            ],
          ),
          child: const CircleAvatar(
            backgroundImage: AssetImage('assets/images/admin.png'),
          ),
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

class _LeadInformationCard extends StatelessWidget {
  const _LeadInformationCard();

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
            'Kumar Agro Mart',
            Colors.green,
          ),
          _buildDividerRow(),
          _buildInfoRow(
            Icons.phone_android_outlined,
            'Phone Number',
            '+91 99765 43210',
            Colors.blue,
          ),
          _buildDividerRow(),
          _buildInfoRow(
            Icons.location_city_outlined,
            'City',
            'Nagpur',
            Colors.orange,
          ),
          _buildDividerRow(),
          _buildInfoRow(
            Icons.map_outlined,
            'State',
            'Maharashtra',
            Colors.purple,
          ),
          _buildDividerRow(),
          _buildInfoRow(
            Icons.campaign_outlined,
            'Lead Source',
            'CTWA (WhatsApp)',
            Colors.teal,
          ),
          _buildDividerRow(),
          _buildInfoRow(
            Icons.badge_outlined,
            'Assigned Sales',
            'Rajesh Sharma',
            Colors.indigo,
          ),
          _buildDividerRow(),
          _buildInfoRow(
            Icons.calendar_today_outlined,
            'Created Date',
            '24 Oct 2023',
            Colors.amber,
          ),
          _buildDividerRow(),
          _buildInfoRow(
            Icons.history_outlined,
            'Last Activity',
            '2 minute ago',
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
                  title: 'GST Certificate',
                  status: 'Verified',
                  subtext: '27ABCDE1234F1Z5',
                  icon: Icons.description_outlined,
                ),
                const SizedBox(height: 16),
                _KycDocumentCard(
                  title: 'PAN Card',
                  status: 'Verified',
                  icon: Icons.badge_outlined,
                ),
                const SizedBox(height: 16),
                _KycDocumentCard(
                  title: 'Dealer Photo',
                  status: 'Verified',
                  icon: Icons.person_outline,
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
                const SizedBox(width: 24),
                _KycDocumentCard(
                  title: 'PAN Card',
                  status: 'Verified',
                  icon: Icons.badge_outlined,
                ),
                const SizedBox(width: 24),
                _KycDocumentCard(
                  title: 'Dealer Photo',
                  status: 'Verified',
                  icon: Icons.person_outline,
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

    final card = MouseRegion(
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
    );

    return isMobile ? card : Expanded(child: card);
  }
}
