// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
// web_notification_helper_web.dart
// Web-specific implementation of notifications using HTML5 Notification and Web Audio APIs.

import 'dart:html' as html;
import 'dart:js' as js;

void requestNotificationPermission() {
  try {
    if (html.Notification.permission == 'default') {
      html.Notification.requestPermission();
    }
  } catch (e) {
    // Ignore error if Notification API is not supported in the user's browser/context
  }
}

void showWebNotification(String title, String body) {
  try {
    if (html.Notification.permission == 'granted') {
      html.Notification(title, body: body);
    } else if (html.Notification.permission != 'denied') {
      html.Notification.requestPermission().then((permission) {
        if (permission == 'granted') {
          html.Notification(title, body: body);
        }
      });
    }
  } catch (e) {
    // Fallback if browser block notifications or Notification is not supported
  }
  _playBeep();
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

        var osc2 = ctx.createOscillator();
        var gain2 = ctx.createGain();
        osc2.connect(gain2);
        gain2.connect(ctx.destination);
        osc2.frequency.setValueAtTime(880.00, ctx.currentTime + 0.1);
        gain2.gain.setValueAtTime(0.15, ctx.currentTime + 0.1);
        gain2.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.35);
        osc2.start(ctx.currentTime + 0.1);
        osc2.stop(ctx.currentTime + 0.35);
      } catch(e) {
        console.log('Error playing notification sound:', e);
      }
      ''',
    ]);
  } catch (e) {
    // Ignore sound play error
  }
}
