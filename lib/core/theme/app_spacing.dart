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

  /// Home reel action column — gap between labeled buttons (Figma ~23px).
  static const double feedInteractionButtonGap = lg + xs;

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

  /// Reel feed — right action column inset above bottom nav.
  static const double reelActionColumnNavGap = sm + md;

  /// Nudge Following status chevron down to align with tab pill text (Figma).
  static const double followingStoriesToggleDown = xs;

  /// Gap between auth logo and headline (Figma register).
  static const double authLogoToHeadline = xl;

  /// Inset above pinned auth wordmark (verify-code and similar).
  static const double authLogoTop = xl;

  /// Space above primary auth CTA (50 = xl + lg + xs)
  static const double authCtaTop = xl + lg + xs;

  /// Horizontal gap between social sign-in icons (40 = xl + md)
  static const double socialRowGap = xl + md;

  /// Divider / social block vertical rhythm (32 = xxl)
  static const double authDividerBlock = xxl;

  /// Bottom inset for floating auth back/forward row (above home indicator).
  /// Add [AppSystemUi.bottomChromeInset] in the widget for the system nav bar.
  static const double authFloatingNavBottom = xl + md;

  /// Onboarding username pill — horizontal inset (Figma ~21px).
  static const double onboardingUsernameFieldHorizontal = 21;

  /// Onboarding username pill — vertical inset (Figma ~11px).
  static const double onboardingUsernameFieldVertical = 11;

  /// Figma — value baseline ~28px from field top when label is shown.
  static const double onboardingUsernameFieldValueTop = 11;

  /// Gap between floating label and typed value (Figma ~5px).
  static const double onboardingUsernameFieldLabelGap = 5;

  /// Vertical offset for empty-state placeholder (centers ~16px text in 62px field).
  static const double onboardingUsernameFieldEmptyTop = 15;
}
