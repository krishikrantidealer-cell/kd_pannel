import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:kd_pannel/app_theme.dart';
import 'package:kd_pannel/core/auth/auth_service.dart';
import 'package:kd_pannel/core/repositories/user_repository.dart';

class LeadsInspectorDrawer extends StatefulWidget {
  final Map<String, dynamic>? lead;
  final List<Map<String, dynamic>> salesAgents;
  final Function(String userId, String? agentId) onAssignAgent;
  final VoidCallback onClose;
  final VoidCallback? onLeadUpdated;

  const LeadsInspectorDrawer({
    super.key,
    required this.lead,
    required this.salesAgents,
    required this.onAssignAgent,
    required this.onClose,
    this.onLeadUpdated,
  });

  @override
  State<LeadsInspectorDrawer> createState() => _LeadsInspectorDrawerState();
}

class _LeadsInspectorDrawerState extends State<LeadsInspectorDrawer> {
  final TextEditingController _noteController = TextEditingController();
  bool _isSavingNote = false;
  bool _isUpdatingKyc = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  String _cleanUrl(String? url) {
    if (url == null || url.trim().isEmpty) return '';
    final trimmed = url.trim();
    if (trimmed.startsWith('http://') ||
        trimmed.startsWith('https://') ||
        trimmed.startsWith('data:image/')) {
      return trimmed;
    }
    // GCS or cloud bucket path
    if (trimmed.startsWith('gs://')) {
      return trimmed.replaceFirst('gs://', 'https://storage.googleapis.com/');
    }
    return '';
  }

