import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:sippichat_client/app/app_dependencies.dart';
import 'package:sippichat_client/features/chat/models/message.dart';
import 'package:sippichat_client/features/chat/widgets/message_bubble.dart';
import 'package:sippichat_client/features/chat/widgets/message_input.dart';
import 'package:sippichat_client/features/conversations/models/conversation.dart';

import 'models/attachment.dart';

class WebChatPage extends StatefulWidget {
  final Conversation conversation;

  const WebChatPage({super.key, required this.conversation});

  @override
  State<WebChatPage> createState() => _WebChatPageState();
}

class _WebChatPageState extends State<WebChatPage> {
  final controller = AppDependencies.chatController;

  final ScrollController _scrollController = ScrollController();

  final Set<String> _readMessageIds = {};

  String? _lastMessageId;

  bool _scrollScheduled = false;

  // ===========================================================================
  // Web dark theme
  // ===========================================================================

  static const Color background = Color(0xFF0D0F11);
  static const Color panel = Color(0xFF181B1F);
  static const Color panelSecondary = Color(0xFF20242A);
  static const Color border = Color(0xFF30353D);

  static const Color textPrimary = Color(0xFFF7F9FC);
  static const Color textSecondary = Color(0xFFD0D5DD);
  static const Color textMuted = Color(0xFFAAB2BD);

  static const Color myMessageColor = Color(0xFF3A414A);
  static const Color otherMessageColor = Color(0xFF252A31);
  static const Color messageBorderColor = Color(0xFF454D58);

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
      await controller.loadMessages(widget.conversation.id);

      if (!mounted) return;

      _lastMessageId = _getNewestMessageId();

      _scheduleScrollToBottom();
    } catch (e, stackTrace) {
      debugPrint('WEB CHAT INIT ERROR: $e');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  // ===========================================================================
  // Message updates
  // ===========================================================================

  void _update() {
    if (!mounted) return;

    final messages = controller.messages;
    final newestMessageId = _getNewestMessageId();

    final hasNewMessage =
        messages.isNotEmpty &&
        _lastMessageId != null &&
        newestMessageId != null &&
        newestMessageId != _lastMessageId;

    final initialMessagesLoaded = _lastMessageId == null && messages.isNotEmpty;

    _lastMessageId = newestMessageId;

    setState(() {});

    if (messages.isEmpty) return;

    if (initialMessagesLoaded || hasNewMessage) {
      _scheduleScrollToBottom();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      _markVisibleMessagesAsRead();
    });
  }

  String? _getNewestMessageId() {
    if (controller.messages.isEmpty) {
      return null;
    }

    return controller.messages.last.id;
  }

  // ===========================================================================
  // Scrolling
  // ===========================================================================

  void _scheduleScrollToBottom() {
    if (_scrollScheduled) return;

    _scrollScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollScheduled = false;

      if (!mounted) return;

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
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;

    if (position.pixels <= 150) {
      _loadOlderMessages();
    }
  }

  Future<void> _loadOlderMessages() async {
    if (!_scrollController.hasClients) return;

    if (controller.loadingMore || !controller.hasMoreMessages) {
      return;
    }

    final oldScrollOffset = _scrollController.offset;
    final oldMaxScrollExtent = _scrollController.position.maxScrollExtent;

    await controller.loadOlderMessages();

    if (!mounted || !_scrollController.hasClients) {
      return;
    }

    final newMaxScrollExtent = _scrollController.position.maxScrollExtent;

    final addedExtent = newMaxScrollExtent - oldMaxScrollExtent;

    if (addedExtent <= 0) return;

    _scrollController.jumpTo(oldScrollOffset + addedExtent);
  }

  // ===========================================================================
  // Read receipts
  // ===========================================================================

  void _markVisibleMessagesAsRead() {
    final currentUserId = AppDependencies.authRepository.currentUser?.id;

    if (currentUserId == null) return;

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
    final participant = widget.conversation.participant;

    final name = participant?.displayName ?? participant?.username ?? 'Chat';

    return Theme(
      data: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: background,

        colorScheme: const ColorScheme.dark(
          surface: panel,
          primary: Color(0xFF8B929B),
          onSurface: textPrimary,
          onPrimary: textPrimary,
        ),

        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: textPrimary),
          bodyMedium: TextStyle(color: textSecondary),
          bodySmall: TextStyle(color: textMuted),
        ),

        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF16191D),
          hintStyle: const TextStyle(color: textMuted),
          labelStyle: const TextStyle(color: textSecondary),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF59616C), width: 2),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: border),
          ),
        ),

        iconTheme: const IconThemeData(color: textSecondary),
      ),

      child: Scaffold(
        backgroundColor: background,
        body: SafeArea(
          child: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: panel,
              border: Border.all(color: border, width: 2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                _buildChatHeader(name),

                Expanded(child: _buildMessageList(controller.messages)),

                if (controller.isOtherUserTyping) _buildTypingIndicator(),

                _buildInput(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // Header
  // ===========================================================================

  Widget _buildChatHeader(String name) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: border, width: 2)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFF292D33),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.person, color: textMuted, size: 21),
          ),

          const SizedBox(width: 12),

          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  color: textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 3),

              const Text(
                'Conversation',
                style: TextStyle(color: textMuted, fontSize: 12),
              ),
            ],
          ),

          const Spacer(),

          IconButton(
            tooltip: 'More',
            onPressed: () {},
            icon: const Icon(Icons.more_horiz, color: textSecondary),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Messages
  // ===========================================================================

  Widget _buildMessageList(List<Message> messages) {
    if (controller.loading) {
      return const Center(
        child: CircularProgressIndicator(color: textSecondary),
      );
    }

    if (controller.error != null) {
      return Center(
        child: Text(
          controller.error!,
          style: const TextStyle(color: Colors.redAccent),
        ),
      );
    }

    if (messages.isEmpty) {
      return const Center(
        child: Text('No messages yet', style: TextStyle(color: textMuted)),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
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

  // ===========================================================================
  // Typing
  // ===========================================================================

  Widget _buildTypingIndicator() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(28, 0, 28, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'typing...',
          style: TextStyle(
            color: textMuted,
            fontSize: 13,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // Input
  // ===========================================================================

  Widget _buildInput() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: border, width: 2)),
      ),
      padding: const EdgeInsets.all(16),
      child: MessageInput(
        conversationId: widget.conversation.id,
        onSend: controller.sendMessage,
        onTypingStart: controller.sendTypingStart,
        onTypingStop: controller.sendTypingStop,
        onPickAttachment: _pickAttachment,
      ),
    );
  }
}
