import 'dart:async';
import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:web/web.dart' as web;

/// Studio-grade native Web Audio synthesis engine for CRM & Telephony notifications.
class TelephonyAudioService {
  static final TelephonyAudioService _instance = TelephonyAudioService._internal();
  factory TelephonyAudioService() {
    _instance._initBroadcastChannel();
    return _instance;
  }
  TelephonyAudioService._internal();

  web.AudioContext? _audioContext;
  web.BroadcastChannel? _tabBroadcastChannel;
  DateTime? _lastIncomingToneTime;
  bool _channelInitialized = false;

  void _initBroadcastChannel() {
    if (!kIsWeb || _channelInitialized) return;
    _channelInitialized = true;
    try {
      _tabBroadcastChannel = web.BroadcastChannel('krishi_crm_audio_sync');
      _tabBroadcastChannel?.onmessage = (web.MessageEvent e) {
        _lastIncomingToneTime = DateTime.now();
      }.toJS;
    } catch (_) {}
  }

  web.AudioContext _getOrCreateContext() {
    if (_audioContext == null || _audioContext!.state == 'closed') {
      _audioContext = web.AudioContext();
    }
    if (_audioContext!.state == 'suspended') {
      _audioContext!.resume();
    }
    return _audioContext!;
  }

  // ── 1. CRM & WhatsApp Notification Chimes & Sent Feedback ──────────────────

  /// Soothing, warm, and gentle WhatsApp incoming notification chime (Warm Marimba / Bell Duo)
  void playIncomingMessageTone() {
    final dtNow = DateTime.now();
    if (_lastIncomingToneTime != null && dtNow.difference(_lastIncomingToneTime!).inMilliseconds < 800) {
      return;
    }
    _lastIncomingToneTime = dtNow;

    try {
      _tabBroadcastChannel?.postMessage('TONE_PLAYED'.toJS);
    } catch (_) {}

    try {
      HapticFeedback.mediumImpact();
    } catch (_) {}

    if (!kIsWeb) return;
    try {
      final ctx = _getOrCreateContext();
      final now = ctx.currentTime;

      // Master lowpass filter for silky smooth warmth with full presence
      final filter = ctx.createBiquadFilter();
      filter.type = 'lowpass';
      filter.frequency.setValueAtTime(2400, now);
      filter.Q.setValueAtTime(0.5, now);
      filter.connect(ctx.destination);

      // Note 1: Warm Fundamental Tone (F5 - 698.46 Hz)
      final gain1 = ctx.createGain();
      gain1.gain.setValueAtTime(0.0001, now);
      gain1.gain.linearRampToValueAtTime(0.22, now + 0.015);
      gain1.gain.exponentialRampToValueAtTime(0.0001, now + 0.50);

      final osc1A = ctx.createOscillator();
      osc1A.type = 'sine';
      osc1A.frequency.setValueAtTime(698.46, now); // F5
      osc1A.connect(gain1);
      gain1.connect(filter);

      osc1A.start(now);
      osc1A.stop(now + 0.50);

      // Note 2: Gentle Ascending Harmonic Bell (A5 - 880.0 Hz)
      final note2Start = now + 0.07;
      final gain2 = ctx.createGain();
      gain2.gain.setValueAtTime(0.0001, note2Start);
      gain2.gain.linearRampToValueAtTime(0.19, note2Start + 0.015);
      gain2.gain.exponentialRampToValueAtTime(0.0001, note2Start + 0.45);

      final osc2A = ctx.createOscillator();
      osc2A.type = 'sine';
      osc2A.frequency.setValueAtTime(880.00, note2Start); // A5
      osc2A.connect(gain2);
      gain2.connect(filter);

      osc2A.start(note2Start);
      osc2A.stop(note2Start + 0.45);

      // Note 3: Subtle Airy Shimmer (C6 - 1046.5 Hz)
      final note3Start = now + 0.14;
      final gain3 = ctx.createGain();
      gain3.gain.setValueAtTime(0.0001, note3Start);
      gain3.gain.linearRampToValueAtTime(0.14, note3Start + 0.015);
      gain3.gain.exponentialRampToValueAtTime(0.0001, note3Start + 0.40);

      final osc3A = ctx.createOscillator();
      osc3A.type = 'sine';
      osc3A.frequency.setValueAtTime(1046.50, note3Start); // C6
      osc3A.connect(gain3);
      gain3.connect(filter);

      osc3A.start(note3Start);
      osc3A.stop(note3Start + 0.40);
    } catch (_) {}
  }

