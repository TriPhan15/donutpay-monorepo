import 'package:flutter_test/flutter_test.dart';

import 'package:finance_ai_app/core/constants/transaction_categories.dart';
import 'package:finance_ai_app/models/today_allowance.dart';
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

void main() {
  // 20 October 2026: 12 days left in the month, today included.
  final today = DateTime(2026, 10, 20, 15, 30);

  group('TodayAllowance.of', () {
    test('without income this month there is nothing to share out', () {
      final a = TodayAllowance.of(
        transactions: [
          _income(DateTime(2026, 9, 30), 9000000),
          _tx(DateTime(2026, 10, 20), 50000),
        ],
        savingsGoals: const [],
        today: today,
      );

      expect(a.hasIncome, isFalse);
      expect(a.spentToday, 50000);
    });

    test(
      'shares what is left before today over the days left, today included',
      () {
        final a = TodayAllowance.of(
          transactions: [
            _income(DateTime(2026, 10, 1), 1300000),
            _tx(DateTime(2026, 10, 5), 100000),
            // Today's spending does not shrink today's allowance.
            _tx(DateTime(2026, 10, 20, 9), 30000),
            _tx(DateTime(2026, 10, 20, 12), 20000),
            // Last month does not count.
            _tx(DateTime(2026, 9, 20), 999000),
          ],
          savingsGoals: const [],
          today: today,
        );

        expect(a.hasIncome, isTrue);
        expect(a.daysLeft, 12);
        expect(a.perDay, 100000);
        expect(a.spentToday, 50000);
        expect(a.remainingToday, 50000);
        expect(a.spentFraction, 0.5);
        expect(a.isOver, isFalse);
      },
    );

    test('a contribution is not spending but is kept out of the allowance', () {
      final a = TodayAllowance.of(
        transactions: [
          _income(DateTime(2026, 10, 1), 1300000),
          _tx(
            DateTime(2026, 10, 20, 8),
            100000,
            category: TransactionCategories.savings,
          ),
        ],
        savingsGoals: const [],
        today: today,
      );

      // No unfinished goal: what was contributed this month is held back.
      expect(a.perDay, 100000);
      expect(a.spentToday, 0);
    });

    test('the urgent goal asks for its monthly need', () {
      final a = TodayAllowance.of(
        transactions: [_income(DateTime(2026, 10, 1), 1500000)],
        savingsGoals: const [
          {'target': 300000, 'current': 0, 'deadline': '19/11/2026'},
        ],
        today: today,
      );

      expect(a.perDay, 100000);
    });

    test('income dated after today does not count yet', () {
      final a = TodayAllowance.of(
        transactions: [
          _income(DateTime(2026, 10, 1), 1200000),
          _income(DateTime(2026, 10, 25), 9000000),
        ],
        savingsGoals: const [],
        today: today,
      );

      expect(a.perDay, 100000);
    });

    test('income dated only after today is no income yet', () {
      final a = TodayAllowance.of(
        transactions: [_income(DateTime(2026, 10, 25), 9000000)],
        savingsGoals: const [],
        today: today,
      );

      expect(a.hasIncome, isFalse);
    });

    test('the last day of the month has one day left', () {
      final a = TodayAllowance.of(
        transactions: [_income(DateTime(2026, 10, 1), 500000)],
        savingsGoals: const [],
        today: DateTime(2026, 10, 31),
      );

      expect(a.daysLeft, 1);
      expect(a.perDay, 500000);
    });

    test('the first day of February shares over 28 days', () {
      final a = TodayAllowance.of(
        transactions: [_income(DateTime(2026, 2, 1), 2800000)],
        savingsGoals: const [],
        today: DateTime(2026, 2, 1),
      );

      expect(a.daysLeft, 28);
      expect(a.perDay, 100000);
    });

    test('spending past the month\'s money is over, and today is all over', () {
      final a = TodayAllowance.of(
        transactions: [
          _income(DateTime(2026, 10, 1), 100000),
          _tx(DateTime(2026, 10, 2), 220000),
          _tx(DateTime(2026, 10, 20), 10000),
        ],
        savingsGoals: const [],
        today: today,
      );

      expect(a.isOver, isTrue);
      expect(a.perDay, -10000);
      expect(a.spentFraction, 1);
    });

    test('spending more than today\'s share leaves a negative rest', () {
      final a = TodayAllowance.of(
        transactions: [
          _income(DateTime(2026, 10, 1), 1200000),
          _tx(DateTime(2026, 10, 20), 150000),
        ],
        savingsGoals: const [],
        today: today,
      );

      expect(a.remainingToday, -50000);
      expect(a.spentFraction, 1);
    });
  });
}
