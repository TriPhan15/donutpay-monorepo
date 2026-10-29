import 'package:flutter/material.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/app_theme.dart';
import 'package:finance_ai_app/core/theme/app_typography.dart';
import 'package:finance_ai_app/core/theme/band_colors.dart';
import 'package:finance_ai_app/models/budget_model.dart';

/// The Tuần / Tháng / Năm tabs inside the blue band of the budget screen (T9 spec, 3.5): a white translucent track,
/// the chosen tab a white pill with dark blue text. The same in light and dark, like the band.
class BudgetPeriodTabs extends StatelessWidget {
  const BudgetPeriodTabs({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  static const double _height = 38;
  static const double _inset = 4;
  static const Duration _fade = Duration(milliseconds: 200);

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(_height / 2);
    return Container(
      height: _height,
      padding: const EdgeInsets.all(_inset),
      decoration: BoxDecoration(color: BandColors.tint, borderRadius: radius),
      child: Row(
        children: [
          for (final type in BudgetPeriodType.values)
            Expanded(
              child: Semantics(
                button: true,
                selected: type == selected,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(type),
                  child: AnimatedContainer(
                    duration: _fade,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: type == selected
                          ? BandColors.primary
                          : Colors.transparent,
                      borderRadius: radius,
                    ),
                    child: Text(
                      BudgetPeriodType.label(context.loc, type),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: type == selected
                            ? AppTheme.primaryDark
                            : BandColors.primary,
                        fontSize: AppTextSize.secondary,
                        fontWeight: FontWeight.w600,
                      ),
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
