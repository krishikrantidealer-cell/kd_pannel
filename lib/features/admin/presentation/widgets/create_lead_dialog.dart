import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kd_pannel/app_theme.dart';
import 'package:kd_pannel/core/auth/auth_service.dart';
import 'package:kd_pannel/core/services/pincode_service.dart';

typedef OnSubmitLead = void Function(Map<String, dynamic> leadData);

class CreateLeadDialog extends StatefulWidget {
  final List<Map<String, dynamic>> salesAgents;
  final OnSubmitLead onSubmit;
  final bool isSubmitting;

  const CreateLeadDialog({
    super.key,
    required this.salesAgents,
    required this.onSubmit,
    this.isSubmitting = false,
  });

  static Future<void> show(
    BuildContext context, {
    required List<Map<String, dynamic>> salesAgents,
    required OnSubmitLead onSubmit,
    bool isSubmitting = false,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: !isSubmitting,
      builder: (context) => CreateLeadDialog(
        salesAgents: salesAgents,
        onSubmit: onSubmit,
        isSubmitting: isSubmitting,
      ),
    );
  }

  @override
  State<CreateLeadDialog> createState() => _CreateLeadDialogState();
}

class _CreateLeadDialogState extends State<CreateLeadDialog> {
  final _formKey = GlobalKey<FormState>();

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _shopNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _villageAreaController = TextEditingController();
  final _addressLine2Controller = TextEditingController();
  final _cityController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _notesController = TextEditingController();

  String _selectedState = 'Madhya Pradesh';
  String _selectedStatus = 'prospect';
  String? _selectedAgentId;
  bool _isFetchingLocation = false;
  String? _pincodeFeedback;

  static const List<String> _leadStatuses = [
    'prospect',
    'contacted',
    'interested',
    'follow_up',
    'hot',
  ];

  static const List<String> _indianStates = [
    'Andhra Pradesh',
    'Arunachal Pradesh',
    'Assam',
    'Bihar',
    'Chhattisgarh',
    'Goa',
    'Gujarat',
    'Haryana',
    'Himachal Pradesh',
    'Jharkhand',
    'Karnataka',
    'Kerala',
    'Madhya Pradesh',
    'Maharashtra',
    'Manipur',
    'Meghalaya',
    'Mizoram',
    'Nagaland',
    'Odisha',
    'Punjab',
    'Rajasthan',
    'Sikkim',
    'Tamil Nadu',
    'Telangana',
    'Tripura',
    'Uttar Pradesh',
    'Uttarakhand',
    'West Bengal',
    'Andaman and Nicobar Islands',
    'Chandigarh',
    'Dadra and Nagar Haveli and Daman and Diu',
    'Delhi',
    'Jammu and Kashmir',
    'Ladakh',
    'Lakshadweep',
    'Puducherry',
  ];

  @override
  void initState() {
    super.initState();
    final auth = AuthService();
    // If sales agent is creating the lead, automatically assign to themselves
    if (auth.isSales) {
      _selectedAgentId = auth.currentUserId;
    }
    PincodeService().init();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _shopNameController.dispose();
    _emailController.dispose();
    _villageAreaController.dispose();
    _addressLine2Controller.dispose();
    _cityController.dispose();
    _pincodeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _handlePincodeChange(String val) async {
    final cleanPin = val.trim().replaceAll(RegExp(r'[^\d]'), '');
    if (cleanPin.length != 6) {
      if (_pincodeFeedback != null) {
        setState(() {
          _pincodeFeedback = null;
        });
      }
      return;
    }

    setState(() {
      _isFetchingLocation = true;
      _pincodeFeedback = null;
    });

    try {
      await PincodeService().init();
      final resolved = await PincodeService().resolve(cleanPin);
      if (!mounted) return;

      if (resolved) {
        final data = PincodeService().lookup(cleanPin);
        if (data != null) {
          final district = data['district'] ?? '';
          final rawState = data['state'] ?? '';

          final matchedState = _indianStates.firstWhere(
            (s) =>
                s.toLowerCase() == rawState.toLowerCase() ||
                s.toLowerCase().contains(rawState.toLowerCase()) ||
                rawState.toLowerCase().contains(s.toLowerCase()),
            orElse: () => _selectedState,
          );

          setState(() {
            if (district.isNotEmpty) {
              _cityController.text = district;
            }
            if (matchedState.isNotEmpty) {
              _selectedState = matchedState;
            }
            _isFetchingLocation = false;
            _pincodeFeedback = '✓ Location auto-filled: $district, $matchedState';
          });
          return;
        }
      }
      setState(() {
        _isFetchingLocation = false;
        _pincodeFeedback = 'Pincode not found in directory. Please enter manually.';
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isFetchingLocation = false;
        });
      }
    }
  }

