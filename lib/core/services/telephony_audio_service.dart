import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// Studio-grade native Web Audio synthesis engine for Telephony & CRM notifications.
/// Built to ITU-T, Twilio, and Google Voice acoustic standards.
class TelephonyAudioService {
  static final TelephonyAudioService _instance = TelephonyAudioService._internal();
  factory TelephonyAudioService() => _instance;
  TelephonyAudioService._internal();

  Timer? _pulseTimer;
  Timer? _inboundRingTimer;
  bool _isDialing = false;
  bool _isInboundRinging = false;
  web.AudioContext? _audioContext;

  web.AudioContext _getOrCreateContext() {
    if (_audioContext == null || _audioContext!.state == 'closed') {
      _audioContext = web.AudioContext();
    }
    if (_audioContext!.state == 'suspended') {
      _audioContext!.resume();
    }
    return _audioContext!;
  }

  // ── 1. Outbound Dialing Ringback Tone ───────────────────────────────────────
  /// Starts the softphone ringback cadence (1.2s tone, 2.0s silence)
  void startDialingTone() {
    if (_isDialing) return;
    _isDialing = true;
    if (kIsWeb) {
      _startWebDialingTone();
    }
  }

  void stopDialingTone() {
    _isDialing = false;
    _pulseTimer?.cancel();
    _pulseTimer = null;
  }

  void _startWebDialingTone() {
    try {
      _playSingleDialingPulse();
      _pulseTimer?.cancel();
      _pulseTimer = Timer.periodic(const Duration(milliseconds: 3200), (timer) {
        if (!_isDialing) {
          timer.cancel();
          return;
        }
        _playSingleDialingPulse();
      });
    } catch (_) {}
  }

  void _playSingleDialingPulse() {
    if (!kIsWeb || !_isDialing) return;
    try {
      final ctx = _getOrCreateContext();
      final now = ctx.currentTime;
      const duration = 1.2;

      // Master gain with smooth acoustic envelope (anti-pop attack & smooth decay)
      final gain = ctx.createGain();
      gain.gain.setValueAtTime(0.0001, now);
      gain.gain.linearRampToValueAtTime(0.09, now + 0.06);
      gain.gain.setValueAtTime(0.09, now + duration - 0.12);
      gain.gain.exponentialRampToValueAtTime(0.0001, now + duration);

      // Acoustic Lowpass Filter for warmth and zero harsh harmonics
      final filter = ctx.createBiquadFilter();
      filter.type = 'lowpass';
      filter.frequency.setValueAtTime(1400, now);

      // ITU-T Standard Dual Tone (400Hz + 450Hz)
      final osc1 = ctx.createOscillator();
      final osc2 = ctx.createOscillator();
      osc1.type = 'sine';
      osc2.type = 'sine';
      osc1.frequency.setValueAtTime(400, now);
      osc2.frequency.setValueAtTime(450, now);

      osc1.connect(gain);
      osc2.connect(gain);
      gain.connect(filter);
      filter.connect(ctx.destination);

      osc1.start(now);
      osc2.start(now);
      osc1.stop(now + duration);
      osc2.stop(now + duration);
    } catch (_) {}
  }

  // ── 2. Call Connected Chime (Uplifting Harmonic 2-Tone) ─────────────────────
  /// Played when agent or customer answers and audio channel is active
  void playCallConnectedTone() {
    stopDialingTone();
    stopInboundRinging();
    if (!kIsWeb) return;
    try {
      final ctx = _getOrCreateContext();
      final now = ctx.currentTime;

      // Note 1: C5 (523.25 Hz)
      final gain1 = ctx.createGain();
      gain1.gain.setValueAtTime(0.0001, now);
      gain1.gain.linearRampToValueAtTime(0.10, now + 0.02);
      gain1.gain.exponentialRampToValueAtTime(0.0001, now + 0.14);

      final osc1 = ctx.createOscillator();
      osc1.type = 'sine';
      osc1.frequency.setValueAtTime(523.25, now);
      osc1.connect(gain1);
      gain1.connect(ctx.destination);
      osc1.start(now);
      osc1.stop(now + 0.14);

      // Note 2: Harmony G5 (783.99 Hz) + C6 (1046.5 Hz)
      final note2Start = now + 0.08;
      final gain2 = ctx.createGain();
      gain2.gain.setValueAtTime(0.0001, note2Start);
      gain2.gain.linearRampToValueAtTime(0.12, note2Start + 0.03);
      gain2.gain.exponentialRampToValueAtTime(0.0001, note2Start + 0.35);

      final osc2A = ctx.createOscillator();
      final osc2B = ctx.createOscillator();
      osc2A.type = 'sine';
      osc2B.type = 'sine';
      osc2A.frequency.setValueAtTime(783.99, note2Start);
      osc2B.frequency.setValueAtTime(1046.50, note2Start);

      osc2A.connect(gain2);
      osc2B.connect(gain2);
      gain2.connect(ctx.destination);

      osc2A.start(note2Start);
      osc2B.start(note2Start);
      osc2A.stop(note2Start + 0.35);
      osc2B.stop(note2Start + 0.35);
    } catch (_) {}
  }

