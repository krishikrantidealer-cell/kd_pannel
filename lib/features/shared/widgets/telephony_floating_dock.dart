import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kd_pannel/core/auth/auth_service.dart';
import 'package:kd_pannel/core/services/telephony_audio_service.dart';
import 'package:kd_pannel/core/utils/navigation_service.dart';
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
  Timer? _dismissTimer;
  int _secondsElapsed = 0;
  bool _isMuted = false;
  bool _isOnHold = false;
  bool _isMinimized = false;
  bool _isEnding = false;
  bool _isDisconnecting = false;

  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
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
    _dismissTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _callDurationTimer?.cancel();
    _dismissTimer?.cancel();
    _secondsElapsed = 0;
    _isEnding = false;
    _isDisconnecting = false;
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
          prev.activeCallLogId != curr.activeCallLogId ||
          prev.errorMessage != curr.errorMessage ||
          prev.successMessage != curr.successMessage,
      listener: (context, state) {
        if (state.errorMessage != null && state.errorMessage!.isNotEmpty) {
          NavigationService.messengerKey.currentState?.showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      state.errorMessage!,
                      style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFFEF4444),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );
          context.read<CallLogsBloc>().add(const ClearCallLogsMessageEvent());
        }

        if (state.isTriggeringCall || state.isCallActive) {
          _animController.forward();
          if (state.isCallActive) {
            TelephonyAudioService().stopDialingTone();
            if (_callDurationTimer == null) {
              TelephonyAudioService().playCallConnectedTone();
              _startTimer();
            }
          } else if (state.isTriggeringCall) {
            TelephonyAudioService().startDialingTone();
            _stopTimer();
          }
        } else if (!state.isCallActive && !state.isTriggeringCall && !_isEnding) {
          // Instant visual and acoustic feedback transition
          TelephonyAudioService().stopDialingTone();
          TelephonyAudioService().playHangupTone();
          setState(() {
            _isEnding = true;
          });
          _stopTimer();

          _dismissTimer?.cancel();
          final int delayMs = state.showPostCallDisposition ? 400 : 200;
          _dismissTimer = Timer(Duration(milliseconds: delayMs), () {
            if (mounted) {
              _animController.reverse().then((_) {
                if (mounted) {
                  setState(() {
                    _isEnding = false;
                    _isDisconnecting = false;
                    _secondsElapsed = 0;
                  });
                  if (state.showPostCallDisposition && state.activeCustomerPhone != null) {
                    _showDispositionDialog(context, state);
                  }
                }
              });
            }
          });
        }
      },
      builder: (context, state) {
        final isDockVisible = state.isCallActive || state.isTriggeringCall || _isEnding;
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
                width: _isMinimized ? 250 : 380,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _isEnding ? const Color(0xFF1E1B2E) : const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 22,
                      offset: const Offset(0, 8),
                    ),
                  ],
                  border: Border.all(
                    color: _isEnding ? const Color(0xFFEF4444).withValues(alpha: 0.6) : const Color(0xFF334155),
                    width: 1.2,
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
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isEnding || _isDisconnecting
                                ? const Color(0xFFEF4444)
                                : (state.isTriggeringCall ? const Color(0xFFF59E0B) : const Color(0xFF10B981)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _isDisconnecting
                                ? 'DISCONNECTING...'
                                : (_isEnding
                                    ? 'CALL ENDED'
                                    : (state.isTriggeringCall
                                        ? 'RINGING YOUR PHONE...'
                                        : 'CALL IN PROGRESS')),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: _isEnding ? const Color(0xFFF87171) : (state.isTriggeringCall ? const Color(0xFFF59E0B) : const Color(0xFF10B981)),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Live Duration Timer (only ticks once call is answered)
                        Text(
                          state.isTriggeringCall ? 'DIALING...' : _formatDuration(_secondsElapsed),
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: _isEnding ? const Color(0xFFF87171) : (state.isTriggeringCall ? const Color(0xFFF59E0B) : const Color(0xFF38BDF8)),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Minimize button
                        if (!_isEnding)
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
                              color: _isEnding ? const Color(0xFF450A0A) : const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.phone_in_talk_rounded,
                              color: _isEnding ? const Color(0xFFF87171) : const Color(0xFF10B981),
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        state.activeCustomerName ?? AuthService().currentUserName ?? 'Customer Contact',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.withValues(alpha: 0.25),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'CLICK TO CALL',
                                        style: GoogleFonts.outfit(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF60A5FA),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  state.isTriggeringCall
                                      ? 'Pick up your phone to connect with ${state.activeCustomerPhone ?? 'customer'}'
                                      : (state.activeCustomerPhone != null
                                          ? 'Connected: ${state.activeCustomerPhone}'
                                          : 'Outbound Line: ${AuthService().agentWhatsAppNumber ?? '7316917208'}'),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    color: state.isTriggeringCall ? const Color(0xFFFCD34D) : const Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      // 3-Step Real-Time Connection Indicator
                      if (!_isEnding) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B).withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF334155), width: 0.8),
                          ),
                          child: Row(
                            children: [
                              Expanded(child: _buildStepBadge('1. Agent', state.isTriggeringCall ? StepStatus.active : StepStatus.completed)),
                              const SizedBox(width: 4),
                              const Icon(Icons.arrow_forward_ios_rounded, size: 8, color: Color(0xFF64748B)),
                              const SizedBox(width: 4),
                              Expanded(child: _buildStepBadge('2. Answer', state.isTriggeringCall ? StepStatus.waiting : StepStatus.completed)),
                              const SizedBox(width: 4),
                              const Icon(Icons.arrow_forward_ios_rounded, size: 8, color: Color(0xFF64748B)),
                              const SizedBox(width: 4),
                              Expanded(child: _buildStepBadge('3. Customer', state.isCallActive ? StepStatus.active : StepStatus.waiting)),
                            ],
                          ),
                        ),
                      ],

                      if (_isEnding) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: state.showPostCallDisposition
                                ? const Color(0xFF3B0764).withValues(alpha: 0.4)
                                : const Color(0xFF450A0A).withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: state.showPostCallDisposition
                                  ? const Color(0xFFA855F7).withValues(alpha: 0.3)
                                  : const Color(0xFFEF4444).withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (state.showPostCallDisposition) ...[
                                const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFC084FC)),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Text(
                                state.showPostCallDisposition
                                    ? 'Opening Post-Call ACW Notes...'
                                    : 'Call Disconnected',
                                style: GoogleFonts.outfit(
                                  fontSize: 11.5,
                                  color: state.showPostCallDisposition ? const Color(0xFFE9D5FF) : const Color(0xFFFCA5A5),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        const SizedBox(height: 14),
                        // Controls Strip (Mute, Hold, Hangup)
                        Row(
                          children: [
                            Expanded(
                              child: _buildDockButton(
                                icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                                label: _isMuted ? 'Unmute' : 'Mute',
                                isActive: _isMuted,
                                onTap: () {
                                  setState(() => _isMuted = !_isMuted);
                                  if (_isMuted) {
                                    TelephonyAudioService().playMuteTone();
                                  } else {
                                    TelephonyAudioService().playUnmuteTone();
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildDockButton(
                                icon: _isOnHold ? Icons.play_arrow_rounded : Icons.pause_rounded,
                                label: _isOnHold ? 'Resume' : 'Hold',
                                isActive: _isOnHold,
                                onTap: () {
                                  setState(() => _isOnHold = !_isOnHold);
                                  TelephonyAudioService().playHoldTone();
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildDockButton(
                                icon: Icons.call_end_rounded,
                                label: _isDisconnecting ? 'Ending...' : 'End Call',
                                isDestructive: true,
                                onTap: () {
                                  final duration = _secondsElapsed;
                                  setState(() {
                                    _isDisconnecting = true;
                                    _isEnding = true;
                                  });
                                  _stopTimer();
                                  TelephonyAudioService().playHangupTone();
                                  context.read<CallLogsBloc>().add(EndActiveCallEvent(durationSeconds: duration));
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
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

  Widget _buildStepBadge(String label, StepStatus status) {
    Color bg;
    Color fg;
    IconData icon;

    switch (status) {
      case StepStatus.completed:
        bg = const Color(0xFF065F46).withValues(alpha: 0.5);
        fg = const Color(0xFF34D399);
        icon = Icons.check_circle_rounded;
        break;
      case StepStatus.active:
        bg = const Color(0xFF78350F).withValues(alpha: 0.5);
        fg = const Color(0xFFFBBF24);
        icon = Icons.hourglass_top_rounded;
        break;
      case StepStatus.waiting:
        bg = const Color(0xFF334155).withValues(alpha: 0.4);
        fg = const Color(0xFF94A3B8);
        icon = Icons.radio_button_unchecked_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: fg),
          const SizedBox(width: 3),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

enum StepStatus { waiting, active, completed }

