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

/// Shows a web notification with sound.
void showWebNotification(String title, String body) {
  _playBeep();

  try {
    const String iconUrl = 'icons/Icon-192.png';

    if (web.Notification.permission == 'granted') {
      _displayNotification(title, body, iconUrl);
    } else if (web.Notification.permission != 'denied') {
      web.Notification.requestPermission().toDart.then((permission) {
        if (permission.toDart == 'granted') {
          _displayNotification(title, body, iconUrl);
        }
      }).catchError((_) {});
    }
  } catch (_) {}
}

/// Displays a desktop browser notification using standard HTML5 Notification API.
void _displayNotification(String title, String body, String icon) {
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
      } catch (_) {}
    }).toJS;
  } catch (_) {}
}

/// Plays a short notification chime using Web Audio API.
void _playBeep() {
  try {
    final ctx = web.AudioContext();
    final osc = ctx.createOscillator();
    final gain = ctx.createGain();

    osc.connect(gain);
    gain.connect(ctx.destination);

    final double currentTime = ctx.currentTime.toDouble();
    osc.frequency.setValueAtTime(587.33, currentTime);
    osc.frequency.setValueAtTime(880.0, currentTime + 0.08);
    gain.gain.setValueAtTime(0.18, currentTime);
    gain.gain.exponentialRampToValueAtTime(0.001, currentTime + 0.25);

    osc.start(currentTime);
    osc.stop(currentTime + 0.25);
  } catch (_) {
    // Ignore audio errors
  }
}


