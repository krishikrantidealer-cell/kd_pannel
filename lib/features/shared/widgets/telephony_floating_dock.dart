import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kd_pannel/core/auth/auth_service.dart';
import 'package:kd_pannel/core/services/telephony_audio_service.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/call_logs_bloc.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/call_logs_event.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/call_logs_state.dart';
import 'package:kd_pannel/features/admin/presentation/widgets/call_disposition_dialog.dart';

/// Bespoke Persistent Floating Telephony Dock
/// Renders an enterprise mini-dock in the bottom-right corner when a call is in progress.
class TelephonyFloatingDock extends StatefulWidget {
  const TelephonyFloatingDock({super.key});

  @override
  State<TelephonyFloatingDock> createState() => _TelephonyFloatingDockState();
}

class _TelephonyFloatingDockState extends State<TelephonyFloatingDock> with SingleTickerProviderStateMixin {
  Timer? _callDurationTimer;
  int _secondsElapsed = 0;
  bool _isMuted = false;
  bool _isOnHold = false;
  bool _isMinimized = false;

  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    TelephonyAudioService().stopDialingTone();
    _callDurationTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _callDurationTimer?.cancel();
    _secondsElapsed = 0;
    _callDurationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _secondsElapsed++;
        });
      }
    });
  }

  void _stopTimer() {
    TelephonyAudioService().stopDialingTone();
    _callDurationTimer?.cancel();
    _callDurationTimer = null;
    if (mounted) {
      setState(() {
        _secondsElapsed = 0;
      });
    }
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds / 60).floor().toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }

  void _showDispositionDialog(BuildContext context, CallLogsState state) {
    final callLogId = state.activeCallLogId ?? '';
    final phone = state.activeCustomerPhone ?? '';
    final name = state.activeCustomerName;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => CallDispositionDialog(
        callLogId: callLogId,
        customerPhone: phone,
        customerName: name,
        onSave: (disposition, followUpDate, followUpNote, notes) {
          Navigator.of(dialogCtx).pop();
          context.read<CallLogsBloc>().add(SaveCallDispositionEvent(
            callLogId: callLogId,
            userDisposition: disposition,
            followUpDate: followUpDate,
            followUpNote: followUpNote,
            notes: notes,
          ));
        },
      ),
    ).then((_) {
      if (context.mounted) {
        context.read<CallLogsBloc>().add(const DismissDispositionModalEvent());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!AuthService().isTelephonyEnabled) {
      return const SizedBox.shrink();
    }

    return BlocConsumer<CallLogsBloc, CallLogsState>(
      listenWhen: (prev, curr) =>
          prev.isTriggeringCall != curr.isTriggeringCall ||
          prev.isCallActive != curr.isCallActive ||
          prev.showPostCallDisposition != curr.showPostCallDisposition ||
          prev.activeCallLogId != curr.activeCallLogId,
      listener: (context, state) {
        if (state.isTriggeringCall || state.isCallActive) {
          _animController.forward();
          if (_callDurationTimer == null) {
            _startTimer();
          }
          if (state.isTriggeringCall) {
            TelephonyAudioService().startDialingTone();
          } else {
            TelephonyAudioService().stopDialingTone();
          }
        } else if (!state.isCallActive && !state.isTriggeringCall) {
          _stopTimer();
          _animController.reverse();
        }

        if (state.showPostCallDisposition && state.activeCustomerPhone != null) {
          _showDispositionDialog(context, state);
        }
      },
      builder: (context, state) {
        final isDockVisible = state.isCallActive || state.isTriggeringCall;
        if (!isDockVisible) {
          return const SizedBox.shrink();
        }

        return Positioned(
          bottom: 24,
          right: 24,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Material(
              color: Colors.transparent,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: _isMinimized ? 240 : 350,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A), // Deep Enterprise Slate
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.28),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                  border: Border.all(
                    color: const Color(0xFF334155),
                    width: 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header: Status + Minimize / Expand
                    Row(
                      children: [
                        // Pulsing Live Indicator
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF10B981),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            state.isTriggeringCall ? 'DIALING (MyOperator)' : 'CALL CONNECTED',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: const Color(0xFF94A3B8),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Live Duration Timer
                        Text(
                          _formatDuration(_secondsElapsed),
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF38BDF8),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Minimize button
                        InkWell(
                          onTap: () => setState(() => _isMinimized = !_isMinimized),
                          borderRadius: BorderRadius.circular(4),
                          child: Padding(
                            padding: const EdgeInsets.all(2.0),
                            child: Icon(
                              _isMinimized ? Icons.open_in_full_rounded : Icons.close_fullscreen_rounded,
                              size: 14,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                        ),
                      ],
                    ),

                    if (!_isMinimized) ...[
                      const SizedBox(height: 12),
                      // Agent Dedicated DID info
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.phone_in_talk_rounded,
                              color: Color(0xFF10B981),
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  state.activeCustomerName ?? AuthService().currentUserName ?? 'Sales Agent',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  state.activeCustomerPhone != null
                                      ? 'Customer: ${state.activeCustomerPhone}'
                                      : 'Outbound Line: ${AuthService().agentWhatsAppNumber ?? '7316917208'}',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    color: const Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      // Controls Strip (Mute, Hold, Hangup)
                      Row(
                        children: [
                          Expanded(
                            child: _buildDockButton(
                              icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                              label: _isMuted ? 'Unmute' : 'Mute',
                              isActive: _isMuted,
                              onTap: () => setState(() => _isMuted = !_isMuted),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildDockButton(
                              icon: _isOnHold ? Icons.play_arrow_rounded : Icons.pause_rounded,
                              label: _isOnHold ? 'Resume' : 'Hold',
                              isActive: _isOnHold,
                              onTap: () => setState(() => _isOnHold = !_isOnHold),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildDockButton(
                              icon: Icons.call_end_rounded,
                              label: 'End Call',
                              isDestructive: true,
                              onTap: () {
                                final duration = _secondsElapsed;
                                _stopTimer();
                                TelephonyAudioService().playHangupTone();
                                _animController.reverse();
                                setState(() {
                                  _secondsElapsed = 0;
                                });
                                context.read<CallLogsBloc>().add(EndActiveCallEvent(durationSeconds: duration));
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDockButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
    bool isDestructive = false,
  }) {
    Color bg = isDestructive
        ? const Color(0xFFEF4444)
        : (isActive ? const Color(0xFF3B82F6) : const Color(0xFF1E293B));
    Color fg = Colors.white;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
