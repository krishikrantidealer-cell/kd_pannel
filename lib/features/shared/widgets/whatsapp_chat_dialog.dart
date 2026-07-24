import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:kd_pannel/app_theme.dart';
import 'package:kd_pannel/core/auth/auth_service.dart';
import 'package:kd_pannel/core/network/api_client.dart';
import 'package:kd_pannel/core/network/websocket_service.dart';

class WhatsAppChatDialog extends StatefulWidget {
  final String phone;
  final String name;

  const WhatsAppChatDialog({
    super.key,
    required this.phone,
    required this.name,
  });

  @override
  State<WhatsAppChatDialog> createState() => _WhatsAppChatDialogState();
}

class _WhatsAppChatDialogState extends State<WhatsAppChatDialog> with SingleTickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  dynamic _conversation;
  List<dynamic> _messages = [];
  bool _isLoading = true;
  bool _isNotesMode = false;
  StreamSubscription? _websocketSubscription;

  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _startOrGetConversation();
    _setupWebSocketListener();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _websocketSubscription?.cancel();
    _messageController.dispose();
    _noteController.dispose();
    _scrollController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _setupWebSocketListener() {
    _websocketSubscription = WebSocketService().chatUpdates.listen((event) {
      if (!mounted || _conversation == null) return;
      final type = event['type'];
      final data = event['data'];

      if (type == 'NEW_MESSAGE') {
        final newMessage = data['message'];
        final conversationId = newMessage['conversationId']?.toString();

        if (_conversation != null && conversationId == _conversation['_id']?.toString()) {
          final hasMsg = _messages.any((m) => m['_id']?.toString() == newMessage['_id']?.toString());
          if (!hasMsg) {
            setState(() {
              _messages.add(newMessage);
            });
            _scrollToBottom();
          }
        }
      } else if (type == 'MESSAGE_STATUS_UPDATED') {
        final conversationId = data['conversationId']?.toString();
        final messageId = data['messageId']?.toString();
        final status = data['status'];

        if (_conversation != null && conversationId == _conversation['_id']?.toString()) {
          setState(() {
            final index = _messages.indexWhere((m) => m['_id']?.toString() == messageId);
            if (index != -1) {
              _messages[index]['status'] = status;
            }
          });
        }
      }
    });
  }

  Future<void> _startOrGetConversation() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final res = await ApiClient().post('/conversations/start', {
        'phone': widget.phone,
        'name': widget.name,
      });

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true && body['data'] != null) {
          _conversation = body['data'];
          await _fetchMessages();
        }
      }
    } catch (e) {
      debugPrint('[WhatsApp Chat Dialog] Error starting conversation: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchMessages() async {
    if (_conversation == null) return;
    try {
      final res = await ApiClient().get('/conversations/${_conversation['_id']}/messages?limit=50');
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true && body['data'] != null) {
          setState(() {
            _messages = List<dynamic>.from(body['data']);
          });
          _scrollToBottom();
        }
      }
    } catch (e) {
      debugPrint('[WhatsApp Chat Dialog] Error fetching messages: $e');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _conversation == null) return;
    final text = _messageController.text.trim();
    _messageController.clear();

    try {
      await ApiClient().post('/messages/send', {
        'conversationId': _conversation['_id'],
        'type': 'Text',
        'content': text,
      });
      _fetchMessages();
    } catch (e) {
      debugPrint('[WhatsApp Chat Dialog] Error sending message: $e');
    }
  }

  Future<void> _addNote() async {
    if (_noteController.text.trim().isEmpty || _conversation == null) return;
    final noteText = _noteController.text.trim();
    _noteController.clear();

    try {
      final res = await ApiClient().post('/notes', {
        'conversationId': _conversation['_id'],
        'note': noteText,
      });
      if (res.statusCode == 201) {
        _fetchMessages();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.lock, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Text('Internal note added successfully', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                ],
              ),
              backgroundColor: AppTheme.warning,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[WhatsApp Chat Dialog] Error adding note: $e');
    }
  }

  Future<void> _updateLanguage(String langCode) async {
    if (_conversation == null) return;
    final convId = _conversation['_id'];
    try {
      final res = await ApiClient().put('/conversations/$convId/language', {
        'preferredLanguage': langCode,
      });
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        setState(() {
          _conversation = body['data'];
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Language updated to ${langCode.toUpperCase()}'),
              backgroundColor: const Color(0xFF008069),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[WhatsApp Chat Dialog] Error updating language: $e');
    }
  }

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
          if (interactive is Map && interactive.containsKey('button_reply') && interactive['button_reply'] is Map) {
            final title = interactive['button_reply']['title']?.toString();
            if (title != null && title.isNotEmpty) return title;
          }
          if (interactive is Map && interactive.containsKey('list_reply') && interactive['list_reply'] is Map) {
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
      return const Icon(Icons.done_all, size: 12, color: Color(0xFF53BDEB)); // WhatsApp Web read status blue check
    }
    return const Icon(Icons.check, size: 12, color: Color(0xFF8696A0));
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;
    
    final bool isLargeScreen = screenWidth > 900;
    
    final Widget mainBody = Material(
      color: Colors.transparent,
      child: Container(
        width: isLargeScreen ? 480 : screenWidth * 0.92,
      height: isLargeScreen ? screenHeight * 0.90 : screenHeight * 0.80,
      decoration: BoxDecoration(
        color: const Color(0xFFE5DDD5), // Classic WhatsApp Chat background beige
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // WhatsApp Official Deep Green Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: const Color(0xFF008069), // Official WhatsApp Green
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.white24,
                  radius: 19,
                  child: Text(
                    widget.name.isNotEmpty ? widget.name.substring(0, 1).toUpperCase() : '👤',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.name,
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Row(
                        children: [
                          Text(
                            '+${widget.phone}',
                            style: GoogleFonts.outfit(
                              fontSize: 11.5,
                              color: Colors.white.withValues(alpha: 0.9),
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          if (!AuthService().isSales && _conversation != null && _conversation['assignedTo'] != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              '• Assigned: ${_conversation['assignedTo']['firstName'] ?? ''} ${_conversation['assignedTo']['lastName'] ?? ''}'.trim(),
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                color: Colors.white.withValues(alpha: 0.85),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // 6-Language Switcher Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: DropdownButton<String>(
                    value: ['en', 'hi', 'ta', 'te', 'mr', 'kn'].contains(_conversation?['contactId']?['preferredLanguage'])
                        ? _conversation?['contactId']?['preferredLanguage']
                        : 'en',
                    style: GoogleFonts.outfit(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                    dropdownColor: const Color(0xFF008069),
                    underline: const SizedBox(),
                    icon: const Icon(Icons.arrow_drop_down, size: 16, color: Colors.white),
                    isDense: true,
                    items: const [
                      DropdownMenuItem(value: 'en', child: Text('EN (English)')),
                      DropdownMenuItem(value: 'hi', child: Text('HI (हिन्दी)')),
                      DropdownMenuItem(value: 'ta', child: Text('TA (தமிழ்)')),
                      DropdownMenuItem(value: 'te', child: Text('TE (తెలుగు)')),
                      DropdownMenuItem(value: 'mr', child: Text('MR (मराठी)')),
                      DropdownMenuItem(value: 'kn', child: Text('KN (ಕನ್ನಡ)')),
                    ],
                    onChanged: (val) {
                      if (val != null) _updateLanguage(val);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white12,
                    hoverColor: Colors.white24,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Message Logs Scroll Area with Doodle pattern styling
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF008069)))
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: const BoxDecoration(
                                color: Colors.white24,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.chat_bubble_outline_rounded,
                                size: 32,
                                color: Color(0xFF008069),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'WhatsApp Conversation',
                              style: GoogleFonts.outfit(
                                color: const Color(0xFF111B21),
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Send a message to start chatting.',
                              style: GoogleFonts.outfit(
                                color: const Color(0xFF667781),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final isOutgoing = msg['direction'] == 'outgoing';
                          final type = msg['type'];
                          final isNote = msg['isNote'] == true;
                          
                          final date = DateTime.parse(msg['createdAt']).toLocal();
                          final formattedTime = DateFormat('hh:mm a').format(date);

                          // WhatsApp Bubble styling
                          BoxDecoration bubbleDecoration;
                          Color textCol = const Color(0xFF111B21);
                          
                          if (isNote) {
                            bubbleDecoration = BoxDecoration(
                              color: const Color(0xFFFFF9E6),
                              borderRadius: const BorderRadius.all(Radius.circular(8)),
                              border: Border.all(color: const Color(0xFFFFE082), width: 0.8),
                            );
                            textCol = const Color(0xFF5D4037);
                          } else if (isOutgoing) {
                            bubbleDecoration = const BoxDecoration(
                              color: Color(0xFFD9FDD3), // Official WhatsApp light green bubble
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(8),
                                topRight: Radius.circular(8),
                                bottomLeft: Radius.circular(8),
                                bottomRight: Radius.zero,
                              ),
                            );
                          } else {
                            bubbleDecoration = const BoxDecoration(
                              color: Colors.white, // Official WhatsApp white bubble
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(8),
                                topRight: Radius.circular(8),
                                bottomLeft: Radius.zero,
                                bottomRight: Radius.circular(8),
                              ),
                            );
                          }

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Align(
                              alignment: isOutgoing ? Alignment.centerRight : Alignment.centerLeft,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: bubbleDecoration,
                                constraints: BoxConstraints(
                                  maxWidth: isLargeScreen ? 340 : screenWidth * 0.70,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isNote)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 4.0),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.lock_outline_rounded, size: 10, color: Colors.orange),
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
                                            if (msg['sentBy'] != null && msg['sentBy'] is Map)
                                              Text(
                                                '${msg['sentBy']['firstName'] ?? ''} ${msg['sentBy']['lastName'] ?? ''}'.trim().toUpperCase(),
                                                style: GoogleFonts.outfit(
                                                  fontSize: 8.5,
                                                  fontWeight: FontWeight.w800,
                                                  color: Colors.orange[800],
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    if (!isNote && isOutgoing && msg['sentBy'] != null && msg['sentBy'] is Map)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 4.0),
                                        child: Text(
                                          '${msg['sentBy']['firstName'] ?? ''} ${msg['sentBy']['lastName'] ?? ''}'.trim().toUpperCase(),
                                          style: GoogleFonts.outfit(
                                            fontSize: 8.5,
                                            fontWeight: FontWeight.w800,
                                            color: const Color(0xFF008069),
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                    if (msg['mediaUrl'] != null && msg['mediaUrl'].toString().trim().isNotEmpty) ...[
                                      if (msg['mediaUrl'].toString().toLowerCase().contains('.png') ||
                                          msg['mediaUrl'].toString().toLowerCase().contains('.jpg') ||
                                          msg['mediaUrl'].toString().toLowerCase().contains('.jpeg') ||
                                          msg['mediaUrl'].toString().toLowerCase().contains('.webp') ||
                                          type == 'image')
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 6.0),
                                          child: InkWell(
                                            onTap: () async {
                                              final url = Uri.tryParse(msg['mediaUrl'].toString());
                                              if (url != null && await canLaunchUrl(url)) {
                                                await launchUrl(url, mode: LaunchMode.externalApplication);
                                              }
                                            },
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(6),
                                              child: Image.network(
                                                msg['mediaUrl'],
                                                fit: BoxFit.cover,
                                                height: 180,
                                                width: double.infinity,
                                                errorBuilder: (context, error, stackTrace) => const SizedBox(),
                                              ),
                                            ),
                                          ),
                                        )
                                      else
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 6.0),
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(6),
                                            onTap: () async {
                                              final url = Uri.tryParse(msg['mediaUrl'].toString());
                                              if (url != null && await canLaunchUrl(url)) {
                                                await launchUrl(url, mode: LaunchMode.externalApplication);
                                              }
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withValues(alpha: 0.05),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.description_rounded, color: Color(0xFF008069), size: 20),
                                                  const SizedBox(width: 8),
                                                  Flexible(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          'Attachment (Tap to view)',
                                                          style: GoogleFonts.outfit(
                                                            fontSize: 12,
                                                            color: const Color(0xFF008069),
                                                            fontWeight: FontWeight.w600,
                                                          ),
                                                        ),
                                                        Text(
                                                          msg['mediaUrl'].toString().split('/').last.split('?').first,
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                          style: GoogleFonts.outfit(
                                                            fontSize: 10,
                                                            color: Colors.grey[700],
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  const Icon(Icons.open_in_new_rounded, color: Color(0xFF008069), size: 15),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                    Text(
                                      _formatCleanMessageText(msg['content'] ?? ''),
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
                                          _buildMessageStatusIcon(msg['status'] ?? 'sent'),
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
          ),
          
          // Segment switcher for CRM note vs WhatsApp
          Container(
            color: const Color(0xFFF0F2F5), // WhatsApp Web input bar background
            padding: const EdgeInsets.only(top: 8, left: 16, right: 16),
            child: Container(
              height: 32,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.05),
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
                          color: !_isNotesMode ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'WhatsApp Message',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: !_isNotesMode ? const Color(0xFF008069) : const Color(0xFF667781),
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
                          color: _isNotesMode ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Internal Note',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _isNotesMode ? Colors.amber[800] : const Color(0xFF667781),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // WhatsApp Web Styled Input Bar
          Container(
            padding: const EdgeInsets.only(left: 12, right: 16, bottom: 16, top: 8),
            color: const Color(0xFFF0F2F5), // WhatsApp Web input bar background
            child: Row(
              children: [
                // Smiley Icon
                // Smiley Icon
                PopupMenuButton<String>(
                  icon: const Icon(Icons.insert_emoticon_rounded, color: Color(0xFF54656F), size: 24),
                  tooltip: 'Insert Emoji',
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
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: ['👋', '👍', '😊', '🙏', '✅', '🛒', '📞', '⭐', '🚚', '🎉'].map((emoji) {
                          return InkWell(
                            onTap: () {
                              Navigator.pop(context, emoji);
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(6.0),
                              child: Text(emoji, style: const TextStyle(fontSize: 20)),
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
                  icon: const Icon(Icons.add_rounded, color: Color(0xFF54656F), size: 24),
                  tooltip: 'Attach Media',
                  onSelected: (value) {
                    _showAttachmentDialog(context, value);
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'Image',
                      child: Row(
                        children: [
                          const Icon(Icons.image_rounded, color: Color(0xFF008069), size: 18),
                          const SizedBox(width: 8),
                          Text('Send Image via URL', style: GoogleFonts.outfit(fontSize: 13)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'Document',
                      child: Row(
                        children: [
                          const Icon(Icons.insert_drive_file_rounded, color: Color(0xFF008069), size: 18),
                          const SizedBox(width: 8),
                          Text('Send Document via URL', style: GoogleFonts.outfit(fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                // Template Icon
                IconButton(
                  icon: const Icon(Icons.quickreply_rounded, color: Color(0xFF54656F), size: 23),
                  onPressed: () {
                    if (_conversation != null) {
                      _showSendTemplateDialog(context, _conversation['_id']);
                    }
                  },
                  tooltip: 'Send Approved Template',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 12),
                
                Expanded(
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    alignment: Alignment.centerLeft,
                    child: _isNotesMode
                        ? TextField(
                            controller: _noteController,
                            style: GoogleFonts.outfit(fontSize: 13.5, color: const Color(0xFF5D4037)),
                            decoration: const InputDecoration(
                              hintText: 'Add an internal note only agents see...',
                              hintStyle: TextStyle(color: Colors.grey, fontSize: 13),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                            onSubmitted: (_) => _addNote(),
                          )
                        : TextField(
                            controller: _messageController,
                            style: GoogleFonts.outfit(fontSize: 13.5, color: const Color(0xFF111B21)),
                            decoration: const InputDecoration(
                              hintText: 'Type a message',
                              hintStyle: TextStyle(color: Colors.grey, fontSize: 13),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                            onSubmitted: (_) => _sendMessage(),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                
                // Send Circle Button
                GestureDetector(
                  onTap: _isNotesMode ? _addNote : _sendMessage,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: _isNotesMode ? Colors.amber[700] : const Color(0xFF00A884), // Official WhatsApp send teal-green
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.send_rounded, color: Colors.white, size: 15),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),);

    if (isLargeScreen) {
      // Slides in from the right hand side on Desktop
      return Stack(
        children: [
          Positioned(
            right: 20,
            top: 20,
            bottom: 20,
            child: mainBody,
          ),
        ],
      );
    }
    
    return Center(child: mainBody);
  }

  void _showSendTemplateDialog(BuildContext context, String conversationId) {
    final TextEditingController templateNameController = TextEditingController(text: 'welcome_lead');
    final TextEditingController paramsController = TextEditingController();
    final TextEditingController mediaUrlController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Send WhatsApp Template',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'To initiate contact outside the 24-hour window, you must send an approved template.',
              style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: templateNameController,
              decoration: const InputDecoration(
                labelText: 'Template Name',
                hintText: 'e.g. welcome_lead',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              style: GoogleFonts.outfit(fontSize: 13.5),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: paramsController,
              decoration: const InputDecoration(
                labelText: 'Body Variables (Optional)',
                hintText: 'Separated by commas, e.g. John, 1000',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              style: GoogleFonts.outfit(fontSize: 13.5),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: mediaUrlController,
              decoration: const InputDecoration(
                labelText: 'Header Image/Doc URL (Optional)',
                hintText: 'e.g. https://example.com/image.png',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              style: GoogleFonts.outfit(fontSize: 13.5),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.outfit(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF008069),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
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
                  _fetchMessages();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Template message sent successfully'), backgroundColor: Color(0xFF008069)),
                    );
                  }
                }
              } catch (e) {
                debugPrint('[Template Send] Failed: $e');
              }
            },
            child: Text('Send Template', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showAttachmentDialog(BuildContext context, String mediaType) {
    final TextEditingController urlController = TextEditingController();
    final TextEditingController captionController = TextEditingController();
    final String label = mediaType == 'Image' ? 'Image URL' : 'Document URL';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Send WhatsApp $mediaType',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter the public URL of the $mediaType you want to send.',
              style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: urlController,
              decoration: InputDecoration(
                labelText: label,
                hintText: mediaType == 'Image'
                    ? 'https://example.com/image.jpg'
                    : 'https://example.com/document.pdf',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              style: GoogleFonts.outfit(fontSize: 13.5),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: captionController,
              decoration: const InputDecoration(
                labelText: 'Caption (Optional)',
                hintText: 'e.g. Please check this document.',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              style: GoogleFonts.outfit(fontSize: 13.5),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.outfit(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF008069),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            onPressed: () async {
              final url = urlController.text.trim();
              if (url.isEmpty) return;
              final caption = captionController.text.trim();

              Navigator.pop(context);

              try {
                if (_conversation == null) return;
                final conversationId = _conversation['_id'];

                final res = await ApiClient().post('/messages/send', {
                  'conversationId': conversationId,
                  'type': mediaType,
                  'content': caption,
                  'mediaUrl': url,
                });
                if (res.statusCode == 200) {
                  _fetchMessages();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('$mediaType message sent successfully'), backgroundColor: const Color(0xFF008069)),
                    );
                  }
                }
              } catch (e) {
                debugPrint('[$mediaType Send] Failed: $e');
              }
            },
            child: Text('Send', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
