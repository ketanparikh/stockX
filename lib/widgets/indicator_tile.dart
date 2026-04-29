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
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 8 : 10,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
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
                    color: AppColors.textPrimary,
                    fontSize: compact ? 12 : 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  indicator.description,
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: compact ? 10 : 11,
                  ),
                ),
              ],
            ),
          ),
          SignalBadge(signal: indicator.signal, fontSize: compact ? 10 : 11),
        ],
      ),
    );
  }
}
