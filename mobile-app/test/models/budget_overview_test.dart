import 'package:flutter_test/flutter_test.dart';

import 'package:finance_ai_app/models/budget_model.dart';
import 'package:finance_ai_app/models/budget_overview.dart';
import 'package:finance_ai_app/models/transaction_model.dart';

final DateTime _today = DateTime(2026, 10, 15);

BudgetModel _budget({
  int? id,
  String? category,
  double amount = 1000,
  String periodType = BudgetPeriodType.month,
  DateTime? day,
}) => BudgetModel.forPeriod(
  id: id,
  categoryId: category == null ? null : id,
  categoryName: category,
  amount: amount,
  periodType: periodType,
  day: day ?? _today,
);

TransactionModel _spent(String category, double amount) => TransactionModel(
  title: category,
  amount: amount,
  date: _today,
  category: category,
  isExpense: true,
);

void main() {
  group('of', () {
    test('keeps only the budgets of the period type that run today', () {
      final overview = BudgetOverview.of(
        budgets: [
          _budget(id: 1, category: 'Ăn uống'),
          _budget(
            id: 2,
            category: 'Ăn uống',
            periodType: BudgetPeriodType.week,
          ),
          _budget(id: 3, category: 'Ăn uống', day: DateTime(2026, 9, 10)),
        ],
        transactions: const [],
        periodType: BudgetPeriodType.month,
        today: _today,
      );

      expect(overview.periodType, BudgetPeriodType.month);
      expect(
        [
          for (final p in [...overview.over, ...overview.within]) p.budget.id,
        ],
        [1],
      );
    });

    test('splits exceeded budgets from the others, each in its own order', () {
      final overview = BudgetOverview.of(
        budgets: [
          _budget(id: 1, category: 'A'),
          _budget(id: 2, category: 'B'),
          _budget(id: 3, category: 'C'),
          _budget(id: 4, category: 'D'),
        ],
        transactions: [
          _spent('A', 1200), // 200 over
          _spent('B', 300), // 30%
          _spent('C', 850), // 85%
          _spent('D', 1500), // 500 over
        ],
        periodType: BudgetPeriodType.month,
        today: _today,
      );

      expect([for (final p in overview.over) p.budget.id], [4, 1]);
      expect([for (final p in overview.within) p.budget.id], [3, 2]);
      expect(overview.isEmpty, isFalse);
    });

    test('the total is the all-categories budget when there is one', () {
      final overview = BudgetOverview.of(
        budgets: [
          _budget(id: 1, category: 'A', amount: 500),
          _budget(id: 2, amount: 8000),
        ],
        transactions: [_spent('A', 600), _spent('B', 1400)],
        periodType: BudgetPeriodType.month,
        today: _today,
      );

      expect(overview.total!.limit, 8000);
      expect(overview.total!.spent, 2000);
    });

    test(
      'without an all-categories budget the total adds the categories up',
      () {
        final overview = BudgetOverview.of(
          budgets: [
            _budget(id: 1, category: 'A', amount: 500),
            _budget(id: 2, category: 'B', amount: 1500),
          ],
          transactions: [_spent('A', 600), _spent('B', 400)],
          periodType: BudgetPeriodType.month,
          today: _today,
        );

        expect(overview.total!.limit, 2000);
        expect(overview.total!.spent, 1000);
      },
    );

    test('a budget without a positive limit is listed but has no total', () {
      final overview = BudgetOverview.of(
        budgets: [_budget(id: 1, category: 'A', amount: 0)],
        transactions: [_spent('A', 600)],
        periodType: BudgetPeriodType.month,
        today: _today,
      );

      expect(overview.over, isEmpty);
      expect([for (final p in overview.within) p.budget.id], [1]);
      expect(overview.within.single.percentLabel, 0);
      expect(overview.total, isNull);
    });

    test('nothing running gives an empty overview', () {
      final overview = BudgetOverview.of(
        budgets: const [],
        transactions: const [],
        periodType: BudgetPeriodType.year,
        today: _today,
      );

      expect(overview.isEmpty, isTrue);
      expect(overview.total, isNull);
    });
  });

  group('initialPeriod', () {
    test('the month comes first', () {
      expect(
        BudgetOverview.initialPeriod([
          _budget(periodType: BudgetPeriodType.week),
          _budget(periodType: BudgetPeriodType.month),
        ], _today),
        BudgetPeriodType.month,
      );
    });

    test('the week when only a week budget runs today', () {
      expect(
        BudgetOverview.initialPeriod([
          _budget(periodType: BudgetPeriodType.week),
          _budget(day: DateTime(2026, 9, 1)),
        ], _today),
        BudgetPeriodType.week,
      );
    });

    test('the month when nothing runs today', () {
      expect(
        BudgetOverview.initialPeriod([
          _budget(day: DateTime(2026, 9, 1)),
        ], _today),
        BudgetPeriodType.month,
      );
    });
  });
}
