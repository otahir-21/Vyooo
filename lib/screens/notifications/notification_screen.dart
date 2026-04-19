import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_gradient_background.dart';

/// Notification types that drive avatar and action button rendering.
enum _NotifType { follow, like, comment, system, live, post }

/// Follow-back state for follow notifications.
enum _FollowState { none, canFollowBack, alreadyFollowing }

class _NotifItem {
  const _NotifItem({
    required this.type,
    required this.message,
    required this.timeAgo,
    this.avatarUrl,
    this.followState = _FollowState.none,
    this.isSystem = false,
  });

  final _NotifType type;
  final String message;
  final String timeAgo;
  final String? avatarUrl;
  final _FollowState followState;
  final bool isSystem;
}

/// Notifications tab: grouped by Today / Yesterday / Last 7 days.
/// Matches Figma: action buttons (Follow back, Following, Reply), VyooO system avatar.
class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final Map<int, bool> _followedBack = {};

  static const List<_NotifItem> _today = [
    _NotifItem(
      type: _NotifType.follow,
      avatarUrl: 'https://i.pravatar.cc/80?img=33',
      message: 'Dennis_Nedry followed you.',
      timeAgo: '2h',
      followState: _FollowState.canFollowBack,
    ),
    _NotifItem(
      type: _NotifType.like,
      avatarUrl: 'https://i.pravatar.cc/80?img=24',
      message: 'Lexilongbottom liked your post.',
      timeAgo: '2h',
    ),
    _NotifItem(
      type: _NotifType.comment,
      avatarUrl: 'https://i.pravatar.cc/80?img=12',
      message: 'Haridesigno commented: Nicce🔥 on your post.',
      timeAgo: '2h',
    ),
  ];

  static const List<_NotifItem> _yesterday = [
    _NotifItem(
      type: _NotifType.follow,
      avatarUrl: 'https://i.pravatar.cc/80?img=47',
      message: '__sath__ followed you.',
      timeAgo: '1d',
      followState: _FollowState.alreadyFollowing,
    ),
    _NotifItem(
      type: _NotifType.like,
      avatarUrl: 'https://i.pravatar.cc/80?img=5',
      message: 'chilly liked your post.',
      timeAgo: '1d',
    ),
    _NotifItem(
      type: _NotifType.system,
      message: 'You received 1k likes on your post.',
      timeAgo: '3d',
      isSystem: true,
    ),
  ];

  static const List<_NotifItem> _lastWeek = [
    _NotifItem(
      type: _NotifType.live,
      avatarUrl: 'https://i.pravatar.cc/80?img=62',
      message: 'mattrife_x has started his live now. Check it out!',
      timeAgo: '4d',
    ),
    _NotifItem(
      type: _NotifType.post,
      avatarUrl: 'https://i.pravatar.cc/80?img=41',
      message: 'Samay Raina added a new post.',
      timeAgo: '5d',
    ),
    _NotifItem(
      type: _NotifType.system,
      message: 'You received 1k likes on your post.',
      timeAgo: '6d',
      isSystem: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppGradientBackground(
        type: GradientType.feed,
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
    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 16, top: 4, bottom: 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              if (Navigator.of(context).canPop()) Navigator.of(context).pop();
            },
            icon: Image.asset(
              'assets/vyooO_icons/Home/chevron_left.png',
              width: 22,
              height: 22,
              color: Colors.white,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          ),
          const Text(
            'Notifications',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    // Assign each item a global index for follow-back state tracking
    int globalIndex = 0;
    final List<Widget> rows = [];

    for (final section in [
      ('Today', _today),
      ('Yesterday', _yesterday),
      ('Last 7 days', _lastWeek),
    ]) {
      final label = section.$1;
      final items = section.$2;

      rows.add(_buildSectionHeader(label));
      rows.add(const SizedBox(height: 12));

      for (final item in items) {
        final idx = globalIndex++;
        rows.add(
          _NotifTile(
            item: item,
            followedBack: _followedBack[idx] ?? false,
            onFollowBack: () => setState(() => _followedBack[idx] = true),
          ),
        );
        rows.add(const SizedBox(height: 20));
      }

      rows.add(const SizedBox(height: 4));
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: rows,
    );
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
}

class _NotifTile extends StatelessWidget {
  const _NotifTile({
    required this.item,
    required this.followedBack,
    required this.onFollowBack,
  });

  final _NotifItem item;
  final bool followedBack;
  final VoidCallback onFollowBack;

  @override
  Widget build(BuildContext context) {
    return Row(
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
                item.message,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                item.timeAgo,
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
    );
  }

  Widget _buildAvatar() {
    if (item.isSystem) {
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

    return CircleAvatar(
      radius: 23,
      backgroundColor: Colors.white.withValues(alpha: 0.15),
      backgroundImage: item.avatarUrl != null
          ? NetworkImage(item.avatarUrl!)
          : null,
      child: item.avatarUrl == null
          ? Icon(
              Icons.person_rounded,
              color: Colors.white.withValues(alpha: 0.6),
              size: 24,
            )
          : null,
    );
  }

  Widget _buildActionButton() {
    switch (item.type) {
      case _NotifType.follow:
        if (item.followState == _FollowState.canFollowBack) {
          return followedBack
              ? _OutlinePillButton(label: 'Following')
              : _PinkPillButton(label: 'Follow back', onTap: onFollowBack);
        }
        if (item.followState == _FollowState.alreadyFollowing) {
          return _OutlinePillButton(label: 'Following');
        }
        return const SizedBox.shrink();
      case _NotifType.comment:
        return _OutlinePillButton(label: 'Reply');
      default:
        return const SizedBox.shrink();
    }
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
  const _OutlinePillButton({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
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
    );
  }
}
