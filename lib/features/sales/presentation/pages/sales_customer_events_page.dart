import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kd_pannel/app_theme.dart';
import 'package:kd_pannel/core/auth/auth_service.dart';
import 'package:kd_pannel/core/network/websocket_service.dart';
import 'package:kd_pannel/core/responsive/responsive.dart';
import 'package:kd_pannel/core/services/analytics_service.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/dealers_bloc.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/leads_bloc.dart';
import 'package:kd_pannel/features/shared/widgets/events/user_card.dart';
import 'package:kd_pannel/features/shared/widgets/events/events_helper.dart';

class SalesCustomerEventsPage extends StatefulWidget {
  const SalesCustomerEventsPage({super.key});

  @override
  State<SalesCustomerEventsPage> createState() =>
      _SalesCustomerEventsPageState();
}

class _SalesCustomerEventsPageState extends State<SalesCustomerEventsPage> {
  final ScrollController _scrollController = ScrollController();
  final Set<String> _processedEventIds = {};
  final Set<String> _loadingUserEvents = {};
  final Set<String> _activeUserNetworkFetches = {};
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedUserType = 'All';
  String _selectedActivityFilter = 'All';

  final Map<String, List<Map<String, dynamic>>> _perUserEventsCache = {};

  Map<String, List<Map<String, dynamic>>> _eventsLogs = {};
  Map<String, String> _nameToId = {};
  final List<Map<String, dynamic>> _realTimeUsers = [];
  final Set<String> _onlineUserKeys = {};

  bool _isLoading = true;
  bool _isLoadingEvents = false;

  int _currentPage = 1;
  final int _usersPerPage = 10;

  StreamSubscription? _presenceSubscription;
  Timer? _realTimeTimer;
  Timer? _rebuildDebounce;
  bool _isRebuildingCache = false;

  Map<String, Map<String, List<Map<String, dynamic>>>>
  _cachedUserEventsGrouped = {};
  List<String> _cachedUsersWithEvents = [];
  Map<String, DateTime> _cachedMostRecentEventTimes = {};
  Map<String, bool> _cachedHighPriority = {};
  Map<String, String> _cachedPriorityReason = {};
  Map<String, String> _cachedUserTypes = {};
  Set<String>? _cachedAssignedUserKeys;

  String? _selectedUser;
  String? _selectedEventType;

  static const List<Map<String, dynamic>> _eventTypes = [
    {
      'id': 'product_view',
      'label': 'Product Views',
      'icon': Icons.visibility_outlined,
      'color': Color(0xFF0284C7),
    },
    {
      'id': 'cart_add',
      'label': 'Cart Adds',
      'icon': Icons.shopping_cart_outlined,
      'color': Color(0xFFF59E0B),
    },
    {
      'id': 'checkout_started',
      'label': 'Checkout',
      'icon': Icons.shopping_bag_outlined,
      'color': Color(0xFFFB923C),
    },
    {
      'id': 'payment_success',
      'label': 'Payments',
      'icon': Icons.check_circle_outline,
      'color': Color(0xFF10B981),
    },
    {
      'id': 'payment_failed',
      'label': 'Failed Payments',
      'icon': Icons.error_outline,
      'color': Color(0xFFEF4444),
    },
  ];

  String _normalizeId(dynamic id) {
    if (id == null) return '';
    if (id is Map) {
      if (id.containsKey(r'$oid')) return id[r'$oid'].toString();
      if (id.containsKey('_id')) return _normalizeId(id['_id']);
      if (id.containsKey('id')) return _normalizeId(id['id']);
    }
    final str = id.toString();
    if (str.startsWith('ObjectId("') && str.endsWith('")')) {
      return str.substring(10, str.length - 2);
    }
    if (str.startsWith("ObjectId('") && str.endsWith("')")) {
      return str.substring(10, str.length - 2);
    }
    return str;
  }

