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
import '../../../core/theme/app_radius.dart';
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
  String _headerName = 'Messages';

  @override
  void initState() {
    super.initState();
    _currentUid = FirebaseAuth.instance.currentUser?.uid;
    _controller = ChatController(uid: _currentUid ?? '');
    _controller.addListener(_onControllerChange);
    _loadHeaderName();
  }

  Future<void> _loadHeaderName() async {
    if (_currentUid == null) return;
    final user = await _userService.getUser(_currentUid!);
    if (!mounted || user == null) return;
    _currentUser = user;
    final username = (user.username ?? '').trim();
    final displayName = (user.displayName ?? '').trim();
    setState(() {
      _headerName = username.isNotEmpty
          ? username
          : (displayName.isNotEmpty ? displayName : 'Messages');
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
                _headerName,
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
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppPadding.screenHorizontal.left,
        AppSpacing.xs,
        AppPadding.screenHorizontal.right,
        AppSpacing.xs,
      ),
      child: Container(
        height: AppSizes.chatSearchHeight,
        decoration: BoxDecoration(
          color: AppColors.chatSearchFill,
          borderRadius: BorderRadius.circular(AppSizes.chatSearchHeight / 2),
        ),
        child: Row(
          children: [
            SizedBox(width: AppSpacing.md - AppSpacing.xs),
            const Icon(
              Icons.search,
              color: AppColors.chatTextSecondary,
              size: 18,
            ),
            SizedBox(width: AppSpacing.sm),
            Text('Search', style: AppTypography.chatTilePreview),
          ],
        ),
      ),
    );
  }

  Widget _buildMessagesSectionHeader() {
    final requestCount = _requestSummaries.length;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppPadding.screenHorizontal.left,
        AppSpacing.xs,
        AppPadding.screenHorizontal.right,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          const Text('Messages', style: AppTypography.chatSectionHeader),
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
            child: Text(
              requestCount > 0
                  ? 'Requests ($requestCount)'
                  : 'Requests',
              style: AppTypography.chatTilePreview.copyWith(
                color: AppColors.brandDeepMagenta,
                fontWeight: FontWeight.w500,
              ),
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

    return SizedBox(
      height: 94,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.fromLTRB(
          AppSpacing.sm + AppSpacing.xs,
          AppSpacing.xs,
          AppSpacing.sm + AppSpacing.xs,
          0,
        ),
        itemCount: noteUsers.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _ChatNoteItem(
              name: currentUser?.displayName ?? 'Your note',
              avatarUrl: currentUser?.photoURL,
              noteText: 'Note...',
              isCurrentUser: true,
              onTap: () => onTapNote(null),
            );
          }
          final user = noteUsers[index - 1];
          return _ChatNoteItem(
            name: user.name,
            avatarUrl: user.avatarUrl.isNotEmpty ? user.avatarUrl : null,
            noteText: null,
            isCurrentUser: false,
            onTap: () => onTapNote(user.summary),
          );
        },
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
    required this.name,
    required this.avatarUrl,
    required this.noteText,
    required this.isCurrentUser,
    required this.onTap,
  });

  final String name;
  final String? avatarUrl;
  final String? noteText;
  final bool isCurrentUser;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 68,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 64,
              width: 68,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    bottom: 0,
                    left: AppSpacing.sm - AppSpacing.xs,
                    right: AppSpacing.sm - AppSpacing.xs,
                    child: _buildAvatar(),
                  ),
                  if (noteText != null)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: _NoteBubble(text: noteText!),
                    ),
                ],
              ),
            ),
            SizedBox(height: AppSpacing.xs - 1),
            Text(
              _displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTypography.chatTilePreview.copyWith(fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  String get _displayName {
    if (isCurrentUser) return 'Your note';
    if (name.length > 9) return '${name.substring(0, 8)}…';
    return name;
  }

  Widget _buildAvatar() {
    final hasImage = avatarUrl != null && avatarUrl!.trim().isNotEmpty;
    return Container(
      width: AppSizes.chatNoteAvatar,
      height: AppSizes.chatNoteAvatar,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.chatSearchFill,
        border: Border.all(color: AppColors.chatDivider, width: 1),
      ),
      child: CircleAvatar(
        radius: AppSizes.chatNoteAvatar / 2,
        backgroundColor: AppColors.chatSearchFill,
        backgroundImage: hasImage
            ? CachedNetworkImageProvider(avatarUrl!)
            : null,
        child: hasImage
            ? null
            : const Icon(
                Icons.person,
                color: AppColors.chatTextSecondary,
                size: 22,
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
    return Center(
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.sm - AppSpacing.xs,
          vertical: AppSpacing.xs - 1,
        ),
        decoration: BoxDecoration(
          color: AppColors.chatNoteBubbleFill,
          borderRadius: AppRadius.inputRadius,
          border: Border.all(color: AppColors.chatNoteBubbleBorder, width: 0.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.chatTilePreview.copyWith(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: AppColors.chatTextPrimary,
          ),
        ),
      ),
    );
  }
}
