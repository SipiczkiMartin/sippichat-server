import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:sippichat_client/core/storage/token_storage.dart';

enum TokenRefreshStatus {
  success,
  noRefreshToken,
  invalidRefreshToken,
  serverUnavailable,
  failed,
}

class TokenRefreshResult {
  final TokenRefreshStatus status;
  final String? accessToken;

  const TokenRefreshResult(
      this.status, {
        this.accessToken,
      });

  bool get isSuccess =>
      status == TokenRefreshStatus.success;

  bool get isServerUnavailable =>
      status == TokenRefreshStatus.serverUnavailable;

  bool get isInvalidRefreshToken =>
      status == TokenRefreshStatus.invalidRefreshToken;
}

class AuthSessionManager {
  final TokenStorage storage;

  late final Dio _refreshClient;

  Future<TokenRefreshResult>? _refreshFuture;

  AuthSessionManager(this.storage) {
    _refreshClient = Dio(
      BaseOptions(
        baseUrl: 'http://10.0.2.2:8080',
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          'Content-Type': 'application/json',
        },
      ),
    );
  }

  Future<TokenRefreshResult> forceRefresh() {
    debugPrint(
      'AuthSessionManager: forcing token refresh',
    );

    return refresh();
  }

  Future<String?> getValidAccessToken() async {
    final accessToken = await storage.getAccessToken();

    if (accessToken == null || accessToken.isEmpty) {
      return null;
    }

    final expiresAt =
    await storage.getAccessTokenExpiresAt();

    // If we don't know the expiry, use the token we have.
    if (expiresAt == null) {
      return accessToken;
    }

    final refreshThreshold = DateTime.now().add(
      const Duration(seconds: 30),
    );

    if (expiresAt.isAfter(refreshThreshold)) {
      return accessToken;
    }

    debugPrint(
      'AuthSessionManager: access token expired/near expiry',
    );

    final result = await refresh();

    if (result.isSuccess) {
      return result.accessToken;
    }

    // VERY IMPORTANT:
    //
    // Server unavailable means:
    // "we don't know whether the session is still valid."
    //
    // Do NOT delete the tokens.
    //
    // Return the old token so WebSocket/API retry logic
    // can continue once the server comes back.
    if (result.isServerUnavailable) {
      debugPrint(
        'AuthSessionManager: server unavailable, '
            'keeping existing access token',
      );

      return accessToken;
    }

    // Invalid refresh token / no refresh token / permanent
    // failure means we cannot establish an authenticated session.
    return null;
  }

  Future<TokenRefreshResult> refresh() async {
    // Prevent multiple simultaneous refresh requests.
    if (_refreshFuture != null) {
      debugPrint(
        'AuthSessionManager: waiting for existing refresh',
      );

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

  Future<TokenRefreshResult> _performRefresh() async {
    final refreshToken =
    await storage.getRefreshToken();

    if (refreshToken == null || refreshToken.isEmpty) {
      debugPrint(
        'AuthSessionManager: no refresh token',
      );

      return const TokenRefreshResult(
        TokenRefreshStatus.noRefreshToken,
      );
    }

    try {
      debugPrint(
        'AuthSessionManager: refreshing access token...',
      );

      final response = await _refreshClient.post(
        '/auth/refresh',
        data: {
          'refresh_token': refreshToken,
        },
      );

      final data = response.data;

      final accessToken =
      data['access_token'] as String?;

      final newRefreshToken =
      data['refresh_token'] as String?;

      final expiresIn =
      data['expires_in'] as int?;

      if (accessToken == null ||
          newRefreshToken == null ||
          expiresIn == null) {
        debugPrint(
          'AuthSessionManager: invalid refresh response',
        );

        return const TokenRefreshResult(
          TokenRefreshStatus.failed,
        );
      }

      await storage.saveTokens(
        accessToken: accessToken,
        refreshToken: newRefreshToken,
        expiresIn: expiresIn,
      );

      debugPrint(
        'AuthSessionManager: token refresh successful',
      );

      return TokenRefreshResult(
        TokenRefreshStatus.success,
        accessToken: accessToken,
      );
    } on DioException catch (e) {
      final status = e.response?.statusCode;

      debugPrint(
        'AuthSessionManager: refresh failed '
            'status=$status',
      );

      // Server explicitly said:
      // "this refresh token is invalid."
      //
      // THIS is when we destroy the local session.
      if (status == 401) {
        debugPrint(
          'AuthSessionManager: refresh token is invalid',
        );

        await storage.clear();

        return const TokenRefreshResult(
          TokenRefreshStatus.invalidRefreshToken,
        );
      }

      // No HTTP response = server unavailable,
      // connection refused, timeout, network failure, etc.
      if (e.response == null) {
        debugPrint(
          'AuthSessionManager: server/network unavailable',
        );

        return const TokenRefreshResult(
          TokenRefreshStatus.serverUnavailable,
        );
      }

      return const TokenRefreshResult(
        TokenRefreshStatus.failed,
      );
    } catch (e) {
      debugPrint(
        'AuthSessionManager: unexpected refresh error: $e',
      );

      return const TokenRefreshResult(
        TokenRefreshStatus.failed,
      );
    }
  }
}