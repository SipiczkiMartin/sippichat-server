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
    final width = MediaQuery.sizeOf(context).width;
    final isMobileWeb = width < 700;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0F11),
      body: SafeArea(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              children: [
                SizedBox(height: isMobileWeb ? 56 : 64),

                Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(isMobileWeb ? 0 : 10),
                    child: isMobileWeb
                        ? _buildMobileLayout()
                        : _buildDesktopLayout(),
                  ),
                ),
              ],
            ),

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

  Widget _buildDesktopLayout() {
    return Row(
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
            onClose: () {
              setState(() {
                selectedConversation = null;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    if (selectedConversation == null) {
      return WebNavigation(
        selectedConversationId: null,
        onConversationSelected: (conversation) {
          setState(() {
            selectedConversation = conversation;
          });
        },
      );
    }

    return WebWorkspace(
      selectedConversation: selectedConversation,
      onClose: () {
        setState(() {
          selectedConversation = null;
        });
      },
    );
  }
}
