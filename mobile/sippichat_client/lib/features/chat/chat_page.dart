import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sippichat_client/app/app_dependencies.dart';
import 'package:sippichat_client/core/network/api_config.dart';
import 'package:sippichat_client/features/chat/models/message.dart';
import 'package:sippichat_client/features/chat/widgets/message_input.dart';
import 'package:sippichat_client/features/conversations/models/conversation.dart';

class ChatPage extends StatefulWidget {
  final Conversation conversation;

  const ChatPage({super.key, required this.conversation});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final controller = AppDependencies.chatController;

  final ScrollController _scrollController = ScrollController();

  static const Color myMessageColor = Color(0xFFFFE1D8);
  static const Color otherMessageColor = Color(0xFFF5F2F0);
  static const Color messageBorderColor = Color(0xFFE8C5BB);

  @override
  void initState() {
    super.initState();

    controller.addListener(_update);

    controller.clearMessages();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await AppDependencies.webSocketService.connect(
        url: ApiConfig.websocketUrl,
      );

      if (!mounted) {
        return;
      }

      await controller.loadMessages(widget.conversation.id);
    } catch (e, stackTrace) {
      debugPrint("CHAT INIT ERROR: $e");
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  void _update() {
    if (!mounted) {
      return;
    }

    setState(() {});

    if (controller.messages.isEmpty) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    if (!mounted || !_scrollController.hasClients) {
      return;
    }

    final position = _scrollController.position;

    if (!position.hasContentDimensions) {
      return;
    }

    // First scroll.
    _scrollController.jumpTo(position.maxScrollExtent);

    debugPrint(
      'SCROLL 1 → '
      'pixels=${position.pixels} '
      'max=${position.maxScrollExtent} '
      'viewport=${position.viewportDimension}',
    );

    // Check again after Flutter has had another frame to lay everything out.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }

      final newPosition = _scrollController.position;

      if (!newPosition.hasContentDimensions) {
        return;
      }

      debugPrint(
        'SCROLL 2 → '
        'pixels=${newPosition.pixels} '
        'max=${newPosition.maxScrollExtent}',
      );

      if (newPosition.pixels != newPosition.maxScrollExtent) {
        _scrollController.jumpTo(newPosition.maxScrollExtent);

        debugPrint(
          'SCROLL CORRECTED → '
          '${newPosition.maxScrollExtent}',
        );
      }
    });
  }

  @override
  void dispose() {
    controller.removeListener(_update);
    _scrollController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messages = controller.messages;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.conversation.participant?.displayName ??
              widget.conversation.participant?.username ??
              "Chat",
        ),
      ),
      body: Column(
        children: [
          Expanded(child: _buildMessageList(messages)),

          if (controller.isOtherUserTyping)
            const Padding(
              padding: EdgeInsets.only(left: 16, right: 16, bottom: 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'typing...',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),

          MessageInput(
            conversationId: widget.conversation.id,
            onSend: controller.sendMessage,
            onTypingStart: controller.sendTypingStart,
            onTypingStop: controller.sendTypingStop,
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList(List<Message> messages) {
    if (controller.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (controller.error != null) {
      return Center(
        child: Text(
          controller.error!,
          style: const TextStyle(color: Colors.red),
        ),
      );
    }

    if (messages.isEmpty) {
      return const Center(child: Text("No messages yet"));
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];

        return _MessageBubble(
          message: message,
          isMine:
              message.sender.id ==
              AppDependencies.authRepository.currentUser?.id,
          myColor: myMessageColor,
          otherColor: otherMessageColor,
          borderColor: messageBorderColor,
        );
      },
    );
  }
}

class _MessageBubble extends StatefulWidget {
  final Message message;
  final bool isMine;
  final Color myColor;
  final Color otherColor;
  final Color borderColor;

  const _MessageBubble({
    required this.message,
    required this.isMine,
    required this.myColor,
    required this.otherColor,
    required this.borderColor,
  });

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble> {
  @override
  Widget build(BuildContext context) {
    final senderName = widget.message.sender.displayName.isNotEmpty
        ? widget.message.sender.displayName
        : widget.message.sender.username;

    final time = _formatTime(widget.message.createdAt);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: widget.isMine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(
              left: widget.isMine ? 40 : 4,
              right: widget.isMine ? 4 : 40,
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
              color: widget.isMine ? widget.myColor : widget.otherColor,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(14),
                topRight: const Radius.circular(14),
                bottomLeft: Radius.circular(widget.isMine ? 14 : 4),
                bottomRight: Radius.circular(widget.isMine ? 4 : 14),
              ),
              border: Border.all(color: widget.borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.message.content,
                  style: const TextStyle(fontSize: 15, height: 1.4),
                ),
                if (widget.isMine) ...[
                  const SizedBox(height: 4),
                  _MessageStatus(status: widget.message.status),
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

class _MessageStatus extends StatelessWidget {
  final MessageStatus status;

  const _MessageStatus({required this.status});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case MessageStatus.sent:
        return Icon(Icons.check, size: 16, color: Colors.grey.shade600);

      case MessageStatus.delivered:
        return const Icon(
          Icons.visibility_outlined,
          size: 17,
          color: Color(0xFF9E9E9E),
        );

      case MessageStatus.read:
        return const Icon(Icons.visibility, size: 17, color: Color(0xFF6FA6A0));
    }
  }
}
