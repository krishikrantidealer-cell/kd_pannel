import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kd_pannel/app_theme.dart';
import 'package:kd_pannel/core/responsive/responsive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/leads_bloc.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/leads_event.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/leads_state.dart';
import 'package:kd_pannel/core/auth/auth_service.dart';

class LeadProfilePage extends StatefulWidget {
  const LeadProfilePage({super.key});

  @override
  State<LeadProfilePage> createState() => _LeadProfilePageState();
}

class _LeadProfilePageState extends State<LeadProfilePage> {
  Map<String, dynamic>? _lead;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_lead == null) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, dynamic>) {
        _lead = Map<String, dynamic>.from(args);
        _saveLeadToCache(_lead!);
        _refreshLeadDetails();
      } else {
        _loadLeadFromCache();
      }
    }
  }

  Future<void> _saveLeadToCache(Map<String, dynamic> lead) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('kd_current_lead', jsonEncode(lead));
    } catch (e) {
      debugPrint('Error saving lead to cache: $e');
    }
  }

  Future<void> _loadLeadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final leadStr = prefs.getString('kd_current_lead');
      if (leadStr != null) {
        if (mounted) {
          setState(() {
            _lead = jsonDecode(leadStr);
          });
        }
        _refreshLeadDetails();
      }
    } catch (e) {
      debugPrint('Error loading lead from cache: $e');
    }
  }

  String _formatTimeAgo(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes} mins ago';
      if (diff.inHours < 24) return '${diff.inHours} hours ago';
      if (diff.inDays == 1) return 'Yesterday';
      return '${diff.inDays} days ago';
    } catch (e) {
      return '-';
    }
  }

  void _refreshLeadDetails() {
    context.read<LeadsBloc>().add(
      const FetchLeadsDataEvent(forceRefresh: true),
    );
  }

  void _toggleBlockLead() {
    if (_lead == null) return;
    final isBlocked = _lead!['isBlocked'] ?? false;
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                isBlocked ? Icons.lock_open : Icons.block,
                color: isBlocked ? Colors.blue : AppTheme.error,
              ),
              const SizedBox(width: 8),
              Text(
                isBlocked ? 'Unblock User' : 'Block User',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Text(
            isBlocked
                ? 'Are you sure you want to unblock this lead? They will regain full access to their account.'
                : 'Are you sure you want to block this lead? They will be instantly force logged out on their device and restricted from accessing the application.',
            style: GoogleFonts.outfit(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'Cancel',
                style: GoogleFonts.outfit(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                context.read<LeadsBloc>().add(
                  ToggleBlockLeadEvent(_lead!['id']),
                );
                setState(() {
                  _lead!['isBlocked'] = !isBlocked;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isBlocked ? Colors.blue : AppTheme.error,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                isBlocked ? 'Unblock' : 'Block',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Map<String, dynamic> _mapUserToLead(Map<String, dynamic> u) {
    return {
      'id': u['_id'],
      'name':
          (u['firstName'] != null &&
              u['firstName'].toString().trim().isNotEmpty)
          ? '${u['firstName']} ${u['lastName'] ?? ''}'.trim()
          : (u['shopName'] != null &&
                u['shopName'].toString().trim().isNotEmpty)
          ? u['shopName']
          : (u['phoneNumber'] ?? 'Unnamed Lead'),
      'phone': u['phoneNumber'] ?? '',
      'city': u['address']?['cityTehsil'] ?? '',
      'state': u['address']?['state'] ?? '',
      'activity': u['updatedAt'] != null ? _formatTimeAgo(u['updatedAt']) : '-',
      'agent': u['assignedAgent'] != null
          ? '${u['assignedAgent']['firstName'] ?? ''} ${u['assignedAgent']['lastName'] ?? ''}'
                .trim()
          : '-',
      'agentId': u['assignedAgent']?['_id'],
      'source': u['source'] ?? 'App',
      'deepLinkUrl': u['deepLinkUrl'],
      'status': u['kycStatus'] == 'pending' || u['kycStatus'] == 'submitted'
          ? 'KYC Pending'
          : (u['assignedAgent'] != null ? 'Assigned' : 'Unassigned'),
      'kycStatus': u['kycStatus'] ?? 'pending',
      'gstNumber': u['gstNumber'] ?? '',
      'userType': u['userType'] ?? '',
      'licenceImage': u['licenceImage'] ?? '',
      'shopImage': u['shopImage'] ?? '',
      'isBlocked': u['isBlocked'] ?? false,
    };
  }

  void _showConvertDealerDialog() {
    String? errorMessage;

    final stateText =
        _lead!['state'] != null && _lead!['state'].toString().isNotEmpty
        ? ', ${_lead!['state']}'
        : '';
    final locationText = '${_lead!['city'] ?? ''}$stateText';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            Widget buildNotificationPreview() {
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.phonelink_ring_rounded,
                          color: Color(0xFF10B981),
                          size: 14,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'LIVE PUSH NOTIFICATION PREVIEW',
                          style: GoogleFonts.outfit(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textSecondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Color(0xFFECFDF5),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.verified_user_rounded,
                              color: Color(0xFF10B981),
                              size: 14,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'KrishiDealer Admin',
                                      style: GoogleFonts.outfit(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      'now',
                                      style: GoogleFonts.outfit(
                                        fontSize: 9.5,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Congratulations! Your KYC verification has been approved. You are now a dealer.',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.outfit(
                                    fontSize: 10.5,
                                    color: AppTheme.textBody,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }

            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              titlePadding: EdgeInsets.zero,
              title: Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Color(0xFFECFDF5),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x1A10B981),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.verified_user_rounded,
                        color: Color(0xFF10B981),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Convert to Dealer',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Verify and grant official dealer credentials',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF065F46),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'You are about to approve this user\'s KYC details. This will convert their account from a Lead to an active Dealer with system privileges.',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: const Color(0xFF6B7280),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Column(
                          children: [
                            _buildInfoRow('Name', _lead!['name'] ?? '-'),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8.0),
                              child: Divider(
                                height: 1,
                                color: Color(0xFFE5E7EB),
                              ),
                            ),
                            _buildInfoRow('Phone', _lead!['phone'] ?? '-'),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8.0),
                              child: Divider(
                                height: 1,
                                color: Color(0xFFE5E7EB),
                              ),
                            ),
                            _buildInfoRow(
                              'Location',
                              locationText.isNotEmpty ? locationText : '-',
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8.0),
                              child: Divider(
                                height: 1,
                                color: Color(0xFFE5E7EB),
                              ),
                            ),
                            _buildInfoRow('Source', _lead!['source'] ?? '-'),
                            if (_lead!['deepLinkUrl'] != null &&
                                _lead!['deepLinkUrl']
                                    .toString()
                                    .trim()
                                    .isNotEmpty) ...[
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8.0),
                                child: Divider(
                                  height: 1,
                                  color: Color(0xFFE5E7EB),
                                ),
                              ),
                              _buildInfoRow('Deep Link', _lead!['deepLinkUrl']),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      buildNotificationPreview(),
                      if (errorMessage case final msg?) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFCA5A5)),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: AppTheme.error,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  msg,
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    color: AppTheme.error,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actionsPadding: const EdgeInsets.only(
                left: 20,
                right: 20,
                bottom: 20,
              ),
              actions: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF4B5563),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () {
                          final userId = _lead!['id'] ?? _lead!['_id'];
                          if (userId != null) {
                            context.read<LeadsBloc>().add(
                              VerifyKYCEvent(userId),
                            );
                          }
                          Navigator.pop(context);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Approve & Convert',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF9CA3AF),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF374151),
            ),
          ),
        ),
      ],
    );
  }

  void _showRejectDialog() {
    final controller = TextEditingController();
    final Map<String, List<String>> categorizedReasons = {
      'Document Issues': ['Blurry Document', 'Incomplete Scan / Cut-off'],
      'Information & Validity': [
        'Expired Licence',
        'Name Mismatch',
        'Wrong Address',
      ],
      'Tax & Registration': ['Invalid GSTIN'],
    };

    String? selectedReason;
    String? hoveredReason;
    String? errorMessage;

    Widget buildNotificationPreview(String content) {
      final String reasonText = content.isNotEmpty
          ? content
                .replaceAll('KYC Rejected: ', '')
                .replaceAll('. Please re-upload valid documents.', '')
          : '[reason]';
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.phonelink_ring_rounded,
                  color: AppTheme.accentColor,
                  size: 14,
                ),
                const SizedBox(width: 8),
                Text(
                  'LIVE PUSH NOTIFICATION PREVIEW',
                  style: GoogleFonts.outfit(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.gavel_rounded,
                      color: AppTheme.primaryColor,
                      size: 14,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'KrishiDealer Admin',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            Text(
                              'now',
                              style: GoogleFonts.outfit(
                                fontSize: 9.5,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Your KYC has been rejected: $reasonText',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            fontSize: 10.5,
                            color: AppTheme.textBody,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    showDialog(
      context: context,
      barrierDismissible:
          false, // Prevent closing dialog by clicking outside during submit
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          List<Widget> categoryWidgets = [];
          categorizedReasons.forEach((category, reasons) {
            categoryWidgets.add(
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 6),
                child: Text(
                  category.toUpperCase(),
                  style: GoogleFonts.outfit(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF9CA3AF),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            );

            categoryWidgets.add(
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: reasons.map((reason) {
                  final bool isSelected = selectedReason == reason;
                  final bool isHovered = hoveredReason == reason;
                  return MouseRegion(
                    cursor: SystemMouseCursors.click,
                    onEnter: (_) {
                      setStateDialog(() => hoveredReason = reason);
                    },
                    onExit: (_) {
                      setStateDialog(() => hoveredReason = null);
                    },
                    child: GestureDetector(
                      onTap: () {
                        setStateDialog(() {
                          selectedReason = reason;
                          controller.text =
                              'KYC Rejected: $reason. Please re-upload valid documents.';
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.error.withOpacity(0.08)
                              : (isHovered
                                    ? const Color(0xFFE5E7EB)
                                    : const Color(0xFFF3F4F6)),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? AppTheme.error.withOpacity(0.4)
                                : const Color(0xFFE5E7EB),
                            width: 1.2,
                          ),
                        ),
                        child: Text(
                          reason,
                          style: GoogleFonts.outfit(
                            fontSize: 11.5,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w600,
                            color: isSelected
                                ? AppTheme.error
                                : const Color(0xFF4B5563),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            );
          });

          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            titlePadding: EdgeInsets.zero,
            title: Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFFFEF2F2),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x1AEF4444),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.gavel_rounded,
                      color: AppTheme.error,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reject KYC Verification',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Review and select/enter the rejection reason',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF991B1B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 16,
            ),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Provide a clear rejection reason. The user will be notified immediately and prompted to re-upload their documents.',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: const Color(0xFF6B7280),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...categoryWidgets,
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'REJECTION EXPLANATION',
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF9CA3AF),
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          '${controller.text.length} / 300',
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: controller.text.length > 270
                                ? AppTheme.error
                                : const Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: controller,
                      maxLines: 3,
                      maxLength: 300,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      onChanged: (val) {
                        setStateDialog(() {});
                      },
                      decoration: InputDecoration(
                        counterText: "",
                        hintText:
                            'Enter a custom explanation or select a reason above...',
                        hintStyle: GoogleFonts.outfit(
                          fontSize: 13,
                          color: const Color(0xFF9CA3AF),
                          fontWeight: FontWeight.w500,
                        ),
                        suffixIcon: controller.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(
                                  Icons.clear_rounded,
                                  size: 16,
                                  color: Color(0xFF9CA3AF),
                                ),
                                onPressed: () {
                                  setStateDialog(() {
                                    controller.clear();
                                    selectedReason = null;
                                  });
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFE5E7EB),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppTheme.error,
                            width: 1.5,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFE5E7EB),
                          ),
                        ),
                        disabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFF3F4F6),
                          ),
                        ),
                        fillColor: const Color(0xFFF9FAFB),
                        filled: true,
                        contentPadding: const EdgeInsets.all(12),
                      ),
                    ),
                    const SizedBox(height: 20),
                    buildNotificationPreview(controller.text),
                  ],
                ),
              ),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            actions: [
              if (errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFEE2E2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: AppTheme.error,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            errorMessage!,
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF4B5563),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () {
                        final reason = controller.text.trim();
                        if (reason.isEmpty) {
                          setStateDialog(() {
                            errorMessage =
                                'Please provide a rejection explanation.';
                          });
                          return;
                        }
                        final userId = _lead!['id'] ?? _lead!['_id'];
                        if (userId != null) {
                          context.read<LeadsBloc>().add(
                            RejectKYCEvent(userId, reason),
                          );
                        }
                        Navigator.pop(context); // Close dialog immediately
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.error,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.error.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.block_outlined,
                              color: Colors.white,
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Reject KYC',
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  void _assignAgent(String? agentId) {
    if (_lead == null) return;
    final userId = _lead!['id'] ?? _lead!['_id'];
    if (userId != null) {
      context.read<LeadsBloc>().add(AssignAgentToLeadEvent(userId, agentId));
    }
  }

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
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
    return BlocConsumer<LeadsBloc, LeadsState>(
      listener: (context, state) {
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: AppTheme.error,
            ),
          );
          context.read<LeadsBloc>().add(const ClearLeadsMessageEvent());
        }
        if (state.actionSuccessMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.actionSuccessMessage!),
              backgroundColor: AppTheme.success,
            ),
          );
          final msg = state.actionSuccessMessage!;
          context.read<LeadsBloc>().add(const ClearLeadsMessageEvent());
          if (msg.contains('KYC Approved') || msg.contains('KYC Rejected')) {
            Navigator.pop(context);
          }
        }
      },
      builder: (context, state) {
        final String? leadId = _lead?['id'] ?? _lead?['_id'];
        Map<String, dynamic>? currentLead = _lead;

        if (leadId != null && state.allRawUsers.isNotEmpty) {
          final rawUser = state.allRawUsers.firstWhere(
            (u) => u['_id'] == leadId || u['id'] == leadId,
            orElse: () => <String, dynamic>{},
          );
          if (rawUser.isNotEmpty) {
            currentLead = _mapUserToLead(rawUser);
            _saveLeadToCache(currentLead);
          }
        }

        if (currentLead == null) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            ),
          );
        }

        final isMobile = Responsive.isMobile(context);
        final isTablet = Responsive.isTablet(context);
        final isLoading = state.status == LeadsStatus.submitting;

        return SelectionArea(
          child: Scaffold(
            backgroundColor: const Color(0xFFF8FAFC),
            body: isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.primaryColor,
                    ),
                  )
                : SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 16 : (isTablet ? 24 : 40),
                      vertical: isMobile ? 20 : 32,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Back Button Row
                        Row(
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
                                  'Back to Leads',
                                  style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF6B7280),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // 1. Flat Header section
                        _FlatHeaderSection(
                          lead: currentLead,
                          isSales: AuthService().isSales,
                          onConvertDealer: _showConvertDealerDialog,
                          onRejectKyc: _showRejectDialog,
                          onToggleBlock: _toggleBlockLead,
                        ),
                        const SizedBox(height: 28),

                        // 2. Lead Information and KYC Documents side-by-side on desktop
                        if (!isMobile)
                          IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  flex: 1,
                                  child: _LeadInformationCard(
                                    lead: currentLead,
                                    salesAgents: state.salesAgents,
                                    onAssignAgent: _assignAgent,
                                  ),
                                ),
                                const SizedBox(width: 32),
                                Expanded(
                                  flex: 1,
                                  child: _DealerKycDocumentsCard(
                                    lead: currentLead,
                                    onViewDocument: _launchUrl,
                                    isVertical: true,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else ...[
                          _LeadInformationCard(
                            lead: currentLead,
                            salesAgents: state.salesAgents,
                            onAssignAgent: _assignAgent,
                          ),
                          const SizedBox(height: 24),
                          _DealerKycDocumentsCard(
                            lead: currentLead,
                            onViewDocument: _launchUrl,
                          ),
                        ],
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }
}

