import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/app_user_model.dart';
import '../../../core/services/user_service.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/theme/app_padding.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../controllers/chat_controller.dart';
import '../models/chat_summary_model.dart';
import '../utils/chat_constants.dart';
import '../widgets/chat_tile.dart';
import 'chat_thread_screen.dart';
import 'message_requests_screen.dart';
import 'new_message_screen.dart';

class ChatInboxScreen extends StatefulWidget {
  const ChatInboxScreen({super.key});

  @override
  State<ChatInboxScreen> createState() => _ChatInboxScreenState();
}

class _ChatInboxScreenState extends State<ChatInboxScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late final ChatController _controller;
  final UserService _userService = UserService();
  String? _currentUid;
  AppUserModel? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUid = FirebaseAuth.instance.currentUser?.uid;
    _controller = ChatController(uid: _currentUid ?? '');
    _controller.addListener(_onControllerChange);
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    if (_currentUid == null) return;
    final user = await _userService.getUser(_currentUid!);
    if (!mounted || user == null) return;
    setState(() {
      _currentUser = user;
    });
  }

  void _onControllerChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChange);
    _controller.dispose();
    super.dispose();
  }

  List<ChatSummaryModel> get _primarySummaries {
    return _controller.summaries.where((s) {
      final rs = s.requestStatus;
      return rs == null ||
          rs == RequestStatus.none ||
          rs == RequestStatus.accepted;
    }).toList();
  }

  List<ChatSummaryModel> get _requestSummaries {
    return _controller.summaries.where((s) {
      return s.requestStatus == RequestStatus.pending;
    }).toList();
  }

  Future<void> _openThread(ChatSummaryModel summary) async {
    if (_currentUid == null) return;

    final currentUser = _currentUser ?? await _userService.getUser(_currentUid!);
    if (!mounted || currentUser == null) return;
    _currentUser ??= currentUser;

    if (summary.type == ChatTypes.group) {
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ChatThreadScreen(
            chatId: summary.chatId,
            currentUser: currentUser,
            chatType: ChatTypes.group,
            groupName: summary.title,
            groupImageUrl: summary.avatarUrl,
            participantIds: summary.participantIds,
          ),
        ),
      );
      return;
    }

    final otherUid = summary.participantIds.firstWhere(
      (id) => id != _currentUid,
      orElse: () => '',
    );
    if (otherUid.isEmpty) return;

    final otherUser = AppUserModel(
      uid: otherUid,
      email: '',
      displayName: summary.title,
      profileImage:
          summary.avatarUrl.trim().isNotEmpty ? summary.avatarUrl : null,
      createdAt: Timestamp.now(),
    );

    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatThreadScreen(
          chatId: summary.chatId,
          currentUser: currentUser,
          otherUser: otherUser,
        ),
      ),
    );
  }

  void _openNewMessage() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const NewMessageScreen()));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: AppColors.chatBackground,
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: AppGradients.chatBackgroundGradient,
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildHeader(),
                _buildSearchBar(),
                _ChatNotesRow(
                  summaries: _primarySummaries,
                  currentUid: _currentUid,
                  onTapNote: (summary) {
                    if (summary != null) {
                      _openThread(summary);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Notes coming soon'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    }
                  },
                ),
                _buildMessagesSectionHeader(),
                const Divider(
                  height: 1,
                  thickness: 0.5,
                  color: AppColors.chatDivider,
                ),
                Expanded(child: _buildInboxList()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppPadding.screenHorizontal.left,
        AppSpacing.xs,
        AppPadding.screenHorizontal.right,
        AppSpacing.xs,
      ),
      child: SizedBox(
        height: AppSizes.chatComposeButton,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppSizes.chatComposeButton,
              ),
              child: Text(
                'Messages',
                style: AppTypography.chatInboxTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: _openNewMessage,
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  width: AppSizes.chatComposeButton,
                  height: AppSizes.chatComposeButton,
                  child: Center(
                    child: SvgPicture.asset(
                      ChatAssets.newChatIcon,
                      width: 18,
                      height: 18,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    final sectionGap =
        AppSizes.chatInboxScaleH(context, AppSizes.chatInboxSectionGap);
    final searchHeight =
        AppSizes.chatInboxScaleH(context, AppSizes.chatSearchHeight);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppPadding.screenHorizontal.left,
        AppSpacing.xs,
        AppPadding.screenHorizontal.right,
        sectionGap,
      ),
      child: SizedBox(
        width: double.infinity,
        height: searchHeight,
        child: SvgPicture.asset(
          ChatAssets.searchBar,
          fit: BoxFit.fill,
        ),
      ),
    );
  }

  Widget _buildMessagesSectionHeader() {
    final requestCount = _requestSummaries.length;
    final requestCountFontSize =
        AppSizes.chatInboxScaleW(context, 14);
    final requestCountLineHeight =
        AppSizes.chatInboxScaleW(context, 17);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppPadding.screenHorizontal.left,
        0,
        AppPadding.screenHorizontal.right,
        AppSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text('Messages', style: AppTypography.chatSectionHeader),
          const Spacer(),
          GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      MessageRequestsScreen(requests: _requestSummaries),
                ),
              );
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Requests',
                  style: AppTypography.chatSectionHeader.copyWith(
                    color: AppColors.chatRequestsTitle,
                  ),
                ),
                if (requestCount > 0) ...[
                  SizedBox(width: AppSpacing.xs - 1),
                  Text(
                    '($requestCount)',
                    style: AppTypography.chatTilePreview.copyWith(
                      color: AppColors.chatRequestsTitle,
                      fontWeight: FontWeight.w500,
                      fontSize: requestCountFontSize,
                      height: requestCountLineHeight / requestCountFontSize,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInboxList() {
    if (_controller.loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.brandMagenta),
      );
    }

    if (_controller.error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              color: AppColors.chatTextSecondary,
              size: 48,
            ),
            SizedBox(height: AppSpacing.md - AppSpacing.xs),
            Text(
              _controller.error!,
              style: AppTypography.chatTilePreview,
            ),
          ],
        ),
      );
    }

    final summaries = _primarySummaries;
    if (summaries.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              color: AppColors.chatTextSecondary.withValues(alpha: 0.5),
              size: 48,
            ),
            SizedBox(height: AppSpacing.md - AppSpacing.xs),
            Text(
              'No conversations yet',
              style: AppTypography.chatTilePreview,
            ),
            SizedBox(height: AppSpacing.sm),
            GestureDetector(
              onTap: _openNewMessage,
              child: Text(
                'Start a conversation',
                style: AppTypography.chatTilePreview.copyWith(
                  color: AppColors.brandDeepMagenta,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.only(top: AppSpacing.xs, bottom: AppSizes.bottomNavBarHeight),
      itemCount: summaries.length,
      itemBuilder: (context, index) {
        final summary = summaries[index];
        return ChatTile(summary: summary, onTap: () => _openThread(summary));
      },
    );
  }
}

