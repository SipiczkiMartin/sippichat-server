enum DownloadResultType { browserHandled, savedToFile }

class DownloadResult {
  final DownloadResultType type;
  final String? path;

  const DownloadResult({required this.type, this.path});

  bool get shouldShowPopup => type == DownloadResultType.savedToFile;
}

abstract class DownloadService {
  const DownloadService();

  Future<DownloadResult> download({
    required String storageKey,
    required String filename,
    required String mimeType,
  });
}
