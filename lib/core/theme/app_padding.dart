import 'package:flutter/widgets.dart';

/// Centralized padding and gap widgets. Use with AppSpacing for numbers.
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

  /// Home feed tab row — tighter horizontal inset than [screenHorizontal].
  static const feedTabRowHorizontal =
      EdgeInsets.symmetric(horizontal: 8);

  /// Home feed tab chips — inner pill padding (Figma vertical 6).
  static const feedTabChip =
      EdgeInsets.symmetric(horizontal: 10, vertical: 6);

  /// Reel overlay "+ Follow" chip (Figma 71×24, 12 horizontal inset).
  static const feedReelFollowChip =
      EdgeInsets.symmetric(horizontal: 12);

  /// Live stream comment field — horizontal inset after rounded corner (Figma ~12).
  static const liveCommentInputContent =
      EdgeInsets.symmetric(horizontal: 12, vertical: 8);
}
