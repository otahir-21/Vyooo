import 'package:flutter/material.dart';

import '../../../screens/profile/profile_figma_tokens.dart';
import '../../utils/user_facing_errors.dart';
import 'profile_modular_grid.dart';
import 'profile_posts_loader.dart';

/// Profile Posts tab grid. Caches its [Future] so parent rebuilds do not refetch Firestore.
class ProfileCachedPostsGrid extends StatefulWidget {
  const ProfileCachedPostsGrid({
    super.key,
    required this.userId,
    required this.thumbnailFor,
    required this.onItemTap,
    this.onItemLongPress,
    this.gap,
    this.padding = EdgeInsets.zero,
    this.loadingHeight = 200,
    this.empty,
  });

  final String userId;
  final String Function(Map<String, dynamic> reel) thumbnailFor;
  final void Function(
    BuildContext context,
    List<Map<String, dynamic>> posts,
    int index,
  ) onItemTap;
  final void Function(
    BuildContext context,
    List<Map<String, dynamic>> posts,
    int index,
  )? onItemLongPress;
  final double? gap;
  final EdgeInsetsGeometry padding;
  final double loadingHeight;
  final Widget? empty;

  @override
  State<ProfileCachedPostsGrid> createState() => ProfileCachedPostsGridState();

  /// Drop cache so the next mount refetches (e.g. after upload/delete).
  static void invalidateCacheFor(String uid) {
    ProfileCachedPostsGridState.invalidateFor(uid);
  }
}

class ProfileCachedPostsGridState extends State<ProfileCachedPostsGrid> {
  static final Map<String, Future<List<Map<String, dynamic>>>> _cache = {};
  static final Map<String, List<VoidCallback>> _reloadListeners = {};

  static void invalidateFor(String uid) {
    final key = uid.trim();
    _cache.remove(key);
    _notifyReload(key);
  }

  static void patchPostInCache({
    required String uid,
    required String reelId,
    String? profileGridSpan,
    String? profileGridTitle,
    String? profileGridThumbnailUrl,
  }) {
    final key = uid.trim();
    final future = _cache[key];
    if (future == null) {
      _notifyReload(key);
      return;
    }
    future.then((posts) {
      final index = posts.indexWhere(
        (p) => (p['id'] as String? ?? '').trim() == reelId.trim(),
      );
      if (index >= 0) {
        if (profileGridSpan != null) {
          posts[index]['profileGridSpan'] = profileGridSpan;
        }
        if (profileGridTitle != null) {
          posts[index]['profileGridTitle'] = profileGridTitle;
        }
        if (profileGridThumbnailUrl != null) {
          posts[index]['profileGridThumbnailUrl'] = profileGridThumbnailUrl;
        }
      }
      _notifyReload(key);
    });
  }

  static void _notifyReload(String uid) {
    final listeners = _reloadListeners[uid];
    if (listeners == null) return;
    for (final listener in List<VoidCallback>.from(listeners)) {
      listener();
    }
  }

  late Future<List<Map<String, dynamic>>> _postsFuture;
  List<Map<String, dynamic>>? _posts;

  @override
  void initState() {
    super.initState();
    _bindFuture();
    _registerReloadListener();
  }

  @override
  void didUpdateWidget(ProfileCachedPostsGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _unregisterReloadListener(oldWidget.userId);
      _registerReloadListener();
      _bindFuture();
    }
  }

  @override
  void dispose() {
    _unregisterReloadListener(widget.userId);
    super.dispose();
  }

  void _registerReloadListener() {
    final uid = widget.userId.trim();
    if (uid.isEmpty) return;
    _reloadListeners.putIfAbsent(uid, () => []).add(_onReloadRequested);
  }

  void _unregisterReloadListener(String uid) {
    final key = uid.trim();
    _reloadListeners[key]?.remove(_onReloadRequested);
  }

  void _onReloadRequested() {
    if (!mounted) return;
    final future = _cache[widget.userId.trim()];
    if (future != null) {
      future.then((posts) {
        if (!mounted) return;
        setState(() => _posts = List<Map<String, dynamic>>.from(posts));
      });
      return;
    }
    setState(_bindFuture);
  }

  void _bindFuture() {
    final uid = widget.userId.trim();
    _postsFuture = _cache.putIfAbsent(
      uid,
      () => ProfilePostsLoader.loadPostsForUser(uid),
    );
    _postsFuture.then((posts) {
      if (!mounted) return;
      setState(() => _posts = List<Map<String, dynamic>>.from(posts));
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_posts == null) {
      return FutureBuilder<List<Map<String, dynamic>>>(
        future: _postsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return _loading();
          }
          if (snapshot.hasError) {
            return _error(snapshot.error);
          }
          final posts = snapshot.data ?? const [];
          if (posts.isEmpty) {
            return widget.empty ?? const SizedBox.shrink();
          }
          return _grid(context, posts);
        },
      );
    }

    if (_posts!.isEmpty) {
      return widget.empty ?? const SizedBox.shrink();
    }
    return _grid(context, _posts!);
  }

  Widget _grid(BuildContext context, List<Map<String, dynamic>> posts) {
    return ProfileModularGrid(
      gap: widget.gap ?? ProfileFigmaTokens.contentGridGap,
      padding: widget.padding,
      items: profileGridItemsFromReels(
        reels: posts,
        thumbnailFor: widget.thumbnailFor,
      ),
      onItemTap: (index) => widget.onItemTap(context, posts, index),
      onItemLongPress: widget.onItemLongPress != null
          ? (index) => widget.onItemLongPress!(context, posts, index)
          : null,
    );
  }

  Widget _loading() {
    return SizedBox(
      height: widget.loadingHeight,
      child: const Center(
        child: CircularProgressIndicator(color: Colors.white54),
      ),
    );
  }

  Widget _error(Object? error) {
    debugPrint('Profile posts error: $error');
    return SizedBox(
      height: widget.loadingHeight,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            messageForFirestore(error),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.65),
              fontSize: 14,
              height: 1.35,
            ),
          ),
        ),
      ),
    );
  }
}
