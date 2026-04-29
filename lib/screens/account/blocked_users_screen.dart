import 'package:flutter/material.dart';

import '../../core/models/app_user_model.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/user_service.dart';
import '../../core/utils/user_facing_errors.dart';
import '../../core/widgets/app_gradient_background.dart';

/// Lists users blocked by the current account (Firestore: users/{uid}.blockedUsers).
class BlockedUsersScreen extends StatelessWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = AuthService().currentUser?.uid;

    return Scaffold(
      body: AppGradientBackground(
        type: GradientType.premiumDark,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _BlockedUsersAppBar(onBack: () => Navigator.pop(context)),
              Expanded(
                child: uid == null || uid.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Sign in to view and manage blocked accounts.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white70, fontSize: 16),
                          ),
                        ),
                      )
                    : StreamBuilder<AppUserModel?>(
                        stream: UserService().userStream(uid),
                        builder: (context, snap) {
                          if (snap.connectionState == ConnectionState.waiting && snap.data == null) {
                            return const Center(
                              child: CircularProgressIndicator(color: Colors.white54),
                            );
                          }
                          final blockedIds = snap.data?.blockedUsers ?? [];
                          if (blockedIds.isEmpty) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: Text(
                                  'You haven’t blocked anyone yet.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.white70, fontSize: 16),
                                ),
                              ),
                            );
                          }
                          return FutureBuilder<List<_BlockedListRow>>(
                            key: ValueKey<String>(blockedIds.join(',')),
                            future: _loadBlockedRows(blockedIds),
                            builder: (context, rowSnap) {
                              if (!rowSnap.hasData) {
                                return const Center(
                                  child: CircularProgressIndicator(color: Colors.white54),
                                );
                              }
                              final rows = rowSnap.data!;
                              return ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                itemCount: rows.length,
                                itemBuilder: (context, index) {
                                  final row = rows[index];
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 18,
                                          backgroundColor: Colors.white24,
                                          backgroundImage: row.avatarUrl.isNotEmpty
                                              ? NetworkImage(row.avatarUrl)
                                              : null,
                                          child: row.avatarUrl.isEmpty
                                              ? const Icon(Icons.person_rounded, color: Colors.white54)
                                              : null,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                row.title,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                  letterSpacing: -0.2,
                                                ),
                                              ),
                                              if (row.subtitle.isNotEmpty)
                                                Text(
                                                  row.subtitle,
                                                  style: TextStyle(
                                                    color: Colors.white
                                                        .withValues(
                                                          alpha: 0.65,
                                                        ),
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w400,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            onTap: () =>
                                                _onUnblock(context, meUid: uid, targetUid: row.uid),
                                            borderRadius: BorderRadius.circular(20),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 16,
                                                vertical: 8,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(20),
                                              ),
                                              child: const Text(
                                                'Unblock',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Future<List<_BlockedListRow>> _loadBlockedRows(List<String> ids) async {
    final svc = UserService();
    final users = await svc.getUsersByIds(ids);
    final byId = <String, AppUserModel>{for (final u in users) u.uid: u};
    final rows = <_BlockedListRow>[];
    for (final id in ids) {
      final u = byId[id];
      final handle = u?.username?.trim() ?? '';
      final displayName = u?.displayName?.trim() ?? '';
      final title = displayName.isNotEmpty
          ? displayName
          : (handle.isNotEmpty ? '@$handle' : id);
      final subtitle = handle.isNotEmpty && displayName.isNotEmpty
          ? '@$handle'
          : '';
      rows.add(
        _BlockedListRow(
          uid: id,
          title: title,
          subtitle: subtitle,
          avatarUrl: u?.profileImage?.trim() ?? '',
        ),
      );
    }
    return rows;
  }

  static Future<void> _onUnblock(
    BuildContext context, {
    required String meUid,
    required String targetUid,
  }) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await UserService().unblockUser(currentUid: meUid, targetUid: targetUid);
      messenger?.showSnackBar(const SnackBar(content: Text('Unblocked.')));
    } catch (e) {
      messenger?.showSnackBar(SnackBar(content: Text(messageForFirestore(e))));
    }
  }
}

class _BlockedListRow {
  const _BlockedListRow({
    required this.uid,
    required this.title,
    required this.subtitle,
    required this.avatarUrl,
  });
  final String uid;
  final String title;
  final String subtitle;
  final String avatarUrl;
}

class _BlockedUsersAppBar extends StatelessWidget {
  const _BlockedUsersAppBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: onBack,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 22),
                SizedBox(width: 12),
                Text(
                  'Blocked Users',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          const Text(
            'VyooO',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}
