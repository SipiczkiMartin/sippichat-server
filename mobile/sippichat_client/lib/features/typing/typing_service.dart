import 'package:flutter/cupertino.dart';

import '../../core/network/websocket_client.dart';

class TypingService {
  final WebsocketClient socket;

  TypingService(this.socket);

  int _startedCount = 0;

  void started(String conversationId) {
    _startedCount++;

    debugPrint(
      "TYPING SERVICE STARTED "
          "count=$_startedCount "
          "conversation=$conversationId "
          "service=${identityHashCode(this)}",
    );

    debugPrintStack();

    socket.sendTypingStarted(conversationId);
  }

  void stopped(String conversationId) {
    debugPrint(
      "TYPING SERVICE STOPPED "
          "conversation=$conversationId "
          "service=${identityHashCode(this)}",
    );

    debugPrintStack();

    socket.sendTypingStopped(conversationId);
  }
}