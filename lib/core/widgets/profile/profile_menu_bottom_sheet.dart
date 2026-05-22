import 'package:flutter/material.dart';

import '../../theme/app_background_assets.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

/// Profile overflow menu (three lines) — [Comment_section] background.
Future<void> showProfileMenuBottomSheet(
  BuildContext context, {
  required VoidCallback onVr,
  required VoidCallback onVyoooCoin,
  required VoidCallback onRevenue,
  required VoidCallback onSettings,
  required VoidCallback onMusicLibrary,
  required VoidCallback onUploadStreamVideos,
  required VoidCallback onLogout,
  required VoidCallback onDeleteAccount,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) {
      return ProfileMenuBottomSheet(
        onVr: () {
          Navigator.pop(sheetContext);
          onVr();
        },
        onVyoooCoin: () {
          Navigator.pop(sheetContext);
          onVyoooCoin();
        },
        onRevenue: () {
          Navigator.pop(sheetContext);
          onRevenue();
        },
        onSettings: () {
          Navigator.pop(sheetContext);
          onSettings();
        },
        onMusicLibrary: () {
          Navigator.pop(sheetContext);
          onMusicLibrary();
        },
        onUploadStreamVideos: () {
          Navigator.pop(sheetContext);
          onUploadStreamVideos();
        },
        onLogout: () {
          Navigator.pop(sheetContext);
          onLogout();
        },
        onDeleteAccount: () {
          Navigator.pop(sheetContext);
          onDeleteAccount();
        },
      );
    },
  );
}

class ProfileMenuBottomSheet extends StatelessWidget {
  const ProfileMenuBottomSheet({
    super.key,
    required this.onVr,
    required this.onVyoooCoin,
    required this.onRevenue,
    required this.onSettings,
    required this.onMusicLibrary,
    required this.onUploadStreamVideos,
    required this.onLogout,
    required this.onDeleteAccount,
  });

  final VoidCallback onVr;
  final VoidCallback onVyoooCoin;
  final VoidCallback onRevenue;
  final VoidCallback onSettings;
  final VoidCallback onMusicLibrary;
  final VoidCallback onUploadStreamVideos;
  final VoidCallback onLogout;
  final VoidCallback onDeleteAccount;

  static const _sheetRadius = BorderRadius.vertical(top: Radius.circular(20));

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return ClipRRect(
      borderRadius: _sheetRadius,
      child: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage(AppBackgroundAssets.commentsSection),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomInset > 0 ? 0 : AppSpacing.sm),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: AppSpacing.sm),
                Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _ProfileMenuTile(
                  assetIconPath: 'assets/vyooO_icons/Home/vr.png',
                  label: 'VR',
                  onTap: onVr,
                ),
                _ProfileMenuTile(
                  assetIconPath: 'assets/vyooO_icons/Settings/Wallet.png',
                  label: 'Vyooo coin',
                  subtitle: 'Coming soon',
                  onTap: onVyoooCoin,
                ),
                _ProfileMenuTile(
                  icon: Icons.payments_rounded,
                  label: 'Revenue',
                  onTap: onRevenue,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  child: Divider(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                _ProfileMenuTile(
                  icon: Icons.settings_rounded,
                  label: 'Settings',
                  onTap: onSettings,
                ),
                _ProfileMenuTile(
                  icon: Icons.music_note_rounded,
                  label: 'Music library',
                  onTap: onMusicLibrary,
                ),
                _ProfileMenuTile(
                  icon: Icons.upload_rounded,
                  label: 'Upload Stream videos',
                  onTap: onUploadStreamVideos,
                ),
                _ProfileMenuTile(
                  icon: Icons.logout_rounded,
                  label: 'Log out',
                  onTap: onLogout,
                ),
                _ProfileMenuTile(
                  icon: Icons.delete_forever_rounded,
                  label: 'Delete account',
                  onTap: onDeleteAccount,
                  isDestructive: true,
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileMenuTile extends StatelessWidget {
  const _ProfileMenuTile({
    required this.label,
    required this.onTap,
    this.icon,
    this.assetIconPath,
    this.subtitle,
    this.isDestructive = false,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final String? assetIconPath;
  final String? subtitle;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final color = isDestructive
        ? const Color(0xFFEF4444)
        : Colors.white.withValues(alpha: 0.92);
    final iconColor = isDestructive
        ? const Color(0xFFEF4444)
        : Colors.white.withValues(alpha: 0.85);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm + 2,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                height: 28,
                child: assetIconPath != null
                    ? Image.asset(
                        assetIconPath!,
                        width: 24,
                        height: 24,
                        color: iconColor,
                      )
                    : Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: AppTypography.authDialogOption.copyWith(
                        color: color,
                        fontWeight:
                            isDestructive ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: AppTypography.authSmallBody.copyWith(
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white.withValues(alpha: 0.45),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
