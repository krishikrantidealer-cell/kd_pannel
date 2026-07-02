import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kd_pannel/app_theme.dart';
import 'package:kd_pannel/core/network/api_client.dart';
import 'package:kd_pannel/core/responsive/responsive.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/dealers_bloc.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/dealers_event.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/dealers_state.dart';
import 'package:kd_pannel/features/admin/presentation/pages/create_order_page.dart';
import 'package:kd_pannel/features/admin/presentation/pages/orders_page.dart';
import 'package:kd_pannel/features/shared/widgets/user_status_notes_widget.dart';
import 'package:kd_pannel/util/dealers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:kd_pannel/core/utils/navigation_service.dart';
import 'package:kd_pannel/core/services/analytics_service.dart';

import '../../../../core/auth/auth_service.dart';
import '../../../../core/network/websocket_service.dart';

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
  List<Map<String, dynamic>> _events = [];
  bool _isLoadingEvents = false;
  String? _agentId;
  String? _agentName;
  bool _isCacheLoaded = false;
  int _activeTab = 0;
  StreamSubscription? _presenceSubscription;
  StreamSubscription? _dealersWsSubscription;

  @override
  void dispose() {
    _presenceSubscription?.cancel();
    _dealersWsSubscription?.cancel();
    super.dispose();
  }

  void _listenToRealTimeEvents() {
    _presenceSubscription?.cancel();
    _presenceSubscription = WebSocketService().presenceUpdates.listen((data) {
      if (!mounted || _dealer == null) return;

      final incomingUser =
          (data['user'] ?? data['userEmail'] ?? data['userId'])?.toString();
      if (incomingUser == null) return;

      final List<String> myIdentifiers = [
        if (_dealer!.email != null) _dealer!.email!.toString(),
        if (_dealer!.phone != null) _dealer!.phone!.toString(),
        if (_dealer!.id != null) _dealer!.id!.toString(),
      ];

      bool isMatch = myIdentifiers.any(
        (id) => id.toLowerCase() == incomingUser.toLowerCase(),
      );

      if (isMatch) {
        // If it's a presence update for the current user, refresh the events feed silently
        _fetchEvents(silent: true);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_dealer == null) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Dealer) {
        _dealer = args;
        _agentId = args.agentId;
        _agentName = args.agent;
        _isCacheLoaded = true;
        _saveDealerToCache(_dealer!);
        _refreshDealerDetails();

        // Track profile view event
        AnalyticsService().logEvent(
          'profile_view',
          properties: {
            'dealerId': args.id ?? '',
            'dealerName': args.name ?? '',
            'details': 'Viewed dealer profile for ${args.name ?? ''}',
          },
        );
      } else {
        _loadDealerFromCache();
      }
      _fetchOrders();
      WebSocketService().connect();
      _dealersWsSubscription?.cancel();
      _dealersWsSubscription = WebSocketService().dealersUpdates.listen((_) {
        if (mounted) {
          _refreshDealerDetails();
        }
      });
      if (AuthService().isAdmin) {
        _fetchSalesAgents();
        _fetchEvents();
        _listenToRealTimeEvents();
      }
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
        if (AuthService().isAdmin) {
          _fetchEvents();
          _listenToRealTimeEvents();
        }
      }
    } catch (e) {
      debugPrint('Error loading dealer from cache: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isCacheLoaded = true;
        });
      }
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

            final String personName =
                (freshUser['firstName'] != null ||
                    freshUser['lastName'] != null)
                ? '${freshUser['firstName'] ?? ''} ${freshUser['lastName'] ?? ''}'
                      .trim()
                : '';

            final freshDealer = Dealer(
              name: personName.isNotEmpty
                  ? personName
                  : (freshUser['phoneNumber'] ?? 'Unnamed Dealer'),
              phone: freshUser['phoneNumber'] ?? '',
              city: freshUser['address']?['cityTehsil'] ?? '',
              state: freshUser['address']?['state'] ?? '',
              agent: agentName.isNotEmpty ? agentName : '-',
              gstStatus: 'Verified',
              totalOrders: _orders.length,
              purchaseValue: _dealer!.purchaseValue,
              isHighValue: _dealer!.isHighValue,
              isInactive: _orders.isEmpty,
              source: freshUser['source'] ?? _dealer?.source ?? 'App',
              deepLinkUrl: freshUser['deepLinkUrl'] ?? _dealer?.deepLinkUrl,
              id: freshUser['_id'],
              agentId: freshUser['assignedAgent']?['_id'],
              licenceImage: freshUser['licenceImage'],
              shopImage: freshUser['shopImage'],
              gstNumber: freshUser['gstNumber'],
              email: freshUser['email'],
              userType: freshUser['userType'],
              kycStatus: freshUser['kycStatus'],
              shopName: freshUser['shopName'],
              address: freshUser['address'] != null
                  ? Map<String, dynamic>.from(freshUser['address'])
                  : null,
              isBlocked: freshUser['isBlocked'] ?? false,
              status:
                  freshUser['status'] ?? freshUser['leadStatus'] ?? 'prospect',
              notes: freshUser['notes'] ?? freshUser['leadNotes'] ?? '',
              notesHistory: freshUser['notesHistory'] != null
                  ? List<Map<String, dynamic>>.from(freshUser['notesHistory'])
                  : [],
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
      final String dealerId = _dealer!.id!;
      // Passing both userId and user for maximum compatibility with backend changes
      final res = await ApiClient().get('/orders/admin/all?userId=$dealerId&user=$dealerId');
      
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) {
          final List rawOrders = data['orders'] ?? [];
          
          if (mounted) {
            setState(() {
              // Local filtering as a second layer of safety
              _orders = rawOrders
                  .map((o) => Map<String, dynamic>.from(o))
                  .where((o) => 
                      (o['user'] is Map && o['user']['_id'] == dealerId) || 
                      o['user'] == dealerId)
                  .toList();
            });
            debugPrint('Loaded ${_orders.length} filtered orders for dealer $dealerId (Total returned: ${rawOrders.length})');
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

  Future<void> _fetchEvents({bool silent = false}) async {
    String? identifier;
    final email = _dealer?.email;
    final phone = _dealer?.phone;
    final id = _dealer?.id;

    if (email != null && email.trim().isNotEmpty) {
      identifier = email.trim();
    } else if (phone != null && phone.trim().isNotEmpty) {
      identifier = phone.trim();
    } else if (id != null && id.trim().isNotEmpty) {
      identifier = id.trim();
    }

    if (identifier == null) return;
    if (mounted && !silent) setState(() => _isLoadingEvents = true);
    try {
      final filtered = await AnalyticsService().fetchEvents(
        userEmail: identifier,
      );
      if (mounted) {
        setState(() {
          _events = filtered;
        });
      }
    } catch (e) {
      debugPrint('Error loading dealer events: $e');
    } finally {
      if (mounted && !silent) {
        setState(() {
          _isLoadingEvents = false;
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
              source: _dealer?.source ?? 'App',
              deepLinkUrl: _dealer?.deepLinkUrl,
              id: _dealer!.id,
              agentId: _agentId ?? _dealer!.agentId,
              licenceImage: _dealer!.licenceImage,
              shopImage: _dealer!.shopImage,
              gstNumber: _dealer!.gstNumber,
              email: _dealer!.email,
              userType: _dealer!.userType,
              kycStatus: _dealer!.kycStatus,
              address: _dealer!.address,
              isBlocked: _dealer!.isBlocked,
              status: _dealer!.status,
              notes: _dealer!.notes,
              notesHistory: _dealer!.notesHistory,
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

  void _toggleBlockDealer() {
    if (_dealer == null) return;
    final isBlocked = _dealer!.isBlocked;
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
                isBlocked ? 'Unblock Dealer' : 'Block Dealer',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Text(
            isBlocked
                ? 'Are you sure you want to unblock this dealer? They will regain access to place orders.'
                : 'Are you sure you want to block this dealer? They will be force logged out instantly and restricted from placing any orders or accessing the application.',
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
                final userId = _dealer?.id;
                if (userId != null) {
                  Navigator.pop(dialogContext);
                  context.read<DealersBloc>().add(
                    ToggleBlockDealerEvent(userId),
                  );
                  setState(() {
                    _dealer = Dealer(
                      name: _dealer!.name,
                      phone: _dealer!.phone,
                      city: _dealer!.city,
                      state: _dealer!.state,
                      agent: _dealer!.agent,
                      gstStatus: _dealer!.gstStatus,
                      totalOrders: _dealer!.totalOrders,
                      purchaseValue: _dealer!.purchaseValue,
                      isHighValue: _dealer!.isHighValue,
                      isInactive: _dealer!.isInactive,
                      source: _dealer!.source,
                      deepLinkUrl: _dealer!.deepLinkUrl,
                      id: _dealer!.id,
                      agentId: _dealer!.agentId,
                      licenceImage: _dealer!.licenceImage,
                      shopImage: _dealer!.shopImage,
                      gstNumber: _dealer!.gstNumber,
                      email: _dealer!.email,
                      userType: _dealer!.userType,
                      kycStatus: _dealer!.kycStatus,
                      shopName: _dealer!.shopName,
                      address: _dealer!.address,
                      isBlocked: !isBlocked,
                      status: _dealer!.status,
                      notes: _dealer!.notes,
                      notesHistory: _dealer!.notesHistory,
                    );
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

  Future<void> _deleteDealer() async {
    if (_dealer == null || _dealer!.id == null) return;
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
          'Are you sure you want to delete dealer "${_dealer!.name}"? This action cannot be undone and all associated profile data will be removed.',
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
      final userId = _dealer?.id;
      if (userId != null) {
        context.read<DealersBloc>().add(DeleteDealerEvent(userId));
        Navigator.pop(context); // Go back to management list after deletion
      }
    }
  }

  Future<void> _editDealer() async {
    if (_dealer == null) return;
    final nameController = TextEditingController(text: _dealer!.name);
    final shopNameController = TextEditingController(
      text: _dealer!.shopName ?? '',
    );
    final gstController = TextEditingController(text: _dealer!.gstNumber ?? '');
    final phoneController = TextEditingController(text: _dealer!.phone);
    final villageAreaController = TextEditingController(
      text: _dealer!.address?['villageArea'] ?? '',
    );
    final addressLine2Controller = TextEditingController(
      text: _dealer!.address?['addressLine2'] ?? '',
    );
    final cityController = TextEditingController(text: _dealer!.city);
    final stateController = TextEditingController(text: _dealer!.state);
    final pincodeController = TextEditingController(
      text: _dealer!.address?['pincode'] ?? '',
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
      final userId = _dealer?.id;

      if (userId != null) {
        context.read<DealersBloc>().add(
          UpdateDealerDetailsEvent(
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
        // Wait for bloc to finish and refresh locally
        await Future.delayed(const Duration(milliseconds: 500));
        _refreshDealerDetails();
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
    if (_dealer == null) {
      if (_isCacheLoaded) {
        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Dealer details not found or session expired.',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () =>
                      Navigator.pushReplacementNamed(context, '/dealers'),
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
                    'Go to Dealers List',
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
      source: _dealer?.source ?? 'App',
      deepLinkUrl: _dealer?.deepLinkUrl,
      id: _dealer!.id,
      agentId: _agentId ?? _dealer!.agentId,
      licenceImage: _dealer!.licenceImage,
      shopImage: _dealer!.shopImage,
      gstNumber: _dealer!.gstNumber,
      email: _dealer!.email,
      userType: _dealer!.userType,
      kycStatus: _dealer!.kycStatus,
      address: _dealer!.address,
      isBlocked: _dealer!.isBlocked,
      status: _dealer!.status,
      notes: _dealer!.notes,
      notesHistory: _dealer!.notesHistory,
    );

    return SelectionArea(
      child: Scaffold(
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
                    _buildBreadcrumbs(context, isMobile, currentDealer.name),
                    const SizedBox(height: 16),

                    // 2. HEADER SECTION
                    _DealerHeroCard(
                      dealer: currentDealer,
                      onToggleBlock: _toggleBlockDealer,
                      onEdit: _editDealer,
                      onDelete: _deleteDealer,
                      onCreateOrder: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                CreateOrderPage(dealer: currentDealer),
                          ),
                        );
                        if (result == true && mounted) {
                          _fetchOrders();
                          _refreshDealerDetails();
                        }
                      },
                    ),
                    const SizedBox(height: 24),

                    // 3. TAB CONTROLLER CHIPS SELECTOR
                    _buildAdvancedProfileTabs(),
                    const SizedBox(height: 24),

                    // 4. TABBED CONTENT CHANNELS
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: _activeTab == 0
                          ? Column(
                              key: const ValueKey(0),
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _StatsCardsSection(
                                  dealer: currentDealer,
                                  orders: _orders,
                                ),
                                const SizedBox(height: 24),
                                if (!isMobile) ...[
                                  IntrinsicHeight(
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
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
                                  ),
                                ] else ...[
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
                              ],
                            )
                          : _activeTab == 1
                          ? _OrderHistoryCard(
                              key: const ValueKey(1),
                              dealer: currentDealer,
                              orders: _orders,
                              isLoading: _isLoadingOrders,
                            )
                          : _activeTab == 2
                          ? _UserEventsCard(
                              key: const ValueKey(2),
                              userIdentifier:
                                  currentDealer.email ??
                                  currentDealer.phone ??
                                  currentDealer.id ??
                                  '',
                              events: _events,
                              isLoading: _isLoadingEvents,
                              onRefresh: () => _fetchEvents(),
                            )
                          : Column(
                              key: const ValueKey(3),
                              children: [
                                if (currentDealer.id != null)
                                  UserStatusNotesWidget(
                                    userId: currentDealer.id!,
                                    initialStatus:
                                        currentDealer.status ?? 'prospect',
                                    initialNotes: currentDealer.notes ?? '',
                                    notesHistory: currentDealer.notesHistory,
                                    isSubmitting:
                                        context
                                            .watch<DealersBloc>()
                                            .state
                                            .status ==
                                        DealersStatus.submitting,
                                    onSave: (status, notes) {
                                      context.read<DealersBloc>().add(
                                        UpdateDealerDetailsEvent(
                                          userId: currentDealer.id!,
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
  }

  Widget _buildAdvancedProfileTabs() {
    final List<Map<String, dynamic>> tabs = [
      {'icon': Icons.dashboard_outlined, 'label': 'Overview'},
      {'icon': Icons.shopping_bag_outlined, 'label': 'Orders'},
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
                  color: isSelected
                      ? AppTheme.primaryColor
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppTheme.primaryColor.withOpacity(0.15),
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

  Widget _buildBreadcrumbs(
    BuildContext context,
    bool isMobile,
    String profileName,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                'Dealers',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryColor,
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
              profileName,
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
    );
  }
}

class _DealerHeroCard extends StatelessWidget {
  final Dealer dealer;
  final VoidCallback onToggleBlock;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onCreateOrder;

  const _DealerHeroCard({
    required this.dealer,
    required this.onToggleBlock,
    required this.onEdit,
    required this.onDelete,
    required this.onCreateOrder,
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

    final String initial = dealer.name.isNotEmpty
        ? dealer.name.substring(0, 1).toUpperCase()
        : 'J';

    final Widget avatar = Container(
      width: 64,
      height: 64,
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
                  colors: dealer.isBlocked ||
                          (dealer.kycStatus?.toLowerCase() == 'rejected')
                      ? [const Color(0xFF991B1B), const Color(0xFFEF4444)]
                      : dealer.kycStatus?.toLowerCase() == 'verified'
                          ? [const Color(0xFF065F46), const Color(0xFF10B981)]
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
                                      dealer.name,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.outfit(
                                        fontSize: isMobile ? 18 : 22,
                                        fontWeight: FontWeight.w900,
                                        color: const Color(0xFF111827),
                                      ),
                                    ),
                                  ),
                                  if (dealer.kycStatus?.toLowerCase() == 'verified') ...[
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
                                  if (dealer.isBlocked)
                                    _buildStatusBadge(
                                      'BLOCKED',
                                      const Color(0xFFEF4444),
                                    ),
                                  _buildStatusBadge(
                                    'GST: ${dealer.gstStatus.toUpperCase()}',
                                    const Color(0xFF3B82F6),
                                  ),
                                  if (dealer.kycStatus != null)
                                    _buildStatusBadge(
                                      'KYC: ${dealer.kycStatus!.toUpperCase()}',
                                      dealer.kycStatus!.toLowerCase() == 'verified'
                                          ? const Color(0xFF10B981)
                                          : dealer.kycStatus!.toLowerCase() == 'rejected'
                                              ? const Color(0xFFEF4444)
                                              : const Color(0xFFF59E0B),
                                    ),
                                ],
                              ),
                              if (!isMobile) ...[
                                const SizedBox(height: 12),
                                _buildContactRow(isMobile),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (isMobile) ...[
                    const SizedBox(height: 16),
                    _buildContactRow(isMobile),
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

  Widget _buildContactRow(bool isMobile) {
    final List<String> addressParts = [];
    if (dealer.address?['villageArea']?.toString().isNotEmpty ?? false) {
      addressParts.add(dealer.address!['villageArea']);
    }
    if (dealer.address?['addressLine2']?.toString().isNotEmpty ?? false) {
      addressParts.add(dealer.address!['addressLine2']);
    }
    if (dealer.city.isNotEmpty) addressParts.add(dealer.city);
    if (dealer.state.isNotEmpty) addressParts.add(dealer.state);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _buildContactItem(Icons.phone_outlined, dealer.phone),
        if (addressParts.isNotEmpty)
          _buildContactItem(Icons.location_on_outlined, addressParts.join(', ')),
        _buildContactItem(Icons.person_outline, 'Agent: ${dealer.agent}'),
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
          Icon(icon, size: 14, color: const Color(0xFF4B5563)),
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
          icon: Icons.add_shopping_cart_rounded,
          label: 'Order',
          color: AppTheme.primaryColor,
          isSolid: true,
          onTap: onCreateOrder,
        ),
        _ActionButton(
          icon: Icons.edit_outlined,
          label: 'Edit',
          color: AppTheme.info,
          isSolid: true,
          onTap: onEdit,
        ),
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
        _ActionButton(
          icon: dealer.isBlocked
              ? Icons.lock_open_outlined
              : Icons.block_outlined,
          label: dealer.isBlocked ? 'Unblock' : 'Block',
          color: dealer.isBlocked ? Colors.blue : AppTheme.error,
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
}

class _ActionButton extends StatefulWidget {
  final dynamic icon;
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
              widget.icon is IconData
                  ? Icon(
                      widget.icon as IconData,
                      size: isMobile ? 18 : 19,
                      color: widget.isSolid ? Colors.white : widget.color,
                    )
                  : widget.icon is FaIconData
                      ? FaIcon(
                          widget.icon,
                          size: isMobile ? 18 : 19,
                          color: widget.isSolid ? Colors.white : widget.color,
                        )
                      : const SizedBox.shrink(),
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

class _StatCard extends StatefulWidget {
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
  State<_StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<_StatCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        width: widget.width,
        height: isMobile ? 110 : 120,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _isHovered
                  ? widget.color.withOpacity(0.12)
                  : Colors.black.withOpacity(0.04),
              blurRadius: _isHovered ? 24 : 15,
              offset: _isHovered ? const Offset(0, 8) : const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: _isHovered
                ? widget.color.withOpacity(0.4)
                : const Color(0xFFE2E8F0),
            width: 1.5,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              right: -10,
              top: -10,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                opacity: _isHovered ? 0.08 : 0.0,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: widget.color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 16,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: _isHovered
                      ? widget.color
                      : widget.color.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.icon,
                  color: _isHovered ? Colors.white : widget.color,
                  size: 20,
                ),
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
                    widget.title,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: const Color(0xFF6B7280),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.value,
                    style: GoogleFonts.outfit(
                      fontSize: 20,
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

  Map<String, String> _getDeepLinkAttributes(String? urlString) {
    if (urlString == null || urlString.trim().isEmpty) return {};
    try {
      final uri = Uri.parse(urlString);
      return uri.queryParameters;
    } catch (e) {
      return {};
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

  Widget _buildLocationItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: const Color(0xFF6B7280)),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: const Color(0xFF6B7280),
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: const Color(0xFF1F2937),
                fontWeight: FontWeight.w700,
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
    final String dealerName = dealer.name.isNotEmpty ? dealer.name : 'Unnamed Dealer';
    final String shopName = dealer.shopName?.toString().isNotEmpty == true
        ? dealer.shopName!
        : 'No Shop Registered';
    final String dealerSource = dealer.source;
    final String initial = dealerName.isNotEmpty ? dealerName.substring(0, 1).toUpperCase() : 'D';

    final String tier = dealer.isHighValue
        ? 'Platinum Distributor'
        : 'Authorized Dealer';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
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
                              dealerName,
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
                                  dealerSource.toUpperCase(),
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
                        dealer.address?['villageArea']?.toString().isNotEmpty == true
                            ? dealer.address!['villageArea']
                            : '-',
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Divider(height: 1, color: Color(0xFFE2E8F0)),
                      ),
                      _buildLocationItem(
                        Icons.location_city_outlined,
                        'City / District',
                        dealer.city.isNotEmpty ? dealer.city : '-',
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Divider(height: 1, color: Color(0xFFE2E8F0)),
                      ),
                      _buildLocationItem(
                        Icons.map_outlined,
                        'State & Pincode',
                        '${dealer.state.isNotEmpty ? dealer.state : '-'} - ${dealer.address?['pincode']?.toString().isNotEmpty == true ? dealer.address!['pincode'] : '-'}',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _buildSectionHeader('Dealer Details', Icons.business_center_outlined),
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
                        Icons.phone_android_outlined,
                        'Phone Number',
                        dealer.phone,
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Divider(height: 1, color: Color(0xFFE2E8F0)),
                      ),
                      _buildLocationItem(
                        Icons.receipt_outlined,
                        'GST Number',
                        dealer.gstNumber?.toString().isNotEmpty == true
                            ? dealer.gstNumber!
                            : 'Not Provided',
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Divider(height: 1, color: Color(0xFFE2E8F0)),
                      ),
                      _buildLocationItem(
                        Icons.category_outlined,
                        'Dealer Type',
                        tier,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                if (dealer.deepLinkUrl != null &&
                    dealer.deepLinkUrl!.trim().isNotEmpty) ...[
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
                                dealer.deepLinkUrl!,
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
                                dealer.deepLinkUrl!,
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
                              dealer.deepLinkUrl!,
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
                              (agent) => agent['_id'] == currentAgentId,
                            )
                                ? currentAgentId
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderHistoryCard extends StatefulWidget {
  final Dealer dealer;
  final List<Map<String, dynamic>> orders;
  final bool isLoading;

  const _OrderHistoryCard({
    super.key,
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
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.softShadow,
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
    final hasLicence =
        dealer.licenceImage != null && dealer.licenceImage!.isNotEmpty;
    final hasShopImage =
        dealer.shopImage != null && dealer.shopImage!.isNotEmpty;

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
              const SizedBox(height: 16),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              const SizedBox(height: 16),
              _buildKycProtocol(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKycProtocol() {
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
}

class _KycDocumentCard extends StatefulWidget {
  final String title;
  final String status;
  final String? subtext;
  final dynamic icon;
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
                child: widget.icon is IconData
                    ? Icon(
                        widget.icon as IconData,
                        size: 16,
                        color: const Color(0xFF2E7D32),
                      )
                    : widget.icon is FaIconData
                        ? FaIcon(
                            widget.icon,
                            size: 16,
                            color: const Color(0xFF2E7D32),
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

class _UserEventsCard extends StatefulWidget {
  final String userIdentifier;
  final List<Map<String, dynamic>> events;
  final bool isLoading;
  final VoidCallback onRefresh;

  const _UserEventsCard({
    super.key,
    required this.userIdentifier,
    required this.events,
    required this.isLoading,
    required this.onRefresh,
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

    final sortedEvents = List<Map<String, dynamic>>.from(widget.events)
      ..sort((a, b) {
        final aTs = a['timestamp']?.toString() ?? '';
        final bTs = b['timestamp']?.toString() ?? '';
        return bTs.compareTo(aTs);
      });

    final filteredEvents = sortedEvents.where((e) {
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
            Expanded(
              child: Row(
                children: [
                  Text(
                    'Live Activity & Events Feed',
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (!widget.isLoading)
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded,
                          size: 18, color: AppTheme.primaryColor),
                      onPressed: widget.onRefresh,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Refresh Activity Feed',
                    ),
                ],
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
