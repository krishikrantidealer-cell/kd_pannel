import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  int _totalAllCount = 0;
  int _totalLeadsCount = 0;
  int _totalDealersCount = 0;
  int _totalActiveCount = 0;
  int _totalUnreadCount = 0;

  @override
  void initState() {
    super.initState();
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
          final cleanPhone = phone
              .replaceAll(RegExp(r'[^0-9]'), '')
              .replaceFirst(RegExp(r'^91'), '');
          _searchController.text = cleanPhone;
          _startOrGetConversation(cleanPhone, name: name);
        }
      }
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _websocketSubscription?.cancel();
    _searchController.dispose();
    _messageController.dispose();
    _noteController.dispose();
    _messageSearchController.dispose();
    _messageScrollController.dispose();
    super.dispose();
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

        final isIncoming = (newMessage?['direction'] ?? '') == 'incoming';
        if (isIncoming) {
          TelephonyAudioService().playIncomingMessageTone();
        }

        setState(() {
          // 1. Update matching conversation in list or insert it
          final String convId = newConversation['_id'].toString();
          final index = _conversations.indexWhere(
            (c) => c['_id'].toString() == convId,
          );

          if (index != -1) {
            _conversations[index] = newConversation;
          } else {
            _conversations.insert(0, newConversation);
          }

          // Sort conversations by last message timestamp with safety
          _conversations.sort((a, b) {
            final dateA = a['lastMessageAt'] != null
                ? DateTime.tryParse(a['lastMessageAt'].toString())
                : null;
            final dateB = b['lastMessageAt'] != null
                ? DateTime.tryParse(b['lastMessageAt'].toString())
                : null;
            if (dateA == null) return 1;
            if (dateB == null) return -1;
            return dateB.compareTo(dateA);
          });

          // 2. If the new message is in the currently selected conversation, append it
          if (_selectedConversation != null &&
              _selectedConversation['_id'].toString() == convId) {
            final String msgId = newMessage['_id']?.toString() ?? '';
            final hasMsg = _messages.any((m) => m['_id'].toString() == msgId);
            if (!hasMsg) {
              _messages.add(newMessage);
              _scrollToBottom();
            }
          } else if (isIncoming && mounted) {
            // Show toast if from another contact
            final contact = newConversation['contactId'] ?? {};
            final senderName = contact['name'] ?? contact['phone'] ?? 'Lead';
            final textSnippet = newMessage['content'] ?? (newMessage['mediaUrl'] != null ? '[Media Attachment]' : 'New Message');

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '💬 $senderName: $textSnippet',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                  ],
                ),
                action: SnackBarAction(
                  label: 'Open',
                  textColor: Colors.white,
                  onPressed: () => _selectConversation(newConversation),
                ),
                backgroundColor: const Color(0xFF008069),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            );
          }
        });
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
              if (unreadC > 0 || search.isEmpty) _totalUnreadCount = unreadC;
            } else if (page == 1 && search.isEmpty) {
              _totalAllCount = _conversations.length;
            }
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
      final endpoint = forceSync ? '/whatsapp/templates?sync=true' : '/whatsapp/templates';
      final res = await ApiClient().get(endpoint);
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true && body['data'] != null) {
          final list = List<dynamic>.from(body['data']);
          setState(() {
            _approvedTemplates = list;
          });
          debugPrint('[WhatsApp CRM] Loaded ${list.length} approved templates from backend.');
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
              _messages.insertAll(0, newMessages);
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

    final content = _messageController.text.trim();
    _messageController.clear();

    try {
      final res = await ApiClient().post('/messages/send', {
        'conversationId': _selectedConversation['_id'],
        'type': 'Text',
        'content': content,
      });

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true) {
          setState(() {
            _messages.add(body['data']);
            _scrollToBottom();
          });
        } else {
          _showErrorSnackBar(body['message'] ?? 'Failed to send message');
        }
      } else {
        final body = jsonDecode(res.body);
        _showErrorSnackBar(
          body['message'] ?? 'Failed to send message (Server Error)',
        );
      }
    } catch (e) {
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
    setState(() {
      _selectedConversation = conversation;
      _messages = [];
    });
    // Fetch chat history
    _fetchMessages(conversation['_id']);
    // Clear unread count locally
    setState(() {
      conversation['unreadCount'] = 0;
    });
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
                    final isSelected =
                        _selectedConversation != null &&
                        _selectedConversation['_id'] == conv['_id'];
                    final unreadCount = conv['unreadCount'] ?? 0;

                    String formattedTime = '';
                    if (conv['lastMessageAt'] != null) {
                      final date = DateTime.parse(
                        conv['lastMessageAt'],
                      ).toLocal();
                      formattedTime = DateFormat('hh:mm a').format(date);
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
                    final bool hasNoMessages = lastText.isEmpty && lastMsg['type'] == null;

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
                                                    fontWeight: FontWeight.w600,
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
                                                ? const Color(0xFF25D366)
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
                                          child: Text(
                                            hasNoMessages
                                                ? '✨ Ready for Outreach'
                                                : _formatCleanMessageText(
                                                    lastText.isNotEmpty
                                                        ? lastText
                                                        : 'Media Attachment',
                                                  ),
                                            style: GoogleFonts.outfit(
                                              fontSize: 11.5,
                                              fontStyle: hasNoMessages ? FontStyle.italic : FontStyle.normal,
                                              color: hasNoMessages
                                                  ? const Color(0xFF008069)
                                                  : const Color(0xFF667781),
                                              fontWeight: hasNoMessages ? FontWeight.w500 : FontWeight.normal,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (unreadCount > 0)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF25D366),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Text(
                                              '$unreadCount',
                                              style: GoogleFonts.outfit(
                                                color: Colors.white,
                                                fontSize: 9.5,
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
                              '+${contact['phone'] ?? ''}',
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
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.assignment_outlined, size: 14, color: Color(0xFF008069)),
                        label: Text(
                          'Templates',
                          style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.bold, color: const Color(0xFF008069)),
                        ),
                        onPressed: () {
                          _showTemplatesManagerDialog(context);
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
                    child: CustomPaint(
                      painter: const WhatsAppDoodlePainter(
                        color: Color(0x0E000000),
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

                          return SelectionContainer.disabled(
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
                                  maxWidth:
                                      MediaQuery.of(context).size.width * 0.45,
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
                            );
                          },
                        ),
                      );
                    }(),
                  ],
                ),
              ),
            ),

          // Message/Note Mode Switcher
          Container(
            color: const Color(0xFFF0F2F5),
            padding: const EdgeInsets.only(top: 8, left: 24, right: 24),
            child: Container(
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFFE9EDEF),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(2),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isNotesMode = false),
                      child: Container(
                        decoration: BoxDecoration(
                          color: !_isNotesMode
                              ? Colors.white
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: !_isNotesMode
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 2,
                                  ),
                                ]
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'WhatsApp Message',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: !_isNotesMode
                                ? const Color(0xFF008069)
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isNotesMode = true),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _isNotesMode
                              ? Colors.white
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: _isNotesMode
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 2,
                                  ),
                                ]
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Internal Note',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _isNotesMode
                                ? Colors.amber[800]
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Web Input Tray Bar (WhatsApp Web grey)
          Container(
            padding: const EdgeInsets.only(
              left: 20,
              right: 24,
              bottom: 16,
              top: 8,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFFF0F2F5),
              border: Border(
                top: BorderSide(color: Color(0xFFE9EDEF), width: 1),
              ),
            ),
            child: Row(
              children: [
                // Smiley Icon
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.insert_emoticon_rounded,
                    color: Color(0xFF64748B),
                    size: 24,
                  ),
                  tooltip: 'Insert Emoji',
                  onSelected: (emoji) {
                    final activeController = _isNotesMode
                        ? _noteController
                        : _messageController;
                    final text = activeController.text;
                    final selection = activeController.selection;
                    final newText = text.replaceRange(
                      selection.start >= 0 ? selection.start : text.length,
                      selection.end >= 0 ? selection.end : text.length,
                      emoji,
                    );
                    activeController.text = newText;
                    activeController.selection = TextSelection.collapsed(
                      offset:
                          (selection.start >= 0
                              ? selection.start
                              : text.length) +
                          emoji.length,
                    );
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      enabled: false,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children:
                            [
                              '👋',
                              '👍',
                              '😊',
                              '🙏',
                              '✅',
                              '🛒',
                              '📞',
                              '⭐',
                              '🚚',
                              '🎉',
                            ].map((emoji) {
                              return InkWell(
                                onTap: () {
                                  Navigator.pop(context, emoji);
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(6.0),
                                  child: Text(
                                    emoji,
                                    style: const TextStyle(fontSize: 20),
                                  ),
                                ),
                              );
                            }).toList(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                // Plus/Attachment Icon
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.add_rounded,
                    color: Color(0xFF64748B),
                    size: 24,
                  ),
                  tooltip: 'Attach Media',
                  onSelected: (value) {
                    _showAttachmentDialog(context, value);
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'Image',
                      child: Row(
                        children: [
                          const Icon(
                            Icons.image_rounded,
                            color: Color(0xFF008069),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Send Image via URL',
                            style: GoogleFonts.outfit(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'Document',
                      child: Row(
                        children: [
                          const Icon(
                            Icons.insert_drive_file_rounded,
                            color: Color(0xFF008069),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Send Document via URL',
                            style: GoogleFonts.outfit(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                // Quick Canned Replies Icon
                IconButton(
                  icon: const Icon(
                    Icons.bolt_rounded,
                    color: Color(0xFF008069),
                    size: 24,
                  ),
                  onPressed: () => _showCannedResponsesDialog(context),
                  tooltip: 'Quick Canned Replies',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
                // Template Icon
                IconButton(
                  icon: const Icon(
                    Icons.quickreply_rounded,
                    color: Color(0xFF64748B),
                    size: 23,
                  ),
                  onPressed: () {
                    if (_selectedConversation != null) {
                      _showSendTemplateDialog(
                        context,
                        _selectedConversation['_id'],
                      );
                    }
                  },
                  tooltip: 'Send Approved Template',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 14),

                Expanded(
                  child: Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFFE2E8F0),
                        width: 1,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    alignment: Alignment.centerLeft,
                    child: _isNotesMode
                        ? TextField(
                            controller: _noteController,
                            style: GoogleFonts.outfit(
                              fontSize: 13.5,
                              color: const Color(0xFF5D4037),
                            ),
                            decoration: const InputDecoration(
                              hintText:
                                  'Add an internal note only agents see...',
                              hintStyle: TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                            onSubmitted: (_) => _addNote(),
                          )
                        : TextField(
                            controller: _messageController,
                            style: GoogleFonts.outfit(
                              fontSize: 13.5,
                              color: const Color(0xFF111B21),
                            ),
                            decoration: const InputDecoration(
                              hintText: 'Type a message',
                              hintStyle: TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                            onSubmitted: (_) => _sendMessage(),
                          ),
                  ),
                ),
                const SizedBox(width: 12),

                // Send Button
                GestureDetector(
                  onTap: _isNotesMode ? _addNote : _sendMessage,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: _isNotesMode
                          ? Colors.amber[700]
                          : const Color(0xFF00A884),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 15,
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
    if (status == 'failed') {
      return const Icon(Icons.error_outline, size: 12, color: Colors.redAccent);
    }
    if (status == 'sent') {
      return const Icon(Icons.check, size: 12, color: Color(0xFF8696A0));
    }
    if (status == 'delivered') {
      return const Icon(Icons.done_all, size: 12, color: Color(0xFF8696A0));
    }
    if (status == 'read') {
      return const Icon(Icons.done_all, size: 12, color: Color(0xFF53BDEB));
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
    if (trimmed.startsWith('[Template]') || trimmed == 'test_intro') {
      final tplName = trimmed.startsWith('[Template]')
          ? trimmed.replaceFirst('[Template]', '').trim()
          : trimmed;
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
      return 'Namaste $customerName, welcome to Krishi Kranti!';
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

    // Find initial selected template - default to initialTemplateName or first approved template if available
    Map<String, dynamic>? selectedTemplate;
    if (_approvedTemplates.isNotEmpty) {
      if (initialTemplateName != null && initialTemplateName.isNotEmpty) {
        selectedTemplate = _approvedTemplates.firstWhere(
          (t) => (t['name'] ?? t['elementName'] ?? '').toString() == initialTemplateName,
          orElse: () => _approvedTemplates.first as Map<String, dynamic>,
        ) as Map<String, dynamic>?;
      } else {
        selectedTemplate = _approvedTemplates.firstWhere(
          (t) => (t['status'] ?? 'APPROVED').toString().toUpperCase() == 'APPROVED',
          orElse: () => _approvedTemplates.first as Map<String, dynamic>,
        ) as Map<String, dynamic>?;
      }
    }

    final TextEditingController mediaUrlController = TextEditingController();
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (dialogContext) {
        Map<String, dynamic>? currentTpl = selectedTemplate;
        // Keep controllers for dynamic variables
        Map<int, TextEditingController> variableControllers = {};

        void initVariableControllers(Map<String, dynamic>? tpl) {
          variableControllers.clear();
          if (tpl == null) return;
          final bodyText = (tpl['body'] ?? tpl['data']?['body'] ?? '').toString();
          final matches = RegExp(r'\{\{(\d+)\}\}').allMatches(bodyText);
          final Set<int> varIndices = {};
          for (final m in matches) {
            final idx = int.tryParse(m.group(1) ?? '1') ?? 1;
            varIndices.add(idx);
          }
          final sorted = varIndices.toList()..sort();
          for (final idx in sorted) {
            if (idx == 1) {
              variableControllers[idx] = TextEditingController(text: initialParam ?? customerName);
            } else {
              variableControllers[idx] = TextEditingController();
            }
          }
        }

        initVariableControllers(currentTpl);

        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final bool hasTemplates = _approvedTemplates.isNotEmpty;
            final tplName = (currentTpl?['name'] ?? currentTpl?['elementName'] ?? '').toString();
            final tplBody = (currentTpl?['body'] ?? currentTpl?['data']?['body'] ?? '').toString();
            final tplCategory = (currentTpl?['category'] ?? 'UTILITY').toString();
            final tplLanguage = (currentTpl?['language'] ?? currentTpl?['languageCode'] ?? 'en').toString();
            final tplFooter = (currentTpl?['footer'] ?? '').toString();
            final tplHeader = (currentTpl?['headerText'] ?? '').toString();
            final headerType = (currentTpl?['headerType'] ?? 'NONE').toString().toUpperCase();
            final tplStatus = (currentTpl?['status'] ?? 'APPROVED').toString().toUpperCase();
            final bool isApproved = tplStatus == 'APPROVED';
            final bool isRejected = tplStatus.contains('REJECT') || tplStatus.contains('FAIL');
            final bool isPending = !isApproved && !isRejected;

            return Dialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Container(
                width: 540,
                padding: const EdgeInsets.all(24),
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
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF008069).withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.quickreply_rounded,
                                color: Color(0xFF008069),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Send WhatsApp Template',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: const Color(0xFF111B21),
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                          onPressed: () => Navigator.pop(dialogCtx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Choose an official Meta-approved template to message outside the 24-hour window.',
                      style: GoogleFonts.outfit(fontSize: 12.5, color: const Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 18),

                    if (!hasTemplates) ...[
                      // Empty state
                      Container(
                        padding: const EdgeInsets.all(24),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.assignment_late_outlined, size: 44, color: Color(0xFF94A3B8)),
                            const SizedBox(height: 10),
                            Text(
                              'No Templates in Workspace',
                              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14.5, color: const Color(0xFF1E293B)),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Create and register official templates with Meta & MyOperator first.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF008069),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              icon: const Icon(Icons.add_rounded, size: 16),
                              label: Text('Open Templates Manager', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold)),
                              onPressed: () {
                                Navigator.pop(dialogCtx);
                                _showTemplatesManagerDialog(context);
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ] else ...[
                      // Template Picker Dropdown Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Select WhatsApp Template:', style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFF334155))),
                          InkWell(
                            borderRadius: BorderRadius.circular(6),
                            onTap: () {
                              Navigator.pop(dialogCtx);
                              _showTemplatesManagerDialog(context);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.settings_outlined, size: 13, color: Color(0xFF64748B)),
                                  const SizedBox(width: 3),
                                  Text(
                                    'Manage',
                                    style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: tplName.isNotEmpty ? tplName : null,
                        isExpanded: true,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF008069), width: 1.6)),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        items: _approvedTemplates.map<DropdownMenuItem<String>>((t) {
                          final name = (t['name'] ?? t['elementName'] ?? '').toString();
                          final cat = (t['category'] ?? 'UTILITY').toString();
                          final l = (t['language'] ?? t['languageCode'] ?? 'en').toString();
                          final st = (t['status'] ?? 'APPROVED').toString().toUpperCase();
                          final bool itemAppr = st == 'APPROVED';
                          final bool itemRej = st.contains('REJECT') || st.contains('FAIL');

                          Color badgeBg = const Color(0xFFE8F5E9);
                          Color badgeText = const Color(0xFF2E7D32);
                          String badgeLabel = '🟢 Approved';

                          if (itemRej) {
                            badgeBg = const Color(0xFFFFEBEE);
                            badgeText = const Color(0xFFC62828);
                            badgeLabel = '❌ Rejected';
                          } else if (!itemAppr) {
                            badgeBg = const Color(0xFFFFF8E1);
                            badgeText = const Color(0xFFF57F17);
                            badgeLabel = '⏳ In Review';
                          }

                          return DropdownMenuItem<String>(
                            value: name,
                            child: Row(
                              children: [
                                Icon(
                                  itemAppr ? Icons.check_circle_outline_rounded : (itemRej ? Icons.cancel_outlined : Icons.hourglass_top_rounded),
                                  size: 15,
                                  color: badgeText,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    name,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(4)),
                                  child: Text(badgeLabel, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: badgeText)),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(4)),
                                  child: Text('$cat • $l', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF475569))),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            final matched = _approvedTemplates.firstWhere(
                              (t) => (t['name'] ?? t['elementName'] ?? '').toString() == val,
                              orElse: () => _approvedTemplates.first,
                            );
                            setDialogState(() {
                              currentTpl = matched as Map<String, dynamic>?;
                              initVariableControllers(currentTpl);
                            });
                          }
                        },
                      ),

                      // Status Warning Notice (for Pending or Rejected templates)
                      if (!isApproved) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: isRejected ? const Color(0xFFFEF2F2) : const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isRejected ? const Color(0xFFFECACA) : const Color(0xFFFDE68A),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isRejected ? Icons.error_outline_rounded : Icons.hourglass_empty_rounded,
                                size: 18,
                                color: isRejected ? const Color(0xFFDC2626) : const Color(0xFFD97706),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  isRejected
                                      ? 'This template was rejected by Meta policy and cannot be sent to customers.'
                                      : 'This template is awaiting Meta / MyOperator review. You cannot dispatch messages with pending templates.',
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: isRejected ? const Color(0xFF991B1B) : const Color(0xFF92400E),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),

                      // Live Message Preview Box
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE7FCE8),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.visibility_rounded, size: 13, color: Color(0xFF047857)),
                                const SizedBox(width: 4),
                                Text('Live Template Preview', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF047857))),
                              ],
                            ),
                            if (tplHeader.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(tplHeader, style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFF111B21))),
                            ],
                            const SizedBox(height: 4),
                            Text(
                              tplBody.isNotEmpty ? tplBody : '(Empty Body)',
                              style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF1E293B), height: 1.35),
                            ),
                            if (tplFooter.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(tplFooter, style: GoogleFonts.outfit(fontSize: 10.5, color: const Color(0xFF64748B), fontStyle: FontStyle.italic)),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Dynamic Variable Input Fields
                      if (variableControllers.isNotEmpty) ...[
                        Text('Fill Template Variables:', style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFF334155))),
                        const SizedBox(height: 8),
                        ...variableControllers.entries.map((entry) {
                          final varIdx = entry.key;
                          final ctrl = entry.value;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: TextField(
                              controller: ctrl,
                              decoration: InputDecoration(
                                labelText: 'Variable {{$varIdx}} ${varIdx == 1 ? "(Customer Name)" : ""}',
                                labelStyle: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF008069)),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF008069), width: 1.5)),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              ),
                              style: GoogleFonts.outfit(fontSize: 13),
                            ),
                          );
                        }),
                      ],

                      if (headerType == 'IMAGE' || headerType == 'DOCUMENT') ...[
                        TextField(
                          controller: mediaUrlController,
                          decoration: InputDecoration(
                            labelText: 'Header Media URL ($headerType)',
                            hintText: 'https://example.com/catalog.pdf',
                            labelStyle: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B)),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          ),
                          style: GoogleFonts.outfit(fontSize: 13),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],

                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          ),
                          onPressed: () => Navigator.pop(dialogCtx),
                          child: Text('Cancel', style: GoogleFonts.outfit(color: const Color(0xFF64748B), fontWeight: FontWeight.w600)),
                        ),
                        if (hasTemplates) ...[
                          const SizedBox(width: 10),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isApproved ? const Color(0xFF008069) : const Color(0xFF94A3B8),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                            ),
                            icon: Icon(isApproved ? Icons.send_rounded : Icons.lock_outline_rounded, size: 14),
                            label: Text(
                              isApproved
                                  ? 'Send Template'
                                  : (isRejected ? 'Template Rejected' : 'Awaiting Meta Approval'),
                              style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                            onPressed: isApproved
                                ? () async {
                                    final nameToSend = (currentTpl?['name'] ?? currentTpl?['elementName'] ?? '').toString();
                                    final langToSend = (currentTpl?['language'] ?? 'en').toString();
                                    if (nameToSend.isEmpty) return;

                                    final sortedKeys = variableControllers.keys.toList()..sort();
                                    final List<String> bodyValues = sortedKeys.map((k) => variableControllers[k]!.text.trim()).toList();
                                    final mediaUrl = mediaUrlController.text.trim();

                                    // Resolve interpolated text
                                    String resolvedContent = (currentTpl?['body'] ?? currentTpl?['data']?['body'] ?? '').toString();
                                    for (final entry in variableControllers.entries) {
                                      resolvedContent = resolvedContent.replaceAll('{{${entry.key}}}', entry.value.text.trim());
                                    }
                                    if (resolvedContent.isEmpty) {
                                      resolvedContent = nameToSend;
                                    }

                                    Navigator.of(dialogCtx).pop();

                                    try {
                                      final res = await ApiClient().post('/messages/send', {
                                        'conversationId': conversationId,
                                        'type': 'Template',
                                        'templateName': nameToSend,
                                        'languageCode': langToSend,
                                        'bodyValues': bodyValues,
                                        'content': resolvedContent,
                                        'mediaUrl': mediaUrl.isNotEmpty ? mediaUrl : null,
                                      });
                                      if (res.statusCode == 200) {
                                        _fetchMessages(conversationId);
                                        if (mounted) {
                                          scaffoldMessenger.showSnackBar(
                                            SnackBar(
                                              content: Text('Template "$nameToSend" dispatched via MyOperator WABA!'),
                                              backgroundColor: const Color(0xFF008069),
                                            ),
                                          );
                                        }
                                      } else {
                                        final body = jsonDecode(res.body);
                                        if (mounted) {
                                          _showErrorSnackBar(body['message'] ?? 'Failed to send template');
                                        }
                                      }
                                    } catch (e) {
                                      debugPrint('[Template Send] Failed: $e');
                                      if (mounted) {
                                        _showErrorSnackBar('Network error: Could not send template ($e)');
                                      }
                                    }
                                  }
                                : null,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showAttachmentDialog(BuildContext context, String mediaType) {
    final TextEditingController urlController = TextEditingController();
    final TextEditingController captionController = TextEditingController();
    final String label = mediaType == 'Image' ? 'Image URL' : 'Document URL';

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 440,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF008069).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          mediaType == 'Image'
                              ? Icons.image_rounded
                              : Icons.insert_drive_file_rounded,
                          color: const Color(0xFF008069),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Send WhatsApp $mediaType',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: const Color(0xFF111B21),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: Color(0xFF64748B),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Enter the direct public link of the $mediaType to send to the recipient.',
                style: GoogleFonts.outfit(
                  fontSize: 12.5,
                  color: const Color(0xFF64748B),
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: urlController,
                decoration: InputDecoration(
                  labelText: label,
                  hintText: mediaType == 'Image'
                      ? 'https://example.com/image.jpg'
                      : 'https://example.com/document.pdf',
                  labelStyle: GoogleFonts.outfit(
                    color: const Color(0xFF008069),
                    fontSize: 13,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: Color(0xFF008069),
                      width: 1.8,
                    ),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  isDense: true,
                ),
                style: GoogleFonts.outfit(fontSize: 13.5),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: captionController,
                decoration: InputDecoration(
                  labelText: 'Caption (Optional)',
                  hintText: 'e.g. Please review this file',
                  labelStyle: GoogleFonts.outfit(
                    color: const Color(0xFF64748B),
                    fontSize: 13,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: Color(0xFF008069),
                      width: 1.8,
                    ),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  isDense: true,
                ),
                style: GoogleFonts.outfit(fontSize: 13.5),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF008069),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 12,
                      ),
                    ),
                    onPressed: () async {
                      final url = urlController.text.trim();
                      if (url.isEmpty) return;
                      final caption = captionController.text.trim();

                      Navigator.pop(context);

                      try {
                        if (_selectedConversation == null) return;
                        final conversationId = _selectedConversation['_id'];

                        final res = await ApiClient().post('/messages/send', {
                          'conversationId': conversationId,
                          'type': mediaType,
                          'content': caption,
                          'mediaUrl': url,
                        });
                        if (res.statusCode == 200) {
                          _fetchMessages(conversationId);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '$mediaType message sent successfully',
                                ),
                                backgroundColor: const Color(0xFF008069),
                              ),
                            );
                          }
                        } else {
                          final body = jsonDecode(res.body);
                          _showErrorSnackBar(
                            body['message'] ?? 'Failed to send $mediaType',
                          );
                        }
                      } catch (e) {
                        debugPrint('[$mediaType Send] Failed: $e');
                        _showErrorSnackBar(
                          'Network error: Could not send $mediaType',
                        );
                      }
                    },
                    child: Text(
                      'Send $mediaType',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
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
    String searchQuery = '';
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final filtered = _cannedResponses.where((c) {
            final title = (c['title'] ?? '').toString().toLowerCase();
            final shortcut = (c['shortcut'] ?? '').toString().toLowerCase();
            final msg = (c['message'] ?? '').toString().toLowerCase();
            final q = searchQuery.toLowerCase();
            return title.contains(q) || shortcut.contains(q) || msg.contains(q);
          }).toList();

          return Dialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              width: 580,
              height: 600,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF008069).withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.bolt_rounded, color: Color(0xFF008069), size: 22),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Canned Responses & Quick Replies',
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF111B21),
                                ),
                              ),
                              Text(
                                '1-click insert pre-approved answers & sales scripts',
                                style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Search & Add Bar
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 38,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          alignment: Alignment.centerLeft,
                          child: TextField(
                            onChanged: (val) => setDialogState(() => searchQuery = val),
                            style: GoogleFonts.outfit(fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Search by shortcut (/bank) or keyword...',
                              hintStyle: GoogleFonts.outfit(fontSize: 12.5, color: const Color(0xFF94A3B8)),
                              prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
                              prefixIconConstraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF008069),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: Text(
                          'New Canned Reply',
                          style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () {
                          _showCreateCannedResponseDialog(context, onSaved: () {
                            setDialogState(() {});
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  const SizedBox(height: 12),

                  // List of canned messages
                  Expanded(
                    child: _isLoadingCanned
                        ? const Center(child: CircularProgressIndicator(color: Color(0xFF008069)))
                        : filtered.isEmpty
                            ? Center(
                                child: Text(
                                  searchQuery.isEmpty ? 'No canned responses yet. Click "+ New Canned Reply" to add one.' : 'No canned replies match "$searchQuery"',
                                  style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF64748B)),
                                  textAlign: TextAlign.center,
                                ),
                              )
                            : ListView.separated(
                                itemCount: filtered.length,
                                separatorBuilder: (context, idx) => const Divider(height: 12, color: Color(0xFFF1F5F9)),
                                itemBuilder: (context, idx) {
                                  final item = filtered[idx];
                                  final shortcut = item['shortcut'] ?? '';
                                  final title = item['title'] ?? 'Quick Reply';
                                  final message = item['message'] ?? '';
                                  final category = item['category'] ?? 'General';
                                  final itemId = item['_id']?.toString();

                                  return Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFF008069).withValues(alpha: 0.12),
                                                    borderRadius: BorderRadius.circular(6),
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
                                                const SizedBox(width: 8),
                                                Text(
                                                  title,
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 13.5,
                                                    fontWeight: FontWeight.w600,
                                                    color: const Color(0xFF1E293B),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius: BorderRadius.circular(4),
                                                border: Border.all(color: const Color(0xFFCBD5E1)),
                                              ),
                                              child: Text(
                                                category,
                                                style: GoogleFonts.outfit(fontSize: 10.5, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          message,
                                          style: GoogleFonts.outfit(
                                            fontSize: 12.5,
                                            color: const Color(0xFF334155),
                                            height: 1.35,
                                          ),
                                          maxLines: 4,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 10),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            if (itemId != null)
                                              IconButton(
                                                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                                                tooltip: 'Delete Canned Reply',
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(),
                                                onPressed: () async {
                                                  try {
                                                    await ApiClient().delete('/canned-responses/$itemId');
                                                    _fetchCannedResponses();
                                                    setDialogState(() {
                                                      _cannedResponses.removeWhere((c) => c['_id'] == itemId);
                                                    });
                                                  } catch (_) {}
                                                },
                                              ),
                                            const SizedBox(width: 14),
                                            ElevatedButton.icon(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFF008069),
                                                foregroundColor: Colors.white,
                                                elevation: 0,
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                              ),
                                              icon: const Icon(Icons.send_rounded, size: 13),
                                              label: Text('Insert into Chat', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold)),
                                              onPressed: () {
                                                Navigator.pop(context);
                                                setState(() {
                                                  _messageController.text = message;
                                                });
                                              },
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showCreateCannedResponseDialog(BuildContext context, {VoidCallback? onSaved}) {
    final titleController = TextEditingController();
    final shortcutController = TextEditingController();
    final messageController = TextEditingController();
    String category = 'Sales';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: 480,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Create Canned Response',
                      style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF111B21)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: shortcutController,
                  decoration: InputDecoration(
                    labelText: 'Shortcut (e.g. /pricing or /bank)',
                    labelStyle: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF008069), fontWeight: FontWeight.w600),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    isDense: true,
                  ),
                  style: GoogleFonts.outfit(fontSize: 13.5),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: 'Title / Label (e.g. Bank Account Details)',
                    labelStyle: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF64748B)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    isDense: true,
                  ),
                  style: GoogleFonts.outfit(fontSize: 13.5),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: InputDecoration(
                    labelText: 'Category',
                    labelStyle: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF64748B)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    isDense: true,
                  ),
                  items: ['General', 'Sales', 'Support', 'Logistics', 'Finance']
                      .map((c) => DropdownMenuItem(value: c, child: Text(c, style: GoogleFonts.outfit(fontSize: 13))))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => category = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: messageController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: 'Message Body',
                    hintText: 'Type your standardized reply message here...',
                    labelStyle: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF64748B)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  style: GoogleFonts.outfit(fontSize: 13.5),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Cancel', style: GoogleFonts.outfit(color: const Color(0xFF64748B))),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF008069),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () async {
                        final title = titleController.text.trim();
                        final shortcut = shortcutController.text.trim();
                        final msg = messageController.text.trim();
                        if (title.isEmpty || shortcut.isEmpty || msg.isEmpty) return;

                        Navigator.pop(context);
                        try {
                          final res = await ApiClient().post('/canned-responses', {
                            'title': title,
                            'shortcut': shortcut,
                            'message': msg,
                            'category': category,
                          });
                          if (res.statusCode == 200) {
                            await _fetchCannedResponses();
                            onSaved?.call();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Canned response created successfully!'),
                                  backgroundColor: Color(0xFF008069),
                                ),
                              );
                            }
                          }
                        } catch (e) {
                          debugPrint('[Create Canned Response] Error: $e');
                        }
                      },
                      child: Text('Save Canned Reply', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 📋 WHATSAPP TEMPLATES & META APPROVAL MANAGEMENT MODAL
  // ══════════════════════════════════════════════════════════════════════════

  void _showTemplatesManagerDialog(BuildContext context) {
    String filterScope = 'ALL'; // 'ALL', 'GLOBAL', 'PRIVATE'
    final bool isAdmin = AuthService().currentUserRole == UserRole.admin;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final List<dynamic> filteredTemplates = _approvedTemplates.where((t) {
            final bool isGlob = t['isGlobal'] != false;
            if (filterScope == 'GLOBAL') return isGlob;
            if (filterScope == 'PRIVATE') return t['isGlobal'] == false;
            return true;
          }).toList();

          return Dialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              width: 780,
              height: 680,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF008069).withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.assignment_outlined, color: Color(0xFF008069), size: 22),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'WhatsApp Business Templates',
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF111B21),
                                ),
                              ),
                              Text(
                                isAdmin
                                    ? 'Manage Global and Agent-specific Meta approved templates'
                                    : 'Manage your private templates and view company global templates',
                                style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Filter & Action Bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Scope Tabs (All / Global / Private)
                      Row(
                        children: [
                          _buildScopeFilterChip('ALL', 'All (${_approvedTemplates.length})', filterScope, (val) {
                            setDialogState(() => filterScope = val);
                          }),
                          const SizedBox(width: 8),
                          _buildScopeFilterChip('GLOBAL', '🌐 Company Global', filterScope, (val) {
                            setDialogState(() => filterScope = val);
                          }),
                          const SizedBox(width: 8),
                          _buildScopeFilterChip('PRIVATE', '🔒 Private Templates', filterScope, (val) {
                            setDialogState(() => filterScope = val);
                          }),
                        ],
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF008069),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: Text(
                          'Create New Template',
                          style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () {
                          _showCreateTemplateDialog(context, onCreated: () {
                            setDialogState(() {});
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  const SizedBox(height: 12),

                  // Template Grid / List
                  Expanded(
                    child: _isLoadingTemplates
                        ? const Center(child: CircularProgressIndicator(color: Color(0xFF008069)))
                        : filteredTemplates.isEmpty
                            ? Center(
                                child: Text(
                                  'No templates found in this category.\nClick "+ Create New Template" to submit one for approval.',
                                  style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF64748B), height: 1.4),
                                  textAlign: TextAlign.center,
                                ),
                              )
                            : ListView.separated(
                                itemCount: filteredTemplates.length,
                                separatorBuilder: (context, idx) => const SizedBox(height: 12),
                                itemBuilder: (context, idx) {
                                  final t = filteredTemplates[idx];
                                  final name = (t['name'] ?? t['elementName'] ?? 'template').toString();
                                  final title = (t['title'] ?? '').toString();
                                  final category = (t['category'] ?? 'UTILITY').toString();
                                  final language = (t['language'] ?? 'en').toString();
                                  final body = (t['body'] ?? t['data']?['body'] ?? (t['components'] is List ? (t['components'] as List).firstWhere((c) => c['type'] == 'BODY', orElse: () => {})['text'] : null) ?? name).toString();
                                  final status = (t['status'] ?? 'APPROVED').toString().toUpperCase();
                                  final footer = (t['footer'] ?? '').toString();
                                  final templateId = t['_id']?.toString();
                                  final bool isGlobal = t['isGlobal'] == true;
                                  String creatorName = '';
                                  if (t['createdBy'] is Map) {
                                    final cb = t['createdBy'] as Map<String, dynamic>;
                                    creatorName = (cb['name'] ?? '${cb['firstName'] ?? ''} ${cb['lastName'] ?? ''}').toString().trim();
                                    if (creatorName.isEmpty) creatorName = (cb['email'] ?? '').toString();
                                  } else if (t['agentId'] is Map) {
                                    final ag = t['agentId'] as Map<String, dynamic>;
                                    creatorName = (ag['name'] ?? '${ag['firstName'] ?? ''} ${ag['lastName'] ?? ''}').toString().trim();
                                  }
                                  if (creatorName.isEmpty) {
                                    creatorName = (t['agentPhone'] ?? '').toString();
                                  }

                                  Color statusColor = const Color(0xFF008069);
                                  String statusText = '🟢 Approved';
                                  if (status.contains('PENDING')) {
                                    statusColor = Colors.orange[800]!;
                                    statusText = '⏳ In Review (Meta)';
                                  } else if (status.contains('REJECT')) {
                                    statusColor = Colors.red[700]!;
                                    statusText = '❌ Rejected';
                                  }

                                  return Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Wrap(
                                                crossAxisAlignment: WrapCrossAlignment.center,
                                                spacing: 8,
                                                runSpacing: 4,
                                                children: [
                                                  Text(
                                                    title.isNotEmpty ? title : name,
                                                    style: GoogleFonts.outfit(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.bold,
                                                      color: const Color(0xFF0F172A),
                                                    ),
                                                  ),
                                                  if (title.isNotEmpty)
                                                    Text(
                                                      '($name)',
                                                      style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B)),
                                                    ),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: isGlobal ? const Color(0xFF0284C7).withValues(alpha: 0.12) : const Color(0xFF64748B).withValues(alpha: 0.12),
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Text(
                                                      isGlobal ? '🌐 Company Global' : (creatorName.isNotEmpty ? '🔒 Private ($creatorName)' : '🔒 Private Template'),
                                                      style: GoogleFonts.outfit(
                                                        fontSize: 10.5,
                                                        fontWeight: FontWeight.w700,
                                                        color: isGlobal ? const Color(0xFF0284C7) : const Color(0xFF475569),
                                                      ),
                                                    ),
                                                  ),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFFE2E8F0),
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Text(
                                                      '$category • $language',
                                                      style: GoogleFonts.outfit(fontSize: 10.5, fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: statusColor.withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                statusText,
                                                style: GoogleFonts.outfit(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: statusColor,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          body,
                                          style: GoogleFonts.outfit(
                                            fontSize: 13,
                                            color: const Color(0xFF334155),
                                            height: 1.4,
                                          ),
                                        ),
                                        if (footer.isNotEmpty) ...[
                                          const SizedBox(height: 6),
                                          Text(
                                            'Footer: $footer',
                                            style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF94A3B8), fontStyle: FontStyle.italic),
                                          ),
                                        ],
                                        const SizedBox(height: 10),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            if (isAdmin && templateId != null)
                                              IconButton(
                                                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                                                tooltip: 'Delete Template',
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(),
                                                onPressed: () async {
                                                  final bool? confirm = await showDialog<bool>(
                                                    context: context,
                                                    builder: (confirmCtx) => AlertDialog(
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                      title: Text('Delete WhatsApp Template?', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
                                                      content: Text(
                                                        'Are you sure you want to delete "$name"? This will remove it from Meta & MyOperator WABA registry.',
                                                        style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF475569)),
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () => Navigator.pop(confirmCtx, false),
                                                          child: Text('Cancel', style: GoogleFonts.outfit(color: const Color(0xFF64748B))),
                                                        ),
                                                        ElevatedButton(
                                                          style: ElevatedButton.styleFrom(
                                                            backgroundColor: const Color(0xFFDC2626),
                                                            foregroundColor: Colors.white,
                                                            elevation: 0,
                                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                          ),
                                                          onPressed: () => Navigator.pop(confirmCtx, true),
                                                          child: Text('Delete', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                                                        ),
                                                      ],
                                                    ),
                                                  );

                                                  if (confirm == true) {
                                                    try {
                                                      final res = await ApiClient().delete('/whatsapp/templates/$templateId');
                                                      if (res.statusCode == 200) {
                                                        _fetchTemplates();
                                                        setDialogState(() {
                                                          _approvedTemplates.removeWhere((tpl) => tpl['_id'] == templateId);
                                                        });
                                                        if (context.mounted) {
                                                          ScaffoldMessenger.of(context).showSnackBar(
                                                            SnackBar(
                                                              content: Text('Template "$name" deleted successfully.'),
                                                              backgroundColor: const Color(0xFF1E293B),
                                                            ),
                                                          );
                                                        }
                                                      }
                                                    } catch (e) {
                                                      debugPrint('[Delete Template] Error: $e');
                                                    }
                                                  }
                                                },
                                              ),
                                            if (status.contains('APPROV') && _selectedConversation != null) ...[
                                              const SizedBox(width: 12),
                                              ElevatedButton.icon(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: const Color(0xFF008069),
                                                  foregroundColor: Colors.white,
                                                  elevation: 0,
                                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                                ),
                                                icon: const Icon(Icons.send_rounded, size: 13),
                                                label: Text('Send to Contact', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold)),
                                                onPressed: () {
                                                  Navigator.pop(context);
                                                  _showSendTemplateDialog(
                                                    context,
                                                    _selectedConversation['_id'],
                                                    initialTemplateName: name,
                                                  );
                                                },
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildScopeFilterChip(String scope, String label, String activeScope, ValueChanged<String> onSelect) {
    final bool isSelected = scope == activeScope;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => onSelect(scope),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF008069) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  void _showCreateTemplateDialog(BuildContext context, {VoidCallback? onCreated}) {
    final nameController = TextEditingController();
    final titleController = TextEditingController();
    final bodyController = TextEditingController();
    final footerController = TextEditingController();
    final headerTextController = TextEditingController();
    String category = 'UTILITY';
    String language = 'en';
    String headerType = 'NONE';
    final bool isAdmin = AuthService().currentUserRole == UserRole.admin;
    bool isGlobal = isAdmin; // Default to global for Admin, private for Sales
    bool autoSlug = true;
    bool isAlreadyApproved = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final String currentTitle = titleController.text;
          final String currentBody = bodyController.text;
          final String currentHeader = headerTextController.text;
          final String currentFooter = footerController.text;

          void insertVariable(String varTag) {
            final text = bodyController.text;
            final selection = bodyController.selection;
            if (selection.start >= 0 && selection.end >= 0) {
              final newText = text.replaceRange(selection.start, selection.end, varTag);
              bodyController.value = TextEditingValue(
                text: newText,
                selection: TextSelection.collapsed(offset: selection.start + varTag.length),
              );
            } else {
              bodyController.text = '$text $varTag'.trim();
            }
            setDialogState(() {});
          }

          return Dialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              width: 820,
              constraints: const BoxConstraints(maxHeight: 680),
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFF008069).withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.mark_chat_unread_rounded, color: Color(0xFF008069), size: 18),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isAlreadyApproved ? 'Register Existing Meta Template' : 'Create WhatsApp Business Template',
                                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                              ),
                              Text(
                                isAlreadyApproved
                                    ? 'Activate an approved template from your MyOperator/Meta dashboard immediately'
                                    : 'Submit for Meta & MyOperator automated compliance review',
                                style: GoogleFonts.outfit(fontSize: 11.5, color: const Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF64748B)),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 14),

                  // ── Body Columns: Editor + Live Preview ──
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Column: Form Fields
                        Expanded(
                          flex: 11,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.only(right: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Existing Approval Toggle
                                Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isAlreadyApproved ? const Color(0xFF008069).withValues(alpha: 0.08) : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isAlreadyApproved ? const Color(0xFF008069).withValues(alpha: 0.35) : const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Checkbox(
                                        value: isAlreadyApproved,
                                        activeColor: const Color(0xFF008069),
                                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        onChanged: (val) {
                                          setDialogState(() => isAlreadyApproved = val ?? false);
                                        },
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Already Approved on MyOperator / Meta',
                                              style: GoogleFonts.outfit(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.bold,
                                                color: isAlreadyApproved ? const Color(0xFF008069) : const Color(0xFF1E293B),
                                              ),
                                            ),
                                            Text(
                                              'Enable if template is already created & approved on MyOperator. Activates instantly without review.',
                                              style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF64748B)),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Title & Identifier
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: titleController,
                                        onChanged: (val) {
                                          if (autoSlug) {
                                            final slug = val
                                                .toLowerCase()
                                                .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
                                                .replaceAll(RegExp(r'^_+|_+$'), '');
                                            nameController.text = slug;
                                          }
                                          setDialogState(() {});
                                        },
                                        decoration: InputDecoration(
                                          labelText: 'Friendly Title',
                                          hintText: 'e.g. Order Confirmation',
                                          labelStyle: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B)),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                          isDense: true,
                                        ),
                                        style: GoogleFonts.outfit(fontSize: 13),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: TextField(
                                        controller: nameController,
                                        onChanged: (_) {
                                          autoSlug = false;
                                          setDialogState(() {});
                                        },
                                        decoration: InputDecoration(
                                          labelText: 'Meta Template Name',
                                          hintText: 'e.g. order_confirmation',
                                          labelStyle: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF008069), fontWeight: FontWeight.w600),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                          isDense: true,
                                        ),
                                        style: GoogleFonts.firaCode(fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),

                                // Category & Language
                                Row(
                                  children: [
                                    Expanded(
                                      child: DropdownButtonFormField<String>(
                                        value: category,
                                        isExpanded: true,
                                        decoration: InputDecoration(
                                          labelText: 'Category',
                                          labelStyle: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B)),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                          isDense: true,
                                        ),
                                        items: [
                                          DropdownMenuItem(
                                            value: 'UTILITY',
                                            child: Text('Utility (Account/Orders)', style: GoogleFonts.outfit(fontSize: 12.5), overflow: TextOverflow.ellipsis),
                                          ),
                                          DropdownMenuItem(
                                            value: 'MARKETING',
                                            child: Text('Marketing (Promotions)', style: GoogleFonts.outfit(fontSize: 12.5), overflow: TextOverflow.ellipsis),
                                          ),
                                          DropdownMenuItem(
                                            value: 'AUTHENTICATION',
                                            child: Text('Authentication (OTPs)', style: GoogleFonts.outfit(fontSize: 12.5), overflow: TextOverflow.ellipsis),
                                          ),
                                        ],
                                        onChanged: (val) {
                                          if (val != null) setDialogState(() => category = val);
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: DropdownButtonFormField<String>(
                                        value: language,
                                        isExpanded: true,
                                        decoration: InputDecoration(
                                          labelText: 'Language',
                                          labelStyle: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B)),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                          isDense: true,
                                        ),
                                        items: [
                                          DropdownMenuItem(value: 'en', child: Text('English (en)', style: GoogleFonts.outfit(fontSize: 12.5))),
                                          DropdownMenuItem(value: 'hi', child: Text('Hindi (hi)', style: GoogleFonts.outfit(fontSize: 12.5))),
                                          DropdownMenuItem(value: 'mr', child: Text('Marathi (mr)', style: GoogleFonts.outfit(fontSize: 12.5))),
                                          DropdownMenuItem(value: 'gu', child: Text('Gujarati (gu)', style: GoogleFonts.outfit(fontSize: 12.5))),
                                        ],
                                        onChanged: (val) {
                                          if (val != null) setDialogState(() => language = val);
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),

                                // Header Type
                                Row(
                                  children: [
                                    Expanded(
                                      child: DropdownButtonFormField<String>(
                                        value: headerType,
                                        isExpanded: true,
                                        decoration: InputDecoration(
                                          labelText: 'Header Type',
                                          labelStyle: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B)),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                          isDense: true,
                                        ),
                                        items: [
                                          DropdownMenuItem(value: 'NONE', child: Text('No Header', style: GoogleFonts.outfit(fontSize: 12.5))),
                                          DropdownMenuItem(value: 'TEXT', child: Text('Text Header', style: GoogleFonts.outfit(fontSize: 12.5))),
                                          DropdownMenuItem(value: 'IMAGE', child: Text('Image Header', style: GoogleFonts.outfit(fontSize: 12.5))),
                                          DropdownMenuItem(value: 'DOCUMENT', child: Text('Document (PDF) Header', style: GoogleFonts.outfit(fontSize: 12.5))),
                                        ],
                                        onChanged: (val) {
                                          if (val != null) setDialogState(() => headerType = val);
                                        },
                                      ),
                                    ),
                                    if (headerType == 'TEXT') ...[
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: TextField(
                                          controller: headerTextController,
                                          onChanged: (_) => setDialogState(() {}),
                                          decoration: InputDecoration(
                                            labelText: 'Header Text',
                                            hintText: 'e.g. Order Confirmed!',
                                            labelStyle: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B)),
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                            isDense: true,
                                          ),
                                          style: GoogleFonts.outfit(fontSize: 13),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 10),

                                // Scope Banner
                                if (isAdmin)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Global Template (Visible to all agents)',
                                          style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
                                        ),
                                        Transform.scale(
                                          scale: 0.8,
                                          child: Switch(
                                            value: isGlobal,
                                            activeColor: const Color(0xFF008069),
                                            onChanged: (val) => setDialogState(() => isGlobal = val),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                const SizedBox(height: 10),

                                // Body text area + variable insertion toolbar
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Body Message *',
                                          style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
                                        ),
                                        Row(
                                          children: [
                                            Text('Insert: ', style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF64748B))),
                                            InkWell(
                                              onTap: () => insertVariable('{{1}}'),
                                              borderRadius: BorderRadius.circular(4),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF008069).withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text('{{1}} Name', style: GoogleFonts.outfit(fontSize: 10.5, fontWeight: FontWeight.bold, color: const Color(0xFF008069))),
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            InkWell(
                                              onTap: () => insertVariable('{{2}}'),
                                              borderRadius: BorderRadius.circular(4),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF008069).withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text('{{2}} Order ID', style: GoogleFonts.outfit(fontSize: 10.5, fontWeight: FontWeight.bold, color: const Color(0xFF008069))),
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            InkWell(
                                              onTap: () => insertVariable('{{3}}'),
                                              borderRadius: BorderRadius.circular(4),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF008069).withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text('{{3}} Amount', style: GoogleFonts.outfit(fontSize: 10.5, fontWeight: FontWeight.bold, color: const Color(0xFF008069))),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    TextField(
                                      controller: bodyController,
                                      maxLines: 4,
                                      onChanged: (_) => setDialogState(() {}),
                                      decoration: InputDecoration(
                                        hintText: 'Namaste {{1}}, your Krishi Kranti order #{{2}} is confirmed for dispatch!',
                                        hintStyle: GoogleFonts.outfit(fontSize: 12.5, color: const Color(0xFF94A3B8)),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                        contentPadding: const EdgeInsets.all(12),
                                      ),
                                      style: GoogleFonts.outfit(fontSize: 13),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),

                                // Footer Field
                                TextField(
                                  controller: footerController,
                                  onChanged: (_) => setDialogState(() {}),
                                  decoration: InputDecoration(
                                    labelText: 'Footer Note (Optional)',
                                    hintText: 'e.g. Krishi Kranti Organics',
                                    labelStyle: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B)),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    isDense: true,
                                  ),
                                  style: GoogleFonts.outfit(fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Vertical Divider
                        Container(
                          width: 1,
                          height: double.infinity,
                          color: const Color(0xFFE2E8F0),
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                        ),

                        // Right Column: Live WhatsApp Message Bubble Preview
                        Expanded(
                          flex: 9,
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFEAE2), // WhatsApp chat wallpaper background
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.visibility_rounded, size: 14, color: Color(0xFF54656F)),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Live WhatsApp Preview',
                                      style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF54656F)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Expanded(
                                  child: Align(
                                    alignment: Alignment.topLeft,
                                    child: Container(
                                      constraints: const BoxConstraints(maxWidth: 290),
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: const BorderRadius.only(
                                          topLeft: Radius.circular(0),
                                          topRight: Radius.circular(10),
                                          bottomLeft: Radius.circular(10),
                                          bottomRight: Radius.circular(10),
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.06),
                                            offset: const Offset(0, 1),
                                            blurRadius: 2,
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Header preview
                                          if (headerType == 'TEXT' && currentHeader.isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(bottom: 6),
                                              child: Text(
                                                currentHeader,
                                                style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF111B21)),
                                              ),
                                            )
                                          else if (headerType == 'IMAGE')
                                            Container(
                                              height: 100,
                                              width: double.infinity,
                                              margin: const EdgeInsets.only(bottom: 6),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFE2E8F0),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: const Icon(Icons.image_rounded, color: Color(0xFF94A3B8), size: 36),
                                            )
                                          else if (headerType == 'DOCUMENT')
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              margin: const EdgeInsets.only(bottom: 6),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF1F5F9),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Row(
                                                children: [
                                                  const Icon(Icons.picture_as_pdf_rounded, color: Colors.red, size: 20),
                                                  const SizedBox(width: 6),
                                                  Text('catalog_attachment.pdf', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600)),
                                                ],
                                              ),
                                            ),

                                          // Body preview
                                          Text(
                                            currentBody.isNotEmpty
                                                ? currentBody
                                                : 'Template message body preview will appear here...',
                                            style: GoogleFonts.outfit(
                                              fontSize: 12.5,
                                              color: currentBody.isNotEmpty ? const Color(0xFF111B21) : const Color(0xFF94A3B8),
                                              height: 1.35,
                                            ),
                                          ),
                                          const SizedBox(height: 6),

                                          // Footer preview
                                          if (currentFooter.isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(bottom: 4),
                                              child: Text(
                                                currentFooter,
                                                style: GoogleFonts.outfit(fontSize: 10.5, color: const Color(0xFF667781)),
                                              ),
                                            ),

                                          // Timestamp
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.end,
                                            children: [
                                              Text(
                                                DateFormat('hh:mm a').format(DateTime.now()),
                                                style: GoogleFonts.outfit(fontSize: 10, color: const Color(0xFF667781)),
                                              ),
                                              const SizedBox(width: 3),
                                              const Icon(Icons.done_all_rounded, size: 13, color: Color(0xFF53BDEB)),
                                            ],
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
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── Actions ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: Text('Cancel', style: GoogleFonts.outfit(color: const Color(0xFF64748B), fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF008069),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        icon: Icon(isAlreadyApproved ? Icons.check_circle_outline_rounded : Icons.send_rounded, size: 16),
                        onPressed: () async {
                          final name = nameController.text.trim();
                          final body = bodyController.text.trim();
                          if (name.isEmpty || body.isEmpty) return;

                          Navigator.pop(context);

                          try {
                            final res = await ApiClient().post('/whatsapp/templates', {
                              'name': name,
                              'title': titleController.text.trim().isNotEmpty ? titleController.text.trim() : name,
                              'isGlobal': isGlobal,
                              'category': category,
                              'language': language,
                              'headerType': headerType,
                              'headerText': headerTextController.text.trim(),
                              'body': body,
                              'footer': footerController.text.trim(),
                              'status': isAlreadyApproved ? 'APPROVED' : 'PENDING',
                            });

                            if (res.statusCode == 200 || res.statusCode == 201) {
                              await _fetchTemplates();
                              onCreated?.call();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(isAlreadyApproved
                                        ? 'Template "$name" registered & activated!'
                                        : 'Template submitted for Meta/MyOperator review!'),
                                    backgroundColor: const Color(0xFF008069),
                                  ),
                                );
                              }
                            } else {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Failed to save template: HTTP ${res.statusCode}'),
                                    backgroundColor: Colors.red[700],
                                  ),
                                );
                              }
                            }
                          } catch (e) {
                            debugPrint('[Create Template] Error: $e');
                          }
                        },
                        label: Text(
                          isAlreadyApproved ? 'Register & Activate Template' : 'Submit for Approval',
                          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 📞 CUSTOMER TELEPHONY TIMELINE & MYOPERATOR RECORDING VAULT MODAL
  // ══════════════════════════════════════════════════════════════════════════
  void _showCustomerCallHistoryDrawer(BuildContext context, String rawPhone, String customerName) {
    final cleanPhone = rawPhone.replaceAll(RegExp(r'\D'), '').replaceFirst(RegExp(r'^91'), '');
    if (cleanPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No phone number available for $customerName', style: GoogleFonts.outfit()),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    List<dynamic> customerCalls = [];
    bool isLoading = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDlgState) {
          if (isLoading) {
            ApiClient().get('/calls/logs?search=$cleanPhone&customerPhone=$cleanPhone&limit=50').then((res) {
              if (res.statusCode == 200) {
                final body = jsonDecode(res.body);
                final List<dynamic> logs = body['data'] is List
                    ? (body['data'] as List)
                    : (body['data']?['callLogs'] ?? []);
                if (context.mounted) {
                  setDlgState(() {
                    customerCalls = List<dynamic>.from(logs);
                    isLoading = false;
                  });
                }
              } else {
                if (context.mounted) {
                  setDlgState(() => isLoading = false);
                }
              }
            }).catchError((_) {
              if (context.mounted) {
                setDlgState(() => isLoading = false);
              }
            });
          }

          return Dialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              width: 620,
              height: 580,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFF008069).withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.phone_in_talk_rounded, color: Color(0xFF008069), size: 18),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    customerName.isNotEmpty ? customerName : 'Customer',
                                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15, color: const Color(0xFF0F172A)),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: Text(
                                      '+91 $cleanPhone',
                                      style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                'Call History & Recordings Timeline',
                                style: GoogleFonts.outfit(fontSize: 11.5, color: const Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          if (!isLoading && customerCalls.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFA7F3D0)),
                              ),
                              child: Text(
                                '${customerCalls.length} calls',
                                style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF065F46)),
                              ),
                            ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF64748B)),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 10),

                  // ── Call Log List ──
                  Expanded(
                    child: isLoading
                        ? const Center(child: CircularProgressIndicator(color: Color(0xFF008069), strokeWidth: 2.5))
                        : customerCalls.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.phone_disabled_rounded, size: 40, color: Colors.grey.shade300),
                                    const SizedBox(height: 8),
                                    Text('No call records found for this contact', style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF64748B))),
                                  ],
                                ),
                              )
                            : ListView.separated(
                                itemCount: customerCalls.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 6),
                                itemBuilder: (ctx, i) {
                                  final call = customerCalls[i];
                                  final status = (call['status'] ?? 'initiated').toString().toLowerCase();
                                  final duration = int.tryParse((call['durationSeconds'] ?? 0).toString()) ?? 0;
                                  final mins = duration ~/ 60;
                                  final secs = duration % 60;
                                  final durText = duration > 0 ? '${mins}m ${secs}s' : '0s';
                                  final isOutbound = (call['direction'] ?? call['type'] ?? 'outbound').toString().toLowerCase() == 'outbound';
                                  final bool isSuccessful = status == 'answered' || status == 'completed';
                                  final bool isMissed = status == 'missed' || status == 'failed' || status == 'no-answer' || status == 'rejected';

                                  final agent = call['agentId'];
                                  final agentName = agent is Map
                                      ? '${agent['firstName'] ?? ''} ${agent['lastName'] ?? ''}'.trim()
                                      : (call['agentName'] ?? 'Agent').toString();
                                  final rawDate = call['createdAt'];
                                  final dateText = rawDate != null
                                      ? DateFormat('dd MMM, hh:mm a').format(DateTime.tryParse(rawDate.toString())?.toLocal() ?? DateTime.now())
                                      : '';
                                  final userDisp = (call['userDisposition'] ?? call['disposition'] ?? '').toString().trim();
                                  final notes = (call['notes'] ?? '').toString().trim();
                                  final rawRecordingUrl = (call['recordingUrl'] ?? '').toString().trim();
                                  final hasRecording = rawRecordingUrl.isNotEmpty;

                                  final Color iconBg = isMissed
                                      ? const Color(0xFFFFF1F2)
                                      : isOutbound
                                          ? const Color(0xFFECFDF5)
                                          : const Color(0xFFEFF6FF);
                                  final Color iconColor = isMissed
                                      ? const Color(0xFFE11D48)
                                      : isOutbound
                                          ? const Color(0xFF059669)
                                          : const Color(0xFF2563EB);

                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: Row(
                                      children: [
                                        // ── Direction / Status Icon ──
                                        Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color: iconBg,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            isMissed
                                                ? Icons.phone_missed_rounded
                                                : isOutbound
                                                    ? Icons.call_made_rounded
                                                    : Icons.call_received_rounded,
                                            size: 16,
                                            color: iconColor,
                                          ),
                                        ),
                                        const SizedBox(width: 10),

                                        // ── Call Details ──
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Text(
                                                    isOutbound ? 'Outbound' : 'Inbound',
                                                    style: GoogleFonts.outfit(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 12.5,
                                                      color: const Color(0xFF1E293B),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                    decoration: BoxDecoration(
                                                      color: isSuccessful
                                                          ? const Color(0xFFDCFCE7)
                                                          : isMissed
                                                              ? const Color(0xFFFEE2E2)
                                                              : const Color(0xFFF1F5F9),
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Text(
                                                      status.toUpperCase(),
                                                      style: GoogleFonts.outfit(
                                                        fontSize: 9,
                                                        fontWeight: FontWeight.bold,
                                                        color: isSuccessful
                                                            ? const Color(0xFF15803D)
                                                            : isMissed
                                                                ? const Color(0xFFB91C1C)
                                                                : const Color(0xFF64748B),
                                                      ),
                                                    ),
                                                  ),
                                                  const Spacer(),
                                                  Text(
                                                    dateText,
                                                    style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF94A3B8)),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 3),
                                              Row(
                                                children: [
                                                  Text(
                                                    '⏱ $durText',
                                                    style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Text(
                                                    '👤 $agentName',
                                                    style: GoogleFonts.outfit(fontSize: 11.5, color: const Color(0xFF64748B)),
                                                  ),
                                                  if (userDisp.isNotEmpty || notes.isNotEmpty) ...[
                                                    const SizedBox(width: 8),
                                                    Flexible(
                                                      child: Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                                        decoration: BoxDecoration(
                                                          color: const Color(0xFFFFFBEB),
                                                          borderRadius: BorderRadius.circular(4),
                                                          border: Border.all(color: const Color(0xFFFDE68A)),
                                                        ),
                                                        child: Text(
                                                          '📝 ${userDisp.isNotEmpty ? userDisp : notes}',
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                          style: GoogleFonts.outfit(fontSize: 10.5, color: const Color(0xFF92400E), fontWeight: FontWeight.w500),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),

                                        // ── Action Button ──
                                        InkWell(
                                          borderRadius: BorderRadius.circular(6),
                                          onTap: () async {
                                            String recordingUrl = rawRecordingUrl;
                                            final logId = call['_id']?.toString() ?? call['callId']?.toString() ?? '';

                                            if (!recordingUrl.startsWith('http://') && !recordingUrl.startsWith('https://') && logId.isNotEmpty) {
                                              try {
                                                final res = await ApiClient().get('/calls/recordings/$logId/url');
                                                if (res.statusCode == 200) {
                                                  final body = jsonDecode(res.body);
                                                  if (body['success'] == true && body['data']?['recordingUrl'] != null) {
                                                    recordingUrl = body['data']['recordingUrl'].toString();
                                                  }
                                                }
                                              } catch (_) {}
                                            }

                                            String targetUrl = 'https://myoperator.com/app/call-logs';
                                            if (recordingUrl.startsWith('http://') || recordingUrl.startsWith('https://')) {
                                              targetUrl = recordingUrl;
                                            } else if (cleanPhone.isNotEmpty) {
                                              targetUrl = 'https://myoperator.com/app/call-logs?search=$cleanPhone';
                                            }

                                            final uri = Uri.parse(targetUrl);
                                            if (await canLaunchUrl(uri)) {
                                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                                            }
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                            decoration: BoxDecoration(
                                              color: hasRecording ? const Color(0xFF008069).withValues(alpha: 0.08) : const Color(0xFFF8FAFC),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(
                                                color: hasRecording ? const Color(0xFF008069).withValues(alpha: 0.25) : const Color(0xFFE2E8F0),
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  hasRecording ? Icons.play_arrow_rounded : Icons.open_in_new_rounded,
                                                  size: 14,
                                                  color: hasRecording ? const Color(0xFF008069) : const Color(0xFF64748B),
                                                ),
                                                const SizedBox(width: 3),
                                                Text(
                                                  hasRecording ? 'Play' : 'Logs',
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: hasRecording ? const Color(0xFF008069) : const Color(0xFF64748B),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Custom painter for authentic WhatsApp vector doodle chat wallpaper
class WhatsAppDoodlePainter extends CustomPainter {
  final Color color;
  const WhatsAppDoodlePainter({this.color = const Color(0x0A000000)});

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = color.withValues(alpha: color.a * 0.6)
      ..style = PaintingStyle.fill;

    const double stepX = 140.0;
    const double stepY = 140.0;

    for (double y = 20; y < size.height + 40; y += stepY) {
      for (double x = 20; x < size.width + 40; x += stepX) {
        final double ox = (y / stepY).floor() % 2 == 1 ? x + 70 : x;
        _drawDoodleCluster(canvas, ox, y, strokePaint, fillPaint);
      }
    }
  }

  void _drawDoodleCluster(Canvas canvas, double cx, double cy, Paint stroke, Paint fill) {
    // 1. Speech bubble
    final bubbleRect = RRect.fromRectAndRadius(Rect.fromLTWH(cx - 30, cy - 25, 22, 15), const Radius.circular(4));
    canvas.drawRRect(bubbleRect, stroke);
    final bubbleTail = Path()
      ..moveTo(cx - 30, cy - 14)
      ..lineTo(cx - 35, cy - 10)
      ..lineTo(cx - 27, cy - 10);
    canvas.drawPath(bubbleTail, stroke);

    // 2. Small Heart
    final heartPath = Path()
      ..moveTo(cx + 15, cy - 20)
      ..cubicTo(cx + 15, cy - 24, cx + 9, cy - 26, cx + 9, cy - 20)
      ..cubicTo(cx + 9, cy - 15, cx + 15, cy - 11, cx + 15, cy - 9)
      ..cubicTo(cx + 15, cy - 11, cx + 21, cy - 15, cx + 21, cy - 20)
      ..cubicTo(cx + 21, cy - 26, cx + 15, cy - 24, cx + 15, cy - 20);
    canvas.drawPath(heartPath, stroke);

    // 3. Coffee Mug
    final cupRect = RRect.fromRectAndRadius(Rect.fromLTWH(cx - 24, cy + 12, 14, 13), const Radius.circular(2));
    canvas.drawRRect(cupRect, stroke);
    canvas.drawArc(Rect.fromLTWH(cx - 10, cy + 14, 7, 7), -1.5, 3.0, false, stroke);

    // 4. Smiley Face
    canvas.drawCircle(Offset(cx + 20, cy + 16), 8, stroke);
    canvas.drawCircle(Offset(cx + 17, cy + 14), 1, fill);
    canvas.drawCircle(Offset(cx + 23, cy + 14), 1, fill);
    canvas.drawArc(Rect.fromLTWH(cx + 16, cy + 15, 8, 5), 0.2, 2.7, false, stroke);

    // 5. Star / Sparkle
    final starPath = Path()
      ..moveTo(cx - 2, cy - 5)
      ..lineTo(cx - 2, cy + 5)
      ..moveTo(cx - 7, cy)
      ..lineTo(cx + 3, cy);
    canvas.drawPath(starPath, stroke);

    // 6. Clock
    canvas.drawCircle(Offset(cx + 35, cy - 2), 7, stroke);
    final clockHands = Path()
      ..moveTo(cx + 35, cy - 6)
      ..lineTo(cx + 35, cy - 2)
      ..lineTo(cx + 38, cy - 2);
    canvas.drawPath(clockHands, stroke);

    // 7. Paper plane / Send arrow
    final plane = Path()
      ..moveTo(cx - 42, cy + 28)
      ..lineTo(cx - 30, cy + 22)
      ..lineTo(cx - 38, cy + 35)
      ..close();
    canvas.drawPath(plane, stroke);

    // 8. Music Note
    final music = Path()
      ..moveTo(cx + 42, cy + 26)
      ..lineTo(cx + 42, cy + 18)
      ..lineTo(cx + 49, cy + 16)
      ..lineTo(cx + 49, cy + 24);
    canvas.drawPath(music, stroke);
    canvas.drawCircle(Offset(cx + 40, cy + 26), 2, fill);
    canvas.drawCircle(Offset(cx + 47, cy + 24), 2, fill);
  }

  @override
  bool shouldRepaint(covariant WhatsAppDoodlePainter oldDelegate) => oldDelegate.color != color;
}