  // ── 3. Call Ended / Hangup Tone (Gentle Descending Softphone Cadence) ───────
  void playHangupTone() {
    stopDialingTone();
    stopInboundRinging();
    if (!kIsWeb) return;
    try {
      final ctx = _getOrCreateContext();
      final now = ctx.currentTime;

      // Soft 3-tone descending chord (G5 -> E5 -> C5)
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

  // ── 4. Inbound Panel Ringing (Modern Enterprise Softphone Chime) ────────────
  void startInboundRinging() {
    if (_isInboundRinging) return;
    _isInboundRinging = true;
    if (kIsWeb) {
      _playSingleInboundChime();
      _inboundRingTimer?.cancel();
      _inboundRingTimer = Timer.periodic(const Duration(milliseconds: 2800), (timer) {
        if (!_isInboundRinging) {
          timer.cancel();
          return;
        }
        _playSingleInboundChime();
      });
    }
  }

  void stopInboundRinging() {
    _isInboundRinging = false;
    _inboundRingTimer?.cancel();
    _inboundRingTimer = null;
  }

  void _playSingleInboundChime() {
    if (!kIsWeb || !_isInboundRinging) return;
    try {
      final ctx = _getOrCreateContext();
      final now = ctx.currentTime;

      // Modern Pentatonic Marimba Arpeggio: E5, G#5, B5, E6
      final freqs = [659.25, 830.61, 987.77, 1318.51];
      for (int i = 0; i < freqs.length; i++) {
        final start = now + (i * 0.09);
        final dur = 0.40;

        final gain = ctx.createGain();
        gain.gain.setValueAtTime(0.0001, start);
        gain.gain.linearRampToValueAtTime(0.11, start + 0.02);
        gain.gain.exponentialRampToValueAtTime(0.0001, start + dur);

        final osc = ctx.createOscillator();
        osc.type = 'sine';
        osc.frequency.setValueAtTime(freqs[i], start);

        osc.connect(gain);
        gain.connect(ctx.destination);

        osc.start(start);
        osc.stop(start + dur);
      }
    } catch (_) {}
  }

  // ── 5. DTMF Keypad Tones (ITU-T Q.23 Dialpad Standard) ──────────────────────
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

  // ── 6. In-Call Controls Feedback (Mute, Unmute, Hold) ───────────────────────
  void playMuteTone() {
    _playSoftClick(520, 310);
  }

  void playUnmuteTone() {
    _playSoftClick(310, 520);
  }

  void playHoldTone() {
    if (!kIsWeb) return;
    try {
      final ctx = _getOrCreateContext();
      final now = ctx.currentTime;

      final gain = ctx.createGain();
      gain.gain.setValueAtTime(0.0001, now);
      gain.gain.linearRampToValueAtTime(0.08, now + 0.02);
      gain.gain.exponentialRampToValueAtTime(0.0001, now + 0.20);

      final osc = ctx.createOscillator();
      osc.type = 'sine';
      osc.frequency.setValueAtTime(587.33, now); // D5

      osc.connect(gain);
      gain.connect(ctx.destination);

      osc.start(now);
      osc.stop(now + 0.20);
    } catch (_) {}
  }

  // ── 7. CRM & WhatsApp Notification Chimes ──────────────────────────────────
  /// Glass marimba notification chime for incoming WhatsApp chats and updates
  void playIncomingMessageTone() {
    if (!kIsWeb) return;
    try {
      final ctx = _getOrCreateContext();
      final now = ctx.currentTime;

      // Bell Harmony: C6 (1046.5 Hz) + G6 (1567.98 Hz)
      final gain = ctx.createGain();
      gain.gain.setValueAtTime(0.0001, now);
      gain.gain.linearRampToValueAtTime(0.11, now + 0.015);
      gain.gain.exponentialRampToValueAtTime(0.0001, now + 0.35);

      final osc1 = ctx.createOscillator();
      final osc2 = ctx.createOscillator();
      osc1.type = 'sine';
      osc2.type = 'sine';
      osc1.frequency.setValueAtTime(1046.50, now);
      osc2.frequency.setValueAtTime(1567.98, now);

      osc1.connect(gain);
      osc2.connect(gain);
      gain.connect(ctx.destination);

      osc1.start(now);
      osc2.start(now);
      osc1.stop(now + 0.35);
      osc2.stop(now + 0.35);
    } catch (_) {}
  }

  /// Alert chime for call updates
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
}
