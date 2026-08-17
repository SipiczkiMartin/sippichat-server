class LoginResponse {
  final String accessToken;
  final String refreshToken;
  final int expiresIn;

  LoginResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
});

  factory LoginResponse.fromJson(Map<String, dynamic> json){
    return LoginResponse(accessToken: json['access_token'], refreshToken: json['refresh_token'], expiresIn: json["expires_in"]);
  }
}