class _FlatHeaderSection extends StatelessWidget {
  final Map<String, dynamic> lead;
  final bool isSales;
  final VoidCallback onConvertDealer;
  final VoidCallback onRejectKyc;
  final VoidCallback onToggleBlock;

  const _FlatHeaderSection({
    required this.lead,
    required this.isSales,
    required this.onConvertDealer,
    required this.onRejectKyc,
    required this.onToggleBlock,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final isTablet = Responsive.isTablet(context);

    final stateText = lead['state'].toString().isNotEmpty
        ? ', ${lead['state']}'
        : '';
    final locationText = '${lead['city']}$stateText';
    final String kycStatus = lead['kycStatus'] ?? 'pending';
    final Color statusColor = kycStatus.toLowerCase() == 'verified'
        ? const Color(0xFF10B981)
        : kycStatus.toLowerCase() == 'rejected'
        ? const Color(0xFFEF4444)
        : const Color(0xFFF59E0B);

    final String initial =
        lead['name'] != null && lead['name'].toString().isNotEmpty
        ? lead['name'].toString().substring(0, 1).toUpperCase()
        : 'L';

    final Widget avatar = Container(
      width: 48,
      height: 48,
      decoration: const BoxDecoration(
        color: Color(0xFFFFF3E0),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initial,
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFFFA9527),
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
                            lead['name'],
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1F2937),
                            ),
                          ),
                          const SizedBox(height: 4),
                          _buildStatusBadge(
                            kycStatus.toUpperCase(),
                            statusColor,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildContactRow(locationText, isMobile),
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
                            lead['name'],
                            style: GoogleFonts.outfit(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1F2937),
                            ),
                          ),
                          const SizedBox(width: 12),
                          _buildStatusBadge(
                            kycStatus.toUpperCase(),
                            statusColor,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      _buildContactRow(locationText, isMobile),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                _buildActionButtons(context, isMobile, isTablet),
              ],
            ),
    );
  }

  Widget _buildContactRow(String locationText, bool isMobile) {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _buildContactItem(Icons.phone_outlined, lead['phone']),
        _buildContactDivider(),
        _buildContactItem(
          Icons.location_on_outlined,
          locationText.isNotEmpty ? locationText : '-',
        ),
        _buildContactDivider(),
        _buildContactItem(Icons.hub_outlined, 'Source: ${lead['source']}'),
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
        Icon(icon, size: 16, color: const Color(0xFFE65100)),
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

  Widget _buildActionButtons(
    BuildContext context,
    bool isMobile,
    bool isTablet,
  ) {
    final String kycStatus = lead['kycStatus'] ?? 'pending';
    final hasLicence =
        lead['licenceImage'] != null &&
        lead['licenceImage'].toString().isNotEmpty;
    final hasShopImage =
        lead['shopImage'] != null && lead['shopImage'].toString().isNotEmpty;
    final hasDocuments = hasLicence || hasShopImage;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _ActionButton(
          icon: Icons.message,
          label: 'WhatsApp',
          color: const Color(0xFF25D366),
          isSolid: true,
          onTap: () async {
            final whatsappUrl = "https://wa.me/${lead['phone']}";
            final Uri url = Uri.parse(whatsappUrl);
            if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Could not open WhatsApp for number: ${lead['phone']}',
                  ),
                  backgroundColor: AppTheme.error,
                ),
              );
            }
          },
        ),
        _ActionButton(
          icon: Icons.person_add_outlined,
          label: 'Convert Dealer',
          color: const Color(0xFF1976D2),
          isSolid: true,
          onTap: (kycStatus.toLowerCase() == 'verified')
              ? null
              : onConvertDealer,
        ),
        // Admin-only actions
        if (!isSales) ...[
          _ActionButton(
            icon: Icons.block_outlined,
            label: 'Reject KYC',
            color: const Color(0xFFD32F2F),
            isSolid: true,
            onTap:
                ((kycStatus.toLowerCase() == 'pending' ||
                        kycStatus.toLowerCase() == 'submitted') &&
                    hasDocuments)
                ? onRejectKyc
                : null,
          ),
          _ActionButton(
            icon: (lead['isBlocked'] ?? false)
                ? Icons.lock_open_outlined
                : Icons.lock_outline,
            label: (lead['isBlocked'] ?? false) ? 'Unblock' : 'Block',
            color: (lead['isBlocked'] ?? false) ? Colors.blue : AppTheme.error,
            isSolid: true,
            onTap: onToggleBlock,
          ),
        ],
      ],
    );
  }
}

