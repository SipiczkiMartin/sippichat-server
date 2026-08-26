import 'package:sippichat_client/core/files/download_service.dart';
import 'package:sippichat_client/core/network/api_client.dart';

DownloadService createPlatformDownloadService(ApiClient apiClient) {
  return WebDownloadService(apiClient);
}

class WebDownloadService extends DownloadService {
  final ApiClient apiClient;

  const WebDownloadService(this.apiClient);

  @override
  Future<DownloadResult> download({
    required String storageKey,
    required String filename,
    required String mimeType,
  }) async {
    await apiClient.downloadForWeb(storageKey: storageKey, filename: filename);

    return const DownloadResult(type: DownloadResultType.browserHandled);
  }
}
