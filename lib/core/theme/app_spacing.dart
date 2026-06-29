// 🔴 IMPORTANT:
// Do NOT use hardcoded spacing anywhere in the project.
// Always use AppSpacing or AppPadding.
// This ensures consistent UI rhythm across the app.

/// 4pt grid spacing constants. Use for SizedBox(height: AppSpacing.xx) or padding values.
abstract final class AppSpacing {
  /// Extra small (e.g. caption to stats gap in feed)
  static const double xs = 4;

  /// Small (icon + text gap, username to caption)
  static const double sm = 8;

  /// Medium (between elements, item gap)
  static const double md = 16;

  /// Large (feed interaction button vertical spacing)
  static const double lg = 22;

  /// Extra large (section spacing)
  static const double xl = 24;

  /// 2× large (auth section gaps, 32 = 8×4pt)
  static const double xxl = 32;

  /// Story row item spacing (12 = 3×4pt)
  static const double storyItem = 12;

  /// Reel music row — icon to label (Figma 6px).
  static const double reelMusicIconGap = 6;

  /// Gap between reel post bottom edge and feed nav chrome (shows bottom radius).
  static const double feedPostNavGap = sm;

  /// Nudge Following status chevron down to align with tab pill text (Figma).
  static const double followingStoriesToggleDown = xs;

  /// Space above primary auth CTA (50 = xl + lg + xs)
  static const double authCtaTop = xl + lg + xs;

  /// Horizontal gap between social sign-in icons (40 = xl + md)
  static const double socialRowGap = xl + md;

  /// Divider / social block vertical rhythm (32 = xxl)
  static const double authDividerBlock = xxl;

  /// Bottom inset for floating auth back/forward row (above home indicator).
  /// Add [AppSystemUi.bottomChromeInset] in the widget for the system nav bar.
  static const double authFloatingNavBottom = xl + md;
}