  /// Soothing & subtle WhatsApp Outgoing Message Sent Sound (Gentle Woodblock / Pop)
  void playOutgoingMessageSentTone() {
    try {
      HapticFeedback.lightImpact();
    } catch (_) {}

    if (!kIsWeb) return;
    try {
      final ctx = _getOrCreateContext();
      final now = ctx.currentTime;
      const duration = 0.050; // 50ms soft warm pop

      final gain = ctx.createGain();
      gain.gain.setValueAtTime(0.0001, now);
      gain.gain.linearRampToValueAtTime(0.15, now + 0.006);
      gain.gain.exponentialRampToValueAtTime(0.0001, now + duration);

      // Acoustic filter for zero harshness
      final filter = ctx.createBiquadFilter();
      filter.type = 'lowpass';
      filter.frequency.setValueAtTime(1600, now);

      final osc = ctx.createOscillator();
      osc.type = 'sine';
      osc.frequency.setValueAtTime(600.0, now);
      osc.frequency.exponentialRampToValueAtTime(1200.0, now + duration);

      osc.connect(gain);
      gain.connect(filter);
      filter.connect(ctx.destination);

      osc.start(now);
      osc.stop(now + duration);
    } catch (_) {}
  }

  /// Trigger Browser Web Notification Channel (silent mode, zero OS bell interference)
  void showDesktopNotification(String title, String body) {
    if (!kIsWeb) return;
    try {
      if (web.Notification.permission == 'granted') {
        web.Notification(
          title,
          web.NotificationOptions(
            body: body,
            icon: 'favicon.png',
            silent: true,
          ),
        );
      }
    } catch (_) {}
  }

  /// Request Browser Web Notification Permission
  void requestNotificationPermission() {
    if (!kIsWeb) return;
    try {
      if (web.Notification.permission == 'default') {
        web.Notification.requestPermission();
      }
    } catch (_) {}
  }

  // ── 2. Telephony Audio Feedback ────────────────────────────────────────────

  /// DTMF Keypad Tones (ITU-T Q.23 Dialpad Standard)
  void playDtmfTone(String key) {
    if (!kIsWeb) return;
    try {
      final ctx = _getOrCreateContext();
      final now = ctx.currentTime;
      const duration = 0.08;

      double rowFreq;
      double colFreq;

      switch (key) {
        case '1': rowFreq = 697; colFreq = 1209; break;
        case '2': rowFreq = 697; colFreq = 1336; break;
        case '3': rowFreq = 697; colFreq = 1477; break;
        case '4': rowFreq = 770; colFreq = 1209; break;
        case '5': rowFreq = 770; colFreq = 1336; break;
        case '6': rowFreq = 770; colFreq = 1477; break;
        case '7': rowFreq = 852; colFreq = 1209; break;
        case '8': rowFreq = 852; colFreq = 1336; break;
        case '9': rowFreq = 852; colFreq = 1477; break;
        case '*': rowFreq = 941; colFreq = 1209; break;
        case '0': rowFreq = 941; colFreq = 1336; break;
        case '#': rowFreq = 941; colFreq = 1477; break;
        case 'backspace':
          _playSoftClick(380, 260);
          return;
        default:
          rowFreq = 770; colFreq = 1336;
      }

      final gain = ctx.createGain();
      gain.gain.setValueAtTime(0.0001, now);
      gain.gain.linearRampToValueAtTime(0.07, now + 0.008);
      gain.gain.setValueAtTime(0.07, now + duration - 0.015);
      gain.gain.exponentialRampToValueAtTime(0.0001, now + duration);

      final oscRow = ctx.createOscillator();
      final oscCol = ctx.createOscillator();
      oscRow.type = 'sine';
      oscCol.type = 'sine';
      oscRow.frequency.setValueAtTime(rowFreq, now);
      oscCol.frequency.setValueAtTime(colFreq, now);

      oscRow.connect(gain);
      oscCol.connect(gain);
      gain.connect(ctx.destination);

      oscRow.start(now);
      oscCol.start(now);
      oscRow.stop(now + duration);
      oscCol.stop(now + duration);
    } catch (_) {}
  }

