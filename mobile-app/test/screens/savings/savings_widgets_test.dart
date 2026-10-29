import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/app_theme.dart';
import 'package:finance_ai_app/core/theme/category_colors.dart';
import 'package:finance_ai_app/l10n/app_localizations.dart';
import 'package:finance_ai_app/models/savings_goal.dart';
import 'package:finance_ai_app/screens/savings/widgets/goal_visual.dart';
import 'package:finance_ai_app/screens/savings/widgets/savings_goal_list.dart';
import 'package:finance_ai_app/screens/savings/widgets/savings_summary_card.dart';

SavingsGoal _goal({
  Object id = 1,
  String title = 'Mua laptop',
  num target = 25e6,
  num current = 15e6,
  String? deadline,
}) => SavingsGoal.fromJson({
  'id': id,
  'title': title,
  'target': target,
  'current': current,
  'deadline': deadline,
});

final DateTime _today = DateTime(2026, 10, 29);

Future<ThemeData> _pump(
  WidgetTester tester,
  Widget child, {
  ThemeMode mode = ThemeMode.light,
  double width = 400,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  late ThemeData theme;
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: mode,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('vi'),
      home: Scaffold(
        body: Builder(
          builder: (context) {
            theme = Theme.of(context);
            return SingleChildScrollView(child: child);
          },
        ),
      ),
    ),
  );
  return theme;
}

Color? _textColor(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style?.color;

void main() {
  group('GoalVisual', () {
    final scheme = ColorScheme.fromSeed(seedColor: AppTheme.primary);

    test('guesses the icon and colour from the title', () {
      expect(
        GoalVisual.of('Mua laptop', scheme).icon,
        Icons.laptop_mac_rounded,
      );
      expect(GoalVisual.of('Mua laptop', scheme).color, CategoryColors.bills);
      expect(
        GoalVisual.of('Du lịch Đà Lạt', scheme).icon,
        Icons.flight_rounded,
      );
      expect(GoalVisual.of('QUỸ KHẨN CẤP', scheme).icon, Icons.shield_rounded);
      expect(
        GoalVisual.of('Mua xe máy', scheme).icon,
        Icons.two_wheeler_rounded,
      );
      expect(
        GoalVisual.of('Đổi ô tô', scheme).icon,
        Icons.directions_car_rounded,
      );
    });

    test('a word inside another word does not count', () {
      // "xem" holds "xe", but is not about a vehicle.
      expect(GoalVisual.of('Đi xem phim', scheme).icon, Icons.savings_rounded);
    });

    test('anything else: the piggy bank in the primary colour', () {
      final v = GoalVisual.of('Tiền cho mẹ', scheme);
      expect(v.icon, Icons.savings_rounded);
      expect(v.color, scheme.primary);
    });
  });

  group('SavingsSummaryCard', () {
    testWidgets('total saved, bar 8, target and count of all goals', (
      tester,
    ) async {
      final overview = SavingsOverview.of([
        _goal(id: 1),
        _goal(id: 2, title: 'Du lịch', target: 5e6, current: 3.2e6),
        _goal(id: 3, title: 'Quỹ khẩn cấp', target: 10e6, current: 10e6),
      ]);
      await _pump(tester, SavingsSummaryCard(overview: overview));

      expect(find.text('Tổng đã tiết kiệm'), findsOneWidget);
      expect(find.text('28.200.000 đ'), findsOneWidget);
      expect(find.text('Mục tiêu: 40.000.000 đ'), findsOneWidget);
      expect(find.text('3 mục tiêu'), findsOneWidget);
      final bar = tester.widget<LinearProgressIndicator>(
        find.byKey(SavingsSummaryCard.barKey),
      );
      expect(bar.minHeight, 8);
      expect(bar.value, closeTo(0.705, 1e-9));
    });
  });

  group('SavingsGoalList', () {
    Future<ThemeData> pumpList(
      WidgetTester tester,
      List<SavingsGoal> goals, {
      ValueChanged<SavingsGoal>? onTap,
      ValueChanged<SavingsGoal>? onLongPress,
      ThemeMode mode = ThemeMode.light,
      double width = 400,
    }) => _pump(
      tester,
      SavingsGoalList(
        goals: goals,
        today: _today,
        onTap: onTap ?? (_) {},
        onLongPress: onLongPress ?? (_) {},
        onDelete: (_) async => false,
      ),
      mode: mode,
      width: width,
    );

    testWidgets('an unfinished goal shows days left and what is missing', (
      tester,
    ) async {
      final theme = await pumpList(tester, [_goal(deadline: '31/03/2027')]);

      expect(find.text('Mua laptop'), findsOneWidget);
      expect(find.text('Còn 153 ngày · 31/03/2027'), findsOneWidget);
      expect(find.text('Còn thiếu'), findsOneWidget);
      expect(find.text('10 tr'), findsOneWidget);
      final bar = tester.widget<LinearProgressIndicator>(
        find.byKey(SavingsGoalList.barKey('1')),
      );
      expect(bar.value, 0.6);
      expect(bar.color, theme.colorScheme.primary);
    });

    testWidgets('due today, overdue and without a date', (tester) async {
      final theme = await pumpList(tester, [
        _goal(id: 1, deadline: '29/10/2026'),
        _goal(id: 2, title: 'Du lịch', deadline: '01/10/2026'),
        _goal(id: 3, title: 'Tiền cho mẹ'),
      ]);

      expect(find.text('Hạn hôm nay · 29/10/2026'), findsOneWidget);
      expect(find.text('Quá hạn · 01/10/2026'), findsOneWidget);
      expect(
        _textColor(tester, 'Quá hạn · 01/10/2026'),
        theme.semanticColors.warningColor,
      );
      expect(find.text('Không đặt hạn'), findsOneWidget);
    });

    testWidgets('a reached goal says so in the success colour', (tester) async {
      final theme = await pumpList(tester, [
        _goal(title: 'Quỹ khẩn cấp', target: 10e6, current: 10e6),
      ]);

      expect(find.text('Đã đạt mục tiêu'), findsOneWidget);
      expect(
        _textColor(tester, 'Đã đạt mục tiêu'),
        theme.semanticColors.successColor,
      );
      expect(find.text('Còn thiếu'), findsNothing);
      expect(find.text('Đã tiết kiệm'), findsOneWidget);
      expect(find.text('10 tr'), findsOneWidget);
    });

    testWidgets('a goal without a target says so instead of "Còn thiếu 0"', (
      tester,
    ) async {
      await pumpList(tester, [_goal(target: 0, current: 0)]);

      expect(find.text('Chưa đặt số tiền'), findsOneWidget);
      expect(find.text('Còn thiếu'), findsNothing);
    });

    testWidgets('tap and long press reach the goal', (tester) async {
      SavingsGoal? tapped;
      SavingsGoal? held;
      await pumpList(
        tester,
        [_goal(id: 7)],
        onTap: (g) => tapped = g,
        onLongPress: (g) => held = g,
      );

      await tester.tap(find.text('Mua laptop'));
      await tester.longPress(find.text('Mua laptop'));
      expect(tapped?.id, '7');
      expect(held?.id, '7');
    });

    testWidgets('a long title on a narrow dark screen does not overflow', (
      tester,
    ) async {
      await pumpList(
        tester,
        [
          _goal(
            title:
                'Mua một chiếc laptop thật xịn để học lập trình và làm đồ án',
            target: 123456789e3,
            current: 1e3,
            deadline: '31/12/2030',
          ),
        ],
        mode: ThemeMode.dark,
        width: 320,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
