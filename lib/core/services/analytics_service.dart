import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:kd_pannel/core/network/api_client.dart';
import 'package:kd_pannel/core/auth/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../network/websocket_service.dart';

/// Gold Standard Event Tracking System
/// Implementation: Dual-Track Ingestion (Batched History + Real-time Heartbeat)
class AnalyticsService extends WidgetsBindingObserver {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  final ApiClient _apiClient = ApiClient();
  static const String _storageKey = 'krishi_analytics_v1_queue';
  static const String _schemaVersion = '1.1.0';
  
  // Enterprise Settings
  static const int _batchThreshold = 20; 
  static const Duration _batchInterval = Duration(seconds: 45); // Historical logs
  
  // Adaptive Heartbeat Settings
  static const Duration _activeHeartbeat = Duration(seconds: 15);
  static const Duration _idleHeartbeat = Duration(seconds: 60);
  static const Duration _idleThreshold = Duration(minutes: 5);
  
  List<Map<String, dynamic>> _localQueue = [];
  Timer? _flushTimer;
  Timer? _heartbeatTimer;
  bool _isProcessing = false;
  DateTime _lastActivity = DateTime.now();
  
  // Observability Metrics
  int _successCount = 0;
  int _failureCount = 0;
  int _totalDropped = 0;

  // Presence State
  String _currentScreen = 'Home';
  String _lastAction = 'App Open';

  /// Initialize the service and start the heartbeat
  Future<void> init() async {
    WidgetsBinding.instance.addObserver(this);
    await _loadFromDisk();
    _startHeartbeat();
    debugPrint('[Analytics] Pipeline online. Adaptive heartbeat active.');
  }

  /// Sets the current context for the real-time heartbeat
  void updateContext({String? screen, String? action}) {
    if (screen != null) _currentScreen = screen;
    if (action != null) _lastAction = action;
    _lastActivity = DateTime.now();
    _startHeartbeat(); // Recalculate interval if active
  }

  String _generateEventId() {
    return '${DateTime.now().millisecondsSinceEpoch}-${_localQueue.length}';
  }

  /// The Main Entry Point for behavioral tracking (Historical Track)
  Future<void> logEvent(String eventName, {Map<String, dynamic>? properties}) async {
    final userEmail = AuthService().currentUserEmail ?? 'Guest';
    final timestamp = DateTime.now().toUtc().toIso8601String();
    
    _lastAction = eventName; // Update presence context
    _lastActivity = DateTime.now();

    final event = {
      'eventId': _generateEventId(),
      'sessionId': AuthService().sessionId,
      'schemaVersion': _schemaVersion,
      'event': eventName,
      'user': userEmail,
      'timestamp': timestamp,
      'platform': kIsWeb ? 'Web' : defaultTargetPlatform.name.toLowerCase(),
      'properties': properties ?? {},
    };

    _localQueue.add(event);
    await _saveToDisk();

    if (_localQueue.length >= _batchThreshold) {
      flush();
    } else {
      _resetBatchTimer();
    }
  }

  // --- Real-time Pulse (The "How we know currently" Logic) ---

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    
    final isIdle = DateTime.now().difference(_lastActivity) > _idleThreshold;
    final interval = isIdle ? _idleHeartbeat : _activeHeartbeat;

    _heartbeatTimer = Timer.periodic(interval, (timer) {
      _sendHeartbeat();
    });
  }

  Future<void> _sendHeartbeat() async {
    final userEmail = AuthService().currentUserEmail;
    if (userEmail == null) return;

    // Use WebSocket if connected (highly efficient)
    if (WebSocketService().connectionStatusNow) {
      WebSocketService().updatePresence(
        currentScreen: _currentScreen,
        lastAction: _lastAction,
        extraData: {
          'userEmail': userEmail,
          'sessionId': AuthService().sessionId,
          'appVersion': _schemaVersion,
        },
      );
      return; // Skip HTTP if WS worked
    }

    // Fallback to HTTP only if WebSocket is disconnected
    try {
      await _apiClient.post('/events/heartbeat', {
        'user': userEmail,
        'sessionId': AuthService().sessionId,
        'currentScreen': _currentScreen,
        'lastAction': _lastAction,
        'device': kIsWeb ? 'Web' : defaultTargetPlatform.name.toUpperCase(),
      });
    } catch (_) {}
  }

  // --- Historical Flush Logic ---
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      flush();
      _heartbeatTimer?.cancel();
    } else if (state == AppLifecycleState.resumed) {
      _startHeartbeat();
    }
  }

  void _resetBatchTimer() {
    _flushTimer?.cancel();
    _flushTimer = Timer(_batchInterval, () => flush());
  }

  Future<void> flush() async {
    if (_isProcessing || _localQueue.isEmpty) return;
    _isProcessing = true;

    final batchToSend = List<Map<String, dynamic>>.from(_localQueue);
    final startTime = DateTime.now();
    
    try {
      final response = await _apiClient.post('/events/batch', {
        'events': batchToSend,
        'sentAt': DateTime.now().toUtc().toIso8601String(),
        'metrics': {
          'queueSize': _localQueue.length,
          'successCount': _successCount,
          'failureCount': _failureCount,
          'droppedCount': _totalDropped,
        }
      });

      if (response.statusCode == 200 || response.statusCode == 201) {
        final latency = DateTime.now().difference(startTime).inMilliseconds;
        debugPrint('[Analytics] Batch flushed. Size: ${batchToSend.length}, Latency: ${latency}ms');
        _successCount++;
        _localQueue.removeRange(0, batchToSend.length);
        await _saveToDisk();
      } else {
        _failureCount++;
      }
    } catch (e) {
      _failureCount++;
      debugPrint('[Analytics] Flush failed: $e');
      // If queue is too large, drop oldest to prevent memory issues (Observability point 9)
      if (_localQueue.length > 500) {
        _localQueue.removeRange(0, 100);
        _totalDropped += 100;
        await _saveToDisk();
      }
    } finally {
      _isProcessing = false;
    }
  }

  // --- Dashboard Data Fetching (Admin Use) ---

  Future<List<Map<String, dynamic>>> fetchEvents({String? userEmail}) async {
    try {
      final path = userEmail != null ? '/events?user=${Uri.encodeComponent(userEmail)}' : '/events';
      final response = await _apiClient.get(path);
      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);
        if (data is Map && data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['data'] ?? []);
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchRealTimeUsers() async {
    try {
      final response = await _apiClient.get('/events/realtime');
      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);
        if (data is Map && data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['data'] ?? []);
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // --- Persistence ---

  Future<void> _saveToDisk() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(_localQueue));
  }

  Future<void> _loadFromDisk() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_storageKey);
    if (data != null) {
      try { _localQueue = List<Map<String, dynamic>>.from(jsonDecode(data)); } catch (_) {}
    }
  }

  /// Flush any pending events, cancel active timers, and clear tracking queues/context
  Future<void> handleLogout() async {
    // 1. Flush any pending events immediately
    await flush();

    // 2. Cancel timers to free up resources
    _flushTimer?.cancel();
    _heartbeatTimer?.cancel();
    _flushTimer = null;
    _heartbeatTimer = null;

    // 3. Clear the queue and persist
    _localQueue.clear();
    await _saveToDisk();

    // 4. Reset tracking screen contexts
    _currentScreen = 'Home';
    _lastAction = 'App Open';
    _successCount = 0;
    _failureCount = 0;
    _totalDropped = 0;
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _flushTimer?.cancel();
    _heartbeatTimer?.cancel();
  }
}
