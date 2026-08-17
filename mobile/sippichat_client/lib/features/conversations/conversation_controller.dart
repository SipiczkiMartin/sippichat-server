import 'package:flutter/foundation.dart';
import 'package:sippichat_client/features/conversations/conversation_service.dart';
import 'package:sippichat_client/features/conversations/models/conversation.dart';

class ConversationController extends ChangeNotifier{
  final ConversationService conversationService;

  ConversationController(this.conversationService);

  List<Conversation> conversations = [];

  bool loading = false;
  String? error;

  Future<void> loadConversations() async {
    loading = true;
    error = null;

    print('START LOADING');
    notifyListeners();

    try {
      conversations = await conversationService.getConversations();

      print('LOADED ${conversations.length} conversations');

    } catch(e, stackTrace) {
      print('ERROR: $e');
      print(stackTrace);
      error = e.toString();
    }

    loading = false;

    print('NOTIFYING LISTENERS');
    notifyListeners();
  }

  Future<Conversation?> createConversation(String userId) async{
    try {
      final conversation =
      await conversationService.createConversation(userId);

      await loadConversations();

      return conversation;
    } catch (e, stackTrace) {
      print("CREATE CONVERSATION ERROR: $e");
      print(stackTrace);

      error = e.toString();
      notifyListeners();

      return null;
    }
  }
}