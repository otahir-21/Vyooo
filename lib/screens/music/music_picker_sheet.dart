import 'package:flutter/material.dart';

import '../../core/mock/mock_music_data.dart';

/// Bottom sheet to pick a music track for profile. Same list as Music library; selection preview with Done/Cancel.
void showMusicPickerSheet(
  BuildContext context, {
  required ValueChanged<MusicTrack> onDone,
  String? currentDisplay,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) =>
        _MusicPickerSheet(onDone: onDone, currentDisplay: currentDisplay),
  );
}

class _MusicPickerSheet extends StatefulWidget {
  const _MusicPickerSheet({required this.onDone, this.currentDisplay});

  final ValueChanged<MusicTrack> onDone;
  final String? currentDisplay;

  @override
  State<_MusicPickerSheet> createState() => _MusicPickerSheetState();
}

class _MusicPickerSheetState extends State<_MusicPickerSheet> {
  MusicTrack? _selectedTrack;
  bool _isTrimming = false;
  int _activeTab = 0; // 0 For you, 1 Trending, 2 Saved
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<MusicTrack> get _filteredTracks {
    final q = _searchController.text.trim().toLowerCase();
    var list = mockMusicTracks;
    if (_activeTab == 2) {
      list = mockMusicTracks.where((t) => t.isSaved).toList();
    }
    if (q.isEmpty) return list;
    return list
        .where(
          (t) =>
              t.title.toLowerCase().contains(q) ||
              t.artist.toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isTrimming && _selectedTrack != null) {
      return _buildTrimmingView();
    }

    return FractionallySizedBox(
      heightFactor: 0.94,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1E0A1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              // Search
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search Music',
                    hintStyle: TextStyle(color: Colors.white38, fontSize: 14),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: Colors.white38,
                      size: 20,
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Tabs
              _buildTabs(),
              const SizedBox(height: 8),
              // List
              Expanded(
                child: Stack(
                  children: [
                    ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 100,
                      ),
                      itemCount: _filteredTracks.length,
                      itemBuilder: (context, index) {
                        final track = _filteredTracks[index];
                        final isSelected = _selectedTrack?.id == track.id;
                        return _PickerMusicTile(
                          track: track,
                          isSelected: isSelected,
                          onTap: () => setState(() => _selectedTrack = track),
                        );
                      },
                    ),
                    if (_selectedTrack != null)
                      Positioned(
                        left: 16,
                        right: 16,
                        bottom: 24,
                        child: _buildFloatingPlaybackBar(),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            _buildTabItem('For you', 0),
            _buildTabItem('Trending', 1),
            _buildTabItem('Saved', 2),
          ],
        ),
      ),
    );
  }

  Widget _buildTabItem(String label, int index) {
    final active = _activeTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeTab = index),
        child: Container(
          decoration: BoxDecoration(
            color: active ? const Color(0xFFDE106B) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: active ? Colors.white : Colors.white60,
              fontSize: 13,
              fontWeight: active ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingPlaybackBar() {
    final t = _selectedTrack!;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFDE106B),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.network(
              t.albumArtUrl,
              width: 44,
              height: 44,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  t.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  t.artist,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(
              Icons.pause_circle_filled_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _isTrimming = true),
            icon: const Icon(
              Icons.arrow_forward_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrimmingView() {
    final t = _selectedTrack!;
    return FractionallySizedBox(
      heightFactor: 0.45,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1E0A1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => setState(() => _isTrimming = false),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Color(0xFFDE106B), fontSize: 15),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      widget.onDone(t);
                      Navigator.of(context).pop();
                    },
                    child: const Text(
                      'Done',
                      style: TextStyle(
                        color: Color(0xFFDE106B),
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                t.albumArtUrl,
                width: 70,
                height: 70,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              t.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              t.artist,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const Spacer(),
            _buildWaveformTrimmer(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildWaveformTrimmer() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: List.generate(40, (i) {
          final active = i > 10 && i < 30;
          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 1),
              height: 20 + (i % 7) * 4.0,
              decoration: BoxDecoration(
                color: active ? const Color(0xFFDE106B) : Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _PickerMusicTile extends StatelessWidget {
  const _PickerMusicTile({
    required this.track,
    required this.isSelected,
    required this.onTap,
  });

  final MusicTrack track;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(
                track.albumArtUrl,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    style: TextStyle(
                      color: isSelected
                          ? const Color(0xFFDE106B)
                          : Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      const Icon(
                        Icons.north_east_rounded,
                        color: Colors.white38,
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${track.artist} • ${track.duration}',
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(
              track.isSaved
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
              color: Colors.white70,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
