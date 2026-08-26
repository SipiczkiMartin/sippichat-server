import 'package:sippichat_client/features/chat/models/attachment.dart';

class Message {
  final String id;
  final String conversationId;
  final String content;
  final DateTime createdAt;
  final Sender sender;
  final List<Attachment> attachments;
  final MessageStatus status;

  const Message({
    required this.id,
    required this.conversationId,
    required this.content,
    required this.createdAt,
    required this.sender,
    this.attachments = const [],
    this.status = MessageStatus.sent
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    final attachmentsJson =
        json["attachments"] as List<dynamic>? ?? [];

    return Message(
      id: json["id"],
      conversationId: json["conversation_id"],
      content: json["content"],
      createdAt: DateTime.parse(json["created_at"]),
      sender: Sender.fromJson(
        json["sender"],
      ),
      attachments: attachmentsJson
          .map(
            (json) => Attachment.fromJson(
          json as Map<String, dynamic>,
        ),
      )
          .toList(),
    );
  }


  Message copyWith({
    MessageStatus? status,
    List<Attachment>? attachments,
  }) {
    return Message(
      id: id,
      conversationId: conversationId,
      content: content,
      createdAt: createdAt,
      sender: sender,
      attachments: attachments ?? this.attachments,
      status: status ?? this.status,
    );
  }

}



enum MessageStatus{
  sent,
  delivered,
  read,
}

class Sender {
  final String id;
  final String username;
  final String displayName;
  final String? avatarUrl;

  const Sender({
    required this.id,
    required this.username,
    required this.displayName,
    this.avatarUrl,
  });

  factory Sender.fromJson(Map<String, dynamic> json) {
    return Sender(
      id: json["id"],
      username: json["username"] ?? "",
      displayName: json["display_name"] ?? "",
      avatarUrl: json["avatar_url"],
    );
  }
}