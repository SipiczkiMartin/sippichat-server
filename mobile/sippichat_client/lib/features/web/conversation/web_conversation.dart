import 'package:flutter/material.dart';
import 'package:sippichat_client/features/chat/chat_page.dart';
import 'package:sippichat_client/features/conversations/models/conversation.dart';

class WebConversation extends StatelessWidget {
  final Conversation conversation;

  const WebConversation({super.key, required this.conversation});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF15181B),
        border: Border.all(color: const Color(0xFF2A2E33)),
      ),
      clipBehavior: Clip.antiAlias,
      child: ChatPage(conversation: conversation),
    );
  }
}
