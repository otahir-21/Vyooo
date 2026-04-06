import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../core/mock/mock_music_data.dart';
import '../../core/services/jamendo_service.dart';
import '../../core/theme/app_spacing.dart';
import 'add_audio_trim_screen.dart';

/// Add audio screen for video edit: search, For you/Trending/Saved tabs,
/// music list with real Jamendo tracks, audio preview via just_audio.
class AddAudioScreen extends StatefulWidget {
  const AddAudioScreen({super.key, this.videoAsset});

  final AssetEntity? videoAsset;

  @override
  State<AddAudioScreen> createState() => _AddAudioScreenState();
}

class _AddAudioScreenState extends State<AddAudioScreen> {
  static const List<String> _tabs = ['For you', 'Trending', 'Saved'];
  static const Color _pink = Color(0xFFDE106B);

  int _selectedTabIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _savedIds = {};

  List<MusicTrack> _forYouTracks = [];
  List<MusicTrack> _trendingTracks = [];
  bool _loading = true;

  MusicTrack? _playingTrack;
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  bool _navigating = false;

  @override
  void initState() {
    super.initState();
    _loadTracks();
    _player.playerStateStream.listen((state) {
      if (mounted) {
        setState(() => _isPlaying =
            state.playing &&
            state.processingState != ProcessingState.completed);
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTracks() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      JamendoService.instance.fetchForYou(),
      JamendoService.instance.fetchTrending(),
    ]);
    if (!mounted) return;
    setState(() {
      _forYouTracks = results[0];
      _trendingTracks = results[1];
      _loading = false;
    });
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      await _loadTracks();
      return;
    }
    setState(() => _loading = true);
    final results = await JamendoService.instance.search(query);
    if (!mounted) return;
    setState(() {
      _forYouTracks = results;
      _trendingTracks = results;
      _loading = false;
    });
  }

  List<MusicTrack> get _currentTracks {
    if (_selectedTabIndex == 2) {
      final allTracks = [..._forYouTracks, ..._trendingTracks];
      final seen = <String>{};
      return allTracks
          .where((t) => _savedIds.contains(t.id) && seen.add(t.id))
          .toList();
    }
    return _selectedTabIndex == 0 ? _forYouTracks : _trendingTracks;
  }

