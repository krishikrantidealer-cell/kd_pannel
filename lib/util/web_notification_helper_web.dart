// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
// web_notification_helper_web.dart
// Web-specific implementation of notifications using HTML5 Notification and Web Audio APIs.

import 'dart:html' as html;
import 'dart:js' as js;
import 'dart:async';

void requestNotificationPermission() {
  try {
    if (html.Notification.permission == 'default') {
      html.Notification.requestPermission();
    }
  } catch (e) {
    // Ignore error if Notification API is not supported
  }
}

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
      });
    }
  } catch (e) {
    print('Error showing notification: $e');
  }
}

/// Attempts to show a notification via ServiceWorker for better Windows integration.
/// Falls back to standard Notification API if ServiceWorker is not available.
void _displayNotification(String title, String body, String icon, String badge) {
  // Use JS to access the ServiceWorker registration if available
  // This is the "Gold Standard" for Windows System Toasts
  final serviceWorker = html.window.navigator.serviceWorker;
  
  if (serviceWorker != null) {
    serviceWorker.getRegistration().then((registration) {
      if (registration != null) {
        // Use JS interop to call showNotification on the registration object
        // as dart:html's ServiceWorkerRegistration doesn't expose it directly in all versions
        js.context.callMethod('eval', [
          '''
          navigator.serviceWorker.ready.then(function(reg) {
            reg.showNotification("$title", {
              body: "$body",
              icon: "$icon",
              badge: "$badge",
              tag: "kd_pannel_notif",
              renotify: true,
              requireInteraction: true,
              vibrate: [200, 100, 200]
            });
          });
          '''
        ]);
        return;
      }
      // Fallback 1: Standard Notification
      _createStandardNotification(title, body, icon);
    }).catchError((_) {
      // Fallback 2: Standard Notification
      _createStandardNotification(title, body, icon);
    });
  } else {
    _createStandardNotification(title, body, icon);
  }
}

void _createStandardNotification(String title, String body, String icon) {
  html.Notification(
    title,
    body: body,
    icon: icon,
    tag: 'kd_pannel_notif',
  );
}

void _playBeep() {
  try {
    js.context.callMethod('eval', [
      '''
      try {
        var AudioContext = window.AudioContext || window.webkitAudioContext;
        var ctx = new AudioContext();
        var osc1 = ctx.createOscillator();
        var gain1 = ctx.createGain();
        osc1.connect(gain1);
        gain1.connect(ctx.destination);
        osc1.frequency.setValueAtTime(587.33, ctx.currentTime);
        gain1.gain.setValueAtTime(0.15, ctx.currentTime);
        gain1.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.15);
        osc1.start();
        osc1.stop(ctx.currentTime + 0.15);
      } catch(e) {}
      ''',
    ]);
  } catch (e) {}
}
