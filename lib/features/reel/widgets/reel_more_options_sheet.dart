import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';

/// Shows the three-dots "more options" bottom sheet: Download, Report, Not Interested,
/// then Captions, Playback speed, Quality, Manage preferences, Why you're seeing this.
Future<void> showReelMoreOptionsSheet(
  BuildContext context, {
  required String reelId,
  String playbackSpeed = 'Normal',
  String quality = 'Auto (1080p HD)',
  bool autoScrollEnabled = true,
  VoidCallback? onDownload,
  VoidCallback? onReport,
  VoidCallback? onNotInterested,
  VoidCallback? onCaptions,
  VoidCallback? onPlaybackSpeed,
  VoidCallback? onQuality,
  VoidCallback? onManagePreferences,
  VoidCallback? onWhyThisPost,
  ValueChanged<bool>? onAutoScrollChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _ReelMoreOptionsSheet(
      reelId: reelId,
      playbackSpeed: playbackSpeed,
      quality: quality,
      autoScrollEnabled: autoScrollEnabled,
      onDownload: onDownload,
      onReport: onReport,
      onNotInterested: onNotInterested,
      onCaptions: onCaptions,
      onPlaybackSpeed: onPlaybackSpeed,
      onQuality: onQuality,
      onManagePreferences: onManagePreferences,
      onWhyThisPost: onWhyThisPost,
      onAutoScrollChanged: onAutoScrollChanged,
    ),
  );
}

abstract final class _Layout {
  static const double dragHandleWidth = 36;
  static const double dragHandleHeight = 4;
}

class _ReelMoreOptionsSheet extends StatefulWidget {
  const _ReelMoreOptionsSheet({
    required this.reelId,
    required this.playbackSpeed,
    required this.quality,
    required this.autoScrollEnabled,
    this.onDownload,
    this.onReport,
    this.onNotInterested,
    this.onCaptions,
    this.onPlaybackSpeed,
    this.onQuality,
    this.onManagePreferences,
    this.onWhyThisPost,
    this.onAutoScrollChanged,
  });

  final String reelId;
  final String playbackSpeed;
  final String quality;
  final bool autoScrollEnabled;
  final VoidCallback? onDownload;
  final VoidCallback? onReport;
  final VoidCallback? onNotInterested;
  final VoidCallback? onCaptions;
  final VoidCallback? onPlaybackSpeed;
  final VoidCallback? onQuality;
  final VoidCallback? onManagePreferences;
  final VoidCallback? onWhyThisPost;
  final ValueChanged<bool>? onAutoScrollChanged;

  @override
  State<_ReelMoreOptionsSheet> createState() => _ReelMoreOptionsSheetState();
}

class _ReelMoreOptionsSheetState extends State<_ReelMoreOptionsSheet> {
  late bool _autoScroll;

  @override
  void initState() {
    super.initState();
    _autoScroll = widget.autoScrollEnabled;
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.75,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF49113B), // Deep Magenta
                Color(0xFF210D1D),
                Color(0xFF0F040C),
              ],
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DragHandle(),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.download_rounded,
                        label: 'Download',
                        onTap: () {
                          Navigator.of(context).pop();
                          widget.onDownload?.call();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.report_outlined,
                        label: 'Report',
                        iconColor: const Color(0xFFEF4444),
                        labelColor: const Color(0xFFEF4444),
                        onTap: () {
                          Navigator.of(context).pop();
                          widget.onReport?.call();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.favorite_border,
                        label: 'Not Interested',
                        onTap: () {
                          Navigator.of(context).pop();
                          widget.onNotInterested?.call();
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  children: [
                    _Section(
                      backgroundColor: Colors.white.withValues(alpha: 0.05),
                      borderRadius: 16,
                      children: [
                        _AutoScrollTile(
                          enabled: _autoScroll,
                          onChanged: (value) {
                            setState(() => _autoScroll = value);
                            widget.onAutoScrollChanged?.call(value);
                          },
                        ),
                        _SettingTile(
                          icon: Icons.closed_caption_outlined,
                          label: 'Captions and translations',
                          onTap: () {
                            Navigator.of(context).pop();
                            widget.onCaptions?.call();
                          },
                        ),
                        _SettingTile(
                          icon: Icons.speed_rounded,
                          label: 'Playback speed',
                          trailing: widget.playbackSpeed,
                          onTap: () {
                            Navigator.of(context).pop();
                            widget.onPlaybackSpeed?.call();
                          },
                        ),
                        _SettingTile(
                          icon: Icons
                              .tune_rounded, // Better icon for Quality matching Figma
                          label: 'Quality',
                          trailing: widget.quality,
                          onTap: () {
                            Navigator.of(context).pop();
                            widget.onQuality?.call();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _Section(
                      backgroundColor: Colors.white.withValues(alpha: 0.05),
                      borderRadius: 16,
                      children: [
                        _SettingTile(
                          icon: Icons.shuffle_rounded,
                          label: 'Manage content preferences',
                          onTap: () {
                            Navigator.of(context).pop();
                            widget.onManagePreferences?.call();
                          },
                        ),
                        _SettingTile(
                          icon: Icons.info_outline_rounded,
                          label: "Why you're seeing this post",
                          onTap: () {
                            Navigator.of(context).pop();
                            widget.onWhyThisPost?.call();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AutoScrollTile extends StatelessWidget {
  const _AutoScrollTile({required this.enabled, required this.onChanged});

  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!enabled),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(
              Icons.play_circle_outline_rounded,
              size: 22,
              color: Colors.white.withValues(alpha: 0.9),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Text(
                'Auto scroll',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            SizedBox(
              height: 24,
              width: 40,
              child: Switch.adaptive(
                value: enabled,
                onChanged: onChanged,
                activeTrackColor: const Color(0xFFEF4444),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DragHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: AppSpacing.storyItem,
        bottom: AppSpacing.xs,
      ),
      child: Center(
        child: Container(
          width: _Layout.dragHandleWidth,
          height: _Layout.dragHandleHeight,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    this.iconColor,
    this.labelColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color? iconColor;
  final Color? labelColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? Colors.white;
    final textColor = labelColor ?? Colors.white;
    return Material(
      color: Colors.white.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 24, color: color),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.backgroundColor,
    required this.borderRadius,
    required this.children,
  });

  final Color backgroundColor;
  final double borderRadius;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.icon,
    required this.label,
    this.trailing,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 22, color: Colors.white.withValues(alpha: 0.9)),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            if (trailing != null) ...[
              Text(
                trailing!,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 4),
            ],
            Icon(
              Icons.chevron_right,
              size: 20,
              color: Colors.white.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }
}
