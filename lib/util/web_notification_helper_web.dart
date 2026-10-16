// web_notification_helper_web.dart
// Web-specific implementation of notifications using modern package:web Notification and Web Audio APIs.

import 'dart:js_interop';
import 'package:web/web.dart' as web;

bool _gestureListenerAttached = false;

/// Requests permission to show notifications.
void requestNotificationPermission() {
  try {
    if (web.Notification.permission == 'default') {
      web.Notification.requestPermission();

      // Modern browsers require a user gesture (click) to prompt for permission.
      // Attach a one-time click listener so the first click in the panel prompts if still 'default'.
      if (!_gestureListenerAttached) {
        _gestureListenerAttached = true;
        late JSFunction clickHandler;
        clickHandler = ((web.Event _) {
          web.window.removeEventListener('click', clickHandler);
          _gestureListenerAttached = false;
          try {
            _getOrCreateNotifContext().resume();
          } catch (_) {}
          try {
            if (web.Notification.permission == 'default') {
              web.Notification.requestPermission();
            }
          } catch (_) {}
        }).toJS;
        web.window.addEventListener('click', clickHandler);
      }
    }
  } catch (_) {
    // Ignore error if Notification API is not supported
  }
}

/// Shows a web notification with priority-aware sound and optional click callback.
void showWebNotification(
  String title,
  String body, {
  String priority = 'normal',
  void Function()? onTap,
}) {
  _playBeep(priority: priority);

  try {
    const String iconUrl = 'icons/Icon-192.png';

    if (web.Notification.permission == 'granted') {
      _displayNotification(title, body, iconUrl, onTap: onTap);
    } else if (web.Notification.permission != 'denied') {
      web.Notification.requestPermission().toDart.then((permission) {
        if (permission.toDart == 'granted') {
          _displayNotification(title, body, iconUrl, onTap: onTap);
        }
      }).catchError((_) {});
    }
  } catch (_) {}
}

/// Displays a desktop browser notification using standard HTML5 Notification API.
void _displayNotification(
  String title,
  String body,
  String icon, {
  void Function()? onTap,
}) {
  final String uniqueTag = 'kd_alert_${DateTime.now().microsecondsSinceEpoch}';

  try {
    final notif = web.Notification(
      title,
      web.NotificationOptions(
        body: body,
        icon: icon,
        tag: uniqueTag,
      ),
    );

    notif.onclick = ((web.Event _) {
      try {
        web.window.focus();
        notif.close();
        onTap?.call();
      } catch (_) {}
    }).toJS;
  } catch (_) {}
}

web.AudioContext? _notifAudioContext;

web.AudioContext _getOrCreateNotifContext() {
  if (_notifAudioContext == null || _notifAudioContext!.state == 'closed') {
    _notifAudioContext = web.AudioContext();
  }
  if (_notifAudioContext!.state == 'suspended') {
    _notifAudioContext!.resume();
  }
  return _notifAudioContext!;
}

/// Plays a priority-differentiated notification chime using Web Audio API.
void _playBeep({String priority = 'normal'}) {
  try {
    final ctx = _getOrCreateNotifContext();
    final double currentTime = ctx.currentTime.toDouble();

    if (priority == 'critical') {
      // Urgent two-pulse chime for critical alerts (Task Due Now, SLA Breach, High-Value Order)
      for (int i = 0; i < 2; i++) {
        final double offset = currentTime + (i * 0.22);
        final osc = ctx.createOscillator();
        final gain = ctx.createGain();
        osc.connect(gain);
        gain.connect(ctx.destination);

        osc.frequency.setValueAtTime(659.25, offset); // E5
        osc.frequency.setValueAtTime(987.77, offset + 0.07); // B5
        gain.gain.setValueAtTime(0.24, offset);
        gain.gain.exponentialRampToValueAtTime(0.001, offset + 0.19);

        osc.start(offset);
        osc.stop(offset + 0.19);
      }
    } else {
      // Clean standard chime for high/normal alerts
      final osc = ctx.createOscillator();
      final gain = ctx.createGain();

      osc.connect(gain);
      gain.connect(ctx.destination);

      osc.frequency.setValueAtTime(587.33, currentTime); // D5
      osc.frequency.setValueAtTime(880.0, currentTime + 0.08); // A5
      gain.gain.setValueAtTime(0.18, currentTime);
      gain.gain.exponentialRampToValueAtTime(0.001, currentTime + 0.25);

      osc.start(currentTime);
      osc.stop(currentTime + 0.25);
    }
  } catch (_) {
    // Ignore audio errors
  }
}


