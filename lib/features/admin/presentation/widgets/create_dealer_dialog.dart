import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kd_pannel/app_theme.dart';
import 'package:kd_pannel/core/auth/auth_service.dart';
import 'package:kd_pannel/core/services/pincode_service.dart';

typedef OnSubmitDealer = void Function({
  required Map<String, dynamic> dealerData,
  Uint8List? licenceBytes,
  String? licenceFileName,
  Uint8List? shopBytes,
  String? shopFileName,
});

class CreateDealerDialog extends StatefulWidget {
  final List<Map<String, dynamic>> salesAgents;
  final OnSubmitDealer onSubmit;
  final bool isSubmitting;

  const CreateDealerDialog({
    super.key,
    required this.salesAgents,
    required this.onSubmit,
    this.isSubmitting = false,
  });

  static Future<void> show(
    BuildContext context, {
    required List<Map<String, dynamic>> salesAgents,
    required OnSubmitDealer onSubmit,
    bool isSubmitting = false,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: !isSubmitting,
      builder: (context) => CreateDealerDialog(
        salesAgents: salesAgents,
        onSubmit: onSubmit,
        isSubmitting: isSubmitting,
      ),
    );
  }

  @override
  State<CreateDealerDialog> createState() => _CreateDealerDialogState();
}

class _CreateDealerDialogState extends State<CreateDealerDialog> {
  final _formKey = GlobalKey<FormState>();

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _shopNameController = TextEditingController();
  final _gstController = TextEditingController();
  final _emailController = TextEditingController();
  final _villageAreaController = TextEditingController();
  final _addressLine2Controller = TextEditingController();
  final _cityController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _notesController = TextEditingController();

  String _selectedState = 'Madhya Pradesh';
  String? _selectedAgentId;
  bool _isFetchingLocation = false;
  String? _pincodeFeedback;

