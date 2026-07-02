import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:kd_pannel/core/auth/auth_service.dart';
import 'package:kd_pannel/core/network/api_client.dart';
import 'package:kd_pannel/core/utils/navigation_service.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  bool _isConnected = false;
  bool _isConnecting = false;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  DateTime? _lastPing;

  // Streams for components to listen to updates
  final _leadsUpdateController = StreamController<void>.broadcast();
  final _dealersUpdateController = StreamController<void>.broadcast();
  final _ordersUpdateController = StreamController<void>.broadcast();
  final _notificationUpdateController = StreamController<void>.broadcast();
  final _presenceUpdateController = StreamController<Map<String, dynamic>>.broadcast();
  final _connectionStateController = StreamController<bool>.broadcast();

  Stream<void> get leadsUpdates => _leadsUpdateController.stream;
  Stream<void> get dealersUpdates => _dealersUpdateController.stream;
  Stream<void> get ordersUpdates => _ordersUpdateController.stream;
  Stream<void> get notificationUpdates => _notificationUpdateController.stream;
  Stream<Map<String, dynamic>> get presenceUpdates => _presenceUpdateController.stream;
  Stream<bool> get connectionStatus => _connectionStateController.stream;
  bool get connectionStatusNow => _isConnected;

  // Debounce timers for updates
  Timer? _leadsDebounce;
  Timer? _dealersDebounce;
  Timer? _ordersDebounce;
  Timer? _notificationDebounce;

  void _triggerLeadsUpdate() {
    _leadsDebounce?.cancel();
    _leadsDebounce = Timer(const Duration(milliseconds: 1500), () {
      if (!_leadsUpdateController.isClosed) {
        _leadsUpdateController.add(null);
      }
    });
  }

  void _triggerDealersUpdate() {
    _dealersDebounce?.cancel();
    _dealersDebounce = Timer(const Duration(milliseconds: 1500), () {
      if (!_dealersUpdateController.isClosed) {
        _dealersUpdateController.add(null);
      }
    });
  }

  void _triggerOrdersUpdate() {
    _ordersDebounce?.cancel();
    _ordersDebounce = Timer(const Duration(milliseconds: 1500), () {
      if (!_ordersUpdateController.isClosed) {
        _ordersUpdateController.add(null);
      }
    });
  }

  void _triggerNotificationUpdate() {
    _notificationDebounce?.cancel();
    _notificationDebounce = Timer(const Duration(milliseconds: 800), () {
      if (!_notificationUpdateController.isClosed) {
        _notificationUpdateController.add(null);
      }
    });
  }

  void connect() {
    if (_isConnected || _isConnecting) return;

    final userId = AuthService().currentUserId;
    if (userId == null) {
      // debugPrint('[WS] Cannot connect: no currentUserId found.');
      return;
    }

    _isConnecting = true;
    final baseApiUrl = ApiClient().baseUrl;
    final cleanUrl = baseApiUrl.replaceAll('/api', '');
    final wsProtocol = cleanUrl.startsWith('https') ? 'wss' : 'ws';
    final wsHost = cleanUrl.replaceFirst(RegExp(r'https?://'), '');
    final wsUri = Uri.parse('$wsProtocol://$wsHost/?userId=$userId');

    debugPrint('[WS] Connecting to $wsUri');

    try {
      _channel = WebSocketChannel.connect(wsUri);
      
      _subscription = _channel!.stream.listen(
        (message) {
          // Fallback: If we get any message, we are connected
          if (!_isConnected) {
            _isConnected = true;
            _isConnecting = false;
            _connectionStateController.add(true);
            _retryCount = 0;
            debugPrint('[WS] Connection established.');
          }
          _handleMessage(message);
        },
        onDone: () {
          debugPrint('[WS] Connection closed.');
          _handleDisconnect();
        },
        onError: (error) {
          debugPrint('[WS] Connection error: $error');
          _handleDisconnect();
        },
      );

      _startHeartbeat();
    } catch (e) {
      debugPrint('[WS] Connection exception: $e');
      _handleDisconnect();
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    // Tighter heartbeat (15s) for Cloud Run to prevent idle timeout
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (_isConnected) {
        _send({'type': 'PING', 'timestamp': DateTime.now().toIso8601String()});
      }
    });
  }

  void updatePresence({
    required String currentScreen,
    String? lastAction,
    Map<String, dynamic>? extraData,
  }) {
    if (!_isConnected) return;

    final presenceData = {
      'type': 'PRESENCE_UPDATE',
      'data': {
        'currentScreen': currentScreen,
        'lastAction': lastAction,
        'timestamp': DateTime.now().toIso8601String(),
        'platform': defaultTargetPlatform.toString(),
        ...?extraData,
      }
    };

    _send(presenceData);
  }

  void _send(Map<String, dynamic> data) {
    if (_channel != null && _isConnected) {
      _channel!.sink.add(jsonEncode(data));
    }
  }

  void _handleMessage(dynamic rawMessage) {
    // Only log significant messages to prevent console spam
    try {
      final data = jsonDecode(rawMessage.toString());
      final String? type = data['type'];

      if (type == 'PONG') {
        _lastPing = DateTime.now();
        return;
      }

      if (type != 'PRESENCE_UPDATE') {
        debugPrint('[WS] Message: $type');
      }

      switch (type) {
        case 'CONNECTION_ACK':
          _isConnected = true;
          _isConnecting = false;
          _connectionStateController.add(true);
          _retryCount = 0;
          debugPrint('[WS] Connection acknowledged by server.');
          break;
        case 'LEADS_UPDATE':
          _triggerLeadsUpdate();
          break;
        case 'DEALERS_UPDATE':
          _triggerDealersUpdate();
          break;
        case 'ORDERS_UPDATE':
          _triggerOrdersUpdate();
          break;
        case 'NOTIFICATION_RECEIVED':
          _triggerNotificationUpdate();
          break;
        case 'PRESENCE_UPDATE':
          if (data['data'] != null) {
            _presenceUpdateController.add(Map<String, dynamic>.from(data['data']));
          }
          break;
        case 'FORCE_LOGOUT':
          NavigationService.navigateToLogin(showSessionExpiredMessage: true);
          break;
      }
    } catch (e) {
      // Fallback for legacy plain-string messages
      final String msgStr = rawMessage.toString();
      if (msgStr.contains('LEADS_UPDATE')) _triggerLeadsUpdate();
      if (msgStr.contains('DEALERS_UPDATE')) _triggerDealersUpdate();
      if (msgStr.contains('ORDERS_UPDATE')) _triggerOrdersUpdate();
      if (msgStr.contains('NOTIFICATION_RECEIVED')) _triggerNotificationUpdate();
    }
  }

  int _retryCount = 0;
  void _handleDisconnect() {
    _isConnected = false;
    _isConnecting = false;
    _connectionStateController.add(false);
    _heartbeatTimer?.cancel();
    _reconnect();
  }

  void _reconnect() {
    _reconnectTimer?.cancel();
    
    // Clean backoff: 5, 10, 20, 30 seconds
    final seconds = [5, 10, 20, 30][(_retryCount >= 4 ? 3 : _retryCount)];
    final delay = Duration(seconds: seconds);
    
    debugPrint('[WS] Connection lost. Retrying in $seconds seconds...');
    
    _reconnectTimer = Timer(delay, () {
      if (!_isConnected && !_isConnecting && AuthService().currentUserId != null) {
        _retryCount++;
        connect();
      }
    });
  }

  void disconnect() {
    _retryCount = 0;
    _leadsDebounce?.cancel();
    _dealersDebounce?.cancel();
    _ordersDebounce?.cancel();
    _notificationDebounce?.cancel();
    _reconnectTimer?.cancel();
    _heartbeatTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _isConnected = false;
    _connectionStateController.add(false);
    debugPrint('[WS] Disconnected');
  }
}
