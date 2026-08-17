import 'participant.dart';

class Conversation {
  final String id;
  final String type;
  final DateTime createdAt;
  final Participant? participant;


  const Conversation({
    required this.id,
    required this.type,
    required this.createdAt,
    this.participant,
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
    );
  }
}