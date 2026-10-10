import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kd_pannel/app_theme.dart';
import 'package:kd_pannel/core/auth/auth_service.dart';
import 'package:kd_pannel/core/network/api_client.dart';
import 'package:kd_pannel/core/network/websocket_service.dart';
import 'package:kd_pannel/core/responsive/responsive.dart';
import 'package:kd_pannel/core/services/telephony_audio_service.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/call_logs_bloc.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/call_logs_event.dart';
import 'package:kd_pannel/features/shared/widgets/telephony_call_button.dart';
import 'package:kd_pannel/features/admin/presentation/widgets/whatsapp/whatsapp_doodle_painter.dart';
import 'package:kd_pannel/features/admin/presentation/widgets/whatsapp/whatsapp_call_history_dialog.dart';
import 'package:kd_pannel/features/admin/presentation/widgets/whatsapp/whatsapp_canned_replies_dialog.dart';
import 'package:kd_pannel/features/admin/presentation/widgets/whatsapp/whatsapp_template_picker_dialog.dart';
import 'package:kd_pannel/features/admin/presentation/widgets/whatsapp/whatsapp_media_picker_dialog.dart';

class WebCustomScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };
}

class WhatsAppCrmPage extends StatefulWidget {
  const WhatsAppCrmPage({super.key});

  @override
  State<WhatsAppCrmPage> createState() => _WhatsAppCrmPageState();
}

class _WhatsAppCrmPageState extends State<WhatsAppCrmPage> {
  // Lists & States
  List<dynamic> _conversations = [];
  List<dynamic> _messages = [];
  List<dynamic> _salesAgents = [];
  dynamic _selectedConversation;
  bool _isLoadingConversations = false;
  bool _isLoadingMessages = false;

  // Search & Pagination Controllers
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final ScrollController _messageScrollController = ScrollController();
  final ScrollController _sidebarFilterScrollController = ScrollController();

