import 'package:flutter_test/flutter_test.dart';
import 'package:vyooo/core/widgets/profile/profile_grid_layout_engine.dart';
import 'package:vyooo/core/widgets/profile/profile_grid_models.dart';

void main() {
  group('ProfileGridLayoutEngine', () {
    test('uniform mode returns one unit tile per item', () {
      final placements = ProfileGridLayoutEngine.layout(
        itemCount: 5,
        viewsByIndex: [10, 20, 30, 40, 50],
        mode: ProfileGridLayoutMode.uniform,
      );
      expect(placements.length, 5);
      expect(
        placements.every((p) => p.span == ProfileGridSpan.unit),
        isTrue,
      );
    });

    test('artistModern promotes highest views in chunk to double', () {
      final views = List<int>.generate(12, (i) => i);
      views[11] = 1000;
      final placements = ProfileGridLayoutEngine.layout(
        itemCount: 12,
        viewsByIndex: views,
        mode: ProfileGridLayoutMode.artistModern,
      );
      expect(placements.length, 12);
      final doubles =
          placements.where((p) => p.span == ProfileGridSpan.double);
      expect(doubles.length, 1);
      expect(doubles.first.sourceIndex, 11);
    });

    test('artistModern honors profileGridSpan double override', () {
      final views = List<int>.generate(5, (i) => i);
      final overrides = List<ProfileGridSpanOverride>.filled(
        5,
        ProfileGridSpanOverride.auto,
      );
      overrides[0] = ProfileGridSpanOverride.double;
      final placements = ProfileGridLayoutEngine.layout(
        itemCount: 5,
        viewsByIndex: views,
        mode: ProfileGridLayoutMode.artistModern,
        spanOverrideByIndex: overrides,
      );
      final doubles =
          placements.where((p) => p.span == ProfileGridSpan.double);
      expect(doubles.length, 1);
      expect(doubles.first.sourceIndex, 0);
    });

    test('artistModern honors profileGridSpan unit override on top views', () {
      final views = List<int>.generate(12, (i) => i + 1);
      final overrides = List<ProfileGridSpanOverride>.filled(
        12,
        ProfileGridSpanOverride.auto,
      );
      overrides[11] = ProfileGridSpanOverride.unit;
      final placements = ProfileGridLayoutEngine.layout(
        itemCount: 12,
        viewsByIndex: views,
        mode: ProfileGridLayoutMode.artistModern,
        spanOverrideByIndex: overrides,
      );
      expect(
        placements.any(
          (p) => p.sourceIndex == 11 && p.span == ProfileGridSpan.double,
        ),
        isFalse,
      );
    });
  });
}
