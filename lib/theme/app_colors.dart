import 'package:flutter/material.dart';

// ── Static semantic colors (theme-independent) ────────────────────────────────

class AppColors {
  // Primary brand — TradingView blue
  static const Color primary      = Color(0xFF2962FF);
  static const Color primaryLight = Color(0xFF6B8EFF);
  static const Color accent       = Color(0xFF00BCD4);

  // Bullish / Bearish — industry-standard financial colors
  static const Color bullish      = Color(0xFF26A69A);   // teal-green (TradingView)
  static const Color bullishLight = Color(0xFF4DB6AC);
  static const Color bullishBg    = Color(0x1A26A69A);

  static const Color bearish      = Color(0xFFEF5350);   // clean red
  static const Color bearishLight = Color(0xFFEF9A9A);
  static const Color bearishBg    = Color(0x1AEF5350);

  static const Color neutral      = Color(0xFFFFA726);   // amber
  static const Color neutralLight = Color(0xFFFFCC02);
  static const Color neutralBg    = Color(0x1AFFA726);

  static const Color info         = Color(0xFF42A5F5);
  static const Color infoBg       = Color(0x1A42A5F5);

  static const List<Color> chartGradientBull = [Color(0x3326A69A), Color(0x0026A69A)];
  static const List<Color> chartGradientBear = [Color(0x33EF5350), Color(0x00EF5350)];
}

// ── Theme-aware surface tokens ────────────────────────────────────────────────

class AppSurfaces extends ThemeExtension<AppSurfaces> {
  final Color scaffold;
  final Color card;
  final Color surfaceVariant;
  final Color border;
  final Color divider;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  const AppSurfaces({
    required this.scaffold,
    required this.card,
    required this.surfaceVariant,
    required this.border,
    required this.divider,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
  });

  // ── Dark — TradingView-inspired ───────────────────────────────────────────
  static const dark = AppSurfaces(
    scaffold:       Color(0xFF0B0E11),   // near-black
    card:           Color(0xFF131722),   // TradingView card bg
    surfaceVariant: Color(0xFF1C2030),   // slightly lifted
    border:         Color(0xFF2A2F45),
    divider:        Color(0xFF1E2235),
    textPrimary:    Color(0xFFD1D4DC),   // TradingView body text
    textSecondary:  Color(0xFF787B86),
    textMuted:      Color(0xFF4C525E),
  );

  // ── Light — Clean professional ────────────────────────────────────────────
  static const light = AppSurfaces(
    scaffold:       Color(0xFFF0F3FA),   // cool blue-tinted gray
    card:           Color(0xFFFFFFFF),
    surfaceVariant: Color(0xFFEBEEF8),
    border:         Color(0xFFD1D5E4),
    divider:        Color(0xFFE4E8F4),
    textPrimary:    Color(0xFF0D1421),   // deep navy
    textSecondary:  Color(0xFF4A5270),
    textMuted:      Color(0xFF8A8FA8),
  );

  @override
  AppSurfaces copyWith({
    Color? scaffold, Color? card, Color? surfaceVariant,
    Color? border, Color? divider,
    Color? textPrimary, Color? textSecondary, Color? textMuted,
  }) => AppSurfaces(
    scaffold:       scaffold       ?? this.scaffold,
    card:           card           ?? this.card,
    surfaceVariant: surfaceVariant ?? this.surfaceVariant,
    border:         border         ?? this.border,
    divider:        divider        ?? this.divider,
    textPrimary:    textPrimary    ?? this.textPrimary,
    textSecondary:  textSecondary  ?? this.textSecondary,
    textMuted:      textMuted      ?? this.textMuted,
  );

  @override
  AppSurfaces lerp(AppSurfaces? other, double t) {
    if (other == null) return this;
    return AppSurfaces(
      scaffold:       Color.lerp(scaffold,       other.scaffold,       t)!,
      card:           Color.lerp(card,           other.card,           t)!,
      surfaceVariant: Color.lerp(surfaceVariant, other.surfaceVariant, t)!,
      border:         Color.lerp(border,         other.border,         t)!,
      divider:        Color.lerp(divider,         other.divider,        t)!,
      textPrimary:    Color.lerp(textPrimary,    other.textPrimary,    t)!,
      textSecondary:  Color.lerp(textSecondary,  other.textSecondary,  t)!,
      textMuted:      Color.lerp(textMuted,       other.textMuted,      t)!,
    );
  }
}

// ── Convenience shortcut: context.appColors.card ─────────────────────────────

extension AppSurfacesContext on BuildContext {
  AppSurfaces get appColors =>
      Theme.of(this).extension<AppSurfaces>() ?? AppSurfaces.dark;
}
