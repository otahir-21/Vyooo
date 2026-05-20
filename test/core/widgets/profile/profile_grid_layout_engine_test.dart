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
  });
}
