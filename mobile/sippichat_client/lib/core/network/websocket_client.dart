import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sippichat_client/features/auth/auth_session_manager.dart';
import 'package:web_socket_channel/io.dart';

enum WebSocketConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
}

class WebsocketClient {

  WebsocketClient();

  static const Duration reconnectDelay = Duration(seconds: 10);

  IOWebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;

  Function(Map<String, dynamic>)? onEvent;

  WebSocketConnectionState _connectionState =
      WebSocketConnectionState.disconnected;

  WebSocketConnectionState get connectionState => _connectionState;

  bool get isConnected =>
      _connectionState == WebSocketConnectionState.connected;

  bool _shouldReconnect = true;

  int _reconnectAttempt = 0;

  // ------------------------------------------------------------
  // CONNECT
  // ------------------------------------------------------------

  Future<void> connect() async {
    if (_connectionState == WebSocketConnectionState.connecting ||
        _connectionState == WebSocketConnectionState.connected) {
      debugPrint(
        "WebSocket: connect ignored, already "
        "${_connectionState.name}",
      );

      return;
    }

    _shouldReconnect = true;

    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    await _connect();
  }

  bool _connectInProgress = false;

  Future<void> _connect() async {
    if (!_shouldReconnect || _channel != null || _connectInProgress) {
      return;
    }

    _connectInProgress = true;

    if (_channel != null) {
      return;
    }

    final token = "token";


    if (!_shouldReconnect) {
      return;
    }

    if (token == null || token.isEmpty) {
      debugPrint("WebSocket: no valid access token");

      _setState(WebSocketConnectionState.disconnected);

      return;
    }

    final reconnecting = _reconnectAttempt > 0;

    _setState(
      reconnecting
          ? WebSocketConnectionState.reconnecting
          : WebSocketConnectionState.connecting,
    );

    debugPrint(
      reconnecting
          ? "WebSocket: reconnect attempt #$_reconnectAttempt"
          : "WebSocket: connecting...",
    );

    try {
      final channel = IOWebSocketChannel.connect(
        Uri.parse("ws://10.0.2.2:8080/ws"),
        headers: {"Authorization": "Bearer $token"},
      );

      _channel = channel;

      _subscription = channel.stream.listen(
        (event) {
          try {
            final String text;

            if (event is String) {
              text = event;
            } else if (event is List<int>) {
              text = utf8.decode(event);
            } else {
              debugPrint(
                "WebSocket: unsupported event "
                "${event.runtimeType}",
              );
              return;
            }

            debugPrint("WebSocket RECEIVED: $text");

            final decoded = jsonDecode(text);

            if (decoded is Map<String, dynamic>) {
              handleEvent(decoded);
            }
          } catch (e, stack) {
            debugPrint("WebSocket decode error: $e");

            debugPrintStack(stackTrace: stack);
          }
        },

        onError: (error, stack) {
          debugPrint(
            "WebSocket ERROR: "
            "code=${channel.closeCode}, "
            "reason=${channel.closeReason}",
          );

          _connectionLost();
        },

        onDone: () {
          debugPrint(
            "WebSocket DONE: "
            "code=${channel.closeCode}, "
            "reason=${channel.closeReason}",
          );

          _connectionLost();
        },
      );

      await channel.ready;

      if (_channel != channel) {
        debugPrint("WebSocket: stale connection");

        return;
      }

      if (!_shouldReconnect) {
        debugPrint("WebSocket: connection cancelled");

        await _cleanupSocket();
        return;
      }

      _reconnectAttempt = 0;

      _setState(WebSocketConnectionState.connected);

      debugPrint("WebSocket connected");
    } catch (e, stack) {
      debugPrint("WebSocket connection failed: $e");

      debugPrintStack(stackTrace: stack);

      await _cleanupSocket();

      _connectionLost();
    } finally {
      _connectInProgress = false;
    }
  }

  // ------------------------------------------------------------
  // CONNECTION LOST
  // ------------------------------------------------------------

  void _connectionLost() {
    if (!_shouldReconnect) {
      _setState(WebSocketConnectionState.disconnected);

      return;
    }

    // Don't schedule multiple timers.
    if (_reconnectTimer != null) {
      return;
    }

    unawaited(_cleanupSocket());

    _reconnectAttempt++;

    _setState(WebSocketConnectionState.reconnecting);

    debugPrint("WebSocket: connection lost");

    debugPrint(
      "WebSocket: scheduling reconnect attempt "
      "#$_reconnectAttempt in "
      "${reconnectDelay.inSeconds}s",
    );

    _reconnectTimer = Timer(reconnectDelay, () {
      _reconnectTimer = null;

      if (!_shouldReconnect) {
        return;
      }

      _connect();
    });
  }

  // ------------------------------------------------------------
  // SEND
  // ------------------------------------------------------------

  void send(Map<String, dynamic> data) {
    if (!isConnected || _channel == null) {
      debugPrint("WebSocket: not connected, message not sent");

      return;
    }

    final encoded = jsonEncode(data);

    debugPrint("WebSocket SEND: $encoded");

    _channel!.sink.add(encoded);
  }

  void sendTypingStarted(String conversationId) {
    debugPrint(
      ">>> SEND TYPING STARTED "
      "socket=${identityHashCode(this)} "
      "conversation=$conversationId",
    );

    debugPrintStack();

    send({
      "type": "typing.started",
      "payload": {"conversation_id": conversationId},
    });
  }

  void sendTypingStopped(String conversationId) {
    send({
      "type": "typing.stopped",
      "payload": {"conversation_id": conversationId},
    });
  }

  // ------------------------------------------------------------
  // EVENTS
  // ------------------------------------------------------------

  void handleEvent(Map<String, dynamic> event) {
    onEvent?.call(event);
  }

  // ------------------------------------------------------------
  // DISCONNECT
  // ------------------------------------------------------------

  Future<void> disconnect() async {
    debugPrint(
      "!!! WEBSOCKET DISCONNECT CALLED !!!\n"
          "${StackTrace.current}",
    );

    _shouldReconnect = false;

    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    _reconnectAttempt = 0;

    await _cleanupSocket();

    _setState(WebSocketConnectionState.disconnected);
  }

  Future<void> _cleanupSocket() async {
    debugPrint(
      "!!! WEBSOCKET CLEANUP CALLED !!!\n"
      "${StackTrace.current}",
    );

    final subscription = _subscription;
    final channel = _channel;

    _subscription = null;
    _channel = null;

    await subscription?.cancel();

    try {
      await channel?.sink.close();
    } catch (e) {
      debugPrint("WebSocket cleanup error: $e");
    }
  }

  // ------------------------------------------------------------
  // STATE
  // ------------------------------------------------------------

  void _setState(WebSocketConnectionState state) {
    _connectionState = state;

    debugPrint("WebSocket state: $state");
  }

  Future<void> dispose() async {
    await disconnect();
  }
}
