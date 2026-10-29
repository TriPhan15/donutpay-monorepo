import 'package:finance_ai_app/models/budget_model.dart';
import 'package:finance_ai_app/models/budget_progress.dart';
import 'package:finance_ai_app/models/home_budget_summary.dart';
import 'package:finance_ai_app/models/transaction_model.dart';

/// What the budget screen shows for one tab (T9 spec, 3.5): the budgets of [periodType] whose period runs today,
/// split into the exceeded ones and the others, and their total for the band.
class BudgetOverview {
  /// The tabs in the order the screen prefers them when it opens, as on the home screen.
  static const List<String> _periodOrder = [
    BudgetPeriodType.month,
    BudgetPeriodType.week,
    BudgetPeriodType.year,
  ];

  final String periodType;

  /// The exceeded budgets, the one over by the most money first.
  final List<BudgetProgress> over;

  /// The other budgets, the most used first.
  final List<BudgetProgress> within;

  /// Null when no budget of the tab has a positive limit.
  final HomeBudgetSummary? total;

  const BudgetOverview._({
    required this.periodType,
    required this.over,
    required this.within,
    required this.total,
  });

  bool get isEmpty => over.isEmpty && within.isEmpty;

  static BudgetOverview of({
    required List<BudgetModel> budgets,
    required Iterable<TransactionModel> transactions,
    required String periodType,
    required DateTime today,
  }) {
    final active = [
      for (final progress in BudgetProgress.activeOn(
        today,
        budgets,
        transactions,
      ))
        if (progress.budget.periodType == periodType) progress,
    ];
    final over = [
      for (final progress in active)
        if (progress.level == BudgetAlertLevel.exceeded) progress,
    ]..sort((a, b) => a.remaining.compareTo(b.remaining));
    final within = [
      for (final progress in active)
        if (progress.level != BudgetAlertLevel.exceeded) progress,
    ]..sort((a, b) => b.percent.compareTo(a.percent));
    return BudgetOverview._(
      periodType: periodType,
      over: over,
      within: within,
      total: HomeBudgetSummary.from(active, today),
    );
  }

  /// The first of month, week and year that has a budget running on [today]; the month when none does.
  static String initialPeriod(List<BudgetModel> budgets, DateTime today) {
    for (final periodType in _periodOrder) {
      if (budgets.any(
        (budget) => budget.periodType == periodType && budget.coversDay(today),
      )) {
        return periodType;
      }
    }
    return BudgetPeriodType.month;
  }
}