class _ActionButton extends StatefulWidget {
  final dynamic icon;
  final String label;
  final Color color;
  final bool isSolid;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    this.isSolid = false,
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
    final bool isDisabled = widget.onTap == null;

    return MouseRegion(
      onEnter: isDisabled ? null : (_) => setState(() => isHovered = true),
      onExit: isDisabled ? null : (_) => setState(() => isHovered = false),
      cursor: isDisabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: isMobile ? 48 : 44,
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 22),
          decoration: BoxDecoration(
            color: isDisabled
                ? (widget.isSolid ? const Color(0xFFE5E7EB) : Colors.white)
                : widget.isSolid
                ? (isHovered ? widget.color.withOpacity(0.9) : widget.color)
                : (isHovered ? widget.color.withOpacity(0.08) : Colors.white),
            borderRadius: BorderRadius.circular(12),
            border: widget.isSolid
                ? null
                : Border.all(
                    color: isDisabled
                        ? const Color(0xFFE5E7EB)
                        : widget.color.withOpacity(isHovered ? 0.8 : 0.4),
                    width: 1.5,
                  ),
            boxShadow: (!isDisabled && isHovered)
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
              widget.icon is IconData
                  ? Icon(
                      widget.icon as IconData,
                      size: isMobile ? 18 : 19,
                      color: isDisabled
                          ? const Color(0xFF9CA3AF)
                          : (widget.isSolid ? Colors.white : widget.color),
                    )
                  : FaIcon(
                      widget.icon,
                      size: isMobile ? 18 : 19,
                      color: isDisabled
                          ? const Color(0xFF9CA3AF)
                          : (widget.isSolid ? Colors.white : widget.color),
                    ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  widget.label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: isMobile ? 13 : 14,
                    fontWeight: FontWeight.w700,
                    color: isDisabled
                        ? const Color(0xFF9CA3AF)
                        : (widget.isSolid ? Colors.white : widget.color),
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
            'Lead Information',
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 12),
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
            lead['source'] ?? 'App',
            Colors.teal,
          ),
          if (lead['deepLinkUrl'] != null &&
              lead['deepLinkUrl'].toString().trim().isNotEmpty) ...[
            _buildDividerRow(),
            _buildInfoRow(
              Icons.link_outlined,
              'Deep Link',
              lead['deepLinkUrl'].toString(),
              Colors.blueGrey,
            ),
            ..._getDeepLinkAttributes(
              lead['deepLinkUrl'].toString(),
            ).entries.map((entry) {
              return Column(
                children: [
                  _buildDividerRow(),
                  _buildInfoRow(
                    Icons.sell_outlined,
                    entry.key,
                    entry.value,
                    Colors.grey,
                  ),
                ],
              );
            }),
          ],
          if (!AuthService().isSales) ...[
            _buildDividerRow(),
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
                  const Expanded(
                    flex: 2,
                    child: Text(
                      'Assigned Sales',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7280),
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
                                  (agent) => agent['_id'] == lead['agentId'],
                                )
                                ? lead['agentId']
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

  Map<String, String> _getDeepLinkAttributes(String? urlString) {
    if (urlString == null || urlString.trim().isEmpty) return {};
    try {
      final uri = Uri.parse(urlString);
      return uri.queryParameters;
    } catch (e) {
      return {};
    }
  }
}

Widget _buildInfoRow(IconData icon, String label, String value, Color color) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
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
              fontSize: 13,
              color: Color(0xFF111827),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _buildDividerRow() => const Divider(height: 1, color: Color(0xFFF1F5F9));

class _DealerKycDocumentsCard extends StatelessWidget {
  final Map<String, dynamic> lead;
  final Function(String url) onViewDocument;
  final bool isVertical;

