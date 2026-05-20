import 'package:flutter/material.dart';

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

  static void invalidateFor(String uid) {
    _cache.remove(uid);
  }

  late Future<List<Map<String, dynamic>>> _postsFuture;

  @override
  void initState() {
    super.initState();
    _bindFuture();
  }

  @override
  void didUpdateWidget(ProfileCachedPostsGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _bindFuture();
    }
  }

  void _bindFuture() {
    final uid = widget.userId.trim();
    _postsFuture = _cache.putIfAbsent(
      uid,
      () => ProfilePostsLoader.loadPostsForUser(uid),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _postsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return SizedBox(
            height: widget.loadingHeight,
            child: const Center(
              child: CircularProgressIndicator(color: Colors.white54),
            ),
          );
        }
        if (snapshot.hasError) {
          debugPrint('Profile posts error: ${snapshot.error}');
          return SizedBox(
            height: widget.loadingHeight,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  messageForFirestore(snapshot.error),
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
        final posts = snapshot.data ?? const [];
        if (posts.isEmpty) {
          return widget.empty ?? const SizedBox.shrink();
        }
        return ProfileModularGrid(
          gap: widget.gap ?? 0,
          padding: widget.padding,
          items: profileGridItemsFromReels(
            reels: posts,
            thumbnailFor: widget.thumbnailFor,
          ),
          onItemTap: (index) => widget.onItemTap(context, posts, index),
        );
      },
    );
  }
}
