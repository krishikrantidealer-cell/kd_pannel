import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:kd_pannel/features/admin/data/models/chat_message_model.dart';

/// Clean, high-performance message bubble with Meta delivery ticks & internal note styling
class ChatMessageBubble extends StatelessWidget {
  final ChatMessageModel message;
  final VoidCallback? onQuote;

  const ChatMessageBubble({
    super.key,
    required this.message,
    this.onQuote,
  });

  Widget _buildDeliveryStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'read':
      case 'seen':
        return const Icon(Icons.done_all_rounded, size: 14, color: Color(0xFF34B7F1)); // WhatsApp Blue Tick
      case 'delivered':
        return const Icon(Icons.done_all_rounded, size: 14, color: Color(0xFF8696A0)); // Double Gray Tick
      case 'failed':
        return const Icon(Icons.error_outline_rounded, size: 14, color: Color(0xFFEF4444));
      case 'pending':
        return const Icon(Icons.access_time_rounded, size: 12, color: Color(0xFF8696A0));
      case 'sent':
      default:
        return const Icon(Icons.done_rounded, size: 14, color: Color(0xFF8696A0)); // Single Tick
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOutbound = message.isOutbound;
    final isNote = message.isInternalNote;

    final formattedTime = DateFormat('hh:mm a').format(message.timestamp);

    // ── Mode A: Internal CRM Note ─────────────────────────────────────────────
    if (isNote) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFFDE68A)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.lock_clock_rounded, size: 16, color: Color(0xFFD97706)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'INTERNAL NOTE • ${message.senderName ?? 'Agent'}',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFB45309),
                        ),
                      ),
                      Text(
                        formattedTime,
                        style: GoogleFonts.outfit(fontSize: 10, color: const Color(0xFF92400E)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message.text,
                    style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF78350F)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // ── Mode B: Standard WhatsApp Message Bubble ──────────────────────────────
    final bubbleColor = isOutbound ? const Color(0xFFD9FDD3) : Colors.white;
    final align = isOutbound ? Alignment.centerRight : Alignment.centerLeft;
    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(12),
      topRight: const Radius.circular(12),
      bottomLeft: isOutbound ? const Radius.circular(12) : const Radius.circular(2),
      bottomRight: isOutbound ? const Radius.circular(2) : const Radius.circular(12),
    );

    return Align(
      alignment: align,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.65),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: borderRadius,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              offset: const Offset(0, 1),
              blurRadius: 1,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Column(
            crossAxisAlignment: isOutbound ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              // Media preview if URL exists
              if (message.mediaUrl != null && message.mediaUrl!.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    onTap: () async {
                      final url = Uri.tryParse(message.mediaUrl!);
                      if (url != null && await canLaunchUrl(url)) {
                        await launchUrl(url, mode: LaunchMode.externalApplication);
                      }
                    },
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 220),
                      color: Colors.black12,
                      child: Image.network(
                        message.mediaUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (ctx, err, stack) => Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.attachment_rounded, size: 16, color: Color(0xFF64748B)),
                              const SizedBox(width: 6),
                              Text('Attachment Link', style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF008069))),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
              ],

              // Message Body Text
              SelectableText(
                message.text,
                style: GoogleFonts.outfit(
                  fontSize: 13.5,
                  color: const Color(0xFF111B21),
                  height: 1.35,
                ),
              ),

              const SizedBox(height: 2),

              // Timestamp & Status Tick Row
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    formattedTime,
                    style: GoogleFonts.outfit(
                      fontSize: 10.5,
                      color: const Color(0xFF667781),
                    ),
                  ),
                  if (isOutbound) ...[
                    const SizedBox(width: 4),
                    _buildDeliveryStatusIcon(message.status),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
