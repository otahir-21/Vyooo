import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../data/mock_share_data.dart';
import '../models/share_contact.dart';
import '../models/share_action.dart';

/// Opens the traditional-style share sheet: content preview, in-app contacts,
/// native share targets (AirDrop, Messages, Mail, etc.), and action list (Copy, etc.).
void showShareBottomSheet(
  BuildContext context, {
  required String reelId,
  String? thumbnailUrl,
  String? authorName,
  required VoidCallback onShareViaNative,
  required VoidCallback onCopyLink,
}) {
  final shareUrl = 'https://vyooo.com/reel/$reelId';
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _ShareSheet(
      thumbnailUrl: thumbnailUrl,
      authorName: authorName ?? 'Vyooo',
      onShareViaNative: onShareViaNative,
      onCopyLink: () {
        Clipboard.setData(ClipboardData(text: shareUrl));
        onCopyLink();
      },
    ),
  );
}

/// Layout constants for share sheet.
abstract final class _ShareLayout {
  static const double dragHandleWidth = 36;
  static const double dragHandleHeight = 4;
  static const double previewThumbSize = 48;
  static const double contactChipWidth = 72;
  static const double contactsRowHeight = 96;
  static const double nativeTargetSize = 56;
  static const double nativeTargetWidth = 64;
  static const double avatarSize = 56;
  static const double appBadgeSize = 22;
}

class _ShareSheet extends StatelessWidget {
  const _ShareSheet({
    this.thumbnailUrl,
    required this.authorName,
    required this.onShareViaNative,
    required this.onCopyLink,
  });

  final String? thumbnailUrl;
  final String authorName;
  final VoidCallback onShareViaNative;
  final VoidCallback onCopyLink;

  void _handleContact(BuildContext context, ShareContact contact) {
    Navigator.of(context).pop();
    onShareViaNative();
  }

  void _handleNativeTarget(BuildContext context) {
    Navigator.of(context).pop();
    onShareViaNative();
  }

  void _handleSystemAction(BuildContext context, ShareSystemAction action) {
    if (action.id == 'copy') {
      onCopyLink();
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pop();
      onShareViaNative();
    }
  }

  @override
  Widget build(BuildContext context) {
    final contacts = getMockShareContacts();
    final nativeTargets = getMockNativeShareTargets();
    final systemActions = getMockShareSystemActions();
    return DraggableScrollableSheet(
      initialChildSize: 0.58,
      minChildSize: 0.35,
      maxChildSize: 0.85,
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
              _ContentPreview(
                thumbnailUrl: thumbnailUrl,
                authorName: authorName,
                onClose: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: AppSpacing.sm),
              _SectionLabel('Share with'),
              SizedBox(
                height: _ShareLayout.contactsRowHeight,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  itemCount: contacts.length,
                  separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
                  itemBuilder: (context, index) {
                    final c = contacts[index];
                    return _ContactChip(
                      contact: c,
                      onTap: () => _handleContact(context, c),
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                height: _ShareLayout.nativeTargetSize + 28,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  itemCount: nativeTargets.length,
                  separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final a = nativeTargets[index];
                    return _NativeTargetChip(
                      action: a,
                      onTap: () => _handleNativeTarget(context),
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                  itemCount: systemActions.length,
                  itemBuilder: (context, index) {
                    final a = systemActions[index];
                    return _SystemActionTile(
                      action: a,
                      onTap: () => _handleSystemAction(context, a),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DragHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.storyItem, bottom: AppSpacing.sm),
      child: Center(
        child: Container(
          width: _ShareLayout.dragHandleWidth,
          height: _ShareLayout.dragHandleHeight,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

class _ContentPreview extends StatelessWidget {
  const _ContentPreview({
    this.thumbnailUrl,
    required this.authorName,
    required this.onClose,
  });

  final String? thumbnailUrl;
  final String authorName;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      child: Row(
        children: [
          Container(
            width: _ShareLayout.previewThumbSize,
            height: _ShareLayout.previewThumbSize,
            decoration: BoxDecoration(
              color: Colors.grey.shade800,
              borderRadius: BorderRadius.circular(AppRadius.input),
            ),
            clipBehavior: Clip.antiAlias,
            child: thumbnailUrl != null && Uri.tryParse(thumbnailUrl!)?.isAbsolute == true
                ? Image.network(thumbnailUrl!, fit: BoxFit.cover)
                : const Icon(Icons.videocam_outlined, color: Colors.white54, size: 28),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Video from $authorName',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Vyooo',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onClose,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _ContactChip extends StatelessWidget {
  const _ContactChip({required this.contact, required this.onTap});

  final ShareContact contact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: _ShareLayout.contactChipWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: _ShareLayout.avatarSize / 2,
                  backgroundColor: Colors.grey.shade700,
                  backgroundImage: Uri.tryParse(contact.avatarUrl)?.isAbsolute == true
                      ? NetworkImage(contact.avatarUrl)
                      : null,
                ),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    width: _ShareLayout.appBadgeSize,
                    height: _ShareLayout.appBadgeSize,
                    decoration: BoxDecoration(
                      color: AppColors.whatsappGreen,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.sheetBackgroundShare, width: 2),
                    ),
                    child: const Icon(Icons.chat_bubble, size: 12, color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              contact.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NativeTargetChip extends StatelessWidget {
  const _NativeTargetChip({required this.action, required this.onTap});

  final ShareActionItem action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bgColor = action.backgroundColor == Colors.white
        ? Colors.grey.shade700
        : action.backgroundColor;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: _ShareLayout.nativeTargetWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: _ShareLayout.nativeTargetSize,
              height: _ShareLayout.nativeTargetSize,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                action.icon,
                size: 26,
                color: action.backgroundColor == Colors.white ? Colors.grey.shade300 : Colors.white,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              action.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SystemActionTile extends StatelessWidget {
  const _SystemActionTile({required this.action, required this.onTap});

  final ShareSystemAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.input),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: AppSpacing.xs),
        child: Row(
          children: [
            Expanded(
              child: Text(
                action.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            Icon(action.icon, size: 22, color: Colors.white70),
          ],
        ),
      ),
    );
  }
}