  // KYC Upload Files
  Uint8List? _licenceBytes;
  String? _licenceFileName;
  Uint8List? _shopBytes;
  String? _shopFileName;

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
    _gstController.dispose();
    _emailController.dispose();
    _villageAreaController.dispose();
    _addressLine2Controller.dispose();
    _cityController.dispose();
    _pincodeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickLicenceFile() async {
    try {
      final res = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
        withData: true,
      );
      if (res != null && res.files.isNotEmpty) {
        final f = res.files.first;
        if (f.bytes != null) {
          setState(() {
            _licenceBytes = f.bytes;
            _licenceFileName = f.name;
          });
        }
      }
    } catch (e) {
      debugPrint('Licence pick error: $e');
    }
  }

  Future<void> _pickShopFile() async {
    try {
      final res = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
        withData: true,
      );
      if (res != null && res.files.isNotEmpty) {
        final f = res.files.first;
        if (f.bytes != null) {
          setState(() {
            _shopBytes = f.bytes;
            _shopFileName = f.name;
          });
        }
      }
    } catch (e) {
      debugPrint('Shop photo pick error: $e');
    }
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
    final String gst = _gstController.text.trim();
    final String email = _emailController.text.trim();
    final String village = _villageAreaController.text.trim();
    final String address2 = _addressLine2Controller.text.trim();
    final String city = _cityController.text.trim();
    final String pin = _pincodeController.text.trim();
    final String notes = _notesController.text.trim();

    final Map<String, dynamic> payload = {
      'phoneNumber': cleanPhone,
      'firstName': firstName,
      'lastName': lastName,
      'shopName': shopName,
      if (gst.isNotEmpty) 'gstNumber': gst,
      if (email.isNotEmpty) 'email': email,
      'address': {
        'villageArea': village,
        'addressLine2': address2,
        'address2': address2,
        'cityTehsil': city,
        'state': _selectedState,
        'pincode': pin,
      },
      if (_selectedAgentId != null && _selectedAgentId!.isNotEmpty)
        'assignedAgent': _selectedAgentId,
      if (notes.isNotEmpty) 'notes': notes,
    };

    widget.onSubmit(
      dealerData: payload,
      licenceBytes: _licenceBytes,
      licenceFileName: _licenceFileName,
      shopBytes: _shopBytes,
      shopFileName: _shopFileName,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;
    final isSales = AuthService().isSales;

    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
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
                          Icons.person_add_alt_1_rounded,
                          color: AppTheme.primaryColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Create New Dealer',
                            style: GoogleFonts.outfit(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          Text(
                            'Directly onboard a verified dealer into the system',
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
              const Divider(height: 1, color: AppTheme.lightBorderColor),
              const SizedBox(height: 16),

              // Form Body
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section 1: Basic Information
                      _buildSectionTitle('1. Dealer & Shop Details', Icons.store_rounded),
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
                          label: 'Shop / Business Name *',
                          controller: _shopNameController,
                          hint: 'e.g. Kisan Agro Mart',
                          validator: (val) => val == null || val.trim().isEmpty ? 'Shop name required' : null,
                        ),
                        const SizedBox(height: 12),
                        _buildInputField(
                          label: 'GST Number (Optional)',
                          controller: _gstController,
                          hint: '23AAAAA0000A1Z5',
                          textCapitalization: TextCapitalization.characters,
                        ),
                      ] else ...[
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: _buildInputField(
                                label: 'Shop / Business Name *',
                                controller: _shopNameController,
                                hint: 'e.g. Kisan Agro Mart',
                                validator: (val) => val == null || val.trim().isEmpty ? 'Shop name required' : null,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              flex: 2,
                              child: _buildInputField(
                                label: 'GST Number (Optional)',
                                controller: _gstController,
                                hint: '23AAAAA0000A1Z5',
                                textCapitalization: TextCapitalization.characters,
                              ),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 20),
                      // Section 2: Address with Pincode Auto-Lookup
                      _buildSectionTitle('2. Location & Address', Icons.location_on_rounded),
                      const SizedBox(height: 12),

                      // Pincode Input (with auto lookup)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildInputField(
                              label: 'Pincode (6 digits) *',
                              controller: _pincodeController,
                              hint: 'e.g. 452001',
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(6),
                              ],
                              onChanged: _handlePincodeChange,
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) return 'Pincode required';
                                if (val.trim().length != 6) return 'Must be 6 digits';
                                return null;
                              },
                              suffixWidget: _isFetchingLocation
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppTheme.primaryColor,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                        ],
                      ),

                      if (_pincodeFeedback != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              _pincodeFeedback!.startsWith('✓')
                                  ? Icons.check_circle_rounded
                                  : Icons.info_outline_rounded,
                              size: 14,
                              color: _pincodeFeedback!.startsWith('✓')
                                  ? AppTheme.success
                                  : AppTheme.warning,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _pincodeFeedback!,
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _pincodeFeedback!.startsWith('✓')
                                      ? AppTheme.success
                                      : AppTheme.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 12),

                      _buildInputField(
                        label: 'Village / Area / Street *',
                        controller: _villageAreaController,
                        hint: 'Shop No. 4, Mandi Road',
                        validator: (val) => val == null || val.trim().isEmpty ? 'Address required' : null,
                      ),
                      const SizedBox(height: 12),

                      if (isMobile) ...[
                        _buildInputField(
                          label: 'City / Tehsil (Auto-filled) *',
                          controller: _cityController,
                          hint: 'e.g. Indore',
                          validator: (val) => val == null || val.trim().isEmpty ? 'City required' : null,
                        ),
                        const SizedBox(height: 12),
                        _buildStateDropdown(),
                      ] else ...[
                        Row(
                          children: [
                            Expanded(
                              child: _buildInputField(
                                label: 'City / Tehsil (Auto-filled) *',
                                controller: _cityController,
                                hint: 'e.g. Indore',
                                validator: (val) => val == null || val.trim().isEmpty ? 'City required' : null,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(child: _buildStateDropdown()),
                          ],
                        ),
                      ],

                      const SizedBox(height: 20),
                      // Section 3: KYC Documents Upload
                      _buildSectionTitle('3. KYC Documents (Optional)', Icons.verified_user_rounded),
                      const SizedBox(height: 12),

                      if (isMobile) ...[
                        _buildDocumentUploadCard(
                          title: 'Fertilizer/Seed License',
                          subtitle: 'Image or PDF (Max 10MB)',
                          fileName: _licenceFileName,
                          icon: Icons.description_rounded,
                          onPick: _pickLicenceFile,
                          onRemove: () => setState(() {
                            _licenceBytes = null;
                            _licenceFileName = null;
                          }),
                        ),
                        const SizedBox(height: 12),
                        _buildDocumentUploadCard(
                          title: 'Shop Front Photo',
                          subtitle: 'Shop signboard / front photo',
                          fileName: _shopFileName,
                          icon: Icons.storefront_rounded,
                          onPick: _pickShopFile,
                          onRemove: () => setState(() {
                            _shopBytes = null;
                            _shopFileName = null;
                          }),
                        ),
                      ] else ...[
                        Row(
                          children: [
                            Expanded(
                              child: _buildDocumentUploadCard(
                                title: 'Fertilizer/Seed License',
                                subtitle: 'Image or PDF (Max 10MB)',
                                fileName: _licenceFileName,
                                icon: Icons.description_rounded,
                                onPick: _pickLicenceFile,
                                onRemove: () => setState(() {
                                  _licenceBytes = null;
                                  _licenceFileName = null;
                                }),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: _buildDocumentUploadCard(
                                title: 'Shop Front Photo',
                                subtitle: 'Shop signboard / front photo',
                                fileName: _shopFileName,
                                icon: Icons.storefront_rounded,
                                onPick: _pickShopFile,
                                onRemove: () => setState(() {
                                  _shopBytes = null;
                                  _shopFileName = null;
                                }),
                              ),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 20),
                      // Section 4: Assignment & Notes
                      _buildSectionTitle('4. Sales Agent & Notes', Icons.assignment_ind_rounded),
                      const SizedBox(height: 12),

                      if (!isSales) ...[
                        _buildAgentDropdown(),
                        const SizedBox(height: 12),
                      ],

                      _buildInputField(
                        label: 'Initial Notes (Optional)',
                        controller: _notesController,
                        hint: 'e.g. Met at agri-expo, interested in fertilizer distribution',
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
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: widget.isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check_circle_outline_rounded, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'Create Dealer',
                                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
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
        Icon(icon, size: 16, color: AppTheme.primaryColor),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentUploadCard({
    required String title,
    required String subtitle,
    required String? fileName,
    required IconData icon,
    required VoidCallback onPick,
    required VoidCallback onRemove,
  }) {
    final hasFile = fileName != null && fileName.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: hasFile ? AppTheme.primaryColor.withValues(alpha: 0.05) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasFile ? AppTheme.primaryColor.withValues(alpha: 0.4) : AppTheme.borderColor,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: hasFile ? AppTheme.primaryColor.withValues(alpha: 0.15) : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: hasFile ? AppTheme.primaryColor.withValues(alpha: 0.3) : AppTheme.borderColor),
            ),
            child: Icon(
              hasFile ? Icons.check_circle_rounded : icon,
              color: hasFile ? AppTheme.primaryColor : AppTheme.textSecondary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
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
                Text(
                  hasFile ? fileName : subtitle,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: hasFile ? FontWeight.w600 : FontWeight.normal,
                    color: hasFile ? AppTheme.primaryColor : AppTheme.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (hasFile)
            IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.close_rounded, size: 18, color: AppTheme.error),
              tooltip: 'Remove',
            )
          else
            OutlinedButton.icon(
              onPressed: onPick,
              icon: const Icon(Icons.upload_file_rounded, size: 14),
              label: const Text('Browse'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                textStyle: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    String? hint,
    String? prefixText,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
    Widget? suffixWidget,
    TextCapitalization textCapitalization = TextCapitalization.none,
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
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          validator: validator,
          onChanged: onChanged,
          textCapitalization: textCapitalization,
          maxLines: maxLines,
          style: GoogleFonts.outfit(fontSize: 14, color: AppTheme.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.outfit(color: const Color(0xFF9CA3AF), fontSize: 14),
            prefixText: prefixText,
            prefixStyle: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
            suffixIcon: suffixWidget != null
                ? Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Center(widthFactor: 1, child: suffixWidget),
                  )
                : null,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppTheme.borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppTheme.borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppTheme.error),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildStateDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'State (Auto-selected) *',
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _indianStates.contains(_selectedState) ? _selectedState : _indianStates.first,
              isExpanded: true,
              icon: const Icon(Icons.arrow_drop_down_rounded, color: AppTheme.textSecondary),
              style: GoogleFonts.outfit(fontSize: 14, color: AppTheme.textPrimary),
              onChanged: (val) {
                if (val != null) setState(() => _selectedState = val);
              },
              items: _indianStates.map((st) {
                return DropdownMenuItem<String>(
                  value: st,
                  child: Text(st, overflow: TextOverflow.ellipsis),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAgentDropdown() {
    final activeAgents = widget.salesAgents.where((a) {
      final name = '${a['firstName'] ?? ''} ${a['lastName'] ?? ''}'.trim();
      return name.isNotEmpty;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Assign Sales Agent (Optional)',
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              value: _selectedAgentId,
              isExpanded: true,
              icon: const Icon(Icons.arrow_drop_down_rounded, color: AppTheme.textSecondary),
              style: GoogleFonts.outfit(fontSize: 14, color: AppTheme.textPrimary),
              hint: Text(
                'Unassigned (Leave unassigned)',
                style: GoogleFonts.outfit(color: const Color(0xFF9CA3AF), fontSize: 14),
              ),
              onChanged: (val) {
                setState(() => _selectedAgentId = val);
              },
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Unassigned'),
                ),
                ...activeAgents.map((agent) {
                  final String agentId = (agent['_id'] ?? '').toString();
                  final String name = '${agent['firstName'] ?? ''} ${agent['lastName'] ?? ''}'.trim();
                  return DropdownMenuItem<String?>(
                    value: agentId,
                    child: Text(name),
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
