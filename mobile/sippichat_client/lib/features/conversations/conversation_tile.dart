import 'package:flutter/material.dart';
import 'package:sippichat_client/features/conversations/models/conversation.dart';

class ConversationTile extends StatelessWidget {
  final Conversation conversation;
  final VoidCallback onTap;
  final bool hasUnread;
  final int unreadCount;

  const ConversationTile({
    super.key,
    required this.conversation,
    required this.onTap,
    required this.hasUnread,
    required this.unreadCount,
  });

  @override
  Widget build(BuildContext context) {
    final participant = conversation.participant;
    final hasUnread = conversation.unreadCount > 0;

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      tileColor: hasUnread
          ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.06)
          : null,
      leading: const CircleAvatar(radius: 26, child: Icon(Icons.person)),
      title: Text(
        participant?.displayName ?? 'Unknown user',
        style: TextStyle(
          fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w600,
          fontSize: 16,
        ),
      ),
      subtitle: Text(
        participant?.username != null
            ? '@${participant!.username}'
            : 'No username',
        style: TextStyle(color: Colors.grey.shade600),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _formatDate(conversation.createdAt),
            style: TextStyle(
              color: hasUnread
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey.shade500,
              fontSize: 12,
              fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
            ),
          ),

          if (hasUnread) ...[
            const SizedBox(height: 6),
            Container(
              constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                unreadCount > 99
                    ? '99+'
                    : unreadCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
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
