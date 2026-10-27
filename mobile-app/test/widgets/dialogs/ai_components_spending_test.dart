import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_ai_app/l10n/app_localizations.dart';
import 'package:finance_ai_app/models/spending_analysis.dart';
import 'package:finance_ai_app/models/transaction_model.dart';
import 'package:finance_ai_app/widgets/dialogs/ai_components.dart';

// 2026-10-26 is a Monday, so the 28th is the Wednesday of the same ISO week.
final _mon = DateTime(2026, 10, 26);
final _wed = DateTime(2026, 10, 28);
final _lastWeek = DateTime(2026, 10, 22);

SpendingRule _rule(
  String from,
  String to,
  int support,
  int antecedentSupport,
) => SpendingRule(
  antecedent: [from],
  consequent: [to],
  support: support,
  antecedentSupport: antecedentSupport,
  confidence: support / antecedentSupport,
  laplaceConfidence: (support + 1) / (antecedentSupport + 2),
  lift: 1.5,
  weeks: const [],
);

TransactionModel _expense(String category, DateTime date) => TransactionModel(
  title: category,
  amount: 1000,
  date: date,
  category: category,
  isExpense: true,
);

PeriodicHabit _habit(
  String category,
  double gap,
  DateTime next, {
  DateTime? last,
}) => PeriodicHabit(
  category: category,
  occurrences: 5,
  meanGapDays: gap,
  lastDate: last ?? DateTime(2026, 10, 23),
  nextExpectedDate: next,
);

SpendingAnalysis _analysis({
  SpendingAnalysisStatus status = SpendingAnalysisStatus.ok,
  List<SpendingPattern> patterns = const [],
  int weeks = 12,
  int minWeeks = 8,
}) => SpendingAnalysis(
  status: status,
  patterns: patterns,
  rules: const [],
  habits: const [],
  weeksWithData: weeks,
  minWeeks: minWeeks,
);

SpendingAnalysis _insufficient({required int weeks}) =>
    _analysis(status: SpendingAnalysisStatus.insufficientData, weeks: weeks);

const _foodThenFun = SpendingPattern(
  itemsets: [
    ['Ăn uống'],
    ['Giải trí'],
  ],
  support: 6,
  weightedSupport: 0.4,
  weeks: [],
);

