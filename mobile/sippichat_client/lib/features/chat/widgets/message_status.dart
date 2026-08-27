import 'package:flutter/material.dart';
import 'package:sippichat_client/features/chat/models/message.dart';

class MessageStatusIcon extends StatelessWidget {
  final MessageStatus status;

  const MessageStatusIcon({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case MessageStatus.delivered:
        return const Icon(
          Icons.visibility_outlined,
          size: 17,
          color: Color(0xFF9E9E9E),
        );

      case MessageStatus.read:
        return const Icon(Icons.visibility, size: 17, color: Color(0xFF6FA6A0));

      case MessageStatus.sent:
        return const SizedBox.shrink();
    }
  }
}
