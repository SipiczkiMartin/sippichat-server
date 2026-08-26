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
      debugPrint('CHAT INIT ERROR: $e');
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

  // ---------------------------------------------------------------------------
  // Attachment picking + uploading
  // ---------------------------------------------------------------------------

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
                if (widget.message.content.isNotEmpty)
                  Text(
                    widget.message.content,
                    style: const TextStyle(fontSize: 15, height: 1.4),
                  ),

                if (widget.message.attachments.isNotEmpty) ...[
                  if (widget.message.content.isNotEmpty)
                    const SizedBox(height: 8),

                  ...widget.message.attachments.map(
                    (attachment) => _MessageAttachment(attachment: attachment),
                  ),
                ],

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

// =============================================================================
// Message attachment
// =============================================================================

class _MessageAttachment extends StatefulWidget {
  final Attachment attachment;

  const _MessageAttachment({required this.attachment});

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
      setState(() {
        _error = 'Attachment has no storage key';
      });
      return;
    }

    if (_loading || _imageBytes != null) {
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final bytes = await AppDependencies.apiClient.downloadFile(storageKey);

      if (!mounted) {
        return;
      }

      setState(() {
        _imageBytes = Uint8List.fromList(bytes);
        _loading = false;
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

  Future<void> _showDownloadComplete({required String filename, String? path}) async {
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
                // We'll wire this to "Open" later.
              },
              child: const Text('Open'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // We'll wire this to "Open file location" later.
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
