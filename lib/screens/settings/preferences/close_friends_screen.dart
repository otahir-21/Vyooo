import 'package:flutter/material.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/services/user_service.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/settings/settings_page_shell.dart';
import 'user_preferences_page_mixin.dart';

class CloseFriendsScreen extends StatefulWidget {
  const CloseFriendsScreen({super.key});

  @override
  State<CloseFriendsScreen> createState() => _CloseFriendsScreenState();
}

class _CloseFriendsScreenState extends State<CloseFriendsScreen>
    with UserPreferencesPageMixin {
  final Map<String, String> _usernamesById = {};
  final _usernameController = TextEditingController();

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _resolveUsernames(List<String> ids) async {
    final svc = UserService();
    for (final id in ids) {
      if (_usernamesById.containsKey(id)) continue;
      final user = await svc.getUser(id);
      if (!mounted) return;
      if (user?.username != null && user!.username!.trim().isNotEmpty) {
        setState(() => _usernamesById[id] = user.username!.trim());
      }
    }
  }

  @override
  Future<void> loadUserPreferences() async {
    await super.loadUserPreferences();
    await _resolveUsernames(prefs.closeFriendIds);
  }

  Future<void> _addCloseFriend() async {
    final raw = _usernameController.text.trim();
    if (raw.isEmpty) return;
    final me = AuthService().currentUser?.uid ?? '';
    if (me.isEmpty) return;

    final user = await UserService().getUserByUsername(raw);
    if (!mounted) return;
    if (user == null || user.uid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No user found with that username.')),
      );
      return;
    }
    if (user.uid == me) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You cannot add yourself.')),
      );
      return;
    }
    if (prefs.closeFriendIds.contains(user.uid)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Already in close friends.')),
      );
      return;
    }
    if (prefs.closeFriendIds.length >= 50) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Close friends list is full (50 max).')),
      );
      return;
    }

    final next = [...prefs.closeFriendIds, user.uid];
    _usernameController.clear();
    await patchUserPreferences((p) => p.copyWith(closeFriendIds: next));
    if (user.username != null) {
      setState(() => _usernamesById[user.uid] = user.username!.trim());
    }
  }

  Future<void> _remove(String uid) async {
    final next = prefs.closeFriendIds.where((id) => id != uid).toList();
    await patchUserPreferences((p) => p.copyWith(closeFriendIds: next));
    setState(() => _usernamesById.remove(uid));
  }

  @override
  Widget build(BuildContext context) {
    if (prefsLoading) {
      return SettingsPageShell(title: 'Close friends', children: [buildPrefsLoading()]);
    }

    return SettingsPageShell(
      title: 'Close friends',
      subtitle:
          'Share stories with a smaller group. Add up to 50 people by username.',
      children: [
        if (buildPrefsErrorBanner() != null) buildPrefsErrorBanner()!,
        SettingsGroupCard(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _usernameController,
                      style: AppTypography.input,
                      decoration: InputDecoration(
                        hintText: 'Username',
                        hintStyle: AppTypography.inputHint,
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.08),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm + 4,
                        ),
                      ),
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _addCloseFriend(),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  IconButton.filled(
                    onPressed: prefsSaving ? null : _addCloseFriend,
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFF81945),
                    ),
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (prefs.closeFriendIds.isEmpty)
          Text(
            'No close friends yet.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
          )
        else
          SettingsGroupCard(
            children: [
              for (final id in prefs.closeFriendIds)
                ListTile(
                  title: Text(
                    _usernamesById[id] ?? id,
                    style: AppTypography.authDialogOption,
                  ),
                  trailing: IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                    onPressed: prefsSaving ? null : () => _remove(id),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