  bool _isKnownSalesAgent(String? identifier) {
    if (identifier == null) return false;
    final lower = identifier.trim().toLowerCase();
    if (lower.isEmpty) return false;
    if (lower == 'admin' ||
        lower == 'sales' ||
        lower.contains('admin') ||
        lower.contains('sales')) {
      return true;
    }

    final cleanDigits = lower.replaceAll(RegExp(r'\D'), '');
    final last10 = cleanDigits.length >= 10
        ? cleanDigits.substring(cleanDigits.length - 10)
        : '';

    try {
      final dealersState = context.read<DealersBloc>().state;
      final leadsState = context.read<LeadsBloc>().state;
      final allSalesAgents = [
        ...dealersState.salesAgents,
        ...leadsState.salesAgents,
      ];
      return allSalesAgents.any((a) {
        final fn =
            '${a['firstName'] ?? ''} ${a['lastName'] ?? ''}'.trim().toLowerCase();
        final name = (a['name'] ?? '').toString().trim().toLowerCase();
        final email = (a['email'] ?? '').toString().trim().toLowerCase();
        final phone = (a['phoneNumber'] ?? a['phone'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
        final cleanP = phone.replaceAll(RegExp(r'\D'), '');
        final p10 =
            cleanP.length >= 10 ? cleanP.substring(cleanP.length - 10) : '';
        final uid = _normalizeId(a['_id'] ?? a['id']).toLowerCase();

        return (fn.isNotEmpty && fn == lower) ||
            (name.isNotEmpty && name == lower) ||
            (email.isNotEmpty && email == lower) ||
            (phone.isNotEmpty && phone == lower) ||
            (last10.isNotEmpty && p10 == last10) ||
            (uid.isNotEmpty && uid == lower);
      });
    } catch (_) {}
    return false;
  }

  void _buildUserLookupIndexes() {
    final assignedKeys = <String>{};
    final currentUserId =
        _normalizeId(AuthService().currentUserId).toLowerCase();
    final currentUserEmail =
        (AuthService().currentUserEmail ?? '').toLowerCase();

    bool isRawUserAssigned(Map<String, dynamic> u) {
      final assignedAgent =
          u['assignedAgent'] ?? u['assignedSalesAgent'] ?? u['salesAgent'];
      if (assignedAgent != null) {
        if (assignedAgent is Map) {
          final aId = _normalizeId(
            assignedAgent['_id'] ??
                assignedAgent[r'$oid'] ??
                assignedAgent['id'],
          ).toLowerCase();
          final aEmail =
              (assignedAgent['email'] ?? '').toString().toLowerCase();
          return (currentUserId.isNotEmpty && aId == currentUserId) ||
              (currentUserEmail.isNotEmpty && aEmail == currentUserEmail);
        } else if (assignedAgent is String) {
          final aId = _normalizeId(assignedAgent).toLowerCase();
          return (currentUserId.isNotEmpty && aId == currentUserId) ||
              (currentUserEmail.isNotEmpty && aId == currentUserEmail);
        }
      }
      return false;
    }

    void indexUser(Map<String, dynamic> u) {
      final dbRole = (u['role'] ?? 'user').toString().toLowerCase();
      if (dbRole != 'user') return;

      final uId = _normalizeId(u['_id']).toLowerCase();
      final uEmail = (u['email'] ?? '').toString().toLowerCase();
      final uPhone = (u['phoneNumber'] ?? u['phone'] ?? '').toString();
      final cleanPhone = uPhone.replaceAll(RegExp(r'\D'), '');
      final uName =
          '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'.trim().toLowerCase();
      final uShop = (u['shopName'] ?? '').toString().trim().toLowerCase();

      if (isRawUserAssigned(u)) {
        if (uId.isNotEmpty) assignedKeys.add(uId);
        if (uEmail.isNotEmpty) assignedKeys.add(uEmail);
        if (uPhone.isNotEmpty) {
          assignedKeys.add(uPhone.toLowerCase());
          if (cleanPhone.length >= 10) {
            assignedKeys.add(cleanPhone.substring(cleanPhone.length - 10));
          }
        }
        if (uName.isNotEmpty) assignedKeys.add(uName);
        if (uShop.isNotEmpty) assignedKeys.add(uShop);
      }
    }

    try {
      final dealersState = context.read<DealersBloc>().state;
      for (final u in dealersState.allRawUsers) {
        indexUser(u);
      }
    } catch (_) {}

    try {
      final leadsState = context.read<LeadsBloc>().state;
      for (final u in leadsState.allRawUsers) {
        indexUser(u);
      }
    } catch (_) {}

    _cachedAssignedUserKeys = assignedKeys;
  }

  @override
  void initState() {
    super.initState();
    _loadEvents();
    _listenToLivePresence();
    _startRealTimePoll();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _realTimeTimer?.cancel();
    _rebuildDebounce?.cancel();
    _presenceSubscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _listenToLivePresence() {
    _presenceSubscription = WebSocketService().presenceUpdates.listen((update) {
      if (!mounted) return;
      final enrichedUpdate = Map<String, dynamic>.from(update);
      final userId = enrichedUpdate['user']?.toString();
      if (userId == null || userId.isEmpty || userId.toLowerCase() == 'guest')
        return;

      final action = enrichedUpdate['lastAction']?.toString();
      if (action != null && action.isNotEmpty && action != 'App Open') {
        final liveEvent = {
          'eventId': 'live-${DateTime.now().millisecondsSinceEpoch}',
          'event': action,
          'user': userId,
          'userName': enrichedUpdate['userName']?.toString() ?? userId,
          'timestamp': DateTime.now().toUtc().toIso8601String(),
          'properties': {
            'screen': enrichedUpdate['currentScreen']?.toString() ?? 'App',
          },
          'userDetails': enrichedUpdate,
        };
        final targetName = enrichedUpdate['userName']?.toString() ?? userId;
        final currentGrouped = Map<String, List<Map<String, dynamic>>>.from(
          _eventsLogs,
        );
        final currentNameToId = Map<String, String>.from(_nameToId);

        _processEventsList(
          [liveEvent],
          currentGrouped,
          currentNameToId,
          targetUserName: targetName,
        );
        _eventsLogs = currentGrouped;
        _nameToId = currentNameToId;
      }

      _requestRebuildCache();
      if (mounted) setState(() {});
    });
  }

  void _startRealTimePoll() {
    _realTimeTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      _loadRealTimeUsers();
    });
    _loadRealTimeUsers();
  }

  Future<void> _loadRealTimeUsers() async {
    try {
      final users = await AnalyticsService().fetchRealTimeUsers();
      if (!mounted) return;
      setState(() {
        _realTimeUsers.clear();
        _onlineUserKeys.clear();
        for (var u in users) {
          _realTimeUsers.add(u);
          final uName =
              (u['userName'] ?? u['user'] ?? u['email'] ?? u['phone'] ?? '')
                  .toString();
          if (uName.isNotEmpty) {
            _onlineUserKeys.add(uName);
            _onlineUserKeys.add(uName.toLowerCase());
          }
          final userId = (u['user'] ?? u['_id'] ?? '').toString();
          if (userId.isNotEmpty) {
            _onlineUserKeys.add(userId);
            _onlineUserKeys.add(userId.toLowerCase());
          }
        }
      });
      _requestRebuildCache();
    } catch (_) {}
  }

  bool _isUserOnline(String userName) {
    final lowerName = userName.toLowerCase();
    if (_onlineUserKeys.contains(userName) ||
        _onlineUserKeys.contains(lowerName))
      return true;

    final rawUser = _nameToId[userName];
    if (rawUser != null &&
        (_onlineUserKeys.contains(rawUser) ||
            _onlineUserKeys.contains(rawUser.toLowerCase()))) {
      return true;
    }

    final mostRecentTime = _cachedMostRecentEventTimes[userName];
    if (mostRecentTime != null) {
      final diffInMinutes = DateTime.now().difference(mostRecentTime).inMinutes;
      if (diffInMinutes <= 5) return true;
    }

    return false;
  }

  void _requestRebuildCache() {
    if (_isRebuildingCache) return;
    _rebuildDebounce?.cancel();
    _rebuildDebounce = Timer(const Duration(milliseconds: 150), () {
      if (mounted) _rebuildCache();
    });
  }

  void _rebuildCache() {
    if (_isRebuildingCache) return;
    _isRebuildingCache = true;
    try {
      _buildUserLookupIndexes();
      final Map<String, Map<String, List<Map<String, dynamic>>>>
      userEventsGrouped = {};
      final Set<String> usersSet = {};

      // 1. Group events by user and category (only users with actual event logs who are assigned)
      _eventsLogs.forEach((category, logs) {
        for (final log in logs) {
          final String? userName = log['user'] as String?;
          if (userName != null && userName.isNotEmpty) {
            if (_isUserAssignedToSales(
              rawUser: _nameToId[userName] ?? userName,
              displayName: userName,
              displayPhone: log['userPhone']?.toString(),
              userDetails: log['userDetails'],
            )) {
              usersSet.add(userName);
              final userMap = userEventsGrouped.putIfAbsent(userName, () => {});
              final categoryList = userMap.putIfAbsent(category, () => []);
              categoryList.add(log);
            }
          }
        }
      });

      final Map<String, String> userTypes = {};

      // Populate user types and add all assigned dealers and leads (only role == 'user')
      try {
        final dealersState = context.read<DealersBloc>().state;
        for (final u in dealersState.allRawUsers) {
          final dbRole = (u['role'] ?? 'user').toString().toLowerCase();
          if (dbRole != 'user') continue;

          final String rawUser = _normalizeId(u['_id']);
          final displayPhone = (u['phoneNumber'] ?? u['phone'] ?? '')
              .toString();
          String displayName = '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'
              .trim();
          if (displayName.isEmpty)
            displayName = (u['shopName'] ?? '').toString();
          if (displayName.isEmpty)
            displayName = displayPhone.isNotEmpty
                ? displayPhone
                : 'New Customer';

          final kycStatus =
              u['kycStatus']?.toString().toLowerCase() ?? 'pending';
          final isDealer = kycStatus == 'verified';
          final type = isDealer ? 'Dealer' : 'Lead';

          if (rawUser.isNotEmpty &&
              displayName != 'New Customer' &&
              displayName != 'Guest') {
            _nameToId[displayName] = rawUser;
          }
          if (displayPhone.isNotEmpty && !_nameToId.containsKey(displayPhone)) {
            _nameToId[displayPhone] = rawUser.isNotEmpty
                ? rawUser
                : displayPhone;
          }
          userTypes[displayName] = type;
          if (rawUser.isNotEmpty) userTypes[rawUser] = type;

          if (_isUserAssignedToSales(
            rawUser: rawUser,
            displayName: displayName,
            displayPhone: displayPhone,
            userDetails: u,
          )) {
            usersSet.add(displayName);
          }
        }
      } catch (_) {}

      try {
        final leadsState = context.read<LeadsBloc>().state;
        for (final u in leadsState.allRawUsers) {
          final dbRole = (u['role'] ?? 'user').toString().toLowerCase();
          if (dbRole != 'user') continue;

          final String rawUser = _normalizeId(u['_id']);
          final displayPhone = (u['phoneNumber'] ?? u['phone'] ?? '')
              .toString();
          String displayName = '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'
              .trim();
          if (displayName.isEmpty)
            displayName = (u['shopName'] ?? '').toString();
          if (displayName.isEmpty)
            displayName = displayPhone.isNotEmpty
                ? displayPhone
                : 'New Customer';

          final kycStatus =
              u['kycStatus']?.toString().toLowerCase() ?? 'pending';
          final isDealer = kycStatus == 'verified';
          final type = isDealer ? 'Dealer' : 'Lead';

          if (rawUser.isNotEmpty &&
              displayName != 'New Customer' &&
              displayName != 'Guest') {
            _nameToId[displayName] = rawUser;
          }
          if (displayPhone.isNotEmpty && !_nameToId.containsKey(displayPhone)) {
            _nameToId[displayPhone] = rawUser.isNotEmpty
                ? rawUser
                : displayPhone;
          }
          userTypes.putIfAbsent(displayName, () => type);
          if (rawUser.isNotEmpty) userTypes.putIfAbsent(rawUser, () => type);

          if (_isUserAssignedToSales(
            rawUser: rawUser,
            displayName: displayName,
            displayPhone: displayPhone,
            userDetails: u,
          )) {
            usersSet.add(displayName);
          }
        }
      } catch (_) {}

      // Add currently active online real-time users (only if assigned to this agent)
      for (final u in _realTimeUsers) {
        final uName = (u['userName'] ?? u['user'] ?? '').toString();
        if (uName.isNotEmpty && uName != 'New Customer' && uName != 'Guest') {
          if (_isUserAssignedToSales(
            rawUser: (u['user'] ?? '').toString(),
            displayName: uName,
            displayPhone: (u['userPhone'] ?? '').toString(),
            userDetails: u,
          )) {
            usersSet.add(uName);
          }
        }
      }

      _cachedUserTypes = userTypes;

      userEventsGrouped.forEach((userName, categories) {
        final List<Map<String, dynamic>> userFlatLogs = [];
        final Set<String> seenEventKeys = {};
        categories.forEach((_, logs) {
          for (final log in logs) {
            final key =
                log['eventId']?.toString() ??
                '${log['rawTimestamp']}_${log['details']}';
            if (!seenEventKeys.contains(key)) {
              seenEventKeys.add(key);
              userFlatLogs.add(log);
            }
          }
        });
        userFlatLogs.sort((a, b) {
          final aTs = a['rawTimestamp']?.toString() ?? '';
          final bTs = b['rawTimestamp']?.toString() ?? '';
          return bTs.compareTo(aTs);
        });

        final top10Logs = userFlatLogs.take(10).toList();
        final Map<String, List<Map<String, dynamic>>> trimmedCategories = {};
        for (final log in top10Logs) {
          final cat = log['eventType']?.toString() ?? 'general';
          trimmedCategories.putIfAbsent(cat, () => []).add(log);
        }
        userEventsGrouped[userName] = trimmedCategories;
      });

      _cachedUserEventsGrouped = userEventsGrouped;

      final Map<String, DateTime> mostRecentEventTimes = {};
      final Map<String, bool> highPriority = {};
      final Map<String, String> priorityReason = {};

      for (final userName in usersSet) {
        DateTime mostRecent = DateTime.fromMillisecondsSinceEpoch(0);
        final userGroups = userEventsGrouped[userName] ?? {};
        userGroups.forEach((_, logs) {
          for (final log in logs) {
            final tsStr = log['rawTimestamp'] as String?;
            if (tsStr != null) {
              try {
                final dt = DateTime.parse(tsStr);
                if (dt.isAfter(mostRecent)) mostRecent = dt;
              } catch (_) {}
            }
          }
        });
        mostRecentEventTimes[userName] = mostRecent;

        bool isHigh = false;
        String reason = '';
        final bool hasSuccess =
            userGroups.containsKey('payment_success') ||
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
      }

      _cachedMostRecentEventTimes = mostRecentEventTimes;
      _cachedHighPriority = highPriority;
      _cachedPriorityReason = priorityReason;

      final sortedUsers = usersSet.toList();
      sortedUsers.sort((a, b) {
        final aOnline = _isUserOnline(a);
        final bOnline = _isUserOnline(b);
        if (aOnline && !bOnline) return -1;
        if (!aOnline && bOnline) return 1;

        final aTime =
            _cachedMostRecentEventTimes[a] ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final bTime =
            _cachedMostRecentEventTimes[b] ??
            DateTime.fromMillisecondsSinceEpoch(0);
        if (aTime != bTime) return bTime.compareTo(aTime);
        return a.compareTo(b);
      });

      _cachedUsersWithEvents = sortedUsers;
    } finally {
      _isRebuildingCache = false;
      if (mounted) setState(() {});
    }
  }

  Map<String, dynamic> _resolveCanonicalUser({
    String? rawUser,
    String? displayPhone,
    String? userName,
    Map<String, dynamic>? userDetails,
  }) {
    final String cleanRaw = (rawUser ?? '').trim();
    final String cleanPhone = (displayPhone ?? '').trim();
    final String cleanName = (userName ?? '').trim();

    final String phoneDigits = (cleanPhone.isNotEmpty ? cleanPhone : cleanRaw)
        .replaceAll(RegExp(r'\D'), '');
    final String phoneLast10 = phoneDigits.length >= 10
        ? phoneDigits.substring(phoneDigits.length - 10)
        : '';

    bool isMatch(Map<String, dynamic> u) {
      final uid = (u['_id'] ?? u['id'] ?? '').toString().toLowerCase();
      if (cleanRaw.isNotEmpty && uid == cleanRaw.toLowerCase()) return true;

      final uPhone = (u['phoneNumber'] ?? u['phone'] ?? '').toString();
      final uCleanP = uPhone.replaceAll(RegExp(r'\D'), '');
      final uP10 = uCleanP.length >= 10
          ? uCleanP.substring(uCleanP.length - 10)
          : '';
      if (phoneLast10.isNotEmpty && uP10.isNotEmpty && phoneLast10 == uP10)
        return true;

      final uEmail = (u['email'] ?? '').toString().toLowerCase().trim();
      if (cleanRaw.contains('@') &&
          uEmail.isNotEmpty &&
          cleanRaw.toLowerCase() == uEmail)
        return true;

      if (cleanName.isNotEmpty && !isGenericProfileName(cleanName)) {
        final fName = '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'
            .trim()
            .toLowerCase();
        final sName = (u['shopName'] ?? '').toString().trim().toLowerCase();
        if (fName.isNotEmpty && fName == cleanName.toLowerCase()) return true;
        if (sName.isNotEmpty && sName == cleanName.toLowerCase()) return true;
      }
      return false;
    }

    try {
      final dealersState = context.read<DealersBloc>().state;
      final leadsState = context.read<LeadsBloc>().state;
      final allSalesAgents = [
        ...dealersState.salesAgents,
        ...leadsState.salesAgents,
      ];
      final matchedSalesAgent = allSalesAgents.firstWhere(
        isMatch,
        orElse: () => <String, dynamic>{},
      );
      if (matchedSalesAgent.isNotEmpty) {
        final fName =
            '${matchedSalesAgent['firstName'] ?? ''} ${matchedSalesAgent['lastName'] ?? ''}'
                .trim();
        final sName = (matchedSalesAgent['name'] ?? '').toString().trim();
        final p = (matchedSalesAgent['phoneNumber'] ??
                matchedSalesAgent['phone'] ??
                '')
            .toString()
            .trim();
        final id = (matchedSalesAgent['_id'] ??
                matchedSalesAgent['id'] ??
                cleanRaw)
            .toString();
        String name = fName.isNotEmpty
            ? fName
            : (sName.isNotEmpty ? sName : (p.isNotEmpty ? p : 'Sales Agent'));
        return {
          'name': name,
          'phone': p.isNotEmpty ? p : cleanPhone,
          'id': id,
          'userDetails': matchedSalesAgent,
          'userType': 'Sales',
        };
      }
    } catch (_) {}

    try {
      final dealersState = context.read<DealersBloc>().state;
      final matchedDealer = dealersState.allRawUsers.firstWhere(
        isMatch,
        orElse: () => <String, dynamic>{},
      );
      if (matchedDealer.isNotEmpty) {
        final fName =
            '${matchedDealer['firstName'] ?? ''} ${matchedDealer['lastName'] ?? ''}'
                .trim();
        final sName = (matchedDealer['shopName'] ?? '').toString().trim();
        final p = (matchedDealer['phoneNumber'] ?? matchedDealer['phone'] ?? '')
            .toString()
            .trim();
        final id = (matchedDealer['_id'] ?? matchedDealer['id'] ?? cleanRaw)
            .toString();
        String name = fName.isNotEmpty
            ? fName
            : (sName.isNotEmpty ? sName : (p.isNotEmpty ? p : 'Customer'));
        return {
          'name': name,
          'phone': p.isNotEmpty ? p : cleanPhone,
          'id': id,
          'userDetails': matchedDealer,
          'userType': 'Dealer',
        };
      }
    } catch (_) {}

    try {
      final leadsState = context.read<LeadsBloc>().state;
      final matchedLead = leadsState.allRawUsers.firstWhere(
        isMatch,
        orElse: () => <String, dynamic>{},
      );
      if (matchedLead.isNotEmpty) {
        final fName =
            '${matchedLead['firstName'] ?? ''} ${matchedLead['lastName'] ?? ''}'
                .trim();
        final sName = (matchedLead['shopName'] ?? '').toString().trim();
        final p = (matchedLead['phoneNumber'] ?? matchedLead['phone'] ?? '')
            .toString()
            .trim();
        final id = (matchedLead['_id'] ?? matchedLead['id'] ?? cleanRaw)
            .toString();
        String name = fName.isNotEmpty
            ? fName
            : (sName.isNotEmpty ? sName : (p.isNotEmpty ? p : 'Customer'));
        return {
          'name': name,
          'phone': p.isNotEmpty ? p : cleanPhone,
          'id': id,
          'userDetails': matchedLead,
          'userType': 'Lead',
        };
      }
    } catch (_) {}

    // Fallback if not found in CRM
    String name = cleanName;
    if (name.isEmpty || isGenericProfileName(name)) {
      if (userDetails != null) {
        final fName =
            '${userDetails['firstName'] ?? ''} ${userDetails['lastName'] ?? ''}'
                .trim();
        final sName = (userDetails['shopName'] ?? '').toString().trim();
        if (fName.isNotEmpty)
          name = fName;
        else if (sName.isNotEmpty)
          name = sName;
      }
    }
    if (name.isEmpty || isGenericProfileName(name)) {
      if (cleanPhone.isNotEmpty)
        name = cleanPhone;
      else if (phoneDigits.length >= 10)
        name = phoneDigits;
      else if (cleanRaw.isNotEmpty && !isGenericProfileName(cleanRaw))
        name = cleanRaw;
      else
        name = 'Customer';
    }

    return {
      'name': name,
      'phone': cleanPhone.isNotEmpty
          ? cleanPhone
          : (phoneDigits.length >= 10 ? phoneDigits : ''),
      'id': cleanRaw,
      'userDetails': userDetails,
      'userType': 'Customer',
    };
  }

  int _lastOrdersCount = -1;
  final Set<String> _mergedOrderIds = {};

  void _mergeSalesCustomerEventsIntoLogs() {
    try {
      final dealersState = context.read<DealersBloc>().state;
      if (_lastOrdersCount == dealersState.allRawOrders.length &&
          _eventsLogs.isNotEmpty) {
        return;
      }
      _lastOrdersCount = dealersState.allRawOrders.length;

      for (final order in dealersState.allRawOrders) {
        if (order['orderStatus'] == 'Cancelled') continue;
        final user = order['user'];
        if (user == null) continue;

        final orderId = (order['orderId'] ?? order['_id'] ?? '').toString();
        if (orderId.isNotEmpty && _mergedOrderIds.contains(orderId)) continue;
        if (orderId.isNotEmpty) _mergedOrderIds.add(orderId);

        final rawUser = (user['_id'] ?? user['id'] ?? '').toString();
        final displayPhone = (user['phoneNumber'] ?? user['phone'] ?? '')
            .toString();
        final userDetails = user is Map<String, dynamic> ? user : null;

        final canonical = _resolveCanonicalUser(
          rawUser: rawUser,
          displayPhone: displayPhone,
          userDetails: userDetails,
        );

        final String displayName = canonical['name'];
        final String phone = canonical['phone'];
        final String uid = canonical['id'];

        if (_isUserAssignedToSales(
          rawUser: uid,
          displayName: displayName,
          userDetails: userDetails,
        )) {
          final eventType = order['orderStatus'] == 'Delivered'
              ? 'payment_success'
              : 'order_created';

          final categoryList = _eventsLogs.putIfAbsent(eventType, () => []);

          if (uid.isNotEmpty &&
              displayName != 'New Customer' &&
              displayName != 'Guest') {
            _nameToId[displayName] = uid;
          }
          if (phone.isNotEmpty && !_nameToId.containsKey(phone)) {
            _nameToId[phone] = uid.isNotEmpty ? uid : phone;
          }

          final total = order['totalAmount'] ?? order['total'] ?? 0;

          categoryList.add({
            'eventId': 'order-$orderId',
            'user': displayName,
            'userPhone': phone,
            'rawUser': uid,
            'category': 'orders',
            'eventType': eventType,
            'event': eventType,
            'time': _formatTimestamp(order['createdAt']?.toString()),
            'rawTimestamp':
                order['createdAt']?.toString() ??
                DateTime.now().toIso8601String(),
            'device': (order['paymentMethod'] ?? 'Web Application').toString(),
            'details':
                'Placed Order #$orderId - ₹$total (${order['orderStatus'] ?? 'Processing'})',
            'payload': Map<String, dynamic>.from(order),
          });
        }
      }
    } catch (e) {
      debugPrint('[SalesCustomerEventsPage] Error merging CRM orders: $e');
    }
  }

  bool _isUserAssignedToSales({
    required String rawUser,
    required String displayName,
    String? displayPhone,
    Map<String, dynamic>? userDetails,
  }) {
    if (_isKnownSalesAgent(rawUser) ||
        _isKnownSalesAgent(displayName) ||
        _isKnownSalesAgent(displayPhone)) {
      return false;
    }

    final curEmail = AuthService().currentUserEmail?.toLowerCase() ?? '';
    final curUid = _normalizeId(AuthService().currentUserId).toLowerCase();
    if (curEmail.isEmpty && curUid.isEmpty) return false;

    if (userDetails != null) {
      final dbRole = (userDetails['role'] ?? 'user').toString().toLowerCase();
      if (dbRole != 'user') return false;

      final assigned =
          userDetails['assignedAgent'] ??
          userDetails['assignedSalesAgent'] ??
          userDetails['salesAgent'];
      if (assigned != null) {
        if (assigned is Map) {
          final aId = _normalizeId(
            assigned['_id'] ?? assigned[r'$oid'] ?? assigned['id'],
          ).toLowerCase();
          final aEmail = (assigned['email'] ?? '').toString().toLowerCase();
          if ((curUid.isNotEmpty && aId == curUid) ||
              (curEmail.isNotEmpty && aEmail == curEmail)) {
            return true;
          }
        } else if (assigned is String) {
          final aId = _normalizeId(assigned).toLowerCase();
          if ((curUid.isNotEmpty && aId == curUid) ||
              (curEmail.isNotEmpty && aId == curEmail)) {
            return true;
          }
        }
      }
    }

    if (_cachedAssignedUserKeys == null) {
      _buildUserLookupIndexes();
    }

    final keys = _cachedAssignedUserKeys ?? {};
    final rawUserLower = _normalizeId(rawUser).trim().toLowerCase();
    final nameLower = displayName.trim().toLowerCase();
    final phoneLower = displayPhone?.trim().toLowerCase() ?? '';
    final cleanPhone = phoneLower.replaceAll(RegExp(r'\D'), '');
    final last10 = cleanPhone.length >= 10
        ? cleanPhone.substring(cleanPhone.length - 10)
        : '';

    if (rawUserLower.isNotEmpty && keys.contains(rawUserLower)) return true;
    if (nameLower.isNotEmpty && keys.contains(nameLower)) return true;
    if (phoneLower.isNotEmpty && keys.contains(phoneLower)) return true;
    if (last10.isNotEmpty && keys.contains(last10)) return true;

    return false;
  }

  void _processEventsList(
    List<Map<String, dynamic>> flatEvents,
    Map<String, List<Map<String, dynamic>>> grouped,
    Map<String, String> nameToId, {
    String? targetUserName,
  }) {
    for (final event in flatEvents) {
      final eventId = (event['eventId'] ?? event['_id'] ?? '').toString();
      if (eventId.isNotEmpty) {
        if (_processedEventIds.contains(eventId)) continue;
        _processedEventIds.add(eventId);
      }

      final rawUser = event['user']?.toString();
      final userDetails = (event['userDetails'] is Map<String, dynamic>)
          ? event['userDetails'] as Map<String, dynamic>
          : null;
      final displayPhone =
          (event['userPhone'] ??
                  userDetails?['phoneNumber'] ??
                  userDetails?['phone'] ??
                  '')
              .toString();

      final canonical = _resolveCanonicalUser(
        rawUser: rawUser,
        displayPhone: displayPhone,
        userName: targetUserName ?? event['userName']?.toString(),
        userDetails: userDetails,
      );

      final String displayName = targetUserName ?? canonical['name'];
      final String phone = displayPhone.isNotEmpty
          ? displayPhone
          : canonical['phone'];
      final String resolvedId =
          (canonical['id'] != null && (canonical['id'] as String).isNotEmpty)
          ? canonical['id']
          : (rawUser ?? '');

      if (_isKnownSalesAgent(rawUser) ||
          _isKnownSalesAgent(displayName) ||
          _isKnownSalesAgent(phone) ||
          _isKnownSalesAgent(resolvedId) ||
          canonical['userType'] == 'Sales' ||
          canonical['userType'] == 'Admin') {
        continue;
      }

      if (!_isUserAssignedToSales(
        rawUser: resolvedId,
        displayName: displayName,
        displayPhone: phone,
        userDetails: userDetails,
      )) {
        continue;
      }

      if (resolvedId.isNotEmpty &&
          displayName != 'New Customer' &&
          displayName != 'Guest') {
        nameToId[displayName] = resolvedId;
      }
      if (phone.isNotEmpty && !nameToId.containsKey(phone)) {
        nameToId[phone] = resolvedId.isNotEmpty ? resolvedId : phone;
      }

      final eventType = event['eventType']?.toString() ?? 'unknown';
      if (!grouped.containsKey(eventType)) grouped[eventType] = [];

      grouped[eventType]!.add({
        'eventId': eventId,
        'user': displayName,
        'userPhone': phone,
        'rawUser': resolvedId,
        'category':
            event['category']?.toString() ??
            event['categoryName']?.toString() ??
            eventType,
        'eventType': eventType,
        'event': event['event']?.toString() ?? eventType,
        'time': _formatTimestamp(event['timestamp']?.toString()),
        'rawTimestamp': event['timestamp']?.toString(),
        'device': event['device']?.toString() ?? 'Unknown Device',
        'details': event['details']?.toString() ?? '',
        'payload': Map<String, dynamic>.from(event['payload'] ?? {}),
      });
    }
  }

  Future<void> _loadEvents() async {
    if (!mounted || _isLoadingEvents) return;
    _isLoadingEvents = true;

    try {
      final res = await AnalyticsService().fetchEventsPaged(limit: 200);
      final flatEvents =
          (res['events'] as List?)?.cast<Map<String, dynamic>>() ?? [];

      if (flatEvents.isNotEmpty) {
        final currentGrouped = Map<String, List<Map<String, dynamic>>>.from(
          _eventsLogs,
        );
        final currentNameToId = Map<String, String>.from(_nameToId);
        _processEventsList(flatEvents, currentGrouped, currentNameToId);
        _eventsLogs = currentGrouped;
        _nameToId = currentNameToId;
      }
    } catch (_) {}

    _mergeSalesCustomerEventsIntoLogs();
    _rebuildCache();
    if (mounted) setState(() => _isLoading = false);
    _isLoadingEvents = false;
  }

  List<String> _getCandidateQueriesForUser(String userName) {
    final Set<String> candidates = {};
    Map<String, dynamic>? foundUser;

    final String rawId = _nameToId[userName] ?? '';

    bool isMatch(Map<String, dynamic> u) {
      final uid = (u['_id'] ?? u['id'] ?? '').toString();
      if (rawId.isNotEmpty && uid.toLowerCase() == rawId.toLowerCase())
        return true;

      final fName = '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'.trim();
      if (fName.isNotEmpty && fName.toLowerCase() == userName.toLowerCase())
        return true;

      final sName = (u['shopName'] ?? '').toString().trim();
      if (sName.isNotEmpty && sName.toLowerCase() == userName.toLowerCase())
        return true;

      final p = (u['phoneNumber'] ?? u['phone'] ?? '').toString().trim();
      if (p.isNotEmpty && p == userName) return true;

      final em = (u['email'] ?? '').toString().trim();
      if (em.isNotEmpty && em.toLowerCase() == userName.toLowerCase())
        return true;

      return false;
    }

    try {
      final dealersState = context.read<DealersBloc>().state;
      final m = dealersState.allRawUsers.firstWhere(
        isMatch,
        orElse: () => <String, dynamic>{},
      );
      if (m.isNotEmpty) foundUser = m;
    } catch (_) {}

    if (foundUser == null) {
      try {
        final leadsState = context.read<LeadsBloc>().state;
        final m = leadsState.allRawUsers.firstWhere(
          isMatch,
          orElse: () => <String, dynamic>{},
        );
        if (m.isNotEmpty) foundUser = m;
      } catch (_) {}
    }

    if (foundUser != null) {
      final em = (foundUser['email'] ?? '').toString().trim();
      if (em.isNotEmpty && em.contains('@')) candidates.add(em);

      final p = (foundUser['phoneNumber'] ?? foundUser['phone'] ?? '')
          .toString()
          .trim();
      if (p.isNotEmpty) {
        candidates.add(p);
        final digits = p.replaceAll(RegExp(r'\D'), '');
        if (digits.length >= 10) {
          final p10 = digits.substring(digits.length - 10);
          candidates.add(p10);
          candidates.add('+91$p10');
        }
      }

      final uid = (foundUser['_id'] ?? foundUser['id'] ?? '').toString().trim();
      if (uid.isNotEmpty) candidates.add(uid);
    }

    if (rawId.isNotEmpty) candidates.add(rawId);
    if (userName.isNotEmpty && !isGenericProfileName(userName))
      candidates.add(userName);

    return candidates.toList();
  }

  Future<void> _fetchEventsForUser(
    String userName, {
    bool silent = false,
  }) async {
    if (_activeUserNetworkFetches.contains(userName)) return;
    _activeUserNetworkFetches.add(userName);

    if (!silent && mounted) setState(() => _loadingUserEvents.add(userName));

    try {
      final candidates = _getCandidateQueriesForUser(userName);
      List<Map<String, dynamic>> flatEvents = [];

      for (final query in candidates) {
        if (query.isEmpty) continue;
        try {
          final res = await AnalyticsService().fetchEventsPaged(
            userEmail: query,
            limit: 10,
          );
          final events =
              (res['events'] as List?)?.cast<Map<String, dynamic>>() ?? [];
          if (events.isNotEmpty) {
            flatEvents = events;
            break;
          }
        } catch (_) {}
      }

      _perUserEventsCache[userName] = flatEvents.take(10).toList();
      if (flatEvents.isNotEmpty) {
        flatEvents = flatEvents.take(10).toList();
        final currentGrouped = Map<String, List<Map<String, dynamic>>>.from(
          _eventsLogs,
        );
        final currentNameToId = Map<String, String>.from(_nameToId);
        _processEventsList(
          flatEvents,
          currentGrouped,
          currentNameToId,
          targetUserName: userName,
        );
        _eventsLogs = currentGrouped;
        _nameToId = currentNameToId;
        _rebuildCache();
      }
    } catch (_) {
    } finally {
      _activeUserNetworkFetches.remove(userName);
      _loadingUserEvents.remove(userName);
      if (mounted) setState(() {});
    }
  }

  void _prefetchPageUsers(List<String> users) {
    if (!mounted) return;
    for (final userName in users) {
      if (!_activeUserNetworkFetches.contains(userName) &&
          !_perUserEventsCache.containsKey(userName)) {
        _fetchEventsForUser(userName, silent: true);
      }
    }
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
  Widget build(BuildContext context) {
    final bool isDesktop = Responsive.isDesktop(context);
    final users = _cachedUsersWithEvents.where((u) {
      // 1. User Type filter
      if (_selectedUserType != 'All') {
        final type = _cachedUserTypes[u] ?? 'Lead';
        if (type.toLowerCase() != _selectedUserType.toLowerCase()) return false;
      }

      // 2. Activity filter
      if (_selectedActivityFilter == 'Live') {
        if (!_isUserOnline(u)) return false;
      } else if (_selectedActivityFilter == 'Cart Abandoned') {
        final r = _cachedPriorityReason[u] ?? '';
        if (r != 'Abandoned Cart' && r != 'Abandoned Checkout') return false;
      } else if (_selectedActivityFilter == 'Payment Failed') {
        final r = _cachedPriorityReason[u] ?? '';
        if (r != 'Payment Failed') return false;
      }

      // 3. Search Query
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase().trim();
        final nameMatches = u.toLowerCase().contains(query);
        final rawUser = _nameToId[u] ?? '';
        final idMatches = rawUser.toLowerCase().contains(query);

        final cleanQ = query.replaceAll(RegExp(r'\D'), '');
        final cleanName = u.replaceAll(RegExp(r'\D'), '');
        final cleanRaw = rawUser.replaceAll(RegExp(r'\D'), '');

        final phoneMatches =
            (cleanQ.isNotEmpty &&
            (cleanName.contains(cleanQ) || cleanRaw.contains(cleanQ)));

        if (!nameMatches && !idMatches && !phoneMatches) return false;
      }

      return true;
    }).toList();

    final int totalUsers = users.length;
    final int totalPages = (totalUsers == 0)
        ? 1
        : ((totalUsers / _usersPerPage).ceil());
    int currentPage = _currentPage;
    if (currentPage > totalPages) currentPage = totalPages;
    if (currentPage < 1) currentPage = 1;

    final int startIndex = (totalUsers == 0)
        ? 0
        : (currentPage - 1) * _usersPerPage;
    final int endIndex = (startIndex + _usersPerPage < totalUsers)
        ? (startIndex + _usersPerPage)
        : totalUsers;
    final List<String> paginatedUsers = (startIndex < totalUsers)
        ? users.sublist(startIndex, endIndex)
        : <String>[];

    if (paginatedUsers.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _prefetchPageUsers(paginatedUsers);
      });
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Customer Events & Live Pulse',
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
            onPressed: () => _loadEvents(),
            tooltip: 'Refresh Events',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            )
          : SingleChildScrollView(
              controller: _scrollController,
              padding: EdgeInsets.all(isDesktop ? 24 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(totalUsers, _cachedUsersWithEvents.length),
                  const SizedBox(height: 16),
                  if (paginatedUsers.isEmpty)
                    _buildEmptyState()
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: paginatedUsers.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final userName = paginatedUsers[index];
                        final userEvents =
                            _cachedUserEventsGrouped[userName] ?? {};
                        final isOnline = _isUserOnline(userName);
                        final isHighPriority =
                            _cachedHighPriority[userName] ?? false;
                        final priorityReason =
                            _cachedPriorityReason[userName] ?? '';

                        return UserCard(
                          name: userName,
                          userType: _cachedUserTypes[userName] ?? 'Lead',
                          groupedEvents: userEvents,
                          isSelected: _selectedUser == userName,
                          selectedEventType: _selectedEventType,
                          eventTypes: _eventTypes,
                          isOnline: isOnline,
                          isHighPriority: isHighPriority,
                          priorityReason: priorityReason,
                          isLoadingEvents: _loadingUserEvents.contains(userName),
                          onTap: () {
                            setState(() {
                              if (_selectedUser == userName) {
                                _selectedUser = null;
                              } else {
                                _selectedUser = userName;
                                _selectedEventType = userEvents.keys.isNotEmpty
                                    ? userEvents.keys.first
                                    : null;
                              }
                            });
                          },
                          onCategorySelected: (cat) {
                            setState(() => _selectedEventType = cat);
                          },
                          onViewProfile: (name) => navigateToProfile(context, name),
                        );
                      },
                    ),
                  const SizedBox(height: 20),
                  _buildPaginationControls(
                    isDesktop,
                    totalUsers,
                    totalPages,
                    currentPage,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader(int filteredCount, int totalCount) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        boxShadow: AppTheme.cardShadow,
        border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.5)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    'Customer Events',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_isLoadingEvents)
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _searchQuery.isNotEmpty ||
                          _selectedUserType != 'All' ||
                          _selectedActivityFilter != 'All'
                      ? '$filteredCount of $totalCount Users'
                      : '$totalCount Users',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppTheme.borderColor.withValues(alpha: 0.8),
                    ),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val;
                        _currentPage = 1;
                      });
                    },
                    style: GoogleFonts.outfit(
                      fontSize: 13.5,
                      color: AppTheme.textPrimary,
                    ),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      hintText: 'Search by name, shop name, or phone number...',
                      hintStyle: GoogleFonts.outfit(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        size: 18,
                        color: AppTheme.textSecondary,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 16),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                  _currentPage = 1;
                                });
                              },
                            )
                          : null,
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppTheme.borderColor.withValues(alpha: 0.8),
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedUserType,
                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 16,
                    ),
                    style: GoogleFonts.outfit(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedUserType = val;
                          _currentPage = 1;
                        });
                      }
                    },
                    items: const [
                      DropdownMenuItem(value: 'All', child: Text('All Types')),
                      DropdownMenuItem(
                        value: 'Dealer',
                        child: Text('Dealers Only'),
                      ),
                      DropdownMenuItem(
                        value: 'Lead',
                        child: Text('Leads Only'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppTheme.borderColor.withValues(alpha: 0.8),
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedActivityFilter,
                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 16,
                    ),
                    style: GoogleFonts.outfit(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedActivityFilter = val;
                          _currentPage = 1;
                        });
                      }
                    },
                    items: const [
                      DropdownMenuItem(
                        value: 'All',
                        child: Text('All Activity'),
                      ),
                      DropdownMenuItem(
                        value: 'Live',
                        child: Text('🟢 Live Only'),
                      ),
                      DropdownMenuItem(
                        value: 'Cart Abandoned',
                        child: Text('🛒 Cart Dropoff'),
                      ),
                      DropdownMenuItem(
                        value: 'Payment Failed',
                        child: Text('⚠️ Payment Failed'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
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
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
      ),
      child: Center(
        child: Column(
          children: [
            const Icon(
              Icons.analytics_outlined,
              size: 40,
              color: AppTheme.primaryColor,
            ),
            const SizedBox(height: 16),
            Text(
              'No Customer Events Logged',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaginationControls(
    bool isDesktop,
    int totalUsers,
    int totalPages,
    int currentPage,
  ) {
    final int startItem = totalUsers == 0
        ? 0
        : (currentPage - 1) * _usersPerPage + 1;
    final int endItem = (currentPage * _usersPerPage < totalUsers)
        ? (currentPage * _usersPerPage)
        : totalUsers;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing $startItem–$endItem of $totalUsers users',
            style: GoogleFonts.outfit(
              fontSize: 13,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: currentPage > 1
                    ? () => setState(() => _currentPage = currentPage - 1)
                    : null,
                icon: const Icon(Icons.chevron_left_rounded, size: 18),
                label: const Text('Prev'),
              ),
              const SizedBox(width: 12),
              Text(
                'Page $currentPage of $totalPages',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: currentPage < totalPages
                    ? () => setState(() => _currentPage = currentPage + 1)
                    : null,
                icon: const Icon(Icons.chevron_right_rounded, size: 18),
                label: const Text('Next'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
