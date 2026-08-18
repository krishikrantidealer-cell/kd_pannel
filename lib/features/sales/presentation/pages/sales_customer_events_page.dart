import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:kd_pannel/app_theme.dart';
import 'package:kd_pannel/core/auth/auth_service.dart';
import 'package:kd_pannel/core/network/websocket_service.dart';
import 'package:kd_pannel/core/responsive/responsive.dart';
import 'package:kd_pannel/core/services/analytics_service.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/dealers_bloc.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/leads_bloc.dart';
import 'package:kd_pannel/features/shared/widgets/whatsapp_chat_dialog.dart';
import 'package:kd_pannel/util/dealers.dart';

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

      if (cleanName.isNotEmpty && !_isGenericProfileName(cleanName)) {
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
    if (name.isEmpty || _isGenericProfileName(name)) {
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
    if (name.isEmpty || _isGenericProfileName(name)) {
      if (cleanPhone.isNotEmpty)
        name = cleanPhone;
      else if (phoneDigits.length >= 10)
        name = phoneDigits;
      else if (cleanRaw.isNotEmpty && !_isGenericProfileName(cleanRaw))
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
    if (userName.isNotEmpty && !_isGenericProfileName(userName))
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

  bool _isGenericProfileName(String name) {
    final low = name.toLowerCase().trim();
    return low.isEmpty ||
        low == 'new customer' ||
        low == 'guest' ||
        low == 'unknown' ||
        low == 'unknown user' ||
        low == 'dealer' ||
        low == 'lead' ||
        low == 'customer' ||
        low == 'admin' ||
        low == 'sales' ||
        low == 'staff' ||
        RegExp(r'^\d+$').hasMatch(low);
  }

  void _navigateToProfile(
    BuildContext context,
    String user, {
    String? phone,
    String? name,
    Map<String, dynamic>? userDetails,
  }) {
    if (user.isEmpty &&
        (phone == null || phone.isEmpty) &&
        (name == null || name.isEmpty))
      return;

    final String cleanUser = user.trim();
    final String? cleanPhone = (phone != null && phone.trim().isNotEmpty)
        ? phone.trim()
        : (RegExp(r'^\+?\d{10,13}$').hasMatch(cleanUser) ? cleanUser : null);
    final String? cleanName =
        (name != null && name.trim().isNotEmpty && !_isGenericProfileName(name))
        ? name.trim()
        : (!cleanUser.contains('@') &&
                  !RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(cleanUser) &&
                  !RegExp(r'^\+?\d+$').hasMatch(cleanUser) &&
                  !_isGenericProfileName(cleanUser)
              ? cleanUser
              : null);
    final String? cleanEmail = cleanUser.contains('@')
        ? cleanUser.toLowerCase()
        : userDetails?['email']?.toString().toLowerCase();
    final String? cleanId =
        (RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(cleanUser) ||
            (cleanUser.length > 15 && !cleanUser.contains(' ')))
        ? cleanUser
        : (userDetails?['_id'] ?? userDetails?['id'])?.toString();

    final String phoneDigits = (cleanPhone ?? cleanUser).replaceAll(
      RegExp(r'\D'),
      '',
    );
    final String phoneLast10 = phoneDigits.length >= 10
        ? phoneDigits.substring(phoneDigits.length - 10)
        : '';

    bool isUserMatch(Map<String, dynamic> u) {
      final String uid = (u['_id'] ?? u['id'] ?? '').toString();
      if (cleanId != null && cleanId.isNotEmpty && uid == cleanId) return true;

      final String uPhone = (u['phoneNumber'] ?? u['phone'] ?? '').toString();
      final String uCleanP = uPhone.replaceAll(RegExp(r'\D'), '');
      final String uP10 = uCleanP.length >= 10
          ? uCleanP.substring(uCleanP.length - 10)
          : '';

      if (phoneLast10.isNotEmpty && uP10.isNotEmpty && phoneLast10 == uP10)
        return true;

      final String uEmail = (u['email'] ?? '').toString().toLowerCase().trim();
      if (cleanEmail != null &&
          cleanEmail.isNotEmpty &&
          uEmail.isNotEmpty &&
          uEmail == cleanEmail)
        return true;

      if (cleanName != null && cleanName.isNotEmpty) {
        final String fullName = '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'
            .trim()
            .toLowerCase();
        final String shopName = (u['shopName'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
        final String targetName = cleanName.toLowerCase();

        if (fullName.isNotEmpty && fullName == targetName) return true;
        if (shopName.isNotEmpty && shopName == targetName) return true;
      }

      return false;
    }

    // 1. Try to find in Dealers first (Real database records)
    try {
      final dealersState = context.read<DealersBloc>().state;
      final Map<String, dynamic>? dealerData = dealersState.allRawUsers
          .firstWhere(isUserMatch, orElse: () => <String, dynamic>{});

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
              (dealerData['firstName'] != null ||
                  dealerData['lastName'] != null)
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
            status:
                dealerData['status'] ?? dealerData['leadStatus'] ?? 'prospect',
            notes: dealerData['notes'] ?? dealerData['leadNotes'] ?? '',
            notesHistory: dealerData['notesHistory'] != null
                ? List<Map<String, dynamic>>.from(dealerData['notesHistory'])
                : [],
          );

          Navigator.pushNamed(context, '/dealers/profile', arguments: dealer);
          return;
        } else {
          final String personName =
              (dealerData['firstName'] != null ||
                  dealerData['lastName'] != null)
              ? '${dealerData['firstName'] ?? ''} ${dealerData['lastName'] ?? ''}'
                    .trim()
              : '';

          final leadMap = {
            'id': dealerData['_id'],
            '_id': dealerData['_id'],
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
    } catch (_) {}

    // 2. Try to find in Leads
    try {
      final leadsState = context.read<LeadsBloc>().state;
      final Map<String, dynamic>? leadData = leadsState.allRawUsers.firstWhere(
        isUserMatch,
        orElse: () => <String, dynamic>{},
      );

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
          final String personName =
              (leadData['firstName'] != null || leadData['lastName'] != null)
              ? '${leadData['firstName'] ?? ''} ${leadData['lastName'] ?? ''}'
                    .trim()
              : '';

          final leadMap = {
            'id': leadData['_id'],
            '_id': leadData['_id'],
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
            'status':
                leadData['status'] ?? leadData['leadStatus'] ?? 'prospect',
            'notes': leadData['notes'] ?? leadData['leadNotes'] ?? '',
            'notesHistory': leadData['notesHistory'] ?? [],
          };
          Navigator.pushNamed(context, '/leads/profile', arguments: leadMap);
          return;
        }
      }
    } catch (_) {}

    // 3. Try to find in fallback static dealers list (allDealers)
    Dealer? matchedDealer;
    for (final d in allDealers) {
      final dPhoneDigits = d.phone.replaceAll(RegExp(r'\D'), '');
      final dP10 = dPhoneDigits.length >= 10
          ? dPhoneDigits.substring(dPhoneDigits.length - 10)
          : '';
      if ((phoneLast10.isNotEmpty && dP10.isNotEmpty && phoneLast10 == dP10) ||
          (cleanName != null &&
              cleanName.isNotEmpty &&
              d.name.toLowerCase() == cleanName.toLowerCase()) ||
          (cleanId != null && d.id != null && d.id == cleanId)) {
        matchedDealer = d;
        break;
      }
    }

    if (matchedDealer != null) {
      Navigator.pushNamed(
        context,
        '/dealers/profile',
        arguments: matchedDealer,
      );
      return;
    }

    // 4. Fallback: Navigate to leads profile with full leadMap
    final String personName = (cleanName != null && cleanName.isNotEmpty)
        ? cleanName
        : (userDetails?['firstName'] != null
              ? '${userDetails!['firstName'] ?? ''} ${userDetails['lastName'] ?? ''}'
                    .trim()
              : (cleanPhone ??
                    (cleanUser.isNotEmpty && !_isGenericProfileName(cleanUser)
                        ? cleanUser
                        : 'Customer')));

    final leadMap = {
      'id': cleanId ?? cleanUser,
      '_id': cleanId,
      'name': personName.isNotEmpty ? personName : 'Customer',
      'phone': cleanPhone ?? (phoneDigits.length >= 10 ? phoneDigits : ''),
      'shopName': userDetails?['shopName'] ?? '',
      'villageArea': userDetails?['address']?['villageArea'] ?? '',
      'city': (userDetails?['address'] is Map)
          ? (userDetails!['address']['cityTehsil'] ??
                userDetails['address']['city'] ??
                'Unknown')
          : (userDetails?['city'] ?? 'Unknown'),
      'state': (userDetails?['address'] is Map)
          ? (userDetails!['address']['state'] ?? 'Unknown')
          : (userDetails?['state'] ?? 'Unknown'),
      'pincode': (userDetails?['address'] is Map)
          ? (userDetails!['address']['pincode'] ?? '')
          : (userDetails?['pincode'] ?? ''),
      'source': userDetails?['source'] ?? 'App',
      'kycStatus': userDetails?['kycStatus'] ?? 'pending',
      'status':
          userDetails?['status'] ?? userDetails?['leadStatus'] ?? 'prospect',
      'notes': userDetails?['notes'] ?? '',
      'notesHistory': userDetails?['notesHistory'] ?? [],
    };
    Navigator.pushNamed(context, '/leads/profile', arguments: leadMap);
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

                        return _SalesUserCard(
                          name: userName,
                          userType: _cachedUserTypes[userName] ?? 'Lead',
                          groupedEvents: userEvents,
                          isOnline: isOnline,
                          isHighPriority: isHighPriority,
                          priorityReason: priorityReason,
                          isLoadingEvents: _loadingUserEvents.contains(
                            userName,
                          ),
                          onViewProfile: (name, {id, phone, details}) =>
                              _navigateToProfile(
                                context,
                                id ?? phone ?? name,
                                phone: phone,
                                name: name,
                                userDetails: details,
                              ),
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

class _SalesUserCard extends StatefulWidget {
  final String name;
  final String userType;
  final Map<String, List<Map<String, dynamic>>> groupedEvents;
  final bool isOnline;
  final bool isHighPriority;
  final String priorityReason;
  final bool isLoadingEvents;
  final void Function(
    String name, {
    String? id,
    String? phone,
    Map<String, dynamic>? details,
  })
  onViewProfile;

  const _SalesUserCard({
    required this.name,
    required this.userType,
    required this.groupedEvents,
    required this.isOnline,
    required this.isHighPriority,
    required this.priorityReason,
    required this.isLoadingEvents,
    required this.onViewProfile,
  });

  @override
  State<_SalesUserCard> createState() => _SalesUserCardState();
}

class _SalesUserCardState extends State<_SalesUserCard> {
  bool _isExpanded = false;

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
      builder: (context) => WhatsAppChatDialog(phone: phoneNumber, name: name),
    );
  }

  String _getCategoryName(Map<String, dynamic> log) {
    final explicitCat =
        log['category']?.toString() ?? log['categoryName']?.toString();
    if (explicitCat != null &&
        explicitCat.isNotEmpty &&
        explicitCat.toLowerCase() != 'general' &&
        explicitCat.toLowerCase() != 'unknown') {
      return _formatTitleCase(explicitCat);
    }

    final rawType = (log['eventType'] ?? log['event'] ?? '').toString();
    if (rawType.isEmpty) return 'General Activity';

    final lower = rawType.toLowerCase();

    if (lower.contains('coupon') ||
        lower.contains('discount') ||
        lower.contains('promo') ||
        lower.contains('offer')) {
      return 'Coupons & Offers';
    } else if (lower.contains('payment') ||
        lower.contains('checkout') ||
        lower.contains('cart') ||
        lower.contains('order') ||
        lower.contains('buy')) {
      return 'Cart & Payments';
    } else if (lower.contains('product') ||
        lower.contains('item') ||
        lower.contains('catalog') ||
        lower.contains('view')) {
      return 'Product Browsing';
    } else if (lower.contains('search') || lower.contains('filter')) {
      return 'Search & Catalog';
    } else if (lower.contains('page') ||
        lower.contains('screen') ||
        lower.contains('nav') ||
        lower.contains('open') ||
        lower.contains('app')) {
      return 'App Navigation';
    } else if (lower.contains('auth') ||
        lower.contains('login') ||
        lower.contains('profile') ||
        lower.contains('account')) {
      return 'Account & Profile';
    } else if (lower.contains('lead') ||
        lower.contains('contact') ||
        lower.contains('call') ||
        lower.contains('whatsapp')) {
      return 'Lead & Inquiry';
    }

    return _formatTitleCase(rawType);
  }

  String _formatTitleCase(String text) {
    final cleaned = text.replaceAll('_', ' ').replaceAll('-', ' ').trim();
    if (cleaned.isEmpty) return 'General Activity';
    return cleaned
        .split(' ')
        .map((word) {
          if (word.isEmpty) return '';
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        })
        .join(' ');
  }

  Widget _buildUserTypeBadge(String type) {
    final isDealer = type.toLowerCase() == 'dealer';
    final label = isDealer ? 'Dealer' : 'Lead';
    final bgColor = isDealer
        ? const Color(0xFF10B981).withValues(alpha: 0.12)
        : const Color(0xFFF59E0B).withValues(alpha: 0.12);
    final textColor = isDealer
        ? const Color(0xFF059669)
        : const Color(0xFFD97706);
    final icon = isDealer ? Icons.verified_rounded : Icons.person_pin_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: textColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: textColor),
          const SizedBox(width: 3),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJourneyMilestonePipeline({
    required bool hasSearch,
    required bool hasCart,
    required bool hasCheckout,
    required bool hasPaid,
    required bool hasFailed,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildMilestoneDot('Search', hasSearch, const Color(0xFF0284C7)),
          _buildMilestoneConnector(hasCart),
          _buildMilestoneDot('Cart', hasCart, const Color(0xFFF59E0B)),
          _buildMilestoneConnector(hasCheckout),
          _buildMilestoneDot('Checkout', hasCheckout, const Color(0xFFFB923C)),
          _buildMilestoneConnector(hasPaid || hasFailed),
          _buildMilestoneDot(
            hasFailed ? 'Failed ❌' : 'Paid',
            hasPaid || hasFailed,
            hasFailed ? Colors.redAccent : const Color(0xFF10B981),
          ),
        ],
      ),
    );
  }

  Widget _buildMilestoneDot(String label, bool completed, Color activeColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: completed ? activeColor : AppTheme.borderColor,
            boxShadow: completed
                ? [
                    BoxShadow(
                      color: activeColor.withValues(alpha: 0.3),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
        ),
        const SizedBox(width: 3.5),
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 9,
            fontWeight: completed ? FontWeight.bold : FontWeight.w500,
            color: completed
                ? activeColor
                : AppTheme.textSecondary.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildMilestoneConnector(bool active) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Container(
        width: 12,
        height: 1.5,
        color: active
            ? AppTheme.primaryColor.withValues(alpha: 0.6)
            : AppTheme.borderColor.withValues(alpha: 0.6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> allEvents = [];
    final Set<String> seenKeys = {};
    String? userPhone;
    String? intentLabel;

    widget.groupedEvents.forEach((_, logs) {
      for (final log in logs) {
        if ((userPhone == null || userPhone!.isEmpty) &&
            log['userPhone'] != null) {
          final p = (log['userPhone'] as String?)?.trim();
          if (p != null && p.isNotEmpty) userPhone = p;
        }
        if (intentLabel == null && log['intentLabel'] != null) {
          intentLabel = log['intentLabel'] as String?;
        }
        final key =
            log['eventId']?.toString() ??
            '${log['rawTimestamp']}_${log['details']}';
        if (!seenKeys.contains(key)) {
          seenKeys.add(key);
          allEvents.add(log);
        }
      }
    });

    // Check if widget.name itself is a phone number
    final cleanNameDigits = widget.name.replaceAll(RegExp(r'\D'), '');
    final bool nameIsPhone =
        cleanNameDigits.length >= 10 &&
        (widget.name.startsWith('+') ||
            RegExp(r'^\d+$').hasMatch(widget.name.trim()));

    if (userPhone == null || userPhone!.isEmpty) {
      if (nameIsPhone) {
        userPhone = widget.name.trim();
      }
    }

    // Try finding phone in Dealers or Leads
    try {
      final dealersState = context.read<DealersBloc>().state;
      final matchedDealer = dealersState.allRawUsers.firstWhere(
        (u) =>
            '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'.trim() ==
                widget.name ||
            (u['shopName'] ?? '').toString().trim() == widget.name ||
            (u['_id'] ?? '').toString() == widget.name,
        orElse: () => <String, dynamic>{},
      );
      if (matchedDealer.isNotEmpty) {
        final p =
            (matchedDealer['phoneNumber'] ?? matchedDealer['phone'] ?? '')
                .toString()
                .trim();
        if (p.isNotEmpty) userPhone = p;
      }
    } catch (_) {}

    if (userPhone == null || userPhone!.isEmpty) {
      try {
        final leadsState = context.read<LeadsBloc>().state;
        final matchedLead = leadsState.allRawUsers.firstWhere(
          (u) =>
              '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'.trim() ==
                  widget.name ||
              (u['shopName'] ?? '').toString().trim() == widget.name ||
              (u['_id'] ?? '').toString() == widget.name,
          orElse: () => <String, dynamic>{},
        );
        if (matchedLead.isNotEmpty) {
          final p = (matchedLead['phoneNumber'] ?? matchedLead['phone'] ?? '')
              .toString()
              .trim();
          if (p.isNotEmpty) userPhone = p;
        }
      } catch (_) {}
    }

    final String? copyablePhone = (userPhone != null && userPhone!.isNotEmpty)
        ? userPhone
        : (nameIsPhone ? widget.name : null);

    allEvents.sort((a, b) {
      final aTs = a['rawTimestamp']?.toString() ?? '';
      final bTs = b['rawTimestamp']?.toString() ?? '';
      return bTs.compareTo(aTs);
    });

    final recentEvents = allEvents.take(10).toList();

    final bool hasSearch =
        widget.groupedEvents.containsKey('product_search') ||
        widget.groupedEvents.containsKey('product_view') ||
        widget.groupedEvents.containsKey('category_view') ||
        widget.groupedEvents.containsKey('login_success');
    final bool hasCart =
        widget.groupedEvents.containsKey('add_to_cart') ||
        widget.groupedEvents.containsKey('cart_add') ||
        widget.groupedEvents.containsKey('cart_view');
    final bool hasCheckout =
        widget.groupedEvents.containsKey('checkout_started') ||
        widget.groupedEvents.containsKey('checkout_init') ||
        widget.groupedEvents.containsKey('payment_initiated') ||
        widget.groupedEvents.containsKey('apply_coupon');
    final bool hasPaid =
        widget.groupedEvents.containsKey('payment_success') ||
        widget.groupedEvents.containsKey('order_placed') ||
        widget.groupedEvents.containsKey('order_completed') ||
        widget.groupedEvents.containsKey('order_created');
    final bool hasFailedPayment = widget.groupedEvents.containsKey(
      'payment_failed',
    );

    int totalEvents = 0;
    widget.groupedEvents.forEach((_, logs) {
      totalEvents += logs.length;
    });

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        border: Border.all(
          color: widget.isOnline
              ? const Color(0xFF10B981).withValues(alpha: 0.5)
              : AppTheme.borderColor.withValues(alpha: 0.7),
          width: widget.isOnline ? 1.5 : 1.0,
        ),
        boxShadow: widget.isOnline
            ? [
                BoxShadow(
                  color: const Color(0xFF10B981).withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: InkWell(
        onTap: () => setState(() => _isExpanded = !_isExpanded),
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: widget.isOnline
                        ? const Color(0xFF10B981).withValues(alpha: 0.15)
                        : AppTheme.primaryColor.withValues(alpha: 0.1),
                    child: Text(
                      widget.name.isNotEmpty
                          ? widget.name[0].toUpperCase()
                          : 'C',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        color: widget.isOnline
                            ? const Color(0xFF10B981)
                            : AppTheme.primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              widget.name,
                              style: GoogleFonts.outfit(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            if (nameIsPhone && copyablePhone != null) ...[
                              Tooltip(
                                message: 'Copy Phone Number',
                                child: InkWell(
                                  onTap: () {
                                    Clipboard.setData(
                                      ClipboardData(text: copyablePhone),
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Row(
                                          children: [
                                            const Icon(
                                              Icons.check_circle_rounded,
                                              color: Colors.white,
                                              size: 15,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                'Phone number ($copyablePhone) copied to clipboard!',
                                                style: GoogleFonts.outfit(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        backgroundColor: const Color(
                                          0xFF0F172A,
                                        ),
                                        duration: const Duration(seconds: 2),
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        width: 360,
                                      ),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(4),
                                  child: Container(
                                    padding: const EdgeInsets.all(3.0),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor.withValues(
                                        alpha: 0.08,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Icon(
                                      Icons.copy_rounded,
                                      size: 12,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            _buildUserTypeBadge(widget.userType),
                            if (widget.isOnline) ...[
                              const _LivePulsingDot(),
                              Text(
                                'LIVE',
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF10B981),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                            if (intentLabel != null) ...[
                              Builder(
                                builder: (context) {
                                  final String currentIntent = intentLabel!;
                                  final Color badgeColor =
                                      currentIntent.contains('Hot')
                                      ? Colors.redAccent
                                      : currentIntent.contains('Warm')
                                      ? Colors.orange
                                      : Colors.blue;
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 1.5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: badgeColor.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: badgeColor.withValues(
                                          alpha: 0.25,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      currentIntent,
                                      style: GoogleFonts.outfit(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: badgeColor,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                        if (copyablePhone != null && !nameIsPhone) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                copyablePhone,
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textSecondary.withValues(
                                    alpha: 0.85,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Tooltip(
                                message: 'Copy Phone Number',
                                child: InkWell(
                                  onTap: () {
                                    Clipboard.setData(
                                      ClipboardData(text: copyablePhone),
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Row(
                                          children: [
                                            const Icon(
                                              Icons.check_circle_rounded,
                                              color: Colors.white,
                                              size: 15,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                'Phone number ($copyablePhone) copied to clipboard!',
                                                style: GoogleFonts.outfit(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        backgroundColor: const Color(
                                          0xFF0F172A,
                                        ),
                                        duration: const Duration(seconds: 2),
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        width: 360,
                                      ),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(4),
                                  child: Container(
                                    padding: const EdgeInsets.all(3.0),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor.withValues(
                                        alpha: 0.08,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Icon(
                                      Icons.copy_rounded,
                                      size: 12,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 6),
                        _buildJourneyMilestonePipeline(
                          hasSearch: hasSearch,
                          hasCart: hasCart,
                          hasCheckout: hasCheckout,
                          hasPaid: hasPaid,
                          hasFailed: hasFailedPayment,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: AppTheme.textSecondary,
                  ),
                ],
              ),
              if (_isExpanded) ...[
                const SizedBox(height: 12),
                const Divider(height: 1, color: AppTheme.lightBorderColor),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recent Activity (Latest ${recentEvents.length})',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            String? cardPhone;
                            String? cardRawUser;
                            Map<String, dynamic>? cardUserDetails;
                            for (final logs in widget.groupedEvents.values) {
                              for (final log in logs) {
                                if (cardPhone == null &&
                                    log['userPhone'] != null &&
                                    (log['userPhone'] as String).isNotEmpty) {
                                  cardPhone = log['userPhone'] as String?;
                                }
                                if (cardRawUser == null &&
                                    log['rawUser'] != null &&
                                    (log['rawUser'] as String).isNotEmpty) {
                                  cardRawUser = log['rawUser'] as String?;
                                }
                                if (cardUserDetails == null &&
                                    log['userDetails']
                                        is Map<String, dynamic>) {
                                  cardUserDetails =
                                      log['userDetails']
                                          as Map<String, dynamic>;
                                }
                              }
                            }
                            widget.onViewProfile(
                              widget.name,
                              id: cardRawUser,
                              phone: cardPhone,
                              details: cardUserDetails,
                            );
                          },
                          icon: const Icon(Icons.launch_rounded, size: 13),
                          label: Text(
                            'View Profile',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (recentEvents.isNotEmpty)
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: recentEvents.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final log = recentEvents[index];

                      return Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.backgroundColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppTheme.borderColor.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _getCategoryName(log),
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                Text(
                                  log['time']?.toString() ?? '',
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            if ((log['details']?.toString() ?? '')
                                .isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                log['details'].toString(),
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  )
                else if (widget.isLoadingEvents)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  )
                else
                  Text(
                    'No recent events recorded.',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LivePulsingDot extends StatefulWidget {
  const _LivePulsingDot();

  @override
  State<_LivePulsingDot> createState() => _LivePulsingDotState();
}

class _LivePulsingDotState extends State<_LivePulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.8,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _fadeAnimation = Tween<double>(
      begin: 0.8,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(
                    0xFF10B981,
                  ).withOpacity(_fadeAnimation.value),
                ),
              ),
            ),
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF10B981),
              ),
            ),
          ],
        );
      },
    );
  }
}
