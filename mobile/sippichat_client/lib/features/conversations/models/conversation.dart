import 'participant.dart';

class Conversation {
  final String id;
  final String type;
  final DateTime createdAt;
  final Participant? participant;
  final int unreadCount;

  const Conversation({
    required this.id,
    required this.type,
    required this.createdAt,
    this.participant,
    this.unreadCount = 0,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json["id"],
      type: json["type"],
      createdAt: DateTime.parse(
        json["created_at"],
      ),
      participant: json["participant"] != null
          ? Participant.fromJson(
        json["participant"],
      )
          : null,
      unreadCount: (json["unread_count"] as num?)?.toInt() ?? 0,
    );
  }

  Conversation copyWith({
    String? id,
    String? type,
    DateTime? createdAt,
    Participant? participant,
    int? unreadCount,
  }) {
    return Conversation(
      id: id ?? this.id,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      participant: participant ?? this.participant,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}