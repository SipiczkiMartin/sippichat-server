import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sippichat_client/app/app_dependencies.dart';
import 'package:sippichat_client/core/network/api_config.dart';
import 'package:sippichat_client/features/auth/login_page.dart';
import 'package:sippichat_client/features/auth/web_login_page.dart';
import 'package:sippichat_client/features/web/web_shell.dart';

import '../conversations/conversations_page.dart';

class AuthBootstrap extends StatefulWidget {
  const AuthBootstrap({super.key});

  @override
  State<AuthBootstrap> createState() => _AuthBootstrapState();
}

class _AuthBootstrapState extends State<AuthBootstrap> {
  @override
  void initState() {
    super.initState();

    debugPrint('AUTH BOOTSTRAP: initState');

    AppDependencies.authController.initialize();
  }

  Future<void> _connectWebSocket() async {
    debugPrint(
      'AUTH BOOTSTRAP: connecting WebSocket ${ApiConfig.websocketUrl}',
    );

    await AppDependencies.webSocketService.connect(url: ApiConfig.websocketUrl);

    debugPrint('AUTH BOOTSTRAP: WebSocket connection complete');
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppDependencies.authController,
      builder: (context, _) {
        final auth = AppDependencies.authController;

        debugPrint(
          'AUTH BOOTSTRAP BUILD: '
          'loading=${auth.loading}, '
          'authenticated=${auth.authenticated}',
        );

        if (auth.loading) {
          debugPrint('AUTH BOOTSTRAP: showing loading screen');

          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (auth.authenticated) {
          debugPrint('AUTH BOOTSTRAP: authenticated -> starting WebSocket');

          return FutureBuilder(
            future: _connectWebSocket(),
            builder: (context, snapshot) {
              debugPrint(
                'AUTH BOOTSTRAP FUTURE: '
                'connectionState=${snapshot.connectionState}',
              );

              if (snapshot.connectionState != ConnectionState.done) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError) {
                debugPrint('AUTH BOOTSTRAP FUTURE ERROR: ${snapshot.error}');

                return Scaffold(
                  body: Center(
                    child: Text(
                      'Unable to connect to server: ${snapshot.error}',
                    ),
                  ),
                );
              }

              if (kIsWeb) {
                debugPrint('AUTH BOOTSTRAP: showing WebShell');

                return const WebShell();
              }

              debugPrint('AUTH BOOTSTRAP: showing ConversationsPage');

              return const ConversationsPage();
            },
          );
        }

        debugPrint('AUTH BOOTSTRAP: unauthenticated -> showing login');

        if (kIsWeb) {
          return const WebLoginPage();
        }

        return const LoginPage();
      },
    );
  }
}
