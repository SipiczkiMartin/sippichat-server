import 'package:flutter/foundation.dart';

class ApiConfig {
  static const String _productionBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static const String _productionWebsocketUrl = String.fromEnvironment(
    'WEBSOCKET_URL',
    defaultValue: '',
  );

  static String get baseUrl {
    if (_productionBaseUrl.isNotEmpty) {
      return _productionBaseUrl;
    }

    if (kIsWeb) {
      return 'http://localhost:8080';
    }

    return 'http://10.0.2.2:8080';
  }

  static String get websocketUrl {
    if (_productionWebsocketUrl.isNotEmpty) {
      return _productionWebsocketUrl;
    }

    if (kIsWeb) {
      return 'ws://localhost:8080/ws';
    }

    return 'ws://10.0.2.2:8080/ws';
  }

  static const String giphyApiKey = String.fromEnvironment('GIPHY_API_KEY');
}