import 'package:flutter_test/flutter_test.dart';

import 'package:finance_ai_app/core/constants/transaction_categories.dart';
import 'package:finance_ai_app/models/spending_highlights.dart';
import 'package:finance_ai_app/models/transaction_model.dart';

TransactionModel _tx(
  DateTime date,
  double amount, {
  String category = TransactionCategories.food,
  bool isExpense = true,
}) => TransactionModel(
  title: category,
  amount: amount,
  date: date,
  category: category,
  isExpense: isExpense,
);

TransactionModel _income(DateTime date, double amount) =>
    _tx(date, amount, category: 'Lương', isExpense: false);

TransactionModel _saving(DateTime date, double amount) =>
    _tx(date, amount, category: TransactionCategories.savings);

/// Wednesday 21 October 2026: this week runs Monday 19 to today.
final DateTime _today = DateTime(2026, 10, 21, 18);

SpendingHighlights _of(
  List<TransactionModel> txs, {
  List<Map<String, dynamic>> goals = const [],
  DateTime? today,
}) => SpendingHighlights.of(
  transactions: txs,
  savingsGoals: goals,
  today: today ?? _today,
);

void main() {
  group('trend against last month', () {
    test('spending down is good, with the change in percent', () {
      final h = _of([
        _tx(DateTime(2026, 9, 10), 1000),
        _tx(DateTime(2026, 10, 3), 880),
      ]);

      expect(h.trend.thisMonth, 880);
      expect(h.trend.lastMonth, 1000);
      expect(h.trend.percent, closeTo(-12, 1e-9));
      expect(h.trend.tone, HighlightTone.good);
    });

    test('spending up needs attention', () {
      final h = _of([
        _tx(DateTime(2026, 9, 10), 1000),
        _tx(DateTime(2026, 10, 3), 1410),
      ]);

      expect(h.trend.percent, closeTo(41, 1e-9));
      expect(h.trend.tone, HighlightTone.attention);
    });

    test('without spending last month there is no percent', () {
      final h = _of([_tx(DateTime(2026, 10, 3), 500)]);

      expect(h.trend.percent, isNull);
      expect(h.trend.tone, HighlightTone.neutral);
    });

    test('January compares with December of the year before', () {
      final h = _of([
        _tx(DateTime(2025, 12, 3), 200),
        _tx(DateTime(2026, 1, 2), 100),
      ], today: DateTime(2026, 1, 5));

      expect(h.trend.lastMonth, 200);
      expect(h.trend.percent, closeTo(-50, 1e-9));
    });

    test('compares with the same days of last month, not the whole month', () {
      final h = _of([
        _tx(DateTime(2026, 9, 21, 23), 300),
        // After the 21st of last month: not yet comparable on the 21st.
        _tx(DateTime(2026, 9, 22), 5000),
        _tx(DateTime(2026, 10, 3), 600),
        // Dated later this month: not spent yet.
        _tx(DateTime(2026, 10, 25), 9000),
      ]);

      expect(h.trend.lastMonth, 300);
      expect(h.trend.thisMonth, 600);
      expect(h.trend.percent, closeTo(100, 1e-9));
    });

    test('the 31st compares with the whole of a 30-day month', () {
      final h = _of([
        _tx(DateTime(2026, 9, 30), 400),
        _tx(DateTime(2026, 10, 31), 200),
      ], today: DateTime(2026, 10, 31));

      expect(h.trend.lastMonth, 400);
    });

    test('contributions and income are not spending', () {
      final h = _of([
        _saving(DateTime(2026, 9, 10), 1000),
        _income(DateTime(2026, 10, 1), 1000),
        _tx(DateTime(2026, 10, 3), 100),
      ]);

      expect(h.trend.lastMonth, 0);
      expect(h.trend.thisMonth, 100);
    });
  });

  group('top category of the month', () {
    test('names the largest one with its share', () {
      final h = _of([
        _tx(DateTime(2026, 10, 3), 300),
        _tx(DateTime(2026, 10, 4), 300),
        _tx(DateTime(2026, 10, 5), 400, category: 'Mua sắm'),
        _tx(DateTime(2026, 9, 5), 9000, category: 'Mua sắm'),
      ]);

      expect(h.topCategory!.category, TransactionCategories.food);
      expect(h.topCategory!.amount, 600);
      expect(h.topCategory!.share, closeTo(60, 1e-9));
      expect(h.topCategory!.tone, HighlightTone.attention);
    });

    test('below half of the spending it is neutral', () {
      final h = _of([
        _tx(DateTime(2026, 10, 3), 400),
        _tx(DateTime(2026, 10, 4), 350, category: 'Mua sắm'),
        _tx(DateTime(2026, 10, 5), 250, category: 'Di chuyển'),
      ]);

      expect(h.topCategory!.share, closeTo(40, 1e-9));
      expect(h.topCategory!.tone, HighlightTone.neutral);
    });

    test('none without spending this month', () {
      expect(_of([_saving(DateTime(2026, 10, 3), 400)]).topCategory, isNull);
    });
  });

  group('saving tip', () {
    test('without a goal, what is left is a surplus', () {
      final h = _of([
        _income(DateTime(2026, 10, 1), 1000),
        _tx(DateTime(2026, 10, 3), 300),
        _saving(DateTime(2026, 10, 4), 200),
      ]);

      expect(h.tip.kind, SavingTipKind.surplus);
      expect(h.tip.amount, 500);
      expect(h.tip.tone, HighlightTone.good);
    });

    test('without a goal and nothing left, add a goal', () {
      final h = _of([
        _income(DateTime(2026, 10, 1), 100),
        _tx(DateTime(2026, 10, 3), 300),
      ]);

      expect(h.tip.kind, SavingTipKind.addGoal);
      expect(h.tip.tone, isNull);
    });

    test('a goal the month covers is on track', () {
      final h = _of(
        [_income(DateTime(2026, 10, 1), 1000)],
        goals: const [
          {'target': 300, 'current': 0, 'deadline': '20/11/2026'},
        ],
      );

      expect(h.tip.kind, SavingTipKind.onTrack);
      expect(h.tip.tone, HighlightTone.good);
    });

    test(
      'a goal the month does not cover needs more, minus what was put in',
      () {
        final h = _of(
          [
            _income(DateTime(2026, 10, 1), 1000),
            _tx(DateTime(2026, 10, 3), 900),
            _saving(DateTime(2026, 10, 4), 100),
          ],
          goals: const [
            {'target': 300, 'current': 0, 'deadline': '20/11/2026'},
          ],
        );

        expect(h.tip.kind, SavingTipKind.needMore);
        expect(h.tip.amount, 200);
        expect(h.tip.tone, HighlightTone.attention);
      },
    );

    test(
      'a goal already covered by contributions while the month is overspent says so, with no amount',
      () {
        final h = _of(
          [
            _income(DateTime(2026, 10, 1), 1000),
            _tx(DateTime(2026, 10, 3), 900),
            _saving(DateTime(2026, 10, 4), 300),
          ],
          goals: const [
            {'target': 300, 'current': 0, 'deadline': '20/11/2026'},
          ],
        );

        expect(h.tip.kind, SavingTipKind.overspent);
        expect(h.tip.amount, 0);
        expect(h.tip.tone, isNull);
      },
    );

    test('a goal without deadline or past it has no amount', () {
      expect(
        _of(
          const [],
          goals: const [
            {'target': 300, 'current': 0, 'deadline': ''},
          ],
        ).tip.kind,
        SavingTipKind.noDeadline,
      );
      expect(
        _of(
          const [],
          goals: const [
            {'target': 300, 'current': 0, 'deadline': '01/10/2026'},
          ],
        ).tip.kind,
        SavingTipKind.overdue,
      );
    });
  });

  group('week against the same days of last week', () {
    test('counts Monday to today against Monday to the same weekday', () {
      final h = _of([
        _tx(DateTime(2026, 10, 19), 100),
        _tx(DateTime(2026, 10, 21, 23), 50),
        _tx(DateTime(2026, 10, 12), 300),
        _tx(DateTime(2026, 10, 14), 10),
        // Thursday of last week is past the same weekday.
        _tx(DateTime(2026, 10, 15), 999),
      ]);

      expect(h.week.thisWeek, 150);
      expect(h.week.lastWeek, 310);
      expect(h.week.difference, -160);
      expect(h.week.tone, HighlightTone.good);
    });

    test('more than last week needs attention; equal is good', () {
      expect(
        _of([_tx(DateTime(2026, 10, 20), 100)]).week.tone,
        HighlightTone.attention,
      );
      expect(
        _of([
          _tx(DateTime(2026, 10, 20), 100),
          _tx(DateTime(2026, 10, 13), 100),
        ]).week.tone,
        HighlightTone.good,
      );
    });

    test('a week that starts in the month before still counts', () {
      final h = _of([
        _tx(DateTime(2026, 9, 28), 100),
      ], today: DateTime(2026, 10, 1));

      expect(h.week.thisWeek, 100);
    });
  });

  group('top week of the month', () {
    test('week four takes the days from the 22nd to the end', () {
      final h = _of([
        _tx(DateTime(2026, 10, 3), 100),
        _tx(DateTime(2026, 10, 22), 80),
        _tx(DateTime(2026, 10, 31), 80),
      ], today: DateTime(2026, 10, 31));

      expect(h.topWeek!.week, 4);
      expect(h.topWeek!.amount, 160);
    });

    test('the first largest week wins a tie', () {
      final h = _of([
        _tx(DateTime(2026, 10, 8), 100),
        _tx(DateTime(2026, 10, 15), 100),
      ]);

      expect(h.topWeek!.week, 2);
    });

    test('none without spending this month', () {
      expect(_of([_income(DateTime(2026, 10, 1), 100)]).topWeek, isNull);
    });
  });
}
