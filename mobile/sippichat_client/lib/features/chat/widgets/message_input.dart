import 'dart:async';

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/foundation.dart' as foundation;
import 'package:flutter/material.dart';

import '../models/attachment.dart';

class MessageInput extends StatefulWidget {
  final String conversationId;

  final void Function(String content, {List<Attachment> attachments}) onSend;

  final void Function(String conversationId) onTypingStart;
  final void Function(String conversationId) onTypingStop;

  final Future<Attachment> Function() onPickAttachment;

  const MessageInput({
    super.key,
    required this.conversationId,
    required this.onSend,
    required this.onTypingStart,
    required this.onTypingStop,
    required this.onPickAttachment,
  });

  @override
  State<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<MessageInput> {
  final textController = TextEditingController();
  final focusNode = FocusNode();

  Timer? _typingTimer;

  bool _isTyping = false;
  bool _showEmojiPicker = false;
  bool _uploadingAttachment = false;

  final List<Attachment> _attachments = [];

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

  // ---------------------------------------------------------------------------
  // Typing
  // ---------------------------------------------------------------------------

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

    _typingTimer = Timer(_typingTimeout, _stopTyping);
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

  // ---------------------------------------------------------------------------
  // Sending
  // ---------------------------------------------------------------------------

  void _sendMessage() {
    final content = textController.text.trim();

    // A message can contain either text, attachments, or both.
    if (content.isEmpty && _attachments.isEmpty) {
      return;
    }

    _stopTyping();

    widget.onSend(content, attachments: List.unmodifiable(_attachments));

    setState(() {
      _attachments.clear();
    });

    textController.clear();
    focusNode.requestFocus();
  }

  // ---------------------------------------------------------------------------
  // Attachments
  // ---------------------------------------------------------------------------

  Future<void> _pickAttachment() async {
    if (_uploadingAttachment) {
      return;
    }

    setState(() {
      _uploadingAttachment = true;
    });

    try {
      final attachment = await widget.onPickAttachment();

      if (!mounted) {
        return;
      }

      setState(() {
        _attachments.add(attachment);
      });
    } catch (e, stackTrace) {
      debugPrint('ATTACHMENT ERROR: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Attachment error: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _uploadingAttachment = false;
        });
      }
    }
  }

  void _removeAttachment(int index) {
    setState(() {
      _attachments.removeAt(index);
    });
  }

  // ---------------------------------------------------------------------------
  // Emoji
  // ---------------------------------------------------------------------------

  void _toggleEmojiPicker() {
    setState(() {
      _showEmojiPicker = !_showEmojiPicker;
    });

    if (_showEmojiPicker) {
      focusNode.unfocus();
    } else {
      focusNode.requestFocus();
    }
  }

  void _onEmojiSelected(Category? category, Emoji emoji) {
    final text = textController.text;
    final selection = textController.selection;

    final start = selection.start < 0 ? text.length : selection.start;

    final end = selection.end < 0 ? text.length : selection.end;

    final newText = text.replaceRange(start, end, emoji.emoji);

    textController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + emoji.emoji.length),
    );

    _onTextChanged(newText);
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ---------------------------------------------------------------------
        // Emoji picker
        // ---------------------------------------------------------------------
        if (_showEmojiPicker)
          SizedBox(
            height: 300,
            child: EmojiPicker(
              onEmojiSelected: _onEmojiSelected,
              config: Config(
                height: 300,
                checkPlatformCompatibility: true,
                emojiViewConfig: EmojiViewConfig(
                  emojiSizeMax:
                      28 *
                      (foundation.defaultTargetPlatform == TargetPlatform.iOS
                          ? 1.20
                          : 1.0),
                ),
                categoryViewConfig: const CategoryViewConfig(),
                bottomActionBarConfig: const BottomActionBarConfig(
                  enabled: false,
                ),
                searchViewConfig: const SearchViewConfig(),
              ),
            ),
          ),

        // ---------------------------------------------------------------------
        // Pending attachments
        // ---------------------------------------------------------------------
        if (_attachments.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (int i = 0; i < _attachments.length; i++)
                  _AttachmentPreview(
                    attachment: _attachments[i],
                    onRemove: () => _removeAttachment(i),
                  ),
              ],
            ),
          ),

        // ---------------------------------------------------------------------
        // Input
        // ---------------------------------------------------------------------
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                icon: _uploadingAttachment
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.attach_file),
                tooltip: 'Attach file',
                onPressed: _uploadingAttachment ? null : _pickAttachment,
              ),

              IconButton(
                icon: Icon(
                  _showEmojiPicker
                      ? Icons.keyboard
                      : Icons.emoji_emotions_outlined,
                ),
                tooltip: _showEmojiPicker ? 'Show keyboard' : 'Add emoji',
                onPressed: _toggleEmojiPicker,
              ),

              Expanded(
                child: TextField(
                  controller: textController,
                  focusNode: focusNode,
                  textInputAction: TextInputAction.send,
                  minLines: 1,
                  maxLines: 5,
                  onChanged: _onTextChanged,
                  onSubmitted: (_) => _sendMessage(),
                  decoration: const InputDecoration(
                    hintText: 'Message...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),

              IconButton(
                icon: const Icon(Icons.send),
                tooltip: 'Send',
                onPressed: _sendMessage,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Attachment preview
// =============================================================================

class _AttachmentPreview extends StatelessWidget {
  final Attachment attachment;
  final VoidCallback onRemove;

  const _AttachmentPreview({required this.attachment, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final mimeType = attachment.mimeType ?? '';

    final isImage = mimeType.startsWith('image/');

    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // File type icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isImage ? Icons.image_outlined : Icons.insert_drive_file_outlined,
              color: Colors.grey.shade700,
            ),
          ),

          const SizedBox(width: 8),

          // Filename + size
          Flexible(
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
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
              ],
            ),
          ),

          const SizedBox(width: 4),

          // Remove
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            icon: const Icon(Icons.close, size: 18),
            tooltip: 'Remove attachment',
            onPressed: onRemove,
          ),
        ],
      ),
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
