import 'package:flutter/material.dart';
import 'package:sippichat_client/app/app_dependencies.dart';
import 'package:sippichat_client/features/auth/login_page.dart';

import '../conversations/conversations_page.dart';

class AuthBootstrap extends StatefulWidget {
  const AuthBootstrap({super.key});

  @override
  State<AuthBootstrap> createState() => _AuthBootstrapState();
}

class _AuthBootstrapState extends State<AuthBootstrap> {
  late final Future<bool> _sessionFuture =
  AppDependencies.authRepository.restoreSession();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _sessionFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.data == true) {
          return const ConversationsPage();
        }

        return const LoginPage();
      },
    );
  }
}