import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/app_user_model.dart';
import '../../../core/theme/app_padding.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../utils/chat_constants.dart';

class ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ChatAppBar({
    super.key,
    this.otherUser,
    this.chatType = ChatTypes.direct,
    this.groupName,
    this.groupImageUrl,
    this.memberCount,
    this.presenceText,
    this.onAudioCall,
    this.onVideoCall,
    this.onHeaderTap,
  });

  final AppUserModel? otherUser;
  final String chatType;
  final String? groupName;
  final String? groupImageUrl;
  final int? memberCount;
  final String? presenceText;
  final VoidCallback? onAudioCall;
  final VoidCallback? onVideoCall;
  final VoidCallback? onHeaderTap;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  bool get _isGroup => chatType == ChatTypes.group;

  bool get _isVerified {
    if (_isGroup) return false;
    return otherUser?.isVerified == true;
  }

  String get _displayName {
    if (_isGroup) return groupName ?? 'Group';
    final u = otherUser;
    if (u == null) return '';
    final dn = (u.displayName ?? '').trim();
    return dn.isNotEmpty ? dn : u.username ?? '';
  }

  String? get _subtitle {
    if (presenceText != null && presenceText!.isNotEmpty) return presenceText;
    if (_isGroup && memberCount != null) return '$memberCount members';
    if (!_isGroup) {
      final u = otherUser;
      if (u != null && (u.username ?? '').trim().isNotEmpty) {
        return u.username;
      }
    }
    return null;
  }

  String? get _avatarUrl {
    if (_isGroup) return groupImageUrl;
    return otherUser?.profileImage;
  }

  @override
  Widget build(BuildContext context) {
    final avatar = _avatarUrl;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.chatBackground,
        border: Border(
          bottom: BorderSide(color: AppColors.chatDivider, width: 0.5),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.xs,
            right: AppPadding.screenHorizontal.right - AppSpacing.xs,
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new,
                  color: AppColors.chatTextPrimary,
                  size: 18,
                ),
                onPressed: () => Navigator.of(context).pop(),
                padding: const EdgeInsets.all(AppSpacing.sm),
                constraints: const BoxConstraints(),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: onHeaderTap,
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    children: [
                      _ChatHeaderAvatar(
                        imageUrl: avatar,
                        isGroup: _isGroup,
                      ),
                      SizedBox(width: AppSpacing.sm + AppSpacing.xs - 2),
                      Flexible(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    _displayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.chatAppBarName,
                                  ),
                                ),
                                if (_isVerified) ...[
                                  SizedBox(width: AppSpacing.xs - 1),
                                  const Icon(
                                    Icons.verified,
                                    color: AppColors.chatVerified,
                                    size: 14,
                                  ),
                                ],
                              ],
                            ),
                            if (_subtitle != null)
                              Text(
                                _subtitle!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.chatAppBarUsername.copyWith(
                                  color: presenceText == 'Active now'
                                      ? AppColors.chatVerified
                                      : AppColors.chatThreadHeaderUsername,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (onAudioCall != null)
                _CallActionButton(
                  assetPath: ChatAssets.audioCallIcon,
                  width: 20,
                  height: 20,
                  onTap: onAudioCall!,
                  tooltip: 'Audio call',
                ),
              if (onVideoCall != null)
                _CallActionButton(
                  assetPath: ChatAssets.videoCallIcon,
                  width: 22,
                  height: 19,
                  onTap: onVideoCall!,
                  tooltip: 'Video call',
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatHeaderAvatar extends StatelessWidget {
  const _ChatHeaderAvatar({
    required this.imageUrl,
    required this.isGroup,
  });

  final String? imageUrl;
  final bool isGroup;

  @override
  Widget build(BuildContext context) {
    final maskSize = AppSizes.chatThreadHeaderAvatar;
    final hasAvatar = imageUrl != null && imageUrl!.trim().isNotEmpty;

    return ClipOval(
      child: SizedBox(
        width: maskSize,
        height: maskSize,
        child: hasAvatar
            ? CachedNetworkImage(
                imageUrl: imageUrl!,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => _placeholder(isGroup),
              )
            : _placeholder(isGroup),
      ),
    );
  }

  Widget _placeholder(bool isGroup) {
    return ColoredBox(
      color: AppColors.chatSearchFill,
      child: Center(
        child: Icon(
          isGroup ? Icons.group : Icons.person,
          color: AppColors.chatTextSecondary,
          size: 18,
        ),
      ),
    );
  }
}

class _CallActionButton extends StatelessWidget {
  const _CallActionButton({
    required this.assetPath,
    required this.width,
    required this.height,
    required this.onTap,
    required this.tooltip,
  });

  final String assetPath;
  final double width;
  final double height;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      tooltip: tooltip,
      padding: const EdgeInsets.all(AppSpacing.sm),
      constraints: const BoxConstraints(),
      icon: SvgPicture.asset(
        assetPath,
        width: width,
        height: height,
        colorFilter: const ColorFilter.mode(
          AppColors.chatAppBarActionIcon,
          BlendMode.srcIn,
        ),
      ),
    );
  }
}
