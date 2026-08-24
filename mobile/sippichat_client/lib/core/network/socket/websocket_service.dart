import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sippichat_client/core/storage/token_storage.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketService {
  final TokenStorage tokenStorage;

  WebSocketChannel? _socket;

  StreamSubscription? _socketSubscription;

  Timer? _reconnectTimer;

  Future<void>? _connecting;

  bool _shouldReconnect = true;
  bool _disposed = false;

  int _reconnectAttempt = 0;

  static const Duration _initialReconnectDelay = Duration(seconds: 1);

  static const Duration _maxReconnectDelay = Duration(seconds: 30);

  WebSocketService(this.tokenStorage);

  bool get isConnected => _socket != null;

  final _eventController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get events => _eventController.stream;

  Future<void> connect({required String url}) async {
    if (_disposed) {
      return;
    }

    _shouldReconnect = true;

    if (isConnected) {
      return;
    }

    if (_connecting != null) {
      return _connecting!;
    }

    _connecting = _connect(url);

    try {
      await _connecting;
    } finally {
      _connecting = null;
    }
  }

  Future<void> _connect(String url) async {
    final accessToken = await tokenStorage.getAccessToken();

    if (accessToken == null || accessToken.isEmpty) {
      debugPrint('WS: no access token available');

      if (_shouldReconnect && !_disposed) {
        _scheduleReconnect(url);
      }

      return;
    }

    debugPrint(
      'WS: connecting... '
      'attempt=${_reconnectAttempt + 1}',
    );

    try {
      final baseUri = Uri.parse(url);

      final uri = baseUri.replace(
        queryParameters: {...baseUri.queryParameters, 'token': accessToken},
      );

      // Never print the actual JWT.
      final safeUri = uri.replace(
        queryParameters: {...uri.queryParameters, 'token': '***'},
      );

      debugPrint('WS: connecting to $safeUri');

      final socket = WebSocketChannel.connect(uri);

      await socket.ready;

      if (_disposed || !_shouldReconnect) {
        await socket.sink.close();
        return;
      }

      _socket = socket;

      _reconnectAttempt = 0;

      debugPrint('WS: connected');

      _socketSubscription = socket.stream.listen(
        (data) {
          _handleData(data);
        },
        onDone: () {
          debugPrint('WS: disconnected');

          _socket = null;
          _socketSubscription = null;

          if (_shouldReconnect && !_disposed) {
            _scheduleReconnect(url);
          }
        },
        onError: (error) {
          debugPrint('WS ERROR: $error');

          _socket = null;
          _socketSubscription = null;

          if (_shouldReconnect && !_disposed) {
            _scheduleReconnect(url);
          }
        },
        cancelOnError: false,
      );
    } catch (e, stackTrace) {
      debugPrint('WS CONNECT ERROR: $e');
      debugPrintStack(stackTrace: stackTrace);

      _socket = null;
      _socketSubscription = null;

      if (_shouldReconnect && !_disposed) {
        _scheduleReconnect(url);
      }
    }
  }

  void _handleData(dynamic data) {
    debugPrint('WS RECEIVED: $data');

    if (data is! String) {
      return;
    }

    try {
      final decoded = jsonDecode(data);

      if (decoded is Map<String, dynamic>) {
        _eventController.add(decoded);
      }
    } catch (e) {
      debugPrint('WS JSON ERROR: $e');
    }
  }

  void _scheduleReconnect(String url) {
    if (_disposed || !_shouldReconnect) {
      return;
    }

    if (_reconnectTimer?.isActive == true) {
      return;
    }

    final delay = _calculateReconnectDelay();

    _reconnectAttempt++;

    debugPrint(
      'WS: reconnect scheduled in '
      '${delay.inSeconds}s '
      '(attempt $_reconnectAttempt)',
    );

    _reconnectTimer = Timer(delay, () {
      _reconnectTimer = null;

      if (_disposed || !_shouldReconnect || isConnected) {
        return;
      }

      connect(url: url);
    });
  }

  Duration _calculateReconnectDelay() {
    if (_reconnectAttempt == 0) {
      return _initialReconnectDelay;
    }

    final seconds = 1 << _reconnectAttempt;

    return Duration(seconds: seconds.clamp(1, _maxReconnectDelay.inSeconds));
  }

  void send({required String type, required Map<String, dynamic> payload}) {
    final socket = _socket;

    if (socket == null) {
      throw StateError('WebSocket is not connected.');
    }

    final event = {'type': type, 'payload': payload};

    debugPrint('WS SEND: $event');

    socket.sink.add(jsonEncode(event));
  }

  Future<void> disconnect() async {
    _shouldReconnect = false;

    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    final socket = _socket;

    _socket = null;

    if (socket == null) {
      return;
    }

    debugPrint('WS: disconnecting...');

    await _socketSubscription?.cancel();
    _socketSubscription = null;

    await socket.sink.close();

    debugPrint('WS: disconnected intentionally');
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }

    _disposed = true;
    _shouldReconnect = false;

    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    await _socketSubscription?.cancel();
    _socketSubscription = null;

    final socket = _socket;
    _socket = null;

    if (socket != null) {
      await socket.sink.close();
    }

    await _eventController.close();
  }
}
