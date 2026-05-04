import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  // ── Dark ──────────────────────────────────────────────────────────────────

  static ThemeData get dark => _build(
        brightness: Brightness.dark,
        scheme: const ColorScheme.dark(
          primary:            Color(0xFF2962FF),
          primaryContainer:   Color(0xFF1A3ABF),
          secondary:          Color(0xFF00BCD4),
          surface:            Color(0xFF131722),
          error:              Color(0xFFEF5350),
          onPrimary:          Colors.white,
          onSecondary:        Colors.white,
          onSurface:          Color(0xFFD1D4DC),
          onError:            Colors.white,
        ),
        surfaces: AppSurfaces.dark,
        isLight: false,
      );

  // ── Light ─────────────────────────────────────────────────────────────────

  static ThemeData get light => _build(
        brightness: Brightness.light,
        scheme: const ColorScheme.light(
          primary:            Color(0xFF2962FF),
          primaryContainer:   Color(0xFFD6E4FF),
          secondary:          Color(0xFF0097A7),
          surface:            Color(0xFFFFFFFF),
          error:              Color(0xFFEF5350),
          onPrimary:          Colors.white,
          onSecondary:        Colors.white,
          onSurface:          Color(0xFF0D1421),
          onError:            Colors.white,
        ),
        surfaces: AppSurfaces.light,
        isLight: true,
      );

  // ── Builder ───────────────────────────────────────────────────────────────

  static ThemeData _build({
    required Brightness brightness,
    required ColorScheme scheme,
    required AppSurfaces surfaces,
    required bool isLight,
  }) {
    final s = surfaces;

    // Card shadow — visible only in light mode for depth
    final cardShadow = isLight
        ? [BoxShadow(color: const Color(0x0A000000), blurRadius: 8, offset: const Offset(0, 2))]
        : <BoxShadow>[];

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      extensions: [s],

      scaffoldBackgroundColor: s.scaffold,

      // ── AppBar ────────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: s.card,
        foregroundColor: s.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: s.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: s.textSecondary, size: 22),
        actionsIconTheme: IconThemeData(color: s.textSecondary),
        surfaceTintColor: Colors.transparent,
        shadowColor: isLight ? const Color(0x14000000) : Colors.transparent,
        shape: Border(bottom: BorderSide(color: s.border, width: 0.5)),
      ),

      // ── Cards ─────────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: s.card,
        elevation: isLight ? 0 : 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: s.border, width: 0.8),
        ),
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
      ),

      // ── Chips ─────────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: s.surfaceVariant,
        selectedColor: scheme.primary.withValues(alpha: 0.18),
        disabledColor: s.border,
        labelStyle: TextStyle(color: s.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
        secondaryLabelStyle: TextStyle(color: scheme.primary, fontSize: 12, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: s.border, width: 0.8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        side: BorderSide(color: s.border, width: 0.8),
      ),

      // ── Dividers ──────────────────────────────────────────────────────────
      dividerTheme: DividerThemeData(color: s.divider, thickness: 0.5, space: 0),

      // ── Inputs ────────────────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: s.surfaceVariant,
        hintStyle: TextStyle(color: s.textMuted, fontSize: 14),
        labelStyle: TextStyle(color: s.textSecondary, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: s.border, width: 0.8),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: s.border, width: 0.8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        isDense: true,
      ),

      // ── Buttons ───────────────────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: Colors.white,
          elevation: isLight ? 2 : 0,
          shadowColor: scheme.primary.withValues(alpha: 0.35),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.2),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          side: BorderSide(color: scheme.primary.withValues(alpha: 0.5)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),

      // ── Switch ────────────────────────────────────────────────────────────
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.primary;
          return isLight ? const Color(0xFFBDBDBD) : const Color(0xFF616161);
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return scheme.primary.withValues(alpha: 0.35);
          }
          return s.surfaceVariant;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.transparent;
          return s.border;
        }),
      ),

      // ── Slider ────────────────────────────────────────────────────────────
      sliderTheme: SliderThemeData(
        activeTrackColor:   scheme.primary,
        thumbColor:         scheme.primary,
        inactiveTrackColor: s.border,
        overlayColor:       scheme.primary.withValues(alpha: 0.12),
        thumbShape:         const RoundSliderThumbShape(enabledThumbRadius: 6),
        trackHeight:        3,
        activeTickMarkColor:   Colors.transparent,
        inactiveTickMarkColor: Colors.transparent,
      ),

      // ── Bottom nav ────────────────────────────────────────────────────────
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: s.card,
        selectedItemColor: scheme.primary,
        unselectedItemColor: s.textMuted,
        selectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      // ── Text ──────────────────────────────────────────────────────────────
      textTheme: TextTheme(
        displayLarge:  TextStyle(color: s.textPrimary, fontWeight: FontWeight.w800, letterSpacing: -1.0),
        displayMedium: TextStyle(color: s.textPrimary, fontWeight: FontWeight.w700, letterSpacing: -0.5),
        displaySmall:  TextStyle(color: s.textPrimary, fontWeight: FontWeight.w700, letterSpacing: -0.3),
        headlineLarge: TextStyle(color: s.textPrimary, fontWeight: FontWeight.w700, fontSize: 22, letterSpacing: -0.3),
        headlineMedium:TextStyle(color: s.textPrimary, fontWeight: FontWeight.w600, fontSize: 18),
        titleLarge:    TextStyle(color: s.textPrimary, fontWeight: FontWeight.w700, fontSize: 17, letterSpacing: -0.2),
        titleMedium:   TextStyle(color: s.textPrimary, fontWeight: FontWeight.w600, fontSize: 15),
        titleSmall:    TextStyle(color: s.textSecondary, fontWeight: FontWeight.w500, fontSize: 13),
        bodyLarge:     TextStyle(color: s.textPrimary,   fontSize: 15, height: 1.5),
        bodyMedium:    TextStyle(color: s.textSecondary, fontSize: 13, height: 1.5),
        bodySmall:     TextStyle(color: s.textMuted,     fontSize: 11, height: 1.4),
        labelLarge:    TextStyle(color: s.textPrimary,   fontSize: 14, fontWeight: FontWeight.w600),
        labelMedium:   TextStyle(color: s.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
        labelSmall:    TextStyle(color: s.textMuted,     fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.3),
      ),

      // ── Misc ──────────────────────────────────────────────────────────────
      iconTheme: IconThemeData(color: s.textSecondary, size: 20),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: Colors.white,
        elevation: isLight ? 4 : 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isLight ? s.card : const Color(0xFF252A3E),
        contentTextStyle: TextStyle(color: s.textPrimary, fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        behavior: SnackBarBehavior.floating,
        elevation: 4,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: s.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titleTextStyle: TextStyle(color: s.textPrimary, fontSize: 17, fontWeight: FontWeight.w700),
        contentTextStyle: TextStyle(color: s.textSecondary, fontSize: 14),
        elevation: isLight ? 8 : 4,
      ),
    );
  }
}
