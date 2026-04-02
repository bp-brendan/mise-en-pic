import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'cookbook_palette.dart';

/// Design-system theme builder for Mise en Pic.
///
/// Mirrors the Neubrutalist letterpress aesthetic shared across Loom, Mute,
/// and Static: thick borders, deboss shadows, paper textures, SourceSerif4.
class CookbookTheme {
  CookbookTheme._();

  static const double strokeWidth = 1.5;
  static const double brutalRadius = 6.0;
  static const String serifFamily = 'SourceSerif4';

  // ── Typography helpers ──────────────────────────────────────────

  static TextStyle displayStyle({
    double fontSize = 32,
    double fontWeight = 760,
    Color? color,
  }) {
    return TextStyle(
      fontFamily: serifFamily,
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      fontVariations: [FontVariation('wght', fontWeight)],
      height: 0.96,
      color: color,
      letterSpacing: -0.5,
    );
  }

  static TextStyle headlineStyle({
    double fontSize = 22,
    double fontWeight = 690,
    Color? color,
  }) {
    return TextStyle(
      fontFamily: serifFamily,
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      fontVariations: [FontVariation('wght', fontWeight)],
      height: 1.08,
      color: color,
      letterSpacing: -0.3,
    );
  }

  static TextStyle titleStyle({
    double fontSize = 17,
    double fontWeight = 640,
    Color? color,
  }) {
    return TextStyle(
      fontFamily: serifFamily,
      fontSize: fontSize,
      fontWeight: FontWeight.w600,
      fontVariations: [FontVariation('wght', fontWeight)],
      height: 1.1,
      color: color,
    );
  }

  static TextStyle bodyStyle({
    double fontSize = 15,
    double fontWeight = 450,
    Color? color,
  }) {
    return TextStyle(
      fontFamily: serifFamily,
      fontSize: fontSize,
      fontWeight: FontWeight.w400,
      fontVariations: [FontVariation('wght', fontWeight)],
      height: 1.5,
      color: color,
    );
  }

  static TextStyle labelStyle({
    double fontSize = 12,
    double fontWeight = 520,
    Color? color,
    double letterSpacing = 1.6,
  }) {
    return TextStyle(
      fontFamily: serifFamily,
      fontSize: fontSize,
      fontWeight: FontWeight.w500,
      fontVariations: [FontVariation('wght', fontWeight)],
      height: 1.15,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  // ── Letterpress shadows ─────────────────────────────────────────

  static List<Shadow> letterpressShadows(
    Color ink, {
    double highlightAlpha = 0.34,
    double shadowAlpha = 0.14,
    double rotation = 0.0,
    double highlightDistance = 0.42,
    double shadowDistance = 0.7,
  }) {
    final angle = CookbookPalette.sharedLightAngle + rotation;
    return [
      Shadow(
        offset: Offset(
          math.cos(angle + math.pi) * highlightDistance,
          math.sin(angle + math.pi) * highlightDistance,
        ),
        color: CookbookPalette.debossHighlight.withValues(alpha: highlightAlpha),
        blurRadius: 0,
      ),
      Shadow(
        offset: Offset(
          math.cos(angle) * shadowDistance,
          math.sin(angle) * shadowDistance,
        ),
        color: CookbookPalette.debossShadow.withValues(alpha: shadowAlpha),
        blurRadius: 0,
      ),
    ];
  }

  // ── Paper elevation shadows ─────────────────────────────────────

  static List<BoxShadow> paperElevationShadows({double lift = 0.5}) {
    final angle = CookbookPalette.sharedLightAngle;
    return [
      BoxShadow(
        color: CookbookPalette.debossShadow.withValues(
          alpha: 0.05 + 0.04 * lift,
        ),
        offset: Offset(0, 1 + 1.2 * lift),
        blurRadius: 2.4 + 2.6 * lift,
        spreadRadius: -1.4,
      ),
      BoxShadow(
        color: CookbookPalette.debossShadow.withValues(
          alpha: 0.06 + 0.028 * lift,
        ),
        offset: Offset(
          math.cos(angle) * (1.6 + 1.9 * lift),
          math.sin(angle) * (1.6 + 1.9 * lift),
        ),
        blurRadius: 5.2 + 5.8 * lift,
        spreadRadius: -3.2 - 0.6 * lift,
      ),
      BoxShadow(
        color: CookbookPalette.debossHighlight.withValues(
          alpha: 0.26 + 0.08 * lift,
        ),
        offset: Offset(
          math.cos(angle + math.pi) * 0.9,
          math.sin(angle + math.pi) * 0.9,
        ),
        blurRadius: 0,
        spreadRadius: -0.5,
      ),
    ];
  }

  // ── Edge-to-edge system UI ──────────────────────────────────────

  static const SystemUiOverlayStyle edgeToEdgeLight = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarIconBrightness: Brightness.dark,
    systemStatusBarContrastEnforced: false,
    systemNavigationBarContrastEnforced: false,
  );

  static const SystemUiOverlayStyle edgeToEdgeDark = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarIconBrightness: Brightness.light,
    systemStatusBarContrastEnforced: false,
    systemNavigationBarContrastEnforced: false,
  );

