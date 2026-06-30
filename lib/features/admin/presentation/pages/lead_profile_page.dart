import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kd_pannel/app_theme.dart';
import 'package:kd_pannel/core/responsive/responsive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/leads_bloc.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/leads_event.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/leads_state.dart';
import 'package:kd_pannel/features/shared/widgets/user_status_notes_widget.dart';
import 'package:kd_pannel/core/auth/auth_service.dart';
import 'package:kd_pannel/core/utils/navigation_service.dart';
import 'package:kd_pannel/core/services/analytics_service.dart';


class LeadProfilePage extends StatefulWidget {
  const LeadProfilePage({super.key});

  @override
  State<LeadProfilePage> createState() => _LeadProfilePageState();
}

class _LeadProfilePageState extends State<LeadProfilePage> {
  Map<String, dynamic>? _lead;
  bool _isCacheLoaded = false;
  List<Map<String, dynamic>> _events = [];
  bool _isLoadingEvents = false;
  int _activeTab = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_lead == null) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map) {
        _lead = Map<String, dynamic>.from(args);
        _isCacheLoaded = true;
        _saveLeadToCache(_lead!);
        _refreshLeadDetails();
        _fetchEvents();

        // Track profile view event
        AnalyticsService().logEvent(
          'profile_view',
          properties: {
            'leadId': _lead!['id'] ?? _lead!['_id'] ?? '',
            'leadName':
                '${_lead!['firstName'] ?? ''} ${_lead!['lastName'] ?? ''}'
                    .trim(),
            'details':
                'Viewed lead profile for ${_lead!['firstName'] ?? ''} ${_lead!['lastName'] ?? ''}'
                    .trim(),
          },
        );
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
        _fetchEvents();
      }
    } catch (e) {
      debugPrint('Error loading lead from cache: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isCacheLoaded = true;
        });
      }
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

  Future<void> _fetchEvents() async {
    if (_lead == null) return;
    final identifier =
        _lead!['email'] ??
        _lead!['phone'] ??
        _lead!['phoneNumber'] ??
        _lead!['id'] ??
        _lead!['_id'];
    if (identifier == null) return;
    if (mounted) setState(() => _isLoadingEvents = true);
    try {
      final filtered = await AnalyticsService().fetchEvents(
        userEmail: identifier.toString(),
      );
      if (mounted) {
        setState(() {
          _events = filtered;
        });
      }
    } catch (e) {
      debugPrint('Error loading lead events: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingEvents = false;
        });
      }
    }
  }

  void _toggleBlockLead() {
    if (_lead == null) return;
    final isBlocked = _lead!['isBlocked'] ?? false;
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
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
                final userId = _lead!['id'] ?? _lead!['_id'];
                if (userId != null) {
                  Navigator.pop(dialogContext);
                  context.read<LeadsBloc>().add(ToggleBlockLeadEvent(userId));
                  setState(() {
                    _lead!['isBlocked'] = !isBlocked;
                  });
                }
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

  Future<void> _editLead() async {
    if (_lead == null) return;
    final nameController = TextEditingController(text: _lead!['name']);
    final shopNameController = TextEditingController(
      text: _lead!['shopName'] ?? '',
    );
    final gstController = TextEditingController(
      text: _lead!['gstNumber'] ?? '',
    );
    final phoneController = TextEditingController(text: _lead!['phone']);
    final villageAreaController = TextEditingController(
      text: _lead!['villageArea'] ?? '',
    );
    final addressLine2Controller = TextEditingController(
      text: _lead!['addressLine2'] ?? '',
    );
    final cityController = TextEditingController(text: _lead!['city']);
    final stateController = TextEditingController(text: _lead!['state']);
    final pincodeController = TextEditingController(
      text: _lead!['pincode'] ?? '',
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Edit Details',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildEditField('Name', nameController),
              const SizedBox(height: 12),
              _buildEditField('Shop Name', shopNameController),
              const SizedBox(height: 12),
              _buildEditField('GST Number', gstController),
              const SizedBox(height: 12),
              _buildEditField(
                'Phone (Not Editable)',
                phoneController,
                readOnly: true,
              ),
              const SizedBox(height: 12),
              _buildEditField(
                'Village/Area (Address 1)',
                villageAreaController,
              ),
              const SizedBox(height: 12),
              _buildEditField(
                'Address Line 2 (Optional)',
                addressLine2Controller,
              ),
              const SizedBox(height: 12),
              _buildEditField('City/Tehsil', cityController),
              const SizedBox(height: 12),
              _buildEditField('State', stateController),
              const SizedBox(height: 12),
              _buildEditField('Pincode', pincodeController),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final String fullName = nameController.text.trim();
      final names = fullName.split(' ');
      final firstName = names.isNotEmpty ? names[0] : '';
      final lastName = names.length > 1 ? names.sublist(1).join(' ') : '';
      final userId = _lead!['id'] ?? _lead!['_id'];

      if (userId != null) {
        context.read<LeadsBloc>().add(
          UpdateLeadDetailsEvent(
            userId: userId,
            updateData: {
              'firstName': firstName,
              'lastName': lastName,
              'shopName': shopNameController.text.trim(),
              'gstNumber': gstController.text.trim(),
              'phoneNumber': phoneController.text.trim(),
              'address': {
                'villageArea': villageAreaController.text.trim(),
                'addressLine2': addressLine2Controller.text.trim(),
                'address2': addressLine2Controller.text.trim(),
                'cityTehsil': cityController.text.trim(),
                'state': stateController.text.trim(),
                'pincode': pincodeController.text.trim(),
              },
            },
          ),
        );
        // Wait for update and refresh
        await Future.delayed(const Duration(milliseconds: 500));
        _refreshLeadDetails();
      }
    }
  }

  Widget _buildEditField(
    String label,
    TextEditingController controller, {
    bool readOnly = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          readOnly: readOnly,
          style: GoogleFonts.outfit(
            fontSize: 14,
            color: readOnly ? AppTheme.textSecondary : AppTheme.textPrimary,
          ),
          decoration: InputDecoration(
            fillColor: readOnly ? const Color(0xFFF9FAFB) : Colors.white,
            filled: readOnly,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppTheme.borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppTheme.borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: AppTheme.primaryColor,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _deleteLead() async {
    if (_lead == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: AppTheme.error,
              size: 28,
            ),
            const SizedBox(width: 12),
            Text(
              'Delete Record',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete lead "${_lead!['name']}"? This action cannot be undone and all associated data will be removed.',
          style: GoogleFonts.outfit(
            color: AppTheme.textSecondary,
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.outfit(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: Text(
              'Confirm Delete',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final userId = _lead!['id'] ?? _lead!['_id'];
      if (userId != null) {
        context.read<LeadsBloc>().add(DeleteLeadEvent(userId));
        Navigator.pop(context); // Go back after deletion
      }
    }
  }

  Map<String, dynamic> _mapUserToLead(Map<String, dynamic> u) {
    final String personName = (u['firstName'] != null || u['lastName'] != null)
        ? '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'.trim()
        : '';
    return {
      'id': u['_id'],
      'name': personName.isNotEmpty
          ? personName
          : (u['phoneNumber'] ?? 'Unnamed Lead'),
      'phone': u['phoneNumber'] ?? '',
      'shopName': u['shopName'] ?? '',
      'villageArea': u['address']?['villageArea'] ?? '',
      'addressLine2': u['address']?['addressLine2'] ?? '',
      'city': u['address']?['cityTehsil'] ?? '',
      'state': u['address']?['state'] ?? '',
      'pincode': u['address']?['pincode'] ?? '',
      'activity': u['updatedAt'] != null ? _formatTimeAgo(u['updatedAt']) : '-',
      'agent': u['assignedAgent'] != null
          ? '${u['assignedAgent']['firstName'] ?? ''} ${u['assignedAgent']['lastName'] ?? ''}'
                .trim()
          : '-',
      'agentId': u['assignedAgent']?['_id'],
      'source': u['source'] ?? 'App',
      'deepLinkUrl': u['deepLinkUrl'],
      'processingStatus':
          u['kycStatus'] == 'pending' || u['kycStatus'] == 'submitted'
          ? 'KYC Pending'
          : (u['assignedAgent'] != null ? 'Assigned' : 'Unassigned'),
      'kycStatus': u['kycStatus'] ?? 'pending',
      'gstNumber': u['gstNumber'] ?? '',
      'userType': u['userType'] ?? '',
      'licenceImage': u['licenceImage'] ?? '',
      'shopImage': u['shopImage'] ?? '',
      'isBlocked': u['isBlocked'] ?? false,
      'status': u['status'] ?? u['leadStatus'] ?? 'prospect',
      'notes': u['notes'] ?? u['leadNotes'] ?? '',
      'notesHistory': u['notesHistory'] ?? [],
    };
  }

  void _showConvertDealerDialog() {
    String? errorMessage;

    final List<String> locationParts = [];
    if (_lead!['villageArea']?.toString().isNotEmpty ?? false) {
      locationParts.add(_lead!['villageArea']);
    }
    if (_lead!['city']?.toString().isNotEmpty ?? false) {
      locationParts.add(_lead!['city']);
    }
    if (_lead!['state']?.toString().isNotEmpty ?? false) {
      locationParts.add(_lead!['state']);
    }
    if (_lead!['pincode']?.toString().isNotEmpty ?? false) {
      locationParts.add(_lead!['pincode']);
    }
    final locationText = locationParts.join(', ');

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

  void _showUploadKycDialog() {
    final shopNameController = TextEditingController(
      text: _lead!['shopName'] ?? '',
    );
    final gstController = TextEditingController(
      text: _lead!['gstNumber'] ?? '',
    );
    String selectedUserType = 'Retailer and Distributor';

    PlatformFile? licenceFile;
    PlatformFile? shopFile;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          title: Text(
            'Upload KYC Documents',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildEditField('Shop Name', shopNameController),
                const SizedBox(height: 12),
                _buildEditField('GST Number (Optional)', gstController),
                const SizedBox(height: 12),
                Text(
                  'User Type',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: selectedUserType,
                      items: ['Retailer and Distributor']
                          .map(
                            (e) => DropdownMenuItem(value: e, child: Text(e)),
                          )
                          .toList(),
                      onChanged: (val) =>
                          setStateDialog(() => selectedUserType = val!),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _buildFilePicker(
                  'GST Certificate / Licence',
                  licenceFile,
                  () async {
                    final res = await FilePicker.pickFiles(
                      type: FileType.image,
                      withData: true,
                    );
                    if (res != null) {
                      setStateDialog(() => licenceFile = res.files.first);
                    }
                  },
                ),
                const SizedBox(height: 12),
                _buildFilePicker('Shop Exterior Image', shopFile, () async {
                  final res = await FilePicker.pickFiles(
                    type: FileType.image,
                    withData: true,
                  );
                  if (res != null) {
                    setStateDialog(() => shopFile = res.files.first);
                  }
                }),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed:
                  (licenceFile == null ||
                      shopFile == null ||
                      shopNameController.text.trim().isEmpty)
                  ? null
                  : () {
                      context.read<LeadsBloc>().add(
                        AdminSubmitKycEvent(
                          userId: _lead!['id'] ?? _lead!['_id'],
                          userType: selectedUserType,
                          shopName: shopNameController.text.trim(),
                          gstNumber: gstController.text.trim(),
                          licenceImageBytes: licenceFile!.bytes!.toList(),
                          licenceFileName: licenceFile!.name,
                          shopImageBytes: shopFile!.bytes!.toList(),
                          shopFileName: shopFile!.name,
                        ),
                      );
                      Navigator.pop(context);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Submit KYC'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilePicker(
    String label,
    PlatformFile? file,
    VoidCallback onTap,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: file != null ? AppTheme.success : AppTheme.borderColor,
                style: file != null ? BorderStyle.solid : BorderStyle.solid,
              ),
              color: file != null
                  ? AppTheme.success.withOpacity(0.05)
                  : Colors.white,
            ),
            child: Row(
              children: [
                Icon(
                  file != null ? Icons.check_circle_outline : Icons.upload_file,
                  size: 20,
                  color: file != null
                      ? AppTheme.success
                      : AppTheme.textSecondary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    file?.name ?? 'Click to select image',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: file != null
                          ? AppTheme.success
                          : AppTheme.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      NavigationService.messengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('Could not open link: $urlString'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.outfit(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: color.withOpacity(0.8),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedProfileTabs() {
    final List<Map<String, dynamic>> tabs = [
      {'icon': Icons.dashboard_outlined, 'label': 'Overview'},
      {'icon': Icons.analytics_outlined, 'label': 'Activities'},
      {'icon': Icons.rate_review_outlined, 'label': 'Notes'},
    ];

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.015),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: tabs.asMap().entries.map((entry) {
          final idx = entry.key;
          final tab = entry.value;
          final isSelected = _activeTab == idx;

          return Expanded(
            child: InkWell(
              onTap: () => setState(() => _activeTab = idx),
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.accentColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppTheme.accentColor.withOpacity(0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      tab['icon'] as IconData,
                      size: 16,
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFF6B7280),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      tab['label'] as String,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: isSelected
                            ? FontWeight.w800
                            : FontWeight.w600,
                        color: isSelected
                            ? Colors.white
                            : const Color(0xFF4B5563),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<LeadsBloc, LeadsState>(
      listener: (context, state) {
        if (state.errorMessage != null) {
          NavigationService.messengerKey.currentState?.showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: AppTheme.error,
            ),
          );
          context.read<LeadsBloc>().add(const ClearLeadsMessageEvent());
        }
        if (state.actionSuccessMessage != null) {
          NavigationService.messengerKey.currentState?.showSnackBar(
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
          if (_isCacheLoaded) {
            return Scaffold(
              backgroundColor: const Color(0xFFF8FAFC),
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Lead details not found or session expired.',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () =>
                          Navigator.pushReplacementNamed(context, '/leads'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Go to Leads List',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
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
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.015),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(
                                  Icons.arrow_back_ios_new_rounded,
                                  size: 14,
                                  color: Color(0xFF6B7280),
                                ),
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.zero,
                                splashRadius: 20,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Admin Portal',
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF9CA3AF),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.chevron_right_rounded,
                                size: 16,
                                color: Color(0xFF9CA3AF),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: Text(
                                    'Leads',
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.accentColor,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.chevron_right_rounded,
                                size: 16,
                                color: Color(0xFF9CA3AF),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  currentLead['name'] ?? '',
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF1F2937),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 1. Flat Header section
                        _FlatHeaderSection(
                          lead: currentLead,
                          isSales: AuthService().isSales,
                          onConvertDealer: _showConvertDealerDialog,
                          onRejectKyc: _showRejectDialog,
                          onToggleBlock: _toggleBlockLead,
                          onEdit: _editLead,
                          onDelete: _deleteLead,
                        ),
                        const SizedBox(height: 28),

                        // 2. TAB CONTROLLER CHIPS SELECTOR
                        _buildAdvancedProfileTabs(),
                        const SizedBox(height: 24),

                        // 3. TABBED CONTENT CHANNELS
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: _activeTab == 0
                              ? Column(
                                  key: const ValueKey(0),
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (!isMobile) ...[
                                      IntrinsicHeight(
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
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
                                                onUpload: _showUploadKycDialog,
                                                isVertical: true,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ] else ...[
                                      _LeadInformationCard(
                                        lead: currentLead,
                                        salesAgents: state.salesAgents,
                                        onAssignAgent: _assignAgent,
                                      ),
                                      const SizedBox(height: 24),
                                      _DealerKycDocumentsCard(
                                        lead: currentLead,
                                        onViewDocument: _launchUrl,
                                        onUpload: _showUploadKycDialog,
                                      ),
                                    ],
                                  ],
                                )
                              : _activeTab == 1
                              ? Column(
                                  key: const ValueKey(1),
                                  children: [
                                    if (leadId != null)
                                      _UserEventsCard(
                                        userIdentifier:
                                            currentLead['email'] ??
                                            currentLead['phone'] ??
                                            currentLead['phoneNumber'] ??
                                            leadId,
                                        events: _events,
                                        isLoading: _isLoadingEvents,
                                      ),
                                  ],
                                )
                              : Column(
                                  key: const ValueKey(2),
                                  children: [
                                    if (leadId != null)
                                      UserStatusNotesWidget(
                                        userId: leadId,
                                        initialStatus:
                                            currentLead['status'] ?? 'prospect',
                                        initialNotes:
                                            currentLead['notes'] ?? '',
                                        notesHistory:
                                            currentLead['notesHistory'] != null
                                            ? List<Map<String, dynamic>>.from(
                                                currentLead['notesHistory'],
                                              )
                                            : null,
                                        isSubmitting: isLoading,
                                        onSave: (status, notes) {
                                          context.read<LeadsBloc>().add(
                                            UpdateLeadDetailsEvent(
                                              userId: leadId,
                                              updateData: {
                                                'leadStatus': status,
                                                'leadNotes': notes,
                                              },
                                            ),
                                          );
                                        },
                                      ),
                                  ],
                                ),
                        ),
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
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _FlatHeaderSection({
    required this.lead,
    required this.isSales,
    required this.onConvertDealer,
    required this.onRejectKyc,
    required this.onToggleBlock,
    required this.onEdit,
    required this.onDelete,
  });

  Widget _buildMiniStat(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.outfit(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: color.withOpacity(0.8),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final isTablet = Responsive.isTablet(context);

    final List<String> locationParts = [];
    if (lead['villageArea']?.toString().isNotEmpty ?? false) {
      locationParts.add(lead['villageArea']);
    }
    if (lead['addressLine2']?.toString().isNotEmpty ?? false) {
      locationParts.add(lead['addressLine2']);
    }
    if (lead['city']?.toString().isNotEmpty ?? false) {
      locationParts.add(lead['city']);
    }
    if (lead['state']?.toString().isNotEmpty ?? false) {
      locationParts.add(lead['state']);
    }
    if (lead['pincode']?.toString().isNotEmpty ?? false) {
      locationParts.add(lead['pincode']);
    }

    final locationText = locationParts.join(', ');
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
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.accentColor, AppTheme.accentColor.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppTheme.accentColor.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Text(
          initial,
          style: GoogleFonts.outfit(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
      ),
    );

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.softShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // 1. BANNER COVER BACKGROUND WITH AURORA GRADIENTS
            Container(
              height: isMobile ? 100 : 130,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: kycStatus.toLowerCase() == 'verified'
                      ? [const Color(0xFF065F46), const Color(0xFF10B981)]
                      : kycStatus.toLowerCase() == 'rejected'
                      ? [const Color(0xFF991B1B), const Color(0xFFEF4444)]
                      : [const Color(0xFFB45309), const Color(0xFFF59E0B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            // Floating Decorative Bubbles
            Positioned(
              right: -20,
              top: -20,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.08),
                ),
              ),
            ),
            Positioned(
              left: 110,
              top: -40,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
            ),
            Positioned(
              right: 140,
              bottom: -15,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.04),
                ),
              ),
            ),

            // 2. CONTENT OVERLAY
            Padding(
              padding: EdgeInsets.fromLTRB(
                isMobile ? 16 : 24,
                isMobile ? 68 : 98,
                isMobile ? 16 : 24,
                isMobile ? 16 : 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: avatar,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      lead['name'] ?? '',
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.outfit(
                                        fontSize: isMobile ? 18 : 22,
                                        fontWeight: FontWeight.w900,
                                        color: const Color(0xFF111827),
                                      ),
                                    ),
                                  ),
                                  if (kycStatus.toLowerCase() == 'verified') ...[
                                    const SizedBox(width: 6),
                                    const Icon(
                                      Icons.verified_rounded,
                                      color: Color(0xFF298E4D),
                                      size: 18,
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  _buildStatusBadge(
                                    'KYC: ${kycStatus.toUpperCase()}',
                                    statusColor,
                                  ),
                                  if (lead['source'] != null && lead['source'].toString().isNotEmpty)
                                    _buildStatusBadge(
                                      'SOURCE: ${lead['source'].toString().toUpperCase()}',
                                      const Color(0xFF3B82F6),
                                    ),
                                ],
                              ),
                              if (!isMobile) ...[
                                const SizedBox(height: 12),
                                _buildContactRow(locationText, isMobile),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (isMobile) ...[
                    const SizedBox(height: 16),
                    _buildContactRow(locationText, isMobile),
                  ],
                  const SizedBox(height: 16),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 16),
                  _buildActionButtons(context, isMobile, isTablet),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactRow(String locationText, bool isMobile) {
    final cleanPhone = lead['phone'] ?? lead['phoneNumber'] ?? '';
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (cleanPhone.toString().isNotEmpty)
          _buildContactItem(Icons.phone_outlined, cleanPhone.toString()),
        if (locationText.isNotEmpty)
          _buildContactItem(Icons.location_on_outlined, locationText),
        if (lead['source'] != null)
          _buildContactItem(Icons.hub_outlined, 'Source: ${lead['source']}'),
      ],
    );
  }

  Widget _buildContactItem(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFFE65100)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: const Color(0xFF374151),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: GoogleFonts.outfit(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.3,
            ),
          ),
        ],
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
          icon: Icons.edit_outlined,
          label: 'Edit',
          color: AppTheme.info,
          isSolid: true,
          onTap: onEdit,
        ),
        _ActionButton(
          icon: FontAwesomeIcons.whatsapp,
          label: 'WhatsApp',
          color: const Color(0xFF25D366),
          isSolid: true,
          onTap: () async {
            final whatsappUrl = "https://wa.me/${lead['phone']}";
            final Uri url = Uri.parse(whatsappUrl);
            if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
              if (!context.mounted) return;
              NavigationService.messengerKey.currentState?.showSnackBar(
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
          _ActionButton(
            icon: Icons.delete_outline_rounded,
            label: 'Delete',
            color: AppTheme.error,
            isSolid: true,
            onTap: onDelete,
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

  Widget _buildMiniStat(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.outfit(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: color.withOpacity(0.8),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

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

  Future<void> _makeCall(String phone, BuildContext context) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\s+'), '');
    final url = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not initiate call to $phone'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _openWhatsApp(String phone, BuildContext context) async {
    var cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    if (cleanPhone.length == 10) {
      cleanPhone = '91$cleanPhone';
    }
    final url = Uri.parse('https://wa.me/$cleanPhone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open WhatsApp for $phone'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  void _copyToClipboard(String text, String label, BuildContext context) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard!'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppTheme.primaryColor,
        duration: const Duration(seconds: 2),
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

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.primaryColor),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF374151),
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final String leadName = lead['name'] ?? 'Unnamed Lead';
    final String leadPhone = lead['phone'] ?? '';
    final String shopName = lead['shopName']?.toString().isNotEmpty == true ? lead['shopName'] : 'No Shop Registered';
    final String leadSource = lead['source'] ?? 'App';
    final String initial = leadName.isNotEmpty ? leadName.substring(0, 1).toUpperCase() : 'L';

    final cardBgColor = Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.softShadow,
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryColor.withOpacity(0.06),
                  AppTheme.primaryColor.withOpacity(0.01),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              border: const Border(
                bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primaryColor,
                        AppTheme.primaryColor.withOpacity(0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      initial,
                      style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              leadName,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF111827),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.campaign_outlined,
                                  size: 12,
                                  color: AppTheme.primaryColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  leadSource.toUpperCase(),
                                  style: GoogleFonts.outfit(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.primaryColor,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.storefront_outlined,
                            size: 14,
                            color: Color(0xFF6B7280),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              shopName,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF4B5563),
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
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader('Location Details', Icons.pin_drop_outlined),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFF1F5F9)),
                  ),
                  child: Column(
                    children: [
                      _buildLocationItem(
                        Icons.home_outlined,
                        'Village/Area',
                        lead['villageArea']?.toString().isNotEmpty == true
                            ? lead['villageArea']
                            : '-',
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Divider(height: 1, color: Color(0xFFE2E8F0)),
                      ),
                      _buildLocationItem(
                        Icons.location_city_outlined,
                        'City / District',
                        lead['city']?.toString().isNotEmpty == true
                            ? lead['city']
                            : '-',
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Divider(height: 1, color: Color(0xFFE2E8F0)),
                      ),
                      _buildLocationItem(
                        Icons.map_outlined,
                        'State & Pincode',
                        '${lead['state']?.toString().isNotEmpty == true ? lead['state'] : '-'} - ${lead['pincode']?.toString().isNotEmpty == true ? lead['pincode'] : '-'}',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                if (lead['deepLinkUrl'] != null &&
                    lead['deepLinkUrl'].toString().trim().isNotEmpty) ...[
                  _buildSectionHeader('Campaign & UTM Attribution', Icons.insights_outlined),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAF5FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFF3E8FF)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.link_outlined,
                              size: 14,
                              color: Color(0xFF8B5CF6),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                lead['deepLinkUrl'].toString(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF6B21A8),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            IconButton(
                              icon: const Icon(Icons.copy_outlined, size: 14),
                              color: const Color(0xFF8B5CF6),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => _copyToClipboard(
                                lead['deepLinkUrl'].toString(),
                                'Deep link url',
                                context,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Builder(
                          builder: (context) {
                            final attributes = _getDeepLinkAttributes(
                              lead['deepLinkUrl'].toString(),
                            );
                            if (attributes.isEmpty) {
                              return Text(
                                'No parameters detected',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontStyle: FontStyle.italic,
                                  color: const Color(0xFF9CA3AF),
                                ),
                              );
                            }
                            return Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: attributes.entries.map((entry) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFFE9D5FF)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '${entry.key}: ',
                                        style: GoogleFonts.outfit(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF7C3AED),
                                        ),
                                      ),
                                      Text(
                                        entry.value,
                                        style: GoogleFonts.outfit(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF4B5563),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                _buildSectionHeader('Operations & Team Assignment', Icons.assignment_ind_outlined),
                const SizedBox(height: 10),
                if (!AuthService().isSales) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.indigo.withOpacity(0.08),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.badge_outlined,
                            size: 16,
                            color: Colors.indigo,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Assigned Representative',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF4B5563),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: salesAgents.any(
                                (agent) => agent['_id'] == lead['agentId'],
                              )
                                  ? lead['agentId']
                                  : null,
                              isExpanded: false,
                              isDense: true,
                              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                              hint: Text(
                                'Select Agent',
                                style: GoogleFonts.outfit(
                                  fontSize: 12.5,
                                  color: const Color(0xFF6B7280),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              onChanged: (String? newAgentId) {
                                onAssignAgent(newAgentId);
                              },
                              items: [
                                DropdownMenuItem<String>(
                                  value: null,
                                  child: Text(
                                    'Unassigned',
                                    style: GoogleFonts.outfit(
                                      fontSize: 12.5,
                                      color: const Color(0xFFEF4444),
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
                                        fontSize: 12.5,
                                        color: const Color(0xFF1F2937),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFEE2E2)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFEE2E2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.history_outlined,
                          size: 16,
                          color: Color(0xFFEF4444),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Last Activity Status',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF991B1B),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        lead['activity'] ?? 'No activity logged',
                        style: GoogleFonts.outfit(
                          fontSize: 12.5,
                          color: const Color(0xFF7F1D1D),
                          fontWeight: FontWeight.w700,
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

  Widget _buildActionButton({
    required BuildContext context,
    required dynamic icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        hoverColor: color.withOpacity(0.08),
        splashColor: color.withOpacity(0.12),
        child: Container(
          width: 92,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.15)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              icon is IconData
                  ? Icon(icon, size: 20, color: color)
                  : icon is FaIconData
                      ? FaIcon(icon, size: 20, color: color)
                      : const SizedBox.shrink(),
              const SizedBox(height: 6),
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationItem(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: const Color(0xFF6B7280)),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF6B7280),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: GoogleFonts.outfit(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1F2937),
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
  final VoidCallback onUpload;
  final bool isVertical;

  const _DealerKycDocumentsCard({
    required this.lead,
    required this.onViewDocument,
    required this.onUpload,
    this.isVertical = false,
  });

  Widget _buildMiniStat(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.outfit(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: color.withOpacity(0.8),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuidanceBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDCFCE7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Color(0xFF16A34A),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.verified_user,
                  size: 12,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'KYC VERIFICATION PROTOCOL',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF14532D),
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildProtocolStep(
            stepNumber: '01',
            title: 'Verify GST Certificate',
            desc:
                'Check if GST/Licence details match official government registration.',
            icon: Icons.fact_check_outlined,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(color: Color(0xFFDCFCE7), height: 1),
          ),
          _buildProtocolStep(
            stepNumber: '02',
            title: 'Validate Shop Image',
            desc:
                'Ensure the uploaded photo shows a clear, authentic storefront.',
            icon: Icons.storefront_outlined,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(color: Color(0xFFDCFCE7), height: 1),
          ),
          _buildProtocolStep(
            stepNumber: '03',
            title: 'Approve or Reject',
            desc:
                'Use the action buttons in the profile header cover to update status.',
            icon: Icons.rate_review_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildProtocolStep({
    required String stepNumber,
    required String title,
    required String desc,
    required IconData icon,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFFDCFCE7),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: const Color(0xFF16A34A)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Step $stepNumber',
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF16A34A),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '•',
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      color: const Color(0xFF86EFAC),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF14532D),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  height: 1.3,
                  color: const Color(0xFF166534),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final hasLicence =
        lead['licenceImage'] != null &&
        lead['licenceImage'].toString().isNotEmpty;
    final hasShopImage =
        lead['shopImage'] != null && lead['shopImage'].toString().isNotEmpty;
    final hasBoth = hasLicence && hasShopImage;

    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'KYC Documents',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF111827),
                ),
              ),
              if (!hasBoth)
                TextButton.icon(
                  onPressed: onUpload,
                  icon: const Icon(Icons.upload_rounded, size: 16),
                  label: const Text('Upload Documents'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
            ],
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
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 16),
          _buildGuidanceBanner(),
        ],
      ),
    );
  }
}

class _KycDocumentCard extends StatefulWidget {
  final String title;
  final String status;
  final String? subtext;
  final dynamic icon;
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

  Widget _buildMiniStat(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.outfit(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: color.withOpacity(0.8),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

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
                child: widget.icon is IconData
                    ? Icon(
                        widget.icon as IconData,
                        size: 16,
                        color: const Color(0xFFFA9527),
                      )
                    : widget.icon is FaIconData
                        ? FaIcon(
                            widget.icon,
                            size: 16,
                            color: const Color(0xFFFA9527),
                          )
                        : const SizedBox.shrink(),
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

class _UserEventsCard extends StatefulWidget {
  final String userIdentifier;
  final List<Map<String, dynamic>> events;
  final bool isLoading;

  const _UserEventsCard({
    super.key,
    required this.userIdentifier,
    required this.events,
    required this.isLoading,
  });

  @override
  State<_UserEventsCard> createState() => _UserEventsCardState();
}

class _UserEventsCardState extends State<_UserEventsCard> {
  int currentPage = 1;
  static const int pageSize = 5;
  final Set<int> _expandedIndices = {};
  String _selectedCategory = 'all';

  bool _matchesCategory(String eventType, String category) {
    if (category == 'all') return true;
    if (category == 'shopping') {
      return eventType == 'add_to_cart' ||
          eventType == 'checkout_started' ||
          eventType == 'apply_coupon' ||
          eventType == 'product_search';
    }
    if (category == 'payments') {
      return eventType == 'payment_initiated' ||
          eventType == 'payment_success' ||
          eventType == 'payment_failed';
    }
    if (category == 'system') {
      return eventType == 'login_success' ||
          eventType == 'app_error' ||
          eventType == 'profile_view';
    }
    return true;
  }

  Map<String, dynamic> _getEventVisuals(String eventType) {
    switch (eventType) {
      case 'login_success':
        return {
          'icon': Icons.login_rounded,
          'color': Colors.green,
          'label': 'Login Success',
        };
      case 'profile_view':
        return {
          'icon': Icons.visibility_rounded,
          'color': Colors.blue,
          'label': 'Profile View',
        };
      case 'product_search':
        return {
          'icon': Icons.search_rounded,
          'color': Colors.teal,
          'label': 'Product Search',
        };
      case 'add_to_cart':
        return {
          'icon': Icons.add_shopping_cart_rounded,
          'color': Colors.orange,
          'label': 'Add to Cart',
        };
      case 'checkout_started':
        return {
          'icon': Icons.shopping_bag_rounded,
          'color': Colors.purple,
          'label': 'Checkout Started',
        };
      case 'apply_coupon':
        return {
          'icon': Icons.local_offer_rounded,
          'color': Colors.indigo,
          'label': 'Apply Coupon',
        };
      case 'payment_initiated':
        return {
          'icon': Icons.payment_rounded,
          'color': Colors.cyan,
          'label': 'Payment Initiated',
        };
      case 'payment_failed':
        return {
          'icon': Icons.error_outline_rounded,
          'color': Colors.red,
          'label': 'Payment Failed',
        };
      case 'payment_success':
        return {
          'icon': Icons.check_circle_outline_rounded,
          'color': const Color(0xFF10B981),
          'label': 'Payment Success',
        };
      case 'coupon_created':
        return {
          'icon': Icons.add_circle_outline_rounded,
          'color': Colors.indigo,
          'label': 'Coupon Created',
        };
      case 'coupon_deleted':
        return {
          'icon': Icons.delete_outline_rounded,
          'color': Colors.redAccent,
          'label': 'Coupon Deleted',
        };
      case 'app_error':
        return {
          'icon': Icons.warning_amber_rounded,
          'color': Colors.deepOrange,
          'label': 'Application Error',
        };
      default:
        return {
          'icon': Icons.info_outline_rounded,
          'color': Colors.grey,
          'label': eventType.replaceAll('_', ' ').toUpperCase(),
        };
    }
  }

  String _formatTime(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays == 1) return 'Yesterday';
      return '${diff.inDays} days ago';
    } catch (_) {
      return dateStr;
    }
  }

  String _getHumanReadableDetails(
    String eventType,
    String originalDetails,
    Map<String, dynamic> payload,
  ) {
    switch (eventType) {
      case 'add_to_cart':
        final prod =
            payload['productName'] ?? payload['productId'] ?? 'an item';
        final qty = payload['quantity'] ?? 1;
        final price = payload['price'] != null
            ? ' at ₹${payload['price']}'
            : '';
        return 'Added "$prod" (Qty: $qty)$price to the shopping cart.';
      case 'checkout_started':
        final val = payload['cartValue'] ?? '0';
        final items = payload['itemCount'] ?? '0';
        return 'Initiated checkout for $items items worth ₹$val.';
      case 'apply_coupon':
        final code = payload['couponCode'] ?? 'coupon';
        final success = payload['success'] == false
            ? 'unsuccessfully'
            : 'successfully';
        return 'Attempted to apply discount coupon "$code" $success.';
      case 'payment_success':
        final amt = payload['amount'] ?? '0';
        final id = payload['orderId'] ?? '-';
        return 'Successfully completed payment of ₹$amt for Order ID: $id.';
      case 'payment_failed':
        final amt = payload['amount'] ?? '0';
        final reason = payload['reason'] ?? 'Transaction declined';
        return 'Payment attempt of ₹$amt failed. ($reason).';
      case 'payment_initiated':
        final amt = payload['amount'] ?? '0';
        return 'Initiated payment gateway session for ₹$amt.';
      case 'login_success':
        return 'Logged into the application.';
      case 'profile_view':
        return 'Profile was accessed for review.';
      case 'coupon_created':
        final code = payload['code'] ?? 'coupon';
        return 'Created a new promotional coupon: "$code".';
      case 'coupon_deleted':
        final code = payload['code'] ?? 'coupon';
        return 'Deleted promotional coupon: "$code".';
      case 'product_search':
        final query = payload['query'] ?? '';
        return 'Searched for products matching: "$query".';
      default:
        return originalDetails.isNotEmpty
            ? originalDetails
            : eventType.replaceAll('_', ' ').toUpperCase();
    }
  }

  Widget _buildFilterTabs() {
    final List<Map<String, String>> tabs = [
      {'id': 'all', 'label': 'All Activities'},
      {'id': 'shopping', 'label': 'Cart & Store'},
      {'id': 'payments', 'label': 'Payments'},
      {'id': 'system', 'label': 'System Logs'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: tabs.map((tab) {
          final isSelected = _selectedCategory == tab['id'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedCategory = tab['id']!;
                  currentPage = 1;
                });
              },
              borderRadius: BorderRadius.circular(20),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primaryColor.withOpacity(0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.primaryColor.withOpacity(0.3)
                        : const Color(0xFFE2E8F0),
                    width: 1.5,
                  ),
                ),
                child: Text(
                  tab['label']!,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected
                        ? AppTheme.primaryColor
                        : const Color(0xFF6B7280),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPayloadChips(Map<String, dynamic> payload) {
    final List<Widget> chips = [];
    payload.forEach((key, value) {
      if (value == null || value.toString().isEmpty) return;
      if (key == 'details' ||
          key == 'dealerId' ||
          key == 'dealerName' ||
          key == 'leadId' ||
          key == 'leadName') {
        return;
      }

      String displayKey = key;
      if (key == 'productId') displayKey = 'Product';
      if (key == 'productName') displayKey = 'Product';
      if (key == 'couponCode') displayKey = 'Coupon';
      if (key == 'cartValue') displayKey = 'Value';
      if (key == 'itemCount') displayKey = 'Items';
      if (key == 'amount') displayKey = 'Amount';

      String displayVal = value.toString();
      if (key == 'amount' || key == 'cartValue' || key == 'price') {
        displayVal = '₹$value';
      }

      chips.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '$displayKey: $displayVal',
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF475569),
            ),
          ),
        ),
      );
    });

    if (chips.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(spacing: 6, runSpacing: 6, children: chips),
    );
  }

  Widget _buildExpandedPayloadList(Map<String, dynamic> payload) {
    final List<Widget> rows = [];

    payload.forEach((key, value) {
      if (value == null || value.toString().isEmpty) return;
      if (key == 'details' ||
          key == 'dealerId' ||
          key == 'dealerName' ||
          key == 'leadId' ||
          key == 'leadName') {
        return;
      }

      String displayKey = key;
      if (key == 'productId') displayKey = 'Product ID';
      if (key == 'productName') displayKey = 'Product Name';
      if (key == 'couponCode') displayKey = 'Coupon Code';
      if (key == 'cartValue') displayKey = 'Cart Total Value';
      if (key == 'itemCount') displayKey = 'Number of Items';
      if (key == 'amount') displayKey = 'Transaction Amount';
      if (key == 'price') displayKey = 'Price per Unit';
      if (key == 'quantity') displayKey = 'Quantity Purchased';
      if (key == 'orderId') displayKey = 'Order ID';
      if (key == 'gateway') displayKey = 'Payment Gateway';
      if (key == 'reason') displayKey = 'Failure Reason';
      if (key == 'ip') displayKey = 'IP Address';
      if (key == 'userAgent') displayKey = 'Browser Signature';

      if (displayKey == key) {
        displayKey = key
            .replaceAll(RegExp(r'(?<!^)(?=[A-Z])|_'), ' ')
            .toUpperCase();
      } else {
        displayKey = displayKey.toUpperCase();
      }

      String displayVal = value.toString();
      if (key == 'amount' || key == 'cartValue' || key == 'price') {
        displayVal = '₹$value';
      }

      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  displayKey,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: Text(
                  displayVal,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1F2937),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });

    if (rows.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DETAILED ACTIVITY METRICS',
            style: GoogleFonts.outfit(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: AppTheme.primaryColor,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          ...rows,
        ],
      ),
    );
  }

  Widget? _buildFollowUpTip(String eventType, Map<String, dynamic> payload) {
    String? tip;
    Color tipColor = Colors.orange;
    IconData tipIcon = Icons.lightbulb_outline_rounded;

    if (eventType == 'payment_failed') {
      tip =
          'Payment Failed: Customer experienced a transaction drop. Call them to assist with alternative options.';
      tipColor = Colors.red;
      tipIcon = Icons.contact_phone_outlined;
    } else if (eventType == 'checkout_started') {
      tip =
          'Checkout Abandoned: Cart is active. Follow up via WhatsApp to offer a discount code and finalize sale.';
      tipColor = Colors.amber.shade800;
      tipIcon = Icons.chat_bubble_outline_rounded;
    } else if (eventType == 'add_to_cart') {
      tip =
          'Cart Updated: Items added but not checked out yet. Monitor active status.';
      tipColor = Colors.blue;
      tipIcon = Icons.shopping_cart_outlined;
    }

    if (tip == null) return null;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: tipColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tipColor.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Icon(tipIcon, size: 14, color: tipColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              tip,
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: tipColor.withOpacity(0.9),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    // Filter events by selected category
    final filteredEvents = widget.events.where((e) {
      final type = e['eventType']?.toString() ?? '';
      return _matchesCategory(type, _selectedCategory);
    }).toList();

    final totalEvents = filteredEvents.length;
    final int totalPages = (totalEvents / pageSize).ceil().clamp(1, 9999);

    if (currentPage > totalPages) {
      currentPage = totalPages;
    }

    final startIndex = (currentPage - 1) * pageSize;
    final endIndex = startIndex + pageSize;
    final currentPageEvents = filteredEvents.sublist(
      startIndex,
      endIndex > totalEvents ? totalEvents : endIndex,
    );

    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Live Activity & Events Feed',
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF111827),
                ),
              ),
              if (totalEvents > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$totalEvents logs',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _buildFilterTabs(),
          const SizedBox(height: 20),
          if (widget.isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: CircularProgressIndicator(color: AppTheme.primaryColor),
              ),
            )
          else if (filteredEvents.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.history_rounded,
                      size: 36,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No recent activity matching this filter.',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: const Color(0xFF6B7280),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: currentPageEvents.length,
              itemBuilder: (context, index) {
                final globalIndex = startIndex + index;
                final event = currentPageEvents[index];
                final eventType = event['eventType']?.toString() ?? '';
                final timestamp = event['timestamp']?.toString() ?? '';
                final details = event['details']?.toString() ?? '';
                final payload = event['payload'] is Map
                    ? Map<String, dynamic>.from(event['payload'])
                    : <String, dynamic>{};

                final visuals = _getEventVisuals(eventType);
                final bool isExpanded = _expandedIndices.contains(globalIndex);
                final bool isLast = index == currentPageEvents.length - 1;

                final followUpTip = _buildFollowUpTip(eventType, payload);

                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: (visuals['color'] as Color).withOpacity(
                                0.1,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              visuals['icon'] as IconData,
                              size: 16,
                              color: visuals['color'] as Color,
                            ),
                          ),
                          if (!isLast)
                            Expanded(
                              child: Container(
                                width: 2,
                                color: const Color(0xFFF1F5F9),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    visuals['label'] as String,
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: const Color(0xFF1F2937),
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      Text(
                                        _formatTime(timestamp),
                                        style: GoogleFonts.outfit(
                                          fontSize: 12,
                                          color: const Color(0xFF9CA3AF),
                                        ),
                                      ),
                                      if (payload.isNotEmpty) ...[
                                        const SizedBox(width: 8),
                                        IconButton(
                                          icon: Icon(
                                            isExpanded
                                                ? Icons
                                                      .keyboard_arrow_up_rounded
                                                : Icons
                                                      .keyboard_arrow_down_rounded,
                                            size: 18,
                                            color: Colors.grey,
                                          ),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onPressed: () {
                                            setState(() {
                                              if (isExpanded) {
                                                _expandedIndices.remove(
                                                  globalIndex,
                                                );
                                              } else {
                                                _expandedIndices.add(
                                                  globalIndex,
                                                );
                                              }
                                            });
                                          },
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _getHumanReadableDetails(
                                  eventType,
                                  details,
                                  payload,
                                ),
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  color: const Color(0xFF4B5563),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              _buildPayloadChips(payload),
                              if (followUpTip != null) followUpTip,
                              if (isExpanded && payload.isNotEmpty)
                                _buildExpandedPayloadList(payload),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            _buildPagination(totalEvents, startIndex, endIndex, totalPages),
          ],
        ],
      ),
    );
  }

  Widget _buildPagination(int total, int start, int end, int totalPages) {
    final showPrev = currentPage > 1;
    final showNext = currentPage < totalPages;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Showing ${start + 1} to ${end > total ? total : end} of $total logs',
          style: GoogleFonts.outfit(
            fontSize: 12,
            color: const Color(0xFF6B7280),
          ),
        ),
        Row(
          children: [
            ElevatedButton(
              onPressed: showPrev
                  ? () => setState(() {
                      currentPage--;
                    })
                  : null,
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: const Color(0xFFF1F5F9),
                foregroundColor: const Color(0xFF475569),
                disabledBackgroundColor: const Color(0xFFF8FAFC),
                disabledForegroundColor: const Color(0xFFCBD5E1),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: const Text('Previous'),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: showNext
                  ? () => setState(() {
                      currentPage++;
                    })
                  : null,
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: const Color(0xFFF1F5F9),
                foregroundColor: const Color(0xFF475569),
                disabledBackgroundColor: const Color(0xFFF8FAFC),
                disabledForegroundColor: const Color(0xFFCBD5E1),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: const Text('Next'),
            ),
          ],
        ),
      ],
    );
  }
}
