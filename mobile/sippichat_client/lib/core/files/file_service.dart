import 'file_service_impl.dart'
    if (dart.library.js_interop) 'file_service_web.dart';

class FileService {
  const FileService();

  Future<String?> chooseDownloadPath({required String filename}) {
    return chooseDownloadPathImpl(filename: filename);
  }

  Future<void> openFile(String path) {
    return openFileImpl(path);
  }
}
