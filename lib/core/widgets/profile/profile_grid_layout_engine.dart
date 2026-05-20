import 'profile_grid_models.dart';

/// Assigns 1×1 / 2×2 spans for creator profile grids.
abstract final class ProfileGridLayoutEngine {
  ProfileGridLayoutEngine._();

  static const int artistChunkSize = 12;
  static const int artistFeaturedSlotCount = 5;

  static List<ProfileGridPlacement> layout({
    required int itemCount,
    required List<int> viewsByIndex,
    required ProfileGridLayoutMode mode,
    int minViewsForDouble = 0,
    List<ProfileGridSpanOverride> spanOverrideByIndex = const [],
  }) {
    switch (mode) {
      case ProfileGridLayoutMode.uniform:
        return List.generate(
          itemCount,
          (i) => ProfileGridPlacement(
            sourceIndex: i,
            span: _spanForUniformIndex(
              i,
              spanOverrideByIndex: spanOverrideByIndex,
            ),
          ),
        );
      case ProfileGridLayoutMode.artistModern:
        return _artistModern(
          itemCount: itemCount,
          viewsByIndex: viewsByIndex,
          minViewsForDouble: minViewsForDouble,
          spanOverrideByIndex: spanOverrideByIndex,
        );
    }
  }

  static ProfileGridSpan _spanForUniformIndex(
    int index, {
    required List<ProfileGridSpanOverride> spanOverrideByIndex,
  }) {
    final override = _overrideAt(index, spanOverrideByIndex);
    return switch (override) {
      ProfileGridSpanOverride.double => ProfileGridSpan.double,
      ProfileGridSpanOverride.unit => ProfileGridSpan.unit,
      ProfileGridSpanOverride.auto => ProfileGridSpan.unit,
    };
  }

  static ProfileGridSpanOverride _overrideAt(
    int index,
    List<ProfileGridSpanOverride> spanOverrideByIndex,
  ) {
    if (index < 0 || index >= spanOverrideByIndex.length) {
      return ProfileGridSpanOverride.auto;
    }
    return spanOverrideByIndex[index];
  }

  static bool _mayUseDoubleHero({
    required int index,
    required List<int> viewsByIndex,
    required int minViewsForDouble,
    required List<ProfileGridSpanOverride> spanOverrideByIndex,
  }) {
    return switch (_overrideAt(index, spanOverrideByIndex)) {
      ProfileGridSpanOverride.double => true,
      ProfileGridSpanOverride.unit => false,
      ProfileGridSpanOverride.auto =>
        viewsByIndex[index] >= minViewsForDouble,
    };
  }

  static List<ProfileGridPlacement> _artistModern({
    required int itemCount,
    required List<int> viewsByIndex,
    required int minViewsForDouble,
    required List<ProfileGridSpanOverride> spanOverrideByIndex,
  }) {
    if (itemCount <= 0) return const [];

    final placements = <ProfileGridPlacement>[];

    for (var chunkStart = 0;
        chunkStart < itemCount;
        chunkStart += artistChunkSize) {
      final chunkEnd = chunkStart + artistChunkSize > itemCount
          ? itemCount
          : chunkStart + artistChunkSize;
      final chunkIndices = List<int>.generate(
        chunkEnd - chunkStart,
        (i) => chunkStart + i,
      );

      if (chunkIndices.length == 1) {
        final index = chunkIndices.first;
        placements.add(
          ProfileGridPlacement(
            sourceIndex: index,
            span: _mayUseDoubleHero(
                  index: index,
                  viewsByIndex: viewsByIndex,
                  minViewsForDouble: minViewsForDouble,
                  spanOverrideByIndex: spanOverrideByIndex,
                )
                ? ProfileGridSpan.double
                : ProfileGridSpan.unit,
          ),
        );
        continue;
      }

      final ranked = List<int>.from(chunkIndices)
        ..sort((a, b) {
          final byViews = viewsByIndex[b].compareTo(viewsByIndex[a]);
          if (byViews != 0) return byViews;
          return a.compareTo(b);
        });

      final pinnedDoubles = ranked
          .where(
            (i) =>
                _overrideAt(i, spanOverrideByIndex) ==
                ProfileGridSpanOverride.double,
          )
          .toList(growable: false);

      final heroIndex =
          pinnedDoubles.isNotEmpty ? pinnedDoubles.first : ranked.first;
      final useDoubleHero = _mayUseDoubleHero(
            index: heroIndex,
            viewsByIndex: viewsByIndex,
            minViewsForDouble: minViewsForDouble,
            spanOverrideByIndex: spanOverrideByIndex,
          ) &&
          chunkIndices.length >= 2;

      final featured = <int>[];
      if (useDoubleHero) {
        featured.add(heroIndex);
        for (final i in ranked.skip(1).take(artistFeaturedSlotCount - 1)) {
          featured.add(i);
        }
      } else {
        featured.addAll(ranked.take(artistFeaturedSlotCount));
      }

      final featuredSet = featured.toSet();
      final rest = chunkIndices.where((i) => !featuredSet.contains(i));

      if (useDoubleHero) {
        placements.add(
          ProfileGridPlacement(
            sourceIndex: heroIndex,
            span: ProfileGridSpan.double,
          ),
        );
        for (final i in featured.skip(1)) {
          placements.add(
            ProfileGridPlacement(
              sourceIndex: i,
              span: ProfileGridSpan.unit,
            ),
          );
        }
      } else {
        for (final i in featured) {
          placements.add(
            ProfileGridPlacement(
              sourceIndex: i,
              span: ProfileGridSpan.unit,
            ),
          );
        }
      }

      for (final i in rest) {
        placements.add(
          ProfileGridPlacement(
            sourceIndex: i,
            span: ProfileGridSpan.unit,
          ),
        );
      }
    }

    return placements;
  }
}
