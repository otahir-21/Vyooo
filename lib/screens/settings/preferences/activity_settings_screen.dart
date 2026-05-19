import 'package:flutter/material.dart';

import '../../../core/widgets/settings/settings_page_shell.dart';
import 'user_preferences_page_mixin.dart';

class ActivitySettingsScreen extends StatefulWidget {
  const ActivitySettingsScreen({super.key});

  @override
  State<ActivitySettingsScreen> createState() => _ActivitySettingsScreenState();
}

class _ActivitySettingsScreenState extends State<ActivitySettingsScreen>
    with UserPreferencesPageMixin {
  @override
  Widget build(BuildContext context) {
    if (prefsLoading) return SettingsPageShell(title: 'Your activity', children: [buildPrefsLoading()]);

    return SettingsPageShell(
      title: 'Your activity',
      subtitle: 'Control what others see about your interactions on Vyooo.',
      children: [
        if (buildPrefsErrorBanner() != null) buildPrefsErrorBanner()!,
        SettingsGroupCard(
          children: [
            SettingsSwitchTile(
              title: 'Show activity status',
              subtitle: 'Let followers see when you were last active',
              value: prefs.showActivityStatus,
              enabled: !prefsSaving,
              onChanged: (v) => patchUserPreferences((p) => p.copyWith(showActivityStatus: v)),
            ),
            SettingsSwitchTile(
              title: 'Share likes to feed',
              subtitle: 'Show posts you liked in friends\' activity feeds',
              value: prefs.allowSharingLikesToFeed,
              enabled: !prefsSaving,
              onChanged: (v) =>
                  patchUserPreferences((p) => p.copyWith(allowSharingLikesToFeed: v)),
            ),
            SettingsSwitchTile(
              title: 'Save search history',
              subtitle: 'Improve recommendations from your searches',
              value: prefs.saveSearchHistory,
              enabled: !prefsSaving,
              onChanged: (v) => patchUserPreferences((p) => p.copyWith(saveSearchHistory: v)),
            ),
          ],
        ),
      ],
    );
  }
}
