import 'package:flutter/material.dart';

import '../../../core/models/user_app_preferences.dart';
import '../../../core/widgets/settings/settings_page_shell.dart';
import 'audience_picker_sheet.dart';
import 'user_preferences_page_mixin.dart';

class MessagesStoryRepliesScreen extends StatefulWidget {
  const MessagesStoryRepliesScreen({super.key});

  @override
  State<MessagesStoryRepliesScreen> createState() =>
      _MessagesStoryRepliesScreenState();
}

class _MessagesStoryRepliesScreenState extends State<MessagesStoryRepliesScreen>
    with UserPreferencesPageMixin {
  Future<void> _pickMessageAudience() async {
    final picked = await showAudiencePickerSheet(
      context,
      title: 'Who can message you',
      currentValue: prefs.messageRequests,
    );
    if (picked == null) return;
    await patchUserPreferences((p) => p.copyWith(messageRequests: picked));
  }

  Future<void> _pickStoryReplies() async {
    final picked = await showAudiencePickerSheet(
      context,
      title: 'Who can reply to your stories',
      currentValue: prefs.storyReplies,
    );
    if (picked == null) return;
    await patchUserPreferences((p) => p.copyWith(storyReplies: picked));
  }

  @override
  Widget build(BuildContext context) {
    if (prefsLoading) {
      return SettingsPageShell(title: 'Messages & story replies', children: [buildPrefsLoading()]);
    }

    return SettingsPageShell(
      title: 'Messages & story replies',
      subtitle: 'Choose who can contact you and reply to your stories.',
      children: [
        if (buildPrefsErrorBanner() != null) buildPrefsErrorBanner()!,
        SettingsGroupCard(
          children: [
            SettingsNavTile(
              title: 'Message requests',
              trailing: AudienceOption.labels[prefs.messageRequests],
              onTap: prefsSaving ? () {} : _pickMessageAudience,
            ),
            SettingsNavTile(
              title: 'Story replies',
              trailing: AudienceOption.labels[prefs.storyReplies],
              onTap: prefsSaving ? () {} : _pickStoryReplies,
            ),
          ],
        ),
      ],
    );
  }
}