  // ── ThemeData builders ──────────────────────────────────────────

  static ThemeData light() {
    return _buildTheme(
      brightness: Brightness.light,
      background: CookbookPalette.lightBackground,
      card: CookbookPalette.lightCard,
      ink: CookbookPalette.lightInk,
      strokeColor: CookbookPalette.lightStroke,
      accent: CookbookPalette.lightAccent,
    );
  }

  static ThemeData dark() {
    return _buildTheme(
      brightness: Brightness.dark,
      background: CookbookPalette.darkBackground,
      card: CookbookPalette.darkCard,
      ink: CookbookPalette.darkInk,
      strokeColor: CookbookPalette.darkStroke,
      accent: CookbookPalette.darkAccent,
    );
  }

  static ThemeData _buildTheme({
    required Brightness brightness,
    required Color background,
    required Color card,
    required Color ink,
    required Color strokeColor,
    required Color accent,
  }) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: brightness,
    ).copyWith(
      surface: card,
      onSurface: ink,
      primary: accent,
      onPrimary: accent.computeLuminance() > 0.55
          ? const Color(0xFF111111)
          : const Color(0xFFF7F5EF),
      outline: strokeColor,
      error: CookbookPalette.error,
    );

    final textTheme = Typography.material2021().black
        .apply(
          bodyColor: ink,
          displayColor: ink,
          fontFamily: serifFamily,
        )
        .copyWith(
          displayLarge: _variableSerif(760, FontWeight.w700, 0.96),
          displayMedium: _variableSerif(720, FontWeight.w700, 1.0),
          headlineLarge: _variableSerif(690, FontWeight.w700, 1.08),
          headlineSmall: _variableSerif(700, FontWeight.w700, 1.1),
          titleLarge: _variableSerif(680, FontWeight.w700, 1.1),
          titleMedium: _variableSerif(640, FontWeight.w600, 1.1),
          bodyLarge: _variableSerif(450, FontWeight.w500, 1.5),
          bodyMedium: _variableSerif(450, FontWeight.w500, 1.5),
          bodySmall: _variableSerif(430, FontWeight.w400, 1.5),
          labelMedium: _variableSerif(520, FontWeight.w500, 1.15),
          labelSmall: _variableSerif(430, FontWeight.w400, 1.2,
              fontStyle: FontStyle.italic),
        );

    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(brutalRadius),
      borderSide: BorderSide(color: strokeColor, width: strokeWidth),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: serifFamily,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      textTheme: textTheme,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(brutalRadius),
          side: BorderSide(color: strokeColor, width: strokeWidth),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: ink,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle:
            brightness == Brightness.light ? edgeToEdgeLight : edgeToEdgeDark,
        shape: Border(
          bottom: BorderSide(color: strokeColor, width: strokeWidth),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: card,
        selectedColor: accent.withValues(alpha: 0.16),
        side: BorderSide(color: strokeColor, width: strokeWidth),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(brutalRadius),
        ),
        labelStyle: TextStyle(
          color: ink,
          fontFamily: serifFamily,
          fontWeight: FontWeight.w600,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(brutalRadius),
            ),
          ),
          side: WidgetStateProperty.all(
            BorderSide(color: strokeColor, width: strokeWidth),
          ),
          foregroundColor: WidgetStateProperty.all(ink),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return accent.withValues(alpha: 0.16);
            }
            return card;
          }),
          textStyle: WidgetStateProperty.all(
            TextStyle(fontFamily: serifFamily, fontWeight: FontWeight.w600),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          backgroundColor: card,
          side: BorderSide(color: strokeColor, width: strokeWidth),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(brutalRadius),
          ),
          textStyle: TextStyle(
            fontFamily: serifFamily,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          foregroundColor: colorScheme.onPrimary,
          backgroundColor: accent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(brutalRadius),
          ),
          textStyle: labelStyle(),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        isDense: true,
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: accent, width: strokeWidth),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: card,
        contentTextStyle: bodyStyle(color: ink),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(brutalRadius),
          side: BorderSide(color: strokeColor, width: strokeWidth),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      dividerTheme: DividerThemeData(
        color: strokeColor,
        thickness: strokeWidth,
      ),
    );
  }

  static TextStyle _variableSerif(
    double weightAxis,
    FontWeight fallbackWeight,
    double height, {
    FontStyle fontStyle = FontStyle.normal,
  }) {
    return TextStyle(
      fontFamily: serifFamily,
      fontWeight: fallbackWeight,
      fontStyle: fontStyle,
      height: height,
      leadingDistribution: TextLeadingDistribution.even,
      fontVariations: [FontVariation('wght', weightAxis)],
    );
  }
}
