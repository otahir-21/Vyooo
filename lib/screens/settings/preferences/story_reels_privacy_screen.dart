import 'package:flutter/material.dart';

import '../../../core/widgets/settings/settings_page_shell.dart';
import 'user_preferences_page_mixin.dart';

class StoryReelsPrivacyScreen extends StatefulWidget {
  const StoryReelsPrivacyScreen({super.key});

  @override
  State<StoryReelsPrivacyScreen> createState() => _StoryReelsPrivacyScreenState();
}

class _StoryReelsPrivacyScreenState extends State<StoryReelsPrivacyScreen>
    with UserPreferencesPageMixin {
  @override
  Widget build(BuildContext context) {
    if (prefsLoading) {
      return SettingsPageShell(title: 'Story & reels', children: [buildPrefsLoading()]);
    }

    return SettingsPageShell(
      title: 'Story & reels',
      subtitle: 'Sharing and remix controls for stories and reels.',
      children: [
        if (buildPrefsErrorBanner() != null) buildPrefsErrorBanner()!,
        SettingsGroupCard(
          children: [
            SettingsSwitchTile(
              title: 'Allow story resharing',
              subtitle: 'Let others share your story to their story',
              value: prefs.allowStoryReshare,
              enabled: !prefsSaving,
              onChanged: (v) =>
                  patchUserPreferences((p) => p.copyWith(allowStoryReshare: v)),
            ),
            SettingsSwitchTile(
              title: 'Allow reels remix',
              subtitle: 'Let others use your audio in their reels',
              value: prefs.allowReelsRemix,
              enabled: !prefsSaving,
              onChanged: (v) =>
                  patchUserPreferences((p) => p.copyWith(allowReelsRemix: v)),
            ),
            SettingsSwitchTile(
              title: 'Hide story from close friends list',
              subtitle: 'Use close friends for exclusive story audience',
              value: false,
              enabled: false,
              onChanged: null,
            ),
          ],
        ),
      ],
    );
  }
}
