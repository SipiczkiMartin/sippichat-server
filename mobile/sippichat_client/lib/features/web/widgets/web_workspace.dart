import 'package:flutter/material.dart';
import 'package:sippichat_client/features/conversations/models/conversation.dart';

import '../../chat/web_chat_page.dart';

class WebWorkspace extends StatelessWidget {
  final Conversation? selectedConversation;

  const WebWorkspace({super.key, required this.selectedConversation});

  @override
  Widget build(BuildContext context) {
    if (selectedConversation != null) {
      return WebChatPage(
        key: ValueKey(selectedConversation!.id),
        conversation: selectedConversation!,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF181B1F),
        border: Border.all(color: const Color(0xFF30353D), width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _WorkspaceIcon(),

            SizedBox(height: 18),

            Text(
              'SippiChat',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: Color(0xFFF8FAFC),
              ),
            ),

            SizedBox(height: 6),

            Text(
              'Select a conversation to start messaging.',
              style: TextStyle(fontSize: 14, color: Color(0xFFB8C0CA)),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkspaceIcon extends StatelessWidget {
  const _WorkspaceIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: const Color(0xFF111315),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF30353D), width: 2),
      ),
      child: const Icon(
        Icons.forum_outlined,
        size: 30,
        color: Color(0xFFAAB3BE),
      ),
    );
  }
}
