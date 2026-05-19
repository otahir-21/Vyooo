import 'package:flutter/material.dart';

import '../../../core/models/user_app_preferences.dart';
import '../../../core/services/user_app_preferences_service.dart';

/// Loads/saves [UserAppPreferences] for settings sub-screens.
mixin UserPreferencesPageMixin<T extends StatefulWidget> on State<T> {
  UserAppPreferences prefs = const UserAppPreferences();
  bool prefsLoading = true;
  bool prefsSaving = false;
  String? prefsError;

  @override
  void initState() {
    super.initState();
    loadUserPreferences();
  }

  Future<void> loadUserPreferences() async {
    setState(() {
      prefsLoading = true;
      prefsError = null;
    });
    try {
      final loaded =
          await UserAppPreferencesService.instance.getForCurrentUser();
      if (!mounted) return;
      setState(() {
        prefs = loaded;
        prefsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        prefsLoading = false;
        prefsError = 'Could not load settings. Pull to retry.';
      });
    }
  }

  Future<void> patchUserPreferences(
    UserAppPreferences Function(UserAppPreferences current) update,
  ) async {
    final next = update(prefs);
    setState(() {
      prefs = next;
      prefsSaving = true;
      prefsError = null;
    });
    try {
      await UserAppPreferencesService.instance.save(next);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        prefsError = 'Could not save. Try again.';
      });
      await loadUserPreferences();
    } finally {
      if (mounted) setState(() => prefsSaving = false);
    }
  }

  Widget buildPrefsLoading() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: CircularProgressIndicator(color: Color(0xFFF81945)),
      ),
    );
  }

  Widget? buildPrefsErrorBanner() {
    if (prefsError == null) return null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        prefsError!,
        style: TextStyle(color: Colors.red.shade300, fontSize: 13),
      ),
    );
  }
}
