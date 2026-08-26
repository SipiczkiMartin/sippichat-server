import 'package:sippichat_client/core/network/api_client.dart';

import 'download_service.dart';
import 'download_service_stub.dart'
    if (dart.library.html) 'web_download_service.dart'
    if (dart.library.io) 'native_download_service.dart';

DownloadService createDownloadService(ApiClient apiClient) {
  return createPlatformDownloadService(apiClient);
}
