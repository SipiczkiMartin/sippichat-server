import 'package:flutter/material.dart';

class MessageInput extends StatefulWidget {
  final String conversationId;

  const MessageInput({super.key, required this.conversationId});

  @override
  State<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<MessageInput> {
  final textController = TextEditingController();
  final focusNode = FocusNode();

  @override
  void dispose() {
    textController.dispose();
    focusNode.dispose();
    super.dispose();
  }

  void _sendMessage() {
    // WebSocket messaging is temporarily disabled.
    // We will reintroduce it with the new WebSocket architecture.
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: textController,
              focusNode: focusNode,
              enabled: false,
              textInputAction: TextInputAction.send,
              decoration: const InputDecoration(
                hintText: "Messaging temporarily unavailable",
                border: OutlineInputBorder(),
              ),
            ),
          ),
          IconButton(icon: const Icon(Icons.send), onPressed: null),
        ],
      ),
    );
  }
}
