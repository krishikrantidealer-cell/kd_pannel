import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kd_pannel/core/auth/auth_service.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/call_logs_bloc.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/call_logs_event.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/call_logs_state.dart';
import 'package:kd_pannel/features/admin/presentation/widgets/call_disposition_dialog.dart';

/// Global listener that automatically pops up the After-Call Work (ACW)
/// Call Disposition Dialog whenever a call ends on the MyOperator mobile app or dialer.
class GlobalTelephonyAcwListener extends StatefulWidget {
  final Widget child;

  const GlobalTelephonyAcwListener({super.key, required this.child});

  @override
  State<GlobalTelephonyAcwListener> createState() => _GlobalTelephonyAcwListenerState();
}

class _GlobalTelephonyAcwListenerState extends State<GlobalTelephonyAcwListener> {
  static bool _isDialogShowing = false;
  static String? _lastCallLogId;
  static DateTime? _lastShownTime;

  void _showAcwDialog(BuildContext context, CallLogsState state) {
    if (!AuthService().isTelephonyEnabled) return;
    if (_isDialogShowing) return;

    final callLogId = state.activeCallLogId ?? '';
    final phone = (state.activeCustomerPhone ?? '').trim();
    if (phone.isEmpty) return;

    final now = DateTime.now();
    if (_lastCallLogId != null &&
        _lastCallLogId == callLogId &&
        _lastShownTime != null &&
        now.difference(_lastShownTime!).inSeconds < 10) {
      return;
    }

    _isDialogShowing = true;
    _lastCallLogId = callLogId;
    _lastShownTime = now;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        _isDialogShowing = false;
        return;
      }

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogCtx) => CallDispositionDialog(
          callLogId: callLogId,
          customerPhone: phone,
          customerName: state.activeCustomerName,
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
        _isDialogShowing = false;
        if (mounted) {
          context.read<CallLogsBloc>().add(const DismissDispositionModalEvent());
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<CallLogsBloc, CallLogsState>(
      listenWhen: (prev, curr) =>
          prev.showPostCallDisposition != curr.showPostCallDisposition ||
          prev.activeCallLogId != curr.activeCallLogId,
      listener: (context, state) {
        if (state.showPostCallDisposition && state.activeCustomerPhone != null) {
          _showAcwDialog(context, state);
        }
      },
      child: widget.child,
    );
  }
}
