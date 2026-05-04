import 'package:flutter/material.dart';
import '../models/indicator_result.dart';
import '../theme/app_colors.dart';
import 'signal_badge.dart';

class IndicatorTile extends StatelessWidget {
  final IndicatorResult indicator;
  final bool compact;

  const IndicatorTile({
    super.key,
    required this.indicator,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 8 : 10,
      ),
      decoration: BoxDecoration(
        color: c.surfaceVariant,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  indicator.name,
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: compact ? 12 : 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  indicator.description,
                  style: TextStyle(color: c.textMuted, fontSize: compact ? 10 : 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SignalBadge(signal: indicator.signal, fontSize: compact ? 10 : 11),
              const SizedBox(height: 4),
              _SignalAgeBadge(age: indicator.signalAge, compact: compact),
            ],
          ),
        ],
      ),
    );
  }
}

class _SignalAgeBadge extends StatelessWidget {
  final int age;
  final bool compact;

  const _SignalAgeBadge({required this.age, required this.compact});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final (color, label) = age == 0
        ? (AppColors.bullish, 'Today')
        : age <= 3
            ? (AppColors.neutral, '${age}d ago')
            : (c.textMuted, '${age}d ago');

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.access_time_rounded, size: compact ? 9 : 10, color: color),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: compact ? 9 : 10,
            fontWeight: age == 0 ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}
