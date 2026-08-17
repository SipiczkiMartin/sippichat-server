import 'message.dart';

class MessagePage {
  final List<Message> messages;
  final bool hasMore;
  final String? nextCursor;

  MessagePage({
    required this.messages,
    required this.hasMore,
    required this.nextCursor,
  });

  factory MessagePage.fromJson(Map<String, dynamic> json) {
    final messagesJson = json["messages"] as List<dynamic>;

    return MessagePage(
      messages: messagesJson
          .map(
            (json) => Message.fromJson(
          json as Map<String, dynamic>,
        ),
      )
          .toList(),
      hasMore: json["has_more"] as bool,
      nextCursor: json["next_cursor"] as String?,
    );
  }
}