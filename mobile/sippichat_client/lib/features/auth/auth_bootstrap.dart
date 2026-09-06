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

    AppDependencies.authController.initialize();
  }

  Future<void> _connectWebSocket() async {
    await AppDependencies.webSocketService.connect(url: ApiConfig.websocketUrl);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppDependencies.authController,
      builder: (context, _) {
        final auth = AppDependencies.authController;

        if (auth.loading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (auth.authenticated) {
          return FutureBuilder(
            future: _connectWebSocket(),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              if (kIsWeb) {
                return const WebShell();
              }

              return const ConversationsPage();
            },
          );
        }

        if (kIsWeb) {
          return const WebLoginPage();
        }

        return const LoginPage();
      },
    );
  }
}
