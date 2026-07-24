import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:kd_pannel/app_theme.dart';
import 'package:kd_pannel/core/auth/auth_service.dart';
import 'package:kd_pannel/core/network/api_client.dart';
import 'package:kd_pannel/core/network/websocket_service.dart';
import 'package:kd_pannel/core/responsive/responsive.dart';

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

  @override
  void initState() {
    super.initState();
    _fetchConversations();
    _fetchSalesAgents();
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
                  _buildFilterTab('open', 'Open'),
                  const SizedBox(width: 6),
                  _buildFilterTab('closed', 'Closed'),
                  const SizedBox(width: 6),
                  _buildFilterTab('snoozed', 'Snoozed'),
                  const SizedBox(width: 6),
                  _buildFilterTab('cart', '🛒 Cart Pending'),
                  const SizedBox(width: 6),
                  _buildFilterTab('payment', '💳 Payment Due'),
                  const SizedBox(width: 6),
                  _buildFilterTab('restock', '📦 Restock Due'),
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

          // Quick Template Chips Bar for Sales Representatives (Mouse & Touch Drag Enabled)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.only(top: 8, left: 16, right: 16),
            height: 36,
            child: ScrollConfiguration(
              behavior: WebCustomScrollBehavior(),
              child: ListView(
                controller: _quickChipScrollController,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                children: [
                  _buildQuickTemplateChip(
                    '👋 Day 1 Welcome',
                    'welcome_dealer_catalog',
                    'Welcome & Catalog',
                  ),
                  const SizedBox(width: 8),
                  _buildQuickTemplateChip(
                    '🔥 Day 2 Best Sellers',
                    'bestseller_pricing_update',
                    'Best Seller Pricing',
                  ),
                  const SizedBox(width: 8),
                  _buildQuickTemplateChip(
                    '🛒 Cart Alert',
                    'abandoned_cart_alert',
                    'Items Pending',
                  ),
                  const SizedBox(width: 8),
                  _buildQuickTemplateChip(
                    '💳 Payment Reminder',
                    'payment_invoice_reminder',
                    'Invoice Due',
                  ),
                  const SizedBox(width: 8),
                  _buildQuickTemplateChip(
                    '🚚 Order Dispatch',
                    'order_dispatch_tracking',
                    'Order Dispatched',
                  ),
                  const SizedBox(width: 8),
                  _buildQuickTemplateChip(
                    '📦 30d Restock Alert',
                    'dealer_stock_replenishment',
                    'Restock Reminder',
                  ),
                  const SizedBox(width: 8),
                  _buildQuickTemplateChip(
                    '🎁 Special Discount',
                    'exclusive_dealer_discount',
                    'Exclusive Offer',
                  ),
                ],
              ),
            ),
          ),

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
                    'End-to-end encrypted Interakt API session',
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

  // ⚡ Smart Retargeting Outreach Recommendation Banner for Sales Reps
  Widget _buildSmartOutreachBanner() {
    if (_selectedConversation == null) return const SizedBox();
    final contact = _selectedConversation['contactId'] ?? {};
    final customerName = contact['name'] ?? 'Customer';

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
                    'Recommended Action: Send Day 1 Welcome & Catalog to $customerName',
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
              'welcome_dealer_catalog',
              'Welcome Catalog',
            ),
          ),
        ],
      ),
    );
  }

  // 1-Tap Zero-Effort Template Dispatcher
  Future<void> _sendQuickTemplateDirectly(
    String templateName,
    String defaultParam,
  ) async {
    if (_selectedConversation == null) return;
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
                    'Outreach Template sent in 1-Tap!',
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
      text: initialTemplateName ?? 'welcome_dealer_catalog',
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
                        child: const Icon(
                          Icons.quickreply_rounded,
                          color: Color(0xFF008069),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Send Approved Template',
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
                'Select a pre-approved Interakt template. Recipient name and parameters are pre-filled automatically.',
                style: GoogleFonts.outfit(
                  fontSize: 12.5,
                  color: const Color(0xFF64748B),
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 20),
              StatefulBuilder(
                builder: (context, setDialogState) {
                  final Map<String, String> approvedTemplates = {
                    'welcome_dealer_catalog': '👋 Day 1 Welcome & Catalog',
                    'bestseller_pricing_update':
                        '🔥 Day 2 Best Sellers & Pricing',
                    'abandoned_cart_alert': '🛒 Abandoned Cart Alert',
                    'payment_invoice_reminder': '💳 Payment & Invoice Reminder',
                    'order_dispatch_tracking': '🚚 Order Dispatch & Tracking',
                    'dealer_stock_replenishment': '📦 30d Restock Alert',
                    'exclusive_dealer_discount': '🎁 Special Dealer Discount',
                  };
                  String selectedKey =
                      approvedTemplates.containsKey(templateNameController.text)
                      ? templateNameController.text
                      : 'welcome_dealer_catalog';

                  return DropdownButtonFormField<String>(
                    initialValue: selectedKey,
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
                    items: approvedTemplates.entries.map((e) {
                      return DropdownMenuItem<String>(
                        value: e.key,
                        child: Text(
                          e.value,
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
              TextField(
                controller: paramsController,
                decoration: InputDecoration(
                  labelText: 'Body Variables (Optional)',
                  hintText: 'Separated by commas, e.g. John, 1000',
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
                              const SnackBar(
                                content: Text(
                                  'Template message sent successfully',
                                ),
                                backgroundColor: Color(0xFF008069),
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
}
