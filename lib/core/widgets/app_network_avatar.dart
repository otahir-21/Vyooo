import 'package:flutter/material.dart';

import '../services/storage_service.dart';

/// Circular avatar that loads a network image and, on failure, can refresh
/// from Firebase Storage when [userId] is provided (handles expired tokens).
class AppNetworkAvatar extends StatefulWidget {
  const AppNetworkAvatar({
    super.key,
    required this.imageUrl,
    this.userId,
    required this.size,
    this.fallback,
    this.fit = BoxFit.cover,
  });

  final String imageUrl;
  final String? userId;
  final double size;
  final Widget? fallback;
  final BoxFit fit;

  @override
  State<AppNetworkAvatar> createState() => _AppNetworkAvatarState();
}

class _AppNetworkAvatarState extends State<AppNetworkAvatar> {
  String? _url;
  bool _storageRefreshAttempted = false;

  @override
  void initState() {
    super.initState();
    _url = _normalizeUrl(widget.imageUrl);
    _maybeRefreshFromStorage();
  }

  @override
  void didUpdateWidget(covariant AppNetworkAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl ||
        oldWidget.userId != widget.userId) {
      _url = _normalizeUrl(widget.imageUrl);
      _storageRefreshAttempted = false;
      _maybeRefreshFromStorage();
    }
  }

  String? _normalizeUrl(String raw) {
    final url = raw.trim();
    if (url.isEmpty) return null;
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.isAbsolute || uri.host.isEmpty) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;
    return url;
  }

  Widget _defaultFallback() {
    return Icon(
      Icons.person_rounded,
      color: Colors.white.withValues(alpha: 0.6),
      size: widget.size * 0.52,
    );
  }

  void _maybeRefreshFromStorage() {
    final uid = widget.userId?.trim();
    if (uid == null || uid.isEmpty || _storageRefreshAttempted) return;
    if (_url != null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshFromStorage());
  }

  Future<void> _refreshFromStorage() async {
    if (_storageRefreshAttempted) return;
    final uid = widget.userId?.trim();
    if (uid == null || uid.isEmpty) return;
    _storageRefreshAttempted = true;
    try {
      final fresh = await StorageService().getProfileImageUrl(uid);
      if (!mounted || fresh == null) return;
      final normalized = _normalizeUrl(fresh);
      if (normalized == null || normalized == _url) return;
      setState(() => _url = normalized);
    } catch (_) {}
  }

  void _handleImageError() {
    if (_storageRefreshAttempted) return;
    final uid = widget.userId?.trim();
    if (uid == null || uid.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshFromStorage());
  }

  @override
  Widget build(BuildContext context) {
    final fallback = widget.fallback ?? _defaultFallback();
    final url = _url;
    if (url == null) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: fallback,
      );
    }

    return ClipOval(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Image.network(
          url,
          key: ValueKey<String>(url),
          fit: widget.fit,
          errorBuilder: (context, error, stackTrace) {
            _handleImageError();
            return fallback;
          },
        ),
      ),
    );
  }
}
