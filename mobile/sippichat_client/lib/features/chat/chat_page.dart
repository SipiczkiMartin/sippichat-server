import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:sippichat_client/app/app_dependencies.dart';
import 'package:sippichat_client/core/network/api_config.dart';
import 'package:sippichat_client/features/chat/models/message.dart';
import 'package:sippichat_client/features/chat/widgets/message_input.dart';
import 'package:sippichat_client/features/conversations/models/conversation.dart';

import 'models/attachment.dart';

// =============================================================================
// Image cache
// =============================================================================
//
// Shared by all message attachment widgets in this ChatPage file.
//
// Images are downloaded once and kept in memory. Scrolling away from an image
// and then back to it does not trigger another HTTP request.
//
// In-flight downloads are also shared so two widgets requesting the same image
// at the same time use the same Future.
//

class _AttachmentImageCache {
  static final Map<String, Uint8List> _cache = {};

  static final Map<String, Future<Uint8List>> _loading = {};

  static Uint8List? get(String storageKey) {
    return _cache[storageKey];
  }

  static Future<Uint8List> load(String storageKey) {
    final cached = _cache[storageKey];

    if (cached != null) {
      return Future.value(cached);
    }

    final existingRequest = _loading[storageKey];

    if (existingRequest != null) {
      return existingRequest;
    }

    final future = _download(storageKey);

    _loading[storageKey] = future;

    future.whenComplete(() {
      _loading.remove(storageKey);
    });

    return future;
  }

  static Future<Uint8List> _download(String storageKey) async {
    final bytes = await AppDependencies.apiClient.downloadFile(storageKey);

    final imageBytes = Uint8List.fromList(bytes);

    _cache[storageKey] = imageBytes;

    return imageBytes;
  }

  static void clear() {
    _cache.clear();
  }

  static void remove(String storageKey) {
    _cache.remove(storageKey);
  }
}

// =============================================================================
// Chat page
// =============================================================================

class ChatPage extends StatefulWidget {
  final Conversation conversation;

  const ChatPage({super.key, required this.conversation});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final controller = AppDependencies.chatController;

  final ScrollController _scrollController = ScrollController();

  final Set<String> _readMessageIds = {};

  // ID of the newest message currently known by the page.
  //
  // This is important because controller.notifyListeners() also fires for
  // delivered/read status changes. We do NOT want those status changes to
  // make the chat jump.
  String? _lastMessageId;

  // Prevent multiple post-frame scroll requests from stacking up.
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
      await AppDependencies.webSocketService.connect(
        url: ApiConfig.websocketUrl,
      );

      if (!mounted) {
        return;
      }

      await controller.loadMessages(widget.conversation.id);

      if (!mounted) {
        return;
      }

      // Remember the newest message loaded from the server.
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

    // Detect an actually NEWEST message.
    //
    // This catches:
    //
    // - our sent message arriving through WebSocket
    // - a received message arriving through WebSocket
    //
    // It does NOT fire for:
    //
    // - delivered status
    // - read status
    // - loading older messages
    //
    final bool hasNewMessage =
        messages.isNotEmpty &&
        _lastMessageId != null &&
        newestMessageId != null &&
        newestMessageId != _lastMessageId;

    // Initial population is handled separately below.
    final bool initialMessagesLoaded =
        _lastMessageId == null && messages.isNotEmpty;

    _lastMessageId = newestMessageId;

    setState(() {});

    if (messages.isEmpty) {
      return;
    }

    // Initial message load.
    if (initialMessagesLoaded) {
      _scheduleScrollToBottom();
    }

    // A new message was appended.
    //
    // This is the important part that fixes received messages not jumping
    // to the bottom.
    if (hasNewMessage) {
      _scheduleScrollToBottom();
    }

    // Read receipts still happen after the UI has been updated.
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

    // The first jump can happen before the ListView has completely settled,
    // especially when an attachment/image changes its size.
    //
    // Do one more check after the next frame.
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

