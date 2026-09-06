import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sippichat_client/app/app_dependencies.dart';
import 'package:sippichat_client/features/conversations/conversation_service.dart';
import 'package:sippichat_client/features/conversations/models/conversation.dart';

class ConversationController extends ChangeNotifier {
  final ConversationService conversationService;

  StreamSubscription<Map<String, dynamic>>? _websocketSubscription;

  ConversationController(this.conversationService) {
    _websocketSubscription = AppDependencies.webSocketService.events.listen(
      _handleWebSocketEvent,
    );
  }

  List<Conversation> conversations = [];

  bool loading = false;
  String? error;

  /// The conversation currently open in ChatPage.
  String? activeConversationId;

  // ---------------------------------------------------------------------------
  // Active conversation
  // ---------------------------------------------------------------------------

  void setActiveConversation(String conversationId) {
    activeConversationId = conversationId;

    debugPrint('CONVERSATION: active conversation=$conversationId');

    markConversationAsRead(conversationId);

    notifyListeners();
  }

  void clearActiveConversation(String conversationId) {
    if (activeConversationId != conversationId) {
      return;
    }

    activeConversationId = null;

    debugPrint('CONVERSATION: cleared active conversation=$conversationId');

    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // WebSocket events
  // ---------------------------------------------------------------------------

  void _handleWebSocketEvent(Map<String, dynamic> event) {
    final type = event['type'];

    debugPrint('CONVERSATION WS EVENT: $type');

    if (type != 'message.created') {
      return;
    }

    final payload = event['payload'];

    if (payload is! Map<String, dynamic>) {
      debugPrint('CONVERSATION WS: payload is not a Map');
      return;
    }

    _handleMessageCreated(payload);
  }

  void _handleMessageCreated(Map<String, dynamic> payload) {
    debugPrint('CONVERSATION WS: message.created payload=$payload');

    final conversationId = payload['conversation_id'];
    final sender = payload['sender'];

    if (conversationId is! String) {
      debugPrint('CONVERSATION WS: invalid conversation_id');
      return;
    }

    if (sender is! Map<String, dynamic>) {
      debugPrint('CONVERSATION WS: invalid sender');
      return;
    }

    final senderId = sender['id'];

    if (senderId is! String) {
      debugPrint('CONVERSATION WS: invalid sender id');
      return;
    }

    final currentUserId = AppDependencies.authRepository.currentUser?.id;

    if (currentUserId == null) {
      debugPrint('CONVERSATION WS: no current user');
      return;
    }

    // Never count our own messages as unread.
    if (senderId == currentUserId) {
      debugPrint('CONVERSATION WS: ignoring own message');
      return;
    }

    // If this conversation is currently open,
    // ChatView will mark the message as read.
    //
    // Therefore we do NOT increment the conversation badge.
    if (conversationId == activeConversationId) {
      debugPrint('CONVERSATION WS: message belongs to active conversation');
      return;
    }

    final index = conversations.indexWhere(
      (conversation) => conversation.id == conversationId,
    );

    debugPrint('CONVERSATION WS: matching conversation index=$index');

    if (index == -1) {
      debugPrint('CONVERSATION WS: conversation not found: $conversationId');
      return;
    }

    final conversation = conversations[index];

    final newUnreadCount = conversation.unreadCount + 1;

    debugPrint(
      'CONVERSATION WS: unread '
      '${conversation.unreadCount} -> $newUnreadCount',
    );

    conversations[index] = conversation.copyWith(unreadCount: newUnreadCount);

    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Conversations
  // ---------------------------------------------------------------------------

  Future<void> loadConversations() async {
    loading = true;
    error = null;

    debugPrint('START LOADING');

    notifyListeners();

    try {
      conversations = await conversationService.getConversations();

      debugPrint('LOADED ${conversations.length} conversations');
    } catch (e, stackTrace) {
      debugPrint('ERROR: $e');
      debugPrintStack(stackTrace: stackTrace);

      error = e.toString();
    }

    loading = false;

    debugPrint('NOTIFYING LISTENERS');

    notifyListeners();
  }

  Future<Conversation?> createConversation(String userId) async {
    try {
      final conversation = await conversationService.createConversation(userId);

      await loadConversations();

      return conversation;
    } catch (e, stackTrace) {
      debugPrint('CREATE CONVERSATION ERROR: $e');
      debugPrintStack(stackTrace: stackTrace);

      error = e.toString();

      notifyListeners();

      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Read state
  // ---------------------------------------------------------------------------

  void markConversationAsRead(String conversationId) {
    final index = conversations.indexWhere(
      (conversation) => conversation.id == conversationId,
    );

    if (index == -1) {
      return;
    }

    final conversation = conversations[index];

    if (conversation.unreadCount == 0) {
      return;
    }

    debugPrint(
      'CONVERSATION: marking $conversationId as read '
      '(${conversation.unreadCount} -> 0)',
    );

    conversations[index] = conversation.copyWith(unreadCount: 0);

    notifyListeners();
  }

  //unread count

  int unreadCountFor(String conversationId) {
    final conversation = conversations.cast<Conversation?>().firstWhere(
          (conversation) => conversation?.id == conversationId,
      orElse: () => null,
    );

    return conversation?.unreadCount ?? 0;
  }

  bool hasUnreadMessages(String conversationId) {
    return unreadCountFor(conversationId) > 0;
  }


  // ---------------------------------------------------------------------------
  // Dispose
  // ---------------------------------------------------------------------------

  @override
  void dispose() {
    _websocketSubscription?.cancel();
    _websocketSubscription = null;

    super.dispose();
  }
}
