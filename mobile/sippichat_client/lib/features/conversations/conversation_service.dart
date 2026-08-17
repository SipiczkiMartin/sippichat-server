import 'package:sippichat_client/core/network/api_client.dart';
import 'package:sippichat_client/features/conversations/models/conversation.dart';

class ConversationService {
  final ApiClient apiClient;

  ConversationService(this.apiClient);

  Future<List<Conversation>> getConversations() async {
    final response = await apiClient.dio.get('/conversations');

    print("RESPONSE:");
    print(response.data);

    final List<dynamic> data = response.data;

    return data
        .map(
          (json) => Conversation.fromJson(
        json as Map<String, dynamic>,
      ),
    )
        .toList();
  }

  Future<Conversation> createConversation(String userID) async{
    final response = await apiClient.dio.post(
      '/conversations',
      data: {
        "user_id":userID
      }
    );
    return Conversation.fromJson(response.data as Map<String, dynamic>);

  }
}