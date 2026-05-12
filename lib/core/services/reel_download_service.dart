import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local offline copies of reel media (app sandbox only). Metadata is not synced to Firestore.
class ReelDownloadService {
  ReelDownloadService._();
  static final ReelDownloadService instance = ReelDownloadService._();

  static const _prefsKey = 'offline_reel_downloads_v1';

  Future<Directory> _rootDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/offline_reels');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<List<DownloadedReelEntry>> listDownloads() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final out = <DownloadedReelEntry>[];
      for (final e in list) {
        if (e is! Map<String, dynamic>) continue;
        out.add(DownloadedReelEntry.fromJson(e));
      }
      return out;
    } catch (_) {
      return [];
    }
  }

  Future<void> _persist(List<DownloadedReelEntry> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode(items.map((e) => e.toJson()).toList()),
    );
  }

  /// Downloads remote video to app documents and registers it for the Downloaded screen.
  Future<bool> downloadVideo({
    required String reelId,
    required String videoUrl,
    String thumbnailUrl = '',
  }) async {
    final id = reelId.trim();
    final url = videoUrl.trim();
    if (id.isEmpty || url.isEmpty) return false;
    try {
      final existing = await listDownloads();
      if (existing.any((e) => e.reelId == id)) {
        return true;
      }
      final uri = Uri.tryParse(url);
      if (uri == null || !uri.hasScheme) return false;
      final res = await http.get(uri);
      if (res.statusCode < 200 || res.statusCode >= 300) return false;

      final dir = await _rootDir();
      final safeExt = _extensionFromUrl(url);
      final file = File('${dir.path}/$id$safeExt');
      await file.writeAsBytes(res.bodyBytes, flush: true);

      final next = [
        ...existing,
        DownloadedReelEntry(
          reelId: id,
          localPath: file.path,
          thumbnailUrl: thumbnailUrl.trim(),
          downloadedAtMs: DateTime.now().millisecondsSinceEpoch,
        ),
      ];
      next.sort((a, b) => b.downloadedAtMs.compareTo(a.downloadedAtMs));
      await _persist(next);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> removeDownload(String reelId) async {
    final id = reelId.trim();
    if (id.isEmpty) return;
    final items = await listDownloads();
    final kept = <DownloadedReelEntry>[];
    for (final e in items) {
      if (e.reelId == id) {
        try {
          final f = File(e.localPath);
          if (await f.exists()) await f.delete();
        } catch (_) {}
      } else {
        kept.add(e);
      }
    }
    await _persist(kept);
  }

  static String _extensionFromUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.pathSegments.isEmpty) return '.mp4';
    final seg = uri.pathSegments.last;
    final dot = seg.lastIndexOf('.');
    if (dot > 0 && dot < seg.length - 1) {
      final ext = seg.substring(dot).toLowerCase();
      if (ext.length >= 2 && ext.length <= 6) return ext;
    }
    return '.mp4';
  }
}

class DownloadedReelEntry {
  const DownloadedReelEntry({
    required this.reelId,
    required this.localPath,
    required this.thumbnailUrl,
    required this.downloadedAtMs,
  });

  final String reelId;
  final String localPath;
  final String thumbnailUrl;
  final int downloadedAtMs;

  Map<String, dynamic> toJson() => {
        'reelId': reelId,
        'localPath': localPath,
        'thumbnailUrl': thumbnailUrl,
        'downloadedAtMs': downloadedAtMs,
      };

  factory DownloadedReelEntry.fromJson(Map<String, dynamic> m) {
    return DownloadedReelEntry(
      reelId: (m['reelId'] as String?) ?? '',
      localPath: (m['localPath'] as String?) ?? '',
      thumbnailUrl: (m['thumbnailUrl'] as String?) ?? '',
      downloadedAtMs: (m['downloadedAtMs'] as num?)?.toInt() ?? 0,
    );
  }
}
