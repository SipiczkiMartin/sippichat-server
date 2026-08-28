import 'package:flutter/foundation.dart';

class ApiConfig {
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:8080';
    }

    return 'http://10.0.2.2:8080';
  }

  static String get websocketUrl{
    if(kIsWeb){
      return 'ws://localhost:8080/ws';
    }

    return 'ws//10.0.2.2:8080/ws';
  }

  static const String giphyApiKey = String.fromEnvironment(
    'GIPHY_API_KEY',
  );
}
