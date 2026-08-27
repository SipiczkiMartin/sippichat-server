import 'package:flutter/material.dart';
import 'package:sippichat_client/app/app_dependencies.dart';
import 'package:sippichat_client/features/conversations/models/conversation.dart';

class WebNavigation extends StatefulWidget {
  final String? selectedConversationId;
  final ValueChanged<Conversation> onConversationSelected;

  const WebNavigation({
    super.key,
    required this.selectedConversationId,
    required this.onConversationSelected,
  });

  @override
  State<WebNavigation> createState() => _WebNavigationState();
}

class _WebNavigationState extends State<WebNavigation> {
  final controller = AppDependencies.conversationController;

  @override
  void initState() {
    super.initState();

    controller.addListener(_update);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.loadConversations();
    });
  }

  void _update() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    controller.removeListener(_update);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: const Color(0xFF181B1F),
        border: Border.all(color: const Color(0xFF30353D), width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                Text(
                  'INBOX',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: Color(0xFF8B929B),
                  ),
                ),
                Spacer(),
                Icon(Icons.more_horiz, size: 20, color: Color(0xFF8B929B)),
              ],
            ),
          ),

          const SizedBox(height: 10),

          const _NavigationItem(
            icon: Icons.mail_outline,
            label: 'All',
            selected: true,
          ),

          const _NavigationItem(icon: Icons.circle_outlined, label: 'Unread'),

          const _NavigationItem(icon: Icons.star_border, label: 'Favorites'),

          const SizedBox(height: 22),

          const _SectionTitle('FOLDERS'),

          const SizedBox(height: 10),

          const _NavigationItem(icon: Icons.person_outline, label: 'Direct'),

          const _NavigationItem(icon: Icons.groups_outlined, label: 'Groups'),

          const _NavigationItem(
            icon: Icons.notifications_none,
            label: 'Requests',
          ),

          const _NavigationItem(icon: Icons.attach_file, label: 'Shared files'),

          const SizedBox(height: 22),

          const _SectionTitle('CONVERSATIONS'),

          const SizedBox(height: 10),

          Expanded(child: _buildConversations()),
        ],
      ),
    );
  }

  Widget _buildConversations() {
    if (controller.loading && controller.conversations.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (controller.error != null && controller.conversations.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          controller.error!,
          style: const TextStyle(color: Colors.red, fontSize: 13),
        ),
      );
    }

    if (controller.conversations.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'No conversations yet',
          style: TextStyle(color: Color(0xFF8B929B), fontSize: 13),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: controller.conversations.length,
      itemBuilder: (context, index) {
        final conversation = controller.conversations[index];

        return _ConversationItem(
          conversation: conversation,
          selected: conversation.id == widget.selectedConversationId,
          onTap: () {
            widget.onConversationSelected(conversation);
          },
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: Color(0xFF8B929B),
        ),
      ),
    );
  }
}

class _NavigationItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;

  const _NavigationItem({
    required this.icon,
    required this.label,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF252A31) : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 19,
            color: selected ? const Color(0xFFF1F3F5) : const Color(0xFF8B929B),
          ),
          const SizedBox(width: 11),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected
                  ? const Color(0xFFF1F3F5)
                  : const Color(0xFFB8BEC7),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConversationItem extends StatelessWidget {
  final Conversation conversation;
  final bool selected;
  final VoidCallback onTap;

  const _ConversationItem({
    required this.conversation,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final participant = conversation.participant;

    final name = participant?.displayName ?? participant?.username ?? 'Unknown';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        height: 48,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF252A31) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 16,
              backgroundColor: Color(0xFF292D33),
              child: Icon(Icons.person, size: 18, color: Color(0xFF8B929B)),
            ),

            const SizedBox(width: 10),

            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  color: selected
                      ? const Color(0xFFF1F3F5)
                      : const Color(0xFFB8BEC7),
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
