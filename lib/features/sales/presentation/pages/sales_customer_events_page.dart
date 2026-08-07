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
import 'package:kd_pannel/util/dealers.dart';

class SalesCustomerEventsPage extends StatefulWidget {
  const SalesCustomerEventsPage({super.key});

  @override
  State<SalesCustomerEventsPage> createState() => _SalesCustomerEventsPageState();
}

class _SalesCustomerEventsPageState extends State<SalesCustomerEventsPage> {
  final ScrollController _scrollController = ScrollController();
  final Set<String> _processedEventIds = {};
  final Set<String> _loadingUserEvents = {};
  final Set<String> _activeUserNetworkFetches = {};
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

  Map<String, Map<String, List<Map<String, dynamic>>>> _cachedUserEventsGrouped = {};
  List<String> _cachedUsersWithEvents = [];
  Map<String, DateTime> _cachedMostRecentEventTimes = {};
  Map<String, bool> _cachedHighPriority = {};
  Map<String, String> _cachedPriorityReason = {};
  Map<String, String> _cachedUserTypes = {};

  @override
  void initState() {
    super.initState();
    _loadEvents();
    _listenToLivePresence();
    _startRealTimePoll();
  }

  @override
  void dispose() {
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
      if (userId == null || userId.isEmpty || userId.toLowerCase() == 'guest') return;

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
        final currentGrouped = Map<String, List<Map<String, dynamic>>>.from(_eventsLogs);
        final currentNameToId = Map<String, String>.from(_nameToId);

        _processEventsList([liveEvent], currentGrouped, currentNameToId, targetUserName: targetName);
        _eventsLogs = currentGrouped;
        _nameToId = currentNameToId;
      }

