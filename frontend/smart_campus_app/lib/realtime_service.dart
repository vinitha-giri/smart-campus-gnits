import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'api_config.dart';

/// Small shared realtime client. It reconnects automatically and exposes a
/// broadcast stream so existing screens do not need to change their APIs.
class RealtimeService {
  RealtimeService._();
  static final RealtimeService instance = RealtimeService._();

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnect;
  final _events = StreamController<Map<String, dynamic>>.broadcast();
  final List<Map<String, dynamic>> _history = [];
  bool _started = false;

  Stream<Map<String, dynamic>> get events => _events.stream;
  bool get isConnected => _channel != null;
  List<Map<String, dynamic>> get history => List.unmodifiable(_history);

  void start() {
    if (_started) return;
    _started = true;
    _connect();
  }

  void _connect() {
    _reconnect?.cancel();
    try {
      final channel = WebSocketChannel.connect(Uri.parse(ApiConfig.websocketUrl));
      _channel = channel;
      _subscription = channel.stream.listen((message) {
        try {
          final decoded = jsonDecode(message.toString());
          if (decoded is Map) {
            final event = Map<String, dynamic>.from(decoded);
            _history.insert(0, event);
            if (_history.length > 50) _history.removeLast();
            _events.add(event);
          }
        } catch (_) {}
      }, onDone: _scheduleReconnect, onError: (_, __) => _scheduleReconnect());
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _subscription?.cancel();
    _subscription = null;
    _channel = null;
    if (!_started) return;
    _reconnect?.cancel();
    _reconnect = Timer(const Duration(seconds: 4), _connect);
  }

  void dispose() {
    _started = false;
    _reconnect?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _channel = null;
  }
}
