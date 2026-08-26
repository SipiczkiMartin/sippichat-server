import 'dart:typed_data';

Future<void> downloadBytesImpl({
  required Uint8List bytes,
  required String filename,
  required String mimeType,
}) async {
  throw UnsupportedError('File download is not implemented on this platform.');
}
