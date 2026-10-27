import 'package:flutter_test/flutter_test.dart';

import 'package:finance_ai_app/core/utils/savings_goal_planner.dart';
import 'package:finance_ai_app/models/transaction_model.dart';

Map<String, dynamic> goal({
  int id = 1,
  String? deadline,
  num target = 3e6,
  num current = 0,
}) => {'id': id, 'target': target, 'current': current, 'deadline': deadline};

TransactionModel tx(
  double amount,
  DateTime date, {
  String category = 'Tiết kiệm',
  bool isExpense = true,
}) => TransactionModel(
  title: 't',
  amount: amount,
  date: date,
  category: category,
  isExpense: isExpense,
);

void main() {
  final today = DateTime(2026, 10, 27, 23, 59);

  test('deadline today counts as one day even at 23:59', () {
    expect(SavingsGoalPlanner.daysLeft('27/10/2026', today), 0);
    expect(SavingsGoalPlanner.monthsLeft(goal(deadline: '27/10/2026'), today), 1);
    expect(
      SavingsGoalPlanner.daysLeft('28/10/2026', DateTime(2026, 10, 27, 0, 1)),
      1,
    );
  });

  test('daysLeft is null for an empty, malformed or impossible date', () {
    expect(SavingsGoalPlanner.daysLeft(null, today), isNull);
    expect(SavingsGoalPlanner.daysLeft('', today), isNull);
    expect(SavingsGoalPlanner.daysLeft('2026-11-01', today), isNull);
    expect(SavingsGoalPlanner.daysLeft('31/02/2026', today), isNull);
  });

  test('months are the days over 30, rounded up', () {
    expect(SavingsGoalPlanner.monthsLeft(goal(deadline: '26/11/2026'), today), 1);
    expect(SavingsGoalPlanner.monthsLeft(goal(deadline: '27/11/2026'), today), 2);
    expect(
      SavingsGoalPlanner.monthlyNeed(
        goal(deadline: '27/11/2026', target: 3e6, current: 1e6),
        today,
      ),
      1e6,
    );
  });

  test('an overdue goal has no monthly need', () {
    expect(SavingsGoalPlanner.monthsLeft(goal(deadline: '26/10/2026'), today), isNull);
    expect(
      SavingsGoalPlanner.monthlyNeed(goal(deadline: '26/10/2026', target: 3e6), today),
      0,
    );
  });

  test('a goal without deadline has no monthly need', () {
    expect(
      SavingsGoalPlanner.monthlyNeed(goal(deadline: null, target: 300e6), today),
      0,
    );
  });

  test('the urgent goal is the nearest future deadline, not an overdue one', () {
    final a = goal(id: 1, deadline: '26/11/2026');
    final b = goal(id: 2, deadline: '01/10/2026');
    final c = goal(id: 3, deadline: '30/11/2026');
    expect(SavingsGoalPlanner.pickUrgentGoal([b, a], today), same(a));
    expect(SavingsGoalPlanner.pickUrgentGoal([c, a], today), same(a));
  });

  test('a tie on the deadline keeps the first goal of the list', () {
    final a = goal(id: 1, deadline: '26/11/2026');
    final b = goal(id: 2, deadline: '26/11/2026');
    expect(SavingsGoalPlanner.pickUrgentGoal([a, b], today), same(a));
  });

  test('finished goals are never picked', () {
    final done = goal(id: 1, deadline: '28/10/2026', target: 1e6, current: 1e6);
    final open = goal(id: 2, deadline: '26/11/2026');
    expect(SavingsGoalPlanner.pickUrgentGoal([done, open], today), same(open));
    expect(SavingsGoalPlanner.pickUrgentGoal([done], today), isNull);
    expect(SavingsGoalPlanner.pickUrgentGoal([], today), isNull);
  });

  test('overdue or open-ended goals are picked only when nothing else is left', () {
    final b = goal(id: 2, deadline: '01/10/2026');
    final open = goal(id: 3, deadline: null);
    expect(SavingsGoalPlanner.pickUrgentGoal([b], today), same(b));
    expect(SavingsGoalPlanner.pickUrgentGoal([open, b], today), same(open));
  });

  test('contributions of this month only', () {
    final txs = [
      tx(400e3, DateTime(2026, 10, 3)),
      tx(100e3, DateTime(2026, 10, 20)),
      tx(900e3, DateTime(2026, 9, 30)),
      tx(50e3, DateTime(2026, 10, 5), category: 'Ăn uống'),
      tx(70e3, DateTime(2026, 10, 6), category: 'Tiết kiệm', isExpense: false),
    ];
    expect(SavingsGoalPlanner.contributedInMonth(txs, today), 500e3);
  });

  test('contributions already made this month are not subtracted twice', () {
    expect(
      SavingsGoalPlanner.goalReserve(monthlyNeed: 1e6, contributedThisMonth: 400e3),
      1e6,
    );
    expect(
      SavingsGoalPlanner.goalReserve(monthlyNeed: 1e6, contributedThisMonth: 1.5e6),
      1.5e6,
    );
  });

  test('only a real deadline already past is overdue', () {
    expect(SavingsGoalPlanner.isOverdue(goal(deadline: '26/10/2026'), today), isTrue);
    expect(SavingsGoalPlanner.isOverdue(goal(deadline: '27/10/2026'), today), isFalse);
    expect(SavingsGoalPlanner.isOverdue(goal(deadline: '30/11/2026'), today), isFalse);
    expect(SavingsGoalPlanner.isOverdue(goal(), today), isFalse);
    expect(SavingsGoalPlanner.isOverdue(goal(deadline: '31/02/2026'), today), isFalse);
  });
}
