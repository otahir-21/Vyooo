import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/app_colors.dart';
import 'app_fonts.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Global theme for Vyooo app.
/// Dark: black scaffold, white text. Light auth: white scaffold, burgundy CTA.
class AppTheme {
  AppTheme._();

  // — Dark surface —
  static const Color scaffoldBackground = Colors.black;
  static const Color primary = Colors.white;
  static const Color buttonBackground = Colors.white;
  static const Color buttonTextColor = Colors.black;
  static const Color defaultTextColor = Colors.white;
  static const Color hintTextColor = White54.value;
  static const Color unfocusedUnderlineColor = White24.value;
  static const Color focusedUnderlineColor = Colors.white;
  static const Color secondaryTextColor = White70.value;
  static const Color searchBarColor = White24.value;

  // — Light auth surface —
  static const Color lightScaffoldBackground = Colors.white;
  static const Color lightOnSurface = Color(0xFF000000);
  static const Color lightHintText = Color(0x80000000);
  static const Color lightUnfocusedUnderline = Color(0x3D000000);
  static const Color lightFocusedUnderline = Color(0xFF000000);
  static const Color lightSecondaryText = Color(0x99000000);
  static const Color lightMutedBody = Color(0x99000000);
  static const Color lightButtonBackground = AppColors.authBrandBurgundy;
  /// Segmented toggle — unselected segment label (Figma ~70% black).
  static const Color lightToggleUnselected = Color(0xB3000000);
  static const Color lightButtonText = Colors.white;
  /// Auth Phone/Email track (Figma #D8D8D8).
  static const Color lightToggleTrack = Color(0xFFD8D8D8);

  static const Color lightToggleBorder = Color(0xFFE5E5E5);
  static const Color lightOtpBoxFill = Color(0xFFF5F5F5);
  /// Verify-code OTP boxes — black @ 6% (Figma).
  static const Color lightOtpBoxFillTranslucent = Color(0x0F000000);
  /// Onboarding username pill fill (Figma ~#F2F2F2).
  static const Color onboardingUsernameFieldFill = Color(0xFFF2F2F2);
  /// Onboarding DOB picker selection band (Figma #787880 @ 8%).
  static const Color onboardingDobPickerSelectionFill = Color(0x14787880);

  /// Onboarding DOB picker edge fade (Figma #B3B3B3).
  static const Color onboardingDobPickerFade = Color(0xFFB3B3B3);

  /// Cupertino picker chrome for light onboarding DOB (forces black selected text).
  static const CupertinoThemeData onboardingDobCupertinoTheme =
      CupertinoThemeData(
    brightness: Brightness.light,
    primaryColor: AppColors.authBrandBurgundy,
    textTheme: CupertinoTextThemeData(
      textStyle: TextStyle(
        fontFamily: AppFonts.body,
        color: Color(0xFF000000),
      ),
      pickerTextStyle: TextStyle(
        fontFamily: AppFonts.body,
        fontSize: 20,
        height: 1.0,
        fontWeight: FontWeight.w600,
        color: Color(0xFF000000),
      ),
    ),
  );

  /// Onboarding username clear icon — #828282 @ 45% (Figma).
  static const Color onboardingUsernameClearIcon = Color(0x73828282);
  static const List<BoxShadow> onboardingUsernameFieldShadow = [
    BoxShadow(
      color: Color(0x26000000),
      blurRadius: 4,
      offset: Offset(0, 1),
    ),
  ];
  static const Color lightSearchBarFill = Color(0xFFF0F0F0);
  static const Color lightInputPillFill = Color(0xFFF8F8F8);

