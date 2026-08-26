import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:sippichat_client/core/files/download_service.dart';
import 'package:sippichat_client/core/network/api_client.dart';

DownloadService createPlatformDownloadService(ApiClient apiClient) {
  return AndroidDownloadService(apiClient);
}

class AndroidDownloadService extends DownloadService {
  final ApiClient apiClient;

  const AndroidDownloadService(this.apiClient);

  @override
  Future<DownloadResult> download({
    required String storageKey,
    required String filename,
    required String mimeType,
  }) async {
    final downloadsDirectory = await getDownloadsDirectory();

    if (downloadsDirectory == null) {
      throw Exception('Android Downloads directory is unavailable.');
    }

    if (!await downloadsDirectory.exists()) {
      await downloadsDirectory.create(recursive: true);
    }

    final file = File('${downloadsDirectory.path}/$filename');

    await apiClient.downloadFileToPath(
      storageKey: storageKey,
      savePath: file.path,
    );

    return DownloadResult(
      type: DownloadResultType.savedToFile,
      path: file.path,
    );
  }
}
