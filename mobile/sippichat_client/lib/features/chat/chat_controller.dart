import 'package:flutter/foundation.dart';
import 'package:sippichat_client/features/chat/chat_service.dart';
import 'package:sippichat_client/features/chat/models/message.dart';

class ChatController extends ChangeNotifier {
  final ChatService chatService;

  ChatController(this.chatService);

  List<Message> messages = [];
  bool loading = false;
  String? error;
  String? currentConversationId;
  bool hasMoreMessages = true;
  bool loadingMore = false;
  String? _nextCursor;

  Future<void> loadMessages(String conversationId) async {
    currentConversationId = conversationId;
    loading = true;
    loadingMore = false;
    hasMoreMessages = true;
    _nextCursor = null;
    error = null;

    messages = [];

    notifyListeners();

    try {
      final page = await chatService.getMessages(conversationId);

      if (currentConversationId != conversationId) {
        return;
      }

      _mergeMessages(page.messages);

      hasMoreMessages = page.hasMore;
      _nextCursor = page.nextCursor;
    } catch (e, stackTrace) {
      debugPrint("ERROR loading messages: $e");
      debugPrintStack(stackTrace: stackTrace);

      if (currentConversationId == conversationId) {
        error = e.toString();
      }
    } finally {
      if (currentConversationId == conversationId) {
        loading = false;
        notifyListeners();
      }
    }
  }

  void _mergeMessages(List<Message> incoming) {
    final messagesById = <String, Message>{
      for (final message in messages) message.id: message,
    };

    for (final message in incoming) {
      messagesById[message.id] = message;
    }

    final merged = messagesById.values.toList();

    merged.sort((a, b) {
      final createdAtComparison = a.createdAt.compareTo(b.createdAt);

      if (createdAtComparison != 0) {
        return createdAtComparison;
      }

      return a.id.compareTo(b.id);
    });

    messages = merged;

    notifyListeners();
  }

  Future<void> loadOlderMessages() async {
    final conversationId = currentConversationId;

    if (conversationId == null) {
      return;
    }

    if (!hasMoreMessages || loadingMore) {
      return;
    }

    final cursor = _nextCursor;

    if (cursor == null) {
      return;
    }

    loadingMore = true;
    notifyListeners();

    try {
      final page = await chatService.getMessages(
        conversationId,
        before: cursor,
      );

      if (currentConversationId != conversationId) {
        return;
      }

      final existingIds = messages.map((message) => message.id).toSet();

      final olderMessages = page.messages
          .where((message) => !existingIds.contains(message.id))
          .toList();

      messages = [...olderMessages, ...messages];

      hasMoreMessages = page.hasMore;
      _nextCursor = page.nextCursor;
    } catch (e, stackTrace) {
      debugPrint("ERROR loading older messages: $e");
      debugPrintStack(stackTrace: stackTrace);

      error = e.toString();
    } finally {
      loadingMore = false;
      notifyListeners();
    }
  }

  void clearMessages() {
    currentConversationId = null;
    messages = [];
    error = null;

    hasMoreMessages = true;
    loadingMore = false;
    _nextCursor = null;

    notifyListeners();
  }

  void addMessage(Message message) {
    if (messages.any((item) => item.id == message.id)) {
      return;
    }

    _mergeMessages([message]);
  }

  @override
  void dispose() {
    super.dispose();
  }
}
