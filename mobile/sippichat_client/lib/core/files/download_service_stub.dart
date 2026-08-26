import 'download_service.dart';
import 'package:sippichat_client/core/network/api_client.dart';

DownloadService createPlatformDownloadService(ApiClient apiClient) {
  throw UnsupportedError('File downloads are not supported on this platform.');
}