    // Start loading older messages before reaching the absolute top.
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

    final oldMaxScrollExtent = _scrollController.position.maxScrollExtent;

    await controller.loadOlderMessages();

    if (!mounted || !_scrollController.hasClients) {
      return;
    }

    final newMaxScrollExtent = _scrollController.position.maxScrollExtent;

    final addedExtent = newMaxScrollExtent - oldMaxScrollExtent;

    if (addedExtent <= 0) {
      return;
    }

    // Keep the same messages underneath the user's eyes after older
    // messages are prepended.
    _scrollController.jumpTo(oldScrollOffset + addedExtent);
  }

  // ===========================================================================
  // Read receipts
  // ===========================================================================

  void _markVisibleMessagesAsRead() {
    final currentUserId = AppDependencies.authRepository.currentUser?.id;

    if (currentUserId == null) {
      return;
    }

    for (final message in controller.messages) {
      // Only messages from the other user need a read receipt.
      if (message.sender.id == currentUserId) {
        continue;
      }

      // Don't repeatedly send the same read receipt.
      if (_readMessageIds.contains(message.id)) {
        continue;
      }

      // Already read according to the server.
      if (message.status == MessageStatus.read) {
        _readMessageIds.add(message.id);
        continue;
      }

      controller.markMessageRead(message.id);

      _readMessageIds.add(message.id);
    }
  }

  // ===========================================================================
  // Attachment picking + uploading
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

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.conversation.participant?.displayName ??
              widget.conversation.participant?.username ??
              'Chat',
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
            onPickAttachment: _pickAttachment,
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
      return const Center(child: Text('No messages yet'));
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];

        return _MessageBubble(
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

// =============================================================================
// Message bubble
// =============================================================================

class _MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMine;
  final Color myColor;
  final Color otherColor;
  final Color borderColor;

  const _MessageBubble({
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
                    (attachment) => _MessageAttachment(
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

                  _MessageStatus(status: message.status),
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

// =============================================================================
// Message attachment
// =============================================================================

class _MessageAttachment extends StatefulWidget {
  final Attachment attachment;

  const _MessageAttachment({super.key, required this.attachment});

  @override
  State<_MessageAttachment> createState() => _MessageAttachmentState();
}

class _MessageAttachmentState extends State<_MessageAttachment> {
  bool _loading = false;
  String? _error;
  Uint8List? _imageBytes;

  bool get _isImage {
    final mimeType = widget.attachment.mimeType ?? '';

    return mimeType.startsWith('image/');
  }

  @override
  void initState() {
    super.initState();

    if (_isImage) {
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    final storageKey = widget.attachment.storageKey;

    if (storageKey == null || storageKey.isEmpty) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = 'Attachment has no storage key';
      });

      return;
    }

    final cached = _AttachmentImageCache.get(storageKey);

    if (cached != null) {
      if (!mounted) {
        return;
      }

      setState(() {
        _imageBytes = cached;
        _loading = false;
        _error = null;
      });

      return;
    }

    if (_loading || _imageBytes != null) {
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final bytes = await _AttachmentImageCache.load(storageKey);

      if (!mounted) {
        return;
      }

      setState(() {
        _imageBytes = bytes;
        _loading = false;
        _error = null;
      });
    } catch (e, stackTrace) {
      debugPrint('ATTACHMENT IMAGE ERROR: $e');

      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _error = 'Could not load image';
      });
    }
  }

  void _openImageViewer() {
    if (_imageBytes == null) {
      return;
    }

    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(12),
          child: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Image.memory(_imageBytes!, fit: BoxFit.contain),
                ),
              ),

              Positioned(
                top: 0,
                right: 0,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isImage) {
      return _buildImageAttachment();
    }

    return _buildFileAttachment();
  }

  Widget _buildImageAttachment() {
    if (_loading) {
      return Container(
        width: 240,
        height: 180,
        margin: const EdgeInsets.only(top: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(Icons.broken_image_outlined, color: Colors.red),

            const SizedBox(width: 8),

            Expanded(
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.red, fontSize: 13),
              ),
            ),

            IconButton(onPressed: _loadImage, icon: const Icon(Icons.refresh)),
          ],
        ),
      );
    }

    if (_imageBytes == null) {
      return const SizedBox(width: 240, height: 180);
    }

    return GestureDetector(
      onTap: _openImageViewer,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.memory(
          _imageBytes!,
          width: 240,
          height: 180,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildFileAttachment() {
    final attachment = widget.attachment;

    return GestureDetector(
      onTap: _downloadFile,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(11),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      Icons.insert_drive_file_outlined,
                      color: Colors.grey.shade700,
                    ),
            ),

            const SizedBox(width: 10),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    attachment.filename ?? 'Attachment',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),

                  if (attachment.size != null)
                    Text(
                      _formatFileSize(attachment.size!),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),

                  if (_error != null)
                    Text(
                      _error!,
                      style: const TextStyle(fontSize: 11, color: Colors.red),
                    ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            if (!_loading)
              Icon(
                Icons.download_outlined,
                size: 20,
                color: Colors.grey.shade700,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadFile() async {
    debugPrint('========================================');

    debugPrint('ATTACHMENT: _downloadFile() START');

    if (_loading) {
      debugPrint('ATTACHMENT: already loading');
      return;
    }

    final storageKey = widget.attachment.storageKey;

    final filename = widget.attachment.filename ?? 'attachment';

    final mimeType = widget.attachment.mimeType ?? 'application/octet-stream';

    debugPrint('ATTACHMENT: filename=$filename');

    debugPrint('ATTACHMENT: storageKey=$storageKey');

    debugPrint('ATTACHMENT: mimeType=$mimeType');

    if (storageKey == null || storageKey.isEmpty) {
      debugPrint('ATTACHMENT: NO STORAGE KEY');

      if (!mounted) {
        return;
      }

      setState(() {
        _error = 'Attachment has no storage key';
      });

      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      debugPrint('ATTACHMENT: starting download service...');

      final result = await AppDependencies.downloadService.download(
        storageKey: storageKey,
        filename: filename,
        mimeType: mimeType,
      );

      debugPrint('ATTACHMENT: DOWNLOAD SUCCESS');

      debugPrint('ATTACHMENT: result=${result.type}');

      debugPrint('ATTACHMENT: path=${result.path}');

      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
      });

      if (result.shouldShowPopup) {
        await _showDownloadComplete(filename: filename, path: result.path);
      }
    } catch (e, stackTrace) {
      debugPrint('========================================');

      debugPrint('ATTACHMENT DOWNLOAD ERROR');

      debugPrint('ERROR: $e');

      debugPrint('TYPE: ${e.runtimeType}');

      debugPrintStack(stackTrace: stackTrace);

      debugPrint('========================================');

      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _error = 'Download failed';
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Download failed: $e')));
    }
  }

  Future<void> _showDownloadComplete({
    required String filename,
    String? path,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Download complete'),
          content: Text(filename),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Close'),
            ),

            TextButton(
              onPressed: () {
                Navigator.of(context).pop();

                // We'll wire this to "Open"
                // later.
              },
              child: const Text('Open'),
            ),

            TextButton(
              onPressed: () {
                Navigator.of(context).pop();

                // We'll wire this to
                // "Open file location"
                // later.
              },
              child: const Text('Open file location'),
            ),
          ],
        );
      },
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }

    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }

    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }

    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

// =============================================================================
// Message status
// =============================================================================
//
// Only two visible states:
//
// delivered -> grey eye
// read      -> colored eye
//
// sent has no icon.
//

class _MessageStatus extends StatelessWidget {
  final MessageStatus status;

  const _MessageStatus({required this.status});

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
