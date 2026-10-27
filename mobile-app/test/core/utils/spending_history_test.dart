import 'package:flutter_test/flutter_test.dart';

import 'package:finance_ai_app/core/utils/spending_history.dart';
import 'package:finance_ai_app/models/transaction_model.dart';

TransactionModel _tx(
  DateTime date, {
  String category = 'Ăn uống',
  bool isExpense = true,
}) => TransactionModel(
  title: 't',
  amount: 1000,
  date: date,
  category: category,
  isExpense: isExpense,
);

void main() {
  test('the window starts on the Monday 25 weeks before this one', () {
    final today = DateTime(2026, 10, 28, 9);
    expect(SpendingHistory.analysisWeeks, 26);
    expect(SpendingHistory.windowStart(today), DateTime(2026, 5, 4));

    final kept = SpendingHistory.forAnalysis([
      _tx(DateTime(2026, 5, 4)),
      _tx(DateTime(2026, 5, 3, 23, 59)),
      _tx(today, category: 'Tiết kiệm'),
      _tx(today, category: 'Lương', isExpense: false),
    ], today);

    expect(kept.map((t) => t.date), [DateTime(2026, 5, 4)]);
  });

  test('a Monday and a Sunday belong to the same week', () {
    expect(
      SpendingHistory.windowStart(DateTime(2026, 10, 26)),
      DateTime(2026, 5, 4),
    );
    expect(
      SpendingHistory.windowStart(DateTime(2026, 11, 1, 23)),
      DateTime(2026, 5, 4),
    );
  });

  test('spending dated after the end of today is not analysed', () {
    final today = DateTime(2026, 10, 28, 9);
    final kept = SpendingHistory.forAnalysis([
      _tx(DateTime(2026, 10, 28, 23, 59)),
      _tx(DateTime(2026, 10, 29)),
      _tx(DateTime(2027, 6, 1)),
    ], today);

    expect(kept.map((t) => t.date), [DateTime(2026, 10, 28, 23, 59)]);
  });

  test('budget advice gets the history from the 1st day 7 months back', () {
    final today = DateTime(2026, 2, 10, 9);
    expect(SpendingHistory.adviceMonths, 7);
    expect(SpendingHistory.adviceWindowStart(today), DateTime(2025, 7, 1));

    final kept = SpendingHistory.forBudgetAdvice([
      _tx(DateTime(2025, 6, 30, 23, 59)),
      _tx(DateTime(2025, 7, 1)),
      _tx(DateTime(2026, 2, 1), category: 'Lương', isExpense: false),
      _tx(DateTime(2026, 2, 2), category: 'Tiết kiệm'),
    ], today);

    expect(kept.map((t) => t.date), [
      DateTime(2025, 7, 1),
      DateTime(2026, 2, 1),
    ]);
  });
}
