import 'package:sippichat_client/core/network/api_client.dart';

import 'download_service.dart';
import 'download_service_stub.dart'
    if (dart.library.html) 'download_service_web.dart'
    if (dart.library.io) 'download_service_android.dart';

DownloadService createDownloadService(ApiClient apiClient) {
  return createPlatformDownloadService(apiClient);
}
