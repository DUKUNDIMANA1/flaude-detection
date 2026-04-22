// lib/services/websocket_service.dart
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../utils/constants.dart';

typedef AlertCallback = void Function(Map<String, dynamic> alert);
typedef TransactionCallback = void Function(Map<String, dynamic> txn);

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  WebSocketChannel? _channel;
  bool _connected = false;
  final List<AlertCallback> _alertListeners = [];
  final List<TransactionCallback> _txnListeners = [];
  final _storage = const FlutterSecureStorage();

  bool get isConnected => _connected;

  Future<void> connect() async {
    if (_connected) return;
    try {
      final token = await _storage.read(key: AppConstants.tokenKey);
      final wsUri = Uri.parse(
          '${AppConstants.wsUrl}/socket.io/?EIO=4&transport=websocket');
      _channel = WebSocketChannel.connect(wsUri);
      _connected = true;

      _channel!.stream.listen(
        (data) => _handleMessage(data),
        onError: (_) => _handleDisconnect(),
        onDone: () => _handleDisconnect(),
      );

      // Send join event
      if (token != null) {
        _send({'event': 'join_alerts', 'data': {'token': token}});
      }
    } catch (_) {
      _connected = false;
    }
  }

  void _handleMessage(dynamic raw) {
    try {
      final decoded = jsonDecode(raw.toString());
      final event = decoded['event'] as String?;
      final data  = decoded['data'] as Map<String, dynamic>?;
      if (data == null) return;

      if (event == 'new_alert') {
        for (final cb in _alertListeners) cb(data);
      } else if (event == 'transaction_update') {
        for (final cb in _txnListeners) cb(data);
      }
    } catch (_) {}
  }

  void _handleDisconnect() {
    _connected = false;
    Future.delayed(const Duration(seconds: 5), connect);
  }

  void _send(Map<String, dynamic> payload) {
    _channel?.sink.add(jsonEncode(payload));
  }

  void onAlert(AlertCallback cb) => _alertListeners.add(cb);
  void onTransaction(TransactionCallback cb) => _txnListeners.add(cb);
  void removeAlertListener(AlertCallback cb) => _alertListeners.remove(cb);
  void removeTransactionListener(TransactionCallback cb) => _txnListeners.remove(cb);

  void disconnect() {
    _channel?.sink.close();
    _connected = false;
  }
}
