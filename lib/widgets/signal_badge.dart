import 'package:flutter/material.dart';
import '../models/indicator_result.dart';
import '../theme/app_colors.dart';

class SignalBadge extends StatelessWidget {
  final SignalType signal;
  final double fontSize;

  const SignalBadge({super.key, required this.signal, this.fontSize = 11});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (signal) {
      SignalType.buy => (AppColors.bullish, 'BUY'),
      SignalType.sell => (AppColors.bearish, 'SELL'),
      SignalType.neutral => (AppColors.neutral, 'NEUTRAL'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.4), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
