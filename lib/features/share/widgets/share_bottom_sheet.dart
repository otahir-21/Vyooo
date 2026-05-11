import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/config/deep_link_config.dart';
import '../data/mock_share_data.dart';
import '../models/share_contact.dart';
import '../models/share_action.dart';

/// Opens the share sheet with a translucent "light black" glassmorphism effect.
Future<void> showShareBottomSheet(
  BuildContext context, {
  required String reelId,
  String? thumbnailUrl,
  String? authorName,
  required VoidCallback onShareViaNative,
  required VoidCallback onCopyLink,
}) {
  final shareUrl = DeepLinkConfig.reelWebUri(reelId).toString();
  return showModalBottomSheet<void>(
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
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.75),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 0.5),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _DragHandle(),
                  _TopBar(onClose: () => Navigator.of(context).pop()),
                  if (thumbnailUrl != null)
                    _ContentHeader(
                      thumbnailUrl: thumbnailUrl,
                      authorName: authorName,
                    ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 110,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: contacts.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 16),
                      itemBuilder: (context, index) {
                        final c = contacts[index];
                        return _ContactChip(
                          contact: c,
                          onTap: () => _handleContact(context, c),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 100,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: nativeTargets.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 16),
                      itemBuilder: (context, index) {
                        final a = nativeTargets[index];
                        return _NativeTargetChip(
                          action: a,
                          onTap: () => _handleNativeTarget(context),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
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
            ),
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
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Center(
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Icon(Icons.search, color: Colors.white70, size: 28),
          const Text(
            'Share With',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          GestureDetector(
            onTap: onClose,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContentHeader extends StatelessWidget {
  const _ContentHeader({
    this.thumbnailUrl,
    required this.authorName,
  });

  final String? thumbnailUrl;
  final String authorName;

  @override
  Widget build(BuildContext context) {
    final thumb = thumbnailUrl?.trim() ?? '';
    final hasValidThumb = thumb.isNotEmpty &&
        Uri.tryParse(thumb)?.isAbsolute == true &&
        (Uri.tryParse(thumb)?.host.isNotEmpty ?? false);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(12),
              image: hasValidThumb
                  ? DecorationImage(image: NetworkImage(thumb), fit: BoxFit.cover)
                  : null,
            ),
            child: !hasValidThumb
                ? const Icon(Icons.videocam, color: Colors.white24)
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Video from $authorName',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  'Vyooo',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 14,
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

class _ContactChip extends StatelessWidget {
  const _ContactChip({required this.contact, required this.onTap});

  final ShareContact contact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 72,
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1),
                  ),
                  child: CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.grey[900],
                    backgroundImage: NetworkImage(contact.avatarUrl),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      shape: BoxShape.circle,
                    ),
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: const BoxDecoration(
                        color: Color(0xFF25D366),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.message, size: 10, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              contact.name,
              maxLines: 2,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w400,
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
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 72,
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: action.backgroundColor,
                shape: BoxShape.circle,
                gradient: action.id == 'instagram' 
                  ? const RadialGradient(
                      center: Alignment.bottomLeft,
                      radius: 1.5,
                      colors: [Color(0xFFFEDA75), Color(0xFFD62976), Color(0xFF4F5BD5)],
                    ) : null,
              ),
              child: Icon(
                action.icon,
                size: 28,
                color: action.backgroundColor == Colors.white ? Colors.blue : Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              action.label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w400,
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
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08), width: 0.8)),
            ),
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
        ),
      ],
    );
  }
}
