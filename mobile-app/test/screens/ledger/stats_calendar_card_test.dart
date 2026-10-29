import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/app_typography.dart';
import 'package:finance_ai_app/models/ledger_stats.dart';
import 'package:finance_ai_app/screens/ledger/widgets/stats_calendar_card.dart';

import '../../helpers/app_settings_scope.dart';
import '../../helpers/fake_settings_repository.dart';

void main() {
  final month = DateTime(2026, 10);
  final today = DateTime(2026, 10, 20);
  final totals = {
    DateTime(2026, 10, 19): const DayTotals(income: 18500000, expense: 350000),
    DateTime(2026, 10, 20): const DayTotals(income: 0, expense: 97000),
  };

  Future<BuildContext> pump(
    WidgetTester tester, {
    DateTime? selected,
    ValueChanged<DateTime>? onSelected,
    ThemeMode mode = ThemeMode.light,
    Size size = const Size(400, 900),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      withAppSettings(
        Scaffold(
          body: MediaQuery.withClampedTextScaling(
            minScaleFactor: textScale,
            maxScaleFactor: textScale,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: StatsCalendarCard(
                month: month,
                selectedDay: selected ?? DateTime(2026, 10, 19),
                today: today,
                totals: totals,
                onDaySelected: onSelected ?? (_) {},
              ),
            ),
          ),
        ),
        settings: FakeSettingsRepository(themeMode: mode),
      ),
    );
    await tester.pumpAndSettle();
    return tester.element(find.byType(StatsCalendarCard));
  }

  BoxDecoration cell(WidgetTester tester, int day) =>
      tester
              .widget<Container>(find.byKey(StatsCalendarCard.dayKey(day)))
              .decoration
          as BoxDecoration;

  testWidgets('Monday-first grid with leading blanks', (tester) async {
    await pump(tester);
    final days = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    final xs = [for (final d in days) tester.getCenter(find.text(d)).dx];
    for (var i = 1; i < xs.length; i++) {
      expect(xs[i] > xs[i - 1], isTrue);
    }
    // 1 October 2026 is a Thursday: under T5.
    expect(
      tester.getCenter(find.byKey(StatsCalendarCard.dayKey(1))).dx,
      closeTo(xs[3], 1),
    );
    expect(find.byKey(StatsCalendarCard.dayKey(31)), findsOneWidget);
    expect(find.byKey(StatsCalendarCard.dayKey(32)), findsNothing);
  });

  testWidgets(
    'a cell shows compact income in green without +, spending in red, nothing for a zero',
    (tester) async {
      final context = await pump(tester, selected: DateTime(2026, 10, 5));
      final colors = Theme.of(context).colorScheme;
      final income = tester.widget<Text>(find.text('18,5 tr'));
      expect(income.style?.color, context.colors.successColor);
      expect(income.style?.fontSize, AppTextSize.caption);
      expect(tester.widget<Text>(find.text('350k')).style?.color, colors.error);
      expect(find.text('97k'), findsOneWidget);
      expect(find.textContaining('+'), findsNothing);
      expect(find.text('0'), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(StatsCalendarCard.dayKey(18)),
          matching: find.byType(Text),
        ),
        findsOneWidget,
        reason: 'only the day number',
      );
    },
  );

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets(
      'the selected day is filled primary, today only outlined (${mode.name})',
      (tester) async {
        final context = await pump(tester, mode: mode);
        final colors = Theme.of(context).colorScheme;
        expect(cell(tester, 19).color, colors.primary);
        expect(cell(tester, 20).color, isNot(colors.primary));
        expect(cell(tester, 20).border, isNotNull);
        expect(cell(tester, 18).border, isNull);
      },
    );
  }

  testWidgets('future days are faded and still tappable', (tester) async {
    DateTime? picked;
    await pump(tester, onSelected: (d) => picked = d);
    final fade = tester.widget<Opacity>(
      find.ancestor(
        of: find.byKey(StatsCalendarCard.dayKey(25)),
        matching: find.byType(Opacity),
      ),
    );
    expect(fade.opacity, 0.35);
    await tester.tap(find.byKey(StatsCalendarCard.dayKey(25)));
    expect(picked, DateTime(2026, 10, 25));
  });

  testWidgets('tapping a day reports it', (tester) async {
    DateTime? picked;
    await pump(tester, onSelected: (d) => picked = d);
    await tester.tap(find.byKey(StatsCalendarCard.dayKey(3)));
    expect(picked, DateTime(2026, 10, 3));
  });

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets(
      'cells grow to fit two lines at 320 px and text scale 1.3 (${mode.name})',
      (tester) async {
        await pump(
          tester,
          mode: mode,
          size: const Size(320, 1200),
          textScale: 1.3,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'an amount stays on one line in a narrow cell (320 px, text scale 1.3)',
    (tester) async {
      await pump(tester, size: const Size(320, 1200), textScale: 1.3);
      for (final amount in ['18,5 tr', '350k', '97k']) {
        final paragraph = tester.renderObject<RenderParagraph>(
          find.text(amount),
        );
        final lines = paragraph
            .getBoxesForSelection(
              TextSelection(baseOffset: 0, extentOffset: amount.length),
            )
            .map((box) => box.top)
            .toSet();
        expect(lines, hasLength(1), reason: amount);
      }
    },
  );
}
