import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:sippichat_client/core/network/api_client.dart';
import 'package:sippichat_client/core/network/socket/websocket_service.dart';
import 'package:sippichat_client/features/chat/chat_service.dart';
import 'package:sippichat_client/features/chat/models/message.dart';

import 'models/attachment.dart';
import 'models/upload_result.dart';

class ChatController extends ChangeNotifier {
  final ChatService chatService;
  final WebSocketService webSocketService;
  final ApiClient apiClient;

  StreamSubscription<Map<String, dynamic>>? _websocketSubscription;

  ChatController(this.chatService, this.webSocketService, this.apiClient) {
    _websocketSubscription = webSocketService.events.listen(
      _handleWebSocketEvent,
    );
  }

  List<Message> messages = [];

  bool loading = false;
  bool loadingMore = false;
  bool hasMoreMessages = true;
  bool isOtherUserTyping = false;

  String? error;
  String? currentConversationId;
  String? _nextCursor;

  void _handleWebSocketEvent(Map<String, dynamic> event) {
    final type = event['type'];

    debugPrint('CHAT WS EVENT: $type');

    final payload = event['payload'];

    if (payload is! Map<String, dynamic>) {
      return;
    }

    switch (type) {
      case 'message.created':
        _handleMessageCreated(payload);
        break;
      case 'typing.started':
        _handleTypingStarted(payload);
        break;
      case 'typing.stopped':
        _handleTypingStopped(payload);
        break;
    }
  }

  void _handleMessageCreated(Map<String, dynamic> payload) {
    final message = Message.fromJson(payload);
    if (message.conversationId != currentConversationId) {
      return;
    }

    addMessage(message);
  }

  void _handleTypingStarted(Map<String, dynamic> payload) {
    final conversationId = payload['conversation_id'];

    if (conversationId != currentConversationId) {
      return;
    }

    isOtherUserTyping = true;
    debugPrint('Typing: started');
    notifyListeners();
  }

  void _handleTypingStopped(Map<String, dynamic> payload) {
    final conversationId = payload['conversation_id'];

    if (conversationId != currentConversationId) {
      return;
    }

    isOtherUserTyping = false;
    debugPrint('Typing: stopped');
    notifyListeners();
  }

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
      debugPrint('ERROR loading messages: $e');
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

  void sendMessage(String content, {List<Attachment> attachments = const []}) {
    final conversationId = currentConversationId;

    if (conversationId == null) {
      return;
    }

    final trimmedContent = content.trim();

    if (trimmedContent.isEmpty && attachments.isEmpty) {
      return;
    }

    if (!webSocketService.isConnected) {
      debugPrint('WS: cannot send message, socket not connected');
      return;
    }

    webSocketService.send(
      type: 'message.send',
      payload: {
        'conversation_id': conversationId,
        'content': trimmedContent,
        'attachments': attachments.map((attachment) {
          return {
            'type': attachment.type,
            'external_url': attachment.externalUrl,
            'storage_key': attachment.storageKey,
            'filename': attachment.filename,
            'mime_type': attachment.mimeType,
            'size': attachment.size,
            'metadata': attachment.metadata,
          };
        }).toList(),
      },
    );
  }

  Future<void> loadOlderMessages() async {
    final conversationId = currentConversationId;

    if (conversationId == null ||
        !hasMoreMessages ||
        loadingMore ||
        _nextCursor == null) {
      return;
    }

    loadingMore = true;
    notifyListeners();

    try {
      final page = await chatService.getMessages(
        conversationId,
        before: _nextCursor,
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
      debugPrint('ERROR loading older messages: $e');
      debugPrintStack(stackTrace: stackTrace);

      error = e.toString();
    } finally {
      loadingMore = false;
      notifyListeners();
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

  void addMessage(Message message) {
    if (messages.any((item) => item.id == message.id)) {
      return;
    }

    _mergeMessages([message]);
  }

  void sendTypingStart(String conversationId) {
    if (!webSocketService.isConnected) {
      return;
    }

    webSocketService.send(
      type: 'typing.started',
      payload: {'conversation_id': conversationId},
    );
  }

  void sendTypingStop(String conversationId) {
    if (!webSocketService.isConnected) {
      return;
    }

    webSocketService.send(
      type: 'typing.stopped',
      payload: {'conversation_id': conversationId},
    );
  }

  Future<UploadResult> uploadFile(PlatformFile file) async {
    debugPrint('CHAT: uploading file ${file.name}');

    final result = await apiClient.uploadFile(file);

    debugPrint(
      'CHAT: upload successful '
      'storageKey=${result.storageKey}',
    );

    return result;
  }

  void clearMessages() {
    currentConversationId = null;
    messages = [];
    error = null;
    hasMoreMessages = true;
    loadingMore = false;
    _nextCursor = null;
    isOtherUserTyping = false;

    notifyListeners();
  }

  @override
  void dispose() {
    _websocketSubscription?.cancel();
    super.dispose();
  }
}
