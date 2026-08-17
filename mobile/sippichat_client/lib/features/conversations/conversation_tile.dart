import 'package:flutter/material.dart';
import 'package:sippichat_client/features/conversations/models/conversation.dart';

class ConversationTile extends StatelessWidget {
  final Conversation conversation;
  final VoidCallback onTap;

  const ConversationTile({
    super.key,
    required this.conversation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final participant = conversation.participant;
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: const CircleAvatar(radius: 26, child: Icon(Icons.person)),
      title: Text(
        participant?.displayName ?? 'Unknown user',
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      ),
      subtitle: Text(
        participant?.username != null
            ? '@${participant!.username}'
            : 'No username',
        style: TextStyle(color: Colors.grey.shade600),
      ),
      trailing: Text(
        _formatDate(conversation.createdAt),
        style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
      ),
    );
  }

  String _formatDate(DateTime dateTime) {
    final local = dateTime.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
