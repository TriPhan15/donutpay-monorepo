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
}
