import 'dart:math' as math;

import 'package:finance_ai_app/models/transaction_model.dart';

/// Plans savings goals for the AI tab. Pure: "today" comes from the caller, so nothing here reads the clock.
class SavingsGoalPlanner {
  SavingsGoalPlanner._();

  /// A month is counted as 30 days when a deadline is turned into months.
  static const int daysPerMonth = 30;

  /// Whole days from [today] to a `dd/MM/yyyy` [deadline], comparing dates only (the time of day never counts).
  /// Today is 0, overdue is negative. Null when the deadline is empty or not a real date in that format.
  static int? daysLeft(Object? deadline, DateTime today) {
    final parts = (deadline ?? '').toString().trim().split('/');
    if (parts.length != 3) return null;
    final d = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final y = int.tryParse(parts[2]);
    if (d == null || m == null || y == null) return null;
    final date = DateTime(y, m, d);
    if (date.year != y || date.month != m || date.day != d) return null;
    // Calendar days between the two dates; UTC keeps a daylight-saving change from skewing the count.
    return DateTime.utc(y, m, d)
        .difference(DateTime.utc(today.year, today.month, today.day))
        .inDays;
  }

  /// Months left to the goal's deadline, at least 1. Null when it has no deadline or is overdue.
  static int? monthsLeft(Map<String, dynamic> goal, DateTime today) {
    final days = daysLeft(goal['deadline'], today);
    if (days == null || days < 0) return null;
    return (math.max(days, 1) / daysPerMonth).ceil();
  }

  static double _remaining(Map<String, dynamic> goal) =>
      ((goal['target'] ?? 0) as num).toDouble() -
      ((goal['current'] ?? 0) as num).toDouble();

  /// The goal to plan for: among unfinished goals, the nearest deadline that is not past (ties keep list order). When
  /// none has one, the first unfinished goal (open-ended or overdue). Null when every goal is done.
  static Map<String, dynamic>? pickUrgentGoal(
    List<Map<String, dynamic>> goals,
    DateTime today,
  ) {
    final open = goals.where((g) => _remaining(g) > 0).toList();
    if (open.isEmpty) return null;
    Map<String, dynamic>? best;
    int? bestDays;
    for (final g in open) {
      final days = daysLeft(g['deadline'], today);
      if (days == null || days < 0) continue;
      if (bestDays == null || days < bestDays) {
        best = g;
        bestDays = days;
      }
    }
    return best ?? open.first;
  }

  /// What the goal asks per month: the rest divided by [monthsLeft]. 0 when there is no usable deadline.
  static double monthlyNeed(Map<String, dynamic> goal, DateTime today) {
    final months = monthsLeft(goal, today);
    if (months == null) return 0;
    return math.max(0, _remaining(goal) / months);
  }

  /// Savings contributions made in the month of [today].
  static double contributedInMonth(
    Iterable<TransactionModel> txs,
    DateTime today,
  ) => txs
      .where(
        (t) =>
            t.isSavingsContribution &&
            t.date.year == today.year &&
            t.date.month == today.month,
      )
      .fold(0.0, (s, t) => s + t.amount);

  /// The money to keep aside this month for the goal. What was already contributed is not taken off the wallet twice:
  /// the larger of the monthly need and what has been put in so far.
  static double goalReserve({
    required double monthlyNeed,
    required double contributedThisMonth,
  }) => math.max(monthlyNeed, contributedThisMonth);
}