  String _selectedStatus = 'all'; // all, closed, snoozed
  String _selectedTab = 'all'; // all, active, leads, dealers, unread
  bool _isSyncingRoster = false;
  int _conversationsPage = 1;
  int _conversationsTotalPages = 1;
  int _messagesPage = 1;
  bool _isNotesMode = false; // toggle input field for message or note
  bool _isSearchingMessages = false;
  String _messageSearchQuery = '';
  final TextEditingController _messageSearchController =
      TextEditingController();
  Timer? _searchDebounce;
  StreamSubscription? _websocketSubscription;
  final Set<String> _seenWsMessageIds = {};

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      _fetchConversations(search: value.trim());
    });
  }

  // Predefined beautiful pastel colors for contacts
  Color _getAvatarColor(String name) {
    final colors = [
      const Color(0xFFE57373), // red
      const Color(0xFFF06292), // pink
      const Color(0xFFBA68C8), // purple
      const Color(0xFF9575CD), // deep purple
      const Color(0xFF7986CB), // indigo
      const Color(0xFF64B5F6), // blue
      const Color(0xFF4FC3F7), // light blue
      const Color(0xFF4DD0E1), // cyan
      const Color(0xFF4DB6AC), // teal
      const Color(0xFF81C784), // green
      const Color(0xFFFFD54F), // amber
      const Color(0xFFFFB74D), // orange
      const Color(0xFFFF8A65), // deep orange
    ];
    if (name.isEmpty) return const Color(0xFF008069);
    final hash = name.codeUnits.fold(0, (prev, element) => prev + element);
    return colors[hash % colors.length];
  }

  List<dynamic> _approvedTemplates = [];
  bool _isLoadingTemplates = false;
  List<dynamic> _cannedResponses = [];
  bool _isLoadingCanned = false;

  // Real-time Agent Typing Trackers: conversationId -> Map { agentId, agentName, timer }
  final Map<String, Map<String, dynamic>> _activeTypingAgents = {};
  Timer? _myTypingDebounceTimer;
  bool _isCurrentlyTypingLocally = false;
  dynamic _replyingToMessage;
  List<dynamic> _activeSlashMatches = [];

  String _interpolateCannedMessage(String template) {
    if (_selectedConversation == null) return template;
    final contact = _selectedConversation['contactId'] ?? {};
    final String customerName = (contact['name'] ?? 'Customer').toString();
    final String customerPhone = (contact['phone'] ?? '').toString();
    final String agentName = AuthService().currentUserName ?? 'Agent';

    return template
        .replaceAll(RegExp(r'\{\{\s*name\s*\}\}', caseSensitive: false), customerName)
        .replaceAll(RegExp(r'\{\{\s*customer_name\s*\}\}', caseSensitive: false), customerName)
        .replaceAll(RegExp(r'\{\{\s*phone\s*\}\}', caseSensitive: false), customerPhone)
        .replaceAll(RegExp(r'\{\{\s*agent_name\s*\}\}', caseSensitive: false), agentName)
        .replaceAll(RegExp(r'\{\{\s*my_name\s*\}\}', caseSensitive: false), agentName);
  }

  void _onMessageTextChanged(String text) {
    final convId = _selectedConversation?['_id']?.toString();
    if (convId == null || convId.isEmpty) return;

    // Detect Slash '/' command for Canned Quick Replies
    if (text.startsWith('/')) {
      final query = text.substring(1).toLowerCase();
      final matches = _cannedResponses.where((c) {
        final sc = (c['shortcut'] ?? '').toString().toLowerCase().replaceAll('/', '');
        final title = (c['title'] ?? '').toString().toLowerCase();
        final msg = (c['message'] ?? '').toString().toLowerCase();
        return sc.contains(query) || title.contains(query) || msg.contains(query);
      }).toList();
      setState(() {
        _activeSlashMatches = matches;
      });
    } else {
      if (_activeSlashMatches.isNotEmpty) {
        setState(() {
          _activeSlashMatches = [];
        });
      }
    }

    if (text.trim().isNotEmpty) {
      if (!_isCurrentlyTypingLocally) {
        _isCurrentlyTypingLocally = true;
        WebSocketService().sendTypingStart(convId);
      }
      _myTypingDebounceTimer?.cancel();
      _myTypingDebounceTimer = Timer(const Duration(milliseconds: 2500), () {
        _isCurrentlyTypingLocally = false;
        WebSocketService().sendTypingStop(convId);
      });
    } else {
      if (_isCurrentlyTypingLocally) {
        _isCurrentlyTypingLocally = false;
        _myTypingDebounceTimer?.cancel();
        WebSocketService().sendTypingStop(convId);
      }
    }
  }

  int _totalAllCount = 0;
  int _totalLeadsCount = 0;
  int _totalDealersCount = 0;
  int _totalActiveCount = 0;
  int _totalUnreadCount = 0;

  void _recalculateUnreadCount() {
    _totalUnreadCount = _conversations.where((c) {
      final isSelected = _selectedConversation != null &&
          _selectedConversation!['_id']?.toString() == c['_id']?.toString();
      if (isSelected) return false;
      final u = int.tryParse(c['unreadCount']?.toString() ?? '0') ?? 0;
      return u > 0;
    }).length;
  }

  bool _matchesCurrentFilters(dynamic conversation) {
    if (_selectedStatus != 'all' && _selectedStatus.isNotEmpty) {
      final status = (conversation['status'] ?? 'open').toString().toLowerCase();
      if (_selectedStatus == 'open' && status != 'open') return false;
      if (_selectedStatus != 'open' && status != _selectedStatus) return false;
    }
    if (_selectedTab == 'all') return true;
    if (_selectedTab == 'unread') {
      final u = int.tryParse(conversation['unreadCount']?.toString() ?? '0') ?? 0;
      return u > 0;
    }
    if (_selectedTab == 'active') {
      final lastIncoming = conversation['lastIncomingMessageAt'];
      if (lastIncoming == null) return false;
      final dt = DateTime.tryParse(lastIncoming.toString());
      if (dt == null) return false;
      return DateTime.now().toUtc().difference(dt.toUtc()).inHours < 24;
    }
    final contact = conversation['contactId'] ?? {};
    final tags = List<dynamic>.from(contact['tags'] ?? []);
    final bool isDealer = tags.any((t) =>
        t.toString().toLowerCase().contains('dealer') ||
        t.toString().toLowerCase().contains('retailer')) ||
        conversation['contactType'] == 'dealer';

    if (_selectedTab == 'dealers') return isDealer;
    if (_selectedTab == 'leads') return !isDealer;
    return true;
  }

  String _normalizePhone(String phone) {
    String digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('91') && digits.length == 12) {
      digits = digits.substring(2);
    } else if (digits.length == 8 && RegExp(r'^[6-9]').hasMatch(digits)) {
      digits = '91$digits';
    }
    return digits;
  }

  @override
  void initState() {
    super.initState();
    TelephonyAudioService().requestNotificationPermission();
    _fetchConversations();
    _fetchSalesAgents();
    _fetchTemplates();
    _fetchCannedResponses();
    _setupWebSocketListener();

    // Check for arguments passed from Leads/Dealers profile buttons
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, dynamic>) {
        final phone = args['phone'] as String?;
        final name = args['name'] as String?;
        if (phone != null && phone.isNotEmpty) {
          final cleanPhone = _normalizePhone(phone);
          _searchController.text = cleanPhone;
          _startOrGetConversation(cleanPhone, name: name);
        }
      }
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _myTypingDebounceTimer?.cancel();
    if (_isCurrentlyTypingLocally && _selectedConversation?['_id'] != null) {
      WebSocketService().sendTypingStop(_selectedConversation!['_id'].toString());
    }
    for (final info in _activeTypingAgents.values) {
      (info['timer'] as Timer?)?.cancel();
    }
    _websocketSubscription?.cancel();
    _searchController.dispose();
    _messageController.dispose();
    _noteController.dispose();
    _messageSearchController.dispose();
    _messageScrollController.dispose();
    _sidebarFilterScrollController.dispose();
    super.dispose();
  }

  void _sortMessages() {
    _messages.sort((a, b) {
      final aTime = DateTime.tryParse(a['createdAt']?.toString() ?? '')?.millisecondsSinceEpoch ?? 0;
      final bTime = DateTime.tryParse(b['createdAt']?.toString() ?? '')?.millisecondsSinceEpoch ?? 0;
      if (aTime != bTime) return aTime.compareTo(bTime);
      return (a['_id']?.toString() ?? '').compareTo(b['_id']?.toString() ?? '');
    });

    final deduped = <dynamic>[];
    for (final msg in _messages) {
      final id = (msg['_id'] ?? '').toString();
      final wabaId = (msg['myoperatorMessageId'] ?? msg['wabaMessageId'] ?? '').toString();
      final isTempMsg = id.startsWith('temp_') || id.startsWith('local_') || id.isEmpty;

      final existingIdx = deduped.indexWhere((ex) {
        final exId = (ex['_id'] ?? '').toString();
        final exWabaId = (ex['myoperatorMessageId'] ?? ex['wabaMessageId'] ?? '').toString();
        final isExTemp = exId.startsWith('temp_') || exId.startsWith('local_') || exId.isEmpty;

        // 1. Exact ID match on database _id
        if (id.isNotEmpty && exId.isNotEmpty && id == exId) return true;

        // 2. Exact ID match on provider message ID
        if (wabaId.isNotEmpty && exWabaId.isNotEmpty && wabaId == exWabaId) return true;

        // 3. Only reconcile content/timestamp if one is a temporary optimistic message
        if (isTempMsg || isExTemp) {
          final content = (msg['content'] ?? '').toString().trim();
          final dir = (msg['direction'] ?? '').toString();
          final ts = DateTime.tryParse(msg['createdAt']?.toString() ?? '')?.millisecondsSinceEpoch ?? 0;

          final exContent = (ex['content'] ?? '').toString().trim();
          final exDir = (ex['direction'] ?? '').toString();
          final exTs = DateTime.tryParse(ex['createdAt']?.toString() ?? '')?.millisecondsSinceEpoch ?? 0;

          if (dir == exDir && content == exContent && (ts - exTs).abs() < 15000) {
            return true;
          }
        }
        return false;
      });

      if (existingIdx == -1) {
        deduped.add(msg);
      } else {
        final ex = deduped[existingIdx];
        if (msg['sentBy'] != null && ex['sentBy'] == null) {
          deduped[existingIdx] = msg;
        } else if (msg['status'] == 'read' && ex['status'] != 'read') {
          ex['status'] = 'read';
        } else if (ex['_id']?.toString().startsWith('temp_') == true && !id.startsWith('temp_')) {
          deduped[existingIdx] = msg;
        }
      }
    }
    _messages = deduped;
  }

  void _sortConversations() {
    _conversations.sort((a, b) {
      final aTime = DateTime.tryParse(a['lastMessageAt']?.toString() ?? '')?.millisecondsSinceEpoch ?? 0;
      final bTime = DateTime.tryParse(b['lastMessageAt']?.toString() ?? '')?.millisecondsSinceEpoch ?? 0;
      return bTime.compareTo(aTime);
    });
  }

  // Set up WebSocket to update interface in real-time
  void _setupWebSocketListener() {
    _websocketSubscription = WebSocketService().chatUpdates.listen((event) {
      if (!mounted) return;
      final type = event['type'];
      final data = event['data'];

      if (type == 'NEW_MESSAGE') {
        final newConversation = data['conversation'];
        final newMessage = data['message'];

        if (newConversation == null || newConversation['_id'] == null) return;

        // Deduplicate WebSocket frames to prevent double-counting
        final String newMsgId = (newMessage?['_id']?.toString().isNotEmpty == true
            ? newMessage!['_id'].toString()
            : (newMessage?['myoperatorMessageId']?.toString().isNotEmpty == true
                ? newMessage!['myoperatorMessageId'].toString()
                : (newMessage?['wabaMessageId']?.toString() ?? ''))).trim();
        if (newMsgId.isNotEmpty) {
          if (_seenWsMessageIds.contains(newMsgId)) {
            return;
          }
          _seenWsMessageIds.add(newMsgId);
          if (_seenWsMessageIds.length > 500) {
            _seenWsMessageIds.remove(_seenWsMessageIds.first);
          }
        }

        final isIncoming = (newMessage?['direction'] ?? '') == 'incoming';
        if (isIncoming) {
          TelephonyAudioService().playIncomingMessageTone();
        }

        final contact = newConversation['contactId'] ?? {};
        final senderName = (contact['name'] ?? contact['phone'] ?? 'WhatsApp User').toString();
        final textSnippet = (newMessage?['content'] ?? (newMessage?['mediaUrl'] != null ? '[Media Attachment]' : 'New Message')).toString();

        if (isIncoming) {
          TelephonyAudioService().showDesktopNotification('💬 $senderName', textSnippet);
        }

        setState(() {
          // 1. Update matching conversation in list or insert it
          final String convId = newConversation['_id'].toString();
          final index = _conversations.indexWhere(
            (c) => c['_id'].toString() == convId,
          );

          final bool isCurrentlySelected = _selectedConversation != null && _selectedConversation['_id'].toString() == convId;

          // Compare timestamps to preserve truly latest message & preview
          final DateTime? existingTs = index != -1 ? DateTime.tryParse(_conversations[index]['lastMessageAt']?.toString() ?? '') : null;
          final DateTime? incomingTs = DateTime.tryParse(newConversation['lastMessageAt']?.toString() ?? '');
          final DateTime? msgTs = DateTime.tryParse(newMessage?['createdAt']?.toString() ?? '');

          final DateTime effectiveMsgTs = msgTs ?? DateTime.now();
          final bool isMsgNewest = (incomingTs == null || !effectiveMsgTs.isBefore(incomingTs)) &&
                                   (existingTs == null || !effectiveMsgTs.isBefore(existingTs));

          if (isMsgNewest && newMessage != null) {
            newConversation['lastMessageAt'] = effectiveMsgTs.toIso8601String();
            newConversation['lastMessage'] = {
              'type': newMessage['type'] ?? 'text',
              'content': newMessage['content'] ?? '',
              'mediaUrl': newMessage['mediaUrl'],
            };
          } else if (existingTs != null && incomingTs != null && existingTs.isAfter(incomingTs)) {
            newConversation['lastMessageAt'] = _conversations[index]['lastMessageAt'];
            newConversation['lastMessage'] = _conversations[index]['lastMessage'];
          } else {
            newConversation['lastMessageAt'] ??= DateTime.now().toIso8601String();
            if (newConversation['lastMessage'] == null && newMessage != null) {
              newConversation['lastMessage'] = {
                'type': newMessage['type'] ?? 'text',
                'content': newMessage['content'] ?? '',
                'mediaUrl': newMessage['mediaUrl'],
              };
            }
          }

          if (!isCurrentlySelected && isIncoming) {
            final int prevUnread = (index != -1
                ? (int.tryParse(_conversations[index]['unreadCount']?.toString() ?? '0') ?? 0)
                : 0);
            final int backendUnread = int.tryParse(newConversation['unreadCount']?.toString() ?? '0') ?? 0;
            final int nextUnread = backendUnread > prevUnread ? backendUnread : (prevUnread + 1);
            newConversation['unreadCount'] = nextUnread;
          } else if (isCurrentlySelected) {
            newConversation['unreadCount'] = 0;
            // Instantly clear unread count on backend DB when viewing active thread
            ApiClient().put('/conversations/$convId/read', {}).catchError((e) {
              debugPrint('[WhatsApp CRM] Error marking conversation as read: $e');
              return http.Response('{}', 500);
            });
          }

          if (index != -1) {
            if (_matchesCurrentFilters(newConversation)) {
              _conversations[index] = newConversation;
            } else {
              _conversations.removeAt(index);
            }
          } else if (_matchesCurrentFilters(newConversation)) {
            _totalAllCount = _totalAllCount + 1;
            _conversations.insert(0, newConversation);
          }
          _recalculateUnreadCount();
          _sortConversations();

          // 2. If the new message is in the currently selected conversation, append it
          if (isCurrentlySelected && newMessage != null) {
            final String msgId = newMessage['_id']?.toString() ?? '';
            final String wabaId = newMessage['myoperatorMessageId']?.toString() ?? '';
            final idx = _messages.indexWhere((m) =>
              (msgId.isNotEmpty && m['_id']?.toString() == msgId) ||
              (wabaId.isNotEmpty && m['myoperatorMessageId']?.toString() == wabaId)
            );
            if (idx == -1) {
              _messages.add(newMessage);
            } else {
              _messages[idx] = newMessage;
            }
            _sortMessages();
            _scrollToBottom();
          }
        });
      } else if (type == 'CONVERSATION_READ' && data != null) {
        final convId = data['conversationId']?.toString();
        if (convId != null) {
          setState(() {
            final idx = _conversations.indexWhere((c) => c['_id']?.toString() == convId);
            if (idx != -1) {
              _conversations[idx]['unreadCount'] = 0;
            }
            if (_selectedConversation?['_id']?.toString() == convId) {
              _selectedConversation!['unreadCount'] = 0;
            }
            _recalculateUnreadCount();
          });
        }
      } else if (type == 'CONVERSATION_UNREAD' && data != null) {
        final convId = data['conversationId']?.toString();
        if (convId != null) {
          setState(() {
            final idx = _conversations.indexWhere((c) => c['_id']?.toString() == convId);
            if (idx != -1) {
              _conversations[idx]['unreadCount'] = 1;
            }
            _recalculateUnreadCount();
          });
        }
      } else if (type == 'MESSAGE_STATUS_UPDATED') {
        final conversationId = data['conversationId'];
        final messageId = data['messageId'];
        final status = data['status'];

        if (_selectedConversation != null &&
            _selectedConversation['_id'] == conversationId) {
          setState(() {
            final index = _messages.indexWhere((m) => m['_id'] == messageId);
            if (index != -1) {
              _messages[index]['status'] = status;
            }
          });
        }
      } else if (type == 'AGENT_TYPING_START' && data != null) {
        final convId = data['conversationId']?.toString();
        final agentId = data['agentId']?.toString();
        final agentName = data['agentName']?.toString() ?? 'Agent';
        final currentUserId = AuthService().currentUserId;

        if (convId != null && agentId != null && agentId != currentUserId) {
          setState(() {
            (_activeTypingAgents[convId]?['timer'] as Timer?)?.cancel();
            final timer = Timer(const Duration(milliseconds: 3500), () {
              if (mounted) {
                setState(() {
                  _activeTypingAgents.remove(convId);
                });
              }
            });

            _activeTypingAgents[convId] = {
              'agentId': agentId,
              'agentName': agentName,
              'timer': timer,
            };
          });
        }
      } else if (type == 'AGENT_TYPING_STOP' && data != null) {
        final convId = data['conversationId']?.toString();
        final agentId = data['agentId']?.toString();
        if (convId != null && _activeTypingAgents[convId]?['agentId'] == agentId) {
          setState(() {
            (_activeTypingAgents[convId]?['timer'] as Timer?)?.cancel();
            _activeTypingAgents.remove(convId);
          });
        }
      } else if (type == 'CALL_UPDATE') {
        final callData = data ?? {};
        final callStatus = callData['status']?.toString().toLowerCase();
        if (callStatus == 'missed' || callStatus == 'no-answer') {
          TelephonyAudioService().playCallMissedTone();
        } else {
          TelephonyAudioService().playCallAlertTone();
        }
      }
    });
  }

  // API Call: Start or retrieve conversation for a given phone/name
  Future<void> _startOrGetConversation(String phone, {String? name}) async {
    setState(() {
      _isLoadingConversations = true;
    });

    try {
      final res = await ApiClient().post('/conversations/start', {
        'phone': phone,
        'name': name,
      });

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true && body['data'] != null) {
          final conv = body['data'];
          setState(() {
            final index = _conversations.indexWhere(
              (c) => c['_id'] == conv['_id'],
            );
            if (index != -1) {
              _conversations[index] = conv;
            } else {
              _conversations.insert(0, conv);
            }
            _selectedConversation = conv;
          });
          _fetchMessages(conv['_id']);
        }
      } else {
        _fetchConversations(search: phone);
      }
    } catch (e) {
      debugPrint('[WhatsApp CRM] Error starting conversation: $e');
      _fetchConversations(search: phone);
    } finally {
      setState(() {
        _isLoadingConversations = false;
      });
    }
  }

  // API Call: Fetch list of conversations
  Future<void> _fetchConversations({String search = '', int page = 1}) async {
    setState(() {
      _isLoadingConversations = true;
      _conversationsPage = page;
    });
    debugPrint(
      '[WhatsApp CRM] Fetching page $_conversationsPage of $_conversationsTotalPages (tab: $_selectedTab)',
    );

    try {
      final endpoint =
          '/conversations?status=$_selectedStatus&tab=$_selectedTab&search=$search&page=$page&limit=500';
      final res = await ApiClient().get(endpoint);

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true && mounted) {
          setState(() {
            if (page == 1) {
              _conversations = body['data'] ?? [];
            } else {
              _conversations.addAll(body['data'] ?? []);
            }
            _conversationsTotalPages = body['pagination']?['pages'] ?? 1;
            if (body['counts'] != null) {
              final counts = body['counts'];
              final int allC = (counts['all'] as num?)?.toInt() ?? 0;
              final int leadsC = (counts['leads'] as num?)?.toInt() ?? 0;
              final int dealersC = (counts['dealers'] as num?)?.toInt() ?? 0;
              final int activeC = (counts['active'] as num?)?.toInt() ?? 0;
              final int unreadC = (counts['unread'] as num?)?.toInt() ?? 0;

              if (allC > 0 || search.isEmpty) _totalAllCount = allC;
              if (leadsC > 0 || search.isEmpty) _totalLeadsCount = leadsC;
              if (dealersC > 0 || search.isEmpty) _totalDealersCount = dealersC;
              if (activeC > 0 || search.isEmpty) _totalActiveCount = activeC;
              if (search.isEmpty) _totalUnreadCount = unreadC;
            } else if (page == 1 && search.isEmpty) {
              _totalAllCount = _conversations.length;
            }

            if (_selectedConversation != null) {
              final selId = _selectedConversation!['_id']?.toString();
              final idx = _conversations.indexWhere((c) => c['_id']?.toString() == selId);
              if (idx != -1) {
                _conversations[idx]['unreadCount'] = 0;
              }
            }
            _recalculateUnreadCount();
          });

          // Auto-select first conversation if search returned elements and nothing is selected
          if (search.isNotEmpty &&
              _conversations.isNotEmpty &&
              _selectedConversation == null) {
            _selectConversation(_conversations.first);
          }
        }
      }
    } catch (e) {
      debugPrint('[WhatsApp CRM] Error fetching conversations: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingConversations = false);
      }
    }
  }

  // API Call: On-demand Roster Sync for Leads & Dealers
  Future<void> _syncAssignedRoster() async {
    setState(() => _isSyncingRoster = true);
    try {
      final res = await ApiClient().post('/conversations/sync-roster', {});
      if (res.statusCode == 200) {
        await _fetchConversations();
        if (_selectedConversation?['_id'] != null) {
          await _fetchMessages(_selectedConversation!['_id'].toString());
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Assigned leads & dealers synchronized to WhatsApp roster!',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF008069),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[WhatsApp CRM] Error syncing roster: $e');
    } finally {
      if (mounted) setState(() => _isSyncingRoster = false);
    }
  }

  // API Call: Fetch support/sales agents list for manual assignment
  Future<void> _fetchSalesAgents() async {
    try {
      final res = await ApiClient().get('/users?role=sales');
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true) {
          setState(() {
            _salesAgents = body['data'] ?? [];
          });
        }
      }
    } catch (e) {
      debugPrint('[WhatsApp CRM] Error fetching sales agents: $e');
    }
  }

  // API Call: Fetch approved WhatsApp templates from MyOperator WABA
  Future<void> _fetchTemplates({bool forceSync = false}) async {
    setState(() => _isLoadingTemplates = true);
    try {
      final endpoint = forceSync ? '/whatsapp/templates?sync=true&status=APPROVED' : '/whatsapp/templates?status=APPROVED';
      final res = await ApiClient().get(endpoint);
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true && body['data'] != null) {
          final list = List<dynamic>.from(body['data']);
          setState(() {
            _approvedTemplates = list.where((t) {
              final s = (t['status'] ?? t['waba_template_status'] ?? '').toString().toUpperCase();
              return s == 'APPROVED' || s == 'ACTIVE';
            }).toList();
          });
          debugPrint('[WhatsApp CRM] Loaded ${_approvedTemplates.length} approved templates from backend.');
        }
      }
    } catch (e) {
      debugPrint('[WhatsApp CRM] Error fetching approved templates: $e');
    } finally {
      if (mounted) setState(() => _isLoadingTemplates = false);
    }
  }

  // API Call: Fetch Canned Responses / Quick Replies
  Future<void> _fetchCannedResponses() async {
    setState(() => _isLoadingCanned = true);
    try {
      final res = await ApiClient().get('/canned-responses');
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true && body['data'] != null) {
          setState(() {
            _cannedResponses = List<dynamic>.from(body['data']);
          });
        }
      }
    } catch (e) {
      debugPrint('[WhatsApp CRM] Error fetching canned responses: $e');
    } finally {
      if (mounted) setState(() => _isLoadingCanned = false);
    }
  }

  // API Call: Fetch specific messages
  Future<void> _fetchMessages(String conversationId, {int page = 1}) async {
    setState(() {
      _isLoadingMessages = true;
      _messagesPage = page;
    });
    debugPrint('[WhatsApp CRM] Fetching message page $_messagesPage');

    try {
      final res = await ApiClient().get(
        '/conversations/$conversationId/messages?page=$page&limit=30',
      );
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true) {
          setState(() {
            if (page == 1) {
              _messages = List<dynamic>.from(body['data'] ?? []);
            } else {
              final newMessages = List<dynamic>.from(body['data'] ?? []);
              for (final m in newMessages) {
                final id = m['_id']?.toString();
                if (!_messages.any((ex) => ex['_id']?.toString() == id)) {
                  _messages.add(m);
                }
              }
              // Viewport Virtualization: Keep active in-memory list bounded to latest 100 messages
              if (_messages.length > 100) {
                _messages = _messages.sublist(_messages.length - 100);
              }
            }
            _sortMessages();

            // Synchronize conversation tile preview and timestamp with the true latest message
            if (_messages.isNotEmpty) {
              final latest = _messages.last;
              final convIdx = _conversations.indexWhere((c) => c['_id']?.toString() == conversationId);
              if (convIdx != -1) {
                _conversations[convIdx]['unreadCount'] = 0;
                _conversations[convIdx]['lastMessage'] = {
                  'type': latest['type'] ?? 'text',
                  'content': latest['content'] ?? '',
                  'mediaUrl': latest['mediaUrl'],
                };
                _conversations[convIdx]['lastMessageAt'] = latest['createdAt'];
              }
              if (_selectedConversation != null && _selectedConversation!['_id']?.toString() == conversationId) {
                _selectedConversation!['unreadCount'] = 0;
                _selectedConversation!['lastMessage'] = {
                  'type': latest['type'] ?? 'text',
                  'content': latest['content'] ?? '',
                  'mediaUrl': latest['mediaUrl'],
                };
                _selectedConversation!['lastMessageAt'] = latest['createdAt'];
              }
              _recalculateUnreadCount();
              _sortConversations();
            }
          });
          if (page == 1) {
            _scrollToBottom();
          }
        }
      }
    } catch (e) {
      debugPrint('[WhatsApp CRM] Error fetching messages: $e');
    } finally {
      setState(() => _isLoadingMessages = false);
    }
  }

  // API Call: Send reply message
  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _selectedConversation == null)
      return;

    final convId = _selectedConversation?['_id']?.toString();
    if (_isCurrentlyTypingLocally && convId != null) {
      _isCurrentlyTypingLocally = false;
      _myTypingDebounceTimer?.cancel();
      WebSocketService().sendTypingStop(convId);
    }

    final content = _messageController.text.trim();
    _messageController.clear();

    final replyPayload = _replyingToMessage != null ? {
      'messageId': (_replyingToMessage['_id'] ?? _replyingToMessage['myoperatorMessageId'])?.toString(),
      'myoperatorMessageId': _replyingToMessage['myoperatorMessageId']?.toString(),
      'senderName': _replyingToMessage['direction'] == 'outgoing' ? 'You' : (_selectedConversation?['contactId']?['name'] ?? 'Lead').toString(),
      'content': _replyingToMessage['content']?.toString() ?? '',
      'mediaUrl': _replyingToMessage['mediaUrl']?.toString(),
    } : null;

    setState(() => _replyingToMessage = null);

    try {
      final res = await ApiClient().post('/messages/send', {
        'conversationId': _selectedConversation['_id'],
        'type': 'Text',
        'content': content,
        if (replyPayload != null) 'replyTo': replyPayload,
      });

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true) {
          TelephonyAudioService().playOutgoingMessageSentTone();
          final sentMsg = body['data'];
          setState(() {
            final String msgId = sentMsg['_id']?.toString() ?? '';
            final String wabaId = sentMsg['myoperatorMessageId']?.toString() ?? '';
            final idx = _messages.indexWhere((m) =>
              (msgId.isNotEmpty && m['_id']?.toString() == msgId) ||
              (wabaId.isNotEmpty && m['myoperatorMessageId']?.toString() == wabaId)
            );
            if (idx == -1) {
              _messages.add(sentMsg);
            } else {
              _messages[idx] = sentMsg;
            }
            _sortMessages();
            _scrollToBottom();

            final currentId = _selectedConversation?['_id']?.toString();
            if (currentId != null) {
              final nowIso = DateTime.now().toIso8601String();
              _selectedConversation['lastMessage'] = {
                'type': 'text',
                'content': content,
              };
              _selectedConversation['lastMessageAt'] = nowIso;
              final idx = _conversations.indexWhere((c) => c['_id']?.toString() == currentId);
              if (idx != -1) {
                _conversations.removeAt(idx);
              }
              _conversations.insert(0, _selectedConversation);
            }
          });
        } else {
          _messageController.text = content;
          _showErrorSnackBar(body['message'] ?? 'Failed to send message');
        }
      } else {
        _messageController.text = content;
        try {
          final body = jsonDecode(res.body);
          _showErrorSnackBar(
            body['message'] ?? 'Failed to send message (Server Error ${res.statusCode})',
          );
        } catch (_) {
          _showErrorSnackBar('Failed to send message (Server Error ${res.statusCode})');
        }
      }
    } catch (e) {
      _messageController.text = content;
      debugPrint('[WhatsApp CRM] Error sending message: $e');
      _showErrorSnackBar('Network error: Could not send message');
    }
  }

  // API Call: Post Internal Note
  Future<void> _addNote() async {
    if (_noteController.text.trim().isEmpty || _selectedConversation == null)
      return;

    final noteText = _noteController.text.trim();
    _noteController.clear();

    try {
      final res = await ApiClient().post('/notes', {
        'conversationId': _selectedConversation['_id'],
        'note': noteText,
      });

      if (res.statusCode == 201) {
        _fetchMessages(_selectedConversation['_id']);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.lock, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Internal note added successfully',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              backgroundColor: AppTheme.warning,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[WhatsApp CRM] Error adding note: $e');
    }
  }

  // API Call: Reassign contact agent
  Future<void> _reassignAgent(String? agentId) async {
    if (_selectedConversation == null) return;

    try {
      final res = await ApiClient().post('/conversations/assign', {
        'conversationId': _selectedConversation['_id'],
        'agentId': agentId ?? '',
      });

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true) {
          setState(() {
            _selectedConversation = body['data'];
            // Refresh conversation in sidebar list
            final index = _conversations.indexWhere(
              (c) => c['_id'] == _selectedConversation['_id'],
            );
            if (index != -1) {
              _conversations[index] = _selectedConversation;
            }
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Lead assigned successfully',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                ),
                backgroundColor: AppTheme.success,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('[WhatsApp CRM] Error assigning lead: $e');
    }
  }



  void _selectConversation(dynamic conversation) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    if (_isCurrentlyTypingLocally && _selectedConversation?['_id'] != null) {
      _isCurrentlyTypingLocally = false;
      _myTypingDebounceTimer?.cancel();
      WebSocketService().sendTypingStop(_selectedConversation!['_id'].toString());
    }
    final convId = conversation['_id']?.toString();
    setState(() {
      _selectedConversation = conversation;
      _messages = [];
      _replyingToMessage = null;
      conversation['unreadCount'] = 0;
      if (convId != null) {
        final idx = _conversations.indexWhere((c) => c['_id']?.toString() == convId);
        if (idx != -1) {
          _conversations[idx]['unreadCount'] = 0;
        }
      }
      _recalculateUnreadCount();
    });
    if (convId != null) {
      ApiClient().put('/conversations/$convId/read', {}).catchError((e) {
        debugPrint('[WhatsApp CRM] Error marking conversation as read on select: $e');
        return http.Response('{}', 500);
      });
    }
    // Fetch chat history
    _fetchMessages(conversation['_id']?.toString() ?? '');
  }

  Future<void> _markConversationAsUnread(dynamic conversation) async {
    final convId = conversation['_id']?.toString();
    if (convId == null) return;
    setState(() {
      conversation['unreadCount'] = 1;
      final idx = _conversations.indexWhere((c) => c['_id']?.toString() == convId);
      if (idx != -1) {
        _conversations[idx]['unreadCount'] = 1;
      }
      if (_selectedConversation?['_id']?.toString() == convId) {
        _selectedConversation = null;
        _messages = [];
      }
      _recalculateUnreadCount();
    });
    try {
      final res = await ApiClient().put('/conversations/$convId/unread', {});
      if (res.statusCode != 200) {
        debugPrint('[WhatsApp CRM] Mark as unread returned ${res.statusCode}');
      }
    } catch (e) {
      debugPrint('[WhatsApp CRM] Error marking conversation as unread: $e');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_messageScrollController.hasClients) {
        _messageScrollController.animateTo(
          _messageScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = Responsive.isDesktop(context);
    final double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Row(
        children: [
          // 1. Left Sidebar
          Container(
            width: isDesktop ? 380 : screenWidth * 0.4,
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                right: BorderSide(color: Color(0xFFE9ECEF), width: 1),
              ),
            ),
            child: _buildSidebar(),
          ),

          // 2. Right Main Chat Pane
          Expanded(
            child: _selectedConversation == null
                ? _buildEmptyState()
                : _buildChatConsole(),
          ),
        ],
      ),
    );
  }

  // Sidebar List Builder
  Widget _buildSidebar() {
    return Column(
      children: [
        // Top Toolbar (Pure White Background)
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: const Color(
                          0xFF008069,
                        ).withValues(alpha: 0.12),
                        radius: 18,
                        child: const Icon(
                          Icons.chat_rounded,
                          color: Color(0xFF008069),
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Conversations',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF111B21),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: (_isLoadingConversations || _isSyncingRoster)
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF008069),
                            ),
                          )
                        : const Icon(
                            Icons.refresh_rounded,
                            color: Color(0xFF008069),
                            size: 20,
                          ),
                    onPressed: (_isLoadingConversations || _isSyncingRoster)
                        ? null
                        : () {
                            _fetchConversations();
                            _syncAssignedRoster();
                          },
                    tooltip: 'Refresh & Sync Roster',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              StreamBuilder<bool>(
                stream: WebSocketService().connectionStatus,
                initialData: WebSocketService().connectionStatusNow,
                builder: (context, snapshot) {
                  final isConnected = snapshot.data ?? false;
                  return Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isConnected ? Colors.green : Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isConnected
                            ? 'Real-time Sync: Active'
                            : 'Real-time Sync: Offline (Refresh)',
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isConnected
                              ? Colors.green[700]
                              : Colors.red[700],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),

        // Search Bar (Pristine White Modern Style with Live Debounced Filter)
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              textAlignVertical: TextAlignVertical.center,
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: const Color(0xFF111B21),
              ),
              onChanged: (val) {
                setState(() {});
                _onSearchChanged(val);
              },
              decoration: InputDecoration(
                hintText: 'Search leads, dealers, phone numbers...',
                hintStyle: GoogleFonts.outfit(
                  fontSize: 12.5,
                  color: const Color(0xFF94A3B8),
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  size: 19,
                  color: Color(0xFF008069),
                ),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 38,
                  minHeight: 38,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: Color(0xFF64748B),
                        ),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                          _fetchConversations();
                        },
                      )
                    : null,
                suffixIconConstraints: const BoxConstraints(
                  minWidth: 38,
                  minHeight: 38,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                border: InputBorder.none,
                isDense: true,
              ),
              onSubmitted: (value) => _fetchConversations(search: value.trim()),
            ),
          ),
        ),

        // Filters bar (All filters visible simultaneously without scrolling)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          color: Colors.white,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Row 1: Primary Audience Segmentation
              Row(
                children: [
                  Expanded(
                    child: _buildTabFilter('all', 'All (${_totalAllCount > 0 ? _totalAllCount : _conversations.length})'),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _buildTabFilter('leads', '🌱 Leads ($_totalLeadsCount)'),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _buildTabFilter('dealers', '🏪 Dealers ($_totalDealersCount)'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // Row 2: Status & Priority Filters
              Row(
                children: [
                  Expanded(
                    child: _buildTabFilter('active', '⚡ Active ($_totalActiveCount)'),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _buildTabFilter('unread', '🔔 Unread ($_totalUnreadCount)'),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _buildStatusFilterTab('closed', '✅ Closed'),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _buildStatusFilterTab('snoozed', '⏳ Snoozed'),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (_isLoadingConversations)
          const LinearProgressIndicator(
            minHeight: 2,
            backgroundColor: Color(0xFFE2E8F0),
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF008069)),
          ),
        const Divider(height: 1, color: Color(0xFFF1F5F9)),

        // Scroll list
        Expanded(
          child: _isLoadingConversations && _conversations.isEmpty
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF008069)),
                )
              : _conversations.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox_outlined, size: 36, color: Colors.grey[400]),
                      const SizedBox(height: 8),
                      Text(
                        'No conversations in this view',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF667781),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton.icon(
                        icon: const Icon(Icons.sync_rounded, size: 16),
                        label: Text('Sync Assigned Contacts', style: GoogleFonts.outfit(fontSize: 12)),
                        onPressed: _syncAssignedRoster,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  addAutomaticKeepAlives: false,
                  addRepaintBoundaries: true,
                  physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
                  itemCount: _conversations.length,
                  itemBuilder: (context, index) {
                    final conv = _conversations[index];
                    final contact = conv['contactId'] ?? {};
                    final lastMsg = conv['lastMessage'] ?? {};
                    final convIdStr = (conv['_id'] ?? '').toString();
                    final isSelected =
                        _selectedConversation != null &&
                        _selectedConversation!['_id']?.toString() == convIdStr;
                    final int rawUnread = conv['unreadCount'] is int
                        ? conv['unreadCount'] as int
                        : (int.tryParse(conv['unreadCount']?.toString() ?? '0') ?? 0);
                    final int unreadCount = isSelected ? 0 : rawUnread;

                    String formattedTime = '';
                    if (conv['lastMessageAt'] != null) {
                      try {
                        final date = DateTime.parse(
                          conv['lastMessageAt'].toString(),
                        ).toLocal();
                        formattedTime = DateFormat('hh:mm a').format(date);
                      } catch (_) {}
                    }

                    final String name = (contact['name'] ?? 'WhatsApp User').toString();
                    final Color avatarColor = _getAvatarColor(name);

                    // Determine Lead vs Dealer from tags
                    final List<dynamic> tags = List<dynamic>.from(contact['tags'] ?? []);
                    final bool isDealer = tags.any((t) =>
                        t.toString().toLowerCase().contains('dealer') ||
                        t.toString().toLowerCase().contains('retailer'));

                    final assignedTo = conv['assignedTo'];
                    String assignedAgentName = '';
                    if (assignedTo is Map) {
                      final fn = (assignedTo['firstName'] ?? '').toString();
                      final ln = (assignedTo['lastName'] ?? '').toString();
                      final full = '$fn $ln'.trim();
                      if (full.isNotEmpty) assignedAgentName = full;
                    } else if (assignedTo is String && assignedTo.isNotEmpty) {
                      final agent = _salesAgents.firstWhere((a) => a['_id'] == assignedTo, orElse: () => null);
                      if (agent != null) {
                        final fn = (agent['firstName'] ?? '').toString();
                        final ln = (agent['lastName'] ?? '').toString();
                        final full = '$fn $ln'.trim();
                        if (full.isNotEmpty) assignedAgentName = full;
                      }
                    }

                    final String lastText = (lastMsg['content'] ?? '').toString().trim();
                    final String lastMedia = (lastMsg['mediaUrl'] ?? '').toString().trim();
                    final bool hasNoMessages = lastText.isEmpty && lastMedia.isEmpty && lastMsg['type'] == null;

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => _selectConversation(conv),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFFF0F2F5)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              // Circle initials with dynamic colors
                              CircleAvatar(
                                backgroundColor: avatarColor.withValues(
                                  alpha: 0.15,
                                ),
                                radius: 20,
                                child: Text(
                                  name.isNotEmpty
                                      ? name.substring(0, 1).toUpperCase()
                                      : '👤',
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: avatarColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Details block
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  name,
                                                  style: GoogleFonts.outfit(
                                                    fontWeight: unreadCount > 0 ? FontWeight.w700 : FontWeight.w600,
                                                    fontSize: 13.5,
                                                    color: const Color(0xFF111B21),
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: 5),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 5,
                                                  vertical: 1.5,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: isDealer
                                                      ? const Color(0xFF0284C7).withValues(alpha: 0.12)
                                                      : const Color(0xFF16A34A).withValues(alpha: 0.12),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  isDealer ? '🏪 Dealer' : '🌱 Lead',
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 9.5,
                                                    fontWeight: FontWeight.bold,
                                                    color: isDealer
                                                        ? const Color(0xFF0284C7)
                                                        : const Color(0xFF16A34A),
                                                  ),
                                                ),
                                              ),
                                              if (assignedAgentName.isNotEmpty) ...[
                                                const SizedBox(width: 4),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFF008069).withValues(alpha: 0.08),
                                                    borderRadius: BorderRadius.circular(4),
                                                    border: Border.all(color: const Color(0xFF008069).withValues(alpha: 0.2), width: 0.6),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      const Icon(Icons.person_outline_rounded, size: 9.5, color: Color(0xFF008069)),
                                                      const SizedBox(width: 2.5),
                                                      Text(
                                                        assignedAgentName,
                                                        style: GoogleFonts.outfit(
                                                          fontSize: 9,
                                                          fontWeight: FontWeight.bold,
                                                          color: const Color(0xFF008069),
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ] else if (AuthService().currentUserRole == UserRole.admin) ...[
                                                const SizedBox(width: 4),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFFFFBEB),
                                                    borderRadius: BorderRadius.circular(4),
                                                    border: Border.all(color: const Color(0xFFFCD34D), width: 0.6),
                                                  ),
                                                  child: Text(
                                                    'Unassigned',
                                                    style: GoogleFonts.outfit(
                                                      fontSize: 8.5,
                                                      fontWeight: FontWeight.w600,
                                                      color: const Color(0xFFB45309),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        Text(
                                          formattedTime,
                                          style: GoogleFonts.outfit(
                                            fontSize: 10,
                                            color: unreadCount > 0
                                                ? const Color(0xFF00A884)
                                                : const Color(0xFF667781),
                                            fontWeight: unreadCount > 0
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Builder(
                                            builder: (context) {
                                              final String convIdStr = (conv['_id'] ?? '').toString();
                                              final bool isOtherAgentTyping = _activeTypingAgents.containsKey(convIdStr);
                                              final String typingAgentName = _activeTypingAgents[convIdStr]?['agentName'] ?? 'Agent';

                                              if (isOtherAgentTyping) {
                                                return Text(
                                                  '✍️ $typingAgentName is typing...',
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 11.5,
                                                    fontStyle: FontStyle.italic,
                                                    color: const Color(0xFF008069),
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                );
                                              }

                                              final cleanLast = _formatCleanMessageText(lastText);
                                              final displaySnippet = hasNoMessages
                                                  ? '✨ Ready for Outreach'
                                                  : (cleanLast.isNotEmpty
                                                      ? cleanLast
                                                      : (lastMedia.isNotEmpty ? '📷 Media Attachment' : ''));

                                              return Text(
                                                displaySnippet,
                                                style: GoogleFonts.outfit(
                                                  fontSize: 11.5,
                                                  fontStyle: hasNoMessages ? FontStyle.italic : FontStyle.normal,
                                                  color: hasNoMessages
                                                      ? const Color(0xFF008069)
                                                      : (unreadCount > 0 ? const Color(0xFF111B21) : const Color(0xFF667781)),
                                                  fontWeight: (hasNoMessages || unreadCount > 0) ? FontWeight.w600 : FontWeight.normal,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              );
                                            },
                                          ),
                                        ),
                                        if (unreadCount > 0)
                                          Container(
                                            constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 5.5,
                                              vertical: 2,
                                            ),
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF00A884),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Text(
                                              unreadCount > 99 ? '99+' : '$unreadCount',
                                              style: GoogleFonts.outfit(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
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
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildTabFilter(String tab, String label) {
    final bool isSelected = _selectedTab == tab && _selectedStatus != 'closed' && _selectedStatus != 'snoozed';
    return InkWell(
      onTap: () {
        setState(() {
          _selectedTab = tab;
          _selectedStatus = 'all';
          _selectedConversation = null;
        });
        _fetchConversations();
      },
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5.5),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF008069).withValues(alpha: 0.12) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF008069)
                : const Color(0xFFE2E8F0),
            width: isSelected ? 1.2 : 1.0,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.outfit(
            fontSize: 10.5,
            color: isSelected
                ? const Color(0xFF008069)
                : const Color(0xFF64748B),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusFilterTab(String status, String label) {
    final bool isSelected = _selectedStatus == status;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedStatus = status;
          _selectedConversation = null;
        });
        _fetchConversations();
      },
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5.5),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF008069).withValues(alpha: 0.12) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF008069)
                : const Color(0xFFE2E8F0),
            width: isSelected ? 1.2 : 1.0,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.outfit(
            fontSize: 10.5,
            color: isSelected
                ? const Color(0xFF008069)
                : const Color(0xFF64748B),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // Right Chat Console
  Widget _buildChatConsole() {
    final contact = _selectedConversation['contactId'] ?? {};
    final assignedTo = _selectedConversation['assignedTo'] ?? contact['assignedTo'];
    final role = AuthService().currentUserRole;

    String? assignedId;
    String assignedAgentName = '';

    if (assignedTo is Map) {
      assignedId = assignedTo['_id']?.toString();
      final fn = (assignedTo['firstName'] ?? '').toString();
      final ln = (assignedTo['lastName'] ?? '').toString();
      final full = '$fn $ln'.trim();
      if (full.isNotEmpty) assignedAgentName = full;
    } else if (assignedTo is String && assignedTo.isNotEmpty) {
      assignedId = assignedTo;
      final agent = _salesAgents.firstWhere(
        (a) => a['_id']?.toString() == assignedId,
        orElse: () => null,
      );
      if (agent != null) {
        final fn = (agent['firstName'] ?? '').toString();
        final ln = (agent['lastName'] ?? '').toString();
        final full = '$fn $ln'.trim();
        if (full.isNotEmpty) assignedAgentName = full;
      }
    }
    if (assignedAgentName.isEmpty && assignedId != null && assignedId.isNotEmpty) {
      final agent = _salesAgents.firstWhere(
        (a) => a['_id']?.toString() == assignedId,
        orElse: () => null,
      );
      if (agent != null) {
        final fn = (agent['firstName'] ?? '').toString();
        final ln = (agent['lastName'] ?? '').toString();
        final full = '$fn $ln'.trim();
        if (full.isNotEmpty) assignedAgentName = full;
      }
    }
    if (assignedAgentName.isEmpty) assignedAgentName = 'Unassigned';

    final String name = contact['name'] ?? 'WhatsApp User';
    final Color avatarColor = _getAvatarColor(name);

    return Container(
      color: const Color(0xFFFAFAFC), // Modern clean off-white background
      child: Column(
        children: [
          // WhatsApp Web Header (Pristine White)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1),
              ),
            ),
            child: _isSearchingMessages
                ? Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: Color(0xFF54656F),
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() {
                            _isSearchingMessages = false;
                            _messageSearchQuery = '';
                            _messageSearchController.clear();
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _messageSearchController,
                          textAlignVertical: TextAlignVertical.center,
                          autofocus: true,
                          decoration: InputDecoration(
                            hintText: 'Search messages in this chat...',
                            hintStyle: GoogleFonts.outfit(
                              fontSize: 13,
                              color: const Color(0xFF64748B),
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 8,
                            ),
                          ),
                          style: GoogleFonts.outfit(
                            fontSize: 13.5,
                            color: const Color(0xFF111B21),
                          ),
                          onChanged: (val) {
                            setState(() {
                              _messageSearchQuery = val.trim();
                            });
                          },
                        ),
                      ),
                      if (_messageSearchQuery.isNotEmpty)
                        IconButton(
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Color(0xFF54656F),
                            size: 18,
                          ),
                          onPressed: () {
                            setState(() {
                              _messageSearchQuery = '';
                              _messageSearchController.clear();
                            });
                          },
                        ),
                    ],
                  )
                : Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: avatarColor.withValues(alpha: 0.15),
                        radius: 19,
                        child: Text(
                          name.isNotEmpty
                              ? name.substring(0, 1).toUpperCase()
                              : '👤',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 14.5,
                            color: avatarColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: 14.5,
                                color: const Color(0xFF111B21),
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              '+91 ${_normalizePhone(contact['phone']?.toString() ?? '')}',
                              style: GoogleFonts.outfit(
                                fontSize: 11.5,
                                color: const Color(0xFF667781),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Clean Assigned Sales Agent Chip
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: assignedAgentName != 'Unassigned'
                              ? const Color(0xFF008069).withValues(alpha: 0.08)
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: assignedAgentName != 'Unassigned'
                                ? const Color(0xFF008069).withValues(alpha: 0.25)
                                : const Color(0xFFE2E8F0),
                            width: 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.person_pin_circle_rounded,
                              size: 14,
                              color: assignedAgentName != 'Unassigned'
                                  ? const Color(0xFF008069)
                                  : const Color(0xFF64748B),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Agent: ',
                              style: GoogleFonts.outfit(
                                fontSize: 11.5,
                                color: const Color(0xFF64748B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              assignedAgentName,
                              style: GoogleFonts.outfit(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: assignedAgentName != 'Unassigned'
                                    ? const Color(0xFF008069)
                                    : const Color(0xFF1E293B),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 8),

                      // ⚡ Canned Messages Button
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF008069),
                          side: const BorderSide(color: Color(0xFF008069), width: 1.0),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.bolt_rounded, size: 14),
                        label: Text(
                          'Canned',
                          style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () => _showCannedResponsesDialog(context),
                      ),
                      const SizedBox(width: 8),

                      // 📋 WhatsApp Templates & Approvals Button
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF1E293B),
                          side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.0),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.assignment_outlined, size: 14),
                        label: Text(
                          'Templates',
                          style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () => _showTemplatesManagerDialog(context),
                      ),
                      const SizedBox(width: 8),

                      // 📞 Customer Call History & MyOperator Recordings Drawer Button
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0284C7),
                          backgroundColor: const Color(0xFFF0F9FF),
                          side: const BorderSide(color: Color(0xFFBAE6FD), width: 1.0),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.phone_in_talk_rounded, size: 14, color: Color(0xFF0284C7)),
                        label: Text(
                          'Call Logs',
                          style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.bold, color: const Color(0xFF0284C7)),
                        ),
                        onPressed: () {
                          final contact = _selectedConversation?['contactId'] ?? {};
                          final String phone = (contact['phone'] ?? '').toString();
                          final String name = (contact['name'] ?? 'Customer').toString();
                          if (phone.isNotEmpty) {
                            _showCustomerCallHistoryDrawer(context, phone, name);
                          }
                        },
                      ),
                      const SizedBox(width: 6),

                      // 🔍 In-Chat Message Search
                      IconButton(
                        icon: const Icon(
                          Icons.search_rounded,
                          color: Color(0xFF54656F),
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() {
                            _isSearchingMessages = true;
                          });
                        },
                        tooltip: 'Search messages in this chat',
                      ),
                      const SizedBox(width: 2),

                      // ⋯ Single Clean Conversation Options Menu (Status controls)
                      PopupMenuButton<String>(
                        icon: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: const Icon(Icons.more_vert_rounded, size: 16, color: Color(0xFF475569)),
                        ),
                        tooltip: 'Conversation Status',
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 4,
                        color: Colors.white,
                        onSelected: (val) {
                          if (val.startsWith('status_')) {
                            final newStatus = val.replaceFirst('status_', '');
                            _updateConversationStatus(newStatus);
                          }
                        },
                        itemBuilder: (context) {
                          final currentStatus = (_selectedConversation?['status'] ?? 'open').toString().toLowerCase();
                          return [
                            PopupMenuItem(
                              value: currentStatus == 'open' ? 'status_closed' : 'status_open',
                              child: Row(
                                children: [
                                  Icon(
                                    currentStatus == 'open' ? Icons.check_circle_outline_rounded : Icons.lock_open_rounded,
                                    size: 15,
                                    color: currentStatus == 'open' ? const Color(0xFFD97706) : const Color(0xFF008069),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    currentStatus == 'open' ? 'Mark Resolved / Closed' : 'Reopen Conversation',
                                    style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'status_snoozed',
                              child: Row(
                                children: [
                                  const Icon(Icons.snooze_rounded, size: 15, color: Color(0xFF64748B)),
                                  const SizedBox(width: 10),
                                  Text('Mark as Snoozed', style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.w500)),
                                ],
                              ),
                            ),
                          ];
                        },
                      ),
                    ],
                  ),
          ),

          // 🕒 Meta 24-Hour Messaging Window Indicator
          _buildMeta24HourWindowBanner(),

          // Message log thread
          Expanded(
            child: Container(
              color: const Color(0xFFEFEAE2),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Opacity(
                      opacity: 0.45,
                      child: Image.asset(
                        'assets/images/whatsapp_bg.png',
                        repeat: ImageRepeat.repeat,
                        alignment: Alignment.topLeft,
                        errorBuilder: (context, error, stackTrace) => const CustomPaint(
                          painter: WhatsAppDoodlePainter(
                            color: Color(0x0E000000),
                          ),
                        ),
                      ),
                    ),
                  ),
                  _isLoadingMessages && _messages.isEmpty
                      ? const Center(
                          child: CircularProgressIndicator(color: Color(0xFF008069)),
                        )
                      : () {
                          final filteredMessages = _messages.where((m) {
                            final content = (m['content'] ?? '')
                                .toString()
                                .toLowerCase();
                            return content.contains(
                              _messageSearchQuery.toLowerCase(),
                            );
                          }).toList();

                          if (filteredMessages.isEmpty) {
                            if (_messageSearchQuery.isNotEmpty) {
                              return Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4),
                                    ],
                                  ),
                                  child: Text(
                                    'No matching messages found',
                                    style: GoogleFonts.outfit(
                                      color: Colors.grey[600],
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              );
                            }

                            final contact = _selectedConversation?['contactId'] ?? {};
                            final String customerName = (contact['name'] ?? 'Customer').toString();
                            final String customerPhone = (contact['phone'] ?? '').toString();
                            final List<dynamic> tags = List<dynamic>.from(contact['tags'] ?? []);
                            final bool isDealer = tags.any((t) =>
                                t.toString().toLowerCase().contains('dealer') ||
                                t.toString().toLowerCase().contains('retailer'));

                            return Center(
                              child: Container(
                                width: 480,
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.06),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF008069).withValues(alpha: 0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.mark_chat_unread_rounded,
                                        size: 32,
                                        color: Color(0xFF008069),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      customerName,
                                      style: GoogleFonts.outfit(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          customerPhone,
                                          style: GoogleFonts.outfit(
                                            fontSize: 13,
                                            color: const Color(0xFF64748B),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: isDealer
                                                ? const Color(0xFF0284C7).withValues(alpha: 0.12)
                                                : const Color(0xFF16A34A).withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            isDealer ? '🏪 Verified Dealer' : '🌱 Assigned Lead',
                                            style: GoogleFonts.outfit(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.bold,
                                              color: isDealer ? const Color(0xFF0284C7) : const Color(0xFF16A34A),
                                            ),
                                          ),
                                        ),
                                        if (assignedAgentName != 'Unassigned') ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF008069).withValues(alpha: 0.08),
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: const Color(0xFF008069).withValues(alpha: 0.2), width: 0.6),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.person_outline_rounded, size: 11, color: Color(0xFF008069)),
                                                const SizedBox(width: 3),
                                                Text(
                                                  assignedAgentName,
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.bold,
                                                    color: const Color(0xFF008069),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: const Color(0xFFE2E8F0)),
                                      ),
                                      child: Text(
                                        '💬 No prior chat history with this contact. Under Meta WhatsApp policies, choose an Approved Template below to start the conversation.',
                                        style: GoogleFonts.outfit(
                                          fontSize: 12,
                                          color: const Color(0xFF475569),
                                          height: 1.4,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF008069),
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      icon: const Icon(Icons.send_rounded, size: 14),
                                      label: Text('Send WhatsApp Template', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold)),
                                      onPressed: () => _showSendTemplateDialog(context, _selectedConversation['_id']),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }

                          return SelectionArea(
                            child: ListView.builder(
                              controller: _messageScrollController,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 16,
                              ),
                              itemCount: filteredMessages.length,
                              itemBuilder: (context, index) {
                                final msg = filteredMessages[index];
                                final isOutgoing = msg['direction'] == 'outgoing';
                                final type = msg['type'];
                                final isNote = msg['isNote'] == true;

                                final date = DateTime.parse(
                                  msg['createdAt'],
                                ).toLocal();
                                final formattedTime = DateFormat(
                                  'hh:mm a',
                                ).format(date);

                                BoxDecoration bubbleDecoration;
                                Color textCol = const Color(0xFF111B21);

                                if (isNote) {
                                  bubbleDecoration = BoxDecoration(
                                    color: const Color(0xFFFFF9E6),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: const Color(0xFFFFE082),
                                      width: 0.8,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.04),
                                        blurRadius: 2,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  );
                                  textCol = const Color(0xFF5D4037);
                                } else if (isOutgoing) {
                                  bubbleDecoration = BoxDecoration(
                                    color: const Color(0xFFD9FDD3), // Official WhatsApp light green
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(8),
                                      bottomLeft: Radius.circular(8),
                                      bottomRight: Radius.circular(8),
                                      topRight: Radius.circular(2),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.06),
                                        blurRadius: 2,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  );
                                } else {
                                  bubbleDecoration = BoxDecoration(
                                    color: Colors.white, // Official WhatsApp white
                                    borderRadius: const BorderRadius.only(
                                      topRight: Radius.circular(8),
                                      bottomLeft: Radius.circular(8),
                                      bottomRight: Radius.circular(8),
                                      topLeft: Radius.circular(2),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.06),
                                        blurRadius: 2,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  );
                                }

                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 3.0),
                                  child: Align(
                                    alignment: isOutgoing
                                        ? Alignment.centerRight
                                        : Alignment.centerLeft,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: bubbleDecoration,
                                      constraints: BoxConstraints(
                                        maxWidth: MediaQuery.of(context).size.width * 0.45,
                                      ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isNote)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 4.0,
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                  Icons.lock_outline_rounded,
                                                  size: 10,
                                                  color: Colors.orange,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'INTERNAL NOTE',
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 8.5,
                                                    fontWeight: FontWeight.w800,
                                                    color: Colors.orange[800],
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            if (msg['sentBy'] != null &&
                                                msg['sentBy'] is Map)
                                              Text(
                                                '${msg['sentBy']['firstName'] ?? ''} ${msg['sentBy']['lastName'] ?? ''}'
                                                    .trim()
                                                    .toUpperCase(),
                                                style: GoogleFonts.outfit(
                                                  fontSize: 8.5,
                                                  fontWeight: FontWeight.w800,
                                                  color: Colors.orange[800],
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    if (!isNote &&
                                        isOutgoing &&
                                        msg['sentBy'] != null &&
                                        msg['sentBy'] is Map)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 4.0,
                                        ),
                                        child: Text(
                                          '${msg['sentBy']['firstName'] ?? ''} ${msg['sentBy']['lastName'] ?? ''}'
                                              .trim()
                                              .toUpperCase(),
                                          style: GoogleFonts.outfit(
                                            fontSize: 8.5,
                                            fontWeight: FontWeight.w800,
                                            color: const Color(0xFF008069),
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                    if (msg['mediaUrl'] != null &&
                                        msg['mediaUrl']
                                            .toString()
                                            .trim()
                                            .isNotEmpty) ...[
                                      if (msg['mediaUrl']
                                              .toString()
                                              .toLowerCase()
                                              .contains('.png') ||
                                          msg['mediaUrl']
                                              .toString()
                                              .toLowerCase()
                                              .contains('.jpg') ||
                                          msg['mediaUrl']
                                              .toString()
                                              .toLowerCase()
                                              .contains('.jpeg') ||
                                          msg['mediaUrl']
                                              .toString()
                                              .toLowerCase()
                                              .contains('.webp') ||
                                          type == 'image')
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 6.0,
                                          ),
                                          child: InkWell(
                                            onTap: () async {
                                              final url = Uri.tryParse(
                                                msg['mediaUrl'].toString(),
                                              );
                                              if (url != null &&
                                                  await canLaunchUrl(url)) {
                                                await launchUrl(
                                                  url,
                                                  mode: LaunchMode
                                                      .externalApplication,
                                                );
                                              }
                                            },
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              child: Image.network(
                                                msg['mediaUrl'],
                                                fit: BoxFit.cover,
                                                height: 180,
                                                width: double.infinity,
                                                errorBuilder:
                                                    (
                                                      context,
                                                      error,
                                                      stackTrace,
                                                    ) => const SizedBox(),
                                              ),
                                            ),
                                          ),
                                        )
                                      else
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 6.0,
                                          ),
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                            onTap: () async {
                                              final url = Uri.tryParse(
                                                msg['mediaUrl'].toString(),
                                              );
                                              if (url != null &&
                                                  await canLaunchUrl(url)) {
                                                await launchUrl(
                                                  url,
                                                  mode: LaunchMode
                                                      .externalApplication,
                                                );
                                              }
                                            },
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 8,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withValues(
                                                  alpha: 0.05,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                border: Border.all(
                                                  color: Colors.black
                                                      .withValues(alpha: 0.08),
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(
                                                    Icons.description_rounded,
                                                    color: Color(0xFF008069),
                                                    size: 20,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Flexible(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          'Attachment (Tap to view)',
                                                          style:
                                                              GoogleFonts.outfit(
                                                                fontSize: 12,
                                                                color:
                                                                    const Color(
                                                                      0xFF008069,
                                                                    ),
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                              ),
                                                        ),
                                                        Text(
                                                          msg['mediaUrl']
                                                              .toString()
                                                              .split('/')
                                                              .last
                                                              .split('?')
                                                              .first,
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style:
                                                              GoogleFonts.outfit(
                                                                fontSize: 10,
                                                                color: Colors
                                                                    .grey[700],
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  const Icon(
                                                    Icons.open_in_new_rounded,
                                                    color: Color(0xFF008069),
                                                    size: 15,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                    if (msg['replyTo'] != null &&
                                        (msg['replyTo']['content'] != null ||
                                         msg['replyTo']['body'] != null ||
                                         msg['replyTo']['mediaUrl'] != null)) ...[
                                      () {
                                        final replyMediaUrl = (msg['replyTo']['mediaUrl'] ?? '').toString().trim();
                                        final rawReplyText = (msg['replyTo']['content'] ?? msg['replyTo']['body'] ?? '').toString();
                                        final cleanReplyText = _formatCleanMessageText(rawReplyText);
                                        final isImageReply = replyMediaUrl.isNotEmpty && (replyMediaUrl.contains('.jpg') || replyMediaUrl.contains('.jpeg') || replyMediaUrl.contains('.png') || replyMediaUrl.contains('.webp'));
                                        final isDocReply = replyMediaUrl.isNotEmpty && !isImageReply;
                                        final displayReplyContent = cleanReplyText.isNotEmpty
                                            ? cleanReplyText
                                            : (isImageReply ? '📷 Photo' : (isDocReply ? '📄 Document' : ''));

                                        return Container(
                                          margin: const EdgeInsets.only(bottom: 6),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(
                                              alpha: isOutgoing ? 0.06 : 0.05,
                                            ),
                                            borderRadius: BorderRadius.circular(6),
                                            border: const Border(
                                              left: BorderSide(
                                                color: Color(0xFF008069),
                                                width: 3.5,
                                              ),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (isImageReply) ...[
                                                ClipRRect(
                                                  borderRadius: BorderRadius.circular(4),
                                                  child: Image.network(
                                                    replyMediaUrl,
                                                    width: 32,
                                                    height: 32,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (_, __, ___) => const Icon(Icons.image_outlined, size: 20, color: Color(0xFF008069)),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                              ] else if (isDocReply) ...[
                                                const Icon(Icons.description_rounded, size: 22, color: Color(0xFF008069)),
                                                const SizedBox(width: 6),
                                              ],
                                              Flexible(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      (msg['replyTo']['senderName'] ?? (isOutgoing ? 'Lead' : 'You')).toString(),
                                                      style: GoogleFonts.outfit(
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.bold,
                                                        color: const Color(0xFF008069),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      displayReplyContent,
                                                      maxLines: 2,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: GoogleFonts.outfit(
                                                        fontSize: 11.5,
                                                        color: const Color(0xFF54656F),
                                                        height: 1.2,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }(),
                                    ],
                                    if (_formatCleanMessageText(msg['content'] ?? '').isNotEmpty)
                                      Text(
                                        _formatCleanMessageText(
                                          msg['content'] ?? '',
                                        ),
                                        style: GoogleFonts.outfit(
                                          fontSize: 13,
                                          color: textCol,
                                          height: 1.25,
                                        ),
                                      ),
                                    const SizedBox(height: 3),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        InkWell(
                                          onTap: () => setState(() => _replyingToMessage = msg),
                                          child: const Padding(
                                            padding: EdgeInsets.only(right: 4.0),
                                            child: Icon(
                                              Icons.reply_rounded,
                                              size: 13,
                                              color: Color(0xFF667781),
                                            ),
                                          ),
                                        ),
                                        Text(
                                          formattedTime,
                                          style: GoogleFonts.outfit(
                                            fontSize: 8.5,
                                            color: const Color(0xFF667781),
                                          ),
                                        ),
                                        if (isOutgoing && !isNote) ...[
                                          const SizedBox(width: 3),
                                          _buildMessageStatusIcon(
                                            msg['status'] ?? 'sent',
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  }(),
                  ],
                ),
              ),
            ),

          // ─── Real-Time Agent Typing Collision Indicator ─────────────────────────
          if (_selectedConversation != null &&
              _activeTypingAgents.containsKey((_selectedConversation!['_id'] ?? '').toString()))
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              decoration: const BoxDecoration(
                color: Color(0xFFF0FDF4),
                border: Border(
                  top: BorderSide(color: Color(0xFFDCFCE7), width: 1),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF00A884),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '✍️ ${_activeTypingAgents[(_selectedConversation!['_id'] ?? '').toString()]!['agentName']} is typing a response...',
                    style: GoogleFonts.outfit(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF008069),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),

          // ─── Quoted Reply Banner (WhatsApp Web Native Preview) ──────────────────
          if (_replyingToMessage != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: const BoxDecoration(
                color: Color(0xFFF0F2F5),
                border: Border(
                  top: BorderSide(color: Color(0xFFE9EDEF), width: 1),
                ),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: const Border(
                    left: BorderSide(color: Color(0xFF008069), width: 4),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    () {
                      final mediaUrl = (_replyingToMessage['mediaUrl'] ?? '').toString();
                      final isImg = mediaUrl.isNotEmpty && (mediaUrl.contains('.jpg') || mediaUrl.contains('.jpeg') || mediaUrl.contains('.png') || mediaUrl.contains('.webp'));
                      final isDoc = mediaUrl.isNotEmpty && !isImg;
                      if (isImg) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.network(
                              mediaUrl,
                              width: 36,
                              height: 36,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(Icons.image_outlined, size: 24, color: Color(0xFF008069)),
                            ),
                          ),
                        );
                      }
                      if (isDoc) {
                        return const Padding(
                          padding: EdgeInsets.only(right: 8.0),
                          child: Icon(Icons.description_rounded, size: 24, color: Color(0xFF008069)),
                        );
                      }
                      return const SizedBox.shrink();
                    }(),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _replyingToMessage['direction'] == 'outgoing'
                                ? 'You'
                                : (_selectedConversation?['contactId']?['name'] ?? 'Lead').toString(),
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF008069),
                            ),
                          ),
                          const SizedBox(height: 2),
                          () {
                            final raw = (_replyingToMessage['content'] ?? '').toString();
                            final cleaned = _formatCleanMessageText(raw);
                            final mediaUrl = (_replyingToMessage['mediaUrl'] ?? '').toString();
                            final isImg = mediaUrl.isNotEmpty && (mediaUrl.contains('.jpg') || mediaUrl.contains('.jpeg') || mediaUrl.contains('.png') || mediaUrl.contains('.webp'));
                            final snippet = cleaned.isNotEmpty
                                ? cleaned
                                : (isImg ? '📷 Photo' : (mediaUrl.isNotEmpty ? '📄 Document' : 'Message'));

                            return Text(
                              snippet,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                color: const Color(0xFF64748B),
                              ),
                            );
                          }(),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF64748B)),
                      tooltip: 'Cancel Reply',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      onPressed: () => setState(() => _replyingToMessage = null),
                    ),
                  ],
                ),
              ),
            ),

          // ─── Slash Command (/) Autocomplete Dropdown ────────────────────────────
          if (_activeSlashMatches.isNotEmpty)
            Container(
              constraints: const BoxConstraints(maxHeight: 190),
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: _activeSlashMatches.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  itemBuilder: (context, index) {
                    final item = _activeSlashMatches[index];
                    final shortcut = item['shortcut'] ?? '';
                    final title = item['title'] ?? 'Quick Reply';
                    final rawMsg = item['message'] ?? '';
                    final interpolated = _interpolateCannedMessage(rawMsg);

                    return InkWell(
                      onTap: () {
                        setState(() {
                          _messageController.text = interpolated;
                          _messageController.selection = TextSelection.fromPosition(
                            TextPosition(offset: _messageController.text.length),
                          );
                          _activeSlashMatches = [];
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF008069).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                shortcut,
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF008069),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              title,
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                interpolated,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

          // ─── Real WhatsApp Web Input Footer (~52px Compact) ──────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: const BoxDecoration(
              color: Color(0xFFF0F2F5),
              border: Border(
                top: BorderSide(color: Color(0xFFE9EDEF), width: 1.0),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // 1. Paperclip Attach Button (Direct OS File Attachment)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Material(
                    color: Colors.transparent,
                    shape: const CircleBorder(),
                    child: Tooltip(
                      message: 'Attach file from computer',
                      child: InkWell(
                        onTap: () => _pickAndAttachFileFromSystem(context),
                        borderRadius: BorderRadius.circular(20),
                        hoverColor: const Color(0xFFDFE5E7),
                        child: Container(
                          width: 38,
                          height: 38,
                          alignment: Alignment.center,
                          child: Transform.rotate(
                            angle: -math.pi / 4, // Iconic 45° tilt
                            child: const Icon(
                              Icons.attach_file_rounded,
                              color: Color(0xFF54656F),
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 2),

                // 2. Emoji Picker Button (Pixel-perfect aligned with paperclip)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Tooltip(
                    message: 'Emoji & Reactions',
                    child: PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      splashRadius: 20,
                      elevation: 16,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      color: Colors.white,
                      surfaceTintColor: Colors.white,
                      offset: const Offset(0, -230),
                      child: Container(
                        width: 38,
                        height: 38,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(shape: BoxShape.circle),
                        child: const Icon(
                          Icons.sentiment_satisfied_alt_outlined,
                          color: Color(0xFF54656F),
                          size: 24,
                        ),
                      ),
                      onSelected: (emoji) {
                        final activeController = _isNotesMode ? _noteController : _messageController;
                        final text = activeController.text;
                        final selection = activeController.selection;
                        final newText = text.replaceRange(
                          selection.start >= 0 ? selection.start : text.length,
                          selection.end >= 0 ? selection.end : text.length,
                          emoji,
                        );
                        activeController.text = newText;
                        activeController.selection = TextSelection.collapsed(
                          offset: (selection.start >= 0 ? selection.start : text.length) + emoji.length,
                        );
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          enabled: false,
                          child: Container(
                            width: 290,
                            padding: const EdgeInsets.all(6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'QUICK EMOJIS',
                                  style: GoogleFonts.outfit(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    '👋', '👍', '🙏', '😊', '✅', '🌾', '🌱', '🛒', '📞', '⭐',
                                    '🚚', '🎉', '🔥', '💯', '🤝', '💼', '📦', '💰', '📍', '🕒',
                                    '🚜', '🌽', '🍅', '🏷️', '💵', '📋', '❤️', '🙌', '🔔', '💬'
                                  ].map((emoji) {
                                    return InkWell(
                                      borderRadius: BorderRadius.circular(8),
                                      onTap: () => Navigator.pop(context, emoji),
                                      child: Padding(
                                        padding: const EdgeInsets.all(4.0),
                                        child: Text(emoji, style: const TextStyle(fontSize: 22)),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 4),

                // 3. WhatsApp Message Input Box (Clean White Pill / Capsule)
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 40, maxHeight: 110),
                    decoration: BoxDecoration(
                      color: _isNotesMode ? const Color(0xFFFFFBEB) : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _isNotesMode ? const Color(0xFFFCD34D) : const Color(0xFFE2E8F0),
                        width: 1.0,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: _isNotesMode
                              ? CallbackShortcuts(
                                  bindings: {
                                    const SingleActivator(LogicalKeyboardKey.enter): () => _addNote(),
                                  },
                                  child: TextField(
                                    controller: _noteController,
                                    maxLines: 4,
                                    minLines: 1,
                                    keyboardType: TextInputType.multiline,
                                    textInputAction: TextInputAction.send,
                                    style: GoogleFonts.outfit(
                                      fontSize: 14,
                                      color: const Color(0xFF78350F),
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Add an internal note (only team agents see this)...',
                                      hintStyle: GoogleFonts.outfit(
                                        color: const Color(0xFFB45309).withValues(alpha: 0.6),
                                        fontSize: 13.5,
                                      ),
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                    onSubmitted: (_) => _addNote(),
                                  ),
                                )
                              : CallbackShortcuts(
                                  bindings: {
                                    const SingleActivator(LogicalKeyboardKey.enter): () => _sendMessage(),
                                  },
                                  child: TextField(
                                    controller: _messageController,
                                    onChanged: _onMessageTextChanged,
                                    maxLines: 4,
                                    minLines: 1,
                                    keyboardType: TextInputType.multiline,
                                    textInputAction: TextInputAction.send,
                                    style: GoogleFonts.outfit(
                                      fontSize: 14,
                                      color: const Color(0xFF111B21),
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Type a message (type / for quick replies)...',
                                      hintStyle: GoogleFonts.outfit(
                                        color: const Color(0xFF8696A0),
                                        fontSize: 13.5,
                                      ),
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                    onSubmitted: (_) => _sendMessage(),
                                  ),
                                ),
                        ),
                        // Mini Note/Message Toggle Switcher Inside Input Box
                        InkWell(
                          onTap: () => setState(() => _isNotesMode = !_isNotesMode),
                          borderRadius: BorderRadius.circular(12),
                          child: Tooltip(
                            message: _isNotesMode ? 'Switch to WhatsApp message' : 'Switch to internal note mode',
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: _isNotesMode ? const Color(0xFFFEF3C7) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _isNotesMode ? const Color(0xFFFDE68A) : const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _isNotesMode ? Icons.lock_rounded : Icons.chat_bubble_outline_rounded,
                                    size: 11,
                                    color: _isNotesMode ? const Color(0xFFD97706) : const Color(0xFF64748B),
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    _isNotesMode ? 'Note' : 'Chat',
                                    style: GoogleFonts.outfit(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      color: _isNotesMode ? const Color(0xFFB45309) : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // 4. Action Send Button (WhatsApp Emerald Action Circle)
                Padding(
                  padding: const EdgeInsets.only(bottom: 1),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _isNotesMode ? _addNote : _sendMessage,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: _isNotesMode ? const Color(0xFFD97706) : const Color(0xFF00A884),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: (_isNotesMode ? const Color(0xFFD97706) : const Color(0xFF00A884)).withValues(alpha: 0.25),
                              blurRadius: 4,
                              offset: const Offset(0, 1.5),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          _isNotesMode ? Icons.lock_outline_rounded : Icons.send_rounded,
                          color: Colors.white,
                          size: 18,
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
  }

  Widget _buildMessageStatusIcon(String status) {
    final s = status.toLowerCase().trim();
    if (s == 'failed' || s == 'undelivered' || s == 'error') {
      return const Icon(Icons.error_outline, size: 12, color: Colors.redAccent);
    }
    if (s == 'read' || s == 'seen') {
      return const Icon(Icons.done_all, size: 12, color: Color(0xFF53BDEB)); // WhatsApp Blue Tick
    }
    if (s == 'delivered') {
      return const Icon(Icons.done_all, size: 12, color: Color(0xFF8696A0)); // WhatsApp Double Grey Tick
    }
    if (s == 'sent') {
      return const Icon(Icons.check, size: 12, color: Color(0xFF8696A0)); // WhatsApp Single Grey Tick
    }
    return const Icon(Icons.check, size: 12, color: Color(0xFF8696A0));
  }

  Widget _buildEmptyState() {
    return Container(
      color: Colors.white,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                size: 64,
                color: Color(0xFF008069),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'WhatsApp CRM for Business',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF111B21),
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Send and receive real-time messages with leads & dealers.',
              style: GoogleFonts.outfit(
                fontSize: 13.5,
                color: const Color(0xFF667781),
              ),
            ),
            const SizedBox(height: 36),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.lock_outline_rounded,
                    size: 13,
                    color: Color(0xFF8696A0),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'End-to-end encrypted MyOperator WhatsApp Business API (WABA) session',
                    style: GoogleFonts.outfit(
                      fontSize: 11.5,
                      color: const Color(0xFF8696A0),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Parse raw JSON messages (button_reply / list_reply) and templates into clean human-readable text
  String _formatCleanMessageText(String raw) {
    if (raw.trim().isEmpty) return '';

    // Handle template markers like "[Template] test_intro" or "test_intro"
    final trimmed = raw.trim();
    if (trimmed == '[Template] undefined' || trimmed == '[Template] null' || trimmed == '[Template]') {
      return '';
    }
    if (trimmed.startsWith('[Template]') || trimmed == 'test_intro') {
      final tplName = trimmed.startsWith('[Template]')
          ? trimmed.replaceFirst('[Template]', '').trim()
          : trimmed;
      if (tplName.isEmpty || tplName == 'undefined' || tplName == 'null') {
        return '';
      }
      final contact = _selectedConversation?['contactId'] ?? {};
      final customerName = (contact['name'] ?? 'Customer').toString();

      final matched = _approvedTemplates.cast<Map<String, dynamic>?>().firstWhere(
        (t) => (t?['name'] ?? t?['elementName'] ?? '').toString() == tplName,
        orElse: () => null,
      );
      if (matched != null) {
        String body = (matched['body'] ?? matched['data']?['body'] ?? '').toString();
        if (body.isNotEmpty) {
          body = body.replaceAll('{{1}}', customerName);
          return body;
        }
      }
      return '';
    }

    if (raw.trim().startsWith('{')) {
      try {
        final Map<String, dynamic> data = jsonDecode(raw);
        if (data.containsKey('button_reply') && data['button_reply'] is Map) {
          final title = data['button_reply']['title']?.toString();
          if (title != null && title.isNotEmpty) return title;
        }
        if (data.containsKey('list_reply') && data['list_reply'] is Map) {
          final title = data['list_reply']['title']?.toString();
          if (title != null && title.isNotEmpty) return title;
        }
        if (data.containsKey('interactive') && data['interactive'] is Map) {
          final interactive = data['interactive'];
          if (interactive is Map &&
              interactive.containsKey('button_reply') &&
              interactive['button_reply'] is Map) {
            final title = interactive['button_reply']['title']?.toString();
            if (title != null && title.isNotEmpty) return title;
          }
          if (interactive is Map &&
              interactive.containsKey('list_reply') &&
              interactive['list_reply'] is Map) {
            final title = interactive['list_reply']['title']?.toString();
            if (title != null && title.isNotEmpty) return title;
          }
        }
        if (data.containsKey('title') && data['title'] != null) {
          return data['title'].toString();
        }
        if (data.containsKey('text') && data['text'] != null) {
          return data['text'].toString();
        }
      } catch (_) {}
    }
    return raw;
  }

  // 🕒 Meta 24-Hour Messaging Window Real-Time Indicator & Guard
  Widget _buildMeta24HourWindowBanner() {
    if (_selectedConversation == null) return const SizedBox.shrink();

    DateTime? lastIncomingTime;
    
    // 1. First check conversation's authoritative lastIncomingMessageAt timestamp
    final rawConvTime = _selectedConversation['lastIncomingMessageAt'];
    if (rawConvTime != null) {
      lastIncomingTime = DateTime.tryParse(rawConvTime.toString());
    }

    // 2. Fallback: Search in loaded message history
    if (lastIncomingTime == null) {
      for (int i = _messages.length - 1; i >= 0; i--) {
        final msg = _messages[i];
        if (msg['direction'] == 'incoming') {
          final raw = msg['createdAt'] ?? msg['timestamp'];
          if (raw != null) {
            lastIncomingTime = DateTime.tryParse(raw.toString());
            break;
          }
        }
      }
    }

    final bool isWindowOpen;
    final int remainingHours;
    final int remainingMinutes;

    if (lastIncomingTime == null) {
      isWindowOpen = false;
      remainingHours = 0;
      remainingMinutes = 0;
    } else {
      final elapsed = DateTime.now().difference(lastIncomingTime.toLocal());
      if (elapsed.inHours < 24) {
        isWindowOpen = true;
        final rem = const Duration(hours: 24) - elapsed;
        remainingHours = rem.inHours;
        remainingMinutes = rem.inMinutes % 60;
      } else {
        isWindowOpen = false;
        remainingHours = 0;
        remainingMinutes = 0;
      }
    }

    if (isWindowOpen) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFA5D6A7), width: 1.0),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Color(0xFF2E7D32), size: 14),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '🟢 24h Meta Service Window Active (${remainingHours}h ${remainingMinutes}m remaining) · Free-form messages allowed',
                style: GoogleFonts.outfit(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1B5E20),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFFCC80), width: 1.0),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Color(0xFFE65100), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    lastIncomingTime == null
                        ? '⚠️ Meta 24-Hour Window Inactive. Customer has not sent an inbound message. Send an Approved Template to begin.'
                        : '⚠️ Meta 24-Hour Service Window Closed. Free text will fail. Re-engage using an Approved Template.',
                    style: GoogleFonts.outfit(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFBF360C),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE65100),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            icon: const Icon(Icons.quickreply_rounded, size: 12),
            label: Text(
              'Select Template',
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            onPressed: () {
              if (_selectedConversation != null) {
                _showSendTemplateDialog(context, _selectedConversation['_id']);
              }
            },
          ),
        ],
      ),
    );
  }

  void _showSendTemplateDialog(
    BuildContext context,
    String conversationId, {
    String? initialTemplateName,
    String? initialParam,
  }) {
    final contact = _selectedConversation?['contactId'] ?? {};
    final customerName = (contact['name'] ?? 'Customer').toString();

    WhatsAppTemplatePickerDialog.show(
      context,
      conversationId: conversationId,
      customerName: customerName,
      approvedTemplates: _approvedTemplates,
      initialTemplateName: initialTemplateName,
      initialParam: initialParam,
      onTemplateSent: () => _fetchMessages(conversationId),
      onRefreshTemplates: () => _fetchTemplates(forceSync: true),
    );
  }

  Future<void> _pickAndAttachFileFromSystem(BuildContext context) async {
    if (_selectedConversation == null) return;
    final convId = _selectedConversation['_id']?.toString() ?? '';
    if (convId.isEmpty) return;

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      final ext = (file.extension ?? '').toLowerCase();
      final isImage = ['jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp', 'heic'].contains(ext);
      final mediaType = isImage ? 'Image' : 'Document';

      if (!mounted) return;
      WhatsAppMediaPickerDialog.show(
        context,
        conversationId: convId,
        mediaType: mediaType,
        initialFile: file,
        onMediaSent: () => _fetchMessages(convId),
      );
    } catch (e) {
      debugPrint('[Direct File Picker] Error: $e');
    }
  }

  void _showAttachmentDialog(BuildContext context, String mediaType) {
    if (_selectedConversation == null) return;
    final convId = _selectedConversation['_id']?.toString() ?? '';
    if (convId.isEmpty) return;

    WhatsAppMediaPickerDialog.show(
      context,
      conversationId: convId,
      mediaType: mediaType,
      onMediaSent: () => _fetchMessages(convId),
    );
  }

  Future<void> _updateConversationStatus(String status) async {
    if (_selectedConversation == null) return;
    try {
      final res = await ApiClient().put(
        '/conversations/${_selectedConversation['_id']}/status',
        {'status': status},
      );
      if (res.statusCode == 200) {
        _fetchConversations();
        setState(() {
          _selectedConversation = null;
          _messages.clear();
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Conversation marked as $status'),
              backgroundColor: const Color(0xFF008069),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[Status Update] Error: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ⚡ CANNED RESPONSES / QUICK REPLIES MANAGEMENT MODAL
  // ══════════════════════════════════════════════════════════════════════════

  void _showCannedResponsesDialog(BuildContext context) {
    WhatsAppCannedRepliesDialog.show(
      context,
      cannedResponses: _cannedResponses,
      onSelectMessage: (msg) {
        final processed = _interpolateCannedMessage(msg);
        setState(() {
          _messageController.text = processed;
          _messageController.selection = TextSelection.fromPosition(
            TextPosition(offset: _messageController.text.length),
          );
        });
      },
      onRefresh: _fetchCannedResponses,
    );
  }

  void _showCreateCannedResponseDialog(BuildContext context, {VoidCallback? onSaved}) {
    WhatsAppCannedRepliesDialog.show(
      context,
      cannedResponses: _cannedResponses,
      onSelectMessage: (_) {},
      onRefresh: () {
        _fetchCannedResponses();
        onSaved?.call();
      },
    );
  }

  void _showTemplatesManagerDialog(BuildContext context) {
    WhatsAppTemplatePickerDialog.showManager(
      context,
      approvedTemplates: _approvedTemplates,
      selectedConversationId: _selectedConversation?['_id']?.toString(),
      onRefreshTemplates: () => _fetchTemplates(forceSync: true),
    );
  }

  void _showCustomerCallHistoryDrawer(BuildContext context, String rawPhone, String customerName) {
    WhatsAppCallHistoryDialog.show(
      context,
      rawPhone: rawPhone,
      customerName: customerName,
    );
  }
}