  void _launchWhatsApp(String phone) async {
    final cleaned = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.parse('https://wa.me/$cleaned');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _launchCall(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _openDocumentUrl(String url) async {
    final clean = _cleanUrl(url);
    if (clean.isEmpty) return;
    final uri = Uri.parse(clean);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showDocumentZoomModal(String title, String imageUrl) {
    final clean = _cleanUrl(imageUrl);
    if (clean.isEmpty) return;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800, maxHeight: 800),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Modal Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: AppTheme.borderColor),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.description_outlined,
                        size: 20, color: AppTheme.primaryColor),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      onPressed: () => _openDocumentUrl(clean),
                      icon: const Icon(Icons.open_in_new_rounded, size: 20),
                      tooltip: 'Open in new tab',
                      color: AppTheme.primaryColor,
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(Icons.close_rounded, size: 22),
                      tooltip: 'Close',
                      color: AppTheme.textSecondary,
                    ),
                  ],
                ),
              ),
              // Modal Image Body
              Flexible(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  color: const Color(0xFFF9FAFB),
                  child: InteractiveViewer(
                    panEnabled: true,
                    minScale: 0.8,
                    maxScale: 4.0,
                    child: Center(
                      child: Image.network(
                        clean,
                        cacheWidth: 1200,
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return const Center(
                            child: SizedBox(
                              width: 40,
                              height: 40,
                              child: CircularProgressIndicator(),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.broken_image_rounded,
                                    size: 48, color: Colors.grey),
                                const SizedBox(height: 12),
                                Text(
                                  'Unable to render image preview',
                                  style: GoogleFonts.outfit(
                                    color: AppTheme.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextButton.icon(
                                  onPressed: () => _openDocumentUrl(clean),
                                  icon: const Icon(Icons.open_in_new_rounded,
                                      size: 16),
                                  label: const Text('Open Direct Link'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _saveNote() async {
    final text = _noteController.text.trim();
    if (text.isEmpty || widget.lead == null) return;

    setState(() => _isSavingNote = true);
    final userId = (widget.lead!['id'] ?? widget.lead!['_id'] ?? '').toString();

    try {
      final existingNotes = (widget.lead!['notes'] ?? '').toString();
      final updatedNotes = existingNotes.isEmpty
          ? text
          : '$existingNotes\n[${DateTime.now().toString().split('.').first}] $text';

      await UserRepository().updateNotes(userId, updatedNotes);
      widget.lead!['notes'] = updatedNotes;
      _noteController.clear();
      widget.onLeadUpdated?.call();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Note added successfully'),
            backgroundColor: AppTheme.success,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save note: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingNote = false);
    }
  }

  void _updateKycStatus(String status) async {
    if (widget.lead == null) return;
    setState(() => _isUpdatingKyc = true);
    final userId = (widget.lead!['id'] ?? widget.lead!['_id'] ?? '').toString();

    try {
      await UserRepository().updateKycStatus(userId, status);
      widget.lead!['kycStatus'] = status;
      widget.onLeadUpdated?.call();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('KYC status updated to ${status.toUpperCase()}'),
            backgroundColor: AppTheme.success,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update KYC: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdatingKyc = false);
    }
  }

  void _openFullProfile() {
    if (widget.lead == null) return;
    final userId = (widget.lead!['id'] ?? widget.lead!['_id'] ?? '').toString();
    final isVerified = widget.lead!['kycStatus'] == 'verified';

    final route = isVerified ? '/dealers/profile' : '/leads/profile';
    Navigator.pushNamed(context, route,
        arguments: {'id': userId, 'lead': widget.lead});
  }

  @override
  Widget build(BuildContext context) {
    final lead = widget.lead;
    final isVisible = lead != null;

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;
    final drawerWidth = isMobile ? screenWidth : 480.0;

    return Stack(
      children: [
        // Backdrop overlay
        if (isVisible)
          Positioned.fill(
            child: GestureDetector(
              onTap: widget.onClose,
              child: Container(
                color: Colors.black.withValues(alpha: 0.35),
              ),
            ),
          ),

        // Slide-over drawer container
        AnimatedPositioned(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          top: 0,
          bottom: 0,
          right: isVisible ? 0 : -drawerWidth,
          width: drawerWidth,
          child: IgnorePointer(
            ignoring: !isVisible,
            child: Material(
              elevation: isVisible ? 16 : 0,
              color: Colors.white,
              child: isVisible
                  ? _buildDrawerContent(lead, isMobile)
                  : const SizedBox.shrink(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDrawerContent(Map<String, dynamic> lead, bool isMobile) {
    final name = (lead['name'] ?? 'Unnamed Lead').toString();
    final shopName = (lead['shopName'] ?? '-').toString();
    final phone = (lead['phone'] ?? '').toString();
    final city = (lead['city'] ?? '-').toString();
    final state = (lead['state'] ?? '-').toString();
    final source = (lead['source'] ?? 'Direct').toString();
    final kycStatus = (lead['kycStatus'] ?? 'pending').toString().toLowerCase();
    final currentAgentId = lead['agentId']?.toString();
    final notes = (lead['notes'] ?? '').toString();
    final gstNumber = (lead['gstNumber'] ?? '').toString();

    final userId = (lead['id'] ?? lead['_id'] ?? '').toString();

    // Extract all uploaded document sources
    final licenceUrl = _cleanUrl(lead['licenceImage']?.toString() ??
        lead['gstCertificate']?.toString());
    final shopUrl = _cleanUrl(lead['shopImage']?.toString());
    final aadharFrontUrl = _cleanUrl(lead['aadharFront']?.toString());
    final aadharBackUrl = _cleanUrl(lead['aadharBack']?.toString());
    final panUrl = _cleanUrl(lead['panCard']?.toString());

    final List<Map<String, String>> documents = [];
    if (licenceUrl.isNotEmpty) {
      documents.add({
        'title': 'GST / Trade Licence',
        'url': licenceUrl,
        'subtitle': gstNumber.isNotEmpty ? 'GST: $gstNumber' : 'Licence Document',
        'icon': 'doc',
      });
    }
    if (shopUrl.isNotEmpty) {
      documents.add({
        'title': 'Store Front Image',
        'url': shopUrl,
        'subtitle': 'Physical Shop Photo',
        'icon': 'store',
      });
    }
    if (aadharFrontUrl.isNotEmpty) {
      documents.add({
        'title': 'Aadhar Card (Front)',
        'url': aadharFrontUrl,
        'subtitle': 'Identity Proof',
        'icon': 'id',
      });
    }
    if (aadharBackUrl.isNotEmpty) {
      documents.add({
        'title': 'Aadhar Card (Back)',
        'url': aadharBackUrl,
        'subtitle': 'Address Proof',
        'icon': 'id',
      });
    }
    if (panUrl.isNotEmpty) {
      documents.add({
        'title': 'PAN Card',
        'url': panUrl,
        'subtitle': 'Tax Identifier',
        'icon': 'id',
      });
    }

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: AppTheme.borderColor),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'L',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.outfit(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        shopName != '-' ? shopName : phone,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close_rounded, size: 22),
                  color: AppTheme.textSecondary,
                  tooltip: 'Close Inspector',
                ),
              ],
            ),
          ),

          // Scrollable Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Quick Actions (WhatsApp & Call)
                  Row(
                    children: [
                      if (phone.isNotEmpty) ...[
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _launchWhatsApp(phone),
                            icon: const Icon(Icons.chat_bubble_rounded, size: 16),
                            label: Text(
                              'WhatsApp',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF107C41),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _launchCall(phone),
                            icon: const Icon(Icons.call_rounded, size: 16),
                            label: Text(
                              'Call Phone',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.primaryColor,
                              side: const BorderSide(color: AppTheme.primaryColor),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Sales Agent Assignment Card
                  if (AuthService().isAdmin) ...[
                    _buildSectionHeader(
                        'ASSIGNED SALES AGENT', Icons.person_pin_rounded),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          value: widget.salesAgents.any(
                                  (a) => a['_id']?.toString() == currentAgentId)
                              ? currentAgentId
                              : null,
                          isExpanded: true,
                          hint: Text(
                            'Unassigned (Click to Assign)',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF8B5CF6),
                            ),
                          ),
                          icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                          items: [
                            DropdownMenuItem<String?>(
                              value: null,
                              child: Text(
                                '👤 Unassigned',
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ),
                            ...widget.salesAgents.map((agent) {
                              final id = agent['_id']?.toString();
                              final agentName =
                                  '${agent['firstName'] ?? ''} ${agent['lastName'] ?? ''}'
                                      .trim();
                              return DropdownMenuItem<String?>(
                                value: id,
                                child: Text(
                                  agentName.isNotEmpty
                                      ? agentName
                                      : (agent['phoneNumber'] ?? 'Agent'),
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                              );
                            }),
                          ],
                          onChanged: (newAgentId) {
                            widget.onAssignAgent(userId, newAgentId);
                            setState(() {
                              lead['agentId'] = newAgentId;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // KYC Documents Section
                  _buildSectionHeader('KYC DOCUMENTS & VERIFICATION',
                      Icons.verified_user_rounded),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Verification Status:',
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                color: AppTheme.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            _buildKycBadge(kycStatus),
                          ],
                        ),

                        // Document Thumbnails List
                        const SizedBox(height: 12),
                        const Divider(height: 1, color: AppTheme.borderColor),
                        const SizedBox(height: 12),

                        if (documents.isNotEmpty) ...[
                          Text(
                            'Uploaded Documents (${documents.length}):',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ...documents.map(
                            (doc) => _buildDocumentItem(
                              title: doc['title']!,
                              subtitle: doc['subtitle']!,
                              url: doc['url']!,
                            ),
                          ),
                        ] else ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                vertical: 16, horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: const Color(0xFFE5E7EB),
                                  style: BorderStyle.solid),
                            ),
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.folder_open_rounded,
                                  size: 28,
                                  color: AppTheme.textSecondary,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'No KYC documents uploaded yet',
                                  style: GoogleFonts.outfit(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Quick KYC Actions
                        if (AuthService().isAdmin &&
                            kycStatus != 'verified') ...[
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _isUpdatingKyc
                                      ? null
                                      : () => _updateKycStatus('verified'),
                                  icon: const Icon(Icons.check_circle_rounded,
                                      size: 16),
                                  label: Text(
                                    'Approve KYC',
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.success,
                                    foregroundColor: Colors.white,
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 8),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _isUpdatingKyc
                                      ? null
                                      : () => _updateKycStatus('rejected'),
                                  icon: const Icon(Icons.cancel_rounded,
                                      size: 16),
                                  label: Text(
                                    'Reject',
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppTheme.error,
                                    side:
                                        const BorderSide(color: AppTheme.error),
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 8),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Location & Contact Info
                  _buildSectionHeader(
                      'LOCATION & DETAILS', Icons.info_outline_rounded),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: Column(
                      children: [
                        _buildInfoRow('Phone', phone),
                        const Divider(height: 16, color: AppTheme.borderColor),
                        _buildInfoRow('City / Tehsil', city),
                        const Divider(height: 16, color: AppTheme.borderColor),
                        _buildInfoRow('State', state),
                        const Divider(height: 16, color: AppTheme.borderColor),
                        _buildInfoRow('Lead Source', source),
                        if (gstNumber.isNotEmpty) ...[
                          const Divider(
                              height: 16, color: AppTheme.borderColor),
                          _buildInfoRow('GST Number', gstNumber),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Notes & Activity Section
                  _buildSectionHeader(
                      'NOTES & ACTIVITY', Icons.edit_note_rounded),
                  const SizedBox(height: 8),
                  if (notes.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: Text(
                        notes,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: AppTheme.textPrimary,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _noteController,
                          maxLines: 2,
                          style: GoogleFonts.outfit(fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Add a new note...',
                            hintStyle: GoogleFonts.outfit(
                                fontSize: 13, color: AppTheme.textSecondary),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.all(12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  const BorderSide(color: AppTheme.borderColor),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  const BorderSide(color: AppTheme.borderColor),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _isSavingNote ? null : _saveNote,
                        icon: _isSavingNote
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.send_rounded,
                                color: AppTheme.primaryColor),
                        tooltip: 'Save Note',
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),

                  // Full Profile Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _openFullProfile,
                      icon: const Icon(Icons.open_in_new_rounded, size: 16),
                      label: Text(
                        'Open Full Profile & History →',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentItem({
    required String title,
    required String subtitle,
    required String url,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          // Thumbnail Preview
          GestureDetector(
            onTap: () => _showDocumentZoomModal(title, url),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Container(
                width: 46,
                height: 46,
                color: const Color(0xFFF3F4F6),
                child: Image.network(
                  url,
                  cacheWidth: 200,
                  cacheHeight: 200,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(
                      child: Icon(
                        Icons.description_rounded,
                        color: AppTheme.primaryColor,
                        size: 22,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: () => _showDocumentZoomModal(title, url),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: () => _showDocumentZoomModal(title, url),
            icon: const Icon(Icons.zoom_in_rounded, size: 20),
            color: AppTheme.primaryColor,
            tooltip: 'Zoom & Inspect',
          ),
          IconButton(
            onPressed: () => _openDocumentUrl(url),
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            color: AppTheme.textSecondary,
            tooltip: 'Open in new tab',
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppTheme.textSecondary),
        const SizedBox(width: 6),
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 13,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 13,
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildKycBadge(String status) {
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case 'verified':
        bg = const Color(0xFFE8F8EF);
        fg = const Color(0xFF107C41);
        label = 'VERIFIED';
        break;
      case 'submitted':
        bg = const Color(0xFFFEF3F2);
        fg = const Color(0xFFD92D20);
        label = 'UNDER REVIEW';
        break;
      case 'rejected':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFDC2626);
        label = 'REJECTED';
        break;
      default:
        bg = const Color(0xFFFFF7ED);
        fg = const Color(0xFFEA580C);
        label = 'PENDING';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.outfit(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: fg,
        ),
      ),
    );
  }
}