      _requestRebuildCache();
      if (mounted) setState(() {});
    });
  }

  void _startRealTimePoll() {
    _realTimeTimer = Timer.periodic(const Duration(seconds: 10), (_) {
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
          final uName = (u['userName'] ?? u['user'] ?? u['email'] ?? u['phone'] ?? '').toString();
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
    if (_onlineUserKeys.contains(userName) || _onlineUserKeys.contains(lowerName)) return true;

    final rawUser = _nameToId[userName];
    if (rawUser != null &&
        (_onlineUserKeys.contains(rawUser) || _onlineUserKeys.contains(rawUser.toLowerCase()))) {
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
      final Map<String, Map<String, List<Map<String, dynamic>>>> userEventsGrouped = {};
      final Set<String> usersSet = {};

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

      final Map<String, String> userTypes = {};

      try {
        final dealersState = context.read<DealersBloc>().state;
        for (final u in dealersState.allRawUsers) {
          final String rawUser = (u['_id'] ?? '').toString();
          final displayPhone = (u['phoneNumber'] ?? u['phone'] ?? '').toString();
          String displayName = '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'.trim();
          if (displayName.isEmpty) displayName = (u['shopName'] ?? '').toString();
          if (displayName.isEmpty) displayName = displayPhone.isNotEmpty ? displayPhone : 'New Customer';

          final kycStatus = u['kycStatus']?.toString().toLowerCase() ?? 'pending';
          final isDealer = kycStatus == 'verified';
          final type = isDealer ? 'Dealer' : 'Lead';

          if (_isUserAssignedToSales(rawUser: rawUser, displayName: displayName, userDetails: u)) {
            usersSet.add(displayName);
            if (rawUser.isNotEmpty) _nameToId[displayName] = rawUser;
            userTypes[displayName] = type;
            if (rawUser.isNotEmpty) userTypes[rawUser] = type;
          }
        }
      } catch (_) {}

      try {
        final leadsState = context.read<LeadsBloc>().state;
        for (final u in leadsState.allRawUsers) {
          final String rawUser = (u['_id'] ?? '').toString();
          final displayPhone = (u['phoneNumber'] ?? u['phone'] ?? '').toString();
          String displayName = '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'.trim();
          if (displayName.isEmpty) displayName = (u['shopName'] ?? '').toString();
          if (displayName.isEmpty) displayName = displayPhone.isNotEmpty ? displayPhone : 'New Customer';

          final kycStatus = u['kycStatus']?.toString().toLowerCase() ?? 'pending';
          final isDealer = kycStatus == 'verified';
          final type = isDealer ? 'Dealer' : 'Lead';

          if (_isUserAssignedToSales(rawUser: rawUser, displayName: displayName, userDetails: u)) {
            usersSet.add(displayName);
            if (rawUser.isNotEmpty) _nameToId[displayName] = rawUser;
            userTypes.putIfAbsent(displayName, () => type);
            if (rawUser.isNotEmpty) userTypes.putIfAbsent(rawUser, () => type);
          }
        }
      } catch (_) {}

      _cachedUserTypes = userTypes;

      userEventsGrouped.forEach((userName, categories) {
        final List<Map<String, dynamic>> userFlatLogs = [];
        final Set<String> seenEventKeys = {};
        categories.forEach((_, logs) {
          for (final log in logs) {
            final key = log['eventId']?.toString() ?? '${log['rawTimestamp']}_${log['details']}';
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

        final aTime = _cachedMostRecentEventTimes[a] ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = _cachedMostRecentEventTimes[b] ?? DateTime.fromMillisecondsSinceEpoch(0);
        if (aTime != bTime) return bTime.compareTo(aTime);
        return a.compareTo(b);
      });

      _cachedUsersWithEvents = sortedUsers;
    } finally {
      _isRebuildingCache = false;
      if (mounted) setState(() {});
    }
  }

  bool _isUserAssignedToSales({
    required String rawUser,
    required String displayName,
    Map<String, dynamic>? userDetails,
  }) {
    final curEmail = AuthService().currentUserEmail?.toLowerCase() ?? '';
    final curUid = AuthService().currentUserId?.toLowerCase() ?? '';
    if (curEmail.isEmpty && curUid.isEmpty) return true;

    if (userDetails != null) {
      final assigned = userDetails['assignedAgent'] ?? userDetails['assignedSalesAgent'] ?? userDetails['salesAgent'];
      if (assigned != null) {
        final assStr = assigned.toString().toLowerCase();
        if (assStr.contains(curEmail) || assStr.contains(curUid)) return true;
      }
    }
    return true;
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
      final displayPhone = (event['userPhone'] ??
              userDetails?['phoneNumber'] ??
              userDetails?['phone'] ??
              '')
          .toString();

      String displayName = targetUserName ??
          event['userName']?.toString() ??
          (userDetails != null
              ? '${userDetails['firstName'] ?? ''} ${userDetails['lastName'] ?? ''}'.trim()
              : null) ??
          '';

      if (displayName.isEmpty) displayName = userDetails?['shopName']?.toString() ?? '';
      if (displayName.isEmpty && displayPhone.isNotEmpty) displayName = displayPhone;
      if (displayName.isEmpty && rawUser != null) displayName = rawUser;
      if (displayName.isEmpty) displayName = 'Guest User';

      final eventType = event['eventType']?.toString() ?? 'unknown';
      if (!grouped.containsKey(eventType)) grouped[eventType] = [];

      if (rawUser != null) nameToId[displayName] = rawUser;

      grouped[eventType]!.add({
        'eventId': eventId,
        'user': displayName,
        'userPhone': displayPhone,
        'rawUser': rawUser,
        'category': event['category']?.toString() ?? event['categoryName']?.toString() ?? eventType,
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
      final res = await AnalyticsService().fetchEventsPaged(limit: 100);
      final flatEvents = (res['events'] as List?)?.cast<Map<String, dynamic>>() ?? [];

      if (flatEvents.isNotEmpty) {
        final currentGrouped = Map<String, List<Map<String, dynamic>>>.from(_eventsLogs);
        final currentNameToId = Map<String, String>.from(_nameToId);
        _processEventsList(flatEvents, currentGrouped, currentNameToId);
        _eventsLogs = currentGrouped;
        _nameToId = currentNameToId;
      }
    } catch (_) {}

    _rebuildCache();
    if (mounted) setState(() => _isLoading = false);
    _isLoadingEvents = false;
  }

  Future<void> _fetchEventsForUser(String userName, {bool silent = false}) async {
    if (_activeUserNetworkFetches.contains(userName)) return;
    _activeUserNetworkFetches.add(userName);

    if (!silent && mounted) setState(() => _loadingUserEvents.add(userName));

    try {
      final resolvedQuery = _nameToId[userName] ?? userName;
      if (resolvedQuery.isEmpty) return;

      final res = await AnalyticsService().fetchEventsPaged(userEmail: resolvedQuery, limit: 10);
      List<Map<String, dynamic>> flatEvents = (res['events'] as List?)?.cast<Map<String, dynamic>>() ?? [];

      if (flatEvents.isNotEmpty) {
        flatEvents = flatEvents.take(10).toList();
        _perUserEventsCache[userName] = flatEvents;
        final currentGrouped = Map<String, List<Map<String, dynamic>>>.from(_eventsLogs);
        final currentNameToId = Map<String, String>.from(_nameToId);
        _processEventsList(flatEvents, currentGrouped, currentNameToId, targetUserName: userName);
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
      if (!_activeUserNetworkFetches.contains(userName)) {
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

  void _navigateToProfile(BuildContext context, String user) {
    if (user.isEmpty) return;
    final nameLower = user.toLowerCase().trim();
    final cleanUser = nameLower.replaceAll(RegExp(r'\D'), '');
    final userLast10 = cleanUser.length >= 10 ? cleanUser.substring(cleanUser.length - 10) : '';

    try {
      final dealersState = context.read<DealersBloc>().state;
      final Map<String, dynamic>? dealerData = dealersState.allRawUsers.firstWhere(
        (u) {
          final String uid = (u['_id'] ?? '').toString();
          if (uid == user) return true;
          final String phone = (u['phoneNumber'] ?? '').toString();
          final String cleanP = phone.replaceAll(RegExp(r'\D'), '');
          final String p10 = cleanP.length >= 10 ? cleanP.substring(cleanP.length - 10) : '';
          if (phone == user || (userLast10.isNotEmpty && p10 == userLast10)) return true;

          final String fullName = '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'.trim().toLowerCase();
          final String shopName = (u['shopName'] ?? '').toString().toLowerCase();

          if (fullName.isNotEmpty && !RegExp(r'^\d+$').hasMatch(fullName)) {
            if (fullName == nameLower || fullName.contains(nameLower) || nameLower.contains(fullName)) return true;
          }
          if (shopName.isNotEmpty && !RegExp(r'^\d+$').hasMatch(shopName)) {
            if (shopName == nameLower || shopName.contains(nameLower) || nameLower.contains(shopName)) return true;
          }
          return false;
        },
        orElse: () => <String, dynamic>{},
      );

      if (dealerData != null && dealerData.isNotEmpty) {
        final kycStatus = dealerData['kycStatus']?.toString().toLowerCase() ?? 'pending';
        final isDealer = kycStatus == 'verified';

        if (isDealer) {
          final agentName = dealerData['assignedAgent'] != null
              ? '${dealerData['assignedAgent']['firstName'] ?? ''} ${dealerData['assignedAgent']['lastName'] ?? ''}'.trim()
              : '-';

          final String personName = (dealerData['firstName'] != null || dealerData['lastName'] != null)
              ? '${dealerData['firstName'] ?? ''} ${dealerData['lastName'] ?? ''}'.trim()
              : '';

          final dealer = Dealer(
            name: personName.isNotEmpty ? personName : (dealerData['phoneNumber'] ?? user),
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
            notesHistory: dealerData['notesHistory'] != null ? List<Map<String, dynamic>>.from(dealerData['notesHistory']) : [],
          );

          Navigator.pushNamed(context, '/dealers/profile', arguments: dealer);
          return;
        } else {
          final String personName = (dealerData['firstName'] != null || dealerData['lastName'] != null)
              ? '${dealerData['firstName'] ?? ''} ${dealerData['lastName'] ?? ''}'.trim()
              : '';

          final leadMap = {
            'id': dealerData['_id'],
            'name': personName.isNotEmpty ? personName : (dealerData['phoneNumber'] ?? user),
            'phone': dealerData['phoneNumber'] ?? '',
            'shopName': dealerData['shopName'] ?? '',
            'villageArea': dealerData['address']?['villageArea'] ?? '',
            'city': dealerData['address']?['cityTehsil'] ?? '',
            'state': dealerData['address']?['state'] ?? '',
            'pincode': dealerData['address']?['pincode'] ?? '',
            'source': dealerData['source'] ?? 'App',
            'kycStatus': dealerData['kycStatus'] ?? 'pending',
            'status': dealerData['status'] ?? dealerData['leadStatus'] ?? 'prospect',
            'notes': dealerData['notes'] ?? dealerData['leadNotes'] ?? '',
            'notesHistory': dealerData['notesHistory'] ?? [],
          };
          Navigator.pushNamed(context, '/leads/profile', arguments: leadMap);
          return;
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = Responsive.isDesktop(context);
    final users = _cachedUsersWithEvents;
    final int totalUsers = users.length;
    final int totalPages = (totalUsers == 0) ? 1 : ((totalUsers / _usersPerPage).ceil());

    int currentPage = _currentPage;
    if (currentPage > totalPages) currentPage = totalPages;
    if (currentPage < 1) currentPage = 1;

    final int startIndex = (totalUsers == 0) ? 0 : (currentPage - 1) * _usersPerPage;
    final int endIndex = (startIndex + _usersPerPage < totalUsers) ? (startIndex + _usersPerPage) : totalUsers;
    final List<String> paginatedUsers = (startIndex < totalUsers) ? users.sublist(startIndex, endIndex) : <String>[];

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
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : SingleChildScrollView(
              controller: _scrollController,
              padding: EdgeInsets.all(isDesktop ? 24 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(totalUsers),
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
                        final userEvents = _cachedUserEventsGrouped[userName] ?? {};
                        final isOnline = _isUserOnline(userName);
                        final isHighPriority = _cachedHighPriority[userName] ?? false;
                        final priorityReason = _cachedPriorityReason[userName] ?? '';

                        return _SalesUserCard(
                          name: userName,
                          userType: _cachedUserTypes[userName] ?? 'Lead',
                          groupedEvents: userEvents,
                          isOnline: isOnline,
                          isHighPriority: isHighPriority,
                          priorityReason: priorityReason,
                          isLoadingEvents: _loadingUserEvents.contains(userName),
                          onViewProfile: (name) => _navigateToProfile(context, name),
                        );
                      },
                    ),
                  const SizedBox(height: 20),
                  _buildPaginationControls(isDesktop, totalUsers, totalPages, currentPage),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader(int totalCount) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppTheme.borderRadiusXLarge)),
        boxShadow: AppTheme.cardShadow,
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
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
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor),
                ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$totalCount Users',
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
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
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
      ),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.analytics_outlined, size: 40, color: AppTheme.primaryColor),
            const SizedBox(height: 16),
            Text(
              'No Customer Events Logged',
              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaginationControls(bool isDesktop, int totalUsers, int totalPages, int currentPage) {
    final int startItem = totalUsers == 0 ? 0 : (currentPage - 1) * _usersPerPage + 1;
    final int endItem = (currentPage * _usersPerPage < totalUsers) ? (currentPage * _usersPerPage) : totalUsers;

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
            style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
          ),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: currentPage > 1 ? () => setState(() => _currentPage = currentPage - 1) : null,
                icon: const Icon(Icons.chevron_left_rounded, size: 18),
                label: const Text('Prev'),
              ),
              const SizedBox(width: 12),
              Text(
                'Page $currentPage of $totalPages',
                style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: currentPage < totalPages ? () => setState(() => _currentPage = currentPage + 1) : null,
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
  final ValueChanged<String> onViewProfile;

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

  String _getCategoryName(Map<String, dynamic> log) {
    final explicitCat = log['category']?.toString() ?? log['categoryName']?.toString();
    if (explicitCat != null &&
        explicitCat.isNotEmpty &&
        explicitCat.toLowerCase() != 'general' &&
        explicitCat.toLowerCase() != 'unknown') {
      return _formatTitleCase(explicitCat);
    }

    final rawType = (log['eventType'] ?? log['event'] ?? '').toString();
    if (rawType.isEmpty) return 'General Activity';

    final lower = rawType.toLowerCase();

    if (lower.contains('coupon') || lower.contains('discount') || lower.contains('promo') || lower.contains('offer')) {
      return 'Coupons & Offers';
    } else if (lower.contains('payment') || lower.contains('checkout') || lower.contains('cart') || lower.contains('order') || lower.contains('buy')) {
      return 'Cart & Payments';
    } else if (lower.contains('product') || lower.contains('item') || lower.contains('catalog') || lower.contains('view')) {
      return 'Product Browsing';
    } else if (lower.contains('search') || lower.contains('filter')) {
      return 'Search & Catalog';
    } else if (lower.contains('page') || lower.contains('screen') || lower.contains('nav') || lower.contains('open') || lower.contains('app')) {
      return 'App Navigation';
    } else if (lower.contains('auth') || lower.contains('login') || lower.contains('profile') || lower.contains('account')) {
      return 'Account & Profile';
    } else if (lower.contains('lead') || lower.contains('contact') || lower.contains('call') || lower.contains('whatsapp')) {
      return 'Lead & Inquiry';
    }

    return _formatTitleCase(rawType);
  }

  String _formatTitleCase(String text) {
    final cleaned = text.replaceAll('_', ' ').replaceAll('-', ' ').trim();
    if (cleaned.isEmpty) return 'General Activity';
    return cleaned.split(' ').map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  Widget _buildUserTypeBadge(String type) {
    final isDealer = type.toLowerCase() == 'dealer';
    final label = isDealer ? 'Dealer' : 'Lead';
    final bgColor = isDealer
        ? const Color(0xFF10B981).withOpacity(0.12)
        : const Color(0xFFF59E0B).withOpacity(0.12);
    final textColor = isDealer
        ? const Color(0xFF059669)
        : const Color(0xFFD97706);
    final icon = isDealer ? Icons.verified_rounded : Icons.person_pin_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: textColor.withOpacity(0.25)),
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

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> allEvents = [];
    final Set<String> seenKeys = {};

    widget.groupedEvents.forEach((_, logs) {
      for (final log in logs) {
        final key = log['eventId']?.toString() ?? '${log['rawTimestamp']}_${log['details']}';
        if (!seenKeys.contains(key)) {
          seenKeys.add(key);
          allEvents.add(log);
        }
      }
    });

    allEvents.sort((a, b) {
      final aTs = a['rawTimestamp']?.toString() ?? '';
      final bTs = b['rawTimestamp']?.toString() ?? '';
      return bTs.compareTo(aTs);
    });

    final recentEvents = allEvents.take(10).toList();

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        border: Border.all(color: widget.isOnline ? const Color(0xFF10B981).withOpacity(0.4) : AppTheme.borderColor),
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
                    backgroundColor: widget.isOnline ? const Color(0xFF10B981).withOpacity(0.15) : AppTheme.primaryColor.withOpacity(0.1),
                    child: Text(
                      widget.name.isNotEmpty ? widget.name[0].toUpperCase() : 'C',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: widget.isOnline ? const Color(0xFF10B981) : AppTheme.primaryColor),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              widget.name,
                              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                            ),
                            const SizedBox(width: 8),
                            _buildUserTypeBadge(widget.userType),
                            if (widget.isOnline) ...[
                              const SizedBox(width: 8),
                              const _LivePulsingDot(),
                              const SizedBox(width: 4),
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
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${recentEvents.length} recent event${recentEvents.length == 1 ? "" : "s"}',
                          style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Icon(_isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: AppTheme.textSecondary),
                ],
              ),
              if (_isExpanded) ...[
                const SizedBox(height: 12),
                const Divider(height: 1, color: AppTheme.lightBorderColor),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Recent Activity (Latest ${recentEvents.length})', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                    TextButton.icon(
                      onPressed: () => widget.onViewProfile(widget.name),
                      icon: const Icon(Icons.launch_rounded, size: 13),
                      label: Text('View Profile', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold)),
                      style: TextButton.styleFrom(foregroundColor: AppTheme.primaryColor),
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
                          border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _getCategoryName(log),
                                  style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
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
                            if ((log['details']?.toString() ?? '').isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                log['details'].toString(),
                                style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textSecondary),
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
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor)),
                  )
                else
                  Text('No recent events recorded.', style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textSecondary)),
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

class _LivePulsingDotState extends State<_LivePulsingDot> with SingleTickerProviderStateMixin {
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

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.8).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.8, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
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
                  color: const Color(0xFF10B981).withOpacity(_fadeAnimation.value),
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
