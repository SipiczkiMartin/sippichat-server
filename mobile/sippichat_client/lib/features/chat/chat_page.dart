import 'package:flutter/material.dart';
import 'package:sippichat_client/features/conversations/models/conversation.dart';

import 'widgets/chat_view.dart';

class ChatPage extends StatelessWidget {
  final Conversation conversation;

  const ChatPage({super.key, required this.conversation});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          conversation.participant?.displayName ??
              conversation.participant?.username ??
              'Chat',
        ),
      ),
      body: ChatView(conversation: conversation),
    );
  }
}
