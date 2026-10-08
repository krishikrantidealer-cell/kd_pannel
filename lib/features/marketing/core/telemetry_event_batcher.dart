import 'dart:async';
import 'package:flutter/foundation.dart';

/// Buffers high-frequency real-time events into a single throttled update window.
class TelemetryEventBatcher<T> {
  final Duration windowDuration;
  final void Function(List<T> batchedItems) onFlush;

  Timer? _debounceTimer;
  final List<T> _buffer = [];
  bool _isDisposed = false;

  TelemetryEventBatcher({
    this.windowDuration = const Duration(milliseconds: 1500),
    required this.onFlush,
  });

  void add(T item) {
    if (_isDisposed) return;
    _buffer.add(item);
    _scheduleFlush();
  }

  void addAll(Iterable<T> items) {
    if (_isDisposed) return;
    _buffer.addAll(items);
    _scheduleFlush();
  }

  void _scheduleFlush() {
    if (_debounceTimer?.isActive ?? false) return;
    _debounceTimer = Timer(windowDuration, _flush);
  }

  void _flush() {
    if (_isDisposed || _buffer.isEmpty) return;
    final List<T> itemsToEmit = List<T>.from(_buffer);
    _buffer.clear();
    onFlush(itemsToEmit);
  }

  void flushImmediately() {
    _debounceTimer?.cancel();
    _flush();
  }

  void dispose() {
    _isDisposed = true;
    _debounceTimer?.cancel();
    _buffer.clear();
  }
}
