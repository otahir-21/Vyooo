import 'package:flutter/widgets.dart';

/// Border radius standards: 12 → Inputs/cards, 20 → Pills, 30 → Full-width buttons.
abstract final class AppRadius {
  static const double input = 12;
  static const double pill = 20;
  static const double button = 30;
  static const double card = 8;

  /// Home feed nav chips — moderate rounded rect (Figma; not full stadium).
  static const double feedTab = 12;

  /// Bottom nav outer chrome — bottom corners only (Figma).
  static const double feedBottomChrome = 24;

  static BorderRadius get feedBottomChromeRadius => const BorderRadius.only(
        bottomLeft: Radius.circular(feedBottomChrome),
        bottomRight: Radius.circular(feedBottomChrome),
      );

  /// Reel post bottom edge — rounded before the nav chrome (bottom only).
  static BorderRadius get feedPostBottomRadius => feedBottomChromeRadius;

  static BorderRadius get inputRadius => BorderRadius.circular(input);
  static BorderRadius get pillRadius => BorderRadius.circular(pill);
  static BorderRadius get buttonRadius => BorderRadius.circular(button);
  static BorderRadius get feedTabRadius => BorderRadius.circular(feedTab);
}
