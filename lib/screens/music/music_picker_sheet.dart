import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/mock/mock_music_data.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';

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
    builder: (ctx) => _MusicPickerSheet(
      onDone: onDone,
      currentDisplay: currentDisplay,
    ),
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
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<MusicTrack> get _filteredTracks {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return mockMusicTracks;
    return mockMusicTracks.where((t) =>
        t.title.toLowerCase().contains(q) ||
        t.artist.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final keyboardInset = media.viewInsets.bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: FractionallySizedBox(
        heightFactor: 0.96,
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1A0020),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                const SizedBox(height: AppSpacing.sm),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    decoration: InputDecoration(
                      hintText: 'Search Music',
                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 16),
                      prefixIcon: Icon(Icons.search_rounded, color: Colors.white.withValues(alpha: 0.6), size: 22),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.input),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Expanded(
                  child: ListView.builder(
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
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
                ),
                if (_selectedTrack != null) _buildSelectionPreview(),
                _buildActions(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionPreview() {
    final t = _selectedTrack!;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.input),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(t.albumArtUrl, width: 64, height: 64, fit: BoxFit.cover),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  t.artist,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                _buildWaveformPlaceholder(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaveformPlaceholder() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(24, (i) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 1),
        width: 3,
        height: 12 + (i % 5) * 4.0,
        decoration: BoxDecoration(
          color: (i % 3 == 0) ? const Color(0xFFDE106B) : Colors.white.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(1),
        ),
      )),
    );
  }

  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.lg),
      child: Row(
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 16),
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: _selectedTrack == null
                ? null
                : () {
                    widget.onDone(_selectedTrack!);
                    Navigator.of(context).pop();
                  },
            child: Text(
              'Done',
              style: TextStyle(
                color: _selectedTrack == null ? Colors.white38 : const Color(0xFFDE106B),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
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
    return Material(
      color: isSelected ? const Color(0xFFDE106B).withValues(alpha: 0.35) : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.input),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.input),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: AppSpacing.xs),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(track.albumArtUrl, width: 52, height: 52, fit: BoxFit.cover),
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
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${track.artist} • ${track.duration}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (track.isSaved)
                Icon(Icons.bookmark_rounded, color: AppColors.deleteRed, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
