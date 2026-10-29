import 'package:flutter/material.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/app_typography.dart';
import 'package:finance_ai_app/core/utils/currency_helper.dart';
import 'package:finance_ai_app/core/utils/savings_goal_planner.dart';
import 'package:finance_ai_app/l10n/app_localizations.dart';
import 'package:finance_ai_app/models/savings_goal.dart';
import 'package:finance_ai_app/screens/savings/widgets/goal_visual.dart';

/// The goals of one tab of the savings screen in a white card (T9 spec 3.6, mockup R9): icon, name, the deadline line,
/// a thin bar, and on the right what is still missing (or, once reached, what is saved). Tap and long press reach the
/// screen; swipe left asks [onDelete], which returns true once the goal is gone.
class SavingsGoalList extends StatelessWidget {
  const SavingsGoalList({
    super.key,
    required this.goals,
    required this.today,
    required this.onTap,
    required this.onLongPress,
    required this.onDelete,
  });

  static Key rowKey(String id) => ValueKey('savings-row-$id');
  static Key barKey(String id) => ValueKey('savings-bar-$id');

  static const double _radius = 16;

  final List<SavingsGoal> goals;
  final DateTime today;
  final ValueChanged<SavingsGoal> onTap;
  final ValueChanged<SavingsGoal> onLongPress;
  final Future<bool> Function(SavingsGoal) onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(_radius),
      child: ColoredBox(
        color: colors.surface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < goals.length; i++) ...[
              if (i > 0)
                Divider(height: 1, thickness: 1, color: colors.outlineVariant),
              _GoalRow(
                goal: goals[i],
                today: today,
                onTap: () => onTap(goals[i]),
                onLongPress: () => onLongPress(goals[i]),
                onDelete: () => onDelete(goals[i]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GoalRow extends StatelessWidget {
  const _GoalRow({
    required this.goal,
    required this.today,
    required this.onTap,
    required this.onLongPress,
    required this.onDelete,
  });

  static const double _barHeight = 4;
  static const double _swipeIconInset = 20;
  static const EdgeInsets _padding = EdgeInsets.symmetric(
    horizontal: 14,
    vertical: 12,
  );

  final SavingsGoal goal;
  final DateTime today;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final Future<bool> Function() onDelete;

  /// The line under the name and its colour (null = secondary text).
  (String, Color?) _meta(AppLocalizations loc, ThemeData theme) {
    if (goal.isDone) {
      return (loc.savingsReached, theme.semanticColors.successColor);
    }
    final deadline = goal.deadline;
    final days = SavingsGoalPlanner.daysLeft(deadline, today);
    if (deadline == null || days == null) return (loc.savingsNoDeadline, null);
    if (days < 0) {
      return (loc.savingsOverdue(deadline), theme.semanticColors.warningColor);
    }
    if (days == 0) return (loc.savingsDueToday(deadline), null);
    return (loc.savingsDaysLeft(days, deadline), null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final loc = context.loc;
    final (meta, metaColor) = _meta(loc, theme);
    final caption = TextStyle(
      color: colors.onSurfaceVariant,
      fontSize: AppTextSize.caption,
    );
    return Dismissible(
      key: SavingsGoalList.rowKey(goal.id),
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
          onLongPress: onLongPress,
          child: Padding(
            padding: _padding,
            child: Row(
              children: [
                GoalIconTile(title: goal.title),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        goal.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: AppTextSize.body,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: caption.copyWith(color: metaColor),
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(_barHeight),
                        child: LinearProgressIndicator(
                          key: SavingsGoalList.barKey(goal.id),
                          value: goal.progress,
                          minHeight: _barHeight,
                          color: goal.isDone
                              ? theme.semanticColors.successColor
                              : colors.primary,
                          backgroundColor: colors.surfaceContainerHighest,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (!goal.hasTarget)
                  Text(loc.savingsNoTarget, style: caption)
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        goal.isDone
                            ? loc.savingsSavedLabel
                            : loc.savingsMissing,
                        style: caption,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        CurrencyHelper.formatCompactVND(
                          goal.isDone ? goal.current : goal.remaining,
                          loc,
                        ),
                        style: TextStyle(
                          color: colors.onSurface,
                          fontSize: AppTextSize.body,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
