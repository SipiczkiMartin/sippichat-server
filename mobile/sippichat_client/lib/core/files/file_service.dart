import 'dart:typed_data';

import 'file_service_impl.dart'
    if (dart.library.js_interop) 'file_service_web.dart';

class FileService {
  const FileService();

  Future<void> downloadBytes({
    required Uint8List bytes,
    required String filename,
    required String mimeType,
  }) {
    return downloadBytesImpl(
      bytes: bytes,
      filename: filename,
      mimeType: mimeType,
    );
  }
}