class _ChatNotesRow extends StatelessWidget {
  const _ChatNotesRow({
    required this.summaries,
    required this.currentUid,
    required this.onTapNote,
  });

  final List<ChatSummaryModel> summaries;
  final String? currentUid;
  final void Function(ChatSummaryModel?) onTapNote;

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final seen = <String>{};
    final noteUsers = <_NoteUser>[];

    for (final s in summaries) {
      if (s.type == ChatTypes.group) continue;
      final otherUid = s.participantIds.firstWhere(
        (id) => id != currentUid,
        orElse: () => '',
      );
      if (otherUid.isEmpty || seen.contains(otherUid)) continue;
      seen.add(otherUid);
      noteUsers.add(
        _NoteUser(name: s.title, avatarUrl: s.avatarUrl, summary: s),
      );
    }

    final sectionGap =
        AppSizes.chatInboxScaleH(context, AppSizes.chatInboxSectionGap);
    final rowHeight =
        AppSizes.chatInboxScaleH(context, AppSizes.chatNotesRowHeight);
    final itemGap =
        AppSizes.chatInboxScaleW(context, AppSizes.chatNoteItemGap);

    return Padding(
      padding: EdgeInsets.only(bottom: sectionGap),
      child: SizedBox(
        height: rowHeight,
        child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.fromLTRB(
          AppPadding.screenHorizontal.left,
          0,
          AppPadding.screenHorizontal.right,
          0,
        ),
        itemCount: noteUsers.length + 1,
        itemBuilder: (context, index) {
          final isLast = index == noteUsers.length;
          final item = index == 0
              ? _ChatNoteItem(
                  rowHeight: rowHeight,
                  name: currentUser?.displayName ?? 'Your note',
                  avatarUrl: currentUser?.photoURL,
                  noteText: 'Note..',
                  isCurrentUser: true,
                  onTap: () => onTapNote(null),
                )
              : _ChatNoteItem(
                  rowHeight: rowHeight,
                  name: noteUsers[index - 1].name,
                  avatarUrl: noteUsers[index - 1].avatarUrl.isNotEmpty
                      ? noteUsers[index - 1].avatarUrl
                      : null,
                  noteText: null,
                  isCurrentUser: false,
                  onTap: () => onTapNote(noteUsers[index - 1].summary),
                );

          return Padding(
            padding: EdgeInsets.only(
              right: isLast ? 0 : itemGap,
            ),
            child: item,
          );
        },
      ),
      ),
    );
  }
}

