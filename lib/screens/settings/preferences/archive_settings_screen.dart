import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/settings/settings_page_shell.dart';
import '../saved_posts_screen.dart';
import 'user_preferences_page_mixin.dart';

class ArchiveSettingsScreen extends StatefulWidget {
  const ArchiveSettingsScreen({super.key});

  @override
  State<ArchiveSettingsScreen> createState() => _ArchiveSettingsScreenState();
}

class _ArchiveSettingsScreenState extends State<ArchiveSettingsScreen>
    with UserPreferencesPageMixin {
  @override
  Widget build(BuildContext context) {
    if (prefsLoading) {
      return const SettingsPageShell(
        title: 'Archive',
        children: [SizedBox(height: 200, child: Center(child: CircularProgressIndicator()))],
      );
    }

    return SettingsPageShell(
      title: 'Archive',
      subtitle:
          'Manage archived stories and posts. Archived content is only visible to you unless you restore it.',
      children: [
        if (buildPrefsErrorBanner() != null) buildPrefsErrorBanner()!,
        SettingsGroupCard(
          children: [
            SettingsSwitchTile(
              title: 'Auto-archive stories',
              subtitle: 'Remove stories from your profile after 24 hours',
              value: prefs.autoArchiveStories,
              enabled: !prefsSaving,
              onChanged: (v) => patchUserPreferences((p) => p.copyWith(autoArchiveStories: v)),
            ),
            SettingsSwitchTile(
              title: 'Save story to archive',
              subtitle: 'Keep a copy in archive when a story expires',
              value: prefs.saveStoryToArchive,
              enabled: !prefsSaving,
              onChanged: (v) => patchUserPreferences((p) => p.copyWith(saveStoryToArchive: v)),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        SettingsGroupCard(
          children: [
            SettingsNavTile(
              title: 'Saved posts',
              subtitle: 'View posts you saved privately',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SavedPostsScreen()),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
