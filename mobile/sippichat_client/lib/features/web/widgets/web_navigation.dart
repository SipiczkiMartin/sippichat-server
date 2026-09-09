import 'package:flutter/material.dart';
import 'package:sippichat_client/app/app_dependencies.dart';
import 'package:sippichat_client/features/conversations/models/conversation.dart';

import '../../users/models/user_search_result.dart';

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
  final searchController = AppDependencies.userSearchController;

  final TextEditingController _searchTextController = TextEditingController();

  @override
  void initState() {
    super.initState();

    controller.addListener(_update);
    searchController.addListener(_update);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await controller.loadConversations();
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
    searchController.removeListener(_update);
    _searchTextController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    final query = value.trim();

    searchController.search(query);
  }

  void _clearSearch() {
    _searchTextController.clear();
    searchController.clear();
  }

  Future<void> _openSearchResult(UserSearchResult user) async {
    final conversation = await controller.createConversation(user.id);

    if (!mounted || conversation == null) {
      return;
    }

    _clearSearch();

    widget.onConversationSelected(conversation);
  }

  @override
  Widget build(BuildContext context) {
    final isMobileWeb = MediaQuery.sizeOf(context).width < 700;

    if (isMobileWeb) {
      return Container(
        width: double.infinity,
        decoration: const BoxDecoration(color: Color(0xFF181B1F)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 12, 18, 10),
              child: Text(
                'CONVERSATIONS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: Color(0xFF8B929B),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                height: 40,
                child: TextField(
                  controller: _searchTextController,
                  style: const TextStyle(
                    color: Color(0xFFF8FAFC),
                    fontSize: 14,
                  ),
                  cursorColor: const Color(0xFFF8FAFC),
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Search people...',
                    hintStyle: const TextStyle(
                      color: Color(0xFF8B929B),
                      fontSize: 14,
                    ),
                    prefixIcon: const Icon(
                      Icons.search,
                      size: 19,
                      color: Color(0xFFAAB3BE),
                    ),
                    suffixIcon: searchController.query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              Icons.close,
                              size: 18,
                              color: Color(0xFFAAB3BE),
                            ),
                            onPressed: _clearSearch,
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFF0D0F11),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(7),
                      borderSide: const BorderSide(
                        color: Color(0xFF30353D),
                        width: 2,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(7),
                      borderSide: const BorderSide(
                        color: Color(0xFF30353D),
                        width: 2,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(7),
                      borderSide: const BorderSide(
                        color: Color(0xFF667085),
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            Expanded(
              child: searchController.query.trim().length >= 2
                  ? _buildMobileSearchResults()
                  : _buildConversations(),
            ),
          ],
        ),
      );
    }

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

  Widget _buildMobileSearchResults() {
    if (searchController.loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF8FB8FF)),
      );
    }

    final results = searchController.results;

    if (results.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'No users found',
          style: TextStyle(color: Color(0xFF8B929B), fontSize: 13),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 4),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final user = results[index];

        return InkWell(
          onTap: () => _openSearchResult(user),
          child: Container(
            height: 56,
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(6)),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFF292D33),
                  backgroundImage: user.avatarUrl != null
                      ? NetworkImage(user.avatarUrl!)
                      : null,
                  child: user.avatarUrl == null
                      ? const Icon(
                          Icons.person,
                          size: 19,
                          color: Color(0xFFAAB3BE),
                        )
                      : null,
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFF8FAFC),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      const SizedBox(height: 2),

                      Text(
                        '@${user.username}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF8B929B),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                const Icon(
                  Icons.arrow_forward_ios,
                  size: 13,
                  color: Color(0xFFAAB3BE),
                ),
              ],
            ),
          ),
        );
      },
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
          hasUnread: controller.hasUnreadMessages(conversation.id),
          unreadCount: controller.unreadCountFor(conversation.id),
          onTap: () {
            controller.setActiveConversation(conversation.id);
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
  final int unreadCount;
  final bool hasUnread;

  const _ConversationItem({
    required this.conversation,
    required this.selected,
    required this.onTap,
    required this.unreadCount,
    required this.hasUnread,
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
          color: selected
              ? const Color(0xFF252A31)
              : hasUnread
              ? const Color(0xFF20242A)
              : Colors.transparent,
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
                      : hasUnread
                      ? const Color(0xFFF1F3F5)
                      : const Color(0xFFB8BEC7),
                  fontWeight: selected || hasUnread
                      ? FontWeight.w600
                      : FontWeight.w400,
                ),
              ),
            ),

            if (hasUnread) ...[
              const SizedBox(width: 8),
              Container(
                constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B929B),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  unreadCount > 99 ? '99+' : unreadCount.toString(),
                  style: const TextStyle(
                    color: Color(0xFF0D0F11),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
