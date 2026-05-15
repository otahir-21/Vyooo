import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/models/notification_preferences.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/notification_preferences_service.dart';
import '../../core/services/push_messaging_service.dart';
import '../../core/widgets/app_gradient_background.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  NotificationPreferences _prefs = const NotificationPreferences();
  bool _loading = true;
  bool _saving = false;
  String? _error;
  bool _osPermissionGranted = true;
  Timer? _saveDebounce;
  StreamSubscription<NotificationPreferences>? _prefsSub;

  @override
  void initState() {
    super.initState();
    unawaited(_refreshOsPermission());
    _prefsSub =
        NotificationPreferencesService.instance.watchForCurrentUser().listen(
      (prefs) {
        if (!mounted) return;
        setState(() {
          _prefs = prefs;
          _loading = false;
        });
      },
      onError: (_) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'Could not load notification settings.';
        });
      },
    );
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _prefsSub?.cancel();
    super.dispose();
  }

  Future<void> _refreshOsPermission() async {
    if (kIsWeb) return;
    var granted = true;
    if (defaultTargetPlatform == TargetPlatform.android) {
      granted = await Permission.notification.isGranted;
    } else if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      final settings = await FirebaseMessaging.instance.getNotificationSettings();
      granted = settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    }
    if (!mounted) return;
    setState(() => _osPermissionGranted = granted);
  }

  void _scheduleSave(NotificationPreferences next) {
    setState(() {
      _prefs = next;
      _error = null;
    });
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 400), () {
      unawaited(_persist(next));
    });
  }

  Future<void> _persist(NotificationPreferences next) async {
    setState(() => _saving = true);
    try {
      await NotificationPreferencesService.instance.save(next);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not save. Try again.';
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _onMasterChanged(bool enabled) async {
    if (enabled) {
      final uid = AuthService().currentUser?.uid ?? '';
      if (uid.isNotEmpty) {
        await PushMessagingService.instance.syncTokenForUser(uid);
      }
      await _refreshOsPermission();
      if (!_osPermissionGranted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Enable notifications in system Settings to receive alerts.',
            ),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: openAppSettings,
            ),
          ),
        );
      }
    }
    _scheduleSave(_prefs.copyWith(pushEnabled: enabled));
  }

  Future<void> _openSystemSettings() async {
    await openAppSettings();
    await Future<void>.delayed(const Duration(milliseconds: 500));
    await _refreshOsPermission();
  }

  bool get _categoriesEnabled => _prefs.pushEnabled;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppGradientBackground(
        type: GradientType.premiumDark,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildAppBar(context),
            if (_loading)
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFFF81945),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 24,
                  ),
                  children: [
                    if (!_osPermissionGranted) ...[
                      _PermissionBanner(onOpenSettings: _openSystemSettings),
                      const SizedBox(height: 16),
                    ],
                    if (_error != null) ...[
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Colors.red.shade300,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    const Text(
                      'Push Notifications',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Column(
                        children: [
                          _NotificationSwitch(
                            title: 'Push notifications',
                            subtitle:
                                'Allow Vyooo to send alerts to this device',
                            value: _prefs.pushEnabled,
                            enabled: !_saving,
                            onChanged: _saving ? null : _onMasterChanged,
                          ),
                          _divider(),
                          _NotificationSwitch(
                            title: 'Activity',
                            subtitle:
                                'Likes, comments, and interactions on your content',
                            value: _prefs.activity,
                            enabled: _categoriesEnabled && !_saving,
                            onChanged: _categoriesEnabled && !_saving
                                ? (v) => _scheduleSave(
                                      _prefs.copyWith(activity: v),
                                    )
                                : null,
                          ),
                          _divider(),
                          _NotificationSwitch(
                            title: 'Post',
                            subtitle:
                                'When someone you follow publishes new content',
                            value: _prefs.postsFromFollowing,
                            enabled: _categoriesEnabled && !_saving,
                            onChanged: _categoriesEnabled && !_saving
                                ? (v) => _scheduleSave(
                                      _prefs.copyWith(
                                        postsFromFollowing: v,
                                      ),
                                    )
                                : null,
                          ),
                          _divider(),
                          _NotificationSwitch(
                            title: 'Live',
                            subtitle:
                                'When creators you follow start a live stream',
                            value: _prefs.live,
                            enabled: _categoriesEnabled && !_saving,
                            onChanged: _categoriesEnabled && !_saving
                                ? (v) => _scheduleSave(
                                      _prefs.copyWith(live: v),
                                    )
                                : null,
                          ),
                          _divider(),
                          _NotificationSwitch(
                            title: 'Subscriptions',
                            subtitle:
                                'New subscriptions, renewals, and cancellations',
                            value: _prefs.subscriptions,
                            enabled: _categoriesEnabled && !_saving,
                            onChanged: _categoriesEnabled && !_saving
                                ? (v) => _scheduleSave(
                                      _prefs.copyWith(subscriptions: v),
                                    )
                                : null,
                          ),
                          _divider(),
                          _NotificationSwitch(
                            title: 'Recommended Content',
                            subtitle:
                                'When content matching your interests is posted',
                            value: _prefs.recommended,
                            enabled: _categoriesEnabled && !_saving,
                            onChanged: _categoriesEnabled && !_saving
                                ? (v) => _scheduleSave(
                                      _prefs.copyWith(recommended: v),
                                    )
                                : null,
                          ),
                        ],
                      ),
                    ),
                    if (_saving) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Saving…',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                SizedBox(width: 16),
                Text(
                  'Notifications',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          const Text(
            'VyooO',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Divider(
      height: 24,
      thickness: 1,
      color: Colors.white.withValues(alpha: 0.1),
    );
  }
}

class _PermissionBanner extends StatelessWidget {
  const _PermissionBanner({required this.onOpenSettings});

  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF81945).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFF81945).withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.notifications_off_outlined,
              color: Color(0xFFF81945), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Notifications are off in system Settings',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Turn them on to receive push alerts from Vyooo.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: onOpenSettings,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Open Settings',
                    style: TextStyle(
                      color: Color(0xFFF81945),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationSwitch extends StatelessWidget {
  const _NotificationSwitch({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Switch.adaptive(
            value: value,
            onChanged: enabled ? onChanged : null,
            activeThumbColor: const Color(0xFFF81945),
            activeTrackColor: const Color(0xFFF81945).withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }
}
