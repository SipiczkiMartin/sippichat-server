class Participant {
  final String id;
  final String username;
  final String displayName;
  final String? avatarUrl;

  const Participant({
    required this.id,
    required this.username,
    required this.displayName,
    this.avatarUrl,
  });


  factory Participant.fromJson(Map<String, dynamic> json) {
    return Participant(
      id: json["id"],
      username: json["username"],
      displayName: json["display_name"],
      avatarUrl: json["avatar_url"],
    );
  }
}