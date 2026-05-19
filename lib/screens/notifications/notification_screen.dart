import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../core/widgets/settings/settings_inner_app_bar.dart';
import 'package:vyooo/core/widgets/app_gradient_background.dart';

import '../../core/models/app_user_model.dart';
import '../../core/services/auth_service.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/user_service.dart';
import '../../core/utils/user_facing_errors.dart';
import '../../features/comments/widgets/comments_bottom_sheet.dart';

/// Notifications tab: grouped by Today / Yesterday / Last 7 days.
class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen>
    with AutomaticKeepAliveClientMixin {
  bool _isMarkingVisibleAsRead = false;
  final Set<String> _followBackInFlight = <String>{};

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppGradientBackground(
        type: GradientType.premiumDark,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildAppBar(context),
              Expanded(child: _buildList()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return const SettingsInnerAppBar(
      title: 'Notifications',
      showLogo: false,
    );
  }

  Widget _buildList() {
    return StreamBuilder<List<AppNotification>>(
      stream: NotificationService().watchMyNotifications(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                messageForFirestore(snapshot.error),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
          );
        }
        final list = snapshot.data ?? const <AppNotification>[];
        _autoMarkVisibleAsRead(list);
        if (list.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.notifications_none_rounded,
                  color: Colors.white,
                  size: 28,
                ),
                const SizedBox(height: 16),
                const Text(
                  'No new notifications',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "You're all caught up!",
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          );
        }
        final me = AuthService().currentUser?.uid ?? '';
        if (me.isEmpty) {
          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: const <Widget>[],
          );
        }

        return StreamBuilder<AppUserModel?>(
          stream: UserService().userStream(me),
          builder: (context, meSnapshot) {
            final following = meSnapshot.data?.following ?? const <String>[];
            final followedUserIds = following.toSet();
            final sections = <String, List<AppNotification>>{};
            for (final n in list) {
              final key = _sectionFor(n.createdAt);
              sections.putIfAbsent(key, () => <AppNotification>[]).add(n);
            }
            final rows = <Widget>[];
            for (final key in ['Today', 'Yesterday', 'Last 7 days', 'Earlier']) {
              final items = sections[key];
              if (items == null || items.isEmpty) continue;
              rows.add(_buildSectionHeader(key));
              rows.add(const SizedBox(height: 12));
              for (final item in items) {
                final targetUid = item.senderId.trim();
                final isFollowed = targetUid.isNotEmpty &&
                    (followedUserIds.contains(targetUid) ||
                        _followBackInFlight.contains(targetUid));
                final isFollowingInProgress = _followBackInFlight.contains(targetUid);
                if (item.type == AppNotificationType.followRequest) {
                  final rid = item.recipientId.trim();
                  final sid = item.senderId.trim();
                  if (rid.isEmpty || sid.isEmpty) {
                    rows.add(
                      _NotifTile(
                        item: item,
                        isFollowed: isFollowed,
                        isFollowingInProgress: isFollowingInProgress,
                        showFollowRequestActions: false,
                        onTap: () => _handleOpen(item),
                        onFollowBack: () => _handleFollowBack(item),
                        onReply: () => _handleReply(item),
                        onAcceptFollowRequest: () =>
                            _handleAcceptFollowRequest(item),
                        onDeclineFollowRequest: () =>
                            _handleDeclineFollowRequest(item),
                      ),
                    );
                  } else {
                    rows.add(
                      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('follow_requests')
                            .doc(UserService.followRequestDocId(sid, rid))
                            .snapshots(),
                        builder: (context, snap) {
                          final showActions =
                              _followRequestActionsStillPending(snap);
                          return _NotifTile(
                            item: item,
                            isFollowed: isFollowed,
                            isFollowingInProgress: isFollowingInProgress,
                            showFollowRequestActions: showActions,
                            onTap: () => _handleOpen(item),
                            onFollowBack: () => _handleFollowBack(item),
                            onReply: () => _handleReply(item),
                            onAcceptFollowRequest: () =>
                                _handleAcceptFollowRequest(item),
                            onDeclineFollowRequest: () =>
                                _handleDeclineFollowRequest(item),
                          );
                        },
                      ),
                    );
                  }
                } else {
                  rows.add(
                    _NotifTile(
                      item: item,
                      isFollowed: isFollowed,
                      isFollowingInProgress: isFollowingInProgress,
                      onTap: () => _handleOpen(item),
                      onFollowBack: () => _handleFollowBack(item),
                      onReply: () => _handleReply(item),
                      onAcceptFollowRequest: () =>
                          _handleAcceptFollowRequest(item),
                      onDeclineFollowRequest: () =>
                          _handleDeclineFollowRequest(item),
                    ),
                  );
                }
                rows.add(const SizedBox(height: 20));
              }
              rows.add(const SizedBox(height: 4));
            }
            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: rows,
            );
          },
        );
      },
    );
  }

  Future<void> _handleOpen(AppNotification item) async {
    await NotificationService().markAsRead(item.id);
  }

  Future<void> _handleAcceptFollowRequest(AppNotification item) async {
    await NotificationService().markAsRead(item.id);
    final me = AuthService().currentUser?.uid ?? '';
    final requesterUid = item.senderId.trim();
    if (me.isEmpty || requesterUid.isEmpty || me == requesterUid) return;
    try {
      await UserService().acceptFollowRequest(
        ownerUid: me,
        requesterUid: requesterUid,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Follow request accepted.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(messageForFirestore(e)),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleDeclineFollowRequest(AppNotification item) async {
    await NotificationService().markAsRead(item.id);
    final me = AuthService().currentUser?.uid ?? '';
    final requesterUid = item.senderId.trim();
    if (me.isEmpty || requesterUid.isEmpty) return;
    try {
      await UserService().declineFollowRequest(
        ownerUid: me,
        requesterUid: requesterUid,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Follow request declined.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(messageForFirestore(e)),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleFollowBack(AppNotification item) async {
    await NotificationService().markAsRead(item.id);
    final me = AuthService().currentUser?.uid ?? '';
    final targetUid = item.senderId.trim();
    if (me.isEmpty || targetUid.isEmpty || me == targetUid) return;
    if (_followBackInFlight.contains(targetUid)) return;
    final alreadyFollowing = await UserService().isFollowingUser(
      currentUid: me,
      targetUid: targetUid,
    );
    if (alreadyFollowing) return;
    setState(() => _followBackInFlight.add(targetUid));
    try {
      await UserService().followUser(currentUid: me, targetUid: targetUid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Followed back.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not follow back right now.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _followBackInFlight.remove(targetUid));
      } else {
        _followBackInFlight.remove(targetUid);
      }
    }
  }

  Future<void> _handleReply(AppNotification item) async {
    await NotificationService().markAsRead(item.id);
    final storyId = item.storyId.trim();
    if (storyId.isNotEmpty) {
      if (!mounted) return;
      showStoryCommentsBottomSheet(context, storyId: storyId);
      return;
    }
    final reelId = item.reelId.trim();
    if (reelId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Post not available for this notification.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (!mounted) return;
    showCommentsBottomSheet(context, reelId: reelId);
  }

  String _sectionFor(DateTime createdAt) {
    final now = DateTime.now();
    final age = now.difference(createdAt);
    if (age.inDays == 0) return 'Today';
    if (age.inDays == 1) return 'Yesterday';
    if (age.inDays < 7) return 'Last 7 days';
    return 'Earlier';
  }

  Widget _buildSectionHeader(String label) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Colors.white.withValues(alpha: 0.55),
      ),
    );
  }

  /// Accept/Decline only while `follow_requests/{requester}_{recipient}` exists
  /// with `status == pending` (accept triggers CF delete; decline deletes client-side).
  bool _followRequestActionsStillPending(
    AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snap,
  ) {
    if (snap.hasError) return false;
    if (!snap.hasData) return true;
    final doc = snap.data!;
    if (!doc.exists) return false;
    final st = (doc.data()?['status'] as String?)?.trim() ?? '';
    return st == 'pending';
  }

  void _autoMarkVisibleAsRead(List<AppNotification> list) {
    if (_isMarkingVisibleAsRead || list.isEmpty) return;
    final unreadIds = list
        .where((n) => !n.isRead)
        .map((n) => n.id)
        .where((id) => id.trim().isNotEmpty)
        .toList();
    if (unreadIds.isEmpty) return;
    _isMarkingVisibleAsRead = true;
    Future.microtask(() async {
      try {
        await NotificationService().markAsReadBulk(unreadIds);
      } finally {
        _isMarkingVisibleAsRead = false;
      }
    });
  }
}

class _NotifTile extends StatelessWidget {
  const _NotifTile({
    required this.item,
    required this.isFollowed,
    required this.isFollowingInProgress,
    required this.onTap,
    this.showFollowRequestActions = true,
    this.onFollowBack,
    this.onReply,
    this.onAcceptFollowRequest,
    this.onDeclineFollowRequest,
  });

  final AppNotification item;
  final bool isFollowed;
  final bool isFollowingInProgress;
  /// When false, hide Accept/Decline for [AppNotificationType.followRequest] rows.
  final bool showFollowRequestActions;
  final VoidCallback onTap;
  final VoidCallback? onFollowBack;
  final VoidCallback? onReply;
  final VoidCallback? onAcceptFollowRequest;
  final VoidCallback? onDeclineFollowRequest;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildAvatar(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${item.actorUsername.isNotEmpty ? item.actorUsername : 'Someone'} ${item.message}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _timeAgo(item.createdAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _buildActionButton(),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    if (item.actorAvatarUrl.isEmpty) {
      return Container(
        width: 46,
        height: 46,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF490038), Color(0xFFDE106B)],
          ),
        ),
        child: Center(
          child: Image.asset(
            'assets/BrandLogo/Vyooo logo (2).png',
            width: 26,
            height: 26,
            fit: BoxFit.contain,
            errorBuilder: (context0, err, stack) => const Text(
              'V',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ),
      );
    }

    return ClipOval(
      child: Container(
        width: 46,
        height: 46,
        color: Colors.white.withValues(alpha: 0.15),
        child: Image.network(
          item.actorAvatarUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Icon(
            Icons.person_rounded,
            color: Colors.white.withValues(alpha: 0.6),
            size: 24,
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton() {
    switch (item.type.name) {
      case 'follow':
        if (isFollowed) {
          return _OutlinePillButton(
            label: isFollowingInProgress ? 'Following...' : 'Followed',
            onTap: null,
          );
        }
        return _PinkPillButton(label: 'Follow back', onTap: onFollowBack ?? onTap);
      case 'followRequest':
        if (!showFollowRequestActions) {
          return const SizedBox.shrink();
        }
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _OutlinePillButton(
              label: 'Decline',
              onTap: onDeclineFollowRequest ?? onTap,
            ),
            const SizedBox(width: 8),
            _PinkPillButton(
              label: 'Accept',
              onTap: onAcceptFollowRequest ?? onTap,
            ),
          ],
        );
      case 'followRequestAccepted':
        return const SizedBox.shrink();
      case 'comment':
        return _OutlinePillButton(
          label: 'Reply',
          onTap: onReply ?? onTap,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  String _timeAgo(DateTime createdAt) {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'Now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}

class _PinkPillButton extends StatelessWidget {
  const _PinkPillButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.brandPink,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _OutlinePillButton extends StatelessWidget {
  const _OutlinePillButton({required this.label, this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.85),
          ),
        ),
      ),
    );
  }
}
