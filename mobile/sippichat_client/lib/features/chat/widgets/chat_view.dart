import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:sippichat_client/app/app_dependencies.dart';
import 'package:sippichat_client/features/chat/models/message.dart';
import 'package:sippichat_client/features/chat/widgets/message_bubble.dart';
import 'package:sippichat_client/features/chat/widgets/message_input.dart';
import 'package:sippichat_client/features/conversations/models/conversation.dart';

import '../models/attachment.dart';

class ChatView extends StatefulWidget {
  final Conversation conversation;

  const ChatView({
    super.key,
    required this.conversation,
  });

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final controller = AppDependencies.chatController;

  final ScrollController _scrollController = ScrollController();

  final Set<String> _readMessageIds = {};

  String? _lastMessageId;

  bool _scrollScheduled = false;

  static const Color myMessageColor = Color(0xFFFFE1D8);
  static const Color otherMessageColor = Color(0xFFF5F2F0);
  static const Color messageBorderColor = Color(0xFFE8C5BB);

  @override
  void initState() {
    super.initState();

    controller.addListener(_update);

    _scrollController.addListener(_onScroll);

    controller.clearMessages();

    _initialize();
  }

  // ===========================================================================
  // Initialization
  // ===========================================================================

  Future<void> _initialize() async {
    try {
      // The WebSocket is now connected at the authenticated app/session level.
      //
      // ChatView only loads the messages for this conversation.
      await controller.loadMessages(widget.conversation.id);

      if (!mounted) {
        return;
      }

      _lastMessageId = _getNewestMessageId();

      _scheduleScrollToBottom();
    } catch (e, stackTrace) {
      debugPrint('CHAT INIT ERROR: $e');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  // ===========================================================================
  // Message updates
  // ===========================================================================

  void _update() {
    if (!mounted) {
      return;
    }

    final messages = controller.messages;

    final newestMessageId = _getNewestMessageId();

    final bool hasNewMessage =
        messages.isNotEmpty &&
            _lastMessageId != null &&
            newestMessageId != null &&
            newestMessageId != _lastMessageId;

    final bool initialMessagesLoaded =
        _lastMessageId == null && messages.isNotEmpty;

    _lastMessageId = newestMessageId;

    setState(() {});

    if (messages.isEmpty) {
      return;
    }

    if (initialMessagesLoaded) {
      _scheduleScrollToBottom();
    }

    if (hasNewMessage) {
      _scheduleScrollToBottom();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      _markVisibleMessagesAsRead();
    });
  }

  String? _getNewestMessageId() {
    final messages = controller.messages;

    if (messages.isEmpty) {
      return null;
    }

    return messages.last.id;
  }

  // ===========================================================================
  // Scrolling
  // ===========================================================================

  void _scheduleScrollToBottom() {
    if (_scrollScheduled) {
      return;
    }

    _scrollScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollScheduled = false;

      if (!mounted) {
        return;
      }

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

    _scrollController.jumpTo(position.maxScrollExtent);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }

      final newPosition = _scrollController.position;

      if (!newPosition.hasContentDimensions) {
        return;
      }

      if (newPosition.pixels != newPosition.maxScrollExtent) {
        _scrollController.jumpTo(newPosition.maxScrollExtent);
      }
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }

    final position = _scrollController.position;

    if (position.pixels <= 150) {
      _loadOlderMessages();
    }
  }

  Future<void> _loadOlderMessages() async {
    if (!_scrollController.hasClients) {
      return;
    }

    if (controller.loadingMore || !controller.hasMoreMessages) {
      return;
    }

    final oldScrollOffset = _scrollController.offset;

    final oldMaxScrollExtent =
        _scrollController.position.maxScrollExtent;

    await controller.loadOlderMessages();

    if (!mounted || !_scrollController.hasClients) {
      return;
    }

    final newMaxScrollExtent =
        _scrollController.position.maxScrollExtent;

    final addedExtent =
        newMaxScrollExtent - oldMaxScrollExtent;

    if (addedExtent <= 0) {
      return;
    }

    _scrollController.jumpTo(
      oldScrollOffset + addedExtent,
    );
  }

  // ===========================================================================
  // Read receipts
  // ===========================================================================

  void _markVisibleMessagesAsRead() {
    final currentUserId =
        AppDependencies.authRepository.currentUser?.id;

    if (currentUserId == null) {
      return;
    }

    for (final message in controller.messages) {
      if (message.sender.id == currentUserId) {
        continue;
      }

      if (_readMessageIds.contains(message.id)) {
        continue;
      }

      if (message.status == MessageStatus.read) {
        _readMessageIds.add(message.id);
        continue;
      }

      controller.markMessageRead(message.id);

      _readMessageIds.add(message.id);
    }
  }

  // ===========================================================================
  // Attachments
  // ===========================================================================

  Future<Attachment> _pickAttachment() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      throw Exception('No file selected');
    }

    final file = result.files.single;

    debugPrint(
      'ATTACHMENT: selected '
          '${file.name} '
          '(${file.size} bytes)',
    );

    final upload = await controller.uploadFile(file);

    return Attachment(
      id: '',
      type: upload.type,
      filename: upload.filename,
      mimeType: upload.mimeType,
      size: upload.size,
      storageKey: upload.storageKey,
      externalUrl: null,
      metadata: null,
      sortOrder: 0,
    );
  }

  // ===========================================================================
  // Lifecycle
  // ===========================================================================

  @override
  void dispose() {
    controller.removeListener(_update);

    _scrollController.removeListener(_onScroll);

    _scrollController.dispose();

    super.dispose();
  }

  // ===========================================================================
  // Build
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final messages = controller.messages;

    return Column(
      children: [
        Expanded(
          child: _buildMessageList(messages),
        ),

        if (controller.isOtherUserTyping)
          const Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              bottom: 6,
            ),
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
          onPickAttachment: _pickAttachment,
        ),
      ],
    );
  }

  Widget _buildMessageList(List<Message> messages) {
    if (controller.loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (controller.error != null) {
      return Center(
        child: Text(
          controller.error!,
          style: const TextStyle(
            color: Colors.red,
          ),
        ),
      );
    }

    if (messages.isEmpty) {
      return const Center(
        child: Text('No messages yet'),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 16,
      ),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];

        return MessageBubble(
          key: ValueKey(message.id),
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
