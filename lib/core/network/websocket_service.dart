import 'dart:async';
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
  
  // Streams for components to listen to updates
  final _leadsUpdateController = StreamController<void>.broadcast();
  final _dealersUpdateController = StreamController<void>.broadcast();
  final _notificationUpdateController = StreamController<void>.broadcast();

  Stream<void> get leadsUpdates => _leadsUpdateController.stream;
  Stream<void> get dealersUpdates => _dealersUpdateController.stream;
  Stream<void> get notificationUpdates => _notificationUpdateController.stream;

  void connect() {
    if (_isConnected) return;

    final userId = AuthService().currentUserId;
    if (userId == null) {
      debugPrint('[WS] Cannot connect: no currentUserId found.');
      return;
    }

    // Replace http/https with ws/wss from ApiClient baseUrl
    final baseApiUrl = ApiClient().baseUrl; // e.g., 'https://krishi-backend-.../api'
    final cleanUrl = baseApiUrl.replaceAll('/api', '');
    final wsProtocol = cleanUrl.startsWith('https') ? 'wss' : 'ws';
    final wsHost = cleanUrl.replaceFirst(RegExp(r'https?://'), '');
    final wsUri = Uri.parse('$wsProtocol://$wsHost/?userId=$userId');

    debugPrint('[WS] Connecting to $wsUri');

    try {
      _channel = WebSocketChannel.connect(wsUri);
      _isConnected = true;

      _subscription = _channel!.stream.listen(
        (message) {
          _handleMessage(message);
        },
        onDone: () {
          debugPrint('[WS] Connection closed. Retrying in 5 seconds...');
          _isConnected = false;
          _reconnect();
        },
        onError: (error) {
          debugPrint('[WS] Error: $error');
          _isConnected = false;
          _reconnect();
        },
      );
    } catch (e) {
      debugPrint('[WS] Connection exception: $e');
      _isConnected = false;
      _reconnect();
    }
  }

  void _handleMessage(dynamic rawMessage) {
    debugPrint('[WS] Received: $rawMessage');
    try {
      final String msgStr = rawMessage.toString();
      if (msgStr.contains('LEADS_UPDATE')) {
        _leadsUpdateController.add(null);
      }
      if (msgStr.contains('DEALERS_UPDATE')) {
        _dealersUpdateController.add(null);
      }
      if (msgStr.contains('NOTIFICATION_RECEIVED')) {
        _notificationUpdateController.add(null);
      }
      if (msgStr.contains('FORCE_LOGOUT')) {
        NavigationService.navigateToLogin(showSessionExpiredMessage: true);
      }
    } catch (e) {
      debugPrint('[WS] Error parsing message: $e');
    }
  }

  Timer? _reconnectTimer;
  void _reconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (!_isConnected && AuthService().currentUserId != null) {
        connect();
      }
    });
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _isConnected = false;
    debugPrint('[WS] Disconnected');
  }
}
