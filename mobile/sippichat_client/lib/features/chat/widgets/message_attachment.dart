import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:sippichat_client/app/app_dependencies.dart';

import '../models/attachment.dart';

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

class MessageAttachment extends StatefulWidget {
  final Attachment attachment;

  const MessageAttachment({super.key, required this.attachment});

  @override
  State<MessageAttachment> createState() => _MessageAttachmentState();
}

class _MessageAttachmentState extends State<MessageAttachment> {
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
