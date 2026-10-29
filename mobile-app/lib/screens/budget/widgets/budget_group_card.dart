import 'package:flutter/material.dart';

import 'package:finance_ai_app/core/constants/transaction_categories.dart';
import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/app_typography.dart';
import 'package:finance_ai_app/core/theme/category_colors.dart';
import 'package:finance_ai_app/core/utils/currency_helper.dart';
import 'package:finance_ai_app/models/budget_progress.dart';

/// Which of the two groups of the budget screen a card holds.
enum BudgetGroupKind { over, within }

/// A group of the budget screen (T9 spec, 3.5, mockup D6): a white card whose header is tinted in the colour of the
/// group ("Đang vượt" red with a warning icon, "Trong mức" green with a tick), then one [BudgetRow] per budget.
class BudgetGroupCard extends StatelessWidget {
  const BudgetGroupCard({
    super.key,
    required this.kind,
    required this.items,
    required this.onTap,
    required this.onDelete,
  });

  static const double _radius = 16;
  static const double _iconSize = 16;
  static const double _iconGap = 7;
  static const EdgeInsets _headerPadding = EdgeInsets.symmetric(
    horizontal: 14,
    vertical: 9,
  );

  /// The alpha of the header tint over the card.
  static const double headerTintAlpha = 0.12;

  static Key headerKey(BudgetGroupKind kind) =>
      ValueKey('budget-group-header-${kind.name}');

  final BudgetGroupKind kind;
  final List<BudgetProgress> items;
  final ValueChanged<BudgetProgress> onTap;

  /// Asks and deletes; true when the budget is gone, so its row leaves the list.
  final Future<bool> Function(BudgetProgress) onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final loc = context.loc;
    final isOver = kind == BudgetGroupKind.over;
    final accent = isOver ? colors.error : theme.semanticColors.successColor;
    return ClipRRect(
      borderRadius: BorderRadius.circular(_radius),
      child: ColoredBox(
        color: colors.surface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              key: headerKey(kind),
              color: accent.withValues(alpha: headerTintAlpha),
              padding: _headerPadding,
              child: Row(
                children: [
                  Icon(
                    isOver
                        ? Icons.warning_amber_rounded
                        : Icons.check_circle_rounded,
                    color: accent,
                    size: _iconSize,
                  ),
                  const SizedBox(width: _iconGap),
                  Expanded(
                    child: Text(
                      isOver ? loc.budgetGroupOver : loc.budgetGroupWithin,
                      style: TextStyle(
                        color: accent,
                        fontSize: AppTextSize.secondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    loc.budgetGroupCount(items.length),
                    style: TextStyle(
                      color: accent,
                      fontSize: AppTextSize.caption,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0)
                Divider(height: 1, thickness: 1, color: colors.outlineVariant),
              BudgetRow(
                progress: items[i],
                onTap: () => onTap(items[i]),
                onDelete: () => onDelete(items[i]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One budget: its category tile and name, what is left (or how much it is over), spent / limit with the percent, and
/// a thin bar that turns orange from 80% and red from 100% (T9 spec, 3.5 and 7). Tap edits it; swipe left deletes it.
class BudgetRow extends StatelessWidget {
  const BudgetRow({
    super.key,
    required this.progress,
    required this.onTap,
    required this.onDelete,
  });

  static const double _tileSize = 32;
  static const double _tileRadius = 11;
  static const double _iconSize = 16;
  static const double _barHeight = 5;
  static const double _swipeIconInset = 20;
  static const EdgeInsets _padding = EdgeInsets.symmetric(
    horizontal: 14,
    vertical: 11,
  );

  static Key barKey(int? id) => ValueKey('budget-bar-$id');

  final BudgetProgress progress;
  final VoidCallback onTap;
  final Future<bool> Function() onDelete;

  /// The bar colour of a budget at [level].
  static Color barColor(BudgetAlertLevel level, ThemeData theme) =>
      switch (level) {
        BudgetAlertLevel.exceeded => theme.colorScheme.error,
        BudgetAlertLevel.warning => theme.semanticColors.warningColor,
        BudgetAlertLevel.none => theme.colorScheme.primary,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final loc = context.loc;
    final budget = progress.budget;
    final categoryName = budget.categoryName;
    final accent = categoryName == null
        ? colors.primary
        : CategoryColors.accentFor(categoryName, colors);
    final isOver = progress.remaining < 0;
    final left = CurrencyHelper.formatCompactVND(progress.remaining.abs(), loc);
    final secondary = TextStyle(
      color: colors.onSurfaceVariant,
      fontSize: AppTextSize.secondary,
    );

    return Dismissible(
      key: ValueKey('budget-row-${budget.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => onDelete(),
      background: Container(
        color: colors.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: _swipeIconInset),
        child: Icon(
          Icons.delete_outline_rounded,
          color: colors.error,
          semanticLabel: loc.commonDelete,
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: _padding,
            child: Row(
              children: [
                Container(
                  width: _tileSize,
                  height: _tileSize,
                  decoration: BoxDecoration(
                    color: CategoryColors.tileFor(accent, theme.brightness),
                    borderRadius: BorderRadius.circular(_tileRadius),
                  ),
                  child: Icon(
                    categoryName == null
                        ? Icons.pie_chart_rounded
                        : TransactionCategories.iconFor(categoryName),
                    color: accent,
                    size: _iconSize,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              budget.categoryLabel(loc),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: AppTextSize.body,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isOver
                                ? loc.budgetOver(left)
                                : loc.budgetLeft(left),
                            maxLines: 1,
                            style: TextStyle(
                              color: isOver ? colors.error : colors.onSurface,
                              fontSize: AppTextSize.body,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              loc.budgetAmounts(
                                CurrencyHelper.formatCompactVND(
                                  progress.spent,
                                  loc,
                                ),
                                CurrencyHelper.formatCompactVND(
                                  progress.limit,
                                  loc,
                                ),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: secondary,
                            ),
                          ),
                          Text('${progress.percentLabel}%', style: secondary),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(_barHeight),
                        child: LinearProgressIndicator(
                          key: barKey(budget.id),
                          value: progress.barValue,
                          minHeight: _barHeight,
                          color: barColor(progress.level, theme),
                          backgroundColor: colors.surfaceContainerHighest,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
