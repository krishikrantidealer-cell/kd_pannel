import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kd_pannel/app_theme.dart';
import 'package:kd_pannel/core/network/api_client.dart';
import 'package:kd_pannel/core/responsive/responsive.dart';
import 'package:kd_pannel/core/services/analytics_service.dart';
import 'package:kd_pannel/core/network/websocket_service.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/leads_bloc.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/leads_event.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/leads_state.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/orders_bloc.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/orders_state.dart';
import 'package:kd_pannel/features/admin/data/models/order_model.dart';
import 'package:kd_pannel/util/dealers.dart';
import 'package:kd_pannel/features/shared/widgets/advanced_stat_card_widget.dart';

class TeamMemberProfilePage extends StatefulWidget {
  const TeamMemberProfilePage({super.key});

  @override
  State<TeamMemberProfilePage> createState() => _TeamMemberProfilePageState();
}

class _TeamMemberProfilePageState extends State<TeamMemberProfilePage> {
  Map<String, dynamic>? _agent;
  bool _isActionLoading = false;
  int _activeTab = 0;
  int _activeLogSubTab = 0; // 0 for Sales, 1 for Admin

  // Real-time agent status
  bool _isAgentActive = false;
  StreamSubscription? _presenceSubscription;
  Timer? _activeTimer;

  // Search & Filters state
  final TextEditingController _leadSearchController = TextEditingController();
  final TextEditingController _orderSearchController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  String _leadSearchQuery = '';
  String _orderSearchQuery = '';
  String _clientSegmentFilter = 'All'; // 'All', 'Leads', 'Dealers'
  bool _isSavingNotes = false;
  bool _isLoadingCache = true;
  int _portfolioLimit = 15;
  int _ordersLimit = 15;
  int _eventsLimit = 15;

