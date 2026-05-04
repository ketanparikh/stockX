import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class FilterSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool enabled;
  final ValueChanged<bool> onToggle;
  final Widget child;
  final String description;

  const FilterSection({
    super.key,
    required this.title,
    required this.icon,
    required this.enabled,
    required this.onToggle,
    required this.child,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: enabled ? c.card : c.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: enabled ? scheme.primary.withValues(alpha: 0.4) : c.border,
          width: enabled ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: enabled
                        ? scheme.primary.withValues(alpha: 0.15)
                        : c.border.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    size: 18,
                    color: enabled ? scheme.primary : c.textMuted,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: enabled ? c.textPrimary : c.textSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        description,
                        style: TextStyle(color: c.textMuted, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: enabled,
                  onChanged: onToggle,
                  activeColor: scheme.primary,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
          ),
          if (enabled) ...[
            Divider(height: 1, color: c.divider),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: child,
            ),
          ],
        ],
      ),
    );
  }
}

class SignalSelector extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final List<String> options;

  const SignalSelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.options = const ['ANY', 'BUY', 'SELL'],
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Row(
      children: options.map((opt) {
        final isSelected = value == opt;
        Color optColor;
        switch (opt) {
          case 'BUY':
            optColor = AppColors.bullish;
          case 'SELL':
            optColor = AppColors.bearish;
          case 'NEUTRAL':
            optColor = AppColors.neutral;
          default:
            optColor = c.textSecondary;
        }
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(opt),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.symmetric(horizontal: 2),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? optColor.withValues(alpha: 0.15) : c.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? optColor : c.border,
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Text(
                opt,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isSelected ? optColor : c.textMuted,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class LabeledSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;
  final String Function(double)? formatter;

  const LabeledSlider({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
    this.formatter,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: c.textSecondary, fontSize: 12)),
            Text(
              formatter != null ? formatter!(value) : value.toStringAsFixed(0),
              style: TextStyle(
                color: scheme.primary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(trackHeight: 3),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
