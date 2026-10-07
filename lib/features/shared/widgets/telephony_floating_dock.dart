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
  Timer? _safetyDismissTimer;
  int _secondsElapsed = 0;
  bool _isMinimized = false;
  bool _isEnding = false;
  bool _isDisconnecting = false;
  bool _wasCallOngoing = false;

  // Global static locks to guarantee that multiple ACW modals CANNOT stack
  static bool _isDispositionDialogShowing = false;
  static String? _lastShownDispositionCallId;
  static String? _lastShownPhone;
  static DateTime? _lastShownDispositionTime;

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
    _safetyDismissTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _callDurationTimer?.cancel();
    _dismissTimer?.cancel();
    _safetyDismissTimer?.cancel();
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

  void _dismissDock(BuildContext context, CallLogsState state) {
    if (_isEnding) return;
    _wasCallOngoing = false;
    TelephonyAudioService().stopDialingTone();
    TelephonyAudioService().playHangupTone();
    _stopTimer();

    if (mounted) {
      setState(() {
        _isEnding = true;
      });
    }

    _dismissTimer?.cancel();
    _safetyDismissTimer?.cancel();

    // Absolute fallback safety: force-close dock after 900ms no matter what
    _safetyDismissTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted && _isEnding) {
        setState(() {
          _isEnding = false;
          _isDisconnecting = false;
          _secondsElapsed = 0;
        });
        _animController.reset();
      }
    });

    final int delayMs = state.showPostCallDisposition ? 350 : 150;
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

  String _formatDuration(int seconds) {
    final minutes = (seconds / 60).floor().toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }

  void _showDispositionDialog(BuildContext context, CallLogsState state, {bool force = false}) {
    final callLogId = state.activeCallLogId ?? '';
    final phone = (state.activeCustomerPhone ?? '').replaceFirst(RegExp(r'^\+?91'), '').trim();
    final name = state.activeCustomerName;

    // Strict guard: if a disposition dialog is ALREADY showing, never stack another on top
    if (_isDispositionDialogShowing) return;

    if (!force) {
      final now = DateTime.now();
      // Debounce auto-opens from redundant state transitions within 1.5 seconds
      if (_lastShownDispositionTime != null && now.difference(_lastShownDispositionTime!).inMilliseconds < 1500) {
        return;
      }
    }

    _isDispositionDialogShowing = true;
    _lastShownDispositionCallId = callLogId.isNotEmpty ? callLogId : null;
    _lastShownPhone = phone.isNotEmpty ? phone : null;
    _lastShownDispositionTime = DateTime.now();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => CallDispositionDialog(
        callLogId: callLogId,
        customerPhone: state.activeCustomerPhone ?? '',
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
    ).whenComplete(() {
      _isDispositionDialogShowing = false;
      _lastShownDispositionTime = null;
      _lastShownDispositionCallId = null;
      _lastShownPhone = null;
      if (context.mounted) {
        context.read<CallLogsBloc>().add(const DismissDispositionModalEvent());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
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

