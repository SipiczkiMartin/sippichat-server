import 'dart:async';

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/foundation.dart' as foundation;
import 'package:flutter/material.dart';

import '../../../app/app_dependencies.dart';
import '../models/attachment.dart';
import 'giphy_service.dart';

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
  final TextEditingController textController = TextEditingController();
  final FocusNode focusNode = FocusNode();

  final TextEditingController _gifSearchController = TextEditingController();

  Timer? _typingTimer;

  bool _isTyping = false;
  bool _showEmojiPicker = false;
  bool _showGifs = false;

  List<GiphyGif> _gifs = [];
  bool _loadingGifs = false;
  String? _gifError;

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
    _gifSearchController.dispose();

    super.dispose();
  }

  // ===========================================================================
  // Typing
  // ===========================================================================

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

  // ===========================================================================
  // Sending
  // ===========================================================================

  void _sendMessage() {
    final content = textController.text.trim();

    // Don't send an empty message without attachments.
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

  // ===========================================================================
  // Attachments
  // ===========================================================================

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
    if (index < 0 || index >= _attachments.length) {
      return;
    }

    setState(() {
      _attachments.removeAt(index);
    });
  }

  // ===========================================================================
  // Emoji / GIF picker
  // ===========================================================================

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

  // ===========================================================================
  // GIF loading
  // ===========================================================================

  Future<void> _loadTrendingGifs() async {
    if (_loadingGifs) {
      return;
    }

    setState(() {
      _loadingGifs = true;
      _gifError = null;
    });

    try {
      final gifs = await AppDependencies.giphyService.trending();

      if (!mounted) {
        return;
      }

      setState(() {
        _gifs = gifs;
        _loadingGifs = false;
      });
    } catch (e, stackTrace) {
      debugPrint('GIPHY TRENDING ERROR: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      setState(() {
        _loadingGifs = false;
        _gifError = 'Could not load GIFs';
      });
    }
  }

  Future<void> _searchGifs() async {
    final query = _gifSearchController.text.trim();

    if (_loadingGifs) {
      return;
    }

    setState(() {
      _loadingGifs = true;
      _gifError = null;
    });

    try {
      final gifs = await AppDependencies.giphyService.search(query);

      if (!mounted) {
        return;
      }

      setState(() {
        _gifs = gifs;
        _loadingGifs = false;
      });
    } catch (e, stackTrace) {
      debugPrint('GIPHY SEARCH ERROR: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      setState(() {
        _loadingGifs = false;
        _gifError = 'Could not search GIFs';
      });
    }
  }

  void _switchToGifs() {
    setState(() {
      _showGifs = true;
    });

    if (_gifs.isEmpty) {
      _loadTrendingGifs();
    }
  }

  void _switchToEmoji() {
    setState(() {
      _showGifs = false;
    });
  }

  // ===========================================================================
  // GIF selection
  // ===========================================================================

  void _selectGif(GiphyGif gif) {
    if (gif.url.isEmpty) {
      return;
    }

    final attachment = Attachment(
      id: '',
      type: 'gif',
      filename: '${gif.id}.gif',
      mimeType: 'image/gif',
      size: null,

      // IMPORTANT:
      // GIPHY files are external.
      // They do NOT have a storage key.
      storageKey: null,

      externalUrl: gif.url,

      metadata: {
        'provider': 'giphy',
        'giphy_id': gif.id,
        'preview_url': gif.previewUrl,
        'width': gif.width,
        'height': gif.height,
      },

      sortOrder: _attachments.length,
    );

    setState(() {
      // Add GIF to the pending message instead of sending it immediately.
      _attachments.add(attachment);

      // Close picker after selection.
      _showEmojiPicker = false;
      _showGifs = false;
    });

    // Put cursor back into the message field so the user
    // can type text for the GIF.
    focusNode.requestFocus();
  }

  // ===========================================================================
  // Build
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // =====================================================================
        // Emoji / GIF picker
        // =====================================================================
        if (_showEmojiPicker)
          SizedBox(
            height: 340,
            child: Column(
              children: [
                Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.grey.withValues(alpha: 0.2),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      _PickerTab(
                        label: 'Emoji',
                        selected: !_showGifs,
                        onTap: _switchToEmoji,
                      ),

                      const SizedBox(width: 8),

                      _PickerTab(
                        label: 'GIF',
                        selected: _showGifs,
                        onTap: _switchToGifs,
                      ),

                      const Spacer(),

                      if (_showGifs)
                        const Text(
                          'Powered by GIPHY',
                          style: TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                    ],
                  ),
                ),

                Expanded(
                  child: _showGifs
                      ? _buildGifPicker()
                      : EmojiPicker(
                          onEmojiSelected: _onEmojiSelected,
                          config: Config(
                            height: 292,
                            checkPlatformCompatibility: true,
                            emojiViewConfig: EmojiViewConfig(
                              emojiSizeMax:
                                  28 *
                                  (foundation.defaultTargetPlatform ==
                                          TargetPlatform.iOS
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
              ],
            ),
          ),

        // =====================================================================
        // Pending attachments
        // =====================================================================
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

        // =====================================================================
        // Message input
        // =====================================================================
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

  // ===========================================================================
  // GIF picker
  // ===========================================================================

  Widget _buildGifPicker() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
          child: TextField(
            controller: _gifSearchController,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _searchGifs(),
            decoration: InputDecoration(
              hintText: 'Search GIFs...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                icon: const Icon(Icons.search),
                onPressed: _searchGifs,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              isDense: true,
            ),
          ),
        ),

        Expanded(child: _buildGifResults()),
      ],
    );
  }

  Widget _buildGifResults() {
    if (_loadingGifs) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_gifError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_gifError!, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _loadTrendingGifs,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_gifs.isEmpty) {
      return const Center(
        child: Text('No GIFs found', style: TextStyle(color: Colors.grey)),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
        childAspectRatio: 1.2,
      ),
      itemCount: _gifs.length,
      itemBuilder: (context, index) {
        final gif = _gifs[index];

        return GestureDetector(
          onTap: () => _selectGif(gif),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              gif.previewUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) {
                return Container(
                  color: Colors.grey.withValues(alpha: 0.15),
                  child: const Icon(Icons.broken_image_outlined),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

// =============================================================================
// Pending attachment preview
// =============================================================================

class _AttachmentPreview extends StatelessWidget {
  final Attachment attachment;
  final VoidCallback onRemove;

  const _AttachmentPreview({required this.attachment, required this.onRemove});

  bool get _isGif {
    return attachment.type == 'gif' || attachment.mimeType == 'image/gif';
  }

  bool get _isImage {
    return attachment.mimeType?.startsWith('image/') ?? false;
  }

  @override
  Widget build(BuildContext context) {
    if (_isGif) {
      return _buildGifPreview();
    }

    return _buildFilePreview();
  }

  // ===========================================================================
  // GIF preview
  // ===========================================================================

  Widget _buildGifPreview() {
    final url = attachment.externalUrl;

    return Stack(
      children: [
        Container(
          width: 180,
          height: 130,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          clipBehavior: Clip.antiAlias,
          child: url != null && url.isNotEmpty
              ? Image.network(
                  url,
                  width: 180,
                  height: 130,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) {
                      return child;
                    }

                    return const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  },
                  errorBuilder: (_, __, ___) {
                    return Center(
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: Colors.grey.shade600,
                        size: 32,
                      ),
                    );
                  },
                )
              : Center(
                  child: Icon(
                    Icons.gif_box_outlined,
                    color: Colors.grey.shade600,
                    size: 36,
                  ),
                ),
        ),

        // ---------------------------------------------------------------------
        // GIF label
        // ---------------------------------------------------------------------
        Positioned(
          left: 8,
          bottom: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(5),
            ),
            child: const Text(
              'GIF',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),

        // ---------------------------------------------------------------------
        // Remove button
        // ---------------------------------------------------------------------
        Positioned(
          top: 5,
          right: 5,
          child: Material(
            color: Colors.black.withValues(alpha: 0.65),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onRemove,
              child: const Padding(
                padding: EdgeInsets.all(5),
                child: Icon(Icons.close, size: 17, color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // Normal file preview
  // ===========================================================================

  Widget _buildFilePreview() {
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
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _isImage
                  ? Icons.image_outlined
                  : Icons.insert_drive_file_outlined,
              color: Colors.grey.shade700,
            ),
          ),

          const SizedBox(width: 8),

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

// =============================================================================
// Picker tab
// =============================================================================

class _PickerTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PickerTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
