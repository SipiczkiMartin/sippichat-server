import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'package:sippichat_client/core/errors/app_exception.dart';
import 'package:sippichat_client/core/network/api_client.dart';
import 'package:sippichat_client/core/network/websocket_client.dart';
import 'package:sippichat_client/core/storage/token_storage.dart';

import 'package:sippichat_client/features/auth/models/register_request.dart';
import 'package:sippichat_client/features/auth/models/user.dart';

import 'models/login_response.dart';

class AuthRepository {
  final ApiClient apiClient;
  final TokenStorage storage;

  AuthRepository({
    required this.apiClient,
    required this.storage,
  });

  User? _currentUser;

  User? get currentUser => _currentUser;

  Future<User> register(RegisterRequest request) async {
    try {
      final response = await apiClient.dio.post(
        '/auth/register',
        data: request.toJson(),
      );

      final loginResponse = LoginResponse.fromJson(response.data);

      await storage.saveTokens(
        accessToken: loginResponse.accessToken,
        refreshToken: loginResponse.refreshToken,
        expiresIn: loginResponse.expiresIn,
      );

      final user = await getCurrentUser();

      _currentUser = user;

      return user;
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) {
        throw const AppException("Email already exists or invalid data!");
      }

      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.connectionError) {
        throw const AppException("Cannot connect to server!");
      }

      throw const AppException("Something went wrong! Try again.");
    }
  }

  Future<User> login(String email, String password) async {
    try {
      final response = await apiClient.dio.post(
        '/auth/login',
        data: {'email': email, 'password': password},
      );

      final loginResponse = LoginResponse.fromJson(response.data);

      await storage.saveTokens(
        accessToken: loginResponse.accessToken,
        refreshToken: loginResponse.refreshToken,
        expiresIn: loginResponse.expiresIn,
      );

      final user = await getCurrentUser();

      _currentUser = user;

      return user;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw const AppException('Invalid email or password');
      }

      if (e.response?.statusCode == 400) {
        throw const AppException('Please check your input');
      }

      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.connectionError) {
        throw const AppException('Cannot connect to server!');
      }

      throw const AppException('Something went wrong. Try again.');
    }
  }

  Future<void> logout() async {
    try {
      final refreshToken = await storage.getRefreshToken();

      if (refreshToken != null && refreshToken.isNotEmpty) {
        await apiClient.dio.post(
          '/auth/logout',
          data: {'refresh_token': refreshToken},
        );
      }
    } finally {
      await storage.clear();
      _currentUser = null;
    }
  }

  Future<User> getCurrentUser() async {
    final response = await apiClient.dio.get('/me');
    final user = User.fromJson(response.data);

    _currentUser = user;

    return user;
  }

  Future<bool> restoreSession() async {
    try {
      final response = await apiClient.dio.get('/me');

      final user = User.fromJson(response.data);

      _currentUser = user;

      return true;
    } on DioException catch (e) {
      debugPrint('Session restore failed: $e');

      if (e.response?.statusCode == 401) {
        await storage.clear();
        _currentUser = null;

        return false;
      }

      if (e.response == null) {
        debugPrint(
          'Session restore: server unavailable, '
          'keeping session',
        );

        return true;
      }

      return false;
    } catch (e) {
      debugPrint('Session restore failed: $e');

      return false;
    }
  }
}
