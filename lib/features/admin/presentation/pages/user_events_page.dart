import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shimmer/shimmer.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/dealers_bloc.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/leads_bloc.dart';
import 'package:kd_pannel/app_theme.dart';
import 'package:kd_pannel/core/responsive/responsive.dart';
import 'package:kd_pannel/util/dealers.dart';
import 'package:kd_pannel/core/services/analytics_service.dart';
import 'package:kd_pannel/core/network/websocket_service.dart';

import 'package:url_launcher/url_launcher.dart';
import 'package:kd_pannel/features/shared/widgets/whatsapp_chat_dialog.dart';
import 'package:kd_pannel/features/marketing/presentation/widgets/funnel_chart_widget.dart';
import 'package:kd_pannel/features/marketing/presentation/widgets/agri_heatmap_widget.dart';
import 'package:kd_pannel/core/services/pincode_service.dart';
import '../../../../core/auth/auth_service.dart';
import '../bloc/dealers_state.dart';
import '../bloc/leads_state.dart';

class UserEventsPage extends StatefulWidget {
  const UserEventsPage({super.key});

  @override
  State<UserEventsPage> createState() => _UserEventsPageState();
}

class _UserEventsPageState extends State<UserEventsPage> {
  int _activeAnalyticsTab = 0; // 0: Funnel & Overview, 1: Retention Cohorts, 2: District Heatmap, 3: Activity Stream
  String _selectedAnalyticsTimeRange = 'Last 30 Days'; // 'Today', 'Last 7 Days', 'Last 30 Days', 'All Time'
  String? _selectedUser;
  String? _selectedEventType;
  String _searchQuery = '';
  String _userSearchQuery = '';
  String _selectedUserType = 'All'; // 'All', 'Dealer', 'Lead', 'Guest'
  String _selectedPriority = 'All'; // 'All', 'High Priority'
  String _selectedMetricFilter =
      'All'; // 'All', 'High Priority', 'Abandoned Carts', 'Failed Payments', 'Live Users'
  String _selectedEventCategory = 'All'; // 'All' or specific category ID (e.g., 'add_to_cart')

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _userSearchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _userCardKeys = {};

  // Database event state variables
  bool _isLoading = true;
  bool _isLoadingEvents = false;
  bool _isBackgroundLoading = false;
  bool _isLoadingRealTime = false;
  bool _isFallbackMode = false;
  String? _nextCursor;
  bool _isLoadingMore = false;
  int _globalHighPriorityCount = 0;
  int _globalFailedPaymentsCount = 0;
  int _globalAbandonedCartsCount = 0;
  Map<String, List<Map<String, dynamic>>> _eventsLogs = {};
  final Set<String> _processedEventIds = {};
  final Set<String> _mergedOrderIds = {};
  final Set<String> _mergedUserIds = {};
  Map<String, String> _nameToId = {};
  List<Map<String, dynamic>> _realTimeUsers = [];
  Timer? _realTimeTimer;
  Timer? _eventsRefreshDebounce;
  Timer? _searchDebounce;
  StreamSubscription? _presenceSubscription;

  // Cached telemetry variables for optimal performance
  List<String> _cachedUsersWithEvents = [];
  Map<String, bool> _cachedHighPriority = {};
  Map<String, String> _cachedPriorityReason = {};
  Map<String, DateTime> _cachedMostRecentEventTimes = {};
  Map<String, Map<String, List<Map<String, dynamic>>>> _cachedUserEventsGrouped = {};
  Map<String, String> _cachedUserTypes = {};
  final Set<String> _onlineUserKeys = {};
  final Set<String> _loadingUserEvents = {};

  final Map<String, List<Map<String, dynamic>>> _perUserEventsCache = {};
  Future<List<Map<String, dynamic>>>? _funnelDataFuture;
  Future<List<Map<String, dynamic>>>? _districtDataFuture;
  DateTimeRange? _customAnalyticsDateRange;

  String _formatAnalyticsDateLabel() {
    if (_selectedAnalyticsTimeRange == 'Custom Range' && _customAnalyticsDateRange != null) {
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final start = _customAnalyticsDateRange!.start;
      final end = _customAnalyticsDateRange!.end;
      return '${start.day} ${months[start.month - 1]} - ${end.day} ${months[end.month - 1]}';
    }
    return _selectedAnalyticsTimeRange;
  }

  @override
  void initState() {
    super.initState();
    PincodeService().init();
    _scrollController.addListener(_onScroll);
    _loadEvents();
    _startRealTimePoll();
    _listenToLivePresence();
  }

