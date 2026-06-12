import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../utils/internet_availability.dart';
import 'auth_service.dart';
import 'feed_offline_video_cache.dart';
import 'feed_reels_cache_service.dart';
import 'reel_preload_service.dart';
import 'reels_service.dart';
import 'user_service.dart';

/// Result of a feed warm-up run: the same data [HomeReelsScreen._loadReels]
/// would have fetched for the For You tab.
class FeedWarmupResult {
  const FeedWarmupResult({
    required this.uid,
    required this.blockedIds,
    required this.forYou,
    required this.completedAt,
  });

  final String uid;
  final List<String> blockedIds;

  /// Block-filtered and repost-hydrated For You reels.
  final List<Map<String, dynamic>> forYou;
  final DateTime completedAt;
}

/// Prefetches the For You feed while the splash video plays so the feed is
/// already populated by the time [HomeReelsScreen] mounts.
///
/// Also persists the result to [FeedReelsCacheService] and kicks off
/// [FeedOfflineVideoCache] so the first reels are viewable with no internet.
class FeedWarmupService {
  FeedWarmupService._();
  static final FeedWarmupService instance = FeedWarmupService._();

  /// Warmed data older than this is discarded; the feed fetches fresh instead.
  static const Duration _maxResultAge = Duration(minutes: 3);

  Future<FeedWarmupResult?>? _pending;

  /// Starts the warm-up once; later calls are no-ops.
  void start() {
    _pending ??= _run();
  }

  /// Hands the warmed feed to the first caller and clears it, so pull-to-refresh
  /// and later reloads always hit the network.
  Future<FeedWarmupResult?> consume() async {
    final pending = _pending;
    if (pending == null) return null;
    _pending = null;
    final result = await pending;
    if (result == null || result.forYou.isEmpty) return null;
    if (DateTime.now().difference(result.completedAt) > _maxResultAge) {
      return null;
    }
    return result;
  }

  Future<FeedWarmupResult?> _run() async {
    try {
      await _waitForAuthRestore();
      if (!await hasInternetAccess()) return null;

      final uid = AuthService().currentUser?.uid ?? '';
      var blockedIds = const <String>[];
      if (uid.isNotEmpty) {
        blockedIds = await UserService().getBlockedUserIds(uid);
      }

      final reelsService = ReelsService();
      final raw = await reelsService.getReelsForYou();
      final filtered = raw.where((r) {
        final ownerId = (r['userId'] as String?) ?? '';
        return ownerId.isEmpty || !blockedIds.contains(ownerId);
      }).toList();
      final hydrated =
          await reelsService.hydrateRepostEngagementStats(filtered);

      if (hydrated.isNotEmpty) {
        unawaited(FeedReelsCacheService.instance.saveForYou(hydrated));
        unawaited(FeedOfflineVideoCache.instance.syncForFeed(hydrated));
        _preloadFirstVideo(hydrated);
      }

      return FeedWarmupResult(
        uid: uid,
        blockedIds: blockedIds,
        forYou: hydrated,
        completedAt: DateTime.now(),
      );
    } catch (e) {
      debugPrint('FeedWarmupService warm-up failed: $e');
      return null;
    }
  }

  /// Pre-initializes the first reel's player while the splash video is still
  /// on screen so the feed starts playing the moment it appears.
  void _preloadFirstVideo(List<Map<String, dynamic>> reels) {
    for (final reel in reels) {
      final mediaType =
          ((reel['mediaType'] as String?) ?? 'video').toLowerCase();
      if (mediaType != 'video') continue;
      final videoUrl = ((reel['videoUrl'] as String?) ?? '').trim();
      if (videoUrl.isEmpty) continue;
      ReelPreloadService.instance.preload(videoUrl);
      return;
    }
  }

  /// FirebaseAuth restores the signed-in user asynchronously on cold start;
  /// the reels query must run with auth attached or security rules reject it.
  Future<void> _waitForAuthRestore() async {
    try {
      await FirebaseAuth.instance
          .authStateChanges()
          .first
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      // Proceed unauthenticated; the query itself degrades gracefully.
    }
  }
}