  void _handleSubmit() {
    if (!_formKey.currentState!.validate()) return;

    final String cleanPhone = _phoneController.text.trim().replaceAll(RegExp(r'[^\d]'), '');
    final String firstName = _firstNameController.text.trim();
    final String lastName = _lastNameController.text.trim();
    final String shopName = _shopNameController.text.trim();
    final String email = _emailController.text.trim();
    final String village = _villageAreaController.text.trim();
    final String address2 = _addressLine2Controller.text.trim();
    final String city = _cityController.text.trim();
    final String pin = _pincodeController.text.trim();
    final String notes = _notesController.text.trim();

    final auth = AuthService();
    final String? agentToAssign = auth.isSales ? auth.currentUserId : _selectedAgentId;

    final Map<String, dynamic> payload = {
      'phoneNumber': cleanPhone,
      'firstName': firstName,
      'lastName': lastName,
      if (shopName.isNotEmpty) 'shopName': shopName,
      if (email.isNotEmpty) 'email': email,
      'status': _selectedStatus,
      'address': {
        'villageArea': village,
        'addressLine2': address2,
        'address2': address2,
        'cityTehsil': city,
        'state': _selectedState,
        'pincode': pin,
      },
      if (agentToAssign != null && agentToAssign.isNotEmpty)
        'assignedAgent': agentToAssign,
      if (notes.isNotEmpty) 'notes': notes,
    };

    widget.onSubmit(payload);
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;
    final auth = AuthService();
    final isSales = auth.isSales;

    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 40,
        vertical: 24,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: isMobile ? double.infinity : 680,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.person_add_rounded,
                          color: AppTheme.primaryColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Create New Lead',
                            style: GoogleFonts.outfit(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          Text(
                            isSales
                                ? 'Add a new prospective lead (auto-assigned to you)'
                                : 'Add a new prospective lead into the system',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: AppTheme.textSecondary),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFF3F4F6),
                      padding: const EdgeInsets.all(8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Form Scroll Area
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section 1: Basic Information
                      _buildSectionTitle('1. Basic Contact Information', Icons.badge_outlined),
                      const SizedBox(height: 12),

                      if (isMobile) ...[
                        _buildInputField(
                          label: 'First Name *',
                          controller: _firstNameController,
                          hint: 'e.g. Ramesh',
                          validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),
                        _buildInputField(
                          label: 'Last Name',
                          controller: _lastNameController,
                          hint: 'e.g. Patel',
                        ),
                        const SizedBox(height: 12),
                        _buildInputField(
                          label: 'Phone Number (10 digits) *',
                          controller: _phoneController,
                          hint: '9876543210',
                          prefixText: '+91 ',
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10),
                          ],
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return 'Phone number required';
                            if (val.trim().length != 10) return 'Must be 10 digits';
                            return null;
                          },
                        ),
                      ] else ...[
                        Row(
                          children: [
                            Expanded(
                              child: _buildInputField(
                                label: 'First Name *',
                                controller: _firstNameController,
                                hint: 'e.g. Ramesh',
                                validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: _buildInputField(
                                label: 'Last Name',
                                controller: _lastNameController,
                                hint: 'e.g. Patel',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildInputField(
                          label: 'Phone Number (10 digits) *',
                          controller: _phoneController,
                          hint: '9876543210',
                          prefixText: '+91 ',
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10),
                          ],
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return 'Phone number required';
                            if (val.trim().length != 10) return 'Must be 10 digits';
                            return null;
                          },
                        ),
                      ],

                      const SizedBox(height: 12),

                      if (isMobile) ...[
                        _buildInputField(
                          label: 'Shop / Farm / Business Name (Optional)',
                          controller: _shopNameController,
                          hint: 'e.g. Kisan Agro Mart or Patel Farm',
                        ),
                        const SizedBox(height: 12),
                        _buildInputField(
                          label: 'Email (Optional)',
                          controller: _emailController,
                          hint: 'e.g. ramesh@example.com',
                          keyboardType: TextInputType.emailAddress,
                        ),
                      ] else ...[
                        Row(
                          children: [
                            Expanded(
                              child: _buildInputField(
                                label: 'Shop / Farm / Business Name (Optional)',
                                controller: _shopNameController,
                                hint: 'e.g. Kisan Agro Mart',
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: _buildInputField(
                                label: 'Email (Optional)',
                                controller: _emailController,
                                hint: 'e.g. ramesh@example.com',
                                keyboardType: TextInputType.emailAddress,
                              ),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 20),
                      // Section 2: Address Information
                      _buildSectionTitle('2. Location & Address', Icons.location_on_outlined),
                      const SizedBox(height: 12),

                      // Pincode with Auto-detection
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: isMobile ? 1 : 2,
                            child: _buildInputField(
                              label: 'Pincode (6 digits)',
                              controller: _pincodeController,
                              hint: 'e.g. 452001',
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(6),
                              ],
                              onChanged: _handlePincodeChange,
                              suffixWidget: _isFetchingLocation
                                  ? const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppTheme.primaryColor,
                                        ),
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            flex: isMobile ? 1 : 3,
                            child: _buildInputField(
                              label: 'City / Tehsil',
                              controller: _cityController,
                              hint: 'e.g. Indore',
                            ),
                          ),
                        ],
                      ),

                      if (_pincodeFeedback != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          _pincodeFeedback!,
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: _pincodeFeedback!.startsWith('✓')
                                ? AppTheme.success
                                : AppTheme.textSecondary,
                          ),
                        ),
                      ],

                      const SizedBox(height: 12),

                      // State Dropdown
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'State',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppTheme.lightBorderColor),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                isExpanded: true,
                                value: _selectedState,
                                items: _indianStates.map((s) {
                                  return DropdownMenuItem(
                                    value: s,
                                    child: Text(
                                      s,
                                      style: GoogleFonts.outfit(fontSize: 14, color: AppTheme.textPrimary),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _selectedState = val);
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      _buildInputField(
                        label: 'Village / Area / Landmark (Optional)',
                        controller: _villageAreaController,
                        hint: 'e.g. Near Bus Stand',
                      ),

                      const SizedBox(height: 20),
                      // Section 3: Status & Assignment
                      _buildSectionTitle('3. Status & Assignment', Icons.assignment_ind_outlined),
                      const SizedBox(height: 12),

                      // Lead Stage / Status
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Lead Stage / Status',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppTheme.lightBorderColor),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                isExpanded: true,
                                value: _selectedStatus,
                                items: _leadStatuses.map((s) {
                                  return DropdownMenuItem(
                                    value: s,
                                    child: Text(
                                      s.toUpperCase().replaceAll('_', ' '),
                                      style: GoogleFonts.outfit(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _selectedStatus = val);
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      if (isSales) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.lock_person_rounded, size: 18, color: AppTheme.primaryColor),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'This lead will automatically be assigned to you (${auth.currentUserName ?? "Your Account"}).',
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    color: AppTheme.primaryColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ] else ...[
                        _buildAgentDropdown(),
                        const SizedBox(height: 12),
                      ],

                      _buildInputField(
                        label: 'Initial Notes / Conversation (Optional)',
                        controller: _notesController,
                        hint: 'e.g. Inquired about wholesale bio-fertilizer pricing, will call back on Monday',
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
              const Divider(height: 1, color: AppTheme.lightBorderColor),
              const SizedBox(height: 16),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: widget.isSubmitting ? null : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      side: const BorderSide(color: AppTheme.lightBorderColor),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: widget.isSubmitting ? null : _handleSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: widget.isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check_rounded, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'Create Lead',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.primaryColor),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required String hint,
    String? prefixText,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
    Widget? suffixWidget,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          validator: validator,
          onChanged: onChanged,
          maxLines: maxLines,
          style: GoogleFonts.outfit(fontSize: 14, color: AppTheme.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.outfit(fontSize: 14, color: AppTheme.textSecondary.withValues(alpha: 0.6)),
            prefixText: prefixText,
            prefixStyle: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
            suffixIcon: suffixWidget,
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppTheme.lightBorderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppTheme.lightBorderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAgentDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Assign Sales Agent (Optional)',
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.lightBorderColor),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              isExpanded: true,
              value: _selectedAgentId,
              hint: Text(
                'Leave Unassigned',
                style: GoogleFonts.outfit(fontSize: 14, color: AppTheme.textSecondary),
              ),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text(
                    '-- Leave Unassigned --',
                    style: GoogleFonts.outfit(fontSize: 14, color: AppTheme.textSecondary),
                  ),
                ),
                ...widget.salesAgents.map((sa) {
                  final name = '${sa['firstName'] ?? ''} ${sa['lastName'] ?? ''}'.trim();
                  final phone = sa['phoneNumber'] ?? '';
                  final displayName = name.isNotEmpty ? '$name ($phone)' : phone;
                  final agentId = (sa['_id'] ?? sa['id']).toString();
                  return DropdownMenuItem<String?>(
                    value: agentId,
                    child: Text(
                      displayName,
                      style: GoogleFonts.outfit(fontSize: 14, color: AppTheme.textPrimary),
                    ),
                  );
                }),
              ],
              onChanged: (val) {
                setState(() => _selectedAgentId = val);
              },
            ),
          ),
        ),
      ],
    );
  }
}
