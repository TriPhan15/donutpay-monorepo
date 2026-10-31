import 'package:finance_ai_app/core/utils/savings_goal_planner.dart';
import 'package:finance_ai_app/models/transaction_model.dart';

/// What the user can spend today (T9 spec 3.1 and 4.1, AI tab band): the money of the month that is left before today,
/// less what the savings goal asks for, shared out evenly over the days left, today included. Today's own spending is
/// not taken off first, so the allowance stays the same all day while the bar under it fills.
class TodayAllowance {
  const TodayAllowance({
    required this.hasIncome,
    required this.perDay,
    required this.spentToday,
    required this.daysLeft,
  });

  /// False when nothing came in this month up to today: there is then nothing to share out and [perDay] is 0.
  final bool hasIncome;

  /// Today's share; below zero when the month's money is already spent.
  final double perDay;

  /// What was spent today, savings contributions left out.
  final double spentToday;

  /// Days from today to the end of the month, today included.
  final int daysLeft;

  double get remainingToday => perDay - spentToday;

  bool get isOver => perDay < 0;

  /// How much of today's share is spent, from 0 to 1. Anything spent on a share of 0 or less fills the bar.
  double get spentFraction {
    if (perDay <= 0) return isOver || spentToday > 0 ? 1 : 0;
    return (spentToday / perDay).clamp(0.0, 1.0);
  }

  factory TodayAllowance.of({
    required List<TransactionModel> transactions,
    required List<Map<String, dynamic>> savingsGoals,
    required DateTime today,
  }) {
    final day = DateTime(today.year, today.month, today.day);
    final month = transactions
        .where((t) => t.date.year == day.year && t.date.month == day.month)
        .toList();
    // Income dated after today has not come in yet.
    final income = month
        .where((t) => t.countsAsIncome && t.date.day <= day.day)
        .fold(0.0, (s, t) => s + t.amount);
    var spentBefore = 0.0;
    var spentToday = 0.0;
    for (final t in month.where((t) => t.countsAsSpending)) {
      final txDay = DateTime(t.date.year, t.date.month, t.date.day);
      if (txDay.isBefore(day)) {
        spentBefore += t.amount;
      } else if (txDay == day) {
        spentToday += t.amount;
      }
    }
    final daysLeft = DateTime(day.year, day.month + 1, 0).day - day.day + 1;
    if (income <= 0) {
      return TodayAllowance(
        hasIncome: false,
        perDay: 0,
        spentToday: spentToday,
        daysLeft: daysLeft,
      );
    }
    final reserve = goalReserve(transactions, savingsGoals, day);
    return TodayAllowance(
      hasIncome: true,
      perDay: (income - spentBefore - reserve) / daysLeft,
      spentToday: spentToday,
      daysLeft: daysLeft,
    );
  }

  /// The money kept out of this month's spending: what the urgent goal asks for. Without an unfinished goal (none, or
  /// all reached or deleted), what was contributed this month, because that money has already left the wallet.
  static double goalReserve(
    List<TransactionModel> transactions,
    List<Map<String, dynamic>> savingsGoals,
    DateTime today,
  ) {
    final contributed = SavingsGoalPlanner.contributedInMonth(
      transactions,
      today,
    );
    final goal = SavingsGoalPlanner.pickUrgentGoal(savingsGoals, today);
    if (goal == null) return contributed;
    return SavingsGoalPlanner.goalReserve(
      monthlyNeed: SavingsGoalPlanner.monthlyNeed(goal, today),
      contributedThisMonth: contributed,
    );
  }
}
