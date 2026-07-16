// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
// web_notification_helper_web.dart
// Web-specific implementation of notifications using HTML5 Notification and Web Audio APIs.

import 'dart:html' as html;
import 'dart:js' as js;

/// Requests permission to show notifications.
void requestNotificationPermission() {
  try {
    if (html.Notification.permission == 'default') {
      html.Notification.requestPermission();
    }
  } catch (e) {
    // Ignore error if Notification API is not supported
  }
}

/// Shows a web notification with sound.
void showWebNotification(String title, String body) {
  _playBeep();
  
  try {
    final String iconUrl = 'icons/Icon-192.png';
    final String badgeUrl = 'icons/Icon-192.png';

    if (html.Notification.permission == 'granted') {
      _displayNotification(title, body, iconUrl, badgeUrl);
    } else if (html.Notification.permission != 'denied') {
      html.Notification.requestPermission().then((permission) {
        if (permission == 'granted') {
          _displayNotification(title, body, iconUrl, badgeUrl);
        }
      }).catchError((_) {});
    }
  } catch (e) {
    print('Error showing notification: $e');
  }
}

/// Attempts to show a notification via ServiceWorker for better platform integration.
/// Falls back to standard Notification API if ServiceWorker is not available or fails.
void _displayNotification(String title, String body, String icon, String badge) {
  try {
    final sw = js.context['navigator']['serviceWorker'];
    // We removed the null check as per the warning "operand can't be null".
    // If it is null, the catch block will handle the resulting exception.
    sw.callMethod('getRegistration').callMethod('then', [
      (registration) {
        // We removed the null check on registration as well.
        registration.callMethod('showNotification', [
          title,
          js.JsObject.jsify({
            'body': body,
            'icon': icon,
            'badge': badge,
            'tag': 'kd_pannel_notif',
            'renotify': true,
            'requireInteraction': true,
            'vibrate': [200, 100, 200]
          })
        ]);
      }
    ]);
    return;
  } catch (e) {
    // Fail silently and use fallback
  }

  _createStandardNotification(title, body, icon);
}

/// Fallback method using standard HTML5 Notification API.
void _createStandardNotification(String title, String body, String icon) {
  try {
    html.Notification(
      title,
      body: body,
      icon: icon,
      tag: 'kd_pannel_notif',
    );
  } catch (e) {
    // Notification API might not be supported or blocked
  }
}

/// Plays a short notification beep using Web Audio API.
void _playBeep() {
  try {
    final audioContextClass = js.context['AudioContext'] ?? js.context['webkitAudioContext'];
    if (audioContextClass == null) return;
    
    final ctx = js.JsObject(audioContextClass);
    final osc = ctx.callMethod('createOscillator');
    final gain = ctx.callMethod('createGain');
    
    osc.callMethod('connect', [gain]);
    gain.callMethod('connect', [ctx['destination']]);
    
    final dynamic currentTime = ctx['currentTime'];
    osc['frequency'].callMethod('setValueAtTime', [587.33, currentTime]);
    gain['gain'].callMethod('setValueAtTime', [0.15, currentTime]);
    gain['gain'].callMethod('exponentialRampToValueAtTime', [0.001, currentTime + 0.15]);
    
    osc.callMethod('start', []);
    osc.callMethod('stop', [currentTime + 0.15]);
  } catch (e) {
    // Ignore audio errors
  }
}