  void _onScroll() {
    if (!AuthService().isSales &&
        _scrollController.hasClients &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 350 &&
        !_isLoadingMore &&
        _nextCursor != null) {
      _loadMoreEvents();
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleanPhone.isEmpty) return;
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _openWhatsAppChat(String phoneNumber, String recipientName) {
    showDialog(
      context: context,
      builder: (context) => WhatsAppChatDialog(
        phone: phoneNumber,
        name: recipientName,
      ),
    );
  }

  String _normalizeId(dynamic id) {
    if (id == null) return '';
    if (id is String) return id;
    if (id is Map) {
      if (id['\$oid'] != null) return id['\$oid'].toString();
      if (id['_id'] != null) return _normalizeId(id['_id']);
    }
    return id.toString();
  }

  Set<String>? _cachedAssignedUserKeys;
  Map<String, String>? _cachedUserTypeLookup;
  Map<String, String> _cachedUserSearchIndex = {};

  DealersState? _lastDealersState;
  LeadsState? _lastLeadsState;

  void _buildUserLookupIndexes() {
    final dealersState = context.read<DealersBloc>().state;
    final leadsState = context.read<LeadsBloc>().state;

    if (_lastDealersState == dealersState && _lastLeadsState == leadsState && _cachedAssignedUserKeys != null) {
      return;
    }
    
    _lastDealersState = dealersState;
    _lastLeadsState = leadsState;

    final Set<String> assignedKeys = {};
    final Map<String, String> typeLookup = {};

    final currentUserId = AuthService().currentUserId;
    final currentUserEmail = AuthService().currentUserEmail;

    bool isRawUserAssigned(Map<String, dynamic> u) {
      if (!AuthService().isSales) return true;
      if (currentUserId == null && currentUserEmail == null) return false;
      final assignedAgent = u['assignedAgent'];
      final assignedAgentId = u['assignedAgentId']?.toString();
      if (assignedAgentId != null && assignedAgentId.isNotEmpty) {
        return assignedAgentId == currentUserId || assignedAgentId == currentUserEmail;
      }
      if (assignedAgent != null) {
        if (assignedAgent is Map) {
          final agentId = _normalizeId(assignedAgent['_id'] ?? assignedAgent['\$oid'] ?? assignedAgent);
          final agentEmail = assignedAgent['email']?.toString();
          return agentId == currentUserId || (agentEmail != null && agentEmail == currentUserEmail);
        } else if (assignedAgent is String) {
          return assignedAgent == currentUserId || assignedAgent == currentUserEmail;
        }
      }
      return true;
    }

    void indexUser(Map<String, dynamic> u, {String? defaultType}) {
      final uId = _normalizeId(u['_id']).toLowerCase();
      final uEmail = (u['email'] ?? '').toString().toLowerCase();
      final uPhone = (u['phoneNumber'] ?? u['phone'] ?? '').toString().toLowerCase();
      final uName = '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'.trim().toLowerCase();
      final uShop = (u['shopName'] ?? '').toString().toLowerCase();
      final kycStatus = u['kycStatus']?.toString().toLowerCase() ?? 'pending';
      final type = defaultType ?? ((kycStatus == 'verified') ? 'Dealer' : 'Lead');

      if (uId.isNotEmpty) typeLookup[uId] ??= type;
      if (uEmail.isNotEmpty) typeLookup[uEmail] ??= type;
      if (uPhone.isNotEmpty) typeLookup[uPhone] ??= type;
      if (uName.isNotEmpty) typeLookup[uName] ??= type;
      if (uShop.isNotEmpty) typeLookup[uShop] ??= type;

      if (isRawUserAssigned(u)) {
        if (uId.isNotEmpty) assignedKeys.add(uId);
        if (uEmail.isNotEmpty) assignedKeys.add(uEmail);
        if (uPhone.isNotEmpty) assignedKeys.add(uPhone);
        if (uName.isNotEmpty) assignedKeys.add(uName);
        if (uShop.isNotEmpty) assignedKeys.add(uShop);
      }
    }

    try {
      final dealersState = context.read<DealersBloc>().state;
      for (final u in dealersState.allRawUsers) {
        indexUser(u, defaultType: 'Dealer');
      }
    } catch (_) {}

    try {
      final leadsState = context.read<LeadsBloc>().state;
      for (final u in leadsState.allRawUsers) {
        indexUser(u, defaultType: 'Lead');
      }
    } catch (_) {}

    _cachedAssignedUserKeys = assignedKeys;
    _cachedUserTypeLookup = typeLookup;
  }

  bool _isUserAssignedToCurrentSalesAgent({
    required String rawUser,
    String? displayName,
    String? displayPhone,
    Map<String, dynamic>? userDetails,
  }) {
    if (!AuthService().isSales) return true;

    final currentUserId = AuthService().currentUserId;
    final currentUserEmail = AuthService().currentUserEmail;
    if (currentUserId == null && currentUserEmail == null) return false;

    // 1. Direct check in userDetails / event if assignedAgent info is present
    if (userDetails != null) {
      final assignedAgent = userDetails['assignedAgent'];
      final assignedAgentId = userDetails['assignedAgentId']?.toString();
      if (assignedAgentId != null && assignedAgentId.isNotEmpty) {
        if (assignedAgentId == currentUserId || assignedAgentId == currentUserEmail) {
          return true;
        }
      }
      if (assignedAgent != null) {
        if (assignedAgent is Map) {
          final agentId = _normalizeId(assignedAgent['_id'] ?? assignedAgent['\$oid'] ?? assignedAgent);
          final agentEmail = assignedAgent['email']?.toString();
          if (agentId == currentUserId || (agentEmail != null && agentEmail == currentUserEmail)) {
            return true;
          }
        } else if (assignedAgent is String) {
          if (assignedAgent == currentUserId || assignedAgent == currentUserEmail) {
            return true;
          }
        }
      }
    }

    if (_cachedAssignedUserKeys == null) {
      _buildUserLookupIndexes();
    }

    final keys = _cachedAssignedUserKeys!;
    final rawUserLower = rawUser.trim().toLowerCase();
    final nameLower = displayName?.trim().toLowerCase() ?? '';
    final phoneLower = displayPhone?.trim().toLowerCase() ?? '';

    if (rawUserLower.isNotEmpty && keys.contains(rawUserLower)) return true;
    if (nameLower.isNotEmpty && keys.contains(nameLower)) return true;
    if (phoneLower.isNotEmpty && keys.contains(phoneLower)) return true;

    return false;
  }

  int _lastOrdersCount = -1;
  int _lastDealersCount = -1;
  int _lastLeadsCount = -1;

  void _mergeSalesCustomerEventsIntoLogs() {
    try {
      final dealersState = context.read<DealersBloc>().state;
      final leadsState = context.read<LeadsBloc>().state;

      // Only re-process if counts changed or it's the first time
      if (_lastOrdersCount == dealersState.allRawOrders.length &&
          _lastDealersCount == dealersState.allRawUsers.length &&
          _lastLeadsCount == leadsState.allRawUsers.length &&
          _eventsLogs.isNotEmpty) {
        // We still might need to merge if _eventsLogs was cleared, but usually it's fine
      }
      
      _lastOrdersCount = dealersState.allRawOrders.length;
      _lastDealersCount = dealersState.allRawUsers.length;
      _lastLeadsCount = leadsState.allRawUsers.length;

      // 1. Process Orders from assigned dealers
      for (final order in dealersState.allRawOrders) {
        if (order['orderStatus'] == 'Cancelled') continue;
        final user = order['user'];
        if (user == null) continue;

        final orderId = (order['orderId'] ?? order['_id'] ?? '').toString();
        if (orderId.isNotEmpty && _mergedOrderIds.contains(orderId)) continue;
        
        final rawUser = _normalizeId(user['_id']);
        String displayName = '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim();
        if (displayName.isEmpty) displayName = (user['shopName'] ?? '').toString();
        if (displayName.isEmpty) displayName = 'Dealer';
        final displayPhone = (user['phoneNumber'] ?? user['phone'] ?? '').toString();

        if (!AuthService().isSales ||
            _isUserAssignedToCurrentSalesAgent(
              rawUser: rawUser,
              displayName: displayName,
              displayPhone: displayPhone,
              userDetails: user is Map<String, dynamic> ? user : null,
            )) {
          final eventType = order['orderStatus'] == 'Delivered'
              ? 'payment_success'
              : 'order_created';
          
          final categoryList = _eventsLogs.putIfAbsent(eventType, () => []);
          if (orderId.isNotEmpty) _mergedOrderIds.add(orderId);

          if (rawUser.isNotEmpty) _nameToId[displayName] = rawUser;
          final total = order['totalAmount'] ?? order['total'] ?? 0;

          categoryList.add({
            'user': displayName,
            'userPhone': displayPhone,
            'rawUser': rawUser,
            'time': _formatTimestamp(order['createdAt']?.toString()),
            'rawTimestamp': order['createdAt']?.toString() ?? DateTime.now().toIso8601String(),
            'device': (order['paymentMethod'] ?? 'Web Application').toString(),
            'details': 'Placed Order #$orderId - ₹$total (${order['orderStatus'] ?? 'Processing'})',
            'payload': Map<String, dynamic>.from(order),
          });
        }
      }

      // 2. Process Assigned Dealers
      for (final u in dealersState.allRawUsers) {
        final rawUser = _normalizeId(u['_id']);
        String displayName = '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'.trim();
        if (displayName.isEmpty) displayName = (u['shopName'] ?? '').toString();
        if (displayName.isEmpty) displayName = 'Dealer';
        final displayPhone = (u['phoneNumber'] ?? u['phone'] ?? '').toString();

        final userKey = 'dealer_${rawUser}_$displayName';
        if (_mergedUserIds.contains(userKey)) continue;

        if (!AuthService().isSales ||
            _isUserAssignedToCurrentSalesAgent(
              rawUser: rawUser,
              displayName: displayName,
              displayPhone: displayPhone,
              userDetails: u,
            )) {
          final eventType = 'kyc_verified';
          final categoryList = _eventsLogs.putIfAbsent(eventType, () => []);

          _mergedUserIds.add(userKey);
          if (rawUser.isNotEmpty) _nameToId[displayName] = rawUser;
          categoryList.add({
            'user': displayName,
            'userPhone': displayPhone,
            'rawUser': rawUser,
            'time': _formatTimestamp(u['createdAt']?.toString()),
            'rawTimestamp': u['createdAt']?.toString() ?? DateTime.now().toIso8601String(),
            'device': 'Mobile App',
            'details': 'Verified Dealer - ${u['city'] ?? u['state'] ?? 'Active'} (${u['shopName'] ?? 'Agro Shop'})',
            'payload': Map<String, dynamic>.from(u),
          });
        }
      }

      // 3. Process Assigned Leads
      for (final u in leadsState.allRawUsers) {
        final rawUser = _normalizeId(u['_id']);
        String displayName = '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'.trim();
        if (displayName.isEmpty) displayName = (u['shopName'] ?? '').toString();
        if (displayName.isEmpty) displayName = 'Lead';
        final displayPhone = (u['phoneNumber'] ?? u['phone'] ?? '').toString();

        final userKey = 'lead_${rawUser}_$displayName';
        if (_mergedUserIds.contains(userKey)) continue;

        if (!AuthService().isSales ||
            _isUserAssignedToCurrentSalesAgent(
              rawUser: rawUser,
              displayName: displayName,
              displayPhone: displayPhone,
              userDetails: u,
            )) {
          final eventType = 'lead_created';
          final categoryList = _eventsLogs.putIfAbsent(eventType, () => []);

          _mergedUserIds.add(userKey);
          if (rawUser.isNotEmpty) _nameToId[displayName] = rawUser;
          categoryList.add({
            'user': displayName,
            'userPhone': displayPhone,
            'rawUser': rawUser,
            'time': _formatTimestamp(u['createdAt']?.toString()),
            'rawTimestamp': u['createdAt']?.toString() ?? DateTime.now().toIso8601String(),
            'device': (u['source'] ?? 'Direct Lead').toString(),
            'details': 'Assigned Lead - Source: ${u['source'] ?? 'CTWA'} (${u['city'] ?? 'Active'})',
            'payload': Map<String, dynamic>.from(u),
          });
        }
      }
    } catch (e) {
      debugPrint('[UserEventsPage] Error merging customer record events: $e');
    }
  }

  String? _getUserRole(String userIdentifier, String? currentRole) {
    if (currentRole?.toLowerCase() == 'admin' || currentRole?.toLowerCase() == 'sales') return currentRole;

    final idLower = userIdentifier.toLowerCase();

    // 1. Try to find in Dealers
    try {
      final dealersState = context.read<DealersBloc>().state;
      final Map<String, dynamic>?
      dealerData = dealersState.allRawUsers.firstWhere((u) {
        final String fullName = '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'
            .trim()
            .toLowerCase();
        final String phone = (u['phoneNumber'] ?? '').toString();
        final String shopName = (u['shopName'] ?? '').toString().toLowerCase();
        final String email = (u['email'] ?? '').toString().toLowerCase();
        final String uid = (u['_id'] ?? '').toString().toLowerCase();
        return fullName == idLower ||
            phone == idLower ||
            shopName == idLower ||
            email == idLower ||
            uid == idLower;
      }, orElse: () => <String, dynamic>{});
      if (dealerData != null && dealerData.isNotEmpty) {
        return dealerData['role']?.toString();
      }
    } catch (_) {}

    // 2. Try to find in Leads
    try {
      final leadsState = context.read<LeadsBloc>().state;
      final Map<String, dynamic>? leadData = leadsState.allRawUsers.firstWhere((
        u,
      ) {
        final String fullName = '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'
            .trim()
            .toLowerCase();
        final String phone = (u['phoneNumber'] ?? '').toString();
        final String email = (u['email'] ?? '').toString().toLowerCase();
        final String uid = (u['_id'] ?? '').toString().toLowerCase();
        return fullName == idLower ||
            phone == idLower ||
            email == idLower ||
            uid == idLower;
      }, orElse: () => <String, dynamic>{});
      if (leadData != null && leadData.isNotEmpty) {
        return leadData['role']?.toString();
      }
    } catch (_) {}

    return currentRole;
  }

  String? _resolveSearchQueryToEmailOrPhone(String? searchQuery) {
    if (searchQuery == null || searchQuery.trim().isEmpty) return null;
    final queryLower = searchQuery.trim().toLowerCase();

    // 1. Try to find in Dealers
    try {
      final dealersState = context.read<DealersBloc>().state;
      final matchingUser = dealersState.allRawUsers.firstWhere((u) {
        final fullName = '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'.trim().toLowerCase();
        final shopName = (u['shopName'] ?? '').toString().toLowerCase();
        final email = (u['email'] ?? '').toString().toLowerCase();
        final phone = (u['phoneNumber'] ?? u['phone'] ?? '').toString().toLowerCase();
        final uid = (u['_id'] ?? '').toString().toLowerCase();
        return fullName.contains(queryLower) ||
            shopName.contains(queryLower) ||
            email.contains(queryLower) ||
            phone.contains(queryLower) ||
            uid.contains(queryLower);
      });
      return matchingUser['email'] ?? matchingUser['phoneNumber'] ?? matchingUser['phone'] ?? searchQuery;
    } catch (_) {}

    // 2. Try to find in Leads
    try {
      final leadsState = context.read<LeadsBloc>().state;
      final matchingUser = leadsState.allRawUsers.firstWhere((u) {
        final fullName = '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'.trim().toLowerCase();
        final shopName = (u['shopName'] ?? '').toString().toLowerCase();
        final email = (u['email'] ?? '').toString().toLowerCase();
        final phone = (u['phoneNumber'] ?? u['phone'] ?? '').toString().toLowerCase();
        final uid = (u['_id'] ?? '').toString().toLowerCase();
        return fullName.contains(queryLower) ||
            shopName.contains(queryLower) ||
            email.contains(queryLower) ||
            phone.contains(queryLower) ||
            uid.contains(queryLower);
      });
      return matchingUser['email'] ?? matchingUser['phoneNumber'] ?? matchingUser['phone'] ?? searchQuery;
    } catch (_) {}

    return searchQuery;
  }

  Timer? _rebuildDebounce;
  bool _isRebuildingCache = false;

  void _requestRebuildCache() {
    if (_isRebuildingCache) return;
    _rebuildDebounce?.cancel();
    _rebuildDebounce = Timer(const Duration(milliseconds: 150), () {
      if (mounted) {
        _rebuildCache();
      }
    });
  }

  void _rebuildCache() {
    if (_isRebuildingCache) return;
    _isRebuildingCache = true;
    try {
      _buildUserLookupIndexes();
      _mergeSalesCustomerEventsIntoLogs();

      final Map<String, Map<String, List<Map<String, dynamic>>>> userEventsGrouped = {};
      final Set<String> usersSet = {};
      
      // 1. Group events by user and category
      _eventsLogs.forEach((category, logs) {
        for (final log in logs) {
          final String? userName = log['user'] as String?;
          if (userName != null && userName.isNotEmpty) {
            usersSet.add(userName);
            
            final userMap = userEventsGrouped.putIfAbsent(userName, () => {});
            final categoryList = userMap.putIfAbsent(category, () => []);
            categoryList.add(log);
          }
        }
      });

      // Also populate usersSet with assigned Dealers and Leads
      try {
        final dealersState = context.read<DealersBloc>().state;
        for (final u in dealersState.allRawUsers) {
          final String rawUser = _normalizeId(u['_id']);
          String displayName = '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'.trim();
          if (displayName.isEmpty) displayName = (u['shopName'] ?? '').toString();
          if (displayName.isEmpty) displayName = 'Dealer';
          final displayPhone = (u['phoneNumber'] ?? u['phone'] ?? '').toString();

          if (!AuthService().isSales ||
              _isUserAssignedToCurrentSalesAgent(
                rawUser: rawUser,
                displayName: displayName,
                displayPhone: displayPhone,
                userDetails: u,
              )) {
            usersSet.add(displayName);
            if (rawUser.isNotEmpty) _nameToId[displayName] = rawUser;
          }
        }
      } catch (_) {}

      try {
        final leadsState = context.read<LeadsBloc>().state;
        for (final u in leadsState.allRawUsers) {
          final String rawUser = _normalizeId(u['_id']);
          String displayName = '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'.trim();
          if (displayName.isEmpty) displayName = (u['shopName'] ?? '').toString();
          if (displayName.isEmpty) displayName = 'Lead';
          final displayPhone = (u['phoneNumber'] ?? u['phone'] ?? '').toString();

          if (!AuthService().isSales ||
              _isUserAssignedToCurrentSalesAgent(
                rawUser: rawUser,
                displayName: displayName,
                displayPhone: displayPhone,
                userDetails: u,
              )) {
            usersSet.add(displayName);
            if (rawUser.isNotEmpty) _nameToId[displayName] = rawUser;
          }
        }
      } catch (_) {}

      // Sort logs inside each category by timestamp descending
      userEventsGrouped.forEach((userName, categories) {
        categories.forEach((category, logs) {
          logs.sort((a, b) {
            final aTs = a['rawTimestamp']?.toString() ?? '';
            final bTs = b['rawTimestamp']?.toString() ?? '';
            return bTs.compareTo(aTs);
          });
        });
      });

      _cachedUserEventsGrouped = userEventsGrouped;

      // 2. Pre-calculate most recent event times, priority reasons, and user types
      final Map<String, DateTime> mostRecentEventTimes = {};
      final Map<String, bool> highPriority = {};
      final Map<String, String> priorityReason = {};
      final Map<String, String> userTypes = {};

      _onlineUserKeys.clear();
      for (var u in _realTimeUsers) {
        final uName = u['userName'] ?? u['user'] ?? '';
        _onlineUserKeys.add(uName);
        final userId = u['user'];
        if (userId != null) {
          _onlineUserKeys.add(userId);
        }
      }

      for (final userName in usersSet) {
        DateTime mostRecent = DateTime.fromMillisecondsSinceEpoch(0);
        final userGroups = userEventsGrouped[userName] ?? {};
        userGroups.forEach((_, logs) {
          for (final log in logs) {
            final tsStr = log['rawTimestamp'] as String?;
            if (tsStr != null) {
              try {
                final dt = DateTime.parse(tsStr);
                if (dt.isAfter(mostRecent)) {
                  mostRecent = dt;
                }
              } catch (_) {}
            }
          }
        });
        mostRecentEventTimes[userName] = mostRecent;

        bool isHigh = false;
        String reason = '';
        final bool hasSuccess = userGroups.containsKey('payment_success') ||
            userGroups.containsKey('order_placed') ||
            userGroups.containsKey('order_completed');

        if (userGroups.containsKey('payment_failed') && !hasSuccess) {
          isHigh = true;
          reason = 'Payment Failed';
        } else if (userGroups.containsKey('checkout_started') && !hasSuccess) {
          isHigh = true;
          reason = 'Abandoned Checkout';
        } else if (userGroups.containsKey('add_to_cart') && !hasSuccess) {
          isHigh = true;
          reason = 'Abandoned Cart';
        }
        highPriority[userName] = isHigh;
        priorityReason[userName] = reason;

        userTypes[userName] = _calculateUserType(userName);
      }

      _cachedMostRecentEventTimes = mostRecentEventTimes;
      _cachedHighPriority = highPriority;
      _cachedPriorityReason = priorityReason;
      _cachedUserTypes = userTypes;

      // Build search indexes
      final Map<String, String> userSearchIndex = {};
      for (final userName in usersSet) {
        final buffer = StringBuffer();
        buffer.write(userName.toLowerCase());
        buffer.write(' ');

        final rawUser = _nameToId[userName];
        if (rawUser != null) {
          buffer.write(rawUser.toLowerCase());
          buffer.write(' ');
        }
        userSearchIndex[userName] = buffer.toString();
      }
      _cachedUserSearchIndex = userSearchIndex;

      final sortedUsers = usersSet.toList();
      sortedUsers.sort((a, b) {
        final aOnline = _isUserOnline(a);
        final bOnline = _isUserOnline(b);
        if (aOnline && !bOnline) return -1;
        if (!aOnline && bOnline) return 1;

        final aTime = _cachedMostRecentEventTimes[a] ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = _cachedMostRecentEventTimes[b] ?? DateTime.fromMillisecondsSinceEpoch(0);
        if (aTime != bTime) {
          return bTime.compareTo(aTime);
        }
        
        return a.compareTo(b);
      });

      _cachedUsersWithEvents = sortedUsers;
    } finally {
      _isRebuildingCache = false;
      if (mounted) setState(() {});
    }
  }


  String _calculateUserType(String userName) {
    final nameLower = userName.toLowerCase();
    if (_cachedUserTypeLookup == null) {
      _buildUserLookupIndexes();
    }
    final type = _cachedUserTypeLookup?[nameLower];
    if (type != null) return type;

    // Check in fallback static dealers list
    final isStaticDealer = allDealers.any((d) {
      return d.name.toLowerCase().contains(nameLower) || nameLower.contains(d.name.toLowerCase().split(' ').first);
    });
    if (isStaticDealer) return 'Dealer';

    return 'Guest';
  }

  void _listenToLivePresence() {
    _presenceSubscription = WebSocketService().presenceUpdates.listen((update) {
      if (mounted) {
        // Normalize the update to ensure it has the enriched fields
        final enrichedUpdate = Map<String, dynamic>.from(update);
        final userId = enrichedUpdate['user'];
        final userIdStr = userId?.toString();
        if (userIdStr == null ||
            userIdStr.isEmpty ||
            userIdStr.toLowerCase() == 'guest' ||
            userIdStr.toLowerCase() == 'unknown user') {
          return;
        }

        final role = _getUserRole(
          userIdStr,
          enrichedUpdate['role']?.toString(),
        );

        // Skip if it's the current admin or has admin/sales role
        final isNameOrEmailAdmin = userIdStr.toLowerCase().contains('admin') ||
            (enrichedUpdate['userName']?.toString().toLowerCase().contains('admin') ?? false);
        if (userIdStr == AuthService().currentUserEmail ||
            role?.toLowerCase() == 'admin' ||
            role?.toLowerCase() == 'sales' ||
            isNameOrEmailAdmin)
          return;

        if (AuthService().isSales &&
            !_isUserAssignedToCurrentSalesAgent(
              rawUser: userIdStr,
              displayName: enrichedUpdate['userName']?.toString(),
              displayPhone: enrichedUpdate['phone']?.toString() ?? enrichedUpdate['phoneNumber']?.toString(),
              userDetails: enrichedUpdate,
            )) {
          return;
        }

        enrichedUpdate['_localLastSeen'] =
            DateTime.now().millisecondsSinceEpoch;

        // Check if user already in list
        final index = _realTimeUsers.indexWhere((u) => u['user'] == userId);
        if (index != -1) {
          _realTimeUsers[index] = {
            ..._realTimeUsers[index],
            ...enrichedUpdate,
          };
        } else {
          _realTimeUsers.insert(0, enrichedUpdate);
        }
        
        _requestRebuildCache();

        // Trigger a background refresh of historical events
        _eventsRefreshDebounce?.cancel();
        _eventsRefreshDebounce = Timer(const Duration(seconds: 5), () {
          if (mounted) _loadEvents(silent: true, isBackground: true);
        });
      }
    });
  }

  void _startRealTimePoll() {
    _realTimeTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _loadRealTimeUsers();
    });
    _loadRealTimeUsers();
  }

  Future<void> _loadRealTimeUsers() async {
    if (_isLoadingRealTime) return;
    _isLoadingRealTime = true;
    try {
      final users = await AnalyticsService().fetchRealTimeUsers();
      if (mounted) {
        setState(() {
          final now = DateTime.now().millisecondsSinceEpoch;
          final Map<String, Map<String, dynamic>> merged = {};

          // 1. Keep currently tracked users if seen within last 2.5 minutes
          for (var u in _realTimeUsers) {
            final lastSeen = u['_localLastSeen'] ?? 0;
            if (now - lastSeen < 150000) {
              merged[u['user']] = Map<String, dynamic>.from(u);
            }
          }

          // 2. Overlay with fresh data from server poll
          final currentUserEmail = AuthService().currentUserEmail;
          for (var u in users) {
            final userId = u['user'];
            final userIdStr = userId?.toString();
            if (userIdStr == null ||
                userIdStr.isEmpty ||
                userIdStr.toLowerCase() == 'guest' ||
                userIdStr.toLowerCase() == 'unknown user') {
              continue;
            }

            final role = _getUserRole(userIdStr, u['role']?.toString());

            // Skip if it's the current admin or has admin/sales role
            final isNameOrEmailAdmin = userIdStr.toLowerCase().contains('admin') ||
                (u['userName']?.toString().toLowerCase().contains('admin') ?? false);
            if (userIdStr == currentUserEmail ||
                role?.toLowerCase() == 'admin' ||
                role?.toLowerCase() == 'sales' ||
                isNameOrEmailAdmin)
              continue;

            if (AuthService().isSales &&
                !_isUserAssignedToCurrentSalesAgent(
                  rawUser: userIdStr,
                  displayName: u['userName']?.toString(),
                  displayPhone: u['phone']?.toString() ?? u['phoneNumber']?.toString(),
                  userDetails: u,
                )) {
              continue;
            }

            final freshData = Map<String, dynamic>.from(u);
            freshData['_localLastSeen'] = now;

            if (merged.containsKey(userId)) {
              merged[userId] = {...merged[userId]!, ...freshData};
            } else {
              merged[userId] = freshData;
            }
          }

          _realTimeUsers = merged.values.toList()
            ..sort(
              (a, b) => (b['_localLastSeen'] ?? 0).compareTo(
                a['_localLastSeen'] ?? 0,
              ),
            );
          _rebuildCache();
        });
      }
    } finally {
      _isLoadingRealTime = false;
    }
  }

  void _processEventsList(
    List<Map<String, dynamic>> flatEvents,
    Map<String, List<Map<String, dynamic>>> grouped,
    Map<String, String> nameToId, {
    bool isSingleUserSearch = false,
    String? targetUserName,
  }) {
    final Map<String, int> batchUserCounts = {};

    for (var event in flatEvents) {
      final String? eventId = event['_id']?.toString() ?? event['eventId']?.toString();
      if (eventId != null) {
        if (_processedEventIds.contains(eventId)) continue;
        _processedEventIds.add(eventId);
      }

      final rawUser = event['user']?.toString();
      if (rawUser == null ||
          rawUser.isEmpty ||
          rawUser.toLowerCase() == 'guest' ||
          rawUser.toLowerCase() == 'unknown user') {
        continue;
      }

      String displayName = (targetUserName != null && targetUserName.isNotEmpty)
          ? targetUserName
          : (event['user']?.toString() ?? 'Unknown User');
      String? displayPhone;

      final userDetails = event['userDetails'] as Map<String, dynamic>?;
      if (userDetails != null && (targetUserName == null || targetUserName.isEmpty)) {
        final firstName = userDetails['firstName'] ?? '';
        final lastName = userDetails['lastName'] ?? '';
        final shopName = userDetails['shopName'] ?? '';
        final phone = userDetails['phoneNumber'] ?? '';

        if (firstName.isNotEmpty || lastName.isNotEmpty) {
          displayName = '$firstName $lastName'.trim();
        } else if (shopName.isNotEmpty) {
          displayName = shopName;
        }

        if (phone.isNotEmpty) {
          displayPhone = phone;
        }
      }

      // Skip if the user is current admin, has 'admin' / 'sales' role, or name/email contains 'admin'
      final currentRole =
          userDetails?['role']?.toString() ?? event['role']?.toString();
      final role = _getUserRole(rawUser, currentRole);
      final isNameOrEmailAdmin = rawUser.toLowerCase().contains('admin') ||
          displayName.toLowerCase().contains('admin');

      if (rawUser == AuthService().currentUserEmail ||
          role?.toLowerCase() == 'admin' ||
          role?.toLowerCase() == 'sales' ||
          isNameOrEmailAdmin) {
        continue;
      }

      if (AuthService().isSales &&
          !_isUserAssignedToCurrentSalesAgent(
            rawUser: rawUser,
            displayName: displayName,
            displayPhone: displayPhone,
            userDetails: userDetails,
          )) {
        continue;
      }

      // User diversity batching: Cap events per user in multi-user global batches to ensure all users get slots
      if (!isSingleUserSearch) {
        final currentCount = batchUserCounts[displayName] ?? 0;
        if (currentCount >= 15) {
          continue;
        }
        batchUserCounts[displayName] = currentCount + 1;
      }

      final eventType = event['eventType']?.toString() ?? 'unknown';
      if (!grouped.containsKey(eventType)) {
        grouped[eventType] = [];
      }

      if (rawUser != null) {
        nameToId[displayName] = rawUser;
      }

      grouped[eventType]!.add({
        'user': displayName,
        'userPhone': displayPhone,
        'rawUser': rawUser, // Keep ID/Email for navigation
        'time': _formatTimestamp(event['timestamp']?.toString()),
        'rawTimestamp': event['timestamp']?.toString(),
        'device': event['device']?.toString() ?? 'Unknown Device',
        'details': event['details']?.toString() ?? '',
        'payload': Map<String, dynamic>.from(event['payload'] ?? {}),
      });
    }
  }

  Future<void> _loadEvents({
    bool silent = false,
    String? searchQuery,
    String? metricFilter,
    bool isBackground = false,
  }) async {
    if (!mounted || _isLoadingEvents) return;
    _isLoadingEvents = true;
    _isBackgroundLoading = isBackground;
    
    final bool isSearch = searchQuery != null && searchQuery.trim().isNotEmpty;
    final String activeMetricFilter = metricFilter ?? _selectedMetricFilter;
    final String activeFilter = activeMetricFilter != 'All'
        ? activeMetricFilter
        : _selectedEventCategory;

    if (!silent && _eventsLogs.isEmpty) {
      setState(() {
        _isLoading = true;
        _isFallbackMode = false;
      });
    } else {
      setState(() {});
    }

    String? backendQuery = _resolveSearchQueryToEmailOrPhone(searchQuery);

    Map<String, dynamic> metrics = {};
    List<Map<String, dynamic>> flatEvents = [];
    try {
      metrics = await AnalyticsService().fetchSummaryMetrics();
      if (mounted && metrics.isNotEmpty) {
        setState(() {
          _globalHighPriorityCount = metrics['highPriority'] as int? ?? 0;
          _globalFailedPaymentsCount = metrics['failedPayments'] as int? ?? 0;
          _globalAbandonedCartsCount = metrics['abandonedCarts'] as int? ?? 0;
        });
      }

      final res = await AnalyticsService().fetchEventsPaged(
        limit: 300,
        userEmail: backendQuery != null && backendQuery.isNotEmpty ? backendQuery : null,
        filter: activeFilter,
      );

      flatEvents = (res['events'] as List?)?.cast<Map<String, dynamic>>() ?? [];

      if (flatEvents.isNotEmpty) {
        // If background refresh and not a search, merge with existing logs
        final bool shouldMerge = isBackground && !isSearch;
        
        if (!shouldMerge) {
          _eventsLogs = {};
          _processedEventIds.clear();
          _nameToId = {};
          _nextCursor = res['nextCursor'] as String?;
        }

        final Map<String, List<Map<String, dynamic>>> currentGrouped = Map.from(_eventsLogs);
        final Map<String, String> currentNameToId = Map.from(_nameToId);

        _processEventsList(flatEvents, currentGrouped, currentNameToId);

        _eventsLogs = currentGrouped;
        _nameToId = currentNameToId;
      } else if (!isBackground) {
        _eventsLogs = {};
        _processedEventIds.clear();
        _nameToId = {};
        _isFallbackMode = false;
        _nextCursor = null;
      }
    } catch (e) {
      debugPrint('[UserEventsPage] Failed to fetch events: $e');
      if (!isBackground) {
        _eventsLogs = {};
        _processedEventIds.clear();
        _isFallbackMode = true;
      }
    }

    if (_eventsLogs.isEmpty || AuthService().isSales) {
      if (flatEvents.isEmpty) {
        _isFallbackMode = true;
      }
    }

    _rebuildCache();

    if (metrics.isEmpty && (searchQuery == null || searchQuery.trim().isEmpty)) {
      final users = _usersWithEvents;
      _globalHighPriorityCount = users.where((u) => _isHighPriority(u)).length;
      _globalFailedPaymentsCount = users.where((u) => _getPriorityReason(u) == 'Payment Failed').length;
      _globalAbandonedCartsCount = users.where((u) {
        final reason = _getPriorityReason(u);
        return reason == 'Abandoned Cart' || reason == 'Abandoned Checkout';
      }).length;
    }

    if (isSearch) {
      if (_cachedUsersWithEvents.isNotEmpty) {
        _selectedUser = _cachedUsersWithEvents.first;
      } else {
        _selectedUser = null;
      }
      _selectedEventType = null;
    } else if (!isBackground) {
      _selectedUser = null;
      _selectedEventType = null;
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
      if (!silent && !isBackground) {
        _prefetchAssignedUsersEvents();
      }
    }
    _isLoadingEvents = false;
    _isBackgroundLoading = false;
  }

  Future<void> _loadMoreEvents() async {
    if (!mounted || _isLoadingEvents || _nextCursor == null || _isLoadingMore) return;
    setState(() {
      _isLoadingMore = true;
    });

    String? backendQuery = _resolveSearchQueryToEmailOrPhone(_userSearchQuery);

    try {
      final res = await AnalyticsService().fetchEventsPaged(
        limit: 300,
        before: _nextCursor,
        userEmail: backendQuery != null && backendQuery.isNotEmpty ? backendQuery : null,
        filter: _selectedMetricFilter,
      );
      final flatEvents = res['events'] as List<Map<String, dynamic>>;
      _nextCursor = res['nextCursor'] as String?;

      if (flatEvents.isNotEmpty) {
        final Map<String, List<Map<String, dynamic>>> grouped = Map.from(_eventsLogs);
        final Map<String, String> nameToId = Map.from(_nameToId);

        _processEventsList(flatEvents, grouped, nameToId);

        setState(() {
          _eventsLogs = grouped;
          _nameToId = nameToId;
        });
      }
    } catch (e) {
      debugPrint('[UserEventsPage] Failed to fetch more events: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }

    _rebuildCache();
  }

  String _formatTimestamp(String? timestampStr) {
    if (timestampStr == null) return 'Just now';
    try {
      final dt = DateTime.parse(timestampStr);
      final diff = DateTime.now().difference(dt);
      if (diff.inSeconds < 60) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes} mins ago';
      if (diff.inHours < 24) return '${diff.inHours} hours ago';
      return '${diff.inDays} days ago';
    } catch (_) {
      return 'Just now';
    }
  }

  @override
  void dispose() {
    _realTimeTimer?.cancel();
    _eventsRefreshDebounce?.cancel();
    _rebuildDebounce?.cancel();
    _searchDebounce?.cancel();
    _presenceSubscription?.cancel();
    _searchController.dispose();
    _userSearchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchEventsForUser(String userName, {bool silent = false}) async {
    if (_loadingUserEvents.contains(userName)) return;
    
    if (!silent) {
      setState(() {
        _loadingUserEvents.add(userName);
      });
    } else {
      _loadingUserEvents.add(userName);
    }

    try {
      final resolvedQuery = _resolveSearchQueryToEmailOrPhone(userName) ?? _nameToId[userName] ?? userName;
      if (resolvedQuery.isEmpty) return;

      Map<String, dynamic> res = await AnalyticsService().fetchEventsPaged(
        userEmail: resolvedQuery,
        limit: 150,
        actorOnly: false,
      );
      List<Map<String, dynamic>> flatEvents = res['events'] as List<Map<String, dynamic>>? ?? [];

      if (flatEvents.isEmpty && _nameToId[userName] != null && _nameToId[userName] != resolvedQuery) {
        final fallbackRes = await AnalyticsService().fetchEventsPaged(
          userEmail: _nameToId[userName],
          limit: 150,
          actorOnly: false,
        );
        flatEvents = fallbackRes['events'] as List<Map<String, dynamic>>? ?? [];
      }

      if (flatEvents.isNotEmpty) {
        _perUserEventsCache[userName] = flatEvents;
        final Map<String, List<Map<String, dynamic>>> grouped = Map.from(_eventsLogs);
        final Map<String, String> nameToId = Map.from(_nameToId);

        _processEventsList(flatEvents, grouped, nameToId, isSingleUserSearch: true, targetUserName: userName);

        _eventsLogs = grouped;
        _nameToId = nameToId;
        _rebuildCache();

        if (_selectedUser == userName && _selectedEventType == null) {
          final updatedGrouped = _getUserEventsGrouped(userName);
          if (updatedGrouped.isNotEmpty) {
            _selectedEventType = updatedGrouped.keys.first;
          }
        }
      }
    } catch (e) {
      debugPrint('[UserEventsPage] Failed to fetch events for user $userName: $e');
    } finally {
      _loadingUserEvents.remove(userName);
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _prefetchAssignedUsersEvents() async {
    if (!mounted) return;
    final int prefetchLimit = AuthService().isSales ? 3 : 10;
    final usersToPrefetch = _cachedUsersWithEvents.where((u) {
      final events = _getUserEventsGrouped(u);
      return events.isEmpty;
    }).take(prefetchLimit).toList();

    for (final userName in usersToPrefetch) {
      if (!mounted) break;
      await _fetchEventsForUser(userName, silent: true);
      await Future.delayed(const Duration(milliseconds: 50));
    }
  }

  void _scrollToAndExpandUser(String userName) {
    // 1. Expand the card
    setState(() {
      _selectedUser = userName;
      final grouped = _getUserEventsGrouped(userName);
      if (grouped.isNotEmpty) {
        _selectedEventType = grouped.keys.first;
      } else {
        _selectedEventType = null;
      }
      _userSearchQuery = '';
      _userSearchController.clear();
    });

    _fetchEventsForUser(userName);

    // 2. Scroll to the card after the next frame (once expanded/visible)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = _userCardKeys[userName];
      if (key != null && key.currentContext != null) {
        Scrollable.ensureVisible(
          key.currentContext!,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  Map<String, String> _enrichUserPresence(
    String userIdentifier,
    String? currentName,
    String? currentPhone,
  ) {
    final idLower = userIdentifier.toLowerCase();

    // 1. Try to find in Dealers
    try {
      final dealersState = context.read<DealersBloc>().state;
      final Map<String, dynamic>?
      dealerData = dealersState.allRawUsers.firstWhere((u) {
        final String fullName = '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'
            .trim()
            .toLowerCase();
        final String phone = (u['phoneNumber'] ?? '').toString();
        final String shopName = (u['shopName'] ?? '').toString().toLowerCase();
        final String email = (u['email'] ?? '').toString().toLowerCase();
        final String uid = (u['_id'] ?? '').toString().toLowerCase();
        return fullName == idLower ||
            phone == idLower ||
            shopName == idLower ||
            email == idLower ||
            uid == idLower;
      }, orElse: () => <String, dynamic>{});
      if (dealerData != null && dealerData.isNotEmpty) {
        final String personName =
            (dealerData['firstName'] != null || dealerData['lastName'] != null)
            ? '${dealerData['firstName'] ?? ''} ${dealerData['lastName'] ?? ''}'
                  .trim()
            : '';
        final String shopName = dealerData['shopName'] ?? '';
        final String displayName = personName.isNotEmpty
            ? personName
            : (shopName.isNotEmpty ? shopName : userIdentifier);
        final String displayPhone =
            dealerData['phoneNumber'] ?? currentPhone ?? '';
        return {'name': displayName, 'phone': displayPhone};
      }
    } catch (_) {}

    // 2. Try to find in Leads
    try {
      final leadsState = context.read<LeadsBloc>().state;
      final Map<String, dynamic>? leadData = leadsState.allRawUsers.firstWhere((
        u,
      ) {
        final String fullName = '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'
            .trim()
            .toLowerCase();
        final String phone = (u['phoneNumber'] ?? '').toString();
        final String email = (u['email'] ?? '').toString().toLowerCase();
        final String uid = (u['_id'] ?? '').toString().toLowerCase();
        return fullName == idLower ||
            phone == idLower ||
            email == idLower ||
            uid == idLower;
      }, orElse: () => <String, dynamic>{});
      if (leadData != null && leadData.isNotEmpty) {
        final String personName =
            (leadData['firstName'] != null || leadData['lastName'] != null)
            ? '${leadData['firstName'] ?? ''} ${leadData['lastName'] ?? ''}'
                  .trim()
            : '';
        final String shopName = leadData['shopName'] ?? '';
        final String displayName = personName.isNotEmpty
            ? personName
            : (shopName.isNotEmpty ? shopName : userIdentifier);
        final String displayPhone =
            leadData['phoneNumber'] ?? currentPhone ?? '';
        return {'name': displayName, 'phone': displayPhone};
      }
    } catch (_) {}

    final String fallbackName = (currentName != null && currentName.isNotEmpty)
        ? currentName
        : userIdentifier;
    final String fallbackPhone = currentPhone ?? '';
    return {'name': fallbackName, 'phone': fallbackPhone};
  }

  bool _isUserOnline(String userName) {
    final userId = _nameToId[userName];
    return _onlineUserKeys.contains(userName) ||
        (userId != null && _onlineUserKeys.contains(userId));
  }

  DateTime _getMostRecentEventTime(String userName) {
    return _cachedMostRecentEventTimes[userName] ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  List<String> get _usersWithEvents => _cachedUsersWithEvents;

  bool _isHighPriority(String userName) {
    return _cachedHighPriority[userName] ?? false;
  }

  String _getPriorityReason(String userName) {
    return _cachedPriorityReason[userName] ?? '';
  }

  List<String> get _filteredUsers {
    var users = _usersWithEvents;

    // Filter by Metric Card Selection
    if (_selectedMetricFilter == 'High Priority') {
      users = users.where((u) => _isHighPriority(u)).toList();
    } else if (_selectedMetricFilter == 'Abandoned Carts') {
      users = users.where((u) {
        final reason = _getPriorityReason(u);
        return reason == 'Abandoned Cart' || reason == 'Abandoned Checkout';
      }).toList();
    } else if (_selectedMetricFilter == 'Failed Payments') {
      users = users.where((u) {
        final reason = _getPriorityReason(u);
        return reason == 'Payment Failed';
      }).toList();
    } else if (_selectedMetricFilter == 'Live Users') {
      users = users.where((u) => _isUserOnline(u)).toList();
    }

    // Filter by Priority Dropdown (syncs/coexists with card selection)
    if (_selectedPriority == 'High Priority') {
      users = users.where((u) => _isHighPriority(u)).toList();
    }

    // Filter by User Type
    if (_selectedUserType != 'All') {
      users = users.where((u) {
        final type = _getUserType(u);
        return type == _selectedUserType;
      }).toList();
    }

    // Filter by Event Category
    if (_selectedEventCategory != 'All') {
      final catLower = _selectedEventCategory.toLowerCase();
      users = users.where((u) {
        final grouped = _getUserEventsGrouped(u);
        if (catLower == 'add_to_cart' || catLower == 'cart_add') {
          return grouped.containsKey('add_to_cart') || grouped.containsKey('cart_add') || grouped.containsKey('cart_view');
        } else if (catLower == 'checkout_started') {
          return grouped.containsKey('checkout_started') || grouped.containsKey('checkout_init') || grouped.containsKey('apply_coupon') || grouped.containsKey('payment_initiated');
        } else if (catLower == 'payment_success' || catLower == 'order_completed' || catLower == 'order_placed') {
          return grouped.containsKey('payment_success') || grouped.containsKey('order_placed') || grouped.containsKey('order_completed');
        } else if (catLower == 'product_search' || catLower == 'product_view') {
          return grouped.containsKey('product_search') || grouped.containsKey('product_view') || grouped.containsKey('category_view') || grouped.containsKey('login_success');
        }
        return grouped.containsKey(_selectedEventCategory) &&
            (grouped[_selectedEventCategory]?.isNotEmpty ?? false);
      }).toList();
    }

    if (_userSearchQuery.isEmpty) return users;
    final query = _userSearchQuery.toLowerCase();
    final cleanQuery = query.replaceAll(RegExp(r'[^\d]'), '');

    return users.where((u) {
      final searchIdx = _cachedUserSearchIndex[u];
      if (searchIdx != null) {
        if (searchIdx.contains(query)) return true;
        if (cleanQuery.isNotEmpty && searchIdx.contains(cleanQuery)) return true;
        return false;
      }
      return u.toLowerCase().contains(query);
    }).toList();
  }

  Map<String, List<Map<String, dynamic>>> _getUserEventsGrouped(
    String userName,
  ) {
    return _cachedUserEventsGrouped[userName] ?? {};
  }

  List<Map<String, dynamic>> get _eventTypes => _allEventTypes;

  static final List<Map<String, dynamic>> _allEventTypes = [
    {
      'id': 'login_success',
      'label': 'Login Success',
      'icon': Icons.login_rounded,
      'color': Colors.green,
      'description': 'User successfully authenticated',
    },
    {
      'id': 'profile_view',
      'label': 'Profile View',
      'icon': Icons.visibility_rounded,
      'color': Colors.blue,
      'description': 'Dealer profile page visited',
    },
    {
      'id': 'product_search',
      'label': 'Product Search',
      'icon': Icons.search_rounded,
      'color': Colors.teal,
      'description': 'Inventory search queries executed',
    },
    {
      'id': 'add_to_cart',
      'label': 'Add to Cart',
      'icon': Icons.add_shopping_cart_rounded,
      'color': Colors.orange,
      'description': 'Items added to purchasing cart',
    },
    {
      'id': 'checkout_started',
      'label': 'Checkout Started',
      'icon': Icons.shopping_bag_rounded,
      'color': Colors.purple,
      'description': 'Checkout process initiated',
    },
    {
      'id': 'payment_failed',
      'label': 'Payment Failed',
      'icon': Icons.error_outline_rounded,
      'color': Colors.red,
      'description': 'Unsuccessful transaction attempts',
    },
    {
      'id': 'payment_success',
      'label': 'Payment Success',
      'icon': Icons.check_circle_outline_rounded,
      'color': const Color(0xFF10B981), // Emerald green
      'description': 'Completed payments received',
    },
  ];

  static final Map<String, List<Map<String, dynamic>>> _mockEventsLogs = {
    'login_success': [
      {
        'user': 'Vijay D. (King Agro)',
        'time': 'Just now',
        'device': 'Android 14 (Samsung S23)',
        'details': 'IP: 157.45.12.8 • Method: OTP Verification',
        'payload': {
          'action': 'login_verify',
          'status': 'success',
          'method': 'otp',
          'phone': '+91 98765 43210',
          'device_fingerprint': 'dev_samsung_s23_9fa1',
          'location': 'Indore, Madhya Pradesh',
        },
      },
      {
        'user': 'Rajesh Kumar',
        'time': '4 mins ago',
        'device': 'Chrome 122 (Windows 11)',
        'details': 'IP: 103.88.22.45 • Method: Google Auth',
        'payload': {
          'action': 'login_verify',
          'status': 'success',
          'method': 'google_sso',
          'email': 'rajesh.k@krishidealer.com',
          'device_fingerprint': 'dev_win_chrome_e3f2',
          'location': 'Bhopal, Madhya Pradesh',
        },
      },
      {
        'user': 'Suresh Patil',
        'time': '12 mins ago',
        'device': 'iOS 17.2 (iPhone 15)',
        'details': 'IP: 223.187.9.11 • Method: Password',
        'payload': {
          'action': 'login_verify',
          'status': 'success',
          'method': 'credentials',
          'username': 'suresh_patel_agro',
          'device_fingerprint': 'dev_iphone15_22b4',
          'location': 'Ujjain, Madhya Pradesh',
        },
      },
    ],
    'profile_view': [
      {
        'user': 'Gupta Seeds',
        'time': '1 min ago',
        'device': 'Android 13 (Realme 9)',
        'details': 'Visited: KYC & Documents page',
        'payload': {
          'action': 'profile_view',
          'section': 'kyc_verification',
          'view_duration_sec': 42,
          'documents_uploaded': ['gst_cert.pdf', 'pan_card.jpg'],
        },
      },
      {
        'user': 'Shiva Enterprises',
        'time': '8 mins ago',
        'device': 'Chrome 122 (macOS 14)',
        'details': 'Visited: Account Settings',
        'payload': {
          'action': 'profile_view',
          'section': 'settings_billing',
          'view_duration_sec': 15,
        },
      },
    ],
    'product_search': [
      {
        'user': 'King Agro',
        'time': '2 mins ago',
        'device': 'Android 14 (Samsung S23)',
        'details': 'Searched: \"High flow drip nozzle\" • 12 results',
        'payload': {
          'action': 'search',
          'query': 'High flow drip nozzle',
          'category': 'Irrigation',
          'results_count': 12,
          'applied_filters': {'sort': 'price_asc', 'stock': 'in_stock_only'},
        },
      },
      {
        'user': 'Patel Agro',
        'time': '15 mins ago',
        'device': 'iOS 17.2 (iPhone 15)',
        'details': 'Searched: \"NPK 19-19-19 Fertilizer\" • 4 results',
        'payload': {
          'action': 'search',
          'query': 'NPK 19-19-19 Fertilizer',
          'category': 'Fertilizers',
          'results_count': 4,
          'applied_filters': {},
        },
      },
    ],
    'add_to_cart': [
      {
        'user': 'Patel Agro',
        'time': '5 mins ago',
        'device': 'iOS 17.2 (iPhone 15)',
        'details': 'Added: 3 items to cart • Value: ₹48,000',
        'payload': {
          'action': 'cart_add',
          'items': [
            {
              'product_id': 'prod_pump_5hp',
              'product_name': 'Water Pump 5HP',
              'variant_id': 'var_pump_5hp_single',
              'variant_name': 'Single Phase',
              'quantity': 2,
              'price': 11250.00,
            },
            {
              'product_id': 'prod_pump_5hp',
              'product_name': 'Water Pump 5HP',
              'variant_id': 'var_pump_5hp_three',
              'variant_name': 'Three Phase',
              'quantity': 1,
              'price': 13500.00,
            },
            {
              'product_id': 'prod_npk_19',
              'product_name': 'NPK Fertilizer 19-19-19',
              'variant_id': 'var_npk_50kg',
              'variant_name': '50kg Bag',
              'quantity': 10,
              'price': 1200.00,
            },
          ],
          'cart_total_after': 48000.00,
        },
      },
      {
        'user': 'King Agro',
        'time': '18 mins ago',
        'device': 'Android 14 (Samsung S23)',
        'details': 'Added: 2 items to cart • Value: ₹21,000',
        'payload': {
          'action': 'cart_add',
          'items': [
            {
              'product_id': 'prod_drip_kit_standard',
              'product_name': 'Drip Irrigation Kit Standard',
              'variant_id': 'var_drip_1acre',
              'variant_name': '1 Acre',
              'quantity': 5,
              'price': 2400.00,
            },
            {
              'product_id': 'prod_drip_kit_standard',
              'product_name': 'Drip Irrigation Kit Standard',
              'variant_id': 'var_drip_2acre',
              'variant_name': '2 Acre',
              'quantity': 2,
              'price': 4500.00,
            },
          ],
          'cart_total_after': 21000.00,
        },
      },
    ],
    'checkout_started': [
      {
        'user': 'Patel Agro',
        'time': '5 mins ago',
        'device': 'iOS 17.2 (iPhone 15)',
        'details': 'Items: 1 • Cart Subtotal: ₹22,500',
        'payload': {
          'action': 'checkout_start',
          'items_count': 1,
          'subtotal': 22500.00,
          'tax': 1125.00,
          'shipping': 0.00,
          'grand_total': 23625.00,
          'selected_address_id': 'addr_patel_indore_01',
        },
      },
    ],
    'apply_coupon': [
      {
        'user': 'Patel Agro',
        'time': '5 mins ago',
        'device': 'iOS 17.2 (iPhone 15)',
        'details': 'Code: \"MONSOON10\" • Discount: ₹2,250 (10%)',
        'payload': {
          'action': 'coupon_apply',
          'coupon_code': 'MONSOON10',
          'valid': true,
          'discount_type': 'percentage',
          'discount_value': 10,
          'discount_amount': 2250.00,
        },
      },
    ],
    'payment_initiated': [
      {
        'user': 'Patel Agro',
        'time': '4 mins ago',
        'device': 'iOS 17.2 (iPhone 15)',
        'details': 'Gateway: Razorpay UPI • Amount: ₹21,375',
        'payload': {
          'action': 'payment_init',
          'order_id': 'ord_patel_9827a',
          'amount': 21375.00,
          'gateway': 'razorpay',
          'method': 'upi',
          'currency': 'INR',
        },
      },
      {
        'user': 'King Agro',
        'time': '20 mins ago',
        'device': 'Android 14 (Samsung S23)',
        'details': 'Gateway: Razorpay Cards • Amount: ₹27,000',
        'payload': {
          'action': 'payment_init',
          'order_id': 'ord_king_1182c',
          'amount': 27000.00,
          'gateway': 'razorpay',
          'method': 'card',
          'currency': 'INR',
        },
      },
    ],
    'payment_failed': [
      {
        'user': 'King Agro',
        'time': '19 mins ago',
        'device': 'Android 14 (Samsung S23)',
        'details': 'Error: Authentication Timeout • Code: FAIL_504',
        'payload': {
          'action': 'payment_callback',
          'status': 'failed',
          'order_id': 'ord_king_1182c',
          'amount': 27000.00,
          'transaction_id': 'txn_king_fa8912',
          'error_code': 'FAIL_504',
          'error_message': '3D Secure Authentication timed out by issuer bank',
        },
      },
    ],
    'payment_success': [
      {
        'user': 'Patel Agro',
        'time': '3 mins ago',
        'device': 'iOS 17.2 (iPhone 15)',
        'details': 'TXN ID: txn_patel_su9281 • Amount Paid: ₹21,375',
        'payload': {
          'action': 'payment_callback',
          'status': 'success',
          'order_id': 'ord_patel_9827a',
          'amount': 21375.00,
          'transaction_id': 'txn_patel_su9281',
          'invoice_number': 'INV-2026-KD8827',
          'payment_completed_at': '2026-06-04T10:58:02Z',
        },
      },
    ],
  };

  Widget _buildFallbackBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7), // Light amber
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFBBF24)), // Amber border
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: Color(0xFFD97706)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Offline Telemetry Mode',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: const Color(0xFF92400E),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Backend events DB returned no records or is unreachable. Displaying cached local telemetry.',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: const Color(0xFFB45309),
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _loadEvents,
            child: Text(
              'Retry',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: const Color(0xFFD97706),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String label,
    required String value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
    Map<String, String>? displayLabels,
  }) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16),
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
              onChanged: onChanged,
              items: options.map<DropdownMenuItem<String>>((String optVal) {
                final textLabel = displayLabels?[optVal] ?? optVal;
                return DropdownMenuItem<String>(
                  value: optVal,
                  child: Text(textLabel),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusXLarge),
        boxShadow: AppTheme.cardShadow,
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.06),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.analytics_outlined,
                size: 40,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No Events Logged Yet',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Real-time user actions and audit logs will automatically populate here once users use the mobile app.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadEvents,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: Text(
                'Refresh Feed',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = Responsive.isDesktop(context);
    final filtered = _filteredUsers;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          AuthService().isSales ? 'Customer Activity & Telemetry' : 'Live Telemetry & Events',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadEvents,
            tooltip: 'Refresh Feed',
          ),
          const SizedBox(width: 8),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppTheme.lightBorderColor),
        ),
      ),
      body: _isLoading
          ? _buildShimmerLoading(isDesktop)
          : RefreshIndicator(
              onRefresh: _loadEvents,
              color: AppTheme.primaryColor,
              child: CustomScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                slivers: [
                  if (_isLoadingEvents && !_isLoading && !_isBackgroundLoading)
                    const SliverToBoxAdapter(
                      child: LinearProgressIndicator(
                        minHeight: 2,
                        color: AppTheme.primaryColor,
                        backgroundColor: Colors.transparent,
                      ),
                    ),
                  SliverPadding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 28 : 16,
                      vertical: isDesktop ? 20 : 12,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        if (_isFallbackMode) _buildFallbackBanner(),
                        _buildSummaryCards(isDesktop),
                        const SizedBox(height: 20),
                        _buildAnalyticsTabsBar(),
                        const SizedBox(height: 16),
                        _buildActiveAnalyticsView(),
                        const SizedBox(height: 20),
                        _buildRealTimeStats(),
                        const SizedBox(height: 20),
                        _buildUsersListHeader(isDesktop, filtered.length),
                      ]),
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 28 : 16,
                    ),
                    sliver: filtered.isEmpty
                        ? SliverToBoxAdapter(child: _buildEmptyUsersList())
                        : SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final userName = filtered[index];
                                final isSelected = _selectedUser == userName;
                                final grouped = _getUserEventsGrouped(userName);
                                final userId = _nameToId[userName];
                                final isOnline = _realTimeUsers.any((u) {
                                  final uName = u['userName'] ?? u['user'] ?? '';
                                  return uName == userName ||
                                      (userId != null && u['user'] == userId);
                                });

                                final bool isHighPriority = _isHighPriority(userName);
                                final String priorityReason = isHighPriority
                                    ? _getPriorityReason(userName)
                                    : '';

                                final cardKey = _userCardKeys.putIfAbsent(
                                  userName,
                                  () => GlobalKey(),
                                );
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _UserCard(
                                    key: cardKey,
                                    name: userName,
                                    userType: _getUserType(userName),
                                    isOnline: isOnline,
                                    isHighPriority: isHighPriority,
                                    priorityReason: priorityReason,
                                    groupedEvents: grouped,
                                    isSelected: isSelected,
                                    selectedEventType: _selectedEventType,
                                    eventTypes: _eventTypes,
                                    isLoadingEvents: _loadingUserEvents.contains(userName),
                                    onCategorySelected: (catId) {
                                      setState(() {
                                        _selectedUser = userName;
                                        _selectedEventType = catId;
                                      });
                                    },
                                    onTap: () {
                                      setState(() {
                                        if (_selectedUser == userName) {
                                          _selectedUser = null;
                                          _selectedEventType = null;
                                        } else {
                                          _selectedUser = userName;
                                          if (_selectedEventCategory != 'All' && grouped.containsKey(_selectedEventCategory)) {
                                            _selectedEventType = _selectedEventCategory;
                                          } else if (grouped.isNotEmpty) {
                                            _selectedEventType = grouped.keys.first;
                                          } else {
                                            _selectedEventType = null;
                                          }
                                          _fetchEventsForUser(userName);
                                        }
                                      });
                                    },
                                    onViewProfile: (name) => _navigateToProfile(context, name),
                                  ),
                                );
                              },
                              childCount: filtered.length,
                            ),
                          ),
                  ),
                  if (!AuthService().isSales && _nextCursor != null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: _isLoadingMore
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      AppTheme.primaryColor,
                                    ),
                                  ),
                                )
                              : OutlinedButton.icon(
                                  onPressed: _loadMoreEvents,
                                  icon: const Icon(Icons.arrow_downward_rounded, size: 14),
                                  label: Text(
                                    'Load More Events',
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppTheme.primaryColor,
                                    side: const BorderSide(color: AppTheme.primaryColor),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 40)),
                ],
              ),
            ),
    );
  }

  Widget _buildAnalyticsTabsBar() {
    final bool isSales = AuthService().isSales;
    final tabs = isSales
        ? [
            {'icon': Icons.stream_rounded, 'title': 'Live Customer Telemetry Feed'},
          ]
        : [
            {'icon': Icons.stream_rounded, 'title': 'Live Telemetry Feed'},
            {'icon': Icons.filter_alt_rounded, 'title': 'Conversion Funnel'},
            {'icon': Icons.map_rounded, 'title': 'Agri District Heatmap'},
          ];

    if (isSales && _activeAnalyticsTab != 0) {
      _activeAnalyticsTab = 0;
    }

    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(tabs.length, (idx) {
                final isSelected = _activeAnalyticsTab == idx;
                final tab = tabs[idx];
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: InkWell(
                    onTap: () => setState(() => _activeAnalyticsTab = idx),
                    borderRadius: BorderRadius.circular(20),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.primaryColor : AppTheme.cardColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor,
                        ),
                        boxShadow: isSelected ? AppTheme.cardShadow : null,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            tab['icon'] as IconData,
                            size: 16,
                            color: isSelected ? Colors.white : AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            tab['title'] as String,
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? Colors.white : AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
        if (_activeAnalyticsTab == 1 || _activeAnalyticsTab == 2) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedAnalyticsTimeRange,
                icon: const Icon(Icons.arrow_drop_down_rounded, color: AppTheme.textPrimary),
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
                onChanged: (val) async {
                  if (val == null) return;
                  if (val == 'Custom Range') {
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2024, 1, 1),
                      lastDate: DateTime.now().add(const Duration(days: 1)),
                      initialDateRange: _customAnalyticsDateRange ?? DateTimeRange(
                        start: DateTime.now().subtract(const Duration(days: 7)),
                        end: DateTime.now(),
                      ),
                      builder: (context, child) {
                        return Theme(
                          data: ThemeData.light().copyWith(
                            colorScheme: const ColorScheme.light(
                              primary: AppTheme.primaryColor,
                              onPrimary: Colors.white,
                              surface: AppTheme.cardColor,
                              onSurface: AppTheme.textPrimary,
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (picked != null) {
                      setState(() {
                        _selectedAnalyticsTimeRange = 'Custom Range';
                        _customAnalyticsDateRange = picked;
                        _funnelDataFuture = AnalyticsService().fetchFunnelData(
                          days: 'Custom Range',
                          customRange: picked,
                        );
                        _districtDataFuture = AnalyticsService().fetchDistrictAnalytics(
                          days: 'Custom Range',
                          customRange: picked,
                        );
                      });
                    }
                  } else {
                    setState(() {
                      _selectedAnalyticsTimeRange = val;
                      _customAnalyticsDateRange = null;
                      _funnelDataFuture = AnalyticsService().fetchFunnelData(days: val);
                      _districtDataFuture = AnalyticsService().fetchDistrictAnalytics(days: val);
                    });
                  }
                },
                items: [
                  const DropdownMenuItem(value: 'Today', child: Text('Today')),
                  const DropdownMenuItem(value: 'Last 7 Days', child: Text('Last 7 Days')),
                  const DropdownMenuItem(value: 'Last 30 Days', child: Text('Last 30 Days')),
                  const DropdownMenuItem(value: 'All Time', child: Text('All Time')),
                  DropdownMenuItem(
                    value: 'Custom Range',
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.date_range_rounded, size: 14, color: AppTheme.primaryColor),
                        const SizedBox(width: 6),
                        Text(_selectedAnalyticsTimeRange == 'Custom Range' ? _formatAnalyticsDateLabel() : 'Custom Range...'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  List<FunnelStepData> _calculateDynamicFunnelSteps() {
    final Set<String> viewUsers = {};
    int viewEvents = 0;

    final Set<String> cartUsers = {};
    int cartEvents = 0;

    final Set<String> checkoutUsers = {};
    int checkoutEvents = 0;

    final Set<String> orderUsers = {};
    int orderEvents = 0;

    final DateTime now = DateTime.now();
    DateTime? cutoff;
    DateTime? endCutoff;
    if (_selectedAnalyticsTimeRange == 'Today') {
      cutoff = DateTime(now.year, now.month, now.day);
    } else if (_selectedAnalyticsTimeRange == 'Last 7 Days') {
      cutoff = now.subtract(const Duration(days: 7));
    } else if (_selectedAnalyticsTimeRange == 'Last 30 Days') {
      cutoff = now.subtract(const Duration(days: 30));
    } else if (_selectedAnalyticsTimeRange == 'Custom Range' && _customAnalyticsDateRange != null) {
      cutoff = _customAnalyticsDateRange!.start;
      endCutoff = _customAnalyticsDateRange!.end.add(const Duration(days: 1));
    }

    _eventsLogs.forEach((catKey, logs) {
      final key = catKey.toLowerCase();
      for (final log in logs) {
        if (cutoff != null) {
          final tsRaw = log['timestamp'] ?? log['createdAt'] ?? log['time'];
          if (tsRaw != null) {
            DateTime? dt;
            if (tsRaw is DateTime) {
              dt = tsRaw;
            } else if (tsRaw is String) {
              dt = DateTime.tryParse(tsRaw);
            }
            if (dt != null && (dt.isBefore(cutoff) || (endCutoff != null && dt.isAfter(endCutoff)))) {
              continue;
            }
          }
        }

        final userName = (log['user'] ?? log['userName'] ?? log['userEmail'] ?? log['userPhone'] ?? '').toString();
        final rawType = (log['eventType'] ?? log['event'] ?? '').toString().toLowerCase();

        if (AuthService().isSales && !_isUserAssignedToCurrentSalesAgent(
          rawUser: userName,
          displayName: userName,
          displayPhone: log['userPhone']?.toString(),
          userDetails: log['payload'] is Map<String, dynamic> ? log['payload'] as Map<String, dynamic> : null,
        )) {
          continue;
        }

        // Step 1 represents all active user touchpoints / sessions
        if (userName.isNotEmpty) viewUsers.add(userName);
        viewEvents++;

        if (key.contains('cart') || key == 'add_to_cart' || rawType.contains('cart')) {
          if (userName.isNotEmpty) cartUsers.add(userName);
          cartEvents++;
        }
        if (key.contains('checkout') || key.contains('coupon') || key == 'checkout_started' || rawType.contains('checkout')) {
          if (userName.isNotEmpty) checkoutUsers.add(userName);
          checkoutEvents++;
        }
        if (key.contains('payment') || key.contains('order') || key == 'payment_success' || key == 'order_placed' || key == 'order_created' || rawType.contains('order') || rawType.contains('payment')) {
          if (userName.isNotEmpty) orderUsers.add(userName);
          orderEvents++;
        }
      }
    });

    int step1Users = viewUsers.length;
    int step1Events = viewEvents;

    final int step2Users = cartUsers.length;
    final int step2Events = cartEvents;

    final int step3Users = checkoutUsers.length;
    final int step3Events = checkoutEvents;

    final int step4Users = orderUsers.length;
    final int step4Events = orderEvents;

    final int maxDownstreamUsers = [step2Users, step3Users, step4Users].fold(0, (max, v) => v > max ? v : max);
    if (step1Users < maxDownstreamUsers) {
      step1Users = maxDownstreamUsers;
      if (step1Events < maxDownstreamUsers) step1Events = maxDownstreamUsers;
    }

    final double rate1 = step1Users > 0 ? 100.0 : 0.0;
    final double rate2 = step1Users > 0 ? ((step2Users / step1Users) * 100).clamp(0.0, 100.0) : 0.0;
    final double rate3 = step1Users > 0 ? ((step3Users / step1Users) * 100).clamp(0.0, 100.0) : 0.0;
    final double rate4 = step1Users > 0 ? ((step4Users / step1Users) * 100).clamp(0.0, 100.0) : 0.0;

    return [
      FunnelStepData(
        stepName: '1. App Browse & Search',
        userCount: step1Users,
        eventCount: step1Events,
        conversionRate: rate1,
        stepColor: const Color(0xFF1E88E5),
      ),
      FunnelStepData(
        stepName: '2. Add To Cart',
        userCount: step2Users,
        eventCount: step2Events,
        conversionRate: rate2,
        stepColor: const Color(0xFF43A047),
      ),
      FunnelStepData(
        stepName: '3. Checkout Started',
        userCount: step3Users,
        eventCount: step3Events,
        conversionRate: rate3,
        stepColor: const Color(0xFFFB8C00),
      ),
      FunnelStepData(
        stepName: '4. Order Completed',
        userCount: step4Users,
        eventCount: step4Events,
        conversionRate: rate4,
        stepColor: const Color(0xFFE53935),
      ),
    ];
  }

  void _onFunnelStepSelected(String stepName) {
    String targetCategory = 'All';
    if (stepName.contains('Browse') || stepName.contains('1')) {
      targetCategory = 'product_search';
    } else if (stepName.contains('Cart') || stepName.contains('2')) {
      targetCategory = 'add_to_cart';
    } else if (stepName.contains('Checkout') || stepName.contains('3')) {
      targetCategory = 'checkout_started';
    } else if (stepName.contains('Order') || stepName.contains('4')) {
      targetCategory = 'payment_success';
    }

    // Toggle filter if clicking the already selected category
    if (_selectedEventCategory == targetCategory) {
      targetCategory = 'All';
    }

    setState(() {
      _selectedMetricFilter = 'All';
      _selectedPriority = 'All';
      _selectedEventCategory = targetCategory;
    });
    _rebuildCache();
  }

  final Set<String> _resolvingPincodes = {};

  void _asyncResolvePincode(String pincode) {
    if (pincode.length != 6 || _resolvingPincodes.contains(pincode)) return;
    _resolvingPincodes.add(pincode);
    PincodeService().resolve(pincode).then((success) {
      _resolvingPincodes.remove(pincode);
      if (success && mounted) {
        setState(() {}); // Rebuild map with new location intelligence
      }
    });
  }

  List<DistrictDemandData> _calculateDynamicDistrictData() {
    final Map<String, _DistrictTempData> districtMap = {};

    _DistrictTempData getOrCreate(String district, String state) {
      final key = '${district.toLowerCase()}_${state.toLowerCase()}';
      return districtMap.putIfAbsent(
        key,
        () => _DistrictTempData(districtName: district, stateName: state),
      );
    }

    try {
      final dealersState = context.read<DealersBloc>().state;
      for (final u in dealersState.allRawUsers) {
        final address = (u['address'] is Map) ? u['address'] as Map : {};
        
        // --- Smart Location Extraction Logic via PIN Code ---
        String district = '';
        String state = '';

        final rawPincode = (address['pincode'] ?? u['pincode'] ?? '').toString().trim();
        if (rawPincode.length == 6) {
          final loc = PincodeService().lookup(rawPincode);
          if (loc != null) {
            district = loc['district']!;
            state = loc['state']!;
          } else {
            _asyncResolvePincode(rawPincode);
          }
        }

        // Fallback to raw fields if PIN code didn't match our cache yet
        if (district.isEmpty) {
          district = (address['district'] ?? u['district'] ?? address['cityTehsil'] ?? u['city'] ?? '').toString().trim();
          state = (address['state'] ?? u['state'] ?? 'Maharashtra').toString().trim();
        }

        if (district.isNotEmpty && district.toLowerCase() != 'unknown') {
          final String rawUser = _normalizeId(u['_id']);
          String displayName = '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'.trim();
          if (displayName.isEmpty) displayName = (u['shopName'] ?? '').toString();
          final displayPhone = (u['phoneNumber'] ?? u['phone'] ?? '').toString();

          if (AuthService().isSales && !_isUserAssignedToCurrentSalesAgent(
            rawUser: rawUser,
            displayName: displayName,
            displayPhone: displayPhone,
            userDetails: u,
          )) {
            continue;
          }

          final entry = getOrCreate(district, state);
          entry.activeDealers++;

          final orderVal = (u['totalOrderValue'] ?? u['revenue'] ?? u['grossRevenue'] ?? 0) as num;
          entry.revenue += orderVal.toDouble();
          if (orderVal > 0) {
            entry.buyerUserIds.add(rawUser);
          }
        }
      }
    } catch (_) {}

    // 2. Process events logs to identify buying behavior and revenue
    _eventsLogs.forEach((catKey, logs) {
      for (final log in logs) {
        final userName = (log['user'] ?? log['userName'] ?? log['userEmail'] ?? log['userPhone'] ?? '').toString();
        if (AuthService().isSales && !_isUserAssignedToCurrentSalesAgent(
          rawUser: userName,
          displayName: userName,
          displayPhone: log['userPhone']?.toString(),
          userDetails: log['payload'] is Map<String, dynamic> ? log['payload'] as Map<String, dynamic> : null,
        )) {
          continue;
        }

        final payload = (log['payload'] is Map) ? log['payload'] as Map : {};
        final shipping = (payload['shippingAddress'] is Map) ? payload['shippingAddress'] as Map : {};
        
        // Smart PIN check for event logs too
        String district = '';
        String state = '';
        final eventPincode = (shipping['pincode'] ?? payload['pincode'] ?? log['pincode'] ?? '').toString().trim();
        if (eventPincode.length == 6) {
          final loc = PincodeService().lookup(eventPincode);
          if (loc != null) {
            district = loc['district']!;
            state = loc['state']!;
          } else {
            _asyncResolvePincode(eventPincode);
          }
        }

        if (district.isEmpty) {
          district = (shipping['district'] ?? shipping['cityTehsil'] ?? log['district'] ?? log['city'] ?? '').toString().trim();
          state = (shipping['state'] ?? log['state'] ?? 'Maharashtra').toString().trim();
        }

        final amount = (payload['totalAmount'] ?? log['amount'] ?? log['price'] ?? 0) as num;

        if (district.isNotEmpty && district.toLowerCase() != 'unknown') {
          final entry = getOrCreate(district, state);
          if (amount > 0) {
            entry.revenue += amount.toDouble();
            if (userName.isNotEmpty) {
              entry.buyerUserIds.add(userName);
            }
          }
        }
      }
    });

    if (districtMap.isEmpty) {
      return [];
    }

    final list = districtMap.values.where((e) => e.revenue > 0).toList();
    if (list.isEmpty) return [];

    list.sort((a, b) => b.revenue.compareTo(a.revenue));

    final categories = [
      'Seeds & Planting',
      'Fertilizers & Soil Care',
      'Irrigation & Drip Kits',
      'Crop Protection',
      'Tools & Machinery',
    ];
    int catIdx = 0;

    return list.map((e) {
      final double conversion = e.activeDealers > 0
          ? ((e.buyersCount / e.activeDealers) * 100).clamp(0.0, 100.0)
          : 0.0;
      final double index = ((e.activeDealers * 5) + (e.buyersCount * 15))
          .clamp(10, 99)
          .toDouble();
      final assignedCategory = categories[(catIdx++) % categories.length];
      return DistrictDemandData(
        districtName: e.districtName,
        stateName: e.stateName,
        primaryCrop: 'General Products',
        category: 'General Products',
        activeDealers: e.activeDealers,
        searchVolumeIndex: index,
        conversionRate: conversion,
        grossRevenueRupees: e.revenue,
      );
    }).toList();
  }

  Widget _buildActiveAnalyticsView() {
    if (AuthService().isSales) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
          border: Border.all(color: AppTheme.borderColor.withOpacity(0.6)),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Row(
          children: [
            const _LivePulsingBadge(color: Color(0xFF10B981)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Live Customer Telemetry Feed',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Monitoring real-time presence heartbeats, active sessions, and incoming telemetry events for your assigned customers below.',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    switch (_activeAnalyticsTab) {
      case 0:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
            border: Border.all(color: AppTheme.borderColor.withOpacity(0.6)),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Row(
            children: [
              const _LivePulsingBadge(color: Color(0xFF10B981)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Live Telemetry & Activity Feed',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Monitoring real-time presence heartbeats, active sessions, and incoming telemetry events below.',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      case 1:
        _funnelDataFuture ??= AnalyticsService().fetchFunnelData(
          days: _selectedAnalyticsTimeRange,
          customRange: _customAnalyticsDateRange,
        );
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _funnelDataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
              return const FunnelChartWidget(steps: [], isLoading: true);
            }
            final data = snapshot.data ?? [];
            if (data.isNotEmpty) {
              final colors = [
                const Color(0xFF1E88E5),
                const Color(0xFF43A047),
                const Color(0xFFFB8C00),
                const Color(0xFFE53935),
              ];
              final steps = List.generate(data.length, (i) {
                final item = data[i];
                final uCount = item['userCount'];
                final eCount = item['eventCount'];
                final cRate = item['conversionRate'];

                return FunnelStepData(
                  stepName: (item['stepName'] ?? item['step'] ?? 'Step ${i + 1}').toString(),
                  userCount: (uCount is num) ? uCount.toInt() : 0,
                  eventCount: (eCount is num) ? eCount.toInt() : 0,
                  conversionRate: (cRate is num) ? cRate.toDouble() : 0.0,
                  stepColor: colors[i % colors.length],
                );
              });
              return FunnelChartWidget(
                steps: steps,
                onStepSelected: _onFunnelStepSelected,
              );
            }
            return FunnelChartWidget(
              steps: _calculateDynamicFunnelSteps(),
              onStepSelected: _onFunnelStepSelected,
            );
          },
        );
      case 2:
        if (AuthService().isSales) {
          final districts = _calculateDynamicDistrictData();
          return AgriHeatmapWidget(districts: districts);
        }
        _districtDataFuture ??= AnalyticsService().fetchDistrictAnalytics(
          days: _selectedAnalyticsTimeRange,
          customRange: _customAnalyticsDateRange,
        );
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _districtDataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
              return const AgriHeatmapWidget(districts: [], isLoading: true);
            }
            final rawData = snapshot.data ?? [];
            final data = rawData.where((item) {
              final rev = item['grossRevenueRupees'];
              return (rev is num) && rev > 0;
            }).toList();
            List<DistrictDemandData> districts = [];
            if (data.isNotEmpty) {
              districts = data.map((item) {
                final dealers = item['activeDealers'] ?? item['activeFarmers'];
                final sIndex = item['searchVolumeIndex'];
                final cRate = item['conversionRate'];
                final rev = item['grossRevenueRupees'];
                final category = (item['category'] ?? 'General Products').toString();
                final subCategory = (item['subCategory'] ?? '').toString();

                Map<String, double>? catBreakdown;
                if (item['categoryBreakdown'] is Map) {
                  catBreakdown = Map<String, double>.from(
                    (item['categoryBreakdown'] as Map).map((k, v) => MapEntry(k.toString(), (v as num).toDouble())),
                  );
                }

                Map<String, double>? subCatBreakdown;
                if (item['subCategoryBreakdown'] is Map) {
                  subCatBreakdown = Map<String, double>.from(
                    (item['subCategoryBreakdown'] as Map).map((k, v) => MapEntry(k.toString(), (v as num).toDouble())),
                  );
                }

                Map<String, double>? prodBreakdown;
                if (item['productBreakdown'] is Map) {
                  prodBreakdown = Map<String, double>.from(
                    (item['productBreakdown'] as Map).map((k, v) => MapEntry(k.toString(), (v as num).toDouble())),
                  );
                }

                return DistrictDemandData(
                  districtName: (item['districtName'] ?? 'Unknown').toString(),
                  stateName: (item['stateName'] ?? 'Madhya Pradesh').toString(),
                  primaryCrop: (item['primaryCrop'] ?? category).toString(),
                  category: category,
                  subCategory: subCategory,
                  registeredDealers: (item['registeredDealers'] is num) ? (item['registeredDealers'] as num).toInt() : (dealers is num ? dealers.toInt() : 0),
                  activeBuyers: (item['activeBuyers'] is num) ? (item['activeBuyers'] as num).toInt() : 0,
                  activeDealers: (item['registeredDealers'] is num) ? (item['registeredDealers'] as num).toInt() : (dealers is num ? dealers.toInt() : 0),
                  searchVolumeIndex: (sIndex is num) ? sIndex.toDouble() : 50.0,
                  conversionRate: (cRate is num) ? cRate.toDouble() : 0.0,
                  grossRevenueRupees: (rev is num) ? rev.toDouble() : 0.0,
                  orderCount: (item['orderCount'] is num) ? (item['orderCount'] as num).toInt() : 0,
                  categoryBreakdown: catBreakdown,
                  subCategoryBreakdown: subCatBreakdown,
                  productBreakdown: prodBreakdown,
                );
              }).toList();
            } else {
              districts = _calculateDynamicDistrictData();
            }
            return AgriHeatmapWidget(districts: districts);
          },
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildUsersListHeader(bool isDesktop, int filteredCount) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppTheme.borderRadiusXLarge)),
        boxShadow: AppTheme.cardShadow,
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    'Users',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_isLoadingEvents && !_isBackgroundLoading)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$filteredCount matching',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                height: 40,
                width: isDesktop ? 300 : double.infinity,
                decoration: BoxDecoration(
                  color: AppTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.borderColor.withOpacity(0.8),
                  ),
                ),
                child: TextField(
                  controller: _userSearchController,
                  onChanged: (val) {
                    setState(() {
                      _userSearchQuery = val.trim();
                    });
                    _searchDebounce?.cancel();
                    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
                      _loadEvents(silent: true, searchQuery: val.trim());
                    });
                  },
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: AppTheme.textPrimary,
                  ),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    hintText: 'Search by name, shop, or phone (Global)...',
                    hintStyle: GoogleFonts.outfit(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      size: 16,
                      color: AppTheme.textSecondary,
                    ),
                    suffixIcon: _userSearchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 16),
                            onPressed: () {
                              _userSearchController.clear();
                              setState(() {
                                _userSearchQuery = '';
                              });
                              _loadEvents(silent: true, searchQuery: '');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                  ),
                ),
              ),
              _buildFilterDropdown(
                label: AuthService().isSales ? 'Customer Type' : 'User Type',
                value: _selectedUserType,
                options: AuthService().isSales
                    ? ['All', 'Dealer', 'Lead']
                    : ['All', 'Dealer', 'Lead', 'Guest'],
                onChanged: (val) => setState(() => _selectedUserType = val!),
              ),
              _buildFilterDropdown(
                label: 'Priority',
                value: _selectedPriority,
                options: ['All', 'High Priority'],
                onChanged: (val) {
                  setState(() {
                    _selectedPriority = val!;
                    _selectedMetricFilter = val;
                  });
                  _loadEvents(silent: false, metricFilter: val);
                },
              ),
              _buildFilterDropdown(
                label: 'Event Category',
                value: _selectedEventCategory,
                options: [
                  'All',
                  ..._eventTypes.map((e) => e['id'] as String),
                ],
                displayLabels: {
                  'All': 'All Categories',
                  ...Map.fromEntries(
                    _eventTypes.map((e) => MapEntry(e['id'] as String, e['label'] as String)),
                  ),
                },
                onChanged: (val) {
                  setState(() {
                    _selectedEventCategory = val!;
                  });
                  _loadEvents(silent: false);
                },
              ),
              if (_selectedUserType != 'All' ||
                  _selectedPriority != 'All' ||
                  _selectedMetricFilter != 'All' ||
                  _selectedEventCategory != 'All' ||
                  _userSearchQuery.isNotEmpty)
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedUserType = 'All';
                      _selectedPriority = 'All';
                      _selectedMetricFilter = 'All';
                      _selectedEventCategory = 'All';
                      _userSearchQuery = '';
                      _userSearchController.clear();
                    });
                    _loadEvents(silent: false, metricFilter: 'All');
                  },
                  icon: const Icon(Icons.filter_list_off_rounded, size: 14),
                  label: Text(
                    'Reset',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: TextButton.styleFrom(foregroundColor: AppTheme.error),
                ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildEmptyUsersList() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(AppTheme.borderRadiusXLarge)),
        boxShadow: AppTheme.cardShadow,
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 28,
              color: AppTheme.textSecondary.withOpacity(0.4),
            ),
            const SizedBox(height: 8),
            Text(
              'No users found',
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildRealTimeStats() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const _LivePulsingBadge(color: Color(0xFF10B981)),
                  const SizedBox(width: 10),
                  Text(
                    'Live Users Presence',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              Text(
                '${_realTimeUsers.length} Active Now',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF10B981),
                ),
              ),
            ],
          ),
          if (_realTimeUsers.isNotEmpty) ...[
            const SizedBox(height: 16),
            SizedBox(
              height: 100,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _realTimeUsers.length,
                separatorBuilder: (context, index) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final user = _realTimeUsers[index];
                  final enriched = _enrichUserPresence(
                    user['user']?.toString() ?? '',
                    user['userName']?.toString(),
                    user['userPhone']?.toString(),
                  );
                  final displayName = enriched['name'] ?? 'Unknown';
                  final displayPhone = enriched['phone'] ?? '';

                  return MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () => _scrollToAndExpandUser(displayName),
                      child: Container(
                        width: 180,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.backgroundColor,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.borderColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (displayPhone.isNotEmpty &&
                                displayPhone != displayName)
                              Text(
                                displayPhone,
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.touch_app_outlined,
                                  size: 12,
                                  color: AppTheme.primaryColor,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    user['action'] ?? 'Browsing',
                                    style: GoogleFonts.outfit(
                                      fontSize: 11,
                                      color: AppTheme.textSecondary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  user['currentScreen'] ?? 'Home',
                                  style: GoogleFonts.outfit(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                                if (user['_localLastSeen'] != null)
                                  Text(
                                    _getRelativeLastSeen(
                                      user['_localLastSeen'],
                                    ),
                                    style: GoogleFonts.outfit(
                                      fontSize: 9,
                                      color: AppTheme.textSecondary.withOpacity(
                                        0.6,
                                      ),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getRelativeLastSeen(int timestamp) {
    final diff = DateTime.now().millisecondsSinceEpoch - timestamp;
    if (diff < 15000) return 'Live';
    if (diff < 60000) return '${(diff / 1000).floor()}s ago';
    return '${(diff / 60000).floor()}m ago';
  }

  Widget _buildSummaryCards(bool isDesktop) {
    final int highPriorityCount = _globalHighPriorityCount;
    final int failedPaymentsCount = _globalFailedPaymentsCount;
    final int abandonedCartsCount = _globalAbandonedCartsCount;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double spacing = 12.0;
        final int columns = isDesktop ? 4 : 2;
        final double cardWidth =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            _buildMetricCard(
              'High Priority',
              '$highPriorityCount',
              'Users needing action',
              Icons.priority_high_rounded,
              Colors.redAccent,
              cardWidth,
              onTap: () {
                setState(() {
                  if (_selectedMetricFilter == 'High Priority') {
                    _selectedMetricFilter = 'All';
                    _selectedPriority = 'All';
                  } else {
                    _selectedMetricFilter = 'High Priority';
                    _selectedPriority = 'High Priority';
                  }
                });
                _loadEvents(silent: false, metricFilter: _selectedMetricFilter);
              },
              isSelected: _selectedMetricFilter == 'High Priority',
            ),
            _buildMetricCard(
              'Abandoned Carts',
              '$abandonedCartsCount',
              'Incomplete purchases',
              Icons.shopping_cart_checkout_rounded,
              Colors.orange,
              cardWidth,
              onTap: () {
                setState(() {
                  if (_selectedMetricFilter == 'Abandoned Carts') {
                    _selectedMetricFilter = 'All';
                  } else {
                    _selectedMetricFilter = 'Abandoned Carts';
                    _selectedPriority = 'All';
                  }
                });
                _loadEvents(silent: false, metricFilter: _selectedMetricFilter);
              },
              isSelected: _selectedMetricFilter == 'Abandoned Carts',
            ),
            _buildMetricCard(
              'Failed Payments',
              '$failedPaymentsCount',
              'Checkout errors',
              Icons.error_outline_rounded,
              Colors.red,
              cardWidth,
              onTap: () {
                setState(() {
                  if (_selectedMetricFilter == 'Failed Payments') {
                    _selectedMetricFilter = 'All';
                  } else {
                    _selectedMetricFilter = 'Failed Payments';
                    _selectedPriority = 'All';
                  }
                });
                _loadEvents(silent: false, metricFilter: _selectedMetricFilter);
              },
              isSelected: _selectedMetricFilter == 'Failed Payments',
            ),
            _buildMetricCard(
              'Live Users',
              '${_realTimeUsers.length}',
              'Currently active',
              Icons.bolt_rounded,
              const Color(0xFF10B981),
              cardWidth,
              onTap: () {
                setState(() {
                  if (_selectedMetricFilter == 'Live Users') {
                    _selectedMetricFilter = 'All';
                  } else {
                    _selectedMetricFilter = 'Live Users';
                    _selectedPriority = 'All';
                  }
                });
              },
              isSelected: _selectedMetricFilter == 'Live Users',
            ),
          ],
        );
      },
    );
  }

  Widget _buildShimmerLoading(bool isDesktop) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 28 : 16,
        vertical: isDesktop ? 20 : 12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary Cards Shimmer
          LayoutBuilder(
            builder: (context, constraints) {
              final double spacing = 12.0;
              final int columns = isDesktop ? 4 : 2;
              final double cardWidth =
                  (constraints.maxWidth - (spacing * (columns - 1))) / columns;

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: List.generate(4, (index) {
                  return Container(
                    width: cardWidth,
                    height: 120,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: Shimmer.fromColors(
                      baseColor: Colors.grey[200]!,
                      highlightColor: Colors.white,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            width: 50,
                            height: 20,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: 100,
                            height: 14,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              );
            },
          ),
          const SizedBox(height: 20),

          // Live Users Presence Shimmer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 150,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    Container(
                      width: 80,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 100,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: 5,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      return Container(
                        width: 180,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.backgroundColor,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.borderColor),
                        ),
                        child: Shimmer.fromColors(
                          baseColor: Colors.grey[200]!,
                          highlightColor: Colors.white,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 100,
                                height: 14,
                                color: Colors.white,
                              ),
                              const SizedBox(height: 6),
                              Container(
                                width: 80,
                                height: 12,
                                color: Colors.white,
                              ),
                              const Spacer(),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    width: 50,
                                    height: 10,
                                    color: Colors.white,
                                  ),
                                  Container(
                                    width: 30,
                                    height: 10,
                                    color: Colors.white,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Users list shimmer
          Container(
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusXLarge),
              border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 100,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    Container(
                      width: 80,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Filters shimmer
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    Container(
                      width: isDesktop ? 300 : double.infinity,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    Container(
                      width: 120,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    Container(
                      width: 120,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // User cards shimmers
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 3,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.borderColor.withOpacity(0.4),
                        ),
                      ),
                      child: Shimmer.fromColors(
                        baseColor: Colors.grey[200]!,
                        highlightColor: Colors.white,
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 150,
                                    height: 16,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    width: 100,
                                    height: 12,
                                    color: Colors.white,
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.keyboard_arrow_down,
                              size: 18,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
    String title,
    String value,
    String subtitle,
    IconData icon,
    Color color,
    double width, {
    VoidCallback? onTap,
    bool isSelected = false,
  }) {
    return MouseRegion(
      cursor: onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: width,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.08) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : AppTheme.borderColor,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 18, color: color),
                  ),
                  if (isSelected)
                    Icon(Icons.check_circle_rounded, size: 16, color: color),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
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
    );
  }



  String _getUserType(String userName) {
    return _cachedUserTypes[userName] ?? 'Guest';
  }
}

class _LivePulsingBadge extends StatefulWidget {
  final Color? color;
  const _LivePulsingBadge({this.color});

  @override
  State<_LivePulsingBadge> createState() => _LivePulsingBadgeState();
}

class _LivePulsingBadgeState extends State<_LivePulsingBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _pulseAnimation = Tween<double>(begin: 1.0, end: 2.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final badgeColor = widget.color ?? AppTheme.warning;
    return SizedBox(
      width: 24,
      height: 24,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Container(
                width: 10 * _pulseAnimation.value,
                height: 10 * _pulseAnimation.value,
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(
                    0.35 * (2.2 - _pulseAnimation.value),
                  ),
                  shape: BoxShape.circle,
                ),
              );
            },
          ),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: badgeColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: badgeColor.withOpacity(0.4),
                  blurRadius: 4,
                  spreadRadius: 1.5,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UserCard extends StatefulWidget {
  final String name;
  final String userType;
  final Map<String, List<Map<String, dynamic>>> groupedEvents;
  final bool isSelected;
  final String? selectedEventType;
  final List<Map<String, dynamic>> eventTypes;
  final Function(String categoryId) onCategorySelected;
  final VoidCallback onTap;
  final Function(String user) onViewProfile;
  final bool isOnline;
  final bool isHighPriority;
  final String priorityReason;
  final bool isLoadingEvents;

  const _UserCard({
    super.key,
    required this.name,
    required this.userType,
    required this.groupedEvents,
    required this.isSelected,
    required this.selectedEventType,
    required this.eventTypes,
    required this.onTap,
    required this.onCategorySelected,
    required this.onViewProfile,
    this.isOnline = false,
    this.isHighPriority = false,
    this.priorityReason = '',
    this.isLoadingEvents = false,
  });

  @override
  State<_UserCard> createState() => _UserCardState();
}

class _UserCardState extends State<_UserCard>
    with SingleTickerProviderStateMixin {
  bool _hovered = false;

  Future<void> _makePhoneCall(String phoneNumber) async {
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleanPhone.isEmpty) return;
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _openWhatsApp(BuildContext context, String phoneNumber, String name) {
    showDialog(
      context: context,
      builder: (context) => WhatsAppChatDialog(
        phone: phoneNumber,
        name: name,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isSelected = widget.isSelected;
    final bool isHovered = _hovered;

    // Calculate total events for this user
    int totalEvents = 0;
    widget.groupedEvents.forEach((_, logs) {
      totalEvents += logs.length;
    });

    // Extract phone number from events if available
    String? userPhone;
    for (final logs in widget.groupedEvents.values) {
      for (final log in logs) {
        if (log['userPhone'] != null) {
          userPhone = log['userPhone'] as String?;
          break;
        }
      }
      if (userPhone != null) break;
    }

    final String initials = widget.name.isNotEmpty
        ? widget.name
              .split(' ')
              .map((e) => e.isNotEmpty ? e[0] : '')
              .take(2)
              .join()
              .toUpperCase()
        : 'U';

    Color bg;
    Color border;
    Color titleColor;
    Color avatarBg;

    if (isSelected) {
      bg = AppTheme.primaryColor.withOpacity(0.04);
      border = AppTheme.primaryColor.withOpacity(0.25);
      titleColor = AppTheme.primaryColor;
      avatarBg = AppTheme.primaryColor.withOpacity(0.12);
    } else if (isHovered) {
      bg = AppTheme.primaryColor.withOpacity(0.015);
      border = AppTheme.borderColor.withOpacity(0.8);
      titleColor = AppTheme.textPrimary;
      avatarBg = AppTheme.textSecondary.withOpacity(0.1);
    } else {
      bg = Colors.transparent;
      border = AppTheme.borderColor.withOpacity(0.4);
      titleColor = AppTheme.textPrimary;
      avatarBg = AppTheme.borderColor.withOpacity(0.4);
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border, width: 1.0),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Stack(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: avatarBg,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          initials,
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? AppTheme.primaryColor
                                : AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      if (widget.isOnline)
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: const _LivePulsingBadge(
                            color: Color(0xFF10B981),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                widget.name,
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: titleColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildUserTypeBadge(context, widget.name),
                            if (widget.isHighPriority) ...[
                              const SizedBox(width: 8),
                              Builder(
                                builder: (context) {
                                  final bool isCartIssue = widget.priorityReason == 'Abandoned Cart' || widget.priorityReason == 'Abandoned Checkout';
                                  final Color badgeColor = isCartIssue ? Colors.orange : AppTheme.error;
                                  final IconData badgeIcon = isCartIssue ? Icons.shopping_cart_outlined : Icons.priority_high_rounded;

                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: badgeColor.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: badgeColor.withOpacity(0.2),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          badgeIcon,
                                          size: 10,
                                          color: badgeColor,
                                        ),
                                        const SizedBox(width: 2),
                                        Text(
                                          widget.priorityReason.isNotEmpty
                                              ? widget.priorityReason
                                              : 'High Priority',
                                          style: GoogleFonts.outfit(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w900,
                                            color: badgeColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                              ),
                            ],
                          ],
                        ),

                        if (userPhone != null && userPhone.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                userPhone,
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textSecondary.withValues(alpha: 0.8),
                                ),
                              ),
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: () => _makePhoneCall(userPhone!),
                                borderRadius: BorderRadius.circular(4),
                                child: const Padding(
                                  padding: EdgeInsets.all(2.0),
                                  child: Icon(
                                    Icons.phone_rounded,
                                    size: 14,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              InkWell(
                                onTap: () => _openWhatsApp(context, userPhone!, widget.name),
                                borderRadius: BorderRadius.circular(4),
                                child: const Padding(
                                  padding: EdgeInsets.all(2.0),
                                  child: Icon(
                                    Icons.chat_rounded,
                                    size: 14,
                                    color: Color(0xFF10B981),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 2),
                        Text(
                          '$totalEvents event${totalEvents == 1 ? "" : "s"} • ${widget.groupedEvents.length} categor${widget.groupedEvents.length == 1 ? "y" : "ies"}',
                          style: GoogleFonts.outfit(
                            fontSize: 12.5,
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isSelected
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 18,
                    color: isSelected
                        ? AppTheme.primaryColor
                        : AppTheme.textSecondary,
                  ),
                ],
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                child: isSelected
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Categories',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              Row(
                                children: [
                                  TextButton.icon(
                                    onPressed: () =>
                                        widget.onViewProfile(widget.name),
                                    icon: const Icon(
                                      Icons.launch_rounded,
                                      size: 13,
                                    ),
                                    label: Text(
                                      'View Profile',
                                      style: GoogleFonts.outfit(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    style: TextButton.styleFrom(
                                      foregroundColor: AppTheme.primaryColor,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          if (widget.isLoadingEvents) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Fetching latest customer events...',
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ] else if (widget.groupedEvents.isEmpty) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: AppTheme.backgroundColor,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.5)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.info_outline_rounded, size: 16, color: AppTheme.textSecondary),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'No recent events recorded for this customer.',
                                      style: GoogleFonts.outfit(
                                        fontSize: 12,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          _buildCategoriesWrap(context),
                          if (widget.selectedEventType != null &&
                              widget.groupedEvents.containsKey(
                                widget.selectedEventType,
                              )) ...[
                            const SizedBox(height: 16),
                            const Divider(
                              height: 1,
                              color: AppTheme.lightBorderColor,
                            ),
                            const SizedBox(height: 12),
                            _buildInlineFeed(context),
                          ],
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoriesWrap(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12.0),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: widget.groupedEvents.entries.map((entry) {
          final categoryId = entry.key;
          final logs = entry.value;
          final isCategorySelected =
              widget.isSelected && widget.selectedEventType == categoryId;

          // Find category styling info
          final catData = widget.eventTypes.firstWhere(
            (t) => t['id'] == categoryId,
            orElse: () => {
              'label': categoryId,
              'icon': Icons.info_outline,
              'color': Colors.grey,
            },
          );

          final String label = catData['label'] as String;
          final IconData icon = catData['icon'] as IconData;

          return InkWell(
            onTap: () => widget.onCategorySelected(categoryId),
            borderRadius: BorderRadius.circular(16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isCategorySelected
                    ? AppTheme.primaryColor
                    : AppTheme.backgroundColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isCategorySelected
                      ? AppTheme.primaryColor
                      : AppTheme.borderColor,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 13,
                    color: isCategorySelected
                        ? Colors.white
                        : AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isCategorySelected
                          ? Colors.white
                          : AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 0.5,
                    ),
                    decoration: BoxDecoration(
                      color: isCategorySelected
                          ? Colors.white.withOpacity(0.2)
                          : AppTheme.lightBorderColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${logs.length}',
                      style: GoogleFonts.outfit(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: isCategorySelected
                            ? Colors.white
                            : AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildInlineFeed(BuildContext context) {
    final logs = widget.groupedEvents[widget.selectedEventType!] ?? [];

    final catData = widget.eventTypes.firstWhere(
      (t) => t['id'] == widget.selectedEventType,
      orElse: () => {'label': widget.selectedEventType, 'color': Colors.grey},
    );
    final String label = catData['label'] as String;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Active Feed: $label',
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${logs.length} event${logs.length == 1 ? "" : "s"}',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: logs.length,
          separatorBuilder: (context, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final log = logs[index];
            return _EventLogCard(
              user: log['user'] as String,
              userPhone: log['userPhone'] as String?,
              rawUser: log['rawUser'] as String?,
              time: log['time'] as String,
              device: log['device'] as String,
              details: log['details'] as String,
              payload: log['payload'] as Map<String, dynamic>,
              accentColor: AppTheme.primaryColor,
            );
          },
        ),
      ],
    );
  }

  Widget _buildUserTypeBadge(BuildContext context, String userName) {
    final type = widget.userType;
    if (type == 'Guest') return const SizedBox.shrink();

    final isDealer = type == 'Dealer';
    final bgColor = isDealer
        ? const Color(0xFF10B981).withOpacity(0.08)
        : const Color(0xFFF59E0B).withOpacity(0.08);
    final textColor = isDealer
        ? const Color(0xFF10B981)
        : const Color(0xFFF59E0B);
    final icon = isDealer ? Icons.verified_rounded : Icons.info_outline_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: textColor.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: textColor),
          const SizedBox(width: 2),
          Text(
            type,
            style: GoogleFonts.outfit(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

void _navigateToProfile(BuildContext context, String user) {
  final nameLower = user.toLowerCase();

  // 1. Try to find in Dealers first (Real database records)
  final dealersState = context.read<DealersBloc>().state;
  final Map<String, dynamic>? dealerData = dealersState.allRawUsers.firstWhere((
    u,
  ) {
    final String fullName = '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'
        .trim()
        .toLowerCase();
    final String phone = (u['phoneNumber'] ?? '').toString();
    final String shopName = (u['shopName'] ?? '').toString().toLowerCase();
    return fullName == nameLower ||
        phone == user ||
        shopName == nameLower ||
        fullName.contains(nameLower) ||
        nameLower.contains(fullName);
  }, orElse: () => <String, dynamic>{});

  if (dealerData != null && dealerData.isNotEmpty) {
    final kycStatus =
        dealerData['kycStatus']?.toString().toLowerCase() ?? 'pending';
    final isDealer = kycStatus == 'verified';

    if (isDealer) {
      final agentName = dealerData['assignedAgent'] != null
          ? '${dealerData['assignedAgent']['firstName'] ?? ''} ${dealerData['assignedAgent']['lastName'] ?? ''}'
                .trim()
          : '-';

      final String personName =
          (dealerData['firstName'] != null || dealerData['lastName'] != null)
          ? '${dealerData['firstName'] ?? ''} ${dealerData['lastName'] ?? ''}'
                .trim()
          : '';

      final dealer = Dealer(
        name: personName.isNotEmpty
            ? personName
            : (dealerData['phoneNumber'] ?? user),
        phone: dealerData['phoneNumber'] ?? '',
        city: dealerData['address']?['cityTehsil'] ?? '',
        state: dealerData['address']?['state'] ?? '',
        agent: agentName,
        gstStatus: 'Verified',
        totalOrders: 0,
        purchaseValue: '₹0',
        isHighValue: false,
        isInactive: false,
        id: dealerData['_id'],
        agentId: dealerData['assignedAgent']?['_id'],
        kycStatus: dealerData['kycStatus'],
        shopName: dealerData['shopName'],
        address: dealerData['address'],
        status: dealerData['status'] ?? dealerData['leadStatus'] ?? 'prospect',
        notes: dealerData['notes'] ?? dealerData['leadNotes'] ?? '',
        notesHistory: dealerData['notesHistory'] != null
            ? List<Map<String, dynamic>>.from(dealerData['notesHistory'])
            : [],
      );

      Navigator.pushNamed(context, '/dealers/profile', arguments: dealer);
      return;
    } else {
      // Treat as Lead
      final String personName =
          (dealerData['firstName'] != null || dealerData['lastName'] != null)
          ? '${dealerData['firstName'] ?? ''} ${dealerData['lastName'] ?? ''}'
                .trim()
          : '';

      final leadMap = {
        'id': dealerData['_id'],
        'name': personName.isNotEmpty
            ? personName
            : (dealerData['phoneNumber'] ?? user),
        'phone': dealerData['phoneNumber'] ?? '',
        'shopName': dealerData['shopName'] ?? '',
        'villageArea': dealerData['address']?['villageArea'] ?? '',
        'city': dealerData['address']?['cityTehsil'] ?? '',
        'state': dealerData['address']?['state'] ?? '',
        'pincode': dealerData['address']?['pincode'] ?? '',
        'source': dealerData['source'] ?? 'App',
        'kycStatus': dealerData['kycStatus'] ?? 'pending',
        'status':
            dealerData['status'] ?? dealerData['leadStatus'] ?? 'prospect',
        'notes': dealerData['notes'] ?? dealerData['leadNotes'] ?? '',
        'notesHistory': dealerData['notesHistory'] ?? [],
      };

      Navigator.pushNamed(context, '/leads/profile', arguments: leadMap);
      return;
    }
  }

  // 2. Try to find in fallback static dealers list (allDealers)
  Dealer? matchedDealer;
  for (final d in allDealers) {
    if (d.name.toLowerCase().contains(nameLower) ||
        nameLower.contains(d.name.toLowerCase().split(' ').first)) {
      matchedDealer = d;
      break;
    }
  }

  if (matchedDealer != null) {
    Navigator.pushNamed(context, '/dealers/profile', arguments: matchedDealer);
    return;
  }

  // 3. Not a dealer, so it must be a Lead! Let's find in Leads first.
  final leadsState = context.read<LeadsBloc>().state;
  final Map<String, dynamic>? leadData = leadsState.allRawUsers.firstWhere((u) {
    final String fullName = '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'
        .trim()
        .toLowerCase();
    final String phone = (u['phoneNumber'] ?? '').toString();
    return fullName == nameLower ||
        phone == user ||
        fullName.contains(nameLower);
  }, orElse: () => <String, dynamic>{});

  if (leadData != null && leadData.isNotEmpty) {
    final kycStatus =
        leadData['kycStatus']?.toString().toLowerCase() ?? 'pending';
    final isDealer = kycStatus == 'verified';

    if (isDealer) {
      final agentName = leadData['assignedAgent'] != null
          ? '${leadData['assignedAgent']['firstName'] ?? ''} ${leadData['assignedAgent']['lastName'] ?? ''}'
                .trim()
          : '-';

      final String personName =
          (leadData['firstName'] != null || leadData['lastName'] != null)
          ? '${leadData['firstName'] ?? ''} ${leadData['lastName'] ?? ''}'
                .trim()
          : '';

      final dealer = Dealer(
        name: personName.isNotEmpty
            ? personName
            : (leadData['phoneNumber'] ?? user),
        phone: leadData['phoneNumber'] ?? '',
        city: (leadData['address'] as Map?)?['cityTehsil'] ?? '',
        state: (leadData['address'] as Map?)?['state'] ?? '',
        agent: agentName,
        gstStatus: 'Verified',
        totalOrders: 0,
        purchaseValue: '₹0',
        isHighValue: false,
        isInactive: false,
        id: leadData['_id'],
        agentId: leadData['assignedAgent']?['_id'],
        kycStatus: 'verified',
        shopName: leadData['shopName'],
        address: leadData['address'],
        status: leadData['status'] ?? leadData['leadStatus'] ?? 'prospect',
        notes: leadData['notes'] ?? leadData['leadNotes'] ?? '',
        notesHistory: leadData['notesHistory'] != null
            ? List<Map<String, dynamic>>.from(leadData['notesHistory'])
            : [],
      );

      Navigator.pushNamed(context, '/dealers/profile', arguments: dealer);
      return;
    } else {
      // Map raw user to lead map format expected by LeadProfilePage
      final String personName =
          (leadData['firstName'] != null || leadData['lastName'] != null)
          ? '${leadData['firstName'] ?? ''} ${leadData['lastName'] ?? ''}'
                .trim()
          : '';

      final leadMap = {
        'id': leadData['_id'],
        'name': personName.isNotEmpty
            ? personName
            : (leadData['phoneNumber'] ?? user),
        'phone': leadData['phoneNumber'] ?? '',
        'shopName': leadData['shopName'] ?? '',
        'villageArea': leadData['address']?['villageArea'] ?? '',
        'city': leadData['address']?['cityTehsil'] ?? '',
        'state': leadData['address']?['state'] ?? '',
        'pincode': leadData['address']?['pincode'] ?? '',
        'source': leadData['source'] ?? 'App',
        'kycStatus': leadData['kycStatus'] ?? 'pending',
        'status': leadData['status'] ?? leadData['leadStatus'] ?? 'prospect',
        'notes': leadData['notes'] ?? leadData['leadNotes'] ?? '',
        'notesHistory': leadData['notesHistory'] ?? [],
      };

      Navigator.pushNamed(context, '/leads/profile', arguments: leadMap);
      return;
    }
  }

  // 4. Default fallback: Navigate to leads profile with a default leadMap
  final leadMap = {
    'id': user,
    'name': user,
    'phone': '',
    'shopName': '',
    'villageArea': '',
    'city': 'Unknown',
    'state': 'Unknown',
    'pincode': '',
    'source': 'App',
    'kycStatus': 'pending',
    'status': 'prospect',
    'notes': '',
    'notesHistory': [],
  };
  Navigator.pushNamed(context, '/leads/profile', arguments: leadMap);
}

class _EventLogCard extends StatefulWidget {
  final String user;
  final String? userPhone;
  final String? rawUser;
  final String time;
  final String device;
  final String details;
  final Map<String, dynamic> payload;
  final Color accentColor;

  const _EventLogCard({
    required this.user,
    this.userPhone,
    this.rawUser,
    required this.time,
    required this.device,
    required this.details,
    required this.payload,
    required this.accentColor,
  });

  @override
  State<_EventLogCard> createState() => _EventLogCardState();
}

class _EventLogCardState extends State<_EventLogCard> {
  bool _expanded = false;
  bool _hovered = false;
  bool _showRawJson = false;

  Future<void> _makePhoneCall(String phoneNumber) async {
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleanPhone.isEmpty) return;
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _openWhatsApp(BuildContext context, String phoneNumber, String name) {
    showDialog(
      context: context,
      builder: (context) => WhatsAppChatDialog(
        phone: phoneNumber,
        name: name,
      ),
    );
  }

  Map<String, dynamic> _getEventTheme() {
    final payload = widget.payload;
    final action = (payload['action'] ?? payload['eventType'] ?? '').toString().toLowerCase();

    if (action.contains('payment_failed') || action == 'payment_fail') {
      return {
        'color': const Color(0xFFEF4444),
        'bgColor': const Color(0xFFFEF2F2),
        'borderColor': const Color(0xFFFCA5A5),
        'tag': 'FAILED PAYMENT',
        'icon': Icons.error_rounded,
      };
    } else if (action.contains('payment_success') || action.contains('order')) {
      return {
        'color': const Color(0xFF10B981),
        'bgColor': const Color(0xFFECFDF5),
        'borderColor': const Color(0xFF6EE7B7),
        'tag': 'SUCCESS',
        'icon': Icons.check_circle_rounded,
      };
    } else if (action == 'cart_add' || action == 'add_to_cart' || action.contains('checkout')) {
      return {
        'color': const Color(0xFFF59E0B),
        'bgColor': const Color(0xFFFFFBEB),
        'borderColor': const Color(0xFFFDE68A),
        'tag': 'HIGH INTENT',
        'icon': Icons.shopping_cart_rounded,
      };
    } else if (action.contains('search') || action.contains('view')) {
      return {
        'color': const Color(0xFF0284C7),
        'bgColor': const Color(0xFFF0F9FF),
        'borderColor': const Color(0xFFBAE6FD),
        'tag': 'BROWSING',
        'icon': Icons.visibility_rounded,
      };
    }
    return {
      'color': AppTheme.primaryColor,
      'bgColor': AppTheme.primaryColor.withOpacity(0.06),
      'borderColor': AppTheme.primaryColor.withOpacity(0.2),
      'tag': 'ACTIVITY',
      'icon': Icons.bolt_rounded,
    };
  }

  String _getHumanHeadline() {
    final payload = widget.payload;
    final action = (payload['action'] ?? payload['eventType'] ?? '').toString().toLowerCase();
    final details = widget.details;

    if (action == 'cart_add' || action == 'add_to_cart') {
      final qty = payload['quantity'] ?? 1;
      final prodName = payload['product_name'] ?? 'Product';
      final price = payload['unit_price'] ?? payload['price'];
      final priceStr = price is num ? ' (₹${(price * qty).toStringAsFixed(0)})' : '';
      return '🛒 Added $qty' + 'x $prodName to Cart$priceStr';
    } else if (action.contains('payment_failed') || action == 'payment_fail') {
      final amt = payload['amount'] ?? payload['total_price'] ?? payload['grand_total'];
      final amtStr = amt is num ? ' ₹${amt.toStringAsFixed(0)}' : '';
      final gw = payload['payment_method'] ?? payload['gateway'] ?? 'Online Payment';
      final reason = payload['error_message'] ?? payload['reason'];
      final reasonStr = reason != null && reason.toString().isNotEmpty ? ' — Cause: $reason' : '';
      return '❌ Payment of$amtStr Failed via $gw$reasonStr';
    } else if (action.contains('payment_success') || action.contains('payment_completed')) {
      final amt = payload['amount'] ?? payload['total_price'] ?? payload['grand_total'];
      final amtStr = amt is num ? ' ₹${amt.toStringAsFixed(0)}' : '';
      final gw = payload['payment_method'] ?? payload['gateway'] ?? 'Online Payment';
      return '🟢 Payment of$amtStr Received via $gw';
    } else if (action.contains('order') || action.contains('checkout_completed')) {
      final orderId = payload['order_id'] ?? payload['orderId'] ?? '';
      final amt = payload['amount'] ?? payload['total_price'] ?? payload['total'];
      final amtStr = amt is num ? ' • Total: ₹${amt.toStringAsFixed(0)}' : '';
      return '📦 Order ${orderId.isNotEmpty ? "#$orderId" : ""} Placed Successfully$amtStr';
    } else if (action.contains('checkout')) {
      final items = payload['item_count'] ?? payload['items_count'];
      final itemsStr = items != null ? ' ($items items in cart)' : '';
      return '🛍️ Started Checkout Process$itemsStr';
    } else if (action.contains('search')) {
      final query = payload['query'] ?? payload['search_term'] ?? '';
      final results = payload['results_count'];
      final resultsStr = results != null ? ' ($results items found)' : '';
      return '🔍 Searched for "${query.isNotEmpty ? query : details}"$resultsStr';
    } else if (action.contains('login') || action.contains('auth')) {
      final method = payload['method'] ?? payload['auth_method'] ?? 'App OTP';
      return '🔑 Logged in via $method';
    } else if (action.contains('view') || action.contains('screen')) {
      final page = payload['screen_name'] ?? payload['product_name'] ?? details;
      return '👀 Viewed: ${page.isNotEmpty ? page : "App Screen"}';
    } else if (details.isNotEmpty) {
      return details;
    }
    return '⚡ Customer activity logged (${action.isNotEmpty ? action : "User Action"})';
  }

  String? _getSalesActionRecommendation() {
    final payload = widget.payload;
    final action = (payload['action'] ?? payload['eventType'] ?? '').toString().toLowerCase();

    if (action == 'cart_add' || action == 'add_to_cart') {
      return '💡 Sales Tip: High purchase intent! Call the customer to assist with ordering or offer special pricing.';
    } else if (action.contains('payment_failed') || action == 'payment_fail') {
      return '🚨 Sales Tip: Payment failed! Contact user now to help them finish order via manual UPI or Bank Deposit.';
    } else if (action.contains('checkout')) {
      return '⚡ Sales Tip: Customer is in checkout! Follow up on WhatsApp if they drop off without ordering.';
    } else if (action.contains('search') || action.contains('view')) {
      return '🔍 Sales Tip: Active browsing. Reach out to guide them on product choice.';
    }
    return null;
  }

  String _formatKey(String key) {
    final mappedKeys = {
      'unit_price': 'Unit Price (₹)',
      'product_name': 'Product Name',
      'variant_name': 'Variant',
      'quantity': 'Quantity',
      'total_price': 'Total Price (₹)',
      'grand_total': 'Grand Total (₹)',
      'amount': 'Amount (₹)',
      'payment_method': 'Payment Mode',
      'gateway': 'Payment Gateway',
      'screen_name': 'Page Viewed',
      'error_message': 'Failure Reason',
      'reason': 'Failure Reason',
      'user_phone': 'Customer Phone',
      'query': 'Search Query',
      'results_count': 'Results Found',
      'item_count': 'Total Items',
    };
    if (mappedKeys.containsKey(key)) return mappedKeys[key]!;

    final words = key.split('_');
    return words
        .map((w) {
          if (w.isEmpty) return '';
          final lower = w.toLowerCase();
          if (lower == 'sso') return 'SSO';
          if (lower == 'id') return 'ID';
          if (lower == 'txn') return 'TXN';
          if (lower == 'kyc') return 'KYC';
          if (lower == 'gst') return 'GST';
          if (lower == 'otp') return 'OTP';
          return w[0].toUpperCase() + w.substring(1);
        })
        .join(' ');
  }

  dynamic _formatValue(String key, dynamic value) {
    if (value == null) return 'N/A';

    if (key.contains('amount') ||
        key.contains('total') ||
        key == 'subtotal' ||
        key == 'tax' ||
        key == 'shipping' ||
        key == 'grand_total' ||
        key == 'unit_price') {
      if (value is num) {
        return '₹${value.toStringAsFixed(2).replaceAll('.00', '')}';
      }
    }

    if (key.contains('at') && value is String && value.contains('T')) {
      try {
        final dt = DateTime.parse(value);
        return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      } catch (_) {}
    }

    if (value is List) {
      return Wrap(
        spacing: 4,
        runSpacing: 4,
        children: value
            .map<Widget>(
              (item) => Container(
                constraints: const BoxConstraints(maxWidth: 240),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.lightBorderColor,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.file_present_rounded,
                      size: 10,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        item.toString(),
                        style: GoogleFonts.outfit(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textBody,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      );
    }

    if (value is Map) {
      if (value.isEmpty) return 'None';
      return Wrap(
        spacing: 4,
        runSpacing: 4,
        children: value.entries
            .map<Widget>(
              (entry) => Container(
                constraints: const BoxConstraints(maxWidth: 240),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.lightBorderColor,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Text(
                  '${entry.key}: ${entry.value}',
                  style: GoogleFonts.outfit(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textBody,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
            .toList(),
      );
    }

    if (value is bool) {
      return value ? 'Yes' : 'No';
    }

    return value.toString();
  }

  Widget _buildStructuredPayload(Map<String, dynamic> payload) {
    final keys = payload.keys.where((k) {
      final lower = k.toLowerCase();
      return lower != 'action' &&
          lower != 'status' &&
          lower != 'items' &&
          lower != '_id' &&
          lower != '\$oid' &&
          lower != '__v' &&
          lower != 'schemaversion' &&
          lower != 'sessionid' &&
          lower != 'user_agent_raw' &&
          lower != 'sdk_version';
    }).toList();

    if (keys.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 450;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: keys.map((key) {
            final val = payload[key];
            final displayKey = _formatKey(key);
            final displayVal = _formatValue(key, val);

            final double itemWidth = isMobile
                ? constraints.maxWidth
                : (constraints.maxWidth - 10) / 2;

            return Container(
              width: itemWidth,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: AppTheme.borderColor.withOpacity(0.6),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 4,
                    child: Text(
                      displayKey,
                      style: GoogleFonts.outfit(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    flex: 6,
                    child: displayVal is Widget
                        ? displayVal
                        : Text(
                            displayVal.toString(),
                            style: GoogleFonts.outfit(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildCartAddDetails(Map<String, dynamic> payload) {
    List<dynamic> items = [];
    if (payload['items'] != null && payload['items'] is List) {
      items = payload['items'] as List;
    } else if (payload['product_id'] != null) {
      items = [
        {
          'product_id': payload['product_id'],
          'product_name': payload['product_name'] ?? 'Unknown Product',
          'variant_id': payload['variant_id'] ?? '',
          'variant_name': payload['variant_name'] ?? '',
          'quantity': payload['quantity'] ?? 1,
          'price': payload['unit_price'] ?? 0.0,
        },
      ];
    }

    if (items.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.borderColor.withOpacity(0.6)),
        ),
        child: Text(
          widget.details,
          style: GoogleFonts.outfit(
            fontSize: 13.5,
            color: AppTheme.textBody,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final item in items) {
      if (item is Map) {
        final map = Map<String, dynamic>.from(item);
        final prodId = map['product_id']?.toString() ?? 'unknown';
        grouped.putIfAbsent(prodId, () => []).add(map);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0, left: 2.0),
          child: Row(
            children: [
              const Icon(
                Icons.shopping_cart_outlined,
                size: 15,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(width: 6),
              Text(
                'Shopping Cart Items',
                style: GoogleFonts.outfit(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
        ),
        ...grouped.entries.map((entry) {
          final prodItems = entry.value;
          final prodName =
              prodItems.first['product_name']?.toString() ?? 'Unknown Product';

          return Container(
            margin: const EdgeInsets.only(bottom: 8.0),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.borderColor.withOpacity(0.8)),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final bool isNarrow = constraints.maxWidth < 450;

                final productHeader = Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.inventory_2_outlined,
                        size: 14,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        prodName,
                        style: GoogleFonts.outfit(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                );

                final variantList = Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: prodItems.map<Widget>((item) {
                    final variantName = item['variant_name']?.toString() ?? '';
                    final qty = item['quantity'] ?? 1;
                    final price = item['price'] ?? 0.0;
                    final formattedPrice =
                        '₹${(price * qty).toStringAsFixed(2).replaceAll('.00', '')}';

                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.lightBorderColor,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: AppTheme.borderColor.withOpacity(0.5),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (variantName.isNotEmpty) ...[
                            Text(
                              variantName,
                              style: GoogleFonts.outfit(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textBody,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Container(
                              width: 1,
                              height: 10,
                              color: AppTheme.textSecondary.withOpacity(0.3),
                            ),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            '${qty}x',
                            style: GoogleFonts.outfit(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '($formattedPrice)',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );

                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      productHeader,
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.only(left: 4.0),
                        child: variantList,
                      ),
                    ],
                  );
                } else {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(flex: 4, child: productHeader),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 6,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: variantList,
                        ),
                      ),
                    ],
                  );
                }
              },
            ),
          );
        }).toList(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final String fullInitials = widget.user
        .split(' ')
        .map((e) => e.isNotEmpty ? e[0] : '')
        .join()
        .toUpperCase();
    final String initials = fullInitials.length <= 2
        ? fullInitials
        : fullInitials.substring(0, 2);

    final theme = _getEventTheme();
    final Color severityColor = theme['color'] as Color;
    final Color severityBg = theme['bgColor'] as Color;
    final Color severityBorder = theme['borderColor'] as Color;
    final String tagLabel = theme['tag'] as String;
    final IconData severityIcon = theme['icon'] as IconData;

    final String headline = _getHumanHeadline();
    final String? salesTip = _getSalesActionRecommendation();
    final String? phone = widget.userPhone;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: _hovered
              ? AppTheme.backgroundColor.withOpacity(0.7)
              : AppTheme.backgroundColor.withOpacity(0.4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _hovered
                ? severityColor.withOpacity(0.35)
                : AppTheme.borderColor,
            width: _hovered ? 1.5 : 1.0,
          ),
          boxShadow: _hovered
              ? [
                  BoxShadow(
                    color: severityColor.withOpacity(0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Header Row with Avatar, Name, Phone & Quick Actions
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        severityColor.withOpacity(0.15),
                        severityColor.withOpacity(0.04),
                      ],
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: severityColor.withOpacity(0.25),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initials.isNotEmpty ? initials : 'U',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: severityColor,
                    ),
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
                          Expanded(
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: GestureDetector(
                                onTap: () => _navigateToProfile(
                                  context,
                                  widget.rawUser ?? widget.user,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        widget.user,
                                        style: GoogleFonts.outfit(
                                          fontSize: 15.5,
                                          fontWeight: FontWeight.w800,
                                          color: AppTheme.textPrimary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.open_in_new_rounded,
                                      size: 12,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Event Severity Tag Pill
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: severityBg,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: severityBorder),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  severityIcon,
                                  size: 11,
                                  color: severityColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  tagLabel,
                                  style: GoogleFonts.outfit(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    color: severityColor,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (phone != null && phone.isNotEmpty) ...[
                            Text(
                              phone,
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Direct Sales Action Buttons: Call & WhatsApp
                            InkWell(
                              onTap: () => _makePhoneCall(phone),
                              borderRadius: BorderRadius.circular(4),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.phone,
                                      size: 11,
                                      color: AppTheme.primaryColor,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      'Call',
                                      style: GoogleFonts.outfit(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            InkWell(
                              onTap: () => _openWhatsApp(
                                context,
                                phone,
                                widget.user,
                              ),
                              borderRadius: BorderRadius.circular(4),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.chat_bubble_outline_rounded,
                                      size: 11,
                                      color: Color(0xFF10B981),
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      'WhatsApp',
                                      style: GoogleFonts.outfit(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF10B981),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            '•  ${widget.time}',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Plain English Human-Readable Headline Container
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: severityBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: severityBorder.withOpacity(0.7)),
              ),
              child: Text(
                headline,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),

            // Sales Action Recommendation Tip Box
            if (salesTip != null) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFCD34D)),
                ),
                child: Text(
                  salesTip,
                  style: GoogleFonts.outfit(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF92400E),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 10),

            // Payload or Cart Details Section
            widget.payload['action'] == 'cart_add'
                ? _buildCartAddDetails(widget.payload)
                : const SizedBox.shrink(),

            const SizedBox(height: 6),

            // View Details Toggle / Raw JSON Toggle
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkWell(
                  onTap: () {
                    setState(() {
                      _expanded = !_expanded;
                    });
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 4,
                      horizontal: 2,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _expanded
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          size: 15,
                          color: AppTheme.primaryColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _expanded ? 'Hide Technical Details' : 'View Key Data Fields',
                          style: GoogleFonts.outfit(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_expanded)
                  InkWell(
                    onTap: () {
                      setState(() {
                        _showRawJson = !_showRawJson;
                      });
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 4,
                        horizontal: 8,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _showRawJson
                                ? Icons.grid_view_rounded
                                : Icons.code_rounded,
                            size: 13,
                            color: AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _showRawJson ? 'Structured View' : 'Raw Developer JSON',
                            style: GoogleFonts.outfit(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            if (_expanded) ...[
              const SizedBox(height: 10),
              _showRawJson
                  ? Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        const JsonEncoder.withIndent(
                          '  ',
                        ).convert(widget.payload),
                        style: GoogleFonts.sourceCodePro(
                          fontSize: 11.5,
                          color: const Color(0xFF38BDF8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    )
                  : _buildStructuredPayload(widget.payload),
            ],
          ],
        ),
      ),
    );
  }
}

class _DistrictTempData {
  final String districtName;
  final String stateName;
  int activeDealers = 0;
  final Set<String> buyerUserIds = {};
  double revenue = 0.0;

  int get buyersCount => buyerUserIds.length;

  _DistrictTempData({required this.districtName, required this.stateName});
}