class _NoteUser {
  const _NoteUser({
    required this.name,
    required this.avatarUrl,
    required this.summary,
  });
  final String name;
  final String avatarUrl;
  final ChatSummaryModel summary;
}

class _ChatNoteItem extends StatelessWidget {
  const _ChatNoteItem({
    required this.rowHeight,
    required this.name,
    required this.avatarUrl,
    required this.noteText,
    required this.isCurrentUser,
    required this.onTap,
  });

  final double rowHeight;
  final String name;
  final String? avatarUrl;
  final String? noteText;
  final bool isCurrentUser;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final itemWidth =
        AppSizes.chatInboxScaleW(context, AppSizes.chatNoteItemWidth);
    final labelSlotHeight = AppSizes.chatInboxScaleH(
      context,
      AppSizes.chatNoteNameLabelHeight,
    );
    final labelGap =
        AppSizes.chatInboxScaleH(context, AppSizes.chatNoteLabelGap);
    final bubbleWidth =
        AppSizes.chatInboxScaleW(context, AppSizes.chatNoteBubbleWidth);
    final bubbleLift =
        AppSizes.chatInboxScaleH(context, AppSizes.chatNoteBubbleLift);
    final yourNoteLabelHeight = AppSizes.chatInboxScaleH(
      context,
      AppSizes.chatNoteYourNoteLabelHeight,
    );
    final nameWidth =
        AppSizes.chatInboxScaleW(context, AppSizes.chatNoteNameWidth);
    final nameFontSize = AppSizes.chatInboxScaleW(context, 16);
    final nameLineHeight = AppSizes.chatInboxScaleH(context, 17);

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: itemWidth,
        height: rowHeight,
        child: Column(
          children: [
            Expanded(
              child: SizedBox(
                width: itemWidth,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.bottomCenter,
                  children: [
                    _buildAvatar(context),
                    if (noteText != null)
                      Positioned(
                        top: -bubbleLift,
                        left: (itemWidth - bubbleWidth) / 2,
                        child: _NoteBubble(text: noteText!),
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(height: labelGap),
            SizedBox(
              height: labelSlotHeight,
              width: itemWidth,
              child: ClipRect(
                child: isCurrentUser
                    ? Align(
                        alignment: Alignment.bottomCenter,
                        child: SvgPicture.asset(
                          ChatAssets.yourNoteLabel,
                          width: itemWidth,
                          height: yourNoteLabelHeight,
                        ),
                      )
                    : Align(
                        alignment: Alignment.bottomCenter,
                        child: SizedBox(
                          width: nameWidth,
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: AppTypography.chatNoteNameLabel.copyWith(
                              fontSize: nameFontSize,
                              height: nameLineHeight / nameFontSize,
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(BuildContext context) {
    final hasImage = avatarUrl != null && avatarUrl!.trim().isNotEmpty;
    final avatarSize =
        AppSizes.chatInboxScaleW(context, AppSizes.chatNoteAvatar);
    final avatarIcon =
        AppSizes.chatInboxScaleW(context, AppSizes.chatNoteAvatarIcon);

    return Container(
      width: avatarSize,
      height: avatarSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.chatSearchFill,
        border: Border.all(color: AppColors.chatDivider, width: 1),
      ),
      child: CircleAvatar(
        radius: avatarSize / 2,
        backgroundColor: AppColors.chatSearchFill,
        backgroundImage: hasImage
            ? CachedNetworkImageProvider(avatarUrl!)
            : null,
        child: hasImage
            ? null
            : Icon(
                Icons.person,
                color: AppColors.chatTextSecondary,
                size: avatarIcon,
              ),
      ),
    );
  }
}

class _NoteBubble extends StatelessWidget {
  const _NoteBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final bubbleWidth =
        AppSizes.chatInboxScaleW(context, AppSizes.chatNoteBubbleWidth);
    final bubbleHeight =
        AppSizes.chatInboxScaleH(context, AppSizes.chatNoteBubbleHeight);
    final bubbleBodyHeight = AppSizes.chatInboxScaleH(
      context,
      AppSizes.chatNoteBubbleBodyHeight,
    );
    final bubbleFontSize = AppSizes.chatInboxScaleW(context, 14);
    final horizontalPadding =
        AppSizes.chatInboxScaleW(context, AppSpacing.sm);

    return SizedBox(
      width: bubbleWidth,
      height: bubbleHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: SvgPicture.asset(
              ChatAssets.noteBubble,
              fit: BoxFit.fill,
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: bubbleBodyHeight,
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: AppTypography.chatNoteBubbleText.copyWith(
                    fontSize: bubbleFontSize,
                    height: 1.0,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
