import 'package:dio/dio.dart';
import 'package:sippichat_client/core/network/api_config.dart';

class GiphyGif {
  final String id;
  final String previewUrl;
  final String url;
  final int width;
  final int height;

  const GiphyGif({
    required this.id,
    required this.previewUrl,
    required this.url,
    required this.width,
    required this.height,
  });

  factory GiphyGif.fromJson(Map<String, dynamic> json) {
    final images = json['images'] as Map<String, dynamic>? ?? {};

    final preview = images['fixed_width_small'] as Map<String, dynamic>?;
    final original = images['original'] as Map<String, dynamic>?;

    return GiphyGif(
      id: json['id'] as String? ?? '',
      previewUrl: preview?['url'] as String? ?? '',
      url: original?['url'] as String? ?? '',
      width: int.tryParse(original?['width']?.toString() ?? '') ?? 0,
      height: int.tryParse(original?['height']?.toString() ?? '') ?? 0,
    );
  }
}

class GiphyService {
  late final Dio _dio;

  GiphyService() {
    _dio = Dio(
      BaseOptions(
        baseUrl: 'https://api.giphy.com/v1',
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );
  }

  Future<List<GiphyGif>> trending({int limit = 30}) async {
    _checkApiKey();

    final response = await _dio.get(
      '/gifs/trending',
      queryParameters: {
        'api_key': ApiConfig.giphyApiKey,
        'limit': limit,
        'rating': 'pg',
        'bundle': 'messaging_non_clips',
      },
    );

    return _parse(response.data);
  }

  Future<List<GiphyGif>> search(String query, {int limit = 30}) async {
    _checkApiKey();

    final trimmed = query.trim();

    if (trimmed.isEmpty) {
      return trending(limit: limit);
    }

    final response = await _dio.get(
      '/gifs/search',
      queryParameters: {
        'api_key': ApiConfig.giphyApiKey,
        'q': trimmed,
        'limit': limit,
        'rating': 'pg',
        'bundle': 'messaging_non_clips',
      },
    );

    return _parse(response.data);
  }

  List<GiphyGif> _parse(dynamic data) {
    if (data is! Map<String, dynamic>) {
      return [];
    }

    final items = data['data'];

    if (items is! List) {
      return [];
    }

    return items
        .whereType<Map<String, dynamic>>()
        .map(GiphyGif.fromJson)
        .where((gif) => gif.url.isNotEmpty)
        .toList();
  }

  void _checkApiKey() {
    if (ApiConfig.giphyApiKey.isEmpty) {
      throw Exception(
        'GIPHY API key is not configured. '
        'Run Flutter with --dart-define=GIPHY_API_KEY=...',
      );
    }
  }
}
