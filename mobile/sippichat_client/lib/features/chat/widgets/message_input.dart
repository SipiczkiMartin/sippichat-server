import 'dart:async';

import 'package:flutter/material.dart';

class MessageInput extends StatefulWidget {
  final String conversationId;
  final void Function(String content) onSend;
  final void Function(String conversationId) onTypingStart;
  final void Function(String conversationId) onTypingStop;

  const MessageInput({
    super.key,
    required this.conversationId,
    required this.onSend,
    required this.onTypingStart,
    required this.onTypingStop,
  });

  @override
  State<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<MessageInput> {
  final textController = TextEditingController();
  final focusNode = FocusNode();

  Timer? _typingTimer;
  bool _isTyping = false;

  static const Duration _typingTimeout = Duration(seconds: 2);

  @override
  void dispose() {
    _typingTimer?.cancel();

    if (_isTyping) {
      widget.onTypingStop(widget.conversationId);
    }

    textController.dispose();
    focusNode.dispose();

    super.dispose();
  }

  void _onTextChanged(String value) {
    if (value.trim().isEmpty) {
      _stopTyping();
      return;
    }

    if (!_isTyping) {
      _isTyping = true;

      widget.onTypingStart(widget.conversationId);
    }

    _typingTimer?.cancel();

    _typingTimer = Timer(_typingTimeout, () {
      _stopTyping();
    });
  }

  void _stopTyping() {
    _typingTimer?.cancel();
    _typingTimer = null;

    if (!_isTyping) {
      return;
    }

    _isTyping = false;

    widget.onTypingStop(widget.conversationId);
  }

  void _sendMessage() {
    final content = textController.text.trim();

    if (content.isEmpty) {
      return;
    }

    _stopTyping();

    widget.onSend(content);

    textController.clear();
    focusNode.requestFocus();
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
              textInputAction: TextInputAction.send,
              onChanged: _onTextChanged,
              onSubmitted: (_) => _sendMessage(),
              decoration: const InputDecoration(
                hintText: 'Message...',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          IconButton(icon: const Icon(Icons.send), onPressed: _sendMessage),
        ],
      ),
    );
  }
}
