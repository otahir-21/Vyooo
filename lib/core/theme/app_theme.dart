import 'package:flutter/material.dart';

import 'app_spacing.dart';

/// Global theme for Vyooo app.
/// Scaffold background: Black, primary: White, underline-only inputs.
class AppTheme {
  AppTheme._();

  // Colors
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

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: 'Inter',
      scaffoldBackgroundColor: scaffoldBackground,
      primaryColor: primary,
      colorScheme: const ColorScheme.dark(
        surface: scaffoldBackground,
        primary: primary,
        onPrimary: buttonTextColor,
        onSurface: defaultTextColor,
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(
          color: defaultTextColor,
          fontWeight: FontWeight.w400,
        ),
        bodyMedium: TextStyle(
          color: defaultTextColor,
          fontWeight: FontWeight.w400,
        ),
        bodySmall: TextStyle(
          color: defaultTextColor,
          fontWeight: FontWeight.w400,
        ),
        titleLarge: TextStyle(
          color: defaultTextColor,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: TextStyle(
          color: defaultTextColor,
          fontWeight: FontWeight.w500,
        ),
        titleSmall: TextStyle(
          color: defaultTextColor,
          fontWeight: FontWeight.w400,
        ),
        labelLarge: TextStyle(
          color: defaultTextColor,
          fontWeight: FontWeight.w500,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        fillColor: Colors.transparent,
        contentPadding: const EdgeInsets.symmetric(
          vertical: AppSpacing.storyItem,
        ),
        hintStyle: const TextStyle(
          color: hintTextColor,
          fontSize: 16,
          fontWeight: FontWeight.w400,
        ),
        labelStyle: const TextStyle(color: defaultTextColor, fontSize: 16),
        floatingLabelStyle: const TextStyle(
          color: defaultTextColor,
          fontSize: 16,
        ),
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
