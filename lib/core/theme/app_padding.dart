import 'package:flutter/widgets.dart';

import 'app_sizes.dart';
class AppPadding {
  static const screenHorizontal =
      EdgeInsets.symmetric(horizontal: 16);

  static const screenVertical =
      EdgeInsets.symmetric(vertical: 16);

  static const card =
      EdgeInsets.all(16);

  static const input =
      EdgeInsets.symmetric(horizontal: 16, vertical: 14);

  static const button =
      EdgeInsets.symmetric(vertical: 14);

  static const sectionGap =
      SizedBox(height: 24);

  static const itemGap =
      SizedBox(height: 16);

  /// Auth/onboarding form (wider horizontal)
  static const authFormHorizontal =
      EdgeInsets.symmetric(horizontal: 30);

  /// Gap after auth headline before form controls
  static const authBelowHeadlineGap = SizedBox(height: 24);

  /// Gap between underline auth fields
  static const authFieldGap = sectionGap;

  /// Home feed tab row — slightly inset from the left vs logo row (Figma).
  static const feedTabRowHorizontal =
      EdgeInsets.only(left: 12, right: 8);

  /// Home feed tab chips — 33px pill; extra bottom inset for descenders.
  static const feedTabChip =
      EdgeInsets.fromLTRB(11, 4, 11, 6);

  /// Home feed tab chips — compact horizontal inset on narrow screens.
  static const feedTabChipCompact =
      EdgeInsets.fromLTRB(8, 4, 8, 6);

  /// Reel overlay "+ Follow" chip (Figma 71×24, 12 horizontal inset).
  static const feedReelFollowChip =
      EdgeInsets.symmetric(horizontal: 12);

  /// Live stream comment field — horizontal inset; vertical centers 15px line in 32px.
  static const liveCommentInputContent =
      EdgeInsets.symmetric(horizontal: 12, vertical: 8.5);

  /// Live feed bottom overlay stack — Figma Frame 2147224967 (12 top, 16 sides).
  static EdgeInsets liveFeedOverlayContentOf(BuildContext context) {
    return EdgeInsets.fromLTRB(
      AppSizes.liveFeedScaleW(context, 16),
      AppSizes.liveFeedScaleH(context, 12),
      AppSizes.liveFeedScaleW(context, 16),
      0,
    );
  }
}