  Future<void> _playTrack(MusicTrack track) async {
    if (_playingTrack?.id == track.id) {
      // Toggle play/pause on same track
      if (_isPlaying) {
        await _player.pause();
      } else {
        await _player.play();
      }
      return;
    }
    setState(() => _playingTrack = track);
    try {
      if (track.audioUrl.isNotEmpty) {
        await _player.setUrl(track.audioUrl);
        await _player.play();
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E0A1E).withValues(alpha: 0.98),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTopBar(),
            const SizedBox(height: 8),
            _buildSearchBar(),
            const SizedBox(height: 16),
            _buildTabs(),
            const SizedBox(height: 8),
            Expanded(child: _buildTrackList()),
            if (_playingTrack != null) _buildMiniPlayer(),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: _search,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Search Music',
            hintStyle: TextStyle(
              color: Colors.white.withValues(alpha: 0.35),
              fontSize: 13,
            ),
            prefixIcon: Icon(
              Icons.search_rounded,
              color: Colors.white.withValues(alpha: 0.4),
              size: 20,
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(top: 12, bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(_tabs.length, (index) {
          final isSelected = index == _selectedTabIndex;
          return GestureDetector(
            onTap: () => setState(() => _selectedTabIndex = index),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? _pink : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _tabs[index],
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.5),
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTrackList() {
    if (_loading) {
      return const Center(
          child:
              CircularProgressIndicator(color: Color(0xFFDE106B)));
    }
    final tracks = _currentTracks;
    if (tracks.isEmpty) {
      return Center(
        child: Text(
          _selectedTabIndex == 2
              ? 'No saved tracks yet'
              : 'No tracks found',
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 14),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      itemCount: tracks.length,
      itemBuilder: (context, index) {
        final track = tracks[index];
        final isSelected = _playingTrack?.id == track.id;
        return _AddAudioListTile(
          track: track,
          isSelected: isSelected,
          isPlaying: isSelected && _isPlaying,
          isSaved: _savedIds.contains(track.id),
          onTap: () {
            if (widget.videoAsset != null) {
              if (_navigating) return;
              _navigating = true;
              _player.stop();
              Navigator.of(context)
                  .push<bool>(MaterialPageRoute(
                    builder: (_) => AddAudioTrimScreen(
                      track: track,
                      videoAsset: widget.videoAsset!,
                    ),
                  ))
                  .then((confirmed) {
                _navigating = false;
                if (!mounted) return;
                if (confirmed == true) {
                  // Return the selected track to EditVideoScreen
                  if (context.mounted) Navigator.of(context).pop(track);
                } else {
                  setState(() => _playingTrack = null);
                }
              });
            } else {
              _playTrack(track);
            }
          },
          onBookmarkTap: () => setState(() {
            if (_savedIds.contains(track.id)) {
              _savedIds.remove(track.id);
            } else {
              _savedIds.add(track.id);
            }
          }),
        );
      },
    );
  }

  Widget _buildMiniPlayer() {
    final t = _playingTrack!;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: _pink,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: t.albumArtUrl.isNotEmpty
                ? Image.network(t.albumArtUrl, width: 44, height: 44, fit: BoxFit.cover)
                : _placeholderArt(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.title,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  t.artist,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _isPlaying ? _player.pause() : _player.play(),
            child: Icon(_isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded, color: Colors.white, size: 36),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(t),
            child: const Icon(Icons.arrow_circle_right_rounded, color: Colors.white, size: 36),
          ),
        ],
      ),
    );
  }

  Widget _placeholderArt() => Container(
        width: 48,
        height: 48,
        color: Colors.white24,
        child: const Icon(Icons.music_note, color: Colors.white),
      );
}

// ── List tile ─────────────────────────────────────────────────────────────────

class _AddAudioListTile extends StatelessWidget {
  const _AddAudioListTile({
    required this.track,
    required this.isSelected,
    required this.isPlaying,
    required this.isSaved,
    required this.onTap,
    required this.onBookmarkTap,
  });

  final MusicTrack track;
  final bool isSelected;
  final bool isPlaying;
  final bool isSaved;
  final VoidCallback onTap;
  final VoidCallback onBookmarkTap;

  static const Color _pink = Color(0xFFDE106B);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: track.albumArtUrl.isNotEmpty
                  ? Image.network(track.albumArtUrl, width: 52, height: 52, fit: BoxFit.cover)
                  : _placeholderArt(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    style: TextStyle(
                      color: isSelected ? _pink : Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (isSelected) ...[
                        _buildEqualizerBars(isPlaying),
                        const SizedBox(width: 6),
                      ],
                      Icon(Icons.north_east_rounded, size: 12, color: Colors.white.withValues(alpha: 0.45)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${track.artist} • ${track.duration}',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onBookmarkTap,
              icon: Icon(
                isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                color: Colors.white.withValues(alpha: 0.8),
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEqualizerBars(bool playing) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _bar(playing ? 10.0 : 6.0),
        const SizedBox(width: 1.5),
        _bar(playing ? 14.0 : 9.0),
        const SizedBox(width: 1.5),
        _bar(playing ? 7.0 : 5.0),
      ],
    );
  }

  Widget _bar(double h) => Container(
        width: 1.8,
        height: h,
        decoration: BoxDecoration(
          color: _pink,
          borderRadius: BorderRadius.circular(1),
        ),
      );

  Widget _placeholderArt() => Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: Colors.white24,
          borderRadius: BorderRadius.circular(6),
        ),
        child:
            const Icon(Icons.music_note, color: Colors.white, size: 24),
      );
}
