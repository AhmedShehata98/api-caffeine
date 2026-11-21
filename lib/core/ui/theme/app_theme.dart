import 'package:flutter/material.dart';
import 'package:api_caffeine/core/ui/theme/app_fonts.dart';
import 'package:api_caffeine/core/ui/theme/app_spacing.dart';
import 'package:api_caffeine/core/ui/theme/http_colors.dart';

/// Material 3 themes seeded from the orange brand color. Dark is the primary theme.

abstract final class AppTheme {
  static const Color seed = Color(0xFFFF6A00);
  static const Color darkBackground = Color(0xFF1F1B2E);

  static final ThemeData dark = _build(
    ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark).copyWith(
      primary: seed,
      onPrimary: const Color(0xFF1F1B2E),
      surface: darkBackground,
      onSurface: const Color(0xFFF5F2FA),
      surfaceContainer: const Color(0xFF292537),
      surfaceContainerHigh: const Color(0xFF322E41),
      surfaceContainerHighest: const Color(0xFF403B50),
      outline: const Color(0xFF777184),
    ),
    HttpColors.dark,
    inputBorder: const Color(0xFF938C9F),
  );

  static final ThemeData light = _build(
    ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
    ).copyWith(
      primary: const Color(0xFFB84D00),
      onPrimary: Colors.white,
      surface: const Color(0xFFFFFAF7),
      onSurface: darkBackground,
      surfaceContainer: const Color(0xFFFBF4EF),
      surfaceContainerHigh: const Color(0xFFF9F0EB),
      surfaceContainerHighest: const Color(0xFFE9DBD4),
      outline: const Color(0xFF85766F),
    ),
    HttpColors.light,
    inputBorder: const Color(0xFF776960),
  );

  static ThemeData _build(
    ColorScheme scheme,
    HttpColors httpColors, {
    required Color inputBorder,
  }) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: AppFonts.ui,
    );

    final text = base.textTheme;

    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      textTheme: text.copyWith(
        displayLarge: text.displayLarge?.copyWith(
          fontFamily: AppFonts.headline,
        ),
        displayMedium: text.displayMedium?.copyWith(
          fontFamily: AppFonts.headline,
        ),
        displaySmall: text.displaySmall?.copyWith(
          fontFamily: AppFonts.headline,
        ),
        headlineLarge: text.headlineLarge?.copyWith(
          fontFamily: AppFonts.headline,
        ),
        headlineMedium: text.headlineMedium?.copyWith(
          fontFamily: AppFonts.headline,
        ),
        headlineSmall: text.headlineSmall?.copyWith(
          fontFamily: AppFonts.headline,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outline,
        space: 1,
        thickness: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          borderSide: BorderSide(color: inputBorder),
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.dialog),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        width: 480,
        backgroundColor: scheme.surfaceContainerHighest,
        contentTextStyle: text.bodyMedium?.copyWith(color: scheme.onSurface),
        actionTextColor: scheme.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
      ),
      extensions: [httpColors],
    );
  }
}
