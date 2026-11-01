import 'dart:math' as math;

import 'package:finance_ai_app/core/utils/savings_goal_planner.dart';
import 'package:finance_ai_app/models/savings_goal.dart';

/// What a contribution being typed does to a goal (T9 spec, 3.6): the percent before and after, and the two parts of
/// the progress bar (what is saved, and what this contribution adds). Percents are floored and capped at 100.
class ContributionPreview {
  const ContributionPreview._({
    required this.beforePercent,
    required this.afterPercent,
    required this.savedFraction,
    required this.addedFraction,
    required this.after,
  });

  factory ContributionPreview.of(SavingsGoal goal, double amount) {
    final added = math.max(0.0, amount);
    final after = goal.current + added;
    final target = goal.target;
    final saved = goal.progress;
    final afterFraction = target > 0 ? (after / target).clamp(0.0, 1.0) : 0.0;
    return ContributionPreview._(
      beforePercent: goal.percentLabel,
      afterPercent: (afterFraction * 100).floor(),
      savedFraction: saved,
      addedFraction: math.max(0.0, afterFraction - saved),
      after: after,
    );
  }

  final int beforePercent;
  final int afterPercent;

  /// The saved share of the bar, 0 to 1.
  final double savedFraction;

  /// The share this contribution adds; [savedFraction] + [addedFraction] never exceeds 1.
  final double addedFraction;

  /// The saved amount once the contribution is in.
  final double after;
}

/// The monthly contribution that keeps a goal on time (T9 spec, 3.6): what is missing over the months left to the
/// deadline ([SavingsGoalPlanner.monthlyNeed]), rounded up to 1.000 ₫ but never more than what is missing. [chip] is the
/// quick amount to badge "Gợi ý" and preselect: the smallest one not below [amount] and not above what is missing, null
/// when there is none (the field then starts with [amount] itself).
class ContributionSuggestion {
  const ContributionSuggestion._(this.amount, this.chip);

  /// The quick amounts of the sheet, 4 × 2: 50k, 100k, 200k, 500k, 1 tr, 2 tr, 3 tr, 5 tr.
  static const List<double> quickAmounts = [
    5e4,
    1e5,
    2e5,
    5e5,
    1e6,
    2e6,
    3e6,
    5e6,
  ];

  static const int _roundTo = 1000;

  /// Null when the goal is reached, has no deadline, or its deadline is past.
  static ContributionSuggestion? of(SavingsGoal goal, DateTime today) {
    if (goal.isDone || goal.remaining <= 0) return null;
    if (SavingsGoalPlanner.monthsLeft(goal.json, today) == null) return null;
    final need = math.min(
      SavingsGoalPlanner.monthlyNeed(goal.json, today),
      goal.remaining,
    );
    if (need <= 0) return null;
    // Whole dong first, so that a floating-point crumb never pushes it to the next thousand.
    final dong = need.round();
    final rounded = ((dong + _roundTo - 1) ~/ _roundTo * _roundTo).toDouble();
    // Rounding up must not put more in than the goal misses (1.500 ₫ left is asked as 1.500, not 2.000).
    final amount = math.min(rounded, goal.remaining);
    // A chip above what is missing would put more in than the goal needs.
    final chips = quickAmounts.where((q) => q >= amount && q <= goal.remaining);
    return ContributionSuggestion._(amount, chips.isEmpty ? null : chips.first);
  }

  final double amount;
  final double? chip;
}
