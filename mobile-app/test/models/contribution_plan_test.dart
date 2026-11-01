import 'package:flutter_test/flutter_test.dart';

import 'package:finance_ai_app/models/contribution_plan.dart';
import 'package:finance_ai_app/models/savings_goal.dart';

SavingsGoal goal({num target = 25e6, num current = 15e6, String? deadline}) =>
    SavingsGoal.fromJson({
      'id': 1,
      'title': 'Mua laptop',
      'target': target,
      'current': current,
      'deadline': deadline,
    });

void main() {
  final today = DateTime(2026, 10, 29, 21, 30);

  group('ContributionPreview', () {
    test('15 tr + 2 tr of 25 tr goes from 60% to 68%', () {
      final p = ContributionPreview.of(goal(), 2e6);
      expect(p.beforePercent, 60);
      expect(p.afterPercent, 68);
      expect(p.after, 17e6);
      expect(p.savedFraction, closeTo(0.6, 1e-9));
      expect(p.addedFraction, closeTo(0.08, 1e-9));
    });

    test('no amount yet: before and after are the same', () {
      final p = ContributionPreview.of(goal(), 0);
      expect(p.afterPercent, 60);
      expect(p.addedFraction, 0);
    });

    test('a negative amount counts as none', () {
      final p = ContributionPreview.of(goal(), -5e6);
      expect(p.afterPercent, 60);
      expect(p.addedFraction, 0);
      expect(p.after, 15e6);
    });

    test('overfill caps at 100 and the bar never goes past full', () {
      final p = ContributionPreview.of(goal(), 50e6);
      expect(p.afterPercent, 100);
      expect(p.after, 65e6);
      expect(p.savedFraction + p.addedFraction, closeTo(1, 1e-9));
    });

    test('a zero target stays at 0%', () {
      final p = ContributionPreview.of(goal(target: 0, current: 0), 1e6);
      expect(p.beforePercent, 0);
      expect(p.afterPercent, 0);
      expect(p.addedFraction, 0);
    });
  });

  group('ContributionSuggestion', () {
    test('10 tr left over 5 months asks 2 tr, and the 2 tr chip', () {
      // 29/10/2026 + 150 days = 28/03/2027: 150 / 30 = 5 months.
      final s = ContributionSuggestion.of(goal(deadline: '28/03/2027'), today)!;
      expect(s.amount, 2e6);
      expect(s.chip, 2e6);
    });

    test('an uneven month is rounded up to 1.000 and badges the next chip', () {
      // 5 tr over 3 months = 1.666.666,67.
      final s = ContributionSuggestion.of(
        goal(target: 20e6, current: 15e6, deadline: '27/01/2027'),
        today,
      )!;
      expect(s.amount, 1667000);
      expect(s.chip, 2e6);
    });

    test('above the largest chip there is no chip, only the amount', () {
      final s = ContributionSuggestion.of(
        goal(target: 25e6, current: 0, deadline: '27/01/2027'),
        today,
      )!;
      expect(s.amount, closeTo(25e6 / 3, 1000));
      expect(s.chip, isNull);
    });

    test('a deadline today asks the whole rest', () {
      final s = ContributionSuggestion.of(goal(deadline: '29/10/2026'), today)!;
      expect(s.amount, 10e6);
      expect(s.chip, isNull);
    });

    test('a small rest: the amount is the rest, and no chip above it', () {
      final s = ContributionSuggestion.of(
        goal(target: 25e6, current: 24.97e6, deadline: '28/11/2026'),
        today,
      )!;
      expect(s.amount, 30000);
      // 50k would put more in than the goal misses.
      expect(s.chip, isNull);
    });

    test('rounding up to 1.000 never asks more than the goal misses', () {
      // 1.500 left over one month: 2.000 would be an over-contribution.
      final s = ContributionSuggestion.of(
        goal(target: 25e6, current: 25e6 - 1500, deadline: '28/11/2026'),
        today,
      )!;
      expect(s.amount, 1500);
      expect(s.chip, isNull);
    });

    test('a rest that is not a whole thousand is asked as it is', () {
      final s = ContributionSuggestion.of(
        goal(target: 25e6, current: 25e6 - 400, deadline: '29/10/2026'),
        today,
      )!;
      expect(s.amount, 400);
    });

    test('no deadline, overdue or done: no suggestion', () {
      expect(ContributionSuggestion.of(goal(), today), isNull);
      expect(
        ContributionSuggestion.of(goal(deadline: '28/10/2026'), today),
        isNull,
      );
      expect(
        ContributionSuggestion.of(
          goal(current: 25e6, deadline: '28/03/2027'),
          today,
        ),
        isNull,
      );
      expect(
        ContributionSuggestion.of(goal(deadline: 'không rõ'), today),
        isNull,
      );
    });

    test('the quick amounts are the eight of the spec, in order', () {
      expect(ContributionSuggestion.quickAmounts, [
        5e4,
        1e5,
        2e5,
        5e5,
        1e6,
        2e6,
        3e6,
        5e6,
      ]);
    });
  });
}
