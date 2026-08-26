import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:sippichat_client/core/network/api_config.dart';
import 'package:sippichat_client/core/storage/token_storage.dart';
import 'package:sippichat_client/features/chat/models/upload_result.dart';

class ApiClient {
  late final Dio dio;

  final TokenStorage tokenStorage;

  Future<String?>? _refreshFuture;

  ApiClient(this.tokenStorage) {
    dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          debugPrint(
            'HTTP REQUEST: '
            '${options.method} '
            'baseUrl=${options.baseUrl} '
            'path=${options.path} '
            'uri=${options.uri}',
          );

          final token = await _getValidAccessToken();

          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }

          handler.next(options);
        },

        onResponse: (response, handler) {
          debugPrint(
            'HTTP RESPONSE: '
            '${response.statusCode} '
            '${response.requestOptions.method} '
            '${response.requestOptions.uri}',
          );

          handler.next(response);
        },

        onError: (error, handler) async {
          if (error.response?.statusCode != 401) {
            handler.next(error);
            return;
          }

          // Never try to refresh because of a refresh request itself.
          if (error.requestOptions.path == '/auth/refresh') {
            handler.next(error);
            return;
          }

          debugPrint('ApiClient: received 401, attempting token refresh');

          final newAccessToken = await _refreshAccessToken();

          if (newAccessToken == null) {
            debugPrint('ApiClient: token refresh failed');

            handler.next(error);
            return;
          }

          final requestOptions = error.requestOptions;

          requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';

          try {
            final response = await dio.fetch(requestOptions);

            handler.resolve(response);
          } on DioException catch (e) {
            handler.next(e);
          }
        },
      ),
    );
  }

  Future<String?> _getValidAccessToken() async {
    final accessToken = await tokenStorage.getAccessToken();

    if (accessToken == null || accessToken.isEmpty) {
      return null;
    }

    final expiresAt = await tokenStorage.getAccessTokenExpiresAt();

    // We don't know the expiry.
    // Use the token we have.
    if (expiresAt == null) {
      return accessToken;
    }

    // Refresh 30 seconds before expiry.
    final refreshThreshold = DateTime.now().add(const Duration(seconds: 30));

    if (expiresAt.isAfter(refreshThreshold)) {
      return accessToken;
    }

    debugPrint('ApiClient: access token expired/near expiry');

    final newAccessToken = await _refreshAccessToken();

    // Server unavailable:
    // keep using the old token.
    if (newAccessToken == null) {
      debugPrint(
        'ApiClient: refresh unavailable, '
        'using existing access token',
      );

      return accessToken;
    }

    return newAccessToken;
  }

  Future<String?> _refreshAccessToken() async {
    // Another request is already refreshing.
    if (_refreshFuture != null) {
      debugPrint('ApiClient: waiting for existing refresh');

      return await _refreshFuture!;
    }

    final future = _performRefresh();

    _refreshFuture = future;

    try {
      return await future;
    } finally {
      _refreshFuture = null;
    }
  }

  Future<String?> _performRefresh() async {
    final refreshToken = await tokenStorage.getRefreshToken();

    if (refreshToken == null || refreshToken.isEmpty) {
      debugPrint('ApiClient: no refresh token');

      return null;
    }

    final refreshClient = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    try {
      debugPrint('ApiClient: refreshing access token...');

      final response = await refreshClient.post(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );

      final data = response.data;

      final accessToken = data['access_token'] as String?;

      final newRefreshToken = data['refresh_token'] as String?;

      final expiresIn = data['expires_in'] as int?;

      if (accessToken == null || newRefreshToken == null || expiresIn == null) {
        debugPrint('ApiClient: invalid refresh response');

        return null;
      }

      await tokenStorage.saveTokens(
        accessToken: accessToken,
        refreshToken: newRefreshToken,
        expiresIn: expiresIn,
      );

      debugPrint('ApiClient: token refresh successful');

      return accessToken;
    } on DioException catch (e) {
      final status = e.response?.statusCode;

      debugPrint('ApiClient: refresh failed, status=$status');

      if (status == 401) {
        // Refresh token is definitely invalid.
        debugPrint(
          'ApiClient: refresh token is invalid, '
          'clearing session',
        );

        await tokenStorage.clear();

        return null;
      }

      if (e.response == null) {
        debugPrint('ApiClient: server/network unavailable');

        return null;
      }

      return null;
    } catch (e) {
      debugPrint('ApiClient: unexpected refresh error: $e');

      return null;
    }
  }

  Future<UploadResult> uploadFile(PlatformFile file) async {
    late MultipartFile multipartFile;

    if (kIsWeb) {
      final bytes = file.bytes;

      if (bytes == null) {
        throw Exception('File bytes are unavailable on Web');
      }

      multipartFile = MultipartFile.fromBytes(bytes, filename: file.name);
    } else {
      final path = file.path;

      if (path == null) {
        throw Exception('File path is unavailable');
      }

      multipartFile = await MultipartFile.fromFile(path, filename: file.name);
    }

    final formData = FormData.fromMap({'file': multipartFile});

    final response = await dio.post('/uploads', data: formData);

    return UploadResult.fromJson(response.data);
  }

  Future<List<int>> downloadFile(String storageKey) async {
    if (storageKey.isEmpty) {
      throw Exception('Storage key empty!');
    }

    final response = await dio.get<List<int>>(
      '/uploads/$storageKey',
      options: Options(responseType: ResponseType.bytes),
    );

    if (response.data == null) {
      throw Exception('Downloaded file is empty!');
    }
    return response.data!;
  }

  Future<void> downloadFileToPath({
    required String storageKey,
    required String savePath,
    void Function(int received, int total)? onProgress,
  }) async {
    if (storageKey.isEmpty) {
      throw Exception('Storage key empty!');
    }

    if (savePath.isEmpty) {
      throw Exception('Save path empty!');
    }

    await dio.download(
      '/uploads/$storageKey',
      savePath,
      onReceiveProgress: onProgress,
    );
  }

  Future<void> downloadForWeb({
    required String storageKey,
    required String filename,
  }) async {
    if (storageKey.isEmpty) {
      throw Exception('Storage key is empty');
    }

    await dio.download('/uploads/$storageKey', filename);
  }
}
