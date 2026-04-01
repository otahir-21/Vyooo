import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../core/mock/mock_music_data.dart';
import '../../core/services/jamendo_service.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_gradient_background.dart';
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
      body: AppGradientBackground(
        type: GradientType.profile,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTopBar(),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: TextField(
                  controller: _searchController,
                  onChanged: _search,
                  style:
                      const TextStyle(color: Colors.white, fontSize: 16),
                  decoration: InputDecoration(
                    hintText: 'Search Music',
                    hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 16),
                    prefixIcon: Icon(Icons.search_rounded,
                        color: Colors.white.withValues(alpha: 0.6),
                        size: 22),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.12),
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppRadius.input),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _buildTabs(),
              const SizedBox(height: AppSpacing.sm),
              Expanded(child: _buildTrackList()),
              if (_playingTrack != null) _buildMiniPlayer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.only(
          left: AppSpacing.md,
          top: AppSpacing.sm,
          bottom: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(
            'add audio',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: List.generate(_tabs.length, (index) {
          final isSelected = index == _selectedTabIndex;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                  right: index < _tabs.length - 1
                      ? AppSpacing.xs
                      : 0),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () =>
                      setState(() => _selectedTabIndex = index),
                  borderRadius:
                      BorderRadius.circular(AppRadius.pill),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? const LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                Color(0xFFDE106B),
                                Color(0xFFF81945)
                              ],
                            )
                          : null,
                      color: isSelected
                          ? null
                          : Colors.white.withValues(alpha: 0.1),
                      borderRadius:
                          BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Center(
                      child: Text(
                        _tabs[index],
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
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
      margin: const EdgeInsets.all(AppSpacing.md),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: _pink,
        borderRadius: BorderRadius.circular(AppRadius.input),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: t.albumArtUrl.isNotEmpty
                ? Image.network(t.albumArtUrl,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        _placeholderArt())
                : _placeholderArt(),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis),
                Text(t.artist,
                    style: TextStyle(
                        color:
                            Colors.white.withValues(alpha: 0.9),
                        fontSize: 12),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Material(
            color: Colors.white,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: () => _isPlaying
                  ? _player.pause()
                  : _player.play(),
              customBorder: const CircleBorder(),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Icon(
                  _isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  color: _pink,
                  size: 24,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Material(
            color: Colors.white,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: () async {
                final idx = _currentTracks
                    .indexWhere((t) => t.id == _playingTrack?.id);
                final next = _currentTracks
                    .skip(idx + 1)
                    .firstOrNull;
                if (next != null) await _playTrack(next);
              },
              customBorder: const CircleBorder(),
              child: const Padding(
                padding: EdgeInsets.all(10),
                child: Icon(Icons.skip_next_rounded,
                    color: _pink, size: 24),
              ),
            ),
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
    return Material(
      color: isSelected
          ? _pink.withValues(alpha: 0.35)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.input),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.input),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.sm, horizontal: AppSpacing.sm),
          child: Row(
            children: [
              if (isSelected) _buildEqualizerBars(isPlaying),
              if (isSelected) const SizedBox(width: AppSpacing.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: track.albumArtUrl.isNotEmpty
                    ? Image.network(
                        track.albumArtUrl,
                        width: 52,
                        height: 52,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            _placeholderArt(),
                      )
                    : _placeholderArt(),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.arrow_upward_rounded,
                            size: 12,
                            color:
                                Colors.white.withValues(alpha: 0.7)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${track.artist} • ${track.duration}',
                            style: TextStyle(
                                color: Colors.white
                                    .withValues(alpha: 0.75),
                                fontSize: 13),
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
                  isSaved
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  color: isSaved
                      ? _pink
                      : Colors.white.withValues(alpha: 0.7),
                  size: 24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEqualizerBars(bool playing) {
    return SizedBox(
      width: 20,
      height: 24,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _bar(playing ? 12.0 : 8.0),
          _bar(playing ? 18.0 : 14.0),
          _bar(playing ? 8.0 : 6.0),
        ],
      ),
    );
  }

  Widget _bar(double h) => Container(
        width: 4,
        height: h,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(2),
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
