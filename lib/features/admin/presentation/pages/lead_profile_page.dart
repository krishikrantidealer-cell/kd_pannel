import 'package:flutter/material.dart';
import 'package:kd_pannel/core/responsive/responsive.dart';
import 'package:kd_pannel/core/theme/app_colors.dart';
import 'package:kd_pannel/features/admin/presentation/widgets/shared_crm/identity_sidebar.dart';
import 'package:kd_pannel/features/admin/presentation/widgets/lead_profile/lead_information_tab.dart';
import 'package:kd_pannel/features/admin/presentation/widgets/lead_profile/kyc_documents_tab.dart';
import 'package:kd_pannel/features/admin/presentation/widgets/lead_profile/activity_timeline_tab.dart';
import 'package:kd_pannel/features/admin/presentation/widgets/lead_profile/edit_lead_panel.dart';
import 'package:kd_pannel/features/admin/presentation/widgets/shared_crm/page_breadcrumb.dart';

class LeadProfilePage extends StatefulWidget {
  const LeadProfilePage({super.key});

  @override
  State<LeadProfilePage> createState() => _LeadProfilePageState();
}

class _LeadProfilePageState extends State<LeadProfilePage> {
  int _activeTab = 0;

  // Lead Data State
  String _leadName = 'Kumar Agro Mart';
  String _phoneNumber = '+91 99765 43210';
  String _city = 'Nagpur';
  String _state = 'Maharashtra';
  String _source = 'CTWA (WhatsApp)';
  String _assignedSales = 'Rajesh Sharma';

  bool _isEditing = false;

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _cityController;
  late TextEditingController _stateController;
  late TextEditingController _sourceController;
  late TextEditingController _agentController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: _leadName);
    _phoneController = TextEditingController(text: _phoneNumber);
    _cityController = TextEditingController(text: _city);
    _stateController = TextEditingController(text: _state);
    _sourceController = TextEditingController(text: _source);
    _agentController = TextEditingController(text: _assignedSales);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _sourceController.dispose();
    _agentController.dispose();
    super.dispose();
  }

  void _toggleEditing(bool value) {
    setState(() => _isEditing = value);
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return Container(
      color: AppColors.background,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: isMobile ? _buildMobileBody() : _buildDesktopBody(),
          );
        },
      ),
    );
  }

  Widget _buildMobileBody() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _isEditing
          ? EditLeadPanel(
              key: const ValueKey('edit_panel'),
              nameController: _nameController,
              phoneController: _phoneController,
              cityController: _cityController,
              stateController: _stateController,
              sourceController: _sourceController,
              agentController: _agentController,
              onSave: _saveLeadData,
              onCancel: () => _toggleEditing(false),
            )
          : SingleChildScrollView(
              key: const ValueKey('profile_content'),
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const PageBreadcrumb(),
                  const SizedBox(height: 24),
                  IdentitySidebar(
                    name: _leadName,
                    phone: _phoneNumber,
                    city: _city,
                    stateName: _state,
                    source: _source,
                    agent: _assignedSales,
                  ),
                  const SizedBox(height: 24),
                  _buildWorkspace(true),
                ],
              ),
            ),
    );
  }

  Widget _buildDesktopBody() {
    return Row(
      children: [
        Flexible(
          flex: 3,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 280, maxWidth: 350),
            child: IdentitySidebar(
              isEmbedded: true,
              name: _leadName,
              phone: _phoneNumber,
              city: _city,
              stateName: _state,
              source: _source,
              agent: _assignedSales,
            ),
          ),
        ),
        Container(
          width: 1.5,
          color: AppColors.slate200,
        ),
        Expanded(
          flex: 7,
          child: _buildWorkspace(false, isEmbedded: true),
        ),
        if (_isEditing) ...[
          Container(
            width: 1.5,
            color: AppColors.slate200,
          ),
          SizedBox(
            width: 380,
            child: EditLeadPanel(
              nameController: _nameController,
              phoneController: _phoneController,
              cityController: _cityController,
              stateController: _stateController,
              sourceController: _sourceController,
              agentController: _agentController,
              onSave: _saveLeadData,
              onCancel: () => _toggleEditing(false),
            ),
          ),
        ],
      ],
    );
  }

  void _saveLeadData() {
    setState(() {
      _leadName = _nameController.text;
      _phoneNumber = _phoneController.text;
      _city = _cityController.text;
      _state = _stateController.text;
      _source = _sourceController.text;
      _assignedSales = _agentController.text;
      _isEditing = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.slate900,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: const [
            Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20),
            SizedBox(width: 12),
            Text(
              'Lead profile updated successfully',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkspace(bool isMobile, {bool isEmbedded = false}) {
    if (isMobile) {
      return Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.lightBorder, width: 1.0),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTabHeader(isEmbedded: isEmbedded),
            Padding(
              padding: const EdgeInsets.all(20),
              child: _getActiveTabContent(),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          color: AppColors.surface,
          height: constraints.maxHeight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTabHeader(isEmbedded: isEmbedded),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 60, // Tab header height
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: _getActiveTabContent(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTabHeader({bool isEmbedded = false}) {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        color: isEmbedded ? AppColors.slate50.withValues(alpha: 0.85) : AppColors.surface,
        border: const Border(
          bottom: BorderSide(color: AppColors.slate200, width: 1.0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.005),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _tabItem(0, 'Lead Information', Icons.info_outline_rounded),
            const SizedBox(width: 40),
            _tabItem(1, 'KYC Documents', Icons.verified_user_outlined),
            const SizedBox(width: 40),
            _tabItem(2, 'Activity Timeline', Icons.history_toggle_off_rounded),
          ],
        ),
      ),
    );
  }

  Widget _tabItem(int index, String label, IconData icon) {
    final isActive = _activeTab == index;
    return InkWell(
      onTap: () => setState(() => _activeTab = index),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        height: 60,
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary.withValues(alpha: 0.04) : Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: isActive ? AppColors.primary : Colors.transparent,
              width: 2.5,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isActive ? AppColors.primary : AppColors.slate400,
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isActive ? FontWeight.w900 : FontWeight.w600,
                color: isActive ? AppColors.slate900 : AppColors.slate500,
                letterSpacing: isActive ? -0.4 : -0.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _getActiveTabContent() {
    switch (_activeTab) {
      case 0:
        return LeadInformationTab(
          name: _leadName,
          phone: _phoneNumber,
          city: _city,
          stateName: _state,
          source: _source,
          agent: _assignedSales,
          onEdit: () => _toggleEditing(true),
        );
      case 1:
        return const KycDocumentsTab();
      case 2:
        return const ActivityTimelineTab();
      default:
        return LeadInformationTab(
          name: _leadName,
          phone: _phoneNumber,
          city: _city,
          stateName: _state,
          source: _source,
          agent: _assignedSales,
          onEdit: () => _toggleEditing(true),
        );
    }
  }
}
