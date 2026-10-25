import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/app_theme.dart';
import 'package:finance_ai_app/core/utils/currency_helper.dart';
import 'package:finance_ai_app/l10n/app_localizations.dart';
import 'package:finance_ai_app/models/budget_model.dart';
import 'package:finance_ai_app/models/budget_progress.dart';

/// One budget with what has been spent of it: a progress bar that turns orange from 80% and red from 100%, and
/// text that says how much is left or by how much the limit was passed.
class BudgetProgressCard extends StatelessWidget {
  static final DateFormat _day = DateFormat('dd/MM/yyyy');

  final BudgetProgress progress;

  const BudgetProgressCard({super.key, required this.progress});

  Color _accentOf(ColorScheme colors, SemanticColors semantic) =>
      switch (progress.level) {
        BudgetAlertLevel.exceeded => colors.error,
        BudgetAlertLevel.warning => semantic.warningColor,
        BudgetAlertLevel.none => colors.primary,
      };

  static String _money(AppLocalizations loc, double amount) =>
      CurrencyHelper.formatVND(amount, loc, showSign: false);

  String _statusOf(AppLocalizations loc) {
    final left = _money(loc, progress.remaining);
    return switch (progress.level) {
      BudgetAlertLevel.exceeded => loc.budgetOverBy(
        _money(loc, -progress.remaining),
      ),
      BudgetAlertLevel.warning => loc.budgetNearLimitLeft(left),
      BudgetAlertLevel.none => loc.budgetLeft(left),
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final semantic = theme.semanticColors;
    final accent = _accentOf(colors, semantic);
    final detailStyle = TextStyle(color: colors.onSurfaceVariant, fontSize: 12);
    final budget = progress.budget;
    final loc = context.locOrDefault;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(colors),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  budget.categoryLabel(loc),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${_money(loc, progress.spent)} / ${_money(loc, progress.limit)}',
                style: detailStyle,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${BudgetPeriodType.label(loc, budget.periodType)} · ${_day.format(budget.start)} – ${_day.format(budget.end)}',
            style: detailStyle.copyWith(fontSize: 11),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.barValue,
              backgroundColor: colors.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(accent),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  _statusOf(loc),
                  style: TextStyle(
                    color: progress.level == BudgetAlertLevel.none
                        ? semantic.successColor
                        : accent,
                    fontSize: 12,
                  ),
                ),
              ),
              Text(
                '${progress.percentLabel}%',
                style: TextStyle(
                  color: accent,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
