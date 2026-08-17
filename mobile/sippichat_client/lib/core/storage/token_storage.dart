import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  final FlutterSecureStorage _storage =
  const FlutterSecureStorage();

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    int? expiresIn,
  }) async {
    await _storage.write(
      key: 'access_token',
      value: accessToken,
    );

    await _storage.write(
      key: 'refresh_token',
      value: refreshToken,
    );

    if (expiresIn != null) {
      final expiresAt = DateTime.now()
          .add(Duration(seconds: expiresIn))
          .millisecondsSinceEpoch
          .toString();

      await _storage.write(
        key: 'access_token_expires_at',
        value: expiresAt,
      );
    }
  }

  Future<String?> getAccessToken() async {
    return await _storage.read(
      key: 'access_token',
    );
  }

  Future<String?> getRefreshToken() async {
    return await _storage.read(
      key: 'refresh_token',
    );
  }

  Future<DateTime?> getAccessTokenExpiresAt() async {
    final value = await _storage.read(
      key: 'access_token_expires_at',
    );

    if (value == null) {
      return null;
    }

    final milliseconds = int.tryParse(value);

    if (milliseconds == null) {
      return null;
    }

    return DateTime.fromMillisecondsSinceEpoch(
      milliseconds,
    );
  }

  Future<bool> isAccessTokenExpired() async {
    final expiresAt = await getAccessTokenExpiresAt();

    if (expiresAt == null) {
      return false;
    }

    return DateTime.now().isAfter(expiresAt);
  }

  Future<void> clear() async {
    await _storage.deleteAll();
  }
}