  // Activity events
  List<Map<String, dynamic>> _agentEvents = [];
  bool _isLoadingEvents = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAgentPresence();
      _fetchAgentEvents();
      _loadAgentNotes();
      _listenToRealTimeHeartbeats();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_agent == null) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, dynamic>) {
        _agent = args;
        _isLoadingCache = false;
        _saveAgentCache(args);
      } else {
        _loadAgentCache();
      }
    }
  }

  Future<void> _saveAgentCache(Map<String, dynamic> agent) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_last_agent', jsonEncode(agent));
    } catch (_) {}
  }

  Future<void> _loadAgentCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedStr = prefs.getString('cached_last_agent');
      if (cachedStr != null && cachedStr.isNotEmpty) {
        final agentMap = jsonDecode(cachedStr) as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _agent = agentMap;
            _isLoadingCache = false;
          });
          _checkAgentPresence();
          _fetchAgentEvents();
          _loadAgentNotes();
          _listenToRealTimeHeartbeats();
          return;
        }
      }
    } catch (_) {}
    if (mounted) {
      setState(() {
        _isLoadingCache = false;
      });
    }
  }

  @override
  void dispose() {
    _presenceSubscription?.cancel();
    _activeTimer?.cancel();
    _leadSearchController.dispose();
    _orderSearchController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _triggerBlocRefresh() {
    context.read<LeadsBloc>().add(
      const FetchLeadsDataEvent(forceRefresh: true),
    );
  }

  String _formatCurrency(double amount) {
    return '₹${amount.toStringAsFixed(0)}';
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

  Future<void> _checkAgentPresence() async {
    if (_agent == null) return;
    try {
      final activeUsers = await AnalyticsService().fetchRealTimeUsers();
      final agentEmail = _agent!['email']?.toString().toLowerCase();
      if (agentEmail != null) {
        final isActive = activeUsers.any((u) {
          final email = (u['user'] ?? u['userEmail'] ?? u['email'])
              ?.toString()
              .toLowerCase();
          return email == agentEmail;
        });
        if (mounted) {
          setState(() {
            _isAgentActive = isActive;
          });
        }
      }
    } catch (_) {}
  }

  void _listenToRealTimeHeartbeats() {
    _presenceSubscription?.cancel();
    _presenceSubscription = WebSocketService().presenceUpdates.listen((data) {
      if (!mounted || _agent == null) return;
      final agentEmail = _agent!['email']?.toString().toLowerCase();
      final incomingUser = (data['user'] ?? data['userEmail'] ?? data['userId'])
          ?.toString()
          .toLowerCase();
      if (agentEmail != null &&
          incomingUser != null &&
          agentEmail == incomingUser) {
        setState(() {
          _isAgentActive = true;
        });
        _activeTimer?.cancel();
        _activeTimer = Timer(const Duration(seconds: 45), () {
          if (mounted) {
            setState(() {
              _isAgentActive = false;
            });
          }
        });
      }
    });
  }

  Future<void> _fetchAgentEvents() async {
    if (_agent == null) return;
    final agentEmail = _agent!['email']?.toString();
    if (agentEmail == null || agentEmail.isEmpty) return;

    if (mounted) setState(() => _isLoadingEvents = true);
    try {
      // Fetch both behavioral events and system audit logs
      final results = await Future.wait([
        AnalyticsService().fetchEvents(userEmail: agentEmail),
        AnalyticsService().fetchAuditLogs(adminEmail: agentEmail),
      ]);

      final events = (results[0] as List? ?? []).cast<Map<String, dynamic>>();
      final auditLogsData = results[1] as Map<String, dynamic>?;
      final auditLogs = (auditLogsData?['logs'] as List? ?? []);

      // Standardize audit logs to match event format for the timeline
      final standardizedAudit = auditLogs
          .map((log) {
            final m = log as Map;
            return {
              'event': m['action'] ?? 'system_audit',
              'timestamp': m['timestamp'],
              'isAudit': true,
              'properties': {
                'details': 'System Action on ${m['targetModel'] ?? 'Object'}',
                'changes': m['changes'],
                'targetId': m['targetId'],
              },
            };
          })
          .toList()
          .cast<Map<String, dynamic>>();

      final combined = [...events, ...standardizedAudit];

      // Sort combined list by timestamp descending
      combined.sort((a, b) {
        final tA =
            DateTime.tryParse(a['timestamp']?.toString() ?? '') ?? DateTime(0);
        final tB =
            DateTime.tryParse(b['timestamp']?.toString() ?? '') ?? DateTime(0);
        return tB.compareTo(tA);
      });

      if (mounted) {
        setState(() {
          _agentEvents = combined;
        });
      }
    } catch (e) {
      debugPrint('Error loading agent events: $e');
    } finally {
      if (mounted) setState(() => _isLoadingEvents = false);
    }
  }

  Future<void> _loadAgentNotes() async {
    if (_agent == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final notes = prefs.getString('agent_notes_${_agent!['_id']}') ?? '';
      _notesController.text = notes;
    } catch (_) {}
  }

  Future<void> _saveAgentNotes() async {
    if (_agent == null) return;
    setState(() => _isSavingNotes = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'agent_notes_${_agent!['_id']}',
        _notesController.text,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Private notes saved successfully'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isSavingNotes = false);
    }
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

  Future<void> _deleteSalesAgent(String agentId, String agentName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Sales Agent',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        content: Text(
          'Are you sure you want to delete $agentName? This agent will be removed and automatically unassigned from all their assigned leads and dealers.',
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isActionLoading = true);
    try {
      final res = await ApiClient().delete('/users/sales/$agentId');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Sales agent deleted successfully'),
                backgroundColor: AppTheme.success,
              ),
            );
            Navigator.pop(context); // Return to list view
          }
          _triggerBlocRefresh();
        } else {
          throw Exception(data['message'] ?? 'Failed to delete agent');
        }
      } else {
        throw Exception('Server returned code: ${res.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  void _showSalesAgentFormDialog(Map<String, dynamic> agent) {
    final formKey = GlobalKey<FormState>();
    final firstNameController = TextEditingController(
      text: agent['firstName'] ?? '',
    );
    final lastNameController = TextEditingController(
      text: agent['lastName'] ?? '',
    );
    final emailController = TextEditingController(text: agent['email'] ?? '');
    final phoneController = TextEditingController(
      text: agent['phoneNumber'] ?? '',
    );
    final passwordController = TextEditingController();
    bool obscurePassword = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setStateDialog) {
          return AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              'Edit Sales Agent',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: firstNameController,
                      decoration: _buildInputDecoration(
                        'First Name',
                        Icons.person_outline,
                      ),
                      validator: (val) =>
                          val == null || val.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: lastNameController,
                      decoration: _buildInputDecoration(
                        'Last Name',
                        Icons.person_outline,
                      ),
                      validator: (val) =>
                          val == null || val.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: emailController,
                      decoration: _buildInputDecoration(
                        'Email Address',
                        Icons.email_outlined,
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (val) => val == null || !val.contains('@')
                          ? 'Invalid email'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: phoneController,
                      decoration: _buildInputDecoration(
                        'Phone Number',
                        Icons.phone_outlined,
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (val) =>
                          val == null || val.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: passwordController,
                      decoration: _buildInputDecoration(
                        'New Password (Optional)',
                        Icons.lock_outline,
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 20,
                            color: AppTheme.textSecondary,
                          ),
                          onPressed: () {
                            setStateDialog(() {
                              obscurePassword = !obscurePassword;
                            });
                          },
                        ),
                      ),
                      obscureText: obscurePassword,
                      validator: (val) {
                        if (val != null && val.isNotEmpty && val.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.outfit(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: _isActionLoading
                    ? null
                    : () async {
                        if (formKey.currentState!.validate()) {
                          setStateDialog(() => _isActionLoading = true);
                          try {
                            final payload = {
                              'firstName': firstNameController.text.trim(),
                              'lastName': lastNameController.text.trim(),
                              'email': emailController.text.trim(),
                              'phoneNumber': phoneController.text.trim(),
                            };
                            if (passwordController.text.isNotEmpty) {
                              payload['password'] = passwordController.text;
                            }

                            final res = await ApiClient().put(
                              '/users/sales/${agent['_id']}',
                              payload,
                            );

                            if (res.statusCode == 200) {
                              final data = jsonDecode(res.body);
                              if (data['success'] == true) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Sales agent updated successfully',
                                      ),
                                      backgroundColor: AppTheme.success,
                                    ),
                                  );
                                }
                                if (dialogCtx.mounted) {
                                  Navigator.pop(dialogCtx);
                                }
                                _triggerBlocRefresh();
                              } else {
                                throw Exception(
                                  data['message'] ?? 'Action failed',
                                );
                              }
                            } else {
                              final data = jsonDecode(res.body);
                              throw Exception(
                                data['message'] ??
                                    'Server returned code: ${res.statusCode}',
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: $e'),
                                  backgroundColor: AppTheme.error,
                                ),
                              );
                            }
                          } finally {
                            setStateDialog(() => _isActionLoading = false);
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isActionLoading
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Update'),
              ),
            ],
          );
        },
      ),
    );
  }

  InputDecoration _buildInputDecoration(
    String label,
    IconData icon, {
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.outfit(
        color: AppTheme.textSecondary,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      prefixIcon: Icon(icon, size: 18, color: AppTheme.primaryColor),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.borderColor, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.error, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.error, width: 1.5),
      ),
    );
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

  Dealer _mapUserToDealer(Map<String, dynamic> u, List<OrderModel> allOrders) {
    final String personName = (u['firstName'] != null || u['lastName'] != null)
        ? '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'.trim()
        : '';

    final dealerId = u['_id'];
    final dealerOrders = allOrders.where((o) => o.userId == dealerId).toList();
    final double purchaseSum = dealerOrders.fold(
      0.0,
      (sum, o) => sum + o.totalAmount,
    );

    return Dealer(
      name: personName.isNotEmpty
          ? personName
          : (u['phoneNumber'] ?? 'Unnamed Dealer'),
      phone: u['phoneNumber'] ?? '',
      city: u['address']?['cityTehsil'] ?? '',
      state: u['address']?['state'] ?? '',
      agent: u['assignedAgent'] != null
          ? '${u['assignedAgent']['firstName'] ?? ''} ${u['assignedAgent']['lastName'] ?? ''}'
                .trim()
          : '-',
      gstStatus: 'Verified',
      totalOrders: dealerOrders.length,
      purchaseValue: _formatCurrency(purchaseSum),
      isHighValue: purchaseSum >= 500000,
      isInactive: dealerOrders.isEmpty,
      source: u['source'] ?? 'App',
      deepLinkUrl: u['deepLinkUrl'],
      id: dealerId,
      agentId: u['assignedAgent']?['_id'],
      licenceImage: u['licenceImage'],
      shopImage: u['shopImage'],
      gstNumber: u['gstNumber'],
      email: u['email'],
      userType: u['userType'],
      kycStatus: u['kycStatus'],
      shopName: u['shopName'],
      address: u['address'] != null
          ? Map<String, dynamic>.from(u['address'])
          : null,
      isBlocked: u['isBlocked'] ?? false,
      status: u['status'] ?? u['leadStatus'] ?? 'prospect',
      notes: u['notes'] ?? u['leadNotes'] ?? '',
      notesHistory: u['notesHistory'] != null
          ? List<Map<String, dynamic>>.from(u['notesHistory'])
          : [],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final isTablet = Responsive.isTablet(context);

    // Grab route arguments (fallback is null)
    if (_agent == null) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, dynamic>) {
        _agent = args;
        _isLoadingCache = false;
        _saveAgentCache(args);
      }
    }

    return BlocBuilder<LeadsBloc, LeadsState>(
      builder: (context, leadsState) {
        // Retrieve fresh details of agent if loaded in leadsState
        if (_agent != null && leadsState.allRawUsers.isNotEmpty) {
          final freshAgent = leadsState.allRawUsers.firstWhere(
            (u) => u['_id'] == _agent!['_id'],
            orElse: () => _agent!,
          );
          _agent = freshAgent;
        }

        if (_agent == null) {
          return Scaffold(
            backgroundColor: const Color(0xFFF8FAFC),
            body: Center(
              child: _isLoadingCache
                  ? const CircularProgressIndicator(
                      color: AppTheme.primaryColor,
                    )
                  : const Text('No team member details found.'),
            ),
          );
        }

        final agentId = _agent!['_id'] ?? '';
        final agentName =
            '${_agent!['firstName'] ?? ''} ${_agent!['lastName'] ?? ''}'.trim();
        final agentPhone = _agent!['phoneNumber'] ?? '-';
        final agentEmail = _agent!['email'] ?? '-';
        final agentRole = _agent!['role'] ?? 'sales';
        final isAgentBlocked = _agent!['isBlocked'] ?? false;
        final createdAtStr = _agent!['createdAt'] != null
            ? _formatTimeAgo(_agent!['createdAt'])
            : '-';

        // Filter assigned leads & dealers
        final assignedLeads = leadsState.allRawUsers.where((u) {
          final isUser = u['role'] == 'user';
          final isNotVerified = u['kycStatus'] != 'verified';
          final assignedToMe =
              u['assignedAgent'] != null &&
              (u['assignedAgent']['_id'] == agentId ||
                  u['assignedAgent'] == agentId);
          return isUser && isNotVerified && assignedToMe;
        }).toList();

        final assignedDealers = leadsState.allRawUsers.where((u) {
          final isUser = u['role'] == 'user';
          final isVerified = u['kycStatus'] == 'verified';
          final assignedToMe =
              u['assignedAgent'] != null &&
              (u['assignedAgent']['_id'] == agentId ||
                  u['assignedAgent'] == agentId);
          return isUser && isVerified && assignedToMe;
        }).toList();

        return BlocBuilder<OrdersBloc, OrdersState>(
          builder: (context, ordersState) {
            // Filter orders for dealers/leads assigned to this agent
            final assignedClientIds = [
              ...assignedLeads.map((e) => e['_id']),
              ...assignedDealers.map((e) => e['_id']),
            ];

            final agentOrders = ordersState.orders.where((o) {
              final isAssignedByAgentId = o.assignedAgentId == agentId;
              final isAssignedByClient = assignedClientIds.contains(o.userId);
              return isAssignedByAgentId || isAssignedByClient;
            }).toList();

            final double cumulativeRevenue = agentOrders.fold(
              0.0,
              (sum, o) => sum + o.totalAmount,
            );

            final double averageOrderValue = agentOrders.isEmpty
                ? 0.0
                : cumulativeRevenue / agentOrders.length;

            // Conversion rate (Dealers onboarding percentage)
            final double totalPortfolio =
                (assignedLeads.length + assignedDealers.length).toDouble();
            final double conversionRate = totalPortfolio == 0
                ? 0.0
                : (assignedDealers.length / totalPortfolio) * 100;

            // Group orders by userId to efficiently compute high-value dealers
            final Map<String, double> dealerSalesMap = {};
            for (var o in ordersState.orders) {
              final uid = o.userId;
              if (uid != null) {
                dealerSalesMap[uid] =
                    (dealerSalesMap[uid] ?? 0.0) + o.totalAmount;
              }
            }

            final int highValueDealersCount = assignedDealers.where((d) {
              final dealerId = d['_id'];
              final sales = dealerSalesMap[dealerId] ?? 0.0;
              return sales >= 500000;
            }).length;

            // Determine Agent Sales Tier/Class
            String tierLabel = 'Bronze Agent';
            Color tierColor = Colors.brown;
            if (cumulativeRevenue >= 1000000) {
              tierLabel = 'Platinum Agent';
              tierColor = Colors.deepPurple;
            } else if (cumulativeRevenue >= 500000) {
              tierLabel = 'Gold Agent';
              tierColor = const Color(0xFFD4AF37); // Gold
            } else if (cumulativeRevenue >= 200000) {
              tierLabel = 'Silver Agent';
              tierColor = const Color(0xFFC0C0C0); // Silver
            }

            // --- HERO INFORMATION CARD (Left / Top Column) ---
            final Widget profileHeroCard = isMobile || isTablet
                ? Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: AppTheme.cardShadow,
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Gradient banner cover at the top of the card
                        Container(
                          height: 80,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: _isAgentActive
                                  ? [
                                      AppTheme.primaryColor,
                                      const Color(0xFF0D3E12),
                                    ]
                                  : [
                                      const Color(0xFF475569),
                                      const Color(0xFF1E293B),
                                    ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Avatar, Name, Badges in a Row on mobile
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Avatar
                                  Stack(
                                    alignment: Alignment.bottomRight,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(2.5),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: _isAgentActive
                                                ? AppTheme.success
                                                : AppTheme.borderColor,
                                            width: 1.5,
                                          ),
                                        ),
                                        child: Container(
                                          width: 52,
                                          height: 52,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                AppTheme.primaryColor,
                                                AppTheme.primaryColor
                                                    .withOpacity(0.8),
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: AppTheme.primaryColor
                                                    .withOpacity(0.2),
                                                blurRadius: 6,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Center(
                                            child: Text(
                                              agentName.isNotEmpty
                                                  ? agentName[0].toUpperCase()
                                                  : 'S',
                                              style: GoogleFonts.outfit(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                                fontSize: 20,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      // Presence status glowing dot
                                      Positioned(
                                        right: 1,
                                        bottom: 1,
                                        child: Container(
                                          height: 12,
                                          width: 12,
                                          decoration: BoxDecoration(
                                            color: _isAgentActive
                                                ? AppTheme.success
                                                : AppTheme.textSecondary,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.white,
                                              width: 1.8,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 16),
                                  // Name & Badges
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          agentName,
                                          style: GoogleFonts.outfit(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w900,
                                            color: AppTheme.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 4,
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 3,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: AppTheme.primaryColor
                                                    .withOpacity(0.08),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                agentRole.toUpperCase(),
                                                style: GoogleFonts.outfit(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppTheme.primaryColor,
                                                ),
                                              ),
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 3,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: tierColor.withOpacity(
                                                  0.08,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                tierLabel,
                                                style: GoogleFonts.outfit(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                  color: tierColor,
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
                              const Divider(
                                height: 24,
                                color: AppTheme.borderColor,
                              ),

                              // Contact Details in a responsive wrap/grid
                              Wrap(
                                spacing: 20,
                                runSpacing: 10,
                                children: [
                                  SizedBox(
                                    width: isMobile ? double.infinity : 240,
                                    child: _buildDetailRow(
                                      'Email',
                                      agentEmail,
                                      Icons.email_outlined,
                                    ),
                                  ),
                                  SizedBox(
                                    width: isMobile ? double.infinity : 240,
                                    child: _buildDetailRow(
                                      'Phone',
                                      agentPhone,
                                      Icons.phone_outlined,
                                    ),
                                  ),
                                  SizedBox(
                                    width: isMobile ? double.infinity : 240,
                                    child: _buildDetailRow(
                                      'Presence',
                                      _isAgentActive ? 'Active Now' : 'Offline',
                                      Icons.sensors_outlined,
                                      valueColor: _isAgentActive
                                          ? AppTheme.success
                                          : AppTheme.textSecondary,
                                    ),
                                  ),
                                  SizedBox(
                                    width: isMobile ? double.infinity : 240,
                                    child: _buildDetailRow(
                                      'Status',
                                      isAgentBlocked ? 'Blocked' : 'Active',
                                      Icons.lock_outline,
                                      valueColor: isAgentBlocked
                                          ? AppTheme.error
                                          : AppTheme.success,
                                    ),
                                  ),
                                ],
                              ),

                              const Divider(
                                height: 24,
                                color: AppTheme.borderColor,
                              ),

                              // Quick CTAs & Action buttons in a single Row
                              Row(
                                children: [
                                  _buildRoundCtaButton(
                                    Icons.phone_in_talk_outlined,
                                    Colors.blue,
                                    () => _launchUrl('tel:$agentPhone'),
                                    'Call',
                                  ),
                                  const SizedBox(width: 8),
                                  _buildRoundCtaButton(
                                    FontAwesomeIcons.whatsapp,
                                    Colors.green,
                                    () {
                                      final cleanPhone = agentPhone.replaceAll(
                                        RegExp(r'[^0-9]'),
                                        '',
                                      );
                                      final waPhone =
                                          cleanPhone.startsWith('91')
                                          ? cleanPhone
                                          : '91$cleanPhone';
                                      _launchUrl('https://wa.me/$waPhone');
                                    },
                                    'WhatsApp',
                                  ),
                                  const SizedBox(width: 8),
                                  _buildRoundCtaButton(
                                    Icons.alternate_email_outlined,
                                    Colors.indigo,
                                    () => _launchUrl('mailto:$agentEmail'),
                                    'Email',
                                  ),
                                  const Spacer(),
                                  // Edit & Delete
                                  TextButton.icon(
                                    onPressed: () =>
                                        _showSalesAgentFormDialog(_agent!),
                                    icon: const Icon(
                                      Icons.edit_outlined,
                                      size: 14,
                                    ),
                                    label: Text(
                                      'Edit',
                                      style: GoogleFonts.outfit(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.blue,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 8,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(6),
                                        side: const BorderSide(
                                          color: Colors.blue,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  TextButton.icon(
                                    onPressed: () =>
                                        _deleteSalesAgent(agentId, agentName),
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      size: 14,
                                    ),
                                    label: Text(
                                      'Delete',
                                      style: GoogleFonts.outfit(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                    style: TextButton.styleFrom(
                                      foregroundColor: AppTheme.error,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 8,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(6),
                                        side: const BorderSide(
                                          color: AppTheme.error,
                                        ),
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
                  )
                : Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: AppTheme.cardShadow,
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Gradient banner cover at the top of the card
                        Stack(
                          alignment: Alignment.bottomCenter,
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              height: 100,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: _isAgentActive
                                      ? [
                                          AppTheme.primaryColor,
                                          const Color(0xFF0D3E12),
                                        ]
                                      : [
                                          const Color(0xFF475569),
                                          const Color(0xFF1E293B),
                                        ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: -40,
                              child: Stack(
                                alignment: Alignment.bottomRight,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(3.5),
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Container(
                                      width: 80,
                                      height: 80,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            AppTheme.primaryColor,
                                            AppTheme.primaryColor.withOpacity(
                                              0.8,
                                            ),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppTheme.primaryColor
                                                .withOpacity(0.2),
                                            blurRadius: 8,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      child: Center(
                                        child: Text(
                                          agentName.isNotEmpty
                                              ? agentName[0].toUpperCase()
                                              : 'S',
                                          style: GoogleFonts.outfit(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                            fontSize: 32,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Presence glowing dot
                                  Positioned(
                                    right: 2,
                                    bottom: 2,
                                    child: Container(
                                      height: 18,
                                      width: 18,
                                      decoration: BoxDecoration(
                                        color: _isAgentActive
                                            ? AppTheme.success
                                            : AppTheme.textSecondary,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 2.5,
                                        ),
                                        boxShadow: _isAgentActive
                                            ? [
                                                BoxShadow(
                                                  color: AppTheme.success
                                                      .withOpacity(0.4),
                                                  blurRadius: 6,
                                                  spreadRadius: 2,
                                                ),
                                              ]
                                            : null,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 50),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Center(
                                child: Column(
                                  children: [
                                    Text(
                                      agentName,
                                      style: GoogleFonts.outfit(
                                        fontSize: 19,
                                        fontWeight: FontWeight.w900,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 3.5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppTheme.primaryColor
                                                .withOpacity(0.08),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Text(
                                            agentRole.toUpperCase(),
                                            style: GoogleFonts.outfit(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.primaryColor,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 3.5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: tierColor.withOpacity(0.08),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.stars,
                                                size: 12,
                                                color: tierColor,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                tierLabel,
                                                style: GoogleFonts.outfit(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: tierColor,
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
                              const Divider(
                                height: 32,
                                color: AppTheme.borderColor,
                              ),

                              // Contact channels & values
                              _buildDetailRow(
                                'Email Address',
                                agentEmail,
                                Icons.email_outlined,
                              ),
                              const SizedBox(height: 14),
                              _buildDetailRow(
                                'Phone Number',
                                agentPhone,
                                Icons.phone_outlined,
                              ),
                              const SizedBox(height: 14),
                              _buildDetailRow(
                                'Presence Status',
                                _isAgentActive ? 'Active Now' : 'Offline',
                                Icons.sensors_outlined,
                                valueColor: _isAgentActive
                                    ? AppTheme.success
                                    : AppTheme.textSecondary,
                              ),
                              const SizedBox(height: 14),
                              _buildDetailRow(
                                'Account Status',
                                isAgentBlocked
                                    ? 'Suspended/Blocked'
                                    : 'Active/Healthy',
                                Icons.lock_outline,
                                valueColor: isAgentBlocked
                                    ? AppTheme.error
                                    : AppTheme.success,
                              ),
                              const SizedBox(height: 14),
                              _buildDetailRow(
                                'System Access',
                                createdAtStr,
                                Icons.history,
                              ),

                              const SizedBox(height: 24),
                              // CTA Communication actions
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  _buildRoundCtaButton(
                                    Icons.phone_in_talk_outlined,
                                    Colors.blue,
                                    () => _launchUrl('tel:$agentPhone'),
                                    'Call Agent',
                                  ),
                                  _buildRoundCtaButton(
                                    FontAwesomeIcons.whatsapp,
                                    Colors.green,
                                    () {
                                      final cleanPhone = agentPhone.replaceAll(
                                        RegExp(r'[^0-9]'),
                                        '',
                                      );
                                      final waPhone =
                                          cleanPhone.startsWith('91')
                                          ? cleanPhone
                                          : '91$cleanPhone';
                                      _launchUrl('https://wa.me/$waPhone');
                                    },
                                    'WhatsApp',
                                  ),
                                  _buildRoundCtaButton(
                                    Icons.alternate_email_outlined,
                                    Colors.indigo,
                                    () => _launchUrl('mailto:$agentEmail'),
                                    'Email',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: const Divider(
                            height: 36,
                            color: AppTheme.borderColor,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(
                            left: 20,
                            right: 20,
                            bottom: 20,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextButton.icon(
                                  onPressed: () =>
                                      _showSalesAgentFormDialog(_agent!),
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 16,
                                  ),
                                  label: Text(
                                    'Edit Details',
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.blue,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      side: const BorderSide(
                                        color: Colors.blue,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextButton.icon(
                                  onPressed: () =>
                                      _deleteSalesAgent(agentId, agentName),
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 16,
                                  ),
                                  label: Text(
                                    'Delete Agent',
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppTheme.error,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      side: const BorderSide(
                                        color: AppTheme.error,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );

            // --- ADVANCED PERFORMANCE STATS GRID ---
            final Widget advancedStatsSection = SelectionContainer.disabled(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final double spacing = 14.0;
                  int columns = 1;
                  if (isMobile) {
                    columns = 2;
                  } else if (isTablet) {
                    columns = 2;
                  } else {
                    columns = 4;
                  }
                  final double width =
                      (constraints.maxWidth - (spacing * (columns - 1))) /
                      columns;

                  return Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: [
                      AdvancedStatCardWidget(
                        width: width,
                        title: 'Sales Value',
                        value: _formatCurrency(cumulativeRevenue),
                        color: Colors.green,
                        trendLabel: 'Cumulative Sales',
                        trendIcon: Icons.payments_outlined,
                        visualWidget: SizedBox(
                          width: 28,
                          height: 28,
                          child: CustomPaint(
                            painter: FulfillmentProgressPainter(
                              cumulativeRevenue >= 1000000.0
                                  ? 1.0
                                  : cumulativeRevenue / 1000000.0,
                              Colors.green,
                            ),
                          ),
                        ),
                      ),
                      AdvancedStatCardWidget(
                        width: width,
                        title: 'Onboarded Portfolio',
                        value:
                            '${assignedLeads.length + assignedDealers.length} Clients',
                        color: Colors.blue,
                        trendLabel:
                            'Leads (${assignedLeads.length}) • Dealers (${assignedDealers.length})',
                        trendIcon: Icons.groups_outlined,
                        visualWidget: SizedBox(
                          width: 50,
                          height: 24,
                          child: CustomPaint(
                            painter: SparklinePainter([
                              10,
                              12,
                              9,
                              15,
                              13,
                              17,
                              (assignedLeads.length + assignedDealers.length)
                                  .toDouble(),
                            ], Colors.blue),
                          ),
                        ),
                      ),
                      AdvancedStatCardWidget(
                        width: width,
                        title: 'Total Bookings',
                        value: '${agentOrders.length} Orders',
                        color: Colors.indigo,
                        trendLabel:
                            'AOV: ${_formatCurrency(averageOrderValue)}',
                        trendIcon: Icons.shopping_bag_outlined,
                        visualWidget: SizedBox(
                          width: 28,
                          height: 28,
                          child: CustomPaint(
                            painter: FulfillmentProgressPainter(
                              agentOrders.isEmpty
                                  ? 0.0
                                  : (agentOrders.length / 50.0).clamp(0.0, 1.0),
                              Colors.indigo,
                            ),
                          ),
                        ),
                      ),
                      AdvancedStatCardWidget(
                        width: width,
                        title: 'Conversion Rate',
                        value: '${conversionRate.toStringAsFixed(1)}%',
                        color: Colors.teal,
                        trendLabel: 'Dealers / Total Portfolio',
                        trendIcon: Icons.verified_user_outlined,
                        visualWidget: SizedBox(
                          width: 50,
                          height: 24,
                          child: CustomPaint(
                            painter: SparklinePainter([
                              0,
                              10,
                              20,
                              15,
                              30,
                              25,
                              conversionRate,
                            ], Colors.teal),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            );

            // --- TARGET PROGRESS TRACKER ---
            final Widget targetTrackerCard = Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderColor),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Monthly Performance Targets',
                        style: GoogleFonts.outfit(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'July 2026',
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Target 1: Revenue (Target: 5L)
                  _buildLinearTargetTracker(
                    'Revenue Booking Target',
                    cumulativeRevenue,
                    500000.0, // 5 Lakh
                    isCurrency: true,
                    barColor: AppTheme.primaryColor,
                  ),
                  const SizedBox(height: 18),
                ],
              ),
            );

            // --- SEGMENTED TABS CONTROLLER ---
            final Widget tabContainer = Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: AppTheme.cardShadow,
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildTabItem(
                      0,
                      'Overview & Analytics',
                      Icons.analytics_outlined,
                    ),
                    _buildTabItem(
                      1,
                      'Client Portfolio (${assignedLeads.length + assignedDealers.length})',
                      Icons.groups_outlined,
                    ),
                    _buildTabItem(
                      2,
                      'Orders History (${agentOrders.length})',
                      Icons.shopping_bag_outlined,
                    ),
                    _buildTabItem(3, 'Activity Logs', Icons.history),
                    _buildTabItem(4, 'Admin Notes', Icons.rate_review_outlined),
                  ],
                ),
              ),
            );

            // --- TAB DETAILS BUILDER ---
            Widget buildTabDetails() {
              if (_activeTab == 0) {
                // OVERVIEW & ANALYTICS
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    targetTrackerCard,
                    const SizedBox(height: 20),

                    // Sales Distribution insight row
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.insights,
                                size: 18,
                                color: AppTheme.primaryColor,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Performance Insights & Intelligence',
                                style: GoogleFonts.outfit(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text(
                            _getAgentInsightText(
                              cumulativeRevenue,
                              conversionRate,
                              assignedDealers.length,
                            ),
                            style: GoogleFonts.outfit(
                              fontSize: 12.5,
                              color: AppTheme.textBody,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildMiniInsightStat(
                                'Total Clients',
                                '${assignedLeads.length + assignedDealers.length}',
                              ),
                              _buildMiniInsightStat(
                                'High Value Dealers',
                                '$highValueDealersCount',
                              ),
                              _buildMiniInsightStat(
                                'Avg. Order Value',
                                _formatCurrency(averageOrderValue),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              } else if (_activeTab == 1) {
                // CLIENT PORTFOLIO (Leads + Dealers combined with filter)
                final List<Map<String, dynamic>> combinedPortfolio = [
                  ...assignedLeads,
                  ...assignedDealers,
                ];

                final filteredPortfolio = combinedPortfolio.where((u) {
                  final isVerified = u['kycStatus'] == 'verified';
                  if (_clientSegmentFilter == 'Leads' && isVerified)
                    return false;
                  if (_clientSegmentFilter == 'Dealers' && !isVerified)
                    return false;

                  final name = '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'
                      .toLowerCase();
                  final shop = (u['shopName'] ?? '').toLowerCase();
                  final phone = (u['phoneNumber'] ?? '').toLowerCase();
                  final query = _leadSearchQuery.toLowerCase();

                  return name.contains(query) ||
                      shop.contains(query) ||
                      phone.contains(query);
                }).toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Search & Segment Selector Row
                    Row(
                      children: [
                        Expanded(
                          flex: isMobile ? 1 : 2,
                          child: _buildTabSearchBar(
                            _leadSearchController,
                            'Search by client name, shop or phone...',
                            _leadSearchQuery,
                            (val) => setState(() => _leadSearchQuery = val),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Segment selection chips
                        Row(
                          children: ['All', 'Leads', 'Dealers'].map((filter) {
                            final isSel = _clientSegmentFilter == filter;
                            return Container(
                              margin: const EdgeInsets.only(left: 6),
                              child: ChoiceChip(
                                label: Text(
                                  filter,
                                  style: GoogleFonts.outfit(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    color: isSel
                                        ? Colors.white
                                        : AppTheme.textSecondary,
                                  ),
                                ),
                                selected: isSel,
                                onSelected: (selected) {
                                  if (selected) {
                                    setState(() {
                                      _clientSegmentFilter = filter;
                                    });
                                  }
                                },
                                selectedColor: AppTheme.primaryColor,
                                backgroundColor: const Color(0xFFF3F4F6),
                                side: BorderSide.none,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (filteredPortfolio.isEmpty)
                      _buildEmptyState('No matching portfolio clients found')
                    else ...[
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filteredPortfolio.length > _portfolioLimit
                            ? _portfolioLimit
                            : filteredPortfolio.length,
                        itemBuilder: (context, idx) {
                          final u = filteredPortfolio[idx];
                          final name =
                              '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'
                                  .trim();
                          final shop = u['shopName'] ?? '-';
                          final phone = u['phoneNumber'] ?? '-';
                          final isVerified = u['kycStatus'] == 'verified';
                          final clientStatus =
                              u['status'] ?? u['leadStatus'] ?? 'prospect';

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            elevation: 0,
                            color: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: const BorderSide(
                                color: AppTheme.borderColor,
                              ),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isVerified
                                    ? Colors.teal.withOpacity(0.08)
                                    : AppTheme.primaryColor.withOpacity(0.08),
                                radius: 18,
                                child: Icon(
                                  isVerified
                                      ? Icons.storefront
                                      : Icons.person_outline,
                                  size: 18,
                                  color: isVerified
                                      ? Colors.teal
                                      : AppTheme.primaryColor,
                                ),
                              ),
                              title: Text(
                                name.isNotEmpty ? name : 'Unnamed Client',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              subtitle: Text(
                                'Shop: $shop • Phone: $phone',
                                style: GoogleFonts.outfit(
                                  fontSize: 11.5,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildBadge(
                                    isVerified
                                        ? 'DEALER'
                                        : clientStatus.toUpperCase(),
                                    isVerified ? Colors.teal : Colors.blue,
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.chevron_right,
                                    size: 16,
                                    color: AppTheme.textSecondary,
                                  ),
                                ],
                              ),
                              onTap: () {
                                if (isVerified) {
                                  Navigator.pushNamed(
                                    context,
                                    '/dealers/profile',
                                    arguments: _mapUserToDealer(
                                      u,
                                      ordersState.orders,
                                    ),
                                  );
                                } else {
                                  Navigator.pushNamed(
                                    context,
                                    '/leads/profile',
                                    arguments: _mapUserToLead(u),
                                  );
                                }
                              },
                            ),
                          );
                        },
                      ),
                      if (filteredPortfolio.length > _portfolioLimit)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Center(
                            child: TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _portfolioLimit += 15;
                                });
                              },
                              icon: const Icon(
                                Icons.add,
                                size: 16,
                                color: AppTheme.primaryColor,
                              ),
                              label: Text(
                                'Show More (${filteredPortfolio.length - _portfolioLimit} remaining)',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ],
                );
              } else if (_activeTab == 2) {
                // ORDERS HISTORY
                final filteredOrders = agentOrders.where((o) {
                  final orderNo = o.orderId.toLowerCase();
                  final clientName = o.customerName.toLowerCase();
                  final query = _orderSearchQuery.toLowerCase();
                  return orderNo.contains(query) || clientName.contains(query);
                }).toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTabSearchBar(
                      _orderSearchController,
                      'Search orders by Order ID or Client name...',
                      _orderSearchQuery,
                      (val) => setState(() => _orderSearchQuery = val),
                    ),
                    const SizedBox(height: 16),
                    if (filteredOrders.isEmpty)
                      _buildEmptyState('No orders found matching query')
                    else ...[
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filteredOrders.length > _ordersLimit
                            ? _ordersLimit
                            : filteredOrders.length,
                        itemBuilder: (context, idx) {
                          final o = filteredOrders[idx];
                          final orderNo = o.orderId;
                          final clientName = o.customerName;
                          final amount = o.totalAmount;
                          final status = o.orderStatus;
                          final dateStr = _formatTimeAgo(
                            o.placedAt.toIso8601String(),
                          );

                          Color statusColor = Colors.orange;
                          if (status.toLowerCase() == 'completed' ||
                              status.toLowerCase() == 'delivered') {
                            statusColor = Colors.green;
                          } else if (status.toLowerCase() == 'cancelled') {
                            statusColor = AppTheme.error;
                          }

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            elevation: 0,
                            color: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: const BorderSide(
                                color: AppTheme.borderColor,
                              ),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.indigo.withOpacity(
                                  0.08,
                                ),
                                radius: 18,
                                child: const Icon(
                                  Icons.shopping_bag_outlined,
                                  size: 18,
                                  color: Colors.indigo,
                                ),
                              ),
                              title: Text(
                                'Order #$orderNo',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              subtitle: Text(
                                'Client: $clientName • $dateStr',
                                style: GoogleFonts.outfit(
                                  fontSize: 11.5,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        _formatCurrency(amount),
                                        style: GoogleFonts.outfit(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: AppTheme.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      _buildBadge(
                                        status.toUpperCase(),
                                        statusColor,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.chevron_right,
                                    size: 16,
                                    color: AppTheme.textSecondary,
                                  ),
                                ],
                              ),
                              onTap: () {
                                Navigator.pushNamed(
                                  context,
                                  '/orders/details',
                                  arguments: o,
                                );
                              },
                            ),
                          );
                        },
                      ),
                      if (filteredOrders.length > _ordersLimit)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Center(
                            child: TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _ordersLimit += 15;
                                });
                              },
                              icon: const Icon(
                                Icons.add,
                                size: 16,
                                color: AppTheme.primaryColor,
                              ),
                              label: Text(
                                'Show More (${filteredOrders.length - _ordersLimit} remaining)',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ],
                );
              } else if (_activeTab == 3) {
                // ACTIVITY LOGS
                final salesLogs = _agentEvents
                    .where((e) => e['isAudit'] != true)
                    .toList();
                final auditLogs = _agentEvents
                    .where((e) => e['isAudit'] == true)
                    .toList();
                final currentLogs = _activeLogSubTab == 0
                    ? salesLogs
                    : auditLogs;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            ChoiceChip(
                              label: Text(
                                'Sales Activities',
                                style: GoogleFonts.outfit(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: _activeLogSubTab == 0
                                      ? Colors.white
                                      : AppTheme.textSecondary,
                                ),
                              ),
                              selected: _activeLogSubTab == 0,
                              onSelected: (selected) {
                                if (selected)
                                  setState(() => _activeLogSubTab = 0);
                              },
                              selectedColor: AppTheme.primaryColor,
                              backgroundColor: const Color(0xFFF3F4F6),
                              side: BorderSide.none,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: Text(
                                'Admin Logs',
                                style: GoogleFonts.outfit(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: _activeLogSubTab == 1
                                      ? Colors.white
                                      : AppTheme.textSecondary,
                                ),
                              ),
                              selected: _activeLogSubTab == 1,
                              onSelected: (selected) {
                                if (selected)
                                  setState(() => _activeLogSubTab = 1);
                              },
                              selectedColor: AppTheme.primaryColor,
                              backgroundColor: const Color(0xFFF3F4F6),
                              side: BorderSide.none,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.refresh,
                            size: 18,
                            color: AppTheme.primaryColor,
                          ),
                          onPressed: _fetchAgentEvents,
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    if (_isLoadingEvents)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(40.0),
                          child: CircularProgressIndicator(
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      )
                    else if (currentLogs.isEmpty)
                      _buildEmptyState(
                        _activeLogSubTab == 0
                            ? 'No recent sales activities found'
                            : 'No recent admin logs found',
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: currentLogs.length > _eventsLimit
                            ? _eventsLimit
                            : currentLogs.length,
                        itemBuilder: (context, idx) {
                          final displayCount = currentLogs.length > _eventsLimit
                              ? _eventsLimit
                              : currentLogs.length;
                          final ev = currentLogs[idx];
                          final eventName =
                              ev['event'] ?? ev['eventType'] ?? 'system_action';
                          final timestamp = ev['timestamp'] ?? '';
                          final props =
                              (ev['properties'] ?? ev['payload']) as Map? ?? {};
                          final details =
                              props['details'] ??
                              props['screen'] ??
                              ev['details'] ??
                              '';
                          final isAudit = ev['isAudit'] == true;

                          // Timeline visuals
                          IconData eventIcon = Icons.settings_ethernet;
                          Color eventColor = Colors.grey;

                          if (isAudit) {
                            eventIcon = Icons.security_rounded;
                            eventColor = Colors.deepOrange;
                          } else {
                            if (eventName.toString().toLowerCase().contains(
                              'login',
                            )) {
                              eventIcon = Icons.login;
                              eventColor = Colors.green;
                            } else if (eventName
                                .toString()
                                .toLowerCase()
                                .contains('order')) {
                              eventIcon = Icons.shopping_cart;
                              eventColor = Colors.teal;
                            } else if (eventName
                                .toString()
                                .toLowerCase()
                                .contains('profile')) {
                              eventIcon = Icons.visibility;
                              eventColor = Colors.blue;
                            }
                          }

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: eventColor.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      eventIcon,
                                      size: 16,
                                      color: eventColor,
                                    ),
                                  ),
                                  if (idx != displayCount - 1)
                                    Container(
                                      width: 2,
                                      height: 48,
                                      color: AppTheme.borderColor,
                                    ),
                                ],
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          eventName
                                              .toString()
                                              .toUpperCase()
                                              .replaceAll('_', ' '),
                                          style: GoogleFonts.outfit(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.textPrimary,
                                          ),
                                        ),
                                        if (isAudit) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.deepOrange
                                                  .withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              'AUDIT',
                                              style: GoogleFonts.outfit(
                                                fontSize: 8,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.deepOrange,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    if (details.toString().isNotEmpty)
                                      Text(
                                        details.toString(),
                                        style: GoogleFonts.outfit(
                                          fontSize: 11.5,
                                          color: AppTheme.textSecondary,
                                        ),
                                      ),
                                    const SizedBox(height: 4),
                                    Text(
                                      timestamp.isNotEmpty
                                          ? _formatTimeAgo(timestamp)
                                          : '-',
                                      style: GoogleFonts.outfit(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    if (currentLogs.length > _eventsLimit)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Center(
                          child: TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _eventsLimit += 15;
                              });
                            },
                            icon: const Icon(
                              Icons.add,
                              size: 16,
                              color: AppTheme.primaryColor,
                            ),
                            label: Text(
                              'Show More (${currentLogs.length - _eventsLimit} remaining)',
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                        ),
                      ), // SelectionContainer.disabled
                  ],
                );
              } else {
                // ADMIN NOTES & PRIVATE LOGS
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Private Administrative Notes',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Write notes regarding commission rates, evaluations, tier adjustments, and internal audits. These notes are only visible to system admins.',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _notesController,
                      maxLines: 8,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: AppTheme.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Enter notes here...',
                        hintStyle: GoogleFonts.outfit(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
                        fillColor: const Color(0xFFF9FAFB),
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppTheme.borderColor,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        onPressed: _isSavingNotes ? null : _saveAgentNotes,
                        icon: _isSavingNotes
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save_outlined, size: 16),
                        label: Text(
                          'Save Private Notes',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }
            }

            // --- PAGE SCAFFOLD IMPLEMENTATION ---
            return Scaffold(
              backgroundColor: const Color(0xFFF8FAFC),
              body: SelectionArea(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 16 : 32,
                    vertical: isMobile ? 16 : 24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Breadcrumb Nav Bar
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back, size: 20),
                            color: AppTheme.textPrimary,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Team Management',
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.chevron_right,
                            size: 16,
                            color: AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            agentName,
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Responsive Layout Builder
                      if (!isMobile && !isTablet)
                        // Desktop side-by-side
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(width: 320, child: profileHeroCard),
                            const SizedBox(width: 24),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  advancedStatsSection,
                                  const SizedBox(height: 24),
                                  tabContainer,
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: AppTheme.borderColor,
                                      ),
                                      boxShadow: AppTheme.cardShadow,
                                    ),
                                    child: buildTabDetails(),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      else
                        // Mobile/Tablet column stack
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            profileHeroCard,
                            const SizedBox(height: 20),
                            advancedStatsSection,
                            const SizedBox(height: 20),
                            tabContainer,
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppTheme.borderColor),
                                boxShadow: AppTheme.cardShadow,
                              ),
                              child: buildTabDetails(),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailRow(
    String label,
    String value,
    IconData icon, {
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.textSecondary),
        const SizedBox(width: 10),
        Text(
          '$label:',
          style: GoogleFonts.outfit(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.outfit(
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: valueColor ?? AppTheme.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRoundCtaButton(
    dynamic icon,
    Color color,
    VoidCallback onTap,
    String tooltip,
  ) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: color.withOpacity(0.08),
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(100),
          child: Container(
            padding: const EdgeInsets.all(12),
            child: icon is IconData
                ? Icon(icon, size: 18, color: color)
                : icon is FaIconData
                ? FaIcon(icon, size: 18, color: color)
                : const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }

  Widget _buildLinearTargetTracker(
    String label,
    double current,
    double target, {
    required bool isCurrency,
    required Color barColor,
  }) {
    final double pct = current >= target ? 1.0 : current / target;
    final int pctInt = (pct * 100).toInt();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            Text(
              '${isCurrency ? _formatCurrency(current) : current.toInt()} / ${isCurrency ? _formatCurrency(target) : target.toInt()} ($pctInt%)',
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: current >= target
                    ? AppTheme.success
                    : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Stack(
          children: [
            Container(
              height: 8,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(100),
              ),
            ),
            AnimatedFractionallySizedBox(
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeInOut,
              widthFactor: pct,
              child: Container(
                height: 8,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [barColor, barColor.withOpacity(0.65)],
                  ),
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMiniInsightStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.outfit(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: AppTheme.textSecondary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  String _getAgentInsightText(
    double revenue,
    double convRate,
    int dealerCount,
  ) {
    if (revenue >= 1000000 && convRate >= 60) {
      return "Excellent performer. High portfolio conversion with stellar revenue contributions. Onboarding speed is optimal.";
    } else if (revenue >= 500000) {
      return "Strong contributor. Healthy order frequencies. Consider focusing on converting more leads to dealers to boost transaction pipelines.";
    } else if (dealerCount == 0) {
      return "Agent has not onboarded any active dealers yet. Priorities should shift to completing pending KYC submissions for assigned leads.";
    } else {
      return "Moderate performance. Portfolio conversions are stable. Advise focusing on high-volume transactions to increase ticket sizes.";
    }
  }

  Widget _buildTabItem(int index, String label, IconData icon) {
    final isSelected = _activeTab == index;
    return InkWell(
      onTap: () => setState(() => _activeTab = index),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? Colors.white : AppTheme.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? Colors.white : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabSearchBar(
    TextEditingController controller,
    String hint,
    String query,
    Function(String) onChanged,
  ) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, size: 16, color: AppTheme.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
              onChanged: onChanged,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: GoogleFonts.outfit(
                  fontSize: 12.5,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w400,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (query.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear, size: 14),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () {
                controller.clear();
                onChanged('');
              },
            ),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: GoogleFonts.outfit(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildEmptyState(String msg) {
    return Container(
      height: 120,
      alignment: Alignment.center,
      child: Text(
        msg,
        style: GoogleFonts.outfit(
          color: AppTheme.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
