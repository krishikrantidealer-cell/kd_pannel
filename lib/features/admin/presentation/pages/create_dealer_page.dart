import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:kd_pannel/app_theme.dart';
import 'package:kd_pannel/core/auth/auth_service.dart';
import 'package:kd_pannel/core/network/api_client.dart';
import 'package:kd_pannel/core/services/pincode_service.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/dealers_bloc.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/dealers_event.dart';

class CreateDealerPage extends StatefulWidget {
  const CreateDealerPage({super.key});

  @override
  State<CreateDealerPage> createState() => _CreateDealerPageState();
}

class _CreateDealerPageState extends State<CreateDealerPage> {
  final _formKey = GlobalKey<FormState>();

  // Text Controllers
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

  // State & Agent variables
  String _selectedState = 'Madhya Pradesh';
  String? _selectedAgentId;
  List<Map<String, dynamic>> _salesAgents = [];
  bool _isLoadingAgents = false;
  bool _isSubmitting = false;

  // Pincode lookup state
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
    PincodeService().init();

    final auth = AuthService();
    if (auth.isSales) {
      _selectedAgentId = auth.currentUserId;
    } else {
      _loadSalesAgents();
    }
  }

  Future<void> _loadSalesAgents() async {
    setState(() => _isLoadingAgents = true);
    try {
      final res = await ApiClient().get('/users?role=sales');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['users'] != null) {
          setState(() {
            _salesAgents = List<Map<String, dynamic>>.from(data['users']);
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading sales agents: $e');
    } finally {
      if (mounted) setState(() => _isLoadingAgents = false);
    }
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

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

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

    final Map<String, dynamic> dealerData = {
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

    try {
      http.Response res;

      if (_licenceBytes != null || _shopBytes != null) {
        final fields = <String, String>{};
        dealerData.forEach((k, v) {
          if (v is Map) {
            fields[k] = jsonEncode(v);
          } else if (v != null) {
            fields[k] = v.toString();
          }
        });

        res = await ApiClient().multipartRequest(
          method: 'POST',
          endpoint: '/users/dealer',
          fields: fields,
          filesBuilder: () {
            final files = <http.MultipartFile>[];
            if (_licenceBytes != null && _licenceFileName != null) {
              files.add(
                http.MultipartFile.fromBytes(
                  'licenceImage',
                  _licenceBytes!,
                  filename: _licenceFileName!,
                ),
              );
            }
            if (_shopBytes != null && _shopFileName != null) {
              files.add(
                http.MultipartFile.fromBytes(
                  'shopImage',
                  _shopBytes!,
                  filename: _shopFileName!,
                ),
              );
            }
            return files;
          },
        );
      } else {
        res = await ApiClient().post('/users/dealer', dealerData);
      }

      final data = jsonDecode(res.body);

      if (!mounted) return;

      if (res.statusCode == 200 || res.statusCode == 201) {
        if (data['success'] == true) {
          try {
            context.read<DealersBloc>().add(const FetchDealersDataEvent(forceRefresh: true));
          } catch (_) {}

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white),
                  const SizedBox(width: 10),
                  Text(data['message'] ?? 'Dealer created successfully!'),
                ],
              ),
              backgroundColor: AppTheme.success,
              behavior: SnackBarBehavior.floating,
            ),
          );

          Navigator.of(context).pop(true);
        } else {
          throw Exception(data['message'] ?? 'Failed to create dealer');
        }
      } else {
        throw Exception(data['message'] ?? 'Failed to create dealer: ${res.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(child: Text(e.toString().replaceAll('Exception: ', ''))),
              ],
            ),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTwoColumn = screenWidth >= 1100;
    final isMobile = screenWidth < 700;
    final auth = AuthService();
    final isSales = auth.isSales;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: Colors.black12,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary),
          tooltip: 'Back to Dealers',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Create New Dealer',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            Text(
              isSales
                  ? 'Onboard a verified dealer assigned directly to you'
                  : 'Onboard and register a verified dealer in the system',
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          if (isSales)
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.person_rounded, size: 14, color: AppTheme.primaryColor),
                  const SizedBox(width: 6),
                  Text(
                    'Creator: You (Sales)',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 16 : 32,
            vertical: 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isTwoColumn)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Column (Profile & Location)
                    Expanded(
                      flex: 6,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildProfileCard(isMobile: false),
                          const SizedBox(height: 24),
                          _buildLocationCard(isMobile: false),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    // Right Column (KYC & Notes & Actions)
                    Expanded(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildKycCard(isMobile: false),
                          const SizedBox(height: 24),
                          _buildAssignmentCard(isSales: isSales),
                          const SizedBox(height: 24),
                          _buildActionCard(),
                        ],
                      ),
                    ),
                  ],
                )
              else ...[
                _buildProfileCard(isMobile: isMobile),
                const SizedBox(height: 20),
                _buildLocationCard(isMobile: isMobile),
                const SizedBox(height: 20),
                _buildKycCard(isMobile: isMobile),
                const SizedBox(height: 20),
                _buildAssignmentCard(isSales: isSales),
                const SizedBox(height: 24),
                _buildActionCard(),
              ],
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard({required bool isMobile}) {
    return _buildCard(
      title: '1. Dealer & Business Profile',
      subtitle: 'Enter dealer contact name, mobile number, and firm details',
      icon: Icons.store_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isMobile) ...[
            _buildInputField(
              label: 'First Name *',
              controller: _firstNameController,
              hint: 'e.g. Ramesh',
              validator: (val) => val == null || val.trim().isEmpty ? 'First name is required' : null,
            ),
            const SizedBox(height: 16),
            _buildInputField(
              label: 'Last Name',
              controller: _lastNameController,
              hint: 'e.g. Patel',
            ),
            const SizedBox(height: 16),
            _buildInputField(
              label: 'Mobile / Phone Number (10 digits) *',
              controller: _phoneController,
              hint: '9876543210',
              prefixText: '+91 ',
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              validator: (val) {
                if (val == null || val.trim().isEmpty) return 'Phone number is required';
                if (val.trim().length != 10) return 'Must be exactly 10 digits';
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
                    validator: (val) => val == null || val.trim().isEmpty ? 'First name is required' : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildInputField(
                    label: 'Last Name',
                    controller: _lastNameController,
                    hint: 'e.g. Patel',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildInputField(
                    label: 'Mobile / Phone Number (10 digits) *',
                    controller: _phoneController,
                    hint: '9876543210',
                    prefixText: '+91 ',
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Phone number is required';
                      if (val.trim().length != 10) return 'Must be exactly 10 digits';
                      return null;
                    },
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          if (isMobile) ...[
            _buildInputField(
              label: 'Shop / Firm / Business Name *',
              controller: _shopNameController,
              hint: 'e.g. Kisan Agro Mart & Krishi Kendra',
              validator: (val) => val == null || val.trim().isEmpty ? 'Shop name is required' : null,
            ),
            const SizedBox(height: 16),
            _buildInputField(
              label: 'GST Number (Optional)',
              controller: _gstController,
              hint: '23AAAAA0000A1Z5',
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 16),
            _buildInputField(
              label: 'Email Address (Optional)',
              controller: _emailController,
              hint: 'dealer@example.com',
              keyboardType: TextInputType.emailAddress,
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: _buildInputField(
                    label: 'Shop / Firm / Business Name *',
                    controller: _shopNameController,
                    hint: 'e.g. Kisan Agro Mart & Krishi Kendra',
                    validator: (val) => val == null || val.trim().isEmpty ? 'Shop name is required' : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: _buildInputField(
                    label: 'GST Number (Optional)',
                    controller: _gstController,
                    hint: '23AAAAA0000A1Z5',
                    textCapitalization: TextCapitalization.characters,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: _buildInputField(
                    label: 'Email Address (Optional)',
                    controller: _emailController,
                    hint: 'dealer@example.com',
                    keyboardType: TextInputType.emailAddress,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLocationCard({required bool isMobile}) {
    return _buildCard(
      title: '2. Location & Address',
      subtitle: 'Enter 6-digit Pincode to auto-fill City and State',
      icon: Icons.location_on_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: isMobile ? double.infinity : 280,
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
                    if (val == null || val.trim().isEmpty) return 'Pincode is required';
                    if (val.trim().length != 6) return 'Must be exactly 6 digits';
                    return null;
                  },
                  suffixWidget: _isFetchingLocation
                      ? const SizedBox(
                          width: 18,
                          height: 18,
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
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  _pincodeFeedback!.startsWith('✓') ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                  size: 16,
                  color: _pincodeFeedback!.startsWith('✓') ? AppTheme.success : AppTheme.warning,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _pincodeFeedback!,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _pincodeFeedback!.startsWith('✓') ? AppTheme.success : AppTheme.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          _buildInputField(
            label: 'Village / Area / Street / Market *',
            controller: _villageAreaController,
            hint: 'Shop No. 12, Krishi Mandi Complex',
            validator: (val) => val == null || val.trim().isEmpty ? 'Address is required' : null,
          ),
          const SizedBox(height: 16),
          if (isMobile) ...[
            _buildInputField(
              label: 'City / Tehsil (Auto-filled) *',
              controller: _cityController,
              hint: 'e.g. Indore',
              validator: (val) => val == null || val.trim().isEmpty ? 'City is required' : null,
            ),
            const SizedBox(height: 16),
            _buildStateDropdown(),
            const SizedBox(height: 16),
            _buildInputField(
              label: 'Landmark / Address Line 2 (Optional)',
              controller: _addressLine2Controller,
              hint: 'Near SBI Branch',
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: _buildInputField(
                    label: 'City / Tehsil (Auto-filled) *',
                    controller: _cityController,
                    hint: 'e.g. Indore',
                    validator: (val) => val == null || val.trim().isEmpty ? 'City is required' : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(child: _buildStateDropdown()),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildInputField(
                    label: 'Landmark / Address 2 (Optional)',
                    controller: _addressLine2Controller,
                    hint: 'Near SBI Branch',
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildKycCard({required bool isMobile}) {
    return _buildCard(
      title: '3. KYC Documents (Optional)',
      subtitle: 'Attach license document or shop photo directly during onboarding',
      icon: Icons.verified_user_rounded,
      child: Column(
        children: [
          if (isMobile) ...[
            _buildDocumentUploadCard(
              title: 'Fertilizer / Seed License',
              subtitle: 'Upload PDF or photo of government license',
              fileName: _licenceFileName,
              icon: Icons.description_rounded,
              onPick: _pickLicenceFile,
              onRemove: () => setState(() {
                _licenceBytes = null;
                _licenceFileName = null;
              }),
            ),
            const SizedBox(height: 16),
            _buildDocumentUploadCard(
              title: 'Shop Front Photo',
              subtitle: 'Upload photo of shopfront with board',
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
                    title: 'Fertilizer / Seed License',
                    subtitle: 'Upload PDF or photo of license',
                    fileName: _licenceFileName,
                    icon: Icons.description_rounded,
                    onPick: _pickLicenceFile,
                    onRemove: () => setState(() {
                      _licenceBytes = null;
                      _licenceFileName = null;
                    }),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildDocumentUploadCard(
                    title: 'Shop Front Photo',
                    subtitle: 'Upload photo of shop with board',
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
        ],
      ),
    );
  }

  Widget _buildAssignmentCard({required bool isSales}) {
    return _buildCard(
      title: isSales ? '4. Assignment & Internal Notes' : '4. Sales Assignment & Internal Notes',
      subtitle: isSales
          ? 'This dealer will be directly assigned to your sales account'
          : 'Assign a sales executive to manage and support this dealer',
      icon: Icons.assignment_ind_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isSales) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: AppTheme.primaryColor, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'As a Sales Agent, this dealer will automatically be assigned to you upon creation.',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ] else ...[
            _buildAgentDropdown(),
            const SizedBox(height: 16),
          ],
          _buildInputField(
            label: 'Initial Notes / Remarks (Optional)',
            controller: _notesController,
            hint: 'e.g. Met at agri-expo, interested in wholesale fertilizer supply',
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Ready to onboard this dealer?',
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton(
                onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  side: const BorderSide(color: AppTheme.borderColor),
                ),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _handleSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSubmitting
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
                          const Icon(Icons.check_circle_outline_rounded, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Create & Verify Dealer',
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 10,
            offset: Offset(0, 4),
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
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppTheme.primaryColor, size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 20),
          child,
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
    final activeAgents = _salesAgents.where((a) {
      final name = '${a['firstName'] ?? ''} ${a['lastName'] ?? ''}'.trim();
      return name.isNotEmpty;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Assign Sales Agent (Admin Control)',
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
              icon: _isLoadingAgents
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor),
                    )
                  : const Icon(Icons.arrow_drop_down_rounded, color: AppTheme.textSecondary),
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
      padding: const EdgeInsets.all(16),
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
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: hasFile ? AppTheme.primaryColor.withValues(alpha: 0.15) : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: hasFile ? AppTheme.primaryColor.withValues(alpha: 0.3) : AppTheme.borderColor,
              ),
            ),
            child: Icon(
              hasFile ? Icons.check_circle_rounded : icon,
              color: hasFile ? AppTheme.primaryColor : AppTheme.textSecondary,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
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
          const SizedBox(width: 10),
          if (hasFile)
            IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.close_rounded, size: 20, color: AppTheme.error),
              tooltip: 'Remove',
            )
          else
            OutlinedButton.icon(
              onPressed: onPick,
              icon: const Icon(Icons.upload_file_rounded, size: 16),
              label: const Text('Browse File'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                textStyle: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }
}
