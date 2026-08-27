import 'package:flutter/material.dart';
import 'package:sippichat_client/app/app_dependencies.dart';
import 'package:sippichat_client/features/profile/model/profile.dart';

class WebProfilePage extends StatefulWidget {
  const WebProfilePage({super.key});

  @override
  State<WebProfilePage> createState() => _WebProfilePageState();
}

class _WebProfilePageState extends State<WebProfilePage> {
  final controller = AppDependencies.profileController;

  String _selectedSection = 'Profile';

  @override
  void initState() {
    super.initState();

    controller.addListener(_update);
    controller.loadProfile();
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
    return Scaffold(
      backgroundColor: const Color(0xFF0D0F11),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),

            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSidebar(),
                  Expanded(child: _buildContent()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // Header
  // ===========================================================================

  Widget _buildHeader() {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: Color(0xFF181B1F),
        border: Border(bottom: BorderSide(color: Color(0xFF30353D), width: 2)),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: Color(0xFFAAB3BE)),
          ),

          const SizedBox(width: 8),

          const Text(
            'SippiChat',
            style: TextStyle(
              color: Color(0xFFF8FAFC),
              fontSize: 21,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(width: 18),

          const Text(
            '/',
            style: TextStyle(color: Color(0xFF667085), fontSize: 20),
          ),

          const SizedBox(width: 18),

          const Text(
            'Settings',
            style: TextStyle(color: Color(0xFFB8C0CA), fontSize: 15),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Sidebar
  // ===========================================================================

  Widget _buildSidebar() {
    return Container(
      width: 240,
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 20),
      decoration: const BoxDecoration(
        color: Color(0xFF181B1F),
        border: Border(right: BorderSide(color: Color(0xFF30353D), width: 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'ACCOUNT',
              style: TextStyle(
                color: Color(0xFF8B95A3),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
          ),

          const SizedBox(height: 10),

          _buildSidebarItem(
            icon: Icons.person_outline,
            label: 'Profile',
            section: 'Profile',
          ),

          _buildSidebarItem(
            icon: Icons.palette_outlined,
            label: 'Appearance',
            section: 'Appearance',
          ),

          const SizedBox(height: 22),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'PREFERENCES',
              style: TextStyle(
                color: Color(0xFF8B95A3),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
          ),

          const SizedBox(height: 10),

          _buildSidebarItem(
            icon: Icons.notifications_none,
            label: 'Notifications',
            section: 'Notifications',
          ),

          _buildSidebarItem(
            icon: Icons.lock_outline,
            label: 'Privacy',
            section: 'Privacy',
          ),

          _buildSidebarItem(
            icon: Icons.security_outlined,
            label: 'Security',
            section: 'Security',
          ),

          const Spacer(),

          const Divider(color: Color(0xFF30353D), height: 1),

          const SizedBox(height: 14),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'SippiChat',
              style: TextStyle(color: Color(0xFF667085), fontSize: 12),
            ),
          ),

          const SizedBox(height: 4),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'Account settings',
              style: TextStyle(color: Color(0xFF667085), fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem({
    required IconData icon,
    required String label,
    required String section,
  }) {
    final selected = _selectedSection == section;

    return InkWell(
      borderRadius: BorderRadius.circular(7),
      onTap: () {
        setState(() {
          _selectedSection = section;
        });
      },
      child: Container(
        height: 42,
        margin: const EdgeInsets.only(bottom: 3),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF292F38) : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 19,
              color: selected
                  ? const Color(0xFFF8FAFC)
                  : const Color(0xFF8B95A3),
            ),

            const SizedBox(width: 11),

            Text(
              label,
              style: TextStyle(
                color: selected
                    ? const Color(0xFFF8FAFC)
                    : const Color(0xFFB8C0CA),
                fontSize: 14,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // Content
  // ===========================================================================

  Widget _buildContent() {
    return Container(
      color: const Color(0xFF0D0F11),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 36),
            child: _buildSelectedSection(),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedSection() {
    switch (_selectedSection) {
      case 'Profile':
        return _buildProfile();

      case 'Appearance':
        return _buildPlaceholder(
          Icons.palette_outlined,
          'Appearance',
          'Appearance settings will be available here.',
        );

      case 'Notifications':
        return _buildPlaceholder(
          Icons.notifications_none,
          'Notifications',
          'Notification preferences will be available here.',
        );

      case 'Privacy':
        return _buildPlaceholder(
          Icons.lock_outline,
          'Privacy',
          'Privacy settings will be available here.',
        );

      case 'Security':
        return _buildPlaceholder(
          Icons.security_outlined,
          'Security',
          'Security settings will be available here.',
        );

      default:
        return _buildProfile();
    }
  }

  // ===========================================================================
  // Profile
  // ===========================================================================

  Widget _buildProfile() {
    final profile = controller.profile;

    if (controller.loading && profile == null) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF8FB8FF)),
      );
    }

    if (profile == null) {
      return _buildPlaceholder(
        Icons.person_outline,
        'Profile',
        'Unable to load your profile.',
      );
    }

    return _ProfileContent(
      profile: profile,
      onSaved: () {
        controller.loadProfile();
      },
    );
  }

  // ===========================================================================
  // Placeholder
  // ===========================================================================

  Widget _buildPlaceholder(IconData icon, String title, String description) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFF181B1F),
        border: Border.all(color: const Color(0xFF30353D), width: 2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 28, color: const Color(0xFF8FB8FF)),

          const SizedBox(height: 18),

          Text(
            title,
            style: const TextStyle(
              color: Color(0xFFF8FAFC),
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            description,
            style: const TextStyle(color: Color(0xFFB8C0CA), fontSize: 14),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Profile content
// =============================================================================

class _ProfileContent extends StatefulWidget {
  final Profile profile;
  final VoidCallback onSaved;

  const _ProfileContent({required this.profile, required this.onSaved});

  @override
  State<_ProfileContent> createState() => _ProfileContentState();
}

class _ProfileContentState extends State<_ProfileContent> {
  late final TextEditingController _displayNameController;
  late final TextEditingController _bioController;

  bool _editing = false;
  bool _saving = false;

  final controller = AppDependencies.profileController;

  @override
  void initState() {
    super.initState();

    _displayNameController = TextEditingController(
      text: widget.profile.displayName,
    );

    _bioController = TextEditingController(text: widget.profile.bio ?? '');
  }

  @override
  void didUpdateWidget(covariant _ProfileContent oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!_editing && oldWidget.profile != widget.profile) {
      _displayNameController.text = widget.profile.displayName;
      _bioController.text = widget.profile.bio ?? '';
    }
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();

    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
    });

    try {
      await controller.updateProfile(
        displayName: _displayNameController.text.trim(),
        bio: _bioController.text.trim(),
      );

      if (!mounted) return;

      setState(() {
        _editing = false;
      });

      widget.onSaved();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile updated')));
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update profile: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  void _cancel() {
    setState(() {
      _displayNameController.text = widget.profile.displayName;
      _bioController.text = widget.profile.bio ?? '';
      _editing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Profile',
            style: TextStyle(
              color: Color(0xFFF8FAFC),
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            'Manage your public profile information.',
            style: TextStyle(color: Color(0xFFB8C0CA), fontSize: 14),
          ),

          const SizedBox(height: 30),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: const Color(0xFF181B1F),
              border: Border.all(color: const Color(0xFF30353D), width: 2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: const Color(0xFF292D33),
                      backgroundImage: profile.avatarUrl != null
                          ? NetworkImage(profile.avatarUrl!)
                          : null,
                      child: profile.avatarUrl == null
                          ? const Icon(
                              Icons.person,
                              size: 34,
                              color: Color(0xFFAAB3BE),
                            )
                          : null,
                    ),

                    const SizedBox(width: 18),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.displayName.isNotEmpty
                                ? profile.displayName
                                : profile.username,
                            style: const TextStyle(
                              color: Color(0xFFF8FAFC),
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),

                          const SizedBox(height: 4),

                          Text(
                            '@${profile.username}',
                            style: const TextStyle(
                              color: Color(0xFF8B95A3),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 30),

                const Divider(color: Color(0xFF30353D), height: 1),

                const SizedBox(height: 26),

                _buildField(
                  label: 'Display name',
                  child: TextField(
                    controller: _displayNameController,
                    enabled: _editing && !_saving,
                    style: const TextStyle(
                      color: Color(0xFFF8FAFC),
                      fontSize: 14,
                    ),
                    decoration: _inputDecoration(),
                  ),
                ),

                const SizedBox(height: 22),

                _buildField(
                  label: 'Username',
                  child: TextField(
                    enabled: false,
                    controller: TextEditingController(text: profile.username),
                    style: const TextStyle(
                      color: Color(0xFF8B95A3),
                      fontSize: 14,
                    ),
                    decoration: _inputDecoration(
                      hint: 'Username cannot be changed here',
                    ),
                  ),
                ),

                const SizedBox(height: 22),

                _buildField(
                  label: 'Bio',
                  child: TextField(
                    controller: _bioController,
                    enabled: _editing && !_saving,
                    maxLines: 4,
                    style: const TextStyle(
                      color: Color(0xFFF8FAFC),
                      fontSize: 14,
                    ),
                    decoration: _inputDecoration(
                      hint: 'Tell people something about yourself...',
                    ),
                  ),
                ),

                const SizedBox(height: 26),

                if (_editing)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: _saving ? null : _cancel,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFB8C0CA),
                          side: const BorderSide(color: Color(0xFF3A414A)),
                        ),
                        child: const Text('Cancel'),
                      ),

                      const SizedBox(width: 10),

                      FilledButton(
                        onPressed: _saving ? null : _save,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF4D7CFE),
                          foregroundColor: Colors.white,
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Save changes'),
                      ),
                    ],
                  )
                else
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: () {
                        setState(() {
                          _editing = true;
                        });
                      },
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Edit profile'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF292F38),
                        foregroundColor: const Color(0xFFF8FAFC),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          Text(
            'Member since ${_formatDate(profile.createdAt)}',
            style: const TextStyle(color: Color(0xFF667085), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildField({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFFB8C0CA),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),

        const SizedBox(height: 7),

        child,
      ],
    );
  }

  InputDecoration _inputDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF667085), fontSize: 13),
      filled: true,
      fillColor: const Color(0xFF0D0F11),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(7),
        borderSide: const BorderSide(color: Color(0xFF30353D)),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(7),
        borderSide: const BorderSide(color: Color(0xFF30353D)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(7),
        borderSide: const BorderSide(color: Color(0xFF667085), width: 2),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();

    return '${local.day.toString().padLeft(2, '0')}.'
        '${local.month.toString().padLeft(2, '0')}.'
        '${local.year}';
  }
}
