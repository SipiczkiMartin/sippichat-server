import 'dart:async';

import 'package:sippichat_client/features/typing/typing_service.dart';

class TypingController {
  final TypingService typingService;

  Timer? _typingTimer;
  bool _isTyping = false;

  TypingController({required this.typingService});

  void onTextChanged({required String conversationId, required String text}) {
    if (text.trim().isEmpty) {
      _typingTimer?.cancel();

      if (_isTyping) {
        typingService.stopped(conversationId);
        _isTyping = false;
      }

      return;
    }

    // Only send "started" once.
    if (!_isTyping) {
      typingService.started(conversationId);
      _isTyping = true;
    }

    // User is still typing, so reset the stop timer.
    _typingTimer?.cancel();

    _typingTimer = Timer(const Duration(seconds: 2), () {
      typingService.stopped(conversationId);
      _isTyping = false;
    });
  }

  void dispose() {
    _typingTimer?.cancel();
  }
}
