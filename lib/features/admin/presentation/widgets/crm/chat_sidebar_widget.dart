import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:kd_pannel/features/admin/data/models/conversation_model.dart';

/// Modular, high-performance conversation sidebar
class ChatSidebarWidget extends StatelessWidget {
  final List<ConversationModel> conversations;
  final ConversationModel? selectedConversation;
  final String selectedStatusFilter;
  final bool isLoading;
  final TextEditingController searchController;
  final Function(String query)? onSearchChanged;
  final Function(String status)? onStatusFilterChanged;
  final Function(ConversationModel conversation) onConversationSelected;

  const ChatSidebarWidget({
    super.key,
    required this.conversations,
    this.selectedConversation,
    this.selectedStatusFilter = 'open',
    this.isLoading = false,
    required this.searchController,
    this.onSearchChanged,
    this.onStatusFilterChanged,
    required this.onConversationSelected,
  });

  Color _getAvatarColor(String name) {
    final colors = [
      const Color(0xFFE57373),
      const Color(0xFFF06292),
      const Color(0xFFBA68C8),
      const Color(0xFF9575CD),
      const Color(0xFF7986CB),
      const Color(0xFF64B5F6),
      const Color(0xFF4FC3F7),
      const Color(0xFF4DD0E1),
      const Color(0xFF4DB6AC),
      const Color(0xFF81C784),
      const Color(0xFFFFB74D),
    ];
    if (name.isEmpty) return const Color(0xFF008069);
    final hash = name.codeUnits.fold(0, (prev, element) => prev + element);
    return colors[hash % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 340,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Column(
        children: [
          // ── Header Bar with Title & Status Tabs ───────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFFF8FAFC),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Conversations',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF111B21),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF008069).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${conversations.length} Active',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF008069),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Search Bar
                TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText: 'Search chats or phone...',
                    hintStyle: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF94A3B8)),
                    prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF008069), size: 18),
                    suffixIcon: searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF64748B)),
                            onPressed: () {
                              searchController.clear();
                              onSearchChanged?.call('');
                            },
                          )
                        : null,
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  onChanged: onSearchChanged,
                ),
                const SizedBox(height: 10),

                // Status Filter Pills (Open, Closed, Snoozed)
                Row(
                  children: [
                    for (final status in ['open', 'closed', 'snoozed'])
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(
                            status.toUpperCase(),
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: selectedStatusFilter == status ? Colors.white : const Color(0xFF475569),
                            ),
                          ),
                          selected: selectedStatusFilter == status,
                          selectedColor: const Color(0xFF008069),
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          onSelected: (selected) {
                            if (selected) onStatusFilterChanged?.call(status);
                          },
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // ── Conversation List Feed ─────────────────────────────────────────
          Expanded(
            child: isLoading && conversations.isEmpty
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF008069)))
                : conversations.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.chat_bubble_outline_rounded, size: 36, color: Color(0xFF94A3B8)),
                            const SizedBox(height: 8),
                            Text(
                              'No conversations found',
                              style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: conversations.length,
                        separatorBuilder: (ctx, i) => const Divider(height: 1, indent: 68, color: Color(0xFFF1F5F9)),
                        itemBuilder: (context, index) {
                          final conv = conversations[index];
                          final isSelected = selectedConversation?.id == conv.id;
                          final displayName = conv.customerName?.isNotEmpty == true
                              ? conv.customerName!
                              : '+${conv.customerPhone}';
                          final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'C';
                          final lastMsg = conv.lastMessage?.text ?? 'No messages yet';
                          final timeStr = DateFormat('hh:mm a').format(conv.updatedAt);

                          return InkWell(
                            onTap: () => onConversationSelected(conv),
                            child: Container(
                              color: isSelected ? const Color(0xFFF0FDF4) : Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: _getAvatarColor(displayName),
                                    child: Text(
                                      initial,
                                      style: GoogleFonts.outfit(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Flexible(
                                              child: Text(
                                                displayName,
                                                style: GoogleFonts.outfit(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13.5,
                                                  color: const Color(0xFF111B21),
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Text(
                                              timeStr,
                                              style: GoogleFonts.outfit(
                                                fontSize: 11,
                                                color: const Color(0xFF64748B),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Flexible(
                                              child: Text(
                                                lastMsg,
                                                style: GoogleFonts.outfit(
                                                  fontSize: 12,
                                                  color: const Color(0xFF64748B),
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (conv.unreadCount > 0)
                                              Container(
                                                padding: const EdgeInsets.all(5),
                                                decoration: const BoxDecoration(
                                                  color: Color(0xFF25D366),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Text(
                                                  '${conv.unreadCount}',
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
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
