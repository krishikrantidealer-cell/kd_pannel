import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Modular, versatile input bar supporting WhatsApp messages, templates, and internal CRM notes
class ChatInputBar extends StatefulWidget {
  final bool isNotesMode;
  final bool isSending;
  final List<dynamic> cannedResponses;
  final ValueChanged<bool> onNotesModeChanged;
  final Function(String text, bool isNote) onSend;
  final VoidCallback? onOpenTemplates;
  final VoidCallback? onAttachMedia;

  const ChatInputBar({
    super.key,
    this.isNotesMode = false,
    this.isSending = false,
    this.cannedResponses = const [],
    required this.onNotesModeChanged,
    required this.onSend,
    this.onOpenTemplates,
    this.onAttachMedia,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final TextEditingController _textController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _handleSend() {
    final text = _textController.text.trim();
    if (text.isEmpty || widget.isSending) return;
    widget.onSend(text, widget.isNotesMode);
    _textController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: widget.isNotesMode ? const Color(0xFFFFFBEB) : const Color(0xFFF0F2F5),
        border: const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Quick Action Bar (Mode Toggle, Templates, Canned Chips) ─────────
          Row(
            children: [
              // Toggle: WhatsApp Message vs Internal Note
              InkWell(
                onTap: () => widget.onNotesModeChanged(!widget.isNotesMode),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: widget.isNotesMode ? const Color(0xFFD97706) : Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: widget.isNotesMode ? const Color(0xFFD97706) : const Color(0xFFCBD5E1),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        widget.isNotesMode ? Icons.lock_clock_rounded : Icons.lock_open_rounded,
                        size: 13,
                        color: widget.isNotesMode ? Colors.white : const Color(0xFF475569),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.isNotesMode ? 'INTERNAL NOTE' : 'WHATSAPP MSG',
                        style: GoogleFonts.outfit(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: widget.isNotesMode ? Colors.white : const Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Templates trigger button
              if (!widget.isNotesMode && widget.onOpenTemplates != null)
                OutlinedButton.icon(
                  onPressed: widget.onOpenTemplates,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFF008069)),
                    foregroundColor: const Color(0xFF008069),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  icon: const Icon(Icons.bolt_rounded, size: 14),
                  label: Text('Templates', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold)),
                ),

              const SizedBox(width: 8),

              // Canned responses horizontal chip preview
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final canned in widget.cannedResponses.take(4))
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ActionChip(
                            label: Text(
                              (canned['shortcut'] ?? canned['title'] ?? 'Quick').toString(),
                              style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF334155)),
                            ),
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            onPressed: () {
                              final text = (canned['message'] ?? canned['text'] ?? '').toString();
                              if (text.isNotEmpty) {
                                _textController.text = text;
                              }
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // ── Text Input Field & Send Action ─────────────────────────────────
          Row(
            children: [
              if (!widget.isNotesMode && widget.onAttachMedia != null)
                IconButton(
                  icon: const Icon(Icons.attach_file_rounded, color: Color(0xFF64748B)),
                  tooltip: 'Attach PDF / Image',
                  onPressed: widget.onAttachMedia,
                ),

              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: widget.isNotesMode ? const Color(0xFFFDE68A) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: TextField(
                    controller: _textController,
                    maxLines: 4,
                    minLines: 1,
                    decoration: InputDecoration(
                      hintText: widget.isNotesMode
                          ? 'Write an internal team note (not sent to customer)...'
                          : 'Type a message (Ctrl+Enter to send)...',
                      hintStyle: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF94A3B8)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    onSubmitted: (_) => _handleSend(),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Send Button
              widget.isSending
                  ? const SizedBox(
                      width: 36,
                      height: 36,
                      child: Padding(
                        padding: EdgeInsets.all(8.0),
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF008069)),
                      ),
                    )
                  : InkWell(
                      onTap: _handleSend,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: widget.isNotesMode ? const Color(0xFFD97706) : const Color(0xFF008069),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                      ),
                    ),
            ],
          ),
        ],
      ),
    );
  }
}
