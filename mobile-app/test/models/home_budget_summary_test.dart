import 'package:flutter_test/flutter_test.dart';

import 'package:finance_ai_app/models/budget_model.dart';
import 'package:finance_ai_app/models/budget_progress.dart';
import 'package:finance_ai_app/models/home_budget_summary.dart';

void main() {
  final today = DateTime(2026, 10, 20);

  BudgetProgress progress(
    String periodType,
    double limit,
    double spent, {
    String? category,
    DateTime? day,
  }) => BudgetProgress(
    budget: BudgetModel.forPeriod(
      categoryName: category,
      amount: limit,
      periodType: periodType,
      day: day ?? today,
    ),
    spent: spent,
  );

  const month = BudgetPeriodType.month;
  const week = BudgetPeriodType.week;
  const year = BudgetPeriodType.year;

  test('the month wins over week and year', () {
    final summary = HomeBudgetSummary.from([
      progress(week, 1000000, 100000),
      progress(year, 90000000, 1000000),
      progress(month, 8000000, 6020000),
    ], today)!;

    expect(summary.periodType, month);
    expect(summary.limit, 8000000);
  });

  test('an all-categories budget is used as is', () {
    final summary = HomeBudgetSummary.from([
      progress(month, 2000000, 1500000, category: 'Ăn uống'),
      progress(month, 8000000, 6020000),
    ], today)!;

    expect(summary.limit, 8000000);
    expect(summary.spent, 6020000);
    expect(summary.remaining, 1980000);
    expect(summary.percentLabel, 75);
    expect(summary.level, BudgetAlertLevel.none);
  });

  test('without one, category budgets of the period are added up', () {
    final summary = HomeBudgetSummary.from([
      progress(month, 3000000, 1000000, category: 'Ăn uống'),
      progress(month, 2000000, 2400000, category: 'Mua sắm'),
      progress(week, 500000, 0, category: 'Di chuyển'),
    ], today)!;

    expect(summary.limit, 5000000);
    expect(summary.spent, 3400000);
  });

  test('only week budgets: the week is used and days run to Sunday', () {
    final wednesday = DateTime(2026, 10, 28);
    final summary = HomeBudgetSummary.from([
      progress(week, 1000000, 200000, day: wednesday),
    ], wednesday)!;

    expect(summary.periodType, week);
    expect(summary.daysLeft, 5);
  });

  test('days left count today and the last day', () {
    expect(
      HomeBudgetSummary.from([progress(month, 1, 0)], today)!.daysLeft,
      12,
    );
    final lastDay = DateTime(2026, 10, 31, 22, 15);
    expect(
      HomeBudgetSummary.from([
        progress(month, 1, 0, day: lastDay),
      ], lastDay)!.daysLeft,
      1,
    );
  });

  test(
    'the most exceeded category is named, else the highest one past 80%',
    () {
      final food = progress(month, 1000000, 850000, category: 'Ăn uống');
      final shopping = progress(month, 1000000, 1400000, category: 'Mua sắm');
      final bills = progress(month, 1000000, 1100000, category: 'Hóa đơn');
      final calm = progress(month, 1000000, 100000, category: 'Di chuyển');

      final over = HomeBudgetSummary.from([
        food,
        bills,
        shopping,
        calm,
      ], today)!;
      expect(over.overCategory, same(shopping));
      expect(over.nearCategory, isNull);

      final near = HomeBudgetSummary.from([food, calm], today)!;
      expect(near.overCategory, isNull);
      expect(near.nearCategory, same(food));

      final quiet = HomeBudgetSummary.from([calm], today)!;
      expect(quiet.overCategory, isNull);
      expect(quiet.nearCategory, isNull);
    },
  );

  test('zero-limit budgets are left out of the band', () {
    expect(HomeBudgetSummary.from([progress(month, 0, 50000)], today), isNull);

    final summary = HomeBudgetSummary.from([
      progress(month, 0, 50000),
      progress(week, 1000000, 200000),
    ], today)!;
    expect(summary.periodType, week);
    expect(summary.limit, 1000000);
  });

  test('an exceeded total has a negative remaining and the exceeded level', () {
    final summary = HomeBudgetSummary.from([
      progress(month, 1000000, 1400000),
    ], today)!;

    expect(summary.remaining, -400000);
    expect(summary.level, BudgetAlertLevel.exceeded);
    expect(summary.percentLabel, 140);
    expect(summary.ringValue, 1);
  });

  test('nothing active gives null', () {
    expect(HomeBudgetSummary.from(const [], today), isNull);
  });
}
