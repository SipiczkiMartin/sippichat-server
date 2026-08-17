import 'package:sippichat_client/core/network/api_client.dart';

import 'models/user_search_result.dart';

class UserSearchService {
  final ApiClient apiClient;

  UserSearchService(this.apiClient);

  Future<List<UserSearchResult>> searchUsers(String query) async{
    final response = await apiClient.dio.get(
      '/users/search',
      queryParameters: {
        'q': query,
      }
    );

    final List<dynamic> data = response.data;
    return data.map(
        (json) => UserSearchResult.fromJson(
          json as Map<String, dynamic>,
        ),
    ).toList();
  }
}