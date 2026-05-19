import 'package:flutter/material.dart';

import '../../../core/models/user_app_preferences.dart';
import '../../../core/widgets/settings/settings_page_shell.dart';
import 'audience_picker_sheet.dart';
import 'user_preferences_page_mixin.dart';

class CommentsPrivacyScreen extends StatefulWidget {
  const CommentsPrivacyScreen({super.key});

  @override
  State<CommentsPrivacyScreen> createState() => _CommentsPrivacyScreenState();
}

class _CommentsPrivacyScreenState extends State<CommentsPrivacyScreen>
    with UserPreferencesPageMixin {
  Future<void> _pickComments() async {
    final picked = await showAudiencePickerSheet(
      context,
      title: 'Who can comment',
      currentValue: prefs.allowCommentsFrom,
    );
    if (picked == null) return;
    await patchUserPreferences((p) => p.copyWith(allowCommentsFrom: picked));
  }

  @override
  Widget build(BuildContext context) {
    if (prefsLoading) {
      return SettingsPageShell(title: 'Comments', children: [buildPrefsLoading()]);
    }

    return SettingsPageShell(
      title: 'Comments',
      subtitle: 'Manage who can comment on your posts and reels.',
      children: [
        if (buildPrefsErrorBanner() != null) buildPrefsErrorBanner()!,
        SettingsGroupCard(
          children: [
            SettingsNavTile(
              title: 'Allow comments from',
              trailing: AudienceOption.labels[prefs.allowCommentsFrom],
              onTap: prefsSaving ? () {} : _pickComments,
            ),
            SettingsSwitchTile(
              title: 'Filter offensive comments',
              subtitle: 'Hide comments that may be spam or harassment',
              value: prefs.filterOffensiveComments,
              enabled: !prefsSaving,
              onChanged: (v) =>
                  patchUserPreferences((p) => p.copyWith(filterOffensiveComments: v)),
            ),
          ],
        ),
      ],
    );
  }
}
