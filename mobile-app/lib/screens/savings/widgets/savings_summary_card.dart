import 'package:flutter/material.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/app_typography.dart';
import 'package:finance_ai_app/core/utils/currency_helper.dart';
import 'package:finance_ai_app/models/savings_goal.dart';

/// The total card of the savings screen (T9 spec 3.6, mockup R9): what all goals hold, a bar, the sum of their targets
/// and how many goals there are.
class SavingsSummaryCard extends StatelessWidget {
  const SavingsSummaryCard({super.key, required this.overview});

  static const Key barKey = ValueKey('savings-summary-bar');
  static const double _radius = 16;
  static const double _barHeight = 8;

  final SavingsOverview overview;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final loc = context.loc;
    final secondary = TextStyle(
      color: colors.onSurfaceVariant,
      fontSize: AppTextSize.secondary,
    );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(_radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(loc.savingsTotalSaved, style: secondary),
          const SizedBox(height: 4),
          Text(
            CurrencyHelper.formatVND(overview.totalSaved, loc, showSign: false),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.onSurface,
              fontSize: AppTextSize.amount,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(_barHeight),
            child: LinearProgressIndicator(
              key: barKey,
              value: overview.progress,
              minHeight: _barHeight,
              color: colors.primary,
              backgroundColor: colors.surfaceContainerHighest,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  loc.savingsTarget(
                    CurrencyHelper.formatVND(
                      overview.totalTarget,
                      loc,
                      showSign: false,
                    ),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: secondary,
                ),
              ),
              const SizedBox(width: 8),
              Text(loc.savingsGoalCount(overview.count), style: secondary),
            ],
          ),
        ],
      ),
    );
  }
}
