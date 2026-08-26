import 'dart:typed_data';
import 'dart:js_interop';

@JS('document.createElement')
external JSObject _createElement(JSString tagName);

Future<void> downloadBytesImpl({
  required Uint8List bytes,
  required String filename,
  required String mimeType,
}) async {
  // Browser implementation next.
}