  static bool isLight(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light;

  /// Edge-to-edge overlay: icon brightness only (no status/navigation bar colors).
  static const SystemUiOverlayStyle edgeToEdgeOverlay = SystemUiOverlayStyle(
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarContrastEnforced: false,
  );

  static const SystemUiOverlayStyle lightEdgeToEdgeOverlay =
      SystemUiOverlayStyle(
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarIconBrightness: Brightness.dark,
    systemNavigationBarContrastEnforced: false,
  );

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: AppFonts.body,
      appBarTheme: const AppBarTheme(
        systemOverlayStyle: edgeToEdgeOverlay,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      scaffoldBackgroundColor: scaffoldBackground,
      primaryColor: primary,
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: primary,
        selectionColor: Color(0x4DFFFFFF),
        selectionHandleColor: primary,
      ),
      cupertinoOverrideTheme: const CupertinoThemeData(
        brightness: Brightness.dark,
        primaryColor: primary,
      ),
      colorScheme: const ColorScheme.dark(
        surface: scaffoldBackground,
        primary: primary,
        onPrimary: buttonTextColor,
        onSurface: defaultTextColor,
      ),
      textTheme: Typography.material2021(platform: TargetPlatform.iOS)
          .white
          .apply(
            fontFamily: AppFonts.body,
            bodyColor: defaultTextColor,
            displayColor: defaultTextColor,
          )
          .copyWith(
            displayLarge: AppTypography.authHeadline,
            bodyLarge: AppTypography.input,
            bodyMedium: AppTypography.input,
            bodySmall: AppTypography.label,
            titleLarge: AppTypography.authHeadline.copyWith(fontSize: 32),
            titleMedium: AppTypography.toggleLabel,
            titleSmall: AppTypography.label,
            labelLarge: AppTypography.primaryButton,
            labelMedium: AppTypography.authSmallBody,
            labelSmall: AppTypography.authDividerLabel,
          ),
      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        fillColor: Colors.transparent,
        contentPadding: const EdgeInsets.symmetric(
          vertical: AppSpacing.storyItem,
        ),
        hintStyle: AppTypography.inputHint,
        labelStyle: AppTypography.input,
        floatingLabelStyle: AppTypography.input,
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: unfocusedUnderlineColor),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: focusedUnderlineColor),
        ),
        errorBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.red),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonBackground,
          foregroundColor: buttonTextColor,
          elevation: 0,
        ),
      ),
    );
  }

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: AppFonts.body,
      appBarTheme: const AppBarTheme(
        systemOverlayStyle: lightEdgeToEdgeOverlay,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      scaffoldBackgroundColor: lightScaffoldBackground,
      primaryColor: lightButtonBackground,
      colorScheme: const ColorScheme.light(
        surface: lightScaffoldBackground,
        primary: lightButtonBackground,
        onPrimary: lightButtonText,
        onSurface: lightOnSurface,
        outline: lightUnfocusedUnderline,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.authBrandBurgundy,
        selectionColor: AppColors.authBrandBurgundy.withValues(alpha: 0.28),
        selectionHandleColor: AppColors.authBrandBurgundy,
      ),
      cupertinoOverrideTheme: const CupertinoThemeData(
        brightness: Brightness.light,
        primaryColor: AppColors.authBrandBurgundy,
      ),
      textTheme: Typography.material2021(platform: TargetPlatform.iOS)
          .black
          .apply(
            fontFamily: AppFonts.body,
            bodyColor: lightOnSurface,
            displayColor: lightOnSurface,
          )
          .copyWith(
            displayLarge: AppTypography.authHeadline.copyWith(
              color: lightOnSurface,
            ),
            bodyLarge: AppTypography.input.copyWith(color: lightOnSurface),
            bodyMedium: AppTypography.input.copyWith(color: lightOnSurface),
            bodySmall: AppTypography.label.copyWith(color: lightSecondaryText),
            titleLarge: AppTypography.authHeadline.copyWith(
              color: lightOnSurface,
              fontSize: 32,
            ),
            titleMedium: AppTypography.toggleLabel.copyWith(
              color: lightOnSurface,
            ),
            titleSmall: AppTypography.label.copyWith(color: lightSecondaryText),
            labelLarge: AppTypography.primaryButton.copyWith(
              color: lightButtonText,
            ),
            labelMedium: AppTypography.authSmallBody.copyWith(
              color: lightMutedBody,
            ),
            labelSmall: AppTypography.authDividerLabel.copyWith(
              color: lightMutedBody,
            ),
          ),
      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        fillColor: Colors.transparent,
        contentPadding: const EdgeInsets.symmetric(
          vertical: AppSpacing.storyItem,
        ),
        hintStyle: AppTypography.inputHint.copyWith(color: lightHintText),
        labelStyle: AppTypography.input.copyWith(color: lightOnSurface),
        floatingLabelStyle: AppTypography.input.copyWith(color: lightOnSurface),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: lightUnfocusedUnderline),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(
            color: AppColors.authBrandBurgundy,
            width: 2,
          ),
        ),
        errorBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.red),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: lightButtonBackground,
          foregroundColor: lightButtonText,
          elevation: 0,
        ),
      ),
    );
  }
}

// Opacity-based whites for consistency with spec
class White54 {
  White54._();
  static const Color value = Color(0x8AFFFFFF);
}

class White70 {
  White70._();
  static const Color value = Color(0xB3FFFFFF);
}

/// Figma reel music line (#FFFFFF @ 80%).
class White80 {
  White80._();
  static const Color value = Color(0xCCFFFFFF);
}

class White24 {
  White24._();
  static const Color value = Color(0x3DFFFFFF);
}

class White10 {
  White10._();
  static const Color value = Color(0x1AFFFFFF);
}

class White40 {
  White40._();
  static const Color value = Color(0x66FFFFFF);
}

class White50 {
  White50._();
  static const Color value = Color(0x80FFFFFF);
}

class White60 {
  White60._();
  static const Color value = Color(0x99FFFFFF);
}

class White15 {
  White15._();
  static const Color value = Color(0x26FFFFFF);
}

/// Figma feed tab pill fill / stroke (#FFFFFF @ 20%).
class White20 {
  White20._();
  static const Color value = Color(0x33FFFFFF);
}

/// Figma feed notification circle fill (#FFFFFF @ 30%).
class White30 {
  White30._();
  static const Color value = Color(0x4DFFFFFF);
}
