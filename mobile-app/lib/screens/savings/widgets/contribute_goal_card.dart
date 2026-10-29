import 'package:flutter/material.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/app_typography.dart';
import 'package:finance_ai_app/core/utils/currency_helper.dart';
import 'package:finance_ai_app/models/contribution_plan.dart';
import 'package:finance_ai_app/models/savings_goal.dart';
import 'package:finance_ai_app/screens/savings/widgets/goal_visual.dart';

/// The goal at the top of the "Góp tiền" sheet (T9 spec 3.6, mockups T1 + P1). It follows the amount being typed:
/// "60% → 68%", a bar with the saved part in the primary colour and this contribution in the pending colour, and
/// "15 tr + 2 tr = 17 / 25 tr". Without an amount it shows the goal as it is.
class ContributeGoalCard extends StatelessWidget {
  const ContributeGoalCard({
    super.key,
    required this.goal,
    required this.amount,
  });

  static const Key savedSegmentKey = ValueKey('contribute-saved-segment');
  static const Key addedSegmentKey = ValueKey('contribute-added-segment');

  static const double _radius = 16;
  static const double _iconSize = 42;
  static const double _iconRadius = 12;
  static const double _barHeight = 8;

  final SavingsGoal goal;

  /// The amount typed; 0 or less means none yet.
  final double amount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final loc = context.loc;
    final preview = ContributionPreview.of(goal, amount);
    final hasAmount = amount > 0;
    String compact(double value) => CurrencyHelper.formatCompactVND(value, loc);
    final muted = TextStyle(
      color: colors.onSurfaceVariant,
      fontSize: AppTextSize.secondary,
    );
    final strong = TextStyle(
      color: colors.onSurface,
      fontSize: AppTextSize.secondary,
      fontWeight: FontWeight.w700,
    );
    final totals = loc.savingsAmountsOf(
      compact(preview.after),
      compact(goal.target),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(_radius),
      ),
      child: Row(
        children: [
          GoalIconTile(title: goal.title, size: _iconSize, radius: _iconRadius),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Expanded(
                      child: Text(
                        goal.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.onSurface,
                          fontSize: AppTextSize.title,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text.rich(
                      TextSpan(
                        children: [
                          if (hasAmount)
                            TextSpan(
                              text: '${preview.beforePercent}% → ',
                              style: muted,
                            ),
                          TextSpan(
                            text: '${preview.afterPercent}%',
                            style: TextStyle(
                              color: colors.primary,
                              fontSize: AppTextSize.title,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                ClipRRect(
                  borderRadius: BorderRadius.circular(_barHeight),
                  child: SizedBox(
                    height: _barHeight,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ColoredBox(color: colors.surfaceContainerHighest),
                        FractionallySizedBox(
                          key: addedSegmentKey,
                          alignment: Alignment.centerLeft,
                          widthFactor:
                              preview.savedFraction + preview.addedFraction,
                          child: ColoredBox(
                            color: theme.semanticColors.pendingProgressColor,
                          ),
                        ),
                        FractionallySizedBox(
                          key: savedSegmentKey,
                          alignment: Alignment.centerLeft,
                          widthFactor: preview.savedFraction,
                          child: ColoredBox(color: colors.primary),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text.rich(
                  TextSpan(
                    children: [
                      if (hasAmount)
                        TextSpan(
                          text:
                              '${loc.savingsContributeAddition(compact(goal.current), compact(amount))} ',
                          style: muted,
                        ),
                      TextSpan(text: totals, style: strong),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
