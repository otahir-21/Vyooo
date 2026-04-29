import 'package:flutter/widgets.dart';

/// Border radius standards: 12 → Inputs/cards, 20 → Pills, 30 → Full-width buttons.
abstract final class AppRadius {
  static const double input = 12;
  static const double pill = 20;
  static const double button = 30;
  static const double card = 8;

  static BorderRadius get inputRadius => BorderRadius.circular(input);
  static BorderRadius get pillRadius => BorderRadius.circular(pill);
  static BorderRadius get buttonRadius => BorderRadius.circular(button);
}
