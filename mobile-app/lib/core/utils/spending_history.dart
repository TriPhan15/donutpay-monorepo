import 'package:finance_ai_app/models/transaction_model.dart';

/// The parts of the history sent to the AI service: 26 weeks for the analysis, whatever period the report on screen
/// shows, and 7 calendar months for the budget advice.
class SpendingHistory {
  static const int analysisWeeks = 26;

  /// The advisor keeps the last 6 full months; one more month lets it tell a partial first month from a full one.
  static const int adviceMonths = 7;

  /// 00:00 on the Monday of the week of [today], [analysisWeeks] - 1 weeks back.
  static DateTime windowStart(DateTime today) => DateTime(
    today.year,
    today.month,
    today.day - (today.weekday - DateTime.monday) - (analysisWeeks - 1) * 7,
  );

  /// 00:00 of the day after [today]: anything from then on is dated in the future.
  static DateTime _endOfToday(DateTime today) =>
      DateTime(today.year, today.month, today.day + 1);

  /// The spending (no income, no savings contribution, no wallet transfer) from [windowStart] to the end of [today].
  static List<TransactionModel> forAnalysis(
    List<TransactionModel> txs,
    DateTime today,
  ) {
    final start = windowStart(today);
    final end = _endOfToday(today);
    return txs
        .where(
          (t) =>
              t.countsAsSpending &&
              !t.date.isBefore(start) &&
              t.date.isBefore(end),
        )
        .toList();
  }

  /// 00:00 on the 1st day of the month [adviceMonths] months before the month of [today].
  static DateTime adviceWindowStart(DateTime today) =>
      DateTime(today.year, today.month - adviceMonths, 1);

  /// Income and spending, without savings contributions, goal refunds and wallet transfers, from [adviceWindowStart] on.
  static List<TransactionModel> forBudgetAdvice(
    List<TransactionModel> txs,
    DateTime today,
  ) {
    final start = adviceWindowStart(today);
    return txs
        .where(
          (t) =>
              t.isNormal && !t.isSavingsContribution && !t.date.isBefore(start),
        )
        .toList();
  }
}
