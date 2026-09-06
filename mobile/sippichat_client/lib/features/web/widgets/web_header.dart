import 'package:flutter/material.dart';
import 'package:sippichat_client/app/app_dependencies.dart';
import 'package:sippichat_client/features/conversations/models/conversation.dart';
import 'package:sippichat_client/features/users/models/user_search_result.dart';

import '../../profile/web/web_profile_page.dart';

class WebHeader extends StatefulWidget {
  final ValueChanged<Conversation> onConversationSelected;

  const WebHeader({super.key, required this.onConversationSelected});

  @override
  State<WebHeader> createState() => _WebHeaderState();
}

class _WebHeaderState extends State<WebHeader> {
  final searchController = AppDependencies.userSearchController;
  final conversationController = AppDependencies.conversationController;
  final authController = AppDependencies.authController;

  final TextEditingController _searchTextController = TextEditingController();

  final LayerLink _searchLayerLink = LayerLink();

  OverlayEntry? _searchOverlay;

  bool _openingConversation = false;

  static const Color background = Color(0xFF181B1F);
  static const Color inputBackground = Color(0xFF0D0F11);
  static const Color border = Color(0xFF30353D);

  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFFB8C0CA);
  static const Color iconColor = Color(0xFFAAB3BE);

  @override
  void initState() {
    super.initState();

    searchController.addListener(_onSearchControllerChanged);
  }

  // ===========================================================================
  // Search controller updates
  // ===========================================================================

  void _onSearchControllerChanged() {
    if (!mounted) {
      return;
    }

    setState(() {});

    if (searchController.query.length >= 2) {
      _showSearchOverlay();
    } else {
      _hideSearchOverlay();
    }
  }

  void _onSearchChanged(String value) {
    final query = value.trim();

    searchController.search(query);

    if (query.length >= 2) {
      _showSearchOverlay();
    } else {
      _hideSearchOverlay();
    }
  }

  // ===========================================================================
  // Overlay
  // ===========================================================================

  void _showSearchOverlay() {
    if (!mounted) {
      return;
    }

    if (_searchOverlay != null) {
      _searchOverlay!.markNeedsBuild();
      return;
    }

    _searchOverlay = OverlayEntry(
      builder: (context) {
        return Positioned.fill(
          child: Stack(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _hideSearchOverlay,
                child: const SizedBox.expand(),
              ),

              CompositedTransformFollower(
                link: _searchLayerLink,
                showWhenUnlinked: false,
                targetAnchor: Alignment.bottomLeft,
                followerAnchor: Alignment.topLeft,
                offset: const Offset(0, 8),
                child: SizedBox(
                  width: 320,
                  child: Material(
                    color: Colors.transparent,
                    child: _buildSearchDropdown(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    Overlay.of(context).insert(_searchOverlay!);
  }

  void _hideSearchOverlay() {
    _searchOverlay?.remove();
    _searchOverlay = null;
  }

  // ===========================================================================
  // Search actions
  // ===========================================================================

  void _clearSearch() {
    _searchTextController.clear();
    searchController.clear();

    _hideSearchOverlay();

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _openConversation(UserSearchResult user) async {
    if (_openingConversation) {
      return;
    }

    setState(() {
      _openingConversation = true;
    });

    _searchOverlay?.markNeedsBuild();

    try {
      final conversation = await conversationController.createConversation(
        user.id,
      );

      if (!mounted) {
        return;
      }

      if (conversation == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open conversation')),
        );

        return;
      }

      _searchTextController.clear();
      searchController.clear();

      _hideSearchOverlay();

      widget.onConversationSelected(conversation);
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to open conversation: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _openingConversation = false;
        });

        _searchOverlay?.markNeedsBuild();
      }
    }
  }

  // ===========================================================================
  // Dispose
  // ===========================================================================

  @override
  void dispose() {
    _hideSearchOverlay();

    searchController.removeListener(_onSearchControllerChanged);

    _searchTextController.dispose();

    searchController.clear();

    super.dispose();
  }

  // ===========================================================================
  // Build
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final user = AppDependencies.authRepository.currentUser;

    final userName = user?.email ?? 'User';

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: background,
        border: Border(bottom: BorderSide(color: border, width: 2)),
      ),
      child: Row(
        children: [
          // ===================================================================
          // Logo
          // ===================================================================
          const Text(
            'SippiChat',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w700,
              color: textPrimary,
              letterSpacing: -0.2,
            ),
          ),

          const SizedBox(width: 32),

          // ===================================================================
          // Search
          // ===================================================================
          CompositedTransformTarget(
            link: _searchLayerLink,
            child: SizedBox(
              width: 320,
              height: 38,
              child: TextField(
                controller: _searchTextController,
                style: const TextStyle(color: textPrimary, fontSize: 14),
                cursorColor: textPrimary,
                textInputAction: TextInputAction.search,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Search people...',
                  hintStyle: const TextStyle(
                    color: textSecondary,
                    fontSize: 14,
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    size: 20,
                    color: iconColor,
                  ),
                  suffixIcon: searchController.query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            Icons.close,
                            size: 18,
                            color: iconColor,
                          ),
                          onPressed: _clearSearch,
                        )
                      : null,
                  filled: true,
                  fillColor: inputBackground,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(7),
                    borderSide: const BorderSide(color: border, width: 2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(7),
                    borderSide: const BorderSide(color: border, width: 2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(7),
                    borderSide: const BorderSide(
                      color: Color(0xFF667085),
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
            ),
          ),

          const Spacer(),

          // ===================================================================
          // Account
          // ===================================================================
          PopupMenuButton<String>(
            offset: const Offset(0, 48),
            color: const Color(0xFF20242A),
            elevation: 8,
            onSelected: (value) async {
              switch (value) {
                case 'profile':
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const WebProfilePage()),
                  );
                  break;

                case 'settings':
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Settings coming soon')),
                  );
                  break;

                case 'logout':
                  await authController.logout();
                  break;
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 17,
                    backgroundColor: Color(0xFF292D33),
                    child: Icon(Icons.person, size: 19, color: iconColor),
                  ),

                  const SizedBox(width: 9),

                  Text(
                    userName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),

                  const SizedBox(width: 4),

                  const Icon(
                    Icons.keyboard_arrow_down,
                    size: 19,
                    color: iconColor,
                  ),
                ],
              ),
            ),
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'profile',
                child: Text(
                  'Profile',
                  style: TextStyle(color: textPrimary, fontSize: 14),
                ),
              ),

              PopupMenuItem(
                value: 'settings',
                child: Text(
                  'Settings',
                  style: TextStyle(color: textPrimary, fontSize: 14),
                ),
              ),

              PopupMenuDivider(),

              PopupMenuItem(
                value: 'logout',
                child: Text(
                  'Logout',
                  style: TextStyle(color: Color(0xFFFF6B6B), fontSize: 14),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Search dropdown
  // ===========================================================================

  Widget _buildSearchDropdown() {
    if (searchController.loading) {
      return _dropdownContainer(
        const Padding(
          padding: EdgeInsets.all(20),
          child: Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF8FB8FF),
              ),
            ),
          ),
        ),
      );
    }

    final results = searchController.results;

    if (results.isEmpty) {
      return _dropdownContainer(
        const Padding(
          padding: EdgeInsets.all(18),
          child: Text(
            'No users found',
            style: TextStyle(color: textSecondary, fontSize: 14),
          ),
        ),
      );
    }

    return _dropdownContainer(
      ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 360),
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 6),
          shrinkWrap: true,
          itemCount: results.length,
          separatorBuilder: (_, __) {
            return const Divider(height: 1, color: border);
          },
          itemBuilder: (context, index) {
            final user = results[index];

            return _buildSearchResult(user);
          },
        ),
      ),
    );
  }

  Widget _dropdownContainer(Widget child) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF20242A),
        border: Border.all(color: border, width: 2),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  // ===========================================================================
  // Search result
  // ===========================================================================

  Widget _buildSearchResult(UserSearchResult user) {
    return InkWell(
      onTap: _openingConversation ? null : () => _openConversation(user),
      hoverColor: const Color(0xFF292F38),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFF292D33),
              backgroundImage: user.avatarUrl != null
                  ? NetworkImage(user.avatarUrl!)
                  : null,
              child: user.avatarUrl == null
                  ? const Icon(Icons.person, size: 19, color: iconColor)
                  : null,
            ),

            const SizedBox(width: 10),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 2),

                  Text(
                    '@${user.username}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),

            if (_openingConversation)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF8FB8FF),
                ),
              )
            else
              const Icon(Icons.arrow_forward_ios, size: 13, color: iconColor),
          ],
        ),
      ),
    );
  }
}