  void _playSoftClick(double startFreq, double endFreq) {
    try {
      final ctx = _getOrCreateContext();
      final now = ctx.currentTime;
      final gain = ctx.createGain();
      gain.gain.setValueAtTime(0.05, now);
      gain.gain.exponentialRampToValueAtTime(0.0001, now + 0.05);

      final osc = ctx.createOscillator();
      osc.type = 'sine';
      osc.frequency.setValueAtTime(startFreq, now);
      osc.frequency.exponentialRampToValueAtTime(endFreq, now + 0.05);

      osc.connect(gain);
      gain.connect(ctx.destination);
      osc.start(now);
      osc.stop(now + 0.05);
    } catch (_) {}
  }

  /// Soft descending cadence when call terminates
  void playHangupTone() {
    if (!kIsWeb) return;
    try {
      final ctx = _getOrCreateContext();
      final now = ctx.currentTime;

      final notes = [783.99, 659.25, 523.25];
      for (int i = 0; i < notes.length; i++) {
        final start = now + (i * 0.07);
        final dur = 0.15;

        final gain = ctx.createGain();
        gain.gain.setValueAtTime(0.0001, start);
        gain.gain.linearRampToValueAtTime(0.08, start + 0.015);
        gain.gain.exponentialRampToValueAtTime(0.0001, start + dur);

        final osc = ctx.createOscillator();
        osc.type = 'sine';
        osc.frequency.setValueAtTime(notes[i], start);

        osc.connect(gain);
        gain.connect(ctx.destination);

        osc.start(start);
        osc.stop(start + dur);
      }
    } catch (_) {}
  }

  /// Alert chime for incoming telephony call updates
  void playCallAlertTone() {
    if (!kIsWeb) return;
    try {
      final ctx = _getOrCreateContext();
      final now = ctx.currentTime;

      final gain = ctx.createGain();
      gain.gain.setValueAtTime(0.0001, now);
      gain.gain.linearRampToValueAtTime(0.10, now + 0.02);
      gain.gain.exponentialRampToValueAtTime(0.0001, now + 0.35);

      final osc = ctx.createOscillator();
      osc.type = 'sine';
      osc.frequency.setValueAtTime(659.25, now); // E5
      osc.frequency.setValueAtTime(987.77, now + 0.08); // B5

      osc.connect(gain);
      gain.connect(ctx.destination);

      osc.start(now);
      osc.stop(now + 0.35);
    } catch (_) {}
  }

  /// Missed call notification tone
  void playCallMissedTone() {
    if (!kIsWeb) return;
    try {
      final ctx = _getOrCreateContext();
      final now = ctx.currentTime;

      final gain = ctx.createGain();
      gain.gain.setValueAtTime(0.0001, now);
      gain.gain.linearRampToValueAtTime(0.09, now + 0.02);
      gain.gain.exponentialRampToValueAtTime(0.0001, now + 0.40);

      final osc = ctx.createOscillator();
      osc.type = 'sine';
      osc.frequency.setValueAtTime(440, now);
      osc.frequency.exponentialRampToValueAtTime(220, now + 0.40);

      osc.connect(gain);
      gain.connect(ctx.destination);

      osc.start(now);
      osc.stop(now + 0.40);
    } catch (_) {}
  }

  /// Safe stub for dialer ringback cleanup
  void stopDialingTone() {}
}
