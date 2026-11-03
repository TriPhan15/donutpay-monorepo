import 'dart:math' as math;

import 'package:finance_ai_app/core/utils/savings_goal_planner.dart';
import 'package:finance_ai_app/models/transaction_model.dart';

/// The colour of a value pill in the highlights: green for good news, red for what needs attention (T9 spec 3.1).
enum HighlightTone { good, attention, neutral }

/// This month's spending so far against the same days of last month (the 1st up to today's day, or the end of a
/// shorter month), so that the start of a month is not compared with a whole one.
class MonthTrend {
  const MonthTrend({required this.thisMonth, required this.lastMonth});

  final double thisMonth;
  final double lastMonth;

  /// The change in percent; null when nothing was spent last month.
  double? get percent =>
      lastMonth == 0 ? null : (thisMonth - lastMonth) / lastMonth * 100;

  HighlightTone get tone => switch (percent) {
    null => HighlightTone.neutral,
    final p when p > 0 => HighlightTone.attention,
    _ => HighlightTone.good,
  };
}

/// The category the most was spent on this month.
class TopCategory {
  /// From this share of the month's spending one category needs attention.
  static const double attentionShare = 50;

  const TopCategory({
    required this.category,
    required this.amount,
    required this.share,
  });

  final String category;
  final double amount;

  /// Percent of the month's spending.
  final double share;

  HighlightTone get tone =>
      share >= attentionShare ? HighlightTone.attention : HighlightTone.neutral;
}

/// [overspent]: this month's contributions already cover the goal, but the month has spent more than came in.
enum SavingTipKind {
  surplus,
  addGoal,
  onTrack,
  needMore,
  overspent,
  noDeadline,
  overdue,
}

/// The savings tip of the old AI tab, with the amount its pill shows.
class SavingTip {
  const SavingTip(this.kind, [this.amount = 0]);

  final SavingTipKind kind;

  /// The surplus, or what is still to put into the goal this month; 0 for the other kinds.
  final double amount;

  /// Null when the tip has no value pill.
  HighlightTone? get tone => switch (kind) {
    SavingTipKind.surplus || SavingTipKind.onTrack => HighlightTone.good,
    SavingTipKind.needMore => HighlightTone.attention,
    _ => null,
  };
}

/// This week from Monday to today against the same days of last week, so that a week just begun is not compared with a
/// whole one.
class WeekCompare {
  const WeekCompare({required this.thisWeek, required this.lastWeek});

  final double thisWeek;
  final double lastWeek;

  double get difference => thisWeek - lastWeek;

  HighlightTone get tone =>
      difference > 0 ? HighlightTone.attention : HighlightTone.good;
}

/// The week of the month (days 1-7, 8-14, 15-21, 22 to the end) the most was spent in.
class TopWeek {
  const TopWeek({required this.week, required this.amount});

  /// 1 to 4.
  final int week;
  final double amount;
}

/// The five rows of "Điểm nổi bật" (T9 spec 3.1, worked out on the phone as 4.1 asks). Pure: today comes from the
/// caller. Savings contributions are never spending.
class SpendingHighlights {
  static const int weeksInMonth = 4;

  const SpendingHighlights({
    required this.trend,
    required this.topCategory,
    required this.tip,
    required this.week,
    required this.topWeek,
  });

  final MonthTrend trend;
  final TopCategory? topCategory;
  final SavingTip tip;
  final WeekCompare week;
  final TopWeek? topWeek;

