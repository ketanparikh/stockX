import 'package:flutter/material.dart';

class AppColors {
  static const Color background = Color(0xFF0D0D0D);
  static const Color surface = Color(0xFF1A1A2E);
  static const Color surfaceVariant = Color(0xFF16213E);
  static const Color card = Color(0xFF1E1E30);
  static const Color cardHover = Color(0xFF252540);

  static const Color primary = Color(0xFF6C63FF);
  static const Color primaryLight = Color(0xFF9D97FF);
  static const Color accent = Color(0xFF00D4FF);

  static const Color bullish = Color(0xFF00C896);
  static const Color bullishLight = Color(0xFF00E5AB);
  static const Color bearish = Color(0xFFFF4D6A);
  static const Color bearishLight = Color(0xFFFF7D8F);
  static const Color neutral = Color(0xFFFFB347);

  static const Color textPrimary = Color(0xFFE8E8F0);
  static const Color textSecondary = Color(0xFF9090A8);
  static const Color textMuted = Color(0xFF606078);

  static const Color border = Color(0xFF2A2A45);
  static const Color divider = Color(0xFF1E1E35);

  static const Color rsiOversold = Color(0xFF00C896);
  static const Color rsiOverbought = Color(0xFFFF4D6A);
  static const Color rsiNeutral = Color(0xFFFFB347);

  static const List<Color> chartGradientBull = [
    Color(0x4000C896),
    Color(0x0000C896),
  ];
  static const List<Color> chartGradientBear = [
    Color(0x40FF4D6A),
    Color(0x00FF4D6A),
  ];
}
