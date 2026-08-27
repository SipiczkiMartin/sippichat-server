import 'package:flutter/material.dart';
import 'package:sippichat_client/features/chat/models/message.dart';

import 'message_attachment.dart';
import 'message_status.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMine;

  final Color myColor;
  final Color otherColor;
  final Color borderColor;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    required this.myColor,
    required this.otherColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final senderName = message.sender.displayName.isNotEmpty
        ? message.sender.displayName
        : message.sender.username;

    final time = _formatTime(message.createdAt);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: isMine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(
              left: isMine ? 40 : 4,
              right: isMine ? 4 : 40,
            ),
            child: Text(
              '$senderName · $time',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
          ),

          const SizedBox(height: 5),

          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isMine ? myColor : otherColor,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(14),
                topRight: const Radius.circular(14),
                bottomLeft: Radius.circular(isMine ? 14 : 4),
                bottomRight: Radius.circular(isMine ? 4 : 14),
              ),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (message.content.isNotEmpty)
                  Text(
                    message.content,
                    style: const TextStyle(fontSize: 15, height: 1.4),
                  ),

                if (message.attachments.isNotEmpty) ...[
                  if (message.content.isNotEmpty) const SizedBox(height: 8),

                  ...message.attachments.map(
                    (attachment) => MessageAttachment(
                      key: ValueKey(
                        attachment.id.isNotEmpty
                            ? attachment.id
                            : attachment.storageKey,
                      ),
                      attachment: attachment,
                    ),
                  ),
                ],

                if (isMine) ...[
                  const SizedBox(height: 4),
                  MessageStatusIcon(status: message.status),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final local = dateTime.toLocal();

    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }
}
