import 'package:flutter/material.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/app_typography.dart';
import 'package:finance_ai_app/core/theme/band_colors.dart';
import 'package:finance_ai_app/core/utils/currency_helper.dart';
import 'package:finance_ai_app/models/budget_model.dart';
import 'package:finance_ai_app/models/home_budget_summary.dart';

/// The line under the tabs in the band of the budget screen (T9 spec, 3.5, mockup K5): a small white ring with the
/// share spent, "Tháng này 6,02 tr / 8 tr" and, on the right, what is left or how much the total is exceeded by.
class BudgetBandSummary extends StatelessWidget {
  const BudgetBandSummary({super.key, required this.summary});

  static const double _ringSize = 34;
  static const double _stroke = 4;
  static const double _ringTrackAlpha = 0.3;

  final HomeBudgetSummary summary;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final over = summary.remaining < 0;
    final remaining = CurrencyHelper.formatCompactVND(
      summary.remaining.abs(),
      loc,
    );
    return Row(
      children: [
        SizedBox.square(
          dimension: _ringSize,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CircularProgressIndicator(
                value: summary.ringValue,
                strokeWidth: _stroke,
                strokeCap: StrokeCap.round,
                color: BandColors.primary,
                backgroundColor: BandColors.primary.withValues(
                  alpha: _ringTrackAlpha,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(_stroke + 1),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${summary.percentLabel}%',
                    style: const TextStyle(
                      color: BandColors.primary,
                      fontSize: AppTextSize.caption,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text.rich(
            TextSpan(
              style: const TextStyle(
                color: BandColors.secondary,
                fontSize: AppTextSize.caption,
              ),
              children: [
                TextSpan(
                  text:
                      '${BudgetPeriodType.currentLabel(loc, summary.periodType)} ',
                ),
                TextSpan(
                  text: CurrencyHelper.formatCompactVND(summary.spent, loc),
                  style: const TextStyle(
                    color: BandColors.primary,
                    fontSize: AppTextSize.body,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextSpan(
                  text:
                      ' / ${CurrencyHelper.formatCompactVND(summary.limit, loc)}',
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          over ? loc.budgetOver(remaining) : loc.budgetLeft(remaining),
          maxLines: 1,
          style: const TextStyle(
            color: BandColors.primary,
            fontSize: AppTextSize.caption,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
