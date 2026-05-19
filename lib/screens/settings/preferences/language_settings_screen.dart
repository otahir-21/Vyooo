import 'package:flutter/material.dart';

import '../../../core/services/local_app_preferences_service.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/settings/settings_page_shell.dart';

class LanguageSettingsScreen extends StatefulWidget {
  const LanguageSettingsScreen({super.key});

  @override
  State<LanguageSettingsScreen> createState() => _LanguageSettingsScreenState();
}

class _LanguageSettingsScreenState extends State<LanguageSettingsScreen> {
  String _selected = LocalAppPreferencesService.defaultLanguage;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final code = await LocalAppPreferencesService.instance.getLanguageCode();
    if (!mounted) return;
    setState(() {
      _selected = code;
      _loading = false;
    });
  }

  Future<void> _select(String code) async {
    setState(() => _selected = code);
    await LocalAppPreferencesService.instance.setLanguageCode(code);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Language saved. App restart may be required for full UI.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SettingsPageShell(
        title: 'Language',
        children: [SizedBox(height: 200, child: Center(child: CircularProgressIndicator()))],
      );
    }

    final entries = LocalAppPreferencesService.supportedLanguages.entries.toList();

    return SettingsPageShell(
      title: 'Language',
      subtitle: 'Choose your preferred language for Vyooo.',
      children: [
        SettingsGroupCard(
          children: [
            for (var i = 0; i < entries.length; i++)
              ListTile(
                title: Text(
                  entries[i].value,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
                trailing: _selected == entries[i].key
                    ? const Icon(Icons.check_rounded, color: Color(0xFFF81945))
                    : null,
                onTap: () => _select(entries[i].key),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'More languages will be added in future updates.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}
