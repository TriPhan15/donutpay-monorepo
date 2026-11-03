import 'package:flutter_test/flutter_test.dart';

import 'package:finance_ai_app/core/utils/spending_history.dart';
import 'package:finance_ai_app/models/transaction_model.dart';
import 'package:finance_ai_app/models/transaction_source.dart';

TransactionModel _tx(
  DateTime date, {
  String category = 'Ăn uống',
  bool isExpense = true,
  TransactionSource source = TransactionSource.normal,
}) => TransactionModel(
  title: 't',
  amount: 1000,
  date: date,
  category: category,
  isExpense: isExpense,
  source: source,
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

  test(
    'what is sent to the AI service leaves out every transaction that is not NORMAL',
    () {
      final today = DateTime(2026, 10, 28, 9);
      final txs = [
        _tx(DateTime(2026, 10, 20)),
        _tx(DateTime(2026, 10, 21), category: 'Lương', isExpense: false),
        _tx(
          DateTime(2026, 10, 22),
          category: 'Tiết kiệm',
          isExpense: false,
          source: TransactionSource.goalRefund,
        ),
        _tx(
          DateTime(2026, 10, 23),
          category: 'Rút ví điện tử',
          source: TransactionSource.walletTransfer,
        ),
        _tx(
          DateTime(2026, 10, 24),
          category: 'Nạp ví điện tử',
          isExpense: false,
          source: TransactionSource.walletTransfer,
        ),
      ];

      expect(SpendingHistory.forAnalysis(txs, today).map((t) => t.date), [
        DateTime(2026, 10, 20),
      ]);
      expect(SpendingHistory.forBudgetAdvice(txs, today).map((t) => t.date), [
        DateTime(2026, 10, 20),
        DateTime(2026, 10, 21),
      ]);
    },
  );
}