  factory SpendingHighlights.of({
    required List<TransactionModel> transactions,
    required List<Map<String, dynamic>> savingsGoals,
    required DateTime today,
  }) {
    final day = DateTime(today.year, today.month, today.day);
    final spending = transactions.where((t) => t.countsAsSpending).toList();
    bool inMonth(TransactionModel t, DateTime month) =>
        t.date.year == month.year && t.date.month == month.month;
    final lastMonth = DateTime(day.year, day.month - 1);
    final thisMonthTxs = spending.where((t) => inMonth(t, day)).toList();
    final thisMonth = _sum(thisMonthTxs);
    final lastMonthLength = DateTime(day.year, day.month, 0).day;
    final comparableDay = math.min(day.day, lastMonthLength);

    final income = transactions
        .where((t) => t.countsAsIncome && inMonth(t, day))
        .fold(0.0, (s, t) => s + t.amount);

    return SpendingHighlights(
      trend: MonthTrend(
        thisMonth: _sum(thisMonthTxs.where((t) => t.date.day <= day.day)),
        lastMonth: _sum(
          spending.where(
            (t) => inMonth(t, lastMonth) && t.date.day <= comparableDay,
          ),
        ),
      ),
      topCategory: _topCategory(thisMonthTxs, thisMonth),
      tip: _tip(transactions, savingsGoals, day, income, thisMonth),
      week: _week(spending, day),
      topWeek: _topWeek(thisMonthTxs),
    );
  }

  static double _sum(Iterable<TransactionModel> txs) =>
      txs.fold(0.0, (s, t) => s + t.amount);

  static DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

  static TopCategory? _topCategory(List<TransactionModel> txs, double total) {
    if (total <= 0) return null;
    final totals = <String, double>{};
    for (final t in txs) {
      final name = t.category.trim();
      totals[name] = (totals[name] ?? 0) + t.amount;
    }
    // reduce keeps the first of two equal totals.
    final top = totals.entries.reduce((a, b) => b.value > a.value ? b : a);
    return TopCategory(
      category: top.key,
      amount: top.value,
      share: top.value / total * 100,
    );
  }

  static SavingTip _tip(
    List<TransactionModel> transactions,
    List<Map<String, dynamic>> goals,
    DateTime today,
    double income,
    double spent,
  ) {
    final contributed = SavingsGoalPlanner.contributedInMonth(
      transactions,
      today,
    );
    final goal = SavingsGoalPlanner.pickUrgentGoal(goals, today);
    if (goal == null) {
      // This month's contributions have left the wallet, so they are not part of the surplus.
      final surplus = income - spent - contributed;
      return surplus > 0
          ? SavingTip(SavingTipKind.surplus, surplus)
          : const SavingTip(SavingTipKind.addGoal);
    }
    final need = SavingsGoalPlanner.monthlyNeed(goal, today);
    if (need == 0) {
      return SavingTip(
        SavingsGoalPlanner.isOverdue(goal, today)
            ? SavingTipKind.overdue
            : SavingTipKind.noDeadline,
      );
    }
    final reserve = SavingsGoalPlanner.goalReserve(
      monthlyNeed: need,
      contributedThisMonth: contributed,
    );
    if (income - spent - reserve >= 0) {
      return const SavingTip(SavingTipKind.onTrack);
    }
    final missing = need - contributed;
    // Nothing more to put in: what is short is the month itself, not the goal.
    if (missing <= 0) return const SavingTip(SavingTipKind.overspent);
    return SavingTip(SavingTipKind.needMore, missing);
  }

  static WeekCompare _week(List<TransactionModel> spending, DateTime today) {
    final monday = DateTime(
      today.year,
      today.month,
      today.day - (today.weekday - DateTime.monday),
    );
    double between(DateTime from, DateTime to) => _sum(
      spending.where((t) {
        final d = _dayOf(t.date);
        return !d.isBefore(from) && !d.isAfter(to);
      }),
    );
    DateTime weekBefore(DateTime d) => DateTime(d.year, d.month, d.day - 7);
    return WeekCompare(
      thisWeek: between(monday, today),
      lastWeek: between(weekBefore(monday), weekBefore(today)),
    );
  }

  static TopWeek? _topWeek(List<TransactionModel> monthTxs) {
    final weeks = List.filled(weeksInMonth, 0.0);
    for (final t in monthTxs) {
      weeks[math.min((t.date.day - 1) ~/ DateTime.daysPerWeek, 3)] += t.amount;
    }
    var top = 0;
    for (var i = 1; i < weeksInMonth; i++) {
      if (weeks[i] > weeks[top]) top = i;
    }
    if (weeks[top] <= 0) return null;
    return TopWeek(week: top + 1, amount: weeks[top]);
  }
}
