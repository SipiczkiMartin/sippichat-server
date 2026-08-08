import 'dart:async';

import 'package:sippichat_client/core/network/typing_service.dart';

class TypingController {

  final TypingService typingService;
  Timer? _typingTimer;

  TypingController({
    required this.typingService,
});

  void onTextExchanged({
    required String conversationId,
    required String text,
}){
    if(text.trim().isEmpty) {
      return;
    }

    typingService.started(conversationId);
    _typingTimer?.cancel();

    _typingTimer = Timer(
      const Duration(seconds: 2),
        (){
        typingService.stopped(conversationId);

        }
    );
  }

  void dispose(){
    _typingTimer?.cancel();

  }
}