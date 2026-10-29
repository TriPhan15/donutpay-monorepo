import 'package:flutter/material.dart';

import 'package:finance_ai_app/core/theme/app_typography.dart';

/// A pill-shaped toggle of a few equal parts (T9 spec, 3.1 and 3.4): the chosen part is filled with the primary colour.
class PillSegmented<T> extends StatelessWidget {
  const PillSegmented({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.height = 36,
  });

  @visibleForTesting
  static const Key trackKey = ValueKey('pill-segmented-track');

  static const double _inset = 3;
  static const Duration _fade = Duration(milliseconds: 200);

  /// Each value with its label, in display order.
  final List<(T, String)> options;
  final T selected;
  final ValueChanged<T> onChanged;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(height / 2);
    return Container(
      key: trackKey,
      height: height,
      padding: const EdgeInsets.all(_inset),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: radius,
      ),
      child: Row(
        children: [
          for (final (value, label) in options)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(value),
                child: AnimatedContainer(
                  duration: _fade,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: value == selected
                        ? colors.primary
                        : Colors.transparent,
                    borderRadius: radius,
                  ),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: value == selected
                          ? colors.onPrimary
                          : colors.onSurfaceVariant,
                      fontSize: AppTextSize.secondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
