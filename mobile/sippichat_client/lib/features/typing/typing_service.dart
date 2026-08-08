import 'package:sippichat_client/core/network/websocket_client.dart';

class TypingService {
  final WebsocketClient socket;

  TypingService(this.socket);

  void started(String conversationId){
    socket.send({
      "type":"typing.started",
      "conversation_id": conversationId,
    });
  }

  void stopped(String conversationId){
    socket.send({
      "type":"typing.stopped",
      "conversation_id": conversationId,
    });
  }

}