  const _DealerKycDocumentsCard({
    required this.lead,
    required this.onViewDocument,
    this.isVertical = false,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final hasLicence =
        lead['licenceImage'] != null &&
        lead['licenceImage'].toString().isNotEmpty;
    final hasShopImage =
        lead['shopImage'] != null && lead['shopImage'].toString().isNotEmpty;

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
            'KYC Documents',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 12),
          if (isMobile || isVertical)
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
                  isVertical: isVertical,
                ),
                const SizedBox(height: 12),
                _KycDocumentCard(
                  title: 'Shop Image',
                  status: lead['kycStatus'],
                  icon: Icons.storefront_outlined,
                  onTap: hasShopImage
                      ? () => onViewDocument(lead['shopImage'])
                      : null,
                  isVertical: isVertical,
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
                const SizedBox(width: 16),
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
  final bool isVertical;

  const _KycDocumentCard({
    required this.title,
    required this.status,
    this.subtext,
    required this.icon,
    this.onTap,
    this.isVertical = false,
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
                  color: Color(0xFFFFF3E0),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.icon,
                  size: 16,
                  color: const Color(0xFFFA9527),
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
              if (widget.onTap != null) ...[
                const SizedBox(width: 8),
                const Icon(
                  Icons.open_in_new_rounded,
                  size: 16,
                  color: AppTheme.primaryColor,
                ),
              ],
            ],
          ),
        ),
      ),
    );

    return isMobile || widget.isVertical ? card : Expanded(child: card);
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
