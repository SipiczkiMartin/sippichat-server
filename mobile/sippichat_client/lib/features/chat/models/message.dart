class Message {
  final String id;
  final String conversationId;
  final String? clientMessageId;
  final String content;
  final DateTime createdAt;
  final Sender sender;
  final MessageStatus status;

  const Message({
    required this.id,
    required this.conversationId,
    this.clientMessageId,
    required this.content,
    required this.createdAt,
    required this.sender,
    this.status = MessageStatus.sent
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json["id"],
      conversationId: json["conversation_id"],
      clientMessageId: json["client_message_id"],
      content: json["content"],
      createdAt: DateTime.parse(json["created_at"]),
      sender: Sender.fromJson(
        json["sender"],
      ),
    );
  }

  Message copyWith({
    MessageStatus? status,
  }) {
    return Message(
      id: id,
      conversationId: conversationId,
      clientMessageId: clientMessageId,
      content: content,
      createdAt: createdAt,
      sender: sender,
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