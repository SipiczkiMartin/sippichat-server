import 'package:flutter/material.dart';
import 'package:sippichat_client/features/auth/auth_bootstrap.dart';

class SippiChatApp extends StatelessWidget {
  const SippiChatApp({super.key});

  Widget build(BuildContext context) {
    return MaterialApp(
      title: "SippiChat",
      theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
      home: const AuthBootstrap(),
    );
  }
}