Future<void> _pump(
  WidgetTester tester,
  Widget Function(ColorScheme colors, AppLocalizations loc) build, {
  Locale locale = const Locale('vi'),
}) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: Builder(
            builder: (context) => build(
              Theme.of(context).colorScheme,
              AppLocalizations.of(context)!,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('buildHabitAlertSection', () {
    testWidgets('the future-habit card shows the rule with its week counts', (
      tester,
    ) async {
      await _pump(
        tester,
        (c, l) => AiComponents.buildHabitAlertSection(
          c,
          l,
          [_rule('Ăn uống', 'Mua sắm', 6, 8)],
          const [],
          _wed,
        ),
      );
      expect(find.textContaining('6/8 tuần'), findsOneWidget);
      expect(find.textContaining('Mua sắm'), findsWidgets);
      expect(find.text('Cảnh báo thói quen tương lai'), findsOneWidget);
    });

    testWidgets(
      'a rule whose antecedent was spent this week comes first and is flagged',
      (tester) async {
        await _pump(
          tester,
          (c, l) => AiComponents.buildHabitAlertSection(
            c,
            l,
            [
              _rule('Ăn uống', 'Mua sắm', 9, 10),
              _rule('Giải trí', 'Du lịch', 5, 8),
            ],
            [_expense('Giải trí', _mon)],
            _wed,
          ),
        );
        expect(
          tester.getTopLeft(find.textContaining('Du lịch').first).dy,
          lessThan(tester.getTopLeft(find.textContaining('Mua sắm').first).dy),
        );
        expect(find.textContaining('Tuần này'), findsOneWidget);
      },
    );

    testWidgets('a consequent already spent this week does not flag the rule', (
      tester,
    ) async {
      await _pump(
        tester,
        (c, l) => AiComponents.buildHabitAlertSection(
          c,
          l,
          [_rule('Giải trí', 'Du lịch', 5, 8)],
          [_expense('Giải trí', _mon), _expense('Du lịch', _wed)],
          _wed,
        ),
      );
      expect(find.textContaining('Tuần này'), findsNothing);
      expect(find.textContaining('5/8 tuần'), findsOneWidget);
    });

    testWidgets('spending of last week does not flag the rule', (tester) async {
      await _pump(
        tester,
        (c, l) => AiComponents.buildHabitAlertSection(
          c,
          l,
          [_rule('Giải trí', 'Du lịch', 5, 8)],
          [_expense('Giải trí', _lastWeek)],
          _wed,
        ),
      );
      expect(find.textContaining('Tuần này'), findsNothing);
    });

    testWidgets('a rule with two antecedent categories needs both this week', (
      tester,
    ) async {
      final rule = SpendingRule(
        antecedent: const ['Ăn uống', 'Giải trí'],
        consequent: const ['Du lịch'],
        support: 4,
        antecedentSupport: 6,
        confidence: 0.6,
        laplaceConfidence: 0.6,
        lift: 1.2,
        weeks: const [],
      );
      await _pump(
        tester,
        (c, l) => AiComponents.buildHabitAlertSection(
          c,
          l,
          [rule],
          [_expense('Ăn uống', _mon)],
          _wed,
        ),
      );
      expect(find.textContaining('Tuần này'), findsNothing);
      await _pump(
        tester,
        (c, l) => AiComponents.buildHabitAlertSection(
          c,
          l,
          [rule],
          [_expense('Ăn uống', _mon), _expense('Giải trí', _wed)],
          _wed,
        ),
      );
      expect(find.textContaining('Tuần này'), findsOneWidget);
    });

    testWidgets('no rule, no card', (tester) async {
      await _pump(
        tester,
        (c, l) =>
            AiComponents.buildHabitAlertSection(c, l, const [], const [], _wed),
      );
      expect(find.text('Cảnh báo thói quen tương lai'), findsNothing);
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('at most three rules are shown', (tester) async {
      await _pump(
        tester,
        (c, l) => AiComponents.buildHabitAlertSection(
          c,
          l,
          [for (var i = 0; i < 5; i++) _rule('A$i', 'B$i', 6, 8)],
          const [],
          _wed,
        ),
      );
      expect(find.textContaining('6/8 tuần'), findsNWidgets(3));
    });

    testWidgets('the English text says the same with the counts', (
      tester,
    ) async {
      await _pump(
        tester,
        (c, l) => AiComponents.buildHabitAlertSection(
          c,
          l,
          [_rule('Ăn uống', 'Mua sắm', 6, 8)],
          const [],
          _wed,
        ),
        locale: const Locale('en'),
      );
      expect(find.textContaining('6/8 weeks'), findsOneWidget);
    });
  });

  group('buildPeriodicHabitsSection', () {
    testWidgets('periodic habits show the gap and the next date', (
      tester,
    ) async {
      await _pump(
        tester,
        (c, l) => AiComponents.buildPeriodicHabitsSection(c, l, [
          _habit('Siêu thị & Chợ', 6.8, DateTime(2026, 10, 30)),
        ], _wed),
      );
      expect(find.text('Thói quen định kỳ'), findsOneWidget);
      expect(find.textContaining('6,8 ngày/lần'), findsOneWidget);
      expect(find.textContaining('30/10'), findsOneWidget);
    });

    testWidgets(
      'a habit whose next date has passed shows the last date instead',
      (tester) async {
        await _pump(
          tester,
          (c, l) => AiComponents.buildPeriodicHabitsSection(c, l, [
            _habit(
              'Siêu thị & Chợ',
              7,
              DateTime(2026, 10, 27),
              last: DateTime(2026, 10, 20),
            ),
          ], _wed),
        );
        expect(find.textContaining('lần gần nhất 20/10'), findsOneWidget);
        expect(find.textContaining('lần tới'), findsNothing);
      },
    );

    testWidgets('a habit due today is not late', (tester) async {
      await _pump(
        tester,
        (c, l) => AiComponents.buildPeriodicHabitsSection(c, l, [
          _habit('Siêu thị & Chợ', 7, DateTime(2026, 10, 28)),
        ], DateTime(2026, 10, 28, 15)),
      );
      expect(find.textContaining('lần tới'), findsOneWidget);
    });

    testWidgets('at most five habits, none for an empty list', (tester) async {
      await _pump(
        tester,
        (c, l) => AiComponents.buildPeriodicHabitsSection(c, l, [
          for (var i = 0; i < 7; i++)
            _habit('Loại $i', 7, DateTime(2026, 11, 2)),
        ], _wed),
      );
      expect(find.textContaining('ngày/lần'), findsNWidgets(5));
      await _pump(
        tester,
        (c, l) => AiComponents.buildPeriodicHabitsSection(c, l, const [], _wed),
      );
      expect(find.byType(Text), findsNothing);
    });
  });

  group('buildSpadeSection', () {
    testWidgets('insufficient data shows weeks so far and weeks needed', (
      tester,
    ) async {
      await _pump(
        tester,
        (c, l) => AiComponents.buildSpadeSection(
          c,
          l,
          _insufficient(weeks: 5),
          false,
        ),
      );
      expect(find.text('Chưa đủ dữ liệu'), findsOneWidget);
      expect(find.textContaining('5 tuần'), findsOneWidget);
      expect(find.textContaining('8 tuần'), findsOneWidget);
    });

    testWidgets('no analysis at all keeps the not-enough-data title', (
      tester,
    ) async {
      await _pump(
        tester,
        (c, l) =>
            AiComponents.buildSpadeSection(c, l, SpendingAnalysis.empty, false),
      );
      expect(find.text('Chưa đủ dữ liệu'), findsOneWidget);
    });

    testWidgets('enough weeks but no sequence says so, not "not enough data"', (
      tester,
    ) async {
      await _pump(
        tester,
        (c, l) => AiComponents.buildSpadeSection(c, l, _analysis(), false),
      );
      expect(find.text('Chưa đủ dữ liệu'), findsNothing);
      expect(find.text('Chưa có mẫu nào'), findsOneWidget);
    });

    testWidgets(
      'a pattern line reads its categories in the language on screen and says k/n weeks',
      (tester) async {
        final analysis = _analysis(patterns: const [_foodThenFun]);
        await _pump(
          tester,
          (c, l) => AiComponents.buildSpadeSection(c, l, analysis, false),
          locale: const Locale('en'),
        );
        expect(find.text('Food & drinks → Entertainment'), findsOneWidget);
        expect(find.text('In 6/12 weeks'), findsOneWidget);
        expect(find.textContaining('W-Sup'), findsNothing);
      },
    );

    testWidgets('the Vietnamese pattern detail reads "Có trong 6/12 tuần"', (
      tester,
    ) async {
      final analysis = _analysis(patterns: const [_foodThenFun]);
      await _pump(
        tester,
        (c, l) => AiComponents.buildSpadeSection(c, l, analysis, false),
      );
      expect(find.text('Có trong 6/12 tuần'), findsOneWidget);
    });
  });
}
