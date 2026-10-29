import 'package:finance_ai_app/models/budget_model.dart';
import 'package:finance_ai_app/models/budget_progress.dart';

/// What the budget band of the home screen shows: the budgets running today for one period (the month first, then
/// the week, then the year) taken as one total, how many days that period has left, and the category budget worth
/// naming under it.
class HomeBudgetSummary {
  /// The periods in the order the band prefers them.
  static const List<String> _periodOrder = [
    BudgetPeriodType.month,
    BudgetPeriodType.week,
    BudgetPeriodType.year,
  ];

  final String periodType;

  /// Today up to the last day of the period, both counted: 1 on the last day.
  final int daysLeft;

  /// The category budget of the period that is exceeded the most.
  final BudgetProgress? overCategory;

  /// The category budget of the period closest to its limit past the warning level; only when none is exceeded.
  final BudgetProgress? nearCategory;

  /// The total as one budget, so that the percent and level follow the rules of [BudgetProgress].
  final BudgetProgress _total;

  const HomeBudgetSummary._({
    required this.periodType,
    required this.daysLeft,
    required this.overCategory,
    required this.nearCategory,
    required BudgetProgress total,
  }) : _total = total;

  double get limit => _total.limit;
  double get spent => _total.spent;

  /// Negative once the total is exceeded.
  double get remaining => _total.remaining;
  double get percent => _total.percent;
  int get percentLabel => _total.percentLabel;

  /// The value of the ring: between 0 and 1.
  double get ringValue => _total.barValue;
  BudgetAlertLevel get level => _total.level;

  /// The summary of [active] (the budgets whose period contains [today]), or null when there is none. An
  /// all-categories budget of the chosen period is the total as it is; without one the category budgets of that
  /// period are added up.
  static HomeBudgetSummary? from(List<BudgetProgress> active, DateTime today) {
    for (final periodType in _periodOrder) {
      // A budget with no positive limit has nothing to measure against, so it is left out.
      final ofPeriod = [
        for (final progress in active)
          if (progress.budget.periodType == periodType && progress.limit > 0)
            progress,
      ];
      if (ofPeriod.isEmpty) continue;

      final categories = [
        for (final progress in ofPeriod)
          if (progress.budget.categoryName != null) progress,
      ];
      final allCategories = ofPeriod.where(
        (progress) => progress.budget.categoryName == null,
      );
      final first = ofPeriod.first.budget;
      final total = allCategories.isNotEmpty
          ? allCategories.first
          : BudgetProgress(
              budget: BudgetModel(
                amount: categories.fold(0.0, (sum, p) => sum + p.limit),
                periodType: periodType,
                startDate: first.startDate,
                endDate: first.endDate,
              ),
              spent: categories.fold(0.0, (sum, p) => sum + p.spent),
            );

      final over = _highest(
        categories.where((p) => p.level == BudgetAlertLevel.exceeded),
        (p) => -p.remaining,
      );
      final near = over != null
          ? null
          : _highest(
              categories.where((p) => p.level == BudgetAlertLevel.warning),
              (p) => p.percent,
            );

      // Counted on UTC dates, so a daylight-saving change in between cannot cut a day off.
      final day = DateTime.utc(today.year, today.month, today.day);
      final end = DateTime.utc(first.end.year, first.end.month, first.end.day);
      return HomeBudgetSummary._(
        periodType: periodType,
        daysLeft: end.difference(day).inDays + 1,
        overCategory: over,
        nearCategory: near,
        total: total,
      );
    }
    return null;
  }

  static BudgetProgress? _highest(
    Iterable<BudgetProgress> progresses,
    double Function(BudgetProgress) score,
  ) {
    BudgetProgress? best;
    for (final progress in progresses) {
      if (best == null || score(progress) > score(best)) best = progress;
    }
    return best;
  }
}
