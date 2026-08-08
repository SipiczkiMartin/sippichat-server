import 'package:sippichat_client/core/network/api_client.dart';

import 'model/profile.dart';

class ProfileRepository {
  final ApiClient apiClient;

  ProfileRepository(this.apiClient);

  Future<Profile> getMe() async{
    final response = await apiClient.dio.get("/me");
    return Profile.fromJson(response.data);
  }

  Future<Profile> updateProfile({required String displayName, required String bio})async {
    final response = await apiClient.dio.patch('/me',
    data: {
      "display_name": displayName,
      "bio": bio,
    });

    return Profile.fromJson(response.data);
  }
}