import 'package:flutter_test/flutter_test.dart';

import 'package:finance_ai_app/models/savings_goal.dart';

SavingsGoal goal({
  Object id = 1,
  Object? target = 25e6,
  Object? current = 15e6,
  String? deadline,
}) => SavingsGoal.fromJson({
  'id': id,
  'title': 'Mua laptop',
  'target': target,
  'current': current,
  'deadline': deadline,
});

void main() {
  group('SavingsGoal', () {
    test('reads the server map', () {
      final g = goal(id: 7, deadline: '31/03/2027');
      expect(g.id, '7');
      expect(g.title, 'Mua laptop');
      expect(g.target, 25e6);
      expect(g.current, 15e6);
      expect(g.deadline, '31/03/2027');
      expect(g.remaining, 10e6);
      expect(g.isDone, isFalse);
      expect(g.progress, 0.6);
      expect(g.percentLabel, 60);
    });

    test('the percent is floored, so 100 only shows once reached', () {
      expect(goal(target: 1000, current: 599).percentLabel, 59);
      expect(goal(target: 1000, current: 999).percentLabel, 99);
      expect(goal(target: 1000, current: 1000).percentLabel, 100);
    });

    test('a zero or missing target is 0% and never done', () {
      final zero = goal(target: 0, current: 0);
      expect(zero.hasTarget, isFalse);
      expect(goal().hasTarget, isTrue);
      expect(zero.progress, 0);
      expect(zero.percentLabel, 0);
      expect(zero.isDone, isFalse);
      final missing = goal(target: null, current: null);
      expect(missing.target, 0);
      expect(missing.current, 0);
      expect(missing.remaining, 0);
    });

    test('an empty deadline is none', () {
      expect(goal(deadline: '').deadline, isNull);
      expect(goal(deadline: '  ').deadline, isNull);
    });

    test('a goal past its target is done with nothing missing', () {
      final g = goal(target: 10e6, current: 12e6);
      expect(g.isDone, isTrue);
      expect(g.remaining, 0);
      expect(g.progress, 1);
      expect(g.percentLabel, 100);
    });
  });

  group('SavingsOverview', () {
    test('splits open and done goals, keeps the list order, totals all', () {
      final a = goal(id: 1, target: 25e6, current: 15e6);
      final b = goal(id: 2, target: 10e6, current: 10e6);
      final c = goal(id: 3, target: 5e6, current: 3.2e6);
      final o = SavingsOverview.of([a, b, c]);
      expect(o.open.map((g) => g.id), ['1', '3']);
      expect(o.done.map((g) => g.id), ['2']);
      expect(o.totalSaved, 28.2e6);
      expect(o.totalTarget, 40e6);
      expect(o.count, 3);
      expect(o.progress, closeTo(0.705, 1e-9));
    });

    test('no goals: zeros and no division by zero', () {
      final o = SavingsOverview.of(const []);
      expect(o.count, 0);
      expect(o.progress, 0);
      expect(o.isEmpty, isTrue);
    });
  });
}
