import 'package:flutter/material.dart';
import 'package:sippichat_client/features/conversations/models/conversation.dart';

import 'widgets/web_header.dart';
import 'widgets/web_navigation.dart';
import 'widgets/web_workspace.dart';

class WebShell extends StatefulWidget {
  const WebShell({super.key});

  @override
  State<WebShell> createState() => _WebShellState();
}

class _WebShellState extends State<WebShell> {
  Conversation? selectedConversation;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0F11),
      body: SafeArea(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // =================================================================
            // Main application
            // =================================================================
            Column(
              children: [
                const SizedBox(height: 64),

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        WebNavigation(
                          selectedConversationId: selectedConversation?.id,
                          onConversationSelected: (conversation) {
                            setState(() {
                              selectedConversation = conversation;
                            });
                          },
                        ),

                        const SizedBox(width: 10),

                        Expanded(
                          child: WebWorkspace(
                            selectedConversation: selectedConversation,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // =================================================================
            // Header
            //
            // This is LAST in the Stack, therefore it paints ABOVE the
            // navigation/workspace.
            // =================================================================
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: WebHeader(
                onConversationSelected: (conversation) {
                  setState(() {
                    selectedConversation = conversation;
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
