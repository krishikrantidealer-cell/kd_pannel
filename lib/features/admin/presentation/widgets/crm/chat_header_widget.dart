import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kd_pannel/features/admin/data/models/conversation_model.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/call_logs_bloc.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/call_logs_event.dart';
import 'package:kd_pannel/features/shared/widgets/telephony_call_button.dart';

/// Modular, responsive header bar for active WhatsApp conversations
class ChatHeaderWidget extends StatelessWidget {
  final ConversationModel conversation;
  final List<dynamic> salesAgents;
  final Function(String agentId)? onReassignAgent;
  final Function(String language)? onLanguageChanged;
  final VoidCallback? onOpenEstimates;

  const ChatHeaderWidget({
    super.key,
    required this.conversation,
    this.salesAgents = const [],
    this.onReassignAgent,
    this.onLanguageChanged,
    this.onOpenEstimates,
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
    final displayName = conversation.customerName?.isNotEmpty == true
        ? conversation.customerName!
        : 'Customer (+${conversation.customerPhone})';
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'C';

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Color(0xFFF0F2F5),
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          // Customer Avatar
          CircleAvatar(
            radius: 20,
            backgroundColor: _getAvatarColor(displayName),
            child: Text(
              initial,
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Name and Phone
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        displayName,
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF111B21),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Language Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF008069).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        conversation.preferredLanguage.toUpperCase(),
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF008069),
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  '+${conversation.customerPhone}',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),

          // Action Buttons: Estimates, Reassign, Calling Menu
          if (onOpenEstimates != null)
            IconButton(
              icon: const Icon(Icons.request_quote_outlined, color: Color(0xFF008069)),
              tooltip: 'Generate Estimate / Quotation',
              onPressed: onOpenEstimates,
            ),

          const SizedBox(width: 6),

          // ── DRY Dual Outbound Calling Button (WebCall & Mobile C2C) ──────────
          TelephonyCallButton(
            customerPhone: conversation.customerPhone,
            customerName: conversation.customerName,
            variant: TelephonyButtonVariant.filled,
            color: const Color(0xFF008069),
          ),
        ],
      ),
    );
  }
}
