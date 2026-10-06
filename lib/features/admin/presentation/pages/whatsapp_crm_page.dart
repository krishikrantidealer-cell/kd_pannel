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
  final ScrollController _quickChipScrollController = ScrollController();

  String _selectedStatus = 'open'; // open, closed, snoozed
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
      '[WhatsApp CRM] Fetching page $_conversationsPage of $_conversationsTotalPages',
    );

    try {
      final endpoint =
          '/conversations?status=$_selectedStatus&search=$search&page=$page&limit=15';
      final res = await ApiClient().get(endpoint);

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true) {
          setState(() {
            if (page == 1) {
              _conversations = body['data'] ?? [];
            } else {
              _conversations.addAll(body['data'] ?? []);
            }
            _conversationsTotalPages = body['pagination']?['pages'] ?? 1;
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
      setState(() => _isLoadingConversations = false);
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
  Future<void> _fetchTemplates() async {
    setState(() => _isLoadingTemplates = true);
    try {
      final res = await ApiClient().get('/templates');
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true && body['data'] != null) {
          setState(() {
            _approvedTemplates = List<dynamic>.from(body['data']);
          });
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

  // API Call: Update Contact Preferred Language
  Future<void> _updateLanguage(String langCode) async {
    if (_selectedConversation == null) return;
    final convId = _selectedConversation['_id'];
    try {
      final res = await ApiClient().put('/conversations/$convId/language', {
        'preferredLanguage': langCode,
      });
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        setState(() {
          _selectedConversation = body['data'];
        });
        _fetchConversations();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Preferred language updated to ${langCode.toUpperCase()}',
              ),
              backgroundColor: const Color(0xFF008069),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[WhatsApp CRM] Error updating language: $e');
    }
  }

  // API Call: Trigger 1-Click Outbound Sales Call via MyOperator OBD API
  Future<void> _triggerOutboundCall(String phone) async {
    if (phone.isEmpty) return;
    try {
      final res = await ApiClient().post('/calls/trigger', {
        'customerPhone': phone,
      });
      if (res.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(
                    Icons.phone_in_talk_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Outbound call initiated via MyOperator!',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF008069),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        final body = jsonDecode(res.body);
        _showErrorSnackBar(body['message'] ?? 'Failed to initiate call');
      }
    } catch (e) {
      debugPrint('[Click-to-Call] Error triggering call: $e');
      _showErrorSnackBar('Network error triggering call');
    }
  }

  // API Call: Reassign contact agent
  Future<void> _reassignAgent(String? agentId) async {
    if (agentId == null || _selectedConversation == null) return;

    try {
      final res = await ApiClient().post('/conversations/assign', {
        'conversationId': _selectedConversation['_id'],
        'agentId': agentId,
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
                  'Lead reassigned successfully',
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
                    icon: const Icon(
                      Icons.sync_rounded,
                      color: Color(0xFF54656F),
                      size: 20,
                    ),
                    onPressed: () => _fetchConversations(),
                    tooltip: 'Refresh conversations',
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

        // Filters bar (Centered filter tabs with Mouse Drag & Wheel Scroll)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: Colors.white,
          alignment: Alignment.centerLeft,
          child: ScrollConfiguration(
            behavior: WebCustomScrollBehavior(),
            child: SingleChildScrollView(
              controller: _sidebarFilterScrollController,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _buildFilterTab('open', '🟢 Open'),
                  const SizedBox(width: 6),
                  _buildFilterTab('all', '💬 All Chats'),
                  const SizedBox(width: 6),
                  _buildFilterTab('closed', '✅ Closed'),
                  const SizedBox(width: 6),
                  _buildFilterTab('snoozed', '⏳ Snoozed'),
                ],
              ),
            ),
          ),
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
                  child: Text(
                    'No conversations found',
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF667781),
                      fontSize: 13,
                    ),
                  ),
                )
              : ListView.builder(
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

                    final String name = contact['name'] ?? 'WhatsApp User';
                    final Color avatarColor = _getAvatarColor(name);

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
                                            _formatCleanMessageText(
                                              lastMsg['content'] ??
                                                  'Media Attachment',
                                            ),
                                            style: GoogleFonts.outfit(
                                              fontSize: 11.5,
                                              color: const Color(0xFF667781),
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

  Widget _buildFilterTab(String status, String label) {
    final bool isSelected = _selectedStatus == status;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedStatus = status;
          _selectedConversation = null;
        });
        _fetchConversations();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE8F5E9) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(20),
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
          style: GoogleFonts.outfit(
            fontSize: 11.5,
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
    final assignedTo = _selectedConversation['assignedTo'];
    final role = AuthService().currentUserRole;

    String? assignedId;
    String assignedAgentName = 'Unassigned';

    if (assignedTo is Map) {
      assignedId = assignedTo['_id']?.toString();
      assignedAgentName =
          '${assignedTo['firstName'] ?? ''} ${assignedTo['lastName'] ?? ''}'
              .trim();
    } else if (assignedTo is String) {
      assignedId = assignedTo;
      final agent = _salesAgents.firstWhere(
        (a) => a['_id'] == assignedId,
        orElse: () => null,
      );
      if (agent != null) {
        assignedAgentName =
            '${agent['firstName'] ?? ''} ${agent['lastName'] ?? ''}'.trim();
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

                      // 6-Language Switcher Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF008069,
                          ).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: const Color(
                              0xFF008069,
                            ).withValues(alpha: 0.3),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.language_rounded,
                              size: 14,
                              color: Color(0xFF008069),
                            ),
                            const SizedBox(width: 4),
                            DropdownButton<String>(
                              value:
                                  [
                                    'en',
                                    'hi',
                                    'ta',
                                    'te',
                                    'mr',
                                    'kn',
                                  ].contains(contact['preferredLanguage'])
                                  ? contact['preferredLanguage']
                                  : 'en',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                color: const Color(0xFF008069),
                                fontWeight: FontWeight.bold,
                              ),
                              underline: const SizedBox(),
                              icon: const Icon(
                                Icons.arrow_drop_down,
                                size: 16,
                                color: Color(0xFF008069),
                              ),
                              isDense: true,
                              items: const [
                                DropdownMenuItem(
                                  value: 'en',
                                  child: Text('EN (English)'),
                                ),
                                DropdownMenuItem(
                                  value: 'hi',
                                  child: Text('HI (हिन्दी)'),
                                ),
                                DropdownMenuItem(
                                  value: 'ta',
                                  child: Text('TA (தமிழ்)'),
                                ),
                                DropdownMenuItem(
                                  value: 'te',
                                  child: Text('TE (తెలుగు)'),
                                ),
                                DropdownMenuItem(
                                  value: 'mr',
                                  child: Text('MR (मराठी)'),
                                ),
                                DropdownMenuItem(
                                  value: 'kn',
                                  child: Text('KN (ಕನ್ನಡ)'),
                                ),
                              ],
                              onChanged: (val) {
                                if (val != null) _updateLanguage(val);
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),

                      // 📞 Click-to-Call MyOperator Button
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF008069),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          elevation: 0,
                        ),
                        icon: const Icon(
                          Icons.phone_forwarded_rounded,
                          size: 13,
                        ),
                        label: Text(
                          'Call Dealer',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: () =>
                            _triggerOutboundCall(contact['phone'] ?? ''),
                      ),
                      const SizedBox(width: 8),

                      // Manual Reassignment Dropdown (Admin only, hidden for Sales reps)
                      if (role == UserRole.admin)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: const Color(0xFFE9ECEF),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(
                                'Assigned: ',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  color: const Color(0xFF667781),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              DropdownButton<String>(
                                value:
                                    _salesAgents.any(
                                      (a) => a['_id'] == assignedId,
                                    )
                                    ? assignedId
                                    : null,
                                hint: Text(
                                  'Unassigned',
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  color: const Color(0xFF111B21),
                                  fontWeight: FontWeight.bold,
                                ),
                                underline: const SizedBox(),
                                icon: const Icon(
                                  Icons.arrow_drop_down,
                                  size: 16,
                                  color: Color(0xFF667781),
                                ),
                                isDense: true,
                                items: [
                                  const DropdownMenuItem<String>(
                                    value: null,
                                    child: Text('Unassigned'),
                                  ),
                                  ..._salesAgents.map((agent) {
                                    return DropdownMenuItem<String>(
                                      value: agent['_id'],
                                      child: Text(
                                        '${agent['firstName'] ?? ''} ${agent['lastName'] ?? ''}'
                                            .trim(),
                                      ),
                                    );
                                  }).toList(),
                                ],
                                onChanged: (value) => _reassignAgent(value),
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
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        icon: const Icon(Icons.bolt_rounded, size: 14),
                        label: Text(
                          'Canned',
                          style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold),
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
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        icon: const Icon(Icons.assignment_outlined, size: 14),
                        label: Text(
                          'Templates',
                          style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () => _showTemplatesManagerDialog(context),
                      ),
                      const SizedBox(width: 8),

                      // 📞 Call Action (WebCall + Mobile C2C - DRY Component)
                      Builder(
                        builder: (ctx) {
                          final contact = _selectedConversation?['contactId'] ?? {};
                          final String phone = (contact['phone'] ?? '').toString();
                          final String name = (contact['name'] ?? 'Customer').toString();
                          if (phone.isEmpty) return const SizedBox.shrink();
                          return TelephonyCallButton(
                            customerPhone: phone,
                            customerName: name,
                            variant: TelephonyButtonVariant.filled,
                            color: const Color(0xFF008069),
                          );
                        },
                      ),
                      const SizedBox(width: 8),

                      // 📜 Customer Call History & MyOperator Recordings Drawer Button
                      IconButton(
                        icon: const Icon(
                          Icons.history_edu_rounded,
                          color: Color(0xFF008069),
                          size: 21,
                        ),
                        tooltip: 'View Customer Call History & MyOperator Recordings',
                        onPressed: () {
                          final contact = _selectedConversation?['contactId'] ?? {};
                          final String phone = (contact['phone'] ?? '').toString();
                          final String name = (contact['name'] ?? 'Customer').toString();
                          if (phone.isNotEmpty) {
                            _showCustomerCallHistoryDrawer(context, phone, name);
                          }
                        },
                      ),
                      const SizedBox(width: 8),

                      // Search button
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
                        tooltip: 'Search messages',
                      ),
                      // More options menu button
                      PopupMenuButton<String>(
                        icon: const Icon(
                          Icons.more_vert_rounded,
                          color: Color(0xFF54656F),
                          size: 20,
                        ),
                        tooltip: 'Options',
                        onSelected: (value) {
                          if (value == 'refresh') {
                            _fetchMessages(_selectedConversation['_id']);
                          } else {
                            _updateConversationStatus(value);
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'refresh',
                            child: Text(
                              'Refresh Chat History',
                              style: GoogleFonts.outfit(fontSize: 13),
                            ),
                          ),
                          PopupMenuItem(
                            value: 'closed',
                            child: Text(
                              'Mark as Closed',
                              style: GoogleFonts.outfit(fontSize: 13),
                            ),
                          ),
                          PopupMenuItem(
                            value: 'snoozed',
                            child: Text(
                              'Mark as Snoozed',
                              style: GoogleFonts.outfit(fontSize: 13),
                            ),
                          ),
                          PopupMenuItem(
                            value: 'open',
                            child: Text(
                              'Mark as Open',
                              style: GoogleFonts.outfit(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),

          // ⚡ Smart Retargeting Outreach Banner for Sales Representatives
          _buildSmartOutreachBanner(),

          // 🕒 Meta 24-Hour Messaging Window Indicator
          _buildMeta24HourWindowBanner(),

          // Message log thread
          Expanded(
            child: _isLoadingMessages && _messages.isEmpty
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
                      return Center(
                        child: Text(
                          _messageSearchQuery.isEmpty
                              ? 'No messages in this chat'
                              : 'No matching messages found',
                          style: GoogleFonts.outfit(
                            color: Colors.grey[600],
                            fontSize: 13,
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
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFFFE082),
                                width: 0.8,
                              ),
                            );
                            textCol = const Color(0xFF5D4037);
                          } else if (isOutgoing) {
                            bubbleDecoration = const BoxDecoration(
                              color: Color(0xFFD9FDD3), // WhatsApp Green Bubble
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(12),
                                bottomLeft: Radius.circular(12),
                                bottomRight: Radius.circular(12),
                                topRight:
                                    Radius.zero, // Pointy Top-Right corner tail
                              ),
                            );
                          } else {
                            bubbleDecoration = const BoxDecoration(
                              color: Colors.white, // WhatsApp White Bubble
                              borderRadius: BorderRadius.only(
                                topRight: Radius.circular(12),
                                bottomLeft: Radius.circular(12),
                                bottomRight: Radius.circular(12),
                                topLeft:
                                    Radius.zero, // Pointy Top-Left corner tail
                              ),
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
                            ),
                          );
                        },
                      ),
                    ); // closes SelectionContainer.disabled
                  }(),
          ),

          // Quick Template Bar for Sales Representatives (Dynamic WABA Approved Templates)
          _buildQuickTemplateBar(),

          // Message/Note Mode Switcher
          Container(
            color: Colors.white,
            padding: const EdgeInsets.only(top: 8, left: 24, right: 24),
            child: Container(
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
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

          // Web Input Tray Bar (Pure White)
          Container(
            padding: const EdgeInsets.only(
              left: 20,
              right: 24,
              bottom: 16,
              top: 8,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Color(0xFFF1F5F9), width: 1),
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

  // Parse raw JSON messages (button_reply / list_reply) into clean human-readable text
  String _formatCleanMessageText(String raw) {
    if (raw.trim().isEmpty) return '';
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

  // ⚡ Dynamic Smart Outreach Banner for Sales Reps
  Widget _buildSmartOutreachBanner() {
    if (_selectedConversation == null) return const SizedBox();
    final contact = _selectedConversation['contactId'] ?? {};
    final customerName = contact['name'] ?? 'Customer';

    if (_approvedTemplates.isEmpty) return const SizedBox();

    final firstTemplate = _approvedTemplates.first;
    final templateName = (firstTemplate['name'] ?? firstTemplate['elementName'] ?? '').toString();
    final displayName = templateName.replaceAll('_', ' ');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF008069).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFF008069).withValues(alpha: 0.25),
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  color: Color(0xFF008069),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Recommended Action: Send "$displayName" to $customerName',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF111B21),
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
              backgroundColor: const Color(0xFF008069),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: const Icon(Icons.bolt_rounded, size: 14),
            label: Text(
              'Send in 1-Tap',
              style: GoogleFonts.outfit(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
              ),
            ),
            onPressed: () => _sendQuickTemplateDirectly(
              templateName,
              '',
            ),
          ),
        ],
      ),
    );
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

  // Quick Template Chips Bar for Sales Representatives (Dynamic WABA Approved Templates)
  Widget _buildQuickTemplateBar() {
    if (_approvedTemplates.isEmpty) {
      return Container(
        color: Colors.white,
        padding: const EdgeInsets.only(top: 6, left: 16, right: 16, bottom: 2),
        child: Row(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                if (_selectedConversation != null) {
                  _showSendTemplateDialog(context, _selectedConversation['_id']);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF008069).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF008069).withValues(alpha: 0.25),
                    width: 1.0,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.quickreply_rounded, size: 13, color: Color(0xFF008069)),
                    const SizedBox(width: 6),
                    Text(
                      'Send Approved WhatsApp Template',
                      style: GoogleFonts.outfit(
                        fontSize: 11.5,
                        color: const Color(0xFF008069),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(top: 8, left: 16, right: 16),
      height: 36,
      child: ScrollConfiguration(
        behavior: WebCustomScrollBehavior(),
        child: ListView.separated(
          controller: _quickChipScrollController,
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: _approvedTemplates.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final t = _approvedTemplates[index];
            final name = (t['name'] ?? t['elementName'] ?? '').toString();
            final displayName = name.replaceAll('_', ' ').toUpperCase();
            return _buildQuickTemplateChip(
              '⚡ $displayName',
              name,
              '',
            );
          },
        ),
      ),
    );
  }

  // 1-Tap Zero-Effort Template Dispatcher
  Future<void> _sendQuickTemplateDirectly(
    String templateName,
    String defaultParam,
  ) async {
    if (_selectedConversation == null || templateName.isEmpty) return;
    final convId = _selectedConversation['_id'];
    final contact = _selectedConversation['contactId'] ?? {};
    final customerName = contact['name'] ?? 'Customer';

    List<String> bodyValues = [customerName];
    if (defaultParam.isNotEmpty) {
      bodyValues.add(defaultParam);
    }

    try {
      final res = await ApiClient().post('/messages/send', {
        'conversationId': convId,
        'type': 'Template',
        'templateName': templateName,
        'bodyValues': bodyValues,
      });

      if (res.statusCode == 200) {
        _fetchMessages(convId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(
                    Icons.flash_on_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Template "$templateName" dispatched via MyOperator WABA!',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF008069),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        final body = jsonDecode(res.body);
        _showErrorSnackBar(body['message'] ?? 'Failed to send template');
      }
    } catch (e) {
      debugPrint('[1-Tap Template] Failed: $e');
      _showErrorSnackBar('Network error: Could not send template');
    }
  }

  Widget _buildQuickTemplateChip(
    String label,
    String templateName,
    String defaultParam,
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _sendQuickTemplateDirectly(templateName, defaultParam),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF008069).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF008069).withValues(alpha: 0.3),
            width: 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bolt_rounded, size: 13, color: Color(0xFF008069)),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 11.5,
                color: const Color(0xFF008069),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
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
    final customerName = contact['name'] ?? 'Customer';
    final TextEditingController templateNameController = TextEditingController(
      text: initialTemplateName ?? (_approvedTemplates.isNotEmpty ? (_approvedTemplates.first['name'] ?? _approvedTemplates.first['elementName'] ?? '') : ''),
    );
    final TextEditingController paramsController = TextEditingController(
      text: initialParam != null && initialParam.isNotEmpty
          ? '$customerName, $initialParam'
          : customerName,
    );
    final TextEditingController mediaUrlController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 460,
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
                'Send an approved WhatsApp Business template (WABA) to initiate or re-engage conversations outside the 24-hour window.',
                style: GoogleFonts.outfit(
                  fontSize: 12.5,
                  color: const Color(0xFF64748B),
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 20),
              if (_approvedTemplates.isNotEmpty) ...[
                StatefulBuilder(
                  builder: (context, setDialogState) {
                    final currentVal = templateNameController.text.trim();
                    final bool isInList = _approvedTemplates.any((t) =>
                        (t['name'] ?? t['elementName'] ?? '').toString() == currentVal);

                    return DropdownButtonFormField<String>(
                      value: isInList ? currentVal : (_approvedTemplates.first['name'] ?? _approvedTemplates.first['elementName'] ?? '').toString(),
                      decoration: InputDecoration(
                        labelText: 'Approved Template',
                        labelStyle: GoogleFonts.outfit(
                          color: const Color(0xFF008069),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
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
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: const Color(0xFF111B21),
                      ),
                      items: _approvedTemplates.map<DropdownMenuItem<String>>((t) {
                        final tName = (t['name'] ?? t['elementName'] ?? '').toString();
                        final lang = (t['language'] ?? t['languageCode'] ?? 'en').toString();
                        return DropdownMenuItem<String>(
                          value: tName,
                          child: Text(
                            '📄 $tName ($lang)',
                            style: GoogleFonts.outfit(fontSize: 12.5),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setDialogState(() {
                          if (val != null) {
                            templateNameController.text = val;
                          }
                        });
                      },
                    );
                  },
                ),
                const SizedBox(height: 14),
              ] else ...[
                TextField(
                  controller: templateNameController,
                  decoration: InputDecoration(
                    labelText: 'Template Name',
                    hintText: 'e.g. welcome_lead',
                    labelStyle: GoogleFonts.outfit(
                      color: const Color(0xFF008069),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
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
              ],
              TextField(
                controller: paramsController,
                decoration: InputDecoration(
                  labelText: 'Body Variables (Optional)',
                  hintText: 'Separated by commas, e.g. $customerName, Special Offer',
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
              const SizedBox(height: 14),
              TextField(
                controller: mediaUrlController,
                decoration: InputDecoration(
                  labelText: 'Header Media URL (Optional)',
                  hintText: 'e.g. https://example.com/header.png',
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
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    onPressed: () async {
                      final tName = templateNameController.text.trim();
                      if (tName.isEmpty) return;

                      final paramsText = paramsController.text.trim();
                      final List<String> bodyValues = paramsText.isNotEmpty
                          ? paramsText.split(',').map((e) => e.trim()).toList()
                          : [];
                      final mediaUrl = mediaUrlController.text.trim();

                      Navigator.pop(context);

                      try {
                        final res = await ApiClient().post('/messages/send', {
                          'conversationId': conversationId,
                          'type': 'Template',
                          'templateName': tName,
                          'bodyValues': bodyValues,
                          'mediaUrl': mediaUrl.isNotEmpty ? mediaUrl : null,
                        });
                        if (res.statusCode == 200) {
                          _fetchMessages(conversationId);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Template "$tName" dispatched successfully via MyOperator WABA',
                                ),
                                backgroundColor: const Color(0xFF008069),
                              ),
                            );
                          }
                        } else {
                          final body = jsonDecode(res.body);
                          _showErrorSnackBar(
                            body['message'] ?? 'Failed to send template',
                          );
                        }
                      } catch (e) {
                        debugPrint('[Template Send] Failed: $e');
                        _showErrorSnackBar(
                          'Network error: Could not send template',
                        );
                      }
                    },
                    child: Text(
                      'Send Template',
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
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: 720,
            height: 650,
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
                              'Create Meta-approved templates with variable placeholders ({{1}}, {{2}})',
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

                // Action Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'All Templates (${_approvedTemplates.length})',
                      style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
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
                      : _approvedTemplates.isEmpty
                          ? Center(
                              child: Text(
                                'No WhatsApp templates found. Click "+ Create New Template" to submit one for approval.',
                                style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF64748B)),
                                textAlign: TextAlign.center,
                              ),
                            )
                          : ListView.separated(
                              itemCount: _approvedTemplates.length,
                              separatorBuilder: (context, idx) => const SizedBox(height: 12),
                              itemBuilder: (context, idx) {
                                final t = _approvedTemplates[idx];
                                final name = (t['name'] ?? t['elementName'] ?? 'template').toString();
                                final category = (t['category'] ?? 'UTILITY').toString();
                                final language = (t['language'] ?? 'en').toString();
                                final body = (t['body'] ?? t['data']?['body'] ?? (t['components'] is List ? (t['components'] as List).firstWhere((c) => c['type'] == 'BODY', orElse: () => {})['text'] : null) ?? name).toString();
                                final status = (t['status'] ?? 'APPROVED').toString().toUpperCase();
                                final footer = (t['footer'] ?? '').toString();
                                final templateId = t['_id']?.toString();

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
                                          Row(
                                            children: [
                                              Text(
                                                name,
                                                style: GoogleFonts.outfit(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: const Color(0xFF0F172A),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
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
                                          if (templateId != null)
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                                              tooltip: 'Delete Template',
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                              onPressed: () async {
                                                try {
                                                  await ApiClient().delete('/templates/$templateId');
                                                  _fetchTemplates();
                                                  setDialogState(() {
                                                    _approvedTemplates.removeWhere((tpl) => tpl['_id'] == templateId);
                                                  });
                                                } catch (_) {}
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
        ),
      ),
    );
  }

  void _showCreateTemplateDialog(BuildContext context, {VoidCallback? onCreated}) {
    final nameController = TextEditingController();
    final bodyController = TextEditingController();
    final footerController = TextEditingController();
    final headerTextController = TextEditingController();
    String category = 'UTILITY';
    String language = 'en';
    String headerType = 'NONE';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: 560,
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Submit WhatsApp Template for Approval',
                        style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF111B21)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Submitted templates will be forwarded to Meta / MyOperator for automated review and approval.',
                    style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 16),

                  // Template Name
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Template Name (lowercase, e.g. harvest_update)',
                      labelStyle: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF008069), fontWeight: FontWeight.bold),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      isDense: true,
                    ),
                    style: GoogleFonts.outfit(fontSize: 13.5),
                  ),
                  const SizedBox(height: 12),

                  // Category & Language Row
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: category,
                          decoration: InputDecoration(
                            labelText: 'Category',
                            labelStyle: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF64748B)),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            isDense: true,
                          ),
                          items: const [
                            DropdownMenuItem(value: 'UTILITY', child: Text('Utility (Order/Account Updates)')),
                            DropdownMenuItem(value: 'MARKETING', child: Text('Marketing (Offers/Promotions)')),
                            DropdownMenuItem(value: 'AUTHENTICATION', child: Text('Authentication (OTPs)')),
                          ],
                          onChanged: (val) {
                            if (val != null) setDialogState(() => category = val);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: language,
                          decoration: InputDecoration(
                            labelText: 'Language',
                            labelStyle: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF64748B)),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            isDense: true,
                          ),
                          items: const [
                            DropdownMenuItem(value: 'en', child: Text('English (en)')),
                            DropdownMenuItem(value: 'hi', child: Text('Hindi (hi)')),
                            DropdownMenuItem(value: 'mr', child: Text('Marathi (mr)')),
                            DropdownMenuItem(value: 'gu', child: Text('Gujarati (gu)')),
                            DropdownMenuItem(value: 'te', child: Text('Telugu (te)')),
                            DropdownMenuItem(value: 'ta', child: Text('Tamil (ta)')),
                          ],
                          onChanged: (val) {
                            if (val != null) setDialogState(() => language = val);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Header Type
                  DropdownButtonFormField<String>(
                    value: headerType,
                    decoration: InputDecoration(
                      labelText: 'Header Type',
                      labelStyle: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF64748B)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'NONE', child: Text('None')),
                      DropdownMenuItem(value: 'TEXT', child: Text('Text Header')),
                      DropdownMenuItem(value: 'IMAGE', child: Text('Image Header')),
                      DropdownMenuItem(value: 'DOCUMENT', child: Text('PDF Document Header')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => headerType = val);
                    },
                  ),
                  if (headerType == 'TEXT') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: headerTextController,
                      decoration: InputDecoration(
                        labelText: 'Header Text',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        isDense: true,
                      ),
                      style: GoogleFonts.outfit(fontSize: 13.5),
                    ),
                  ],
                  const SizedBox(height: 12),

                  // Body Text
                  TextField(
                    controller: bodyController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: 'Template Body Text',
                      hintText: 'Namaste {{1}}, your Krishi Kranti order #{{2}} is confirmed for dispatch!',
                      helperText: 'Use {{1}}, {{2}} for dynamic contact variables (Name, Order ID, Price)',
                      labelStyle: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF008069), fontWeight: FontWeight.bold),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    style: GoogleFonts.outfit(fontSize: 13.5),
                  ),
                  const SizedBox(height: 12),

                  // Footer Text
                  TextField(
                    controller: footerController,
                    decoration: InputDecoration(
                      labelText: 'Footer (Optional, e.g. Krishi Kranti Organics)',
                      labelStyle: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF64748B)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      isDense: true,
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
                          final name = nameController.text.trim();
                          final body = bodyController.text.trim();
                          if (name.isEmpty || body.isEmpty) return;

                          Navigator.pop(context);

                          try {
                            final res = await ApiClient().post('/templates', {
                              'name': name,
                              'category': category,
                              'language': language,
                              'headerType': headerType,
                              'headerText': headerTextController.text.trim(),
                              'body': body,
                              'footer': footerController.text.trim(),
                            });

                            if (res.statusCode == 200) {
                              await _fetchTemplates();
                              onCreated?.call();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Template submitted for Meta/MyOperator review!'),
                                    backgroundColor: Color(0xFF008069),
                                  ),
                                );
                              }
                            }
                          } catch (e) {
                            debugPrint('[Create Template] Error: $e');
                          }
                        },
                        child: Text('Submit for Approval', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 📞 CUSTOMER TELEPHONY TIMELINE & MYOPERATOR RECORDING VAULT MODAL
  // ══════════════════════════════════════════════════════════════════════════
  void _showCustomerCallHistoryDrawer(BuildContext context, String rawPhone, String customerName) {
    final cleanPhone = rawPhone.replaceAll(RegExp(r'\D'), '').replaceFirst(RegExp(r'^91'), '');
    List<dynamic> customerCalls = [];
    bool isLoading = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDlgState) {
          if (isLoading) {
            ApiClient().get('/call/logs?search=$cleanPhone&limit=50').then((res) {
              if (res.statusCode == 200) {
                final body = jsonDecode(res.body);
                final logs = body['data']?['callLogs'] ?? body['data'] ?? [];
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
              width: 580,
              height: 600,
              padding: const EdgeInsets.all(24),
              child: Column(
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
                            child: const Icon(Icons.phone_in_talk_rounded, color: Color(0xFF008069), size: 20),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Call History: $customerName',
                                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: const Color(0xFF111B21)),
                              ),
                              Text(
                                '+91 $cleanPhone · MyOperator Telephony Audit',
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
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF008069)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Due to MyOperator portal security, recordings can be accessed directly in the MyOperator console with 1-click.',
                            style: GoogleFonts.outfit(fontSize: 11.5, color: const Color(0xFF475569)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: isLoading
                        ? const Center(child: CircularProgressIndicator(color: Color(0xFF008069)))
                        : customerCalls.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.phone_disabled_rounded, size: 48, color: Color(0xFFCBD5E1)),
                                    const SizedBox(height: 12),
                                    Text('No call records found for this number', style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF64748B))),
                                  ],
                                ),
                              )
                            : ListView.separated(
                                itemCount: customerCalls.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 8),
                                itemBuilder: (ctx, i) {
                                  final call = customerCalls[i];
                                  final status = (call['status'] ?? 'initiated').toString().toLowerCase();
                                  final duration = int.tryParse((call['durationSeconds'] ?? 0).toString()) ?? 0;
                                  final mins = duration ~/ 60;
                                  final secs = duration % 60;
                                  final durText = duration > 0 ? '${mins}m ${secs}s' : '0s';
                                  final isOutbound = (call['direction'] ?? 'outbound').toString().toLowerCase() == 'outbound';
                                  final agent = call['agentId'];
                                  final agentName = agent is Map ? '${agent['firstName'] ?? ''} ${agent['lastName'] ?? ''}'.trim() : 'Agent';
                                  final rawDate = call['createdAt'];
                                  final dateText = rawDate != null ? DateFormat('dd MMM, hh:mm a').format(DateTime.parse(rawDate.toString()).toLocal()) : '';
                                  final userDisp = (call['userDisposition'] ?? call['disposition'] ?? '').toString().trim();
                                  final notes = (call['notes'] ?? '').toString().trim();

                                  return Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
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
                                                Icon(
                                                  isOutbound ? Icons.call_made_rounded : Icons.call_received_rounded,
                                                  size: 16,
                                                  color: isOutbound ? const Color(0xFF008069) : Colors.blue,
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  isOutbound ? 'Outbound Call' : 'Inbound Call',
                                                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13, color: const Color(0xFF1E293B)),
                                                ),
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: status == 'answered' || status == 'completed'
                                                        ? const Color(0xFFE8F5E9)
                                                        : const Color(0xFFFFEBEE),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    status.toUpperCase(),
                                                    style: GoogleFonts.outfit(
                                                      fontSize: 9.5,
                                                      fontWeight: FontWeight.bold,
                                                      color: status == 'answered' || status == 'completed'
                                                          ? const Color(0xFF2E7D32)
                                                          : const Color(0xFFC62828),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Text(
                                              dateText,
                                              style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF64748B)),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Text('⏱ Duration: $durText', style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF475569))),
                                            const SizedBox(width: 14),
                                            Text('👤 Agent: $agentName', style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF475569))),
                                          ],
                                        ),
                                        if (userDisp.isNotEmpty || notes.isNotEmpty) ...[
                                          const SizedBox(height: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFFF9E6),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              '📝 ${userDisp.isNotEmpty ? userDisp : ''}${notes.isNotEmpty ? ' · $notes' : ''}',
                                              style: GoogleFonts.outfit(fontSize: 11.5, color: const Color(0xFF5D4037), fontWeight: FontWeight.w500),
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            TextButton.icon(
                                              style: TextButton.styleFrom(
                                                foregroundColor: const Color(0xFF008069),
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              ),
                                              icon: const Icon(Icons.open_in_new_rounded, size: 13),
                                              label: Text(
                                                'Listen in MyOperator Panel',
                                                style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.bold),
                                              ),
                                              onPressed: () async {
                                                await Clipboard.setData(ClipboardData(text: cleanPhone));
                                                final url = Uri.parse('https://in.app.myoperator.com/log');
                                                if (await canLaunchUrl(url)) {
                                                  await launchUrl(url, mode: LaunchMode.externalApplication);
                                                }
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
}
