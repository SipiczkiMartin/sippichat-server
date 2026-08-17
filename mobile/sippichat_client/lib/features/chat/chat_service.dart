import 'package:sippichat_client/core/network/api_client.dart';

import 'models/message.dart';
import 'models/message_page.dart';

class ChatService {
  final ApiClient apiClient;

  ChatService(this.apiClient);

  Future<MessagePage> getMessages(
      String conversationId, {
        int limit = 50,
        String? before,
      }) async {
    final response = await apiClient.dio.get(
      "/conversations/$conversationId/messages",
      queryParameters: {
        "limit": limit,
        if (before != null) "before": before,
      },
    );

    return MessagePage.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  Future<Message> sendMessage(
      String conversationId,
      String content,
      ) async {
    final response = await apiClient.dio.post(
      "/conversations/$conversationId/messages",
      data: {
        "content": content,
      },
    );

    return Message.fromJson(response.data);
  }

  Future<List<Message>> syncMessages(
      String conversationId, {
        required DateTime afterCreatedAt,
        required String afterId,
  }) async {
    final response = await apiClient.dio.post(
      "/conversations/$conversationId/messages/sync",
      data: {
        "after_created_at":afterCreatedAt.toUtc().toIso8601String(),
        "after_id":afterId,
      }
    );

    final data = response.data as Map<String, dynamic>;
    final messagesJson = data["messages"] as List<dynamic>;
    return messagesJson.map(
        (json) => Message.fromJson(json as Map<String,dynamic>)
    ).toList();
  }
}