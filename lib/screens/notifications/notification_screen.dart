import 'package:flutter/material.dart';
import 'package:vyooo/core/widgets/app_gradient_background.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/notification_service.dart';

/// Notifications tab: grouped by Today / Yesterday / Last 7 days.
class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen>
    with AutomaticKeepAliveClientMixin {
  bool _isMarkingVisibleAsRead = false;

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
    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 16, top: 4, bottom: 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              if (Navigator.of(context).canPop()) Navigator.of(context).pop();
            },
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 20,
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
    return StreamBuilder<List<AppNotification>>(
      stream: NotificationService().watchMyNotifications(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Could not load notifications.\nCheck Firestore rules/deploy and try again.',
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
            rows.add(
              _NotifTile(
                item: item,
                onTap: () => NotificationService().markAsRead(item.id),
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
      },
    );
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
  const _NotifTile({required this.item, required this.onTap});

  final AppNotification item;
  final VoidCallback onTap;

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
        return _PinkPillButton(label: 'Follow back', onTap: onTap);
      case 'comment':
        return _OutlinePillButton(label: 'Reply');
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
