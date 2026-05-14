import 'package:flutter/material.dart';

/// Bottom row for the create hub: **Story | Post | Live** — same chrome as [UploadScreen].
///
/// [selectedSegment]: `0` Story, `1` Post, `2` Live.
class UploadCreateBottomBar extends StatelessWidget {
  const UploadCreateBottomBar({
    super.key,
    required this.selectedSegment,
    required this.onStoryTap,
    required this.onPostTap,
    required this.onLiveTap,
  });

  final int selectedSegment;
  final VoidCallback onStoryTap;
  final VoidCallback onPostTap;
  final VoidCallback onLiveTap;

  @override
  Widget build(BuildContext context) {
    final seg = selectedSegment.clamp(0, 2);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E0A1E).withValues(alpha: 0.4),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
      ),
      child: Row(
        children: [
            Expanded(
              child: Center(
                child: UploadCreateSegmentButton(
                  label: 'Story',
                  iconPath: 'assets/vyooO_icons/Upload_Story_Live/story.png',
                  selected: seg == 0,
                  onTap: onStoryTap,
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: UploadCreateSegmentButton(
                  label: 'Post',
                  iconPath: 'assets/vyooO_icons/Upload_Story_Live/gallery.png',
                  selected: seg == 1,
                  onTap: onPostTap,
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: UploadCreateSegmentButton(
                  label: 'Live',
                  iconPath: 'assets/vyooO_icons/Upload_Story_Live/live.png',
                  selected: seg == 2,
                  onTap: onLiveTap,
                ),
              ),
            ),
          ],
        ),
    );
  }
}

class UploadCreateSegmentButton extends StatelessWidget {
  const UploadCreateSegmentButton({
    super.key,
    required this.label,
    required this.iconPath,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String iconPath;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : Colors.white.withValues(alpha: 0.6);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFDE106B) : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                iconPath,
                width: 20,
                height: 20,
                color: color,
                errorBuilder: (_, _, _) => Icon(
                  label == 'Story'
                      ? Icons.videocam_outlined
                      : label == 'Post'
                          ? Icons.post_add_outlined
                          : Icons.wifi_tethering_rounded,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
