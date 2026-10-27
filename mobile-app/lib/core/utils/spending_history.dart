import 'package:finance_ai_app/models/transaction_model.dart';

/// The part of the history the AI service analyses: 26 weeks, whatever period the report on screen shows.
class SpendingHistory {
  static const int analysisWeeks = 26;

  /// 00:00 on the Monday of the week of [today], [analysisWeeks] - 1 weeks back.
  static DateTime windowStart(DateTime today) => DateTime(
    today.year,
    today.month,
    today.day - (today.weekday - DateTime.monday) - (analysisWeeks - 1) * 7,
  );

  /// The spending (no income, no savings contribution) from [windowStart] on.
  static List<TransactionModel> forAnalysis(
    List<TransactionModel> txs,
    DateTime today,
  ) {
    final start = windowStart(today);
    return txs
        .where((t) => t.countsAsSpending && !t.date.isBefore(start))
        .toList();
  }
}
