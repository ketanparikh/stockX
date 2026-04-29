import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  // ── Dark ──────────────────────────────────────────────────────────────────

  static ThemeData get dark => _build(Brightness.dark, _darkScheme, _darkSurfaces);

  static const _darkScheme = ColorScheme.dark(
    primary: AppColors.primary,
    secondary: AppColors.accent,
    surface: AppColors.surface,
    error: AppColors.bearish,
    onPrimary: Colors.white,
    onSecondary: Colors.white,
    onSurface: AppColors.textPrimary,
  );

  static const _darkSurfaces = _SurfaceTokens(
    scaffold: AppColors.background,
    appBar: AppColors.surface,
    card: AppColors.card,
    surfaceVariant: AppColors.surfaceVariant,
    border: AppColors.border,
    divider: AppColors.divider,
    textPrimary: AppColors.textPrimary,
    textSecondary: AppColors.textSecondary,
    textMuted: AppColors.textMuted,
    fillColor: AppColors.surfaceVariant,
    sliderInactive: AppColors.border,
  );

  // ── Light ─────────────────────────────────────────────────────────────────

  static ThemeData get light => _build(Brightness.light, _lightScheme, _lightSurfaces);

  static const _lightScheme = ColorScheme.light(
    primary: Color(0xFF5B52E0),       // slightly deeper purple for contrast on white
    secondary: Color(0xFF0099BB),
    surface: Color(0xFFFFFFFF),
    error: AppColors.bearish,
    onPrimary: Colors.white,
    onSecondary: Colors.white,
    onSurface: Color(0xFF111128),
  );

  static const _lightSurfaces = _SurfaceTokens(
    scaffold: Color(0xFFF4F4FB),
    appBar: Color(0xFFFFFFFF),
    card: Color(0xFFFFFFFF),
    surfaceVariant: Color(0xFFF0F0F8),
    border: Color(0xFFDDDDEE),
    divider: Color(0xFFEAEAF5),
    textPrimary: Color(0xFF111128),
    textSecondary: Color(0xFF44445A),
    textMuted: Color(0xFF8888A0),
    fillColor: Color(0xFFF0F0F8),
    sliderInactive: Color(0xFFCCCCDD),
  );

  // ── Builder ───────────────────────────────────────────────────────────────

  static ThemeData _build(
    Brightness brightness,
    ColorScheme scheme,
    _SurfaceTokens t,
  ) {
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: t.scaffold,
      appBarTheme: AppBarTheme(
        backgroundColor: t.appBar,
        foregroundColor: t.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: t.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: t.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: t.border),
        ),
        margin: EdgeInsets.zero,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: t.surfaceVariant,
        selectedColor: scheme.primary.withOpacity(0.15),
        labelStyle: TextStyle(color: t.textSecondary, fontSize: 12),
        secondaryLabelStyle: TextStyle(color: scheme.primary, fontSize: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: t.border),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
      dividerTheme: DividerThemeData(color: t.divider, thickness: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: t.fillColor,
        hintStyle: TextStyle(color: t.textMuted),
        labelStyle: TextStyle(color: t.textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: t.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: t.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          disabledBackgroundColor: t.border,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: scheme.primary,
        thumbColor: scheme.primary,
        inactiveTrackColor: t.sliderInactive,
        overlayColor: scheme.primary.withOpacity(0.12),
        trackHeight: 3,
      ),
      textTheme: TextTheme(
        displayLarge:  TextStyle(color: t.textPrimary,   fontWeight: FontWeight.w800),
        displayMedium: TextStyle(color: t.textPrimary,   fontWeight: FontWeight.w700),
        titleLarge:    TextStyle(color: t.textPrimary,   fontWeight: FontWeight.w700, fontSize: 18),
        titleMedium:   TextStyle(color: t.textPrimary,   fontWeight: FontWeight.w600, fontSize: 16),
        titleSmall:    TextStyle(color: t.textSecondary, fontWeight: FontWeight.w500, fontSize: 13),
        bodyLarge:     TextStyle(color: t.textPrimary,   fontSize: 15),
        bodyMedium:    TextStyle(color: t.textSecondary, fontSize: 13),
        bodySmall:     TextStyle(color: t.textMuted,     fontSize: 11),
        labelLarge:    TextStyle(color: t.textPrimary,   fontSize: 14, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Internal token bag to avoid duplicating the builder for dark vs light.
class _SurfaceTokens {
  final Color scaffold;
  final Color appBar;
  final Color card;
  final Color surfaceVariant;
  final Color border;
  final Color divider;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color fillColor;
  final Color sliderInactive;

  const _SurfaceTokens({
    required this.scaffold,
    required this.appBar,
    required this.card,
    required this.surfaceVariant,
    required this.border,
    required this.divider,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.fillColor,
    required this.sliderInactive,
  });
}
