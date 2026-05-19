import 'package:flutter/material.dart';

import '../../../core/services/local_app_preferences_service.dart';
import '../../../core/widgets/settings/settings_page_shell.dart';

class DataUsageSettingsScreen extends StatefulWidget {
  const DataUsageSettingsScreen({super.key});

  @override
  State<DataUsageSettingsScreen> createState() => _DataUsageSettingsScreenState();
}

class _DataUsageSettingsScreenState extends State<DataUsageSettingsScreen> {
  bool _cellularUpload = false;
  bool _highQuality = true;
  bool _autoplayCellular = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final local = LocalAppPreferencesService.instance;
    final results = await Future.wait([
      local.getCellularUploadEnabled(),
      local.getHighQualityUploadEnabled(),
      local.getAutoplayOnCellular(),
    ]);
    if (!mounted) return;
    setState(() {
      _cellularUpload = results[0];
      _highQuality = results[1];
      _autoplayCellular = results[2];
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SettingsPageShell(
        title: 'Data usage & media quality',
        children: [SizedBox(height: 200, child: Center(child: CircularProgressIndicator()))],
      );
    }

    final local = LocalAppPreferencesService.instance;

    return SettingsPageShell(
      title: 'Data usage & media quality',
      subtitle: 'Reduce mobile data usage or improve upload quality.',
      children: [
        SettingsGroupCard(
          children: [
            SettingsSwitchTile(
              title: 'Upload over cellular',
              subtitle: 'Allow uploads when not on Wi‑Fi',
              value: _cellularUpload,
              onChanged: (v) async {
                setState(() => _cellularUpload = v);
                await local.setCellularUploadEnabled(v);
              },
            ),
            SettingsSwitchTile(
              title: 'High quality uploads',
              subtitle: 'Use higher resolution for photos and videos',
              value: _highQuality,
              onChanged: (v) async {
                setState(() => _highQuality = v);
                await local.setHighQualityUploadEnabled(v);
              },
            ),
            SettingsSwitchTile(
              title: 'Autoplay on cellular',
              subtitle: 'Auto-play reels and previews on mobile data',
              value: _autoplayCellular,
              onChanged: (v) async {
                setState(() => _autoplayCellular = v);
                await local.setAutoplayOnCellular(v);
              },
            ),
          ],
        ),
      ],
    );
  }
}
