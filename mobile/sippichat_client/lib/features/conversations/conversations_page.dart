import 'package:flutter/material.dart';
import 'package:sippichat_client/app/app_dependencies.dart';
import 'package:sippichat_client/features/auth/login_page.dart';
import 'package:sippichat_client/features/conversations/conversation_tile.dart';
import 'package:sippichat_client/features/profile/profile_page.dart';
import 'package:sippichat_client/features/users/models/user_search_result.dart';

import '../chat/chat_page.dart';

class ConversationsPage extends StatefulWidget {
  const ConversationsPage({super.key});

  @override
  State<ConversationsPage> createState() => _ConversationsPageState();
}

class _ConversationsPageState extends State<ConversationsPage> {
  final controller = AppDependencies.conversationController;
  final searchController = AppDependencies.userSearchController;

  final TextEditingController _searchTextController =
  TextEditingController();

  @override
  void initState() {
    super.initState();

    controller.addListener(_update);
    searchController.addListener(_update);

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
    searchController.removeListener(_update);
    _searchTextController.dispose();

    searchController.clear();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final conversations = controller.conversations;
    final searching = searchController.query.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text("SippiChat"),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: _openProfile,
          ),
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchField(),
          Expanded(
            child: searching
                ? _buildSearchResults()
                : _buildBody(conversations),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.chat),
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        controller: _searchTextController,
        onChanged: searchController.search,
        decoration: InputDecoration(
          hintText: "Search people...",
          prefixIcon: const Icon(Icons.search),
          suffixIcon: searchController.query.isNotEmpty
              ? IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              _searchTextController.clear();
              searchController.clear();
            },
          )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (searchController.loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    final results = searchController.results;

    if (results.isEmpty) {
      return const Center(
        child: Text("No users found"),
      );
    }

    return ListView.separated(
      itemCount: results.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final user = results[index];

        return _buildUserSearchTile(user);
      },
    );
  }

  Widget _buildUserSearchTile(UserSearchResult user) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: user.avatarUrl != null
            ? NetworkImage(user.avatarUrl!)
            : null,
        child: user.avatarUrl == null
            ? const Icon(Icons.person)
            : null,
      ),
      title: Text(user.displayName),
      subtitle: Text("@${user.username}"),
      onTap: () => _openConversation(user),
    );
  }

  Future _openConversation(UserSearchResult user) async {
    try {
      final conversation =
      await controller.createConversation(user.id);

      if (conversation == null) {
        return;
      }

      if (!mounted) return;

      searchController.clear();
      _searchTextController.clear();

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatPage(
            conversation: conversation,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to open conversation: $e"),
        ),
      );
    }
  }


  void _openProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ProfilePage(),
      ),
    );
  }

  Future _logout() async {
    await AppDependencies.authRepository.logout();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginPage(),
      ),
          (route) => false,
    );
  }

  Widget _buildBody(List conversations) {
    if (controller.loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (controller.error != null) {
      return Center(
        child: Text(
          controller.error!,
          style: const TextStyle(color: Colors.red),
        ),
      );
    }

    if (conversations.isEmpty) {
      return const Center(
        child: Text("No conversations yet"),
      );
    }

    return ListView.separated(
      itemCount: conversations.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final conversation = conversations[index];

        return ConversationTile(
          conversation: conversation,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChatPage(
                  conversation: conversation,
                ),
              ),
            );
          },
        );
      },
    );
  }
}