import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// Universal native audio feedback service for telephony dialing & call events
class TelephonyAudioService {
  static final TelephonyAudioService _instance = TelephonyAudioService._internal();
  factory TelephonyAudioService() => _instance;
  TelephonyAudioService._internal();

  Timer? _pulseTimer;
  bool _isPlaying = false;
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

  void startDialingTone() {
    if (_isPlaying) return;
    _isPlaying = true;

    if (kIsWeb) {
      _startWebDialingTone();
    }
  }

  void stopDialingTone() {
    _isPlaying = false;
    _pulseTimer?.cancel();
    _pulseTimer = null;
    if (kIsWeb) {
      _stopWebDialingTone();
    }
  }

  void playHangupTone() {
    stopDialingTone();
    if (!kIsWeb) return;
    try {
      final ctx = _getOrCreateContext();
      final now = ctx.currentTime;

      final gain = ctx.createGain();
      gain.gain.setValueAtTime(0.12, now);
      gain.gain.exponentialRampToValueAtTime(0.0001, now + 0.4);

      final osc = ctx.createOscillator();
      osc.type = 'triangle';
      osc.frequency.setValueAtTime(480, now);
      osc.frequency.exponentialRampToValueAtTime(180, now + 0.4);

      osc.connect(gain);
      gain.connect(ctx.destination);

      osc.start(now);
      osc.stop(now + 0.4);
    } catch (_) {}
  }

  void _startWebDialingTone() {
    try {
      // Pulse loop: 1.2s tone on, 2.0s tone off (standard Indian PBX ringback cadence)
      _playSinglePulse();
      _pulseTimer = Timer.periodic(const Duration(milliseconds: 3200), (timer) {
        if (!_isPlaying) {
          timer.cancel();
          return;
        }
        _playSinglePulse();
      });
    } catch (_) {}
  }

  void _playSinglePulse() {
    if (!kIsWeb || !_isPlaying) return;
    try {
      final ctx = _getOrCreateContext();
      final now = ctx.currentTime;
      final duration = 1.2;

      final gain = ctx.createGain();
      gain.gain.setValueAtTime(0.10, now);
      gain.gain.exponentialRampToValueAtTime(0.0001, now + duration);

      final osc1 = ctx.createOscillator();
      final osc2 = ctx.createOscillator();

      osc1.type = 'sine';
      osc2.type = 'sine';

      // 400Hz + 450Hz Indian PBX ringback dual tone
      osc1.frequency.setValueAtTime(400, now);
      osc2.frequency.setValueAtTime(450, now);

      osc1.connect(gain);
      osc2.connect(gain);
      gain.connect(ctx.destination);

      osc1.start(now);
      osc2.start(now);

      osc1.stop(now + duration);
      osc2.stop(now + duration);
    } catch (_) {}
  }

  /// Crisp notification chime when an inbound WhatsApp message arrives
  void playIncomingMessageTone() {
    if (!kIsWeb) return;
    try {
      final ctx = _getOrCreateContext();
      final now = ctx.currentTime;

      final gain = ctx.createGain();
      gain.gain.setValueAtTime(0.08, now);
      gain.gain.exponentialRampToValueAtTime(0.0001, now + 0.35);

      final osc = ctx.createOscillator();
      osc.type = 'sine';
      osc.frequency.setValueAtTime(880, now); // A5 note
      osc.frequency.setValueAtTime(1174.66, now + 0.08); // D6 note

      osc.connect(gain);
      gain.connect(ctx.destination);

      osc.start(now);
      osc.stop(now + 0.35);
    } catch (_) {}
  }

  /// Alert chime for incoming or updated telephony calls
  void playCallAlertTone() {
    if (!kIsWeb) return;
    try {
      final ctx = _getOrCreateContext();
      final now = ctx.currentTime;

      final gain = ctx.createGain();
      gain.gain.setValueAtTime(0.12, now);
      gain.gain.exponentialRampToValueAtTime(0.0001, now + 0.5);

      final osc = ctx.createOscillator();
      osc.type = 'triangle';
      osc.frequency.setValueAtTime(587.33, now); // D5
      osc.frequency.setValueAtTime(880, now + 0.15); // A5

      osc.connect(gain);
      gain.connect(ctx.destination);

      osc.start(now);
      osc.stop(now + 0.5);
    } catch (_) {}
  }

  /// Missed call notification tone
  void playCallMissedTone() {
    if (!kIsWeb) return;
    try {
      final ctx = _getOrCreateContext();
      final now = ctx.currentTime;

      final gain = ctx.createGain();
      gain.gain.setValueAtTime(0.10, now);
      gain.gain.exponentialRampToValueAtTime(0.0001, now + 0.4);

      final osc = ctx.createOscillator();
      osc.type = 'sawtooth';
      osc.frequency.setValueAtTime(440, now);
      osc.frequency.exponentialRampToValueAtTime(220, now + 0.4);

      osc.connect(gain);
      gain.connect(ctx.destination);

      osc.start(now);
      osc.stop(now + 0.4);
    } catch (_) {}
  }

  void _stopWebDialingTone() {
    if (!kIsWeb) return;
    try {
      if (_audioContext != null && _audioContext!.state == 'running') {
        _audioContext!.suspend();
      }
    } catch (_) {}
  }